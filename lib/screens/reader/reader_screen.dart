import 'dart:io';
import 'package:flutter/gestures.dart'; // Added for RichText span handling
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
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
  // TODO: Secure your API key in a real app
  final String _geminiApiKey = "AIzaSyAnRFZpp5Cogg-O_YwVS2Ztx19-mElq6q8";

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

  // Maps sentenceIndex -> List of GlobalKeys for each word
  final Map<int, List<GlobalKey>> _wordKeys = {};

  @override
  void initState() {
    super.initState();
    try {
      Gemini.init(apiKey: _geminiApiKey);
    } catch (e) {
      // Handle init error if necessary
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
    _videoController?.removeListener(_videoListener);
    _videoController?.dispose();
    _flutterTts.stop();
    super.dispose();
  }

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

  // --- COLOR LOGIC ---
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

  // --- DRAG SELECTION LOGIC ---
  void _handleDragUpdate(int sentenceIndex, Offset globalPosition) {
    final keys = _wordKeys[sentenceIndex];
    if (keys == null) return;

    for (int i = 0; i < keys.length; i++) {
      final key = keys[i];
      final context = key.currentContext;
      if (context == null) continue;

      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final localPosition = renderBox.globalToLocal(globalPosition);
        final size = renderBox.size;

        // Expanded hit test for easier selection
        if (localPosition.dx >= -10 &&
            localPosition.dx <= size.width + 10 &&
            localPosition.dy >= -10 &&
            localPosition.dy <= size.height + 10) {
          if (_selectionEndIndex != i) {
            setState(() {
              if (_selectionStartIndex == -1) _selectionStartIndex = i;
              _selectionEndIndex = i;
            });
          }
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
    final phrase = sublist.join("");
    final cleanId = phrase.toLowerCase().trim().replaceAll(
      RegExp(r'[^\w\s]'),
      '',
    );
    final originalText = phrase.trim();

    _showCombinedDialog(cleanId, originalText, isPhrase: true);
  }

  void _clearSelection() {
    setState(() {
      _isSelectionMode = false;
      _selectionSentenceIndex = -1;
      _selectionStartIndex = -1;
      _selectionEndIndex = -1;
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
    int newIndex = -1;

    for (int i = 0; i < widget.lesson.transcript.length; i++) {
      final line = widget.lesson.transcript[i];
      if (currentSeconds >= line.start && currentSeconds < line.end) {
        newIndex = i;
        break;
      }
    }

    if (!_isSelectionMode &&
        newIndex != -1 &&
        newIndex != _activeSentenceIndex) {
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

  @override
  Widget build(BuildContext context) {
    final bool hasTranscript = widget.lesson.transcript.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: _isSelectionMode
            ? Text(
                "Release to Translate Phrase",
                style: TextStyle(color: Colors.white, fontSize: 16),
              )
            : Text(
                widget.lesson.title,
                style: TextStyle(color: Colors.black, fontSize: 16),
              ),
        backgroundColor: _isSelectionMode ? Colors.purple : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(
          color: _isSelectionMode ? Colors.white : Colors.black,
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
      body: Column(
        children: [
          _isVideo ? _buildVideoHeader() : _buildTtsHeader(),
          Expanded(
            child: SingleChildScrollView(
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
                      );
                    }).toList()
                  else
                    ...widget.lesson.sentences.asMap().entries.map((entry) {
                      final index = entry.key;
                      final sentence = entry.value;
                      final isActive = index == _activeSentenceIndex;
                      return _buildTextRow(index, sentence, isActive);
                    }).toList(),
                  SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Wrapper for Video Transcripts
  Widget _buildTranscriptRow(
    int index,
    String text,
    double startTime,
    bool isActive,
  ) {
    return Container(
      key: _itemKeys[index],
      margin: EdgeInsets.only(bottom: 12),
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
              // NEW: Long press the sentence area to translate the WHOLE sentence
              onLongPress: () =>
                  _showCombinedDialog("sentence_$index", text, isPhrase: true),
              onDoubleTap: () =>
                  !_isSelectionMode && _isVideo ? _seekToTime(startTime) : null,
              child: _buildSentence(text, index),
            ),
          ),
        ],
      ),
    );
  }

  // Wrapper for Text-Only Lessons
  Widget _buildTextRow(int index, String sentence, bool isActive) {
    return GestureDetector(
      // NEW: Long press the sentence area to translate the WHOLE sentence
      onLongPress: () =>
          _showCombinedDialog("sentence_$index", sentence, isPhrase: true),
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

  // --- WORD BUILDER ---
  Widget _buildSentence(String sentence, int sentenceIndex) {
    _wordKeys[sentenceIndex] = [];
    final words = sentence.split(RegExp(r'(\s+)'));

    return Wrap(
      spacing: 0,
      runSpacing: 6,
      children: words.asMap().entries.map((entry) {
        final int wordIndex = entry.key;
        final String word = entry.value;
        final cleanWord = word.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
        final GlobalKey wordKey = GlobalKey();
        _wordKeys[sentenceIndex]!.add(wordKey);

        if (cleanWord.isEmpty || word.trim().isEmpty) {
          return Text(
            word,
            style: TextStyle(fontSize: 18, height: 1.5, color: Colors.black87),
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
          if (wordIndex >= start && wordIndex <= end) isSelected = true;
        }

        final vocabItem = _vocabulary[cleanWord];
        Color bgColor = isSelected
            ? Colors.purple.withOpacity(0.3)
            : _getWordColor(vocabItem);

        return GestureDetector(
          key: wordKey,
          behavior: HitTestBehavior.translucent,
          // 1. Start Phrase Selection
          onLongPressStart: (_) => _startSelection(sentenceIndex, wordIndex),
          // 2. Drag to expand Selection
          onLongPressMoveUpdate: (details) =>
              _handleDragUpdate(sentenceIndex, details.globalPosition),
          // 3. Finish Phrase Selection
          onLongPressEnd: (_) => _finishSelection(sentence),
          // 4. Tap single word
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
                  ? Border.all(color: Colors.purple, width: 1.5)
                  : null,
            ),
            padding: EdgeInsets.symmetric(horizontal: 1, vertical: 1),
            child: Text(
              word,
              style: TextStyle(
                fontSize: 18,
                height: 1.5,
                color: Colors.black87,
                fontFamily: 'Roboto',
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

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

  Widget _buildTtsHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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

  void _onWordTap(String cleanWord, String originalWord) {
    if (_isTtsPlaying) _flutterTts.stop();
    _showCombinedDialog(cleanWord, originalWord, isPhrase: false);
  }

  // --- DUAL TRANSLATION DIALOG ---
  void _showCombinedDialog(
    String cleanId,
    String originalText, {
    required bool isPhrase,
  }) async {
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    final translationService = context.read<TranslationService>();

    VocabularyItem? existingItem = isPhrase ? null : _vocabulary[cleanId];

    bool resumeVideoAfter = false;
    if (_isVideo &&
        _videoController != null &&
        _videoController!.value.isPlaying) {
      _videoController!.pause();
      resumeVideoAfter = true;
    }

    String standardTranslation = existingItem?.translation ?? 'Loading...';
    String geminiTranslation = 'Loading...';

    if (existingItem == null) {
      translationService
          .translate(originalText, user.nativeLanguage, widget.lesson.language)
          .then((val) {
            standardTranslation = val;
          })
          .catchError((_) {
            standardTranslation = "Failed to translate";
          });
    }

    // Prompt for Gemini
    final geminiPrompt = isPhrase
        ? "Translate this sentence/phrase to ${user.nativeLanguage}. Explain any grammar or idiom nuances briefly. Text: \"$originalText\""
        : "Translate word '$originalText' to ${user.nativeLanguage}. Give context.";

    Gemini.instance
        .prompt(parts: [Part.text(geminiPrompt)])
        .then((value) {
          geminiTranslation = value?.output ?? "No output from Gemini";
        })
        .catchError((e) {
          geminiTranslation = "Gemini Error: $e";
        });

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          if (standardTranslation == 'Loading...' ||
              geminiTranslation == 'Loading...') {
            Future.delayed(Duration(milliseconds: 500), () {
              if (context.mounted) setModalState(() {});
            });
          }

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.all(24),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          originalText,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.volume_up, color: Colors.blue),
                        onPressed: () => _flutterTts.speak(originalText),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Standard Translation Box
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "STANDARD TRANSLATION",
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          standardTranslation,
                          style: TextStyle(fontSize: 16, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 12),

                  // Gemini Translation Box with Formatting
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.purple[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 14,
                              color: Colors.purple,
                            ),
                            SizedBox(width: 4),
                            Text(
                              "GEMINI AI",
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.purple,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        // REPLACED Text() with GeminiFormattedText to handle asterisks
                        GeminiFormattedText(text: geminiTranslation),
                      ],
                    ),
                  ),

                  SizedBox(height: 24),

                  if (!isPhrase)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _StatusButton(
                          label: 'New',
                          status: 0,
                          color: Colors.blue,
                          onTap: () => _updateWordStatus(
                            cleanId,
                            originalText,
                            standardTranslation,
                            0,
                          ),
                        ),
                        _StatusButton(
                          label: '1',
                          status: 1,
                          color: Colors.yellow[700]!,
                          onTap: () => _updateWordStatus(
                            cleanId,
                            originalText,
                            standardTranslation,
                            1,
                          ),
                        ),
                        _StatusButton(
                          label: '2',
                          status: 2,
                          color: Colors.orange[600]!,
                          onTap: () => _updateWordStatus(
                            cleanId,
                            originalText,
                            standardTranslation,
                            2,
                          ),
                        ),
                        _StatusButton(
                          label: '3',
                          status: 3,
                          color: Colors.orange[700]!,
                          onTap: () => _updateWordStatus(
                            cleanId,
                            originalText,
                            standardTranslation,
                            3,
                          ),
                        ),
                        _StatusButton(
                          label: 'Known',
                          status: 5,
                          color: Colors.green,
                          onTap: () => _updateWordStatus(
                            cleanId,
                            originalText,
                            standardTranslation,
                            5,
                          ),
                        ),
                      ],
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text("Close"),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    ).then((_) {
      _clearSelection();
    });

    if (resumeVideoAfter && _isVideo && _videoController != null) {
      _videoController!.play();
    }
  }

  void _updateWordStatus(
    String cleanWord,
    String originalWord,
    String translation,
    int status,
  ) {
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    VocabularyItem? existingItem = _vocabulary[cleanWord];

    if (existingItem != null) {
      final updatedItem = existingItem.copyWith(
        status: status,
        timesEncountered: existingItem.timesEncountered + 1,
      );
      context.read<VocabularyBloc>().add(
        VocabularyUpdateRequested(updatedItem),
      );
      setState(() => _vocabulary[cleanWord] = updatedItem);
    } else {
      final newItem = VocabularyItem(
        id: '',
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
  const _StatusButton({
    required this.label,
    required this.status,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 55,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
          minimumSize: Size(50, 36),
        ),
        child: Text(label, style: TextStyle(fontSize: 12)),
      ),
    );
  }
}

/// Custom Widget to Parse Gemini's Markdown-like syntax
/// Handles **bold text** and * lists without needing an HTML or Markdown package.
class GeminiFormattedText extends StatelessWidget {
  final String text;

  const GeminiFormattedText({Key? key, required this.text}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (text == "Loading..." || text.startsWith("Gemini Error")) {
      return Text(text, style: TextStyle(color: Colors.black54));
    }

    List<Widget> children = [];

    // Split lines to handle bullets separately
    List<String> lines = text.split('\n');

    for (String line in lines) {
      if (line.trim().isEmpty) {
        children.add(SizedBox(height: 8)); // Paragraph spacing
        continue;
      }

      // Handle Bullet points (lines starting with *)
      if (line.trim().startsWith('* ')) {
        children.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "• ",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Expanded(child: _parseRichText(line.trim().substring(2))),
            ],
          ),
        );
      } else {
        children.add(_parseRichText(line));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  // Parses **bold** inside a line
  Widget _parseRichText(String text) {
    List<TextSpan> spans = [];

    // Split by **
    List<String> parts = text.split('**');

    for (int i = 0; i < parts.length; i++) {
      // Even parts are normal, Odd parts are bold (because split occurs at **)
      if (i % 2 == 0) {
        spans.add(
          TextSpan(
            text: parts[i],
            style: TextStyle(color: Colors.black87, fontSize: 15, height: 1.4),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: parts[i],
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 15,
              height: 1.4,
            ),
          ),
        );
      }
    }

    return RichText(text: TextSpan(children: spans));
  }
}
