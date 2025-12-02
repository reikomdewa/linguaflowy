import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/vocabulary/vocabulary_bloc.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/user_model.dart';
import 'package:linguaflow/models/vocabulary_item.dart';
import 'package:linguaflow/services/translation_service.dart';
import 'package:linguaflow/services/vocabulary_service.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class ReaderScreen extends StatefulWidget {
  final LessonModel lesson;

  const ReaderScreen({required this.lesson});

  @override
  _ReaderScreenState createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  Map<String, VocabularyItem> _vocabulary = {};
  
  // --- VIDEO STATE ---
  YoutubePlayerController? _videoController;
  bool _isVideo = false;
  bool _isAudioMode = false;
  bool _isPlaying = false; 

  // --- TTS STATE ---
  final FlutterTts _flutterTts = FlutterTts();
  bool _isTtsPlaying = false;
  double _ttsSpeed = 0.5;

  // --- SYNC & SCROLL STATE ---
  // FIXED: Renamed to match usage in build method
  int _activeSentenceIndex = -1; 
  final List<GlobalKey> _itemKeys = []; 

  // --- SELECTION STATE ---
  bool _isSelectionMode = false;
  int _selectionSentenceIndex = -1;
  int _selectionStartIndex = -1;
  int _selectionEndIndex = -1;
  
  // Maps sentenceIndex -> List of GlobalKeys for each word (For hit testing)
  final Map<int, List<GlobalKey>> _wordKeys = {};

  @override
  void initState() {
    super.initState();
    _loadVocabulary();
    
    // Generate Keys for Auto-Scrolling
    final count = widget.lesson.transcript.isNotEmpty 
        ? widget.lesson.transcript.length 
        : widget.lesson.sentences.length;
    
    for (var i = 0; i < count; i++) {
      _itemKeys.add(GlobalKey());
    }

    if (widget.lesson.type == 'video' || widget.lesson.videoUrl != null) {
      _initializeVideoPlayer();
    } else {
      _initializeTts();
    }
  }

  @override
  void dispose() {
    _videoController?.removeListener(_videoListener);
    _videoController?.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  // --- DATA LOADING ---
  Future<void> _loadVocabulary() async {
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    final vocabService = context.read<VocabularyService>();
    final items = await vocabService.getVocabulary(user.id);
    if (mounted) {
      setState(() {
        _vocabulary = {for (var item in items) item.word.toLowerCase(): item};
      });
    }
  }

  // --- COLOR LOGIC (LingQ Style) ---
  Color _getWordColor(VocabularyItem? item) {
    // 1. New Word (Unknown) -> Blue Highlight
    if (item == null || item.status == 0) {
      return Colors.blue.withOpacity(0.15); 
    }
    
    // 2. Learning Stages -> Yellow/Orange gradients
    switch (item.status) {
      case 1: return Color(0xFFFFF9C4); // Very Light Yellow
      case 2: return Color(0xFFFFF59D); // Light Yellow
      case 3: return Color(0xFFFFCC80); // Light Orange
      case 4: return Color(0xFFFFB74D); // Orange
      
      // 3. Known Word -> Transparent (Looks like normal text)
      case 5: return Colors.transparent; 
      
      // 4. Ignored -> Transparent/Grey
      default: return Colors.transparent;
    }
  }

  // --- SELECTION HELPERS ---
  void _handleDragUpdate(int sentenceIndex, Offset globalPosition) {
    final keys = _wordKeys[sentenceIndex];
    if (keys == null) return;

    for (int i = 0; i < keys.length; i++) {
      final key = keys[i];
      final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
      
      if (renderBox != null) {
        final localPosition = renderBox.globalToLocal(globalPosition);
        final size = renderBox.size;
        
        if (localPosition.dx >= 0 && localPosition.dx <= size.width &&
            localPosition.dy >= 0 && localPosition.dy <= size.height) {
          
          setState(() {
            if (i < _selectionStartIndex) {
              _selectionStartIndex = i;
            } else {
              _selectionEndIndex = i;
            }
          });
          break;
        }
      }
    }
  }

  void _finishSelection(String fullSentence) {
    if (_selectionStartIndex == -1 || _selectionEndIndex == -1) {
      _clearSelection();
      return;
    }

    final start = _selectionStartIndex < _selectionEndIndex ? _selectionStartIndex : _selectionEndIndex;
    final end = _selectionStartIndex < _selectionEndIndex ? _selectionEndIndex : _selectionStartIndex;

    final words = fullSentence.split(RegExp(r'(\s+)'));
    
    if (start < 0 || end >= words.length) {
      _clearSelection();
      return;
    }

    // Reconstruct phrase
    final sublist = words.sublist(start, end + 1);
    final phrase = sublist.join(""); 
    
    final cleanId = phrase.toLowerCase().trim().replaceAll(RegExp(r'[^\w\s]'), '');
    final originalText = phrase.trim();

    _showWordDialog(cleanId, originalText);
  }

  void _clearSelection() {
    setState(() {
      _isSelectionMode = false;
      _selectionSentenceIndex = -1;
      _selectionStartIndex = -1;
      _selectionEndIndex = -1;
    });
  }

  // --- VIDEO LOGIC ---
  void _initializeVideoPlayer() {
    String? videoId;
    if (widget.lesson.id.startsWith('yt_')) {
      videoId = widget.lesson.id.replaceAll('yt_', '');
    } else if (widget.lesson.videoUrl != null) {
      videoId = YoutubePlayer.convertUrlToId(widget.lesson.videoUrl!);
    }

    if (videoId != null) {
      _isVideo = true;
      _videoController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
          enableCaption: false,
          forceHD: false,
        ),
      );
      _videoController!.addListener(_videoListener);
    }
  }

  void _videoListener() {
    if (_videoController == null) return;
    
    // Sync Play Button UI
    if (_videoController!.value.isPlaying != _isPlaying) {
      setState(() => _isPlaying = _videoController!.value.isPlaying);
    }

    // Sync Transcript Highlight
    if (widget.lesson.transcript.isEmpty) return;

    final currentSeconds = _videoController!.value.position.inMilliseconds / 1000;
    int newIndex = -1;
    
    for (int i = 0; i < widget.lesson.transcript.length; i++) {
      final line = widget.lesson.transcript[i];
      if (currentSeconds >= line.start && currentSeconds < line.end) {
        newIndex = i;
        break;
      }
    }

    // Only scroll if NOT selecting
    if (!_isSelectionMode && newIndex != -1 && newIndex != _activeSentenceIndex) {
      setState(() => _activeSentenceIndex = newIndex);
      _scrollToActiveLine(newIndex);
    }
  }

  void _scrollToActiveLine(int index) {
    if (index < _itemKeys.length && _itemKeys[index].currentContext != null) {
      Scrollable.ensureVisible(
        _itemKeys[index].currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.5,
      );
    }
  }

  void _seekToTime(double seconds) {
    if (_videoController != null) {
      _videoController!.seekTo(Duration(milliseconds: (seconds * 1000).toInt()));
      _videoController!.play();
    }
  }

  // --- TTS LOGIC ---
  void _initializeTts() async {
    await _flutterTts.setLanguage(widget.lesson.language);
    await _flutterTts.setSpeechRate(_ttsSpeed);
    
    // Attempt to pick best voice
    if (Platform.isAndroid) {
        try {
          var voices = await _flutterTts.getVoices;
          var bestVoice = voices.firstWhere((v) => 
            v['locale'].toString().startsWith(widget.lesson.language) && 
            v['name'].toString().toLowerCase().contains('network'), orElse: () => null);
          if (bestVoice != null) {
             await _flutterTts.setVoice({"name": bestVoice["name"], "locale": bestVoice["locale"]});
          }
        } catch(e) {}
    }

    _flutterTts.setCompletionHandler(() {
      setState(() {
        _isTtsPlaying = false;
        _activeSentenceIndex = -1;
      });
    });
  }

  Future<void> _speakSentence(String text, int index) async {
    await _flutterTts.stop();
    setState(() {
      _activeSentenceIndex = index;
      _isTtsPlaying = true;
    });
    await _flutterTts.speak(text);
  }

  Future<void> _toggleTtsFullLesson() async {
    if (_isTtsPlaying) {
      await _flutterTts.stop();
      setState(() {
        _isTtsPlaying = false;
        _activeSentenceIndex = -1;
      });
    } else {
      setState(() => _isTtsPlaying = true);
      await _flutterTts.speak(widget.lesson.content);
    }
  }

  Future<void> _changeTtsSpeed() async {
    double newSpeed = _ttsSpeed == 0.5 ? 0.75 : (_ttsSpeed == 0.75 ? 1.0 : 0.5);
    await _flutterTts.setSpeechRate(newSpeed);
    setState(() => _ttsSpeed = newSpeed);
  }

  @override
  Widget build(BuildContext context) {
    final bool hasTranscript = widget.lesson.transcript.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white, // LingQ style white background
      appBar: AppBar(
        title: _isSelectionMode 
          ? Text("Select Phrase", style: TextStyle(color: Colors.white, fontSize: 16))
          : Text(widget.lesson.title, style: TextStyle(fontSize: 16, color: Colors.black)),
        backgroundColor: _isSelectionMode ? Colors.purple : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: _isSelectionMode ? Colors.white : Colors.black),
        leading: _isSelectionMode 
          ? IconButton(icon: Icon(Icons.close), onPressed: _clearSelection)
          : BackButton(),
        actions: [
          if (!_isSelectionMode && _isVideo)
            IconButton(
              icon: Icon(_isAudioMode ? Icons.videocam : Icons.headphones),
              onPressed: () => setState(() => _isAudioMode = !_isAudioMode),
            ),
          IconButton(icon: Icon(Icons.settings), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          _isVideo ? _buildVideoHeader() : _buildTtsHeader(),

          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(bottom: BorderSide(color: Colors.grey[200]!))
            ),
            child: Row(
              children: [
                Icon(Icons.language, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Text(widget.lesson.language.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                Spacer(),
                Text(hasTranscript ? '${widget.lesson.transcript.length} lines' : '${widget.lesson.sentences.length} sentences', 
                     style: TextStyle(color: Colors.grey[700])),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.lesson.title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.2)),
                  SizedBox(height: 24),
                  
                  if (hasTranscript)
                    ...widget.lesson.transcript.asMap().entries.map((entry) {
                      final index = entry.key;
                      final line = entry.value;
                      final isActive = index == _activeSentenceIndex;

                      return Container(
                        key: _itemKeys[index],
                        margin: EdgeInsets.only(bottom: 12),
                        // Highlight Active Sentence with subtle grey background
                        padding: isActive ? EdgeInsets.all(12) : EdgeInsets.zero,
                        decoration: BoxDecoration(
                          color: isActive ? Colors.grey[100] : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_isVideo)
                              GestureDetector(
                                onTap: () => _seekToTime(line.start),
                                child: Padding(
                                  padding: EdgeInsets.only(top: 4, right: 12),
                                  child: Icon(
                                    isActive ? Icons.play_arrow : Icons.play_arrow_outlined, 
                                    color: isActive ? Colors.blue : Colors.grey[400], 
                                    size: 24
                                  ),
                                ),
                              ),
                            Expanded(
                              child: GestureDetector(
                                onDoubleTap: () => !_isSelectionMode && _isVideo ? _seekToTime(line.start) : null,
                                child: _buildSentence(line.text, index),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList()
                  else
                    ...widget.lesson.sentences.asMap().entries.map((entry) {
                      final index = entry.key;
                      final sentence = entry.value;
                      final isActive = index == _activeSentenceIndex;

                      return GestureDetector(
                        onDoubleTap: () => _speakSentence(sentence, index),
                        child: Container(
                          key: _itemKeys[index],
                          margin: EdgeInsets.only(bottom: 24), // More spacing for text lessons
                          padding: isActive ? EdgeInsets.all(12) : EdgeInsets.zero,
                          decoration: BoxDecoration(
                            color: isActive ? Colors.yellow.withOpacity(0.1) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _buildSentence(sentence, index),
                        ),
                      );
                    }).toList(),
                  
                  SizedBox(height: 100), // Bottom padding for FAB/Scroll
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- SENTENCE BUILDER (LingQ Style) ---
  Widget _buildSentence(String sentence, int sentenceIndex) {
    // 1. Prepare keys for hit testing this specific sentence
    _wordKeys[sentenceIndex] = [];
    
    // Split keeping delimiters to maintain spacing
    final words = sentence.split(RegExp(r'(\s+)'));
    
    return Wrap(
      // LingQ uses tighter spacing, relying on space characters
      spacing: 0, 
      runSpacing: 6, // Line height feel
      children: words.asMap().entries.map((entry) {
        final int wordIndex = entry.key;
        final String word = entry.value;
        final cleanWord = word.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
        
        final GlobalKey wordKey = GlobalKey();
        _wordKeys[sentenceIndex]!.add(wordKey);

        // Render plain text if it's just a space or punctuation
        if (cleanWord.isEmpty || word.trim().isEmpty) {
          return Text(word, style: TextStyle(fontSize: 18, height: 1.5, color: Colors.black87));
        }

        // Selection Logic
        bool isSelected = false;
        if (_isSelectionMode && _selectionSentenceIndex == sentenceIndex) {
          int start = _selectionStartIndex < _selectionEndIndex ? _selectionStartIndex : _selectionEndIndex;
          int end = _selectionStartIndex < _selectionEndIndex ? _selectionEndIndex : _selectionStartIndex;
          if (wordIndex >= start && wordIndex <= end) isSelected = true;
        }

        final vocabItem = _vocabulary[cleanWord];
        
        // Priority: Selection > Vocab Status > Transparent
        Color bgColor = isSelected ? Colors.purple.withOpacity(0.2) : _getWordColor(vocabItem);
        
        // Text Color: Known words are black, Unknown might be blue-ish if you want
        Color textColor = Colors.black87;

        return GestureDetector(
          key: wordKey,
          onLongPressStart: (_) => _startSelection(sentenceIndex, wordIndex),
          onLongPressMoveUpdate: (details) => _handleDragUpdate(sentenceIndex, details.globalPosition),
          onLongPressEnd: (_) => _finishSelection(sentence),
          onTap: () {
            if (_isSelectionMode) {
              _clearSelection();
            } else {
              _onWordTap(cleanWord, word, sentenceIndex);
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(4), // Subtle rounded corners like LingQ
              border: isSelected ? Border.all(color: Colors.purple, width: 1) : null,
            ),
            // Padding inside the highlight box
            padding: EdgeInsets.symmetric(horizontal: 1, vertical: 1),
            child: Text(
              word,
              style: TextStyle(
                fontSize: 18,
                height: 1.5, // Good reading height
                color: textColor,
                fontFamily: 'Roboto', // Or serif if preferred
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // --- HEADER WIDGETS ---
  Widget _buildVideoHeader() {
    if (_videoController == null) return SizedBox.shrink();
    return Column(
      children: [
        SizedBox(
          height: _isAudioMode ? 1 : 220,
          child: YoutubePlayer(
            controller: _videoController!,
            showVideoProgressIndicator: true,
            progressIndicatorColor: Colors.red,
          ),
        ),
        if (_isAudioMode) _buildAudioPlayerUI(),
      ],
    );
  }

  Widget _buildAudioPlayerUI() {
    return Container(
      color: Colors.grey[100],
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                iconSize: 42,
                icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.blue),
                onPressed: () => _isPlaying ? _videoController!.pause() : _videoController!.play(),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Audio Mode", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 12)),
                    Text(widget.lesson.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          StreamBuilder<YoutubePlayerValue>(
            stream: Stream.periodic(Duration(milliseconds: 200), (_) => _videoController!.value),
            builder: (context, snapshot) {
              final position = _videoController!.value.position.inSeconds.toDouble();
              final duration = _videoController!.value.metaData.duration.inSeconds.toDouble();
              return Slider(
                value: position.clamp(0.0, duration > 0 ? duration : 1.0),
                min: 0.0,
                max: duration > 0 ? duration : 1.0,
                onChanged: (val) => _videoController!.seekTo(Duration(seconds: val.toInt())),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTtsHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.blue,
            child: IconButton(
              icon: Icon(_isTtsPlaying ? Icons.stop : Icons.play_arrow, color: Colors.white),
              onPressed: _toggleTtsFullLesson,
            ),
          ),
          SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Audio Lesson", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text("Tap 2x on text to read", style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          Spacer(),
          InkWell(
            onTap: _changeTtsSpeed,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(20)),
              child: Text("${_ttsSpeed}x", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            ),
          ),
        ],
      ),
    );
  }

  // --- SELECTION STATE ---
  void _startSelection(int sentenceIndex, int wordIndex) {
    if (_isVideo && _videoController != null) _videoController!.pause();
    if (_isTtsPlaying) { _flutterTts.stop(); setState(() => _isTtsPlaying = false); }

    setState(() {
      _isSelectionMode = true;
      _selectionSentenceIndex = sentenceIndex;
      _selectionStartIndex = wordIndex;
      _selectionEndIndex = wordIndex;
    });
  }

  void _onWordTap(String cleanWord, String originalWord, int wordIndex) {
    if (_isTtsPlaying) { _flutterTts.stop(); setState(() => _isTtsPlaying = false); }
    _showWordDialog(cleanWord, originalWord);
  }

  // --- DIALOG LOGIC ---
  void _showWordDialog(String cleanWord, String originalWord) async {
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    final vocabService = context.read<VocabularyService>();
    final translationService = context.read<TranslationService>();

    VocabularyItem? existingItem = _vocabulary[cleanWord];
    String translation = existingItem?.translation ?? 'Loading...';

    if (existingItem == null) {
      translationService.translate(cleanWord, user.nativeLanguage, widget.lesson.language).then((val) {});
    }

    bool resumeVideoAfter = false;
    if (_isVideo && _videoController != null && _videoController!.value.isPlaying) {
      _videoController!.pause();
      resumeVideoAfter = true;
    }

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(builder: (context, setModalState) {
         if (existingItem == null && translation == 'Loading...') {
             translationService.translate(cleanWord, user.nativeLanguage, widget.lesson.language).then((val) {
               if(mounted) setModalState(() => translation = val);
             });
             translation = 'Translating...';
         }
         return Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            padding: EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(originalWord, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold))),
                      IconButton(
                        icon: Icon(Icons.volume_up, color: Colors.blue),
                        onPressed: () => _flutterTts.speak(originalWord),
                      )
                    ],
                  ),
                  SizedBox(height: 8),
                  Text('Translation', style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                  Text(translation, style: TextStyle(fontSize: 20)),
                  SizedBox(height: 32),
                  Text('Status', style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                  SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                      _StatusButton(label: 'New', status: 0, color: Colors.blue, onTap: () => _updateWordStatus(cleanWord, originalWord, translation, 0)),
                      _StatusButton(label: '1', status: 1, color: Colors.yellow[700]!, onTap: () => _updateWordStatus(cleanWord, originalWord, translation, 1)),
                      _StatusButton(label: '2', status: 2, color: Colors.orange[600]!, onTap: () => _updateWordStatus(cleanWord, originalWord, translation, 2)),
                      _StatusButton(label: '3', status: 3, color: Colors.orange[700]!, onTap: () => _updateWordStatus(cleanWord, originalWord, translation, 3)),
                      _StatusButton(label: '4', status: 4, color: Colors.orange[800]!, onTap: () => _updateWordStatus(cleanWord, originalWord, translation, 4)),
                      _StatusButton(label: 'Known', status: 5, color: Colors.green, onTap: () => _updateWordStatus(cleanWord, originalWord, translation, 5)),
                  ]),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _updateWordStatus(cleanWord, originalWord, translation, -1),
                    icon: Icon(Icons.block),
                    label: Text('Ignore Word'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey, minimumSize: Size(double.infinity, 48)),
                  ),
                ],
              ),
            ),
         );
      }),
    ).then((_) {
      _clearSelection();
    });

    if (resumeVideoAfter && _isVideo && _videoController != null) {
      _videoController!.play();
    }
  }

  void _updateWordStatus(String cleanWord, String originalWord, String translation, int status) {
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    VocabularyItem? existingItem = _vocabulary[cleanWord];
    if (existingItem != null) {
      final updatedItem = existingItem.copyWith(status: status, timesEncountered: existingItem.timesEncountered + 1);
      context.read<VocabularyBloc>().add(VocabularyUpdateRequested(updatedItem));
      setState(() => _vocabulary[cleanWord] = updatedItem);
    } else {
      final newItem = VocabularyItem(id: '', userId: user.id, word: cleanWord, baseForm: cleanWord, language: widget.lesson.language, translation: translation, status: status, timesEncountered: 1, lastReviewed: DateTime.now(), createdAt: DateTime.now());
      context.read<VocabularyBloc>().add(VocabularyAddRequested(newItem));
      setState(() => _vocabulary[cleanWord] = newItem);
    }
    Navigator.pop(context);
  }
}

class _StatusButton extends StatelessWidget {
  final String label;
  final int status;
  final Color color;
  final VoidCallback onTap;
  const _StatusButton({required this.label, required this.status, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 60, child: ElevatedButton(onPressed: onTap, style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, padding: EdgeInsets.zero), child: Text(label)));
  }
}