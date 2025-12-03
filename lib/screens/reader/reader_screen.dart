// 


import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/vocabulary/vocabulary_bloc.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/vocabulary_item.dart';
import 'package:linguaflow/services/translation_service.dart';
import 'package:linguaflow/services/vocabulary_service.dart';
// Make sure to import your translation sheet file
import 'package:linguaflow/widgets/translation_sheet.dart'; 
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
  int _activeSentenceIndex = -1;
  final List<GlobalKey> _itemKeys = [];

  // --- SELECTION STATE ---
  bool _isSelectionMode = false;
  int _selectionSentenceIndex = -1;
  int _selectionStartIndex = -1;
  int _selectionEndIndex = -1;

  // --- SENTENCE MODE STATE ---
  bool _isSentenceMode = false;
  bool _hasShownSwipeHint = false;

  // --- KEY CACHING ---
  final Map<String, GlobalKey> _stableWordKeys = {};

  @override
  void initState() {
    super.initState();

    final envKey = dotenv.env['GEMINI_API_KEY'];
    if (envKey != null && envKey.isNotEmpty) {
      try {
        Gemini.init(apiKey: envKey);
      } catch (e) {
        print("Gemini Init Error: $e");
      }
    }

    _loadVocabulary();

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
    try {
      _videoController?.removeListener(_videoListener);
    } catch (_) {}
    _videoController?.dispose();
    _flutterTts.stop();
    _stableWordKeys.clear();
    super.dispose();
  }

  GlobalKey _getWordKey(int sentenceIndex, int wordIndex) {
    final key = "s${sentenceIndex}_w$wordIndex";
    if (!_stableWordKeys.containsKey(key)) {
      _stableWordKeys[key] = GlobalKey();
    }
    return _stableWordKeys[key]!;
  }

  Future<void> _loadVocabulary() async {
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    
    // UPDATED: Fetch directly from Firestore to ensure persistence
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .collection('vocabulary')
          .get();

      final Map<String, VocabularyItem> loadedVocab = {};
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        loadedVocab[doc.id] = VocabularyItem(
          id: doc.id,
          userId: user.id,
          word: data['word'] ?? doc.id,
          baseForm: data['baseForm'] ?? doc.id,
          language: data['language'] ?? '',
          translation: data['translation'] ?? '',
          status: data['status'] ?? 0,
          timesEncountered: data['timesEncountered'] ?? 1,
          lastReviewed: (data['lastReviewed'] as Timestamp?)?.toDate() ?? DateTime.now(),
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }

      if (mounted) {
        setState(() {
          _vocabulary = loadedVocab;
        });
      }
    } catch (e) {
      print("Error loading vocabulary from Firestore: $e");
      // Fallback to service
      try {
        final vocabService = context.read<VocabularyService>();
        final items = await vocabService.getVocabulary(user.id);
        if (mounted) {
          setState(() {
            _vocabulary = {for (var item in items) item.word.toLowerCase(): item};
          });
        }
      } catch (_) {}
    }
  }

  Color _getWordColor(VocabularyItem? item) {
    if (item == null || item.status == 0) {
      return Colors.blue.withOpacity(0.15);
    }
    switch (item.status) {
      case 1:
        return Color(0xFFFFF9C4);
      case 2:
        return Color(0xFFFFF59D);
      case 3:
        return Color(0xFFFFCC80);
      case 4:
        return Color(0xFFFFB74D);
      case 5:
        return Colors.transparent;
      default:
        return Colors.transparent;
    }
  }

  // --- SELECTION LOGIC ---
  void _handleDragUpdate(
    int sentenceIndex,
    int maxWords,
    Offset globalPosition,
  ) {
    for (int i = 0; i < maxWords; i++) {
      final key = _getWordKey(sentenceIndex, i);
      final context = key.currentContext;

      if (context != null) {
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          final topLeft = renderBox.localToGlobal(Offset.zero);
          final size = renderBox.size;
          final rect = topLeft & size;
          final inflatedRect = rect.inflate(10.0);

          if (inflatedRect.contains(globalPosition)) {
            if (_selectionEndIndex != i) {
              setState(() {
                _selectionEndIndex = i;
              });
            }
            return;
          }
        }
      }
    }
  }

  void _finishSelection(String fullSentence) {
    if (_selectionStartIndex == -1 || _selectionEndIndex == -1) {
      _clearSelection();
      return;
    }

    final start = _selectionStartIndex < _selectionEndIndex
        ? _selectionStartIndex
        : _selectionEndIndex;
    final end = _selectionStartIndex < _selectionEndIndex
        ? _selectionEndIndex
        : _selectionStartIndex;

    final words = fullSentence.split(RegExp(r'(\s+)'));

    if (start < 0 || end >= words.length) {
      _clearSelection();
      return;
    }

    final sublist = words.sublist(start, end + 1);
    final phrase = sublist.join(" ");

    final cleanId = phrase.toLowerCase().trim().replaceAll(
      RegExp(r'[^\w\s]'),
      '',
    );
    final originalText = phrase.trim();

    final bool isPhraseSelection = sublist.length > 1;

    _showLingQDialog(cleanId, originalText, isPhrase: isPhraseSelection);
  }

  void _clearSelection() {
    setState(() {
      _isSelectionMode = false;
      _selectionSentenceIndex = -1;
      _selectionStartIndex = -1;
      _selectionEndIndex = -1;
    });
  }

  void _startSelection(int sentenceIndex, int wordIndex) {
    if (_isVideo && _videoController != null) _videoController!.pause();
    if (_isTtsPlaying) _flutterTts.stop();

    setState(() {
      _isSelectionMode = true;
      _selectionSentenceIndex = sentenceIndex;
      _selectionStartIndex = wordIndex;
      _selectionEndIndex = wordIndex;
    });
  }

  // --- MEDIA CONTROLS ---
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
        ),
      );
      _videoController!.addListener(_videoListener);
    }
  }

  void _videoListener() {
    if (_videoController == null) return;
    if (_videoController!.value.isPlaying != _isPlaying) {
      setState(() => _isPlaying = _videoController!.value.isPlaying);
    }

    if (widget.lesson.transcript.isEmpty) return;
    final currentSeconds =
        _videoController!.value.position.inMilliseconds / 1000;

    int realTimeIndex = -1;
    for (int i = 0; i < widget.lesson.transcript.length; i++) {
      final line = widget.lesson.transcript[i];
      if (currentSeconds >= line.start && currentSeconds < line.end) {
        realTimeIndex = i;
        break;
      }
    }

    if (_isSentenceMode) {
      if (realTimeIndex != -1 && realTimeIndex != _activeSentenceIndex) {
        setState(() => _activeSentenceIndex = realTimeIndex);
      }
      if (_activeSentenceIndex >= 0 &&
          _activeSentenceIndex < widget.lesson.transcript.length) {
        final activeLine = widget.lesson.transcript[_activeSentenceIndex];
        if (_isPlaying &&
            currentSeconds >= activeLine.end &&
            currentSeconds < activeLine.end + 0.5) {
          if (realTimeIndex == _activeSentenceIndex) {
            _videoController!.pause();
          }
        }
      }
    } else if (!_isSelectionMode) {
      if (realTimeIndex != -1 && realTimeIndex != _activeSentenceIndex) {
        setState(() => _activeSentenceIndex = realTimeIndex);
        _scrollToActiveLine(realTimeIndex);
      }
    }
  }

  void _scrollToActiveLine(int index) {
    if (!_isSentenceMode &&
        index < _itemKeys.length &&
        _itemKeys[index].currentContext != null) {
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
      _videoController!.seekTo(
        Duration(milliseconds: (seconds * 1000).toInt()),
      );
      _videoController!.play();
    }
  }

  void _initializeTts() async {
    await _flutterTts.setLanguage(widget.lesson.language);
    await _flutterTts.setSpeechRate(_ttsSpeed);
    _flutterTts.setCompletionHandler(() {
      setState(() {
        _isTtsPlaying = false;
        if (!_isSentenceMode) _activeSentenceIndex = -1;
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
        if (!_isSentenceMode) _activeSentenceIndex = -1;
      });
    } else {
      setState(() => _isTtsPlaying = true);
      await _flutterTts.speak(widget.lesson.content);
    }
  }

  void _toggleSentenceMode() {
    setState(() {
      _isSentenceMode = !_isSentenceMode;
      if (_activeSentenceIndex == -1) _activeSentenceIndex = 0;
    });
    if (_isSentenceMode) {
      _playCurrentSentenceInMode();
    }
  }

  // --- SWIPE LOGIC ---
  void _handleSwipeMarking(int leavingIndex) {
    if (leavingIndex < 0) return;

    String sentenceText = "";
    if (widget.lesson.transcript.isNotEmpty &&
        leavingIndex < widget.lesson.transcript.length) {
      sentenceText = widget.lesson.transcript[leavingIndex].text;
    } else if (leavingIndex < widget.lesson.sentences.length) {
      sentenceText = widget.lesson.sentences[leavingIndex];
    }

    if (sentenceText.isEmpty) return;

    final words = sentenceText.split(RegExp(r'(\s+)'));
    bool markedAny = false;

    for (var word in words) {
      final clean = word.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
      if (clean.isEmpty) continue;

      final item = _vocabulary[clean];
      if (item == null || item.status == 0) {
        _updateWordStatus(
          clean,
          word.trim(),
          "", // Auto-marked doesn't need translation
          5,
          showDialog: false,
        );
        markedAny = true;
      }
    }

    if (markedAny && !_hasShownSwipeHint) {
      _hasShownSwipeHint = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Swiping marks blue words as known"),
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _nextSentence() {
    final count = widget.lesson.transcript.isNotEmpty
        ? widget.lesson.transcript.length
        : widget.lesson.sentences.length;

    if (_activeSentenceIndex < count - 1) {
      _handleSwipeMarking(_activeSentenceIndex);
      setState(() => _activeSentenceIndex++);
      _playCurrentSentenceInMode();
    }
  }

  void _prevSentence() {
    if (_activeSentenceIndex > 0) {
      setState(() => _activeSentenceIndex--);
      _playCurrentSentenceInMode();
    }
  }

  void _playCurrentSentenceInMode() {
    if (_activeSentenceIndex == -1) return;
    if (_isVideo && widget.lesson.transcript.isNotEmpty) {
      final line = widget.lesson.transcript[_activeSentenceIndex];
      _seekToTime(line.start);
    } else {
      final sentence = widget.lesson.sentences[_activeSentenceIndex];
      _speakSentence(sentence, _activeSentenceIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: _isSelectionMode
            ? Text(
                "Release to Translate",
                style: TextStyle(color: Colors.white, fontSize: 16),
              )
            : Text(
                widget.lesson.title,
                style: TextStyle(color: textColor, fontSize: 16),
              ),
        backgroundColor: _isSelectionMode ? Colors.purple : bgColor,
        elevation: 0,
        iconTheme: IconThemeData(
          color: _isSelectionMode ? Colors.white : textColor,
        ),
        leading: _isSelectionMode
            ? IconButton(icon: Icon(Icons.close), onPressed: _clearSelection)
            : BackButton(),
        actions: [
          if (!_isSelectionMode && _isVideo)
            IconButton(
              icon: Icon(_isAudioMode ? Icons.videocam : Icons.headphones),
              onPressed: () => setState(() => _isAudioMode = !_isAudioMode),
            ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _isVideo
                    ? _buildVideoHeader(isDark)
                    : _buildTtsHeader(isDark, textColor),
                Expanded(
                  child: _isSentenceMode
                      ? _buildSentenceModeView(isDark, textColor)
                      : _buildParagraphModeView(isDark),
                ),
              ],
            ),

            if (!_isSelectionMode)
              Positioned(
                bottom: 24,
                right: 24,
                child: Material(
                  color: Colors.transparent,
                  elevation: 10,
                  shadowColor: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(30),
                  child: InkWell(
                    onTap: _toggleSentenceMode,
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Color(0xFF2C2C2C).withOpacity(0.9)
                            : Colors.black.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isSentenceMode ? Icons.notes : Icons.short_text,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            _isSentenceMode ? 'All' : 'Chunks',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildParagraphModeView(bool isDark) {
    final hasTranscript = widget.lesson.transcript.isNotEmpty;
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasTranscript)
            ...widget.lesson.transcript.asMap().entries.map((entry) {
              final index = entry.key;
              final line = entry.value;
              final isActive = index == _activeSentenceIndex;
              return _buildTranscriptRow(
                index,
                line.text,
                line.start,
                isActive,
                isDark,
              );
            }).toList()
          else
            ...widget.lesson.sentences.asMap().entries.map((entry) {
              final index = entry.key;
              final sentence = entry.value;
              final isActive = index == _activeSentenceIndex;
              return _buildTextRow(index, sentence, isActive, isDark);
            }).toList(),
          SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildSentenceModeView(bool isDark, Color? textColor) {
    final count = widget.lesson.transcript.isNotEmpty
        ? widget.lesson.transcript.length
        : widget.lesson.sentences.length;

    if (count == 0) return Center(child: Text("No content"));

    if (_activeSentenceIndex < 0) _activeSentenceIndex = 0;
    if (_activeSentenceIndex >= count) _activeSentenceIndex = count - 1;

    String currentText = "";
    if (widget.lesson.transcript.isNotEmpty) {
      currentText = widget.lesson.transcript[_activeSentenceIndex].text;
    } else {
      currentText = widget.lesson.sentences[_activeSentenceIndex];
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Text(
                "${_activeSentenceIndex + 1}",
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: RoundSliderOverlayShape(overlayRadius: 0),
                    activeTrackColor: Colors.blue,
                    inactiveTrackColor: isDark
                        ? Colors.grey[800]
                        : Colors.grey[200],
                    thumbColor: Colors.blue,
                  ),
                  child: Slider(
                    value: _activeSentenceIndex.toDouble(),
                    min: 0,
                    max: (count - 1).toDouble() < 0
                        ? 0
                        : (count - 1).toDouble(),
                    onChanged: (val) {
                      setState(() => _activeSentenceIndex = val.toInt());
                      _playCurrentSentenceInMode();
                    },
                  ),
                ),
              ),
              Text(
                "$count",
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity! < 0) {
                _nextSentence();
              } else if (details.primaryVelocity! > 0) {
                _prevSentence();
              }
            },
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity! < 0) {
                _nextSentence();
              } else if (details.primaryVelocity! > 0) {
                _prevSentence();
              }
            },
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 24),
              alignment: Alignment.center,
              child: SingleChildScrollView(
                child: _buildSentence(currentText, _activeSentenceIndex),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Text(
            "Swipe UP for next • DOWN for previous",
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildTranscriptRow(
    int index,
    String text,
    double startTime,
    bool isActive,
    bool isDark,
  ) {
    return Container(
      key: _itemKeys[index],
      margin: EdgeInsets.only(bottom: 12),
      padding: isActive ? EdgeInsets.all(12) : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: isActive
            ? (isDark ? Colors.white10 : Colors.grey[100])
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isVideo)
            GestureDetector(
              onTap: () => _seekToTime(startTime),
              child: Padding(
                padding: EdgeInsets.only(top: 4, right: 12),
                child: Icon(
                  isActive ? Icons.play_arrow : Icons.play_arrow_outlined,
                  color: isActive ? Colors.blue : Colors.grey[400],
                  size: 24,
                ),
              ),
            ),
          Expanded(
            child: GestureDetector(
              onLongPress: () =>
                  _showLingQDialog("sentence_$index", text, isPhrase: true),
              onDoubleTap: () =>
                  !_isSelectionMode && _isVideo ? _seekToTime(startTime) : null,
              child: _buildSentence(text, index),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextRow(int index, String sentence, bool isActive, bool isDark) {
    return GestureDetector(
      onLongPress: () =>
          _showLingQDialog("sentence_$index", sentence, isPhrase: true),
      onDoubleTap: () => _speakSentence(sentence, index),
      child: Container(
        key: _itemKeys[index],
        margin: EdgeInsets.only(bottom: 24),
        padding: isActive ? EdgeInsets.all(12) : EdgeInsets.zero,
        decoration: BoxDecoration(
          color: isActive ? Colors.yellow.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: _buildSentence(sentence, index),
      ),
    );
  }

  Widget _buildSentence(String sentence, int sentenceIndex) {
    final words = sentence.split(RegExp(r'(\s+)'));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double fontSize = _isSentenceMode ? 26 : 18;
    final double lineHeight = _isSentenceMode ? 1.6 : 1.5;

    return Wrap(
      spacing: 0,
      runSpacing: _isSentenceMode ? 12 : 6,
      alignment: _isSentenceMode ? WrapAlignment.center : WrapAlignment.start,
      children: words.asMap().entries.map((entry) {
        final int wordIndex = entry.key;
        final String word = entry.value;
        final cleanWord = word.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
        final GlobalKey wordKey = _getWordKey(sentenceIndex, wordIndex);

        if (cleanWord.isEmpty || word.trim().isEmpty) {
          return Container(
            key: wordKey,
            padding: EdgeInsets.symmetric(horizontal: 2, vertical: 1),
            child: Text(
              word,
              style: TextStyle(
                fontSize: fontSize,
                height: lineHeight,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          );
        }

        bool isSelected = false;
        if (_isSelectionMode && _selectionSentenceIndex == sentenceIndex) {
          int start = _selectionStartIndex < _selectionEndIndex
              ? _selectionStartIndex
              : _selectionEndIndex;
          int end = _selectionStartIndex < _selectionEndIndex
              ? _selectionEndIndex
              : _selectionStartIndex;

          if (wordIndex >= start && wordIndex <= end) {
            isSelected = true;
          }
        }

        final vocabItem = _vocabulary[cleanWord];
        Color bgColor = _getWordColor(vocabItem);
        Color textColor;

        if (isSelected) {
          bgColor = Colors.purple.withOpacity(0.3);
          textColor = Colors.white;
        } else if (vocabItem == null || vocabItem.status == 0) {
          textColor = isDark ? Colors.white : Colors.black87;
        } else if (vocabItem.status == 5) {
          textColor = isDark ? Colors.white : Colors.black87;
        } else {
          textColor = Colors.black87;
        }

        return GestureDetector(
          key: wordKey,
          behavior: HitTestBehavior.translucent,
          onLongPressStart: (_) => _startSelection(sentenceIndex, wordIndex),
          onLongPressMoveUpdate: (details) => _handleDragUpdate(
            sentenceIndex,
            words.length,
            details.globalPosition,
          ),
          onLongPressEnd: (_) => _finishSelection(sentence),
          onTap: () {
            if (_isSelectionMode) {
              _clearSelection();
            } else {
              _onWordTap(cleanWord, word);
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(4),
              border: isSelected
                  ? Border.all(color: Colors.purple.withOpacity(0.5), width: 1)
                  : null,
            ),
            padding: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Text(
              word,
              style: TextStyle(
                fontSize: fontSize,
                height: lineHeight,
                color: textColor,
                fontFamily: 'Roboto',
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _onWordTap(String cleanWord, String originalWord) {
    if (_isTtsPlaying) _flutterTts.stop();
    _showLingQDialog(cleanWord, originalWord, isPhrase: false);
  }

  Widget _buildVideoHeader(bool isDark) {
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
        if (_isAudioMode) _buildAudioPlayerUI(isDark),
      ],
    );
  }

  Widget _buildAudioPlayerUI(bool isDark) {
    return Container(
      color: isDark ? Color(0xFF1E1E1E) : Colors.grey[100],
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          IconButton(
            iconSize: 42,
            icon: Icon(
              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
              color: Colors.blue,
            ),
            onPressed: () => _isPlaying
                ? _videoController!.pause()
                : _videoController!.play(),
          ),
          SizedBox(width: 8),
          Text(
            "Audio Mode",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
          ),
        ],
      ),
    );
  }

  Widget _buildTtsHeader(bool isDark, Color? textColor) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.blue,
            child: IconButton(
              icon: Icon(
                _isTtsPlaying ? Icons.stop : Icons.play_arrow,
                color: Colors.white,
              ),
              onPressed: _toggleTtsFullLesson,
            ),
          ),
          SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Audio Lesson",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: textColor,
                ),
              ),
              Text(
                "Long press sentence to translate",
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- DIALOG ---
  void _showLingQDialog(
    String cleanId,
    String originalText, {
    required bool isPhrase,
  }) {
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    final translationService = context.read<TranslationService>();
    VocabularyItem? existingItem = isPhrase ? null : _vocabulary[cleanId];

    if (_isVideo &&
        _videoController != null &&
        _videoController!.value.isPlaying) {
      _videoController!.pause();
    }

    Future<String> translationFuture;
    if (existingItem != null) {
      translationFuture = Future.value(existingItem.translation);
    } else {
      translationFuture = translationService
          .translate(originalText, user.nativeLanguage, widget.lesson.language)
          .catchError((e) => "Translation unavailable");
    }

    final geminiPrompt = isPhrase
    ? "Translate this ${user.currentLanguage} phrase to ${user.nativeLanguage}: \"$originalText\"\n"
      "Provide:\n"
      "1. Translation (concise)\n"
      "2. Key grammar point (1-2 sentences)"
    : "Translate this ${user.currentLanguage} word to ${user.nativeLanguage}: \"$originalText\"\n"
      "Provide:\n"
      "1. Most common translation\n"
      "2. Brief usage context (one example)";

    final Future<String?> geminiFuture = Gemini.instance
        .prompt(parts: [Part.text(geminiPrompt)])
        .then((value) => value?.output)
        .catchError((e) => "Gemini unavailable");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return TranslationSheet(
          originalText: originalText,
          translationFuture: translationFuture,
          geminiFuture: geminiFuture,
          isPhrase: isPhrase,
          existingItem: existingItem,
          targetLanguage: widget.lesson.language,
          // sourceLanguage: widget.lesson.language,
          nativeLanguage: user.nativeLanguage,
          onSpeak: () => _flutterTts.speak(originalText),
          onUpdateStatus: (status, translation) =>
              _updateWordStatus(cleanId, originalText, translation, status),
          onSaveToFirebase: () => _saveWordToFirebase(originalText),
          onClose: () => Navigator.pop(context),
        );
      },
    ).then((_) {
      _clearSelection();
    });
  }

  void _saveWordToFirebase(String word) async {
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .collection('saved_words')
          .add({
            'word': word,
            'added_at': FieldValue.serverTimestamp(),
            'source_lesson': widget.lesson.id,
          });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Saved to your list!")));
    } catch (e) {
      print("Error saving word: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving: Check console rules")),
      );
    }
  }

  // *** FIXED FUNCTION WITH FIREBASE PERSISTENCE ***
  Future<void> _updateWordStatus(
    String cleanWord,
    String originalWord,
    String translation,
    int status, {
    bool showDialog = true,
  }) async {
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    VocabularyItem? existingItem = _vocabulary[cleanWord];
    VocabularyItem newItem;

    // 1. Prepare Data
    if (existingItem != null) {
      newItem = existingItem.copyWith(
        status: status,
        translation: translation.isNotEmpty ? translation : existingItem.translation,
        timesEncountered: existingItem.timesEncountered + 1,
        lastReviewed: DateTime.now(),
      );
    } else {
      newItem = VocabularyItem(
        id: cleanWord, // Using word as ID
        userId: user.id,
        word: cleanWord,
        baseForm: cleanWord,
        language: widget.lesson.language,
        translation: translation,
        status: status,
        timesEncountered: 1,
        lastReviewed: DateTime.now(),
        createdAt: DateTime.now(),
      );
    }

    // 2. Update Local State (Immediate Feedback)
    setState(() => _vocabulary[cleanWord] = newItem);

    // 3. Update Bloc (for other screens)
    if (existingItem != null) {
      context.read<VocabularyBloc>().add(VocabularyUpdateRequested(newItem));
    } else {
      context.read<VocabularyBloc>().add(VocabularyAddRequested(newItem));
    }

    // 4. *** PERSIST TO FIREBASE *** (This was missing or incomplete)
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .collection('vocabulary')
          .doc(cleanWord) // docId = word ensures uniqueness
          .set({
            'id': cleanWord,
            'userId': user.id,
            'word': cleanWord,
            'baseForm': cleanWord,
            'language': widget.lesson.language,
            'translation': translation,
            'status': status,
            'timesEncountered': newItem.timesEncountered,
            'lastReviewed': FieldValue.serverTimestamp(),
            'createdAt': existingItem != null ? existingItem.createdAt : FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)); 
    } catch (e) {
      print("Error saving ranking to Firestore: $e");
      // Optionally show error snackbar here
    }

    if (showDialog) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Word status updated"),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
