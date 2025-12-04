import 'dart:async';
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
import 'package:linguaflow/screens/reader/widgets/reader_top_bar.dart';
import 'package:linguaflow/services/translation_service.dart';
import 'package:linguaflow/services/vocabulary_service.dart';
import 'package:linguaflow/widgets/translation_sheet.dart'; 
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

// NOTE: ReaderTopBar and ReaderModeToggleButton are defined at the bottom of this file

class ReaderScreen extends StatefulWidget {
  final LessonModel lesson;

  const ReaderScreen({super.key, required this.lesson});

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
  final double _ttsSpeed = 0.5;

  // --- SYNC & SCROLL STATE ---
  int _activeSentenceIndex = -1;
  final List<GlobalKey> _itemKeys = [];

  // --- SMART CHUNKING STATE ---
  List<String> _smartChunks = []; 
  List<int> _chunkToTranscriptMap = []; 

  // --- PAGINATION STATE (For Text Mode) ---
  final PageController _pageController = PageController();
  List<List<int>> _bookPages = []; 
  int _currentPage = 0;
  final int _wordsPerPage = 100; 

  // --- SELECTION STATE ---
  bool _isSelectionMode = false;
  int _selectionSentenceIndex = -1;
  int _selectionStartIndex = -1;
  int _selectionEndIndex = -1;

  // --- SENTENCE MODE STATE ---
  bool _isSentenceMode = false;
  bool _hasShownSwipeHint = false;
  String? _currentSentenceTranslation;

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
    
    _generateSmartChunks();

    final maxCount = (_smartChunks.length > widget.lesson.sentences.length) 
        ? _smartChunks.length 
        : widget.lesson.sentences.length;
        
    for (var i = 0; i < maxCount + 50; i++) { 
      _itemKeys.add(GlobalKey());
    }

    if (widget.lesson.transcript.isEmpty) {
      _prepareBookPages();
    }

    if (widget.lesson.type == 'video' || widget.lesson.videoUrl != null) {
      _initializeVideoPlayer();
    } else {
      _initializeTts();
    }
  }

  void _generateSmartChunks() {
    _smartChunks = [];
    _chunkToTranscriptMap = [];

    if (widget.lesson.transcript.isNotEmpty) {
      for (int i = 0; i < widget.lesson.transcript.length; i++) {
        _smartChunks.add(widget.lesson.transcript[i].text);
        _chunkToTranscriptMap.add(i);
      }
      return;
    }

    List<String> rawSentences = widget.lesson.sentences;
    if (rawSentences.isEmpty) {
      rawSentences = widget.lesson.content.split(RegExp(r'(?<=[.!?])\s+'));
    }

    for (int i = 0; i < rawSentences.length; i++) {
      String sentence = rawSentences[i];
      if (sentence.split(' ').length > 15) {
        List<String> parts = sentence.split(RegExp(r'(?<=[,;:])\s+'));
        for (String part in parts) {
          if (part.trim().isNotEmpty) {
            _smartChunks.add(part.trim());
            _chunkToTranscriptMap.add(i);
          }
        }
      } else {
        if (sentence.trim().isNotEmpty) {
          _smartChunks.add(sentence.trim());
          _chunkToTranscriptMap.add(i);
        }
      }
    }
  }

  void _prepareBookPages() {
    _bookPages = [];
    List<int> currentPageIndices = [];
    int currentWordCount = 0;

    for (int i = 0; i < widget.lesson.sentences.length; i++) {
      String s = widget.lesson.sentences[i];
      int wordCount = s.split(' ').length;

      if (currentWordCount + wordCount > _wordsPerPage && currentPageIndices.isNotEmpty) {
        _bookPages.add(currentPageIndices);
        currentPageIndices = [];
        currentWordCount = 0;
      }

      currentPageIndices.add(i);
      currentWordCount += wordCount;
    }

    if (currentPageIndices.isNotEmpty) {
      _bookPages.add(currentPageIndices);
    }
  }

  @override
  void dispose() {
    try {
      _videoController?.removeListener(_videoListener);
    } catch (_) {}
    _videoController?.dispose();
    _pageController.dispose();
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

  String _generateCleanId(String text) {
    return text.toLowerCase().trim().replaceAll(RegExp(r'[^\w\s]'), '');
  }

  DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  Future<void> _loadVocabulary() async {
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
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
          word: data['word']?.toString() ?? doc.id,
          baseForm: data['baseForm']?.toString() ?? doc.id,
          language: data['language']?.toString() ?? '',
          translation: data['translation']?.toString() ?? '',
          status: (data['status'] is int) ? data['status'] : 0,
          timesEncountered: (data['timesEncountered'] is int) ? data['timesEncountered'] : 1,
          lastReviewed: _parseDateTime(data['lastReviewed']),
          createdAt: _parseDateTime(data['createdAt']),
        );
      }
      if (mounted) setState(() => _vocabulary = loadedVocab);
    } catch (e) {
      print("Error loading vocabulary: $e");
      try {
        final vocabService = context.read<VocabularyService>();
        final items = await vocabService.getVocabulary(user.id);
        if (mounted) setState(() => _vocabulary = {for (var item in items) item.word.toLowerCase(): item});
      } catch (_) {}
    }
  }

  Color _getWordColor(VocabularyItem? item) {
    if (item == null || item.status == 0) return Colors.blue.withOpacity(0.15); 
    switch (item.status) {
      case 1: return Color(0xFFFFF9C4); 
      case 2: return Color(0xFFFFF59D); 
      case 3: return Color(0xFFFFCC80); 
      case 4: return Color(0xFFFFB74D); 
      case 5: return Colors.transparent; 
      default: return Colors.transparent;
    }
  }

  // --- SELECTION LOGIC ---
  void _handleDragUpdate(int sentenceIndex, int maxWords, Offset globalPosition) {
    for (int i = 0; i < maxWords; i++) {
      final key = _getWordKey(sentenceIndex, i);
      final context = key.currentContext;
      if (context != null) {
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          final rect = (renderBox.localToGlobal(Offset.zero) & renderBox.size).inflate(10.0);
          if (rect.contains(globalPosition)) {
            if (_selectionEndIndex != i) setState(() => _selectionEndIndex = i);
            return;
          }
        }
      }
    }
  }

  void _finishSelection(String fullSentence) {
    if (_selectionStartIndex == -1 || _selectionEndIndex == -1) { _clearSelection(); return; }
    final start = _selectionStartIndex < _selectionEndIndex ? _selectionStartIndex : _selectionEndIndex;
    final end = _selectionStartIndex < _selectionEndIndex ? _selectionEndIndex : _selectionStartIndex;
    final words = fullSentence.split(RegExp(r'(\s+)'));
    if (start < 0 || end >= words.length) { _clearSelection(); return; }
    final phrase = words.sublist(start, end + 1).join(" ");
    _showLingQDialog(_generateCleanId(phrase), phrase.trim(), isPhrase: words.sublist(start, end + 1).length > 1);
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
    if (_isVideo) _videoController?.pause();
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
    if (widget.lesson.id.startsWith('yt_')) videoId = widget.lesson.id.replaceAll('yt_', '');
    else if (widget.lesson.videoUrl != null) videoId = YoutubePlayer.convertUrlToId(widget.lesson.videoUrl!);

    if (videoId != null) {
      _isVideo = true;
      _videoController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(autoPlay: false, mute: false, enableCaption: false),
      );
      _videoController!.addListener(_videoListener);
    }
  }

  void _videoListener() {
    if (_videoController == null) return;
    if (_videoController!.value.isPlaying != _isPlaying) setState(() => _isPlaying = _videoController!.value.isPlaying);
    if (widget.lesson.transcript.isEmpty) return;
    
    final currentSeconds = _videoController!.value.position.inMilliseconds / 1000;
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
        setState(() {
          _activeSentenceIndex = realTimeIndex;
          _currentSentenceTranslation = null;
        });
      }
      if (_activeSentenceIndex >= 0 && _activeSentenceIndex < widget.lesson.transcript.length) {
        final activeLine = widget.lesson.transcript[_activeSentenceIndex];
        if (_isPlaying && currentSeconds >= activeLine.end && currentSeconds < activeLine.end + 0.5) {
          if (realTimeIndex == _activeSentenceIndex) _videoController!.pause();
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
    if (!_isSentenceMode && index < _itemKeys.length && _itemKeys[index].currentContext != null) {
      Scrollable.ensureVisible(_itemKeys[index].currentContext!, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut, alignment: 0.5);
    }
  }

  void _seekToTime(double seconds) {
    if (_videoController != null) {
      _videoController!.seekTo(Duration(milliseconds: (seconds * 1000).toInt()));
      _videoController!.play();
    }
  }

  void _initializeTts() async {
    await _flutterTts.setLanguage(widget.lesson.language);
    await _flutterTts.setSpeechRate(_ttsSpeed);
    
    _flutterTts.setCompletionHandler(() {
      // If we are in Chunk Mode, we stop after one chunk.
      if (_isSentenceMode) {
        setState(() => _isTtsPlaying = false);
      } 
      // If we are in Paragraph Mode, we Auto-Advance to next sentence.
      else {
        if (_activeSentenceIndex < widget.lesson.sentences.length - 1) {
          // Play next
          int nextIndex = _activeSentenceIndex + 1;
          // Check if next sentence is on a new page, if so flip page
          if (_bookPages.isNotEmpty) {
             // Calculate which page the next sentence belongs to
             for(int i=0; i<_bookPages.length; i++) {
               if (_bookPages[i].contains(nextIndex)) {
                 if(_currentPage != i) {
                   _pageController.jumpToPage(i);
                   setState(() => _currentPage = i);
                 }
                 break;
               }
             }
          }
          _speakSentence(widget.lesson.sentences[nextIndex], nextIndex);
        } else {
          // End of lesson
          setState(() {
             _isTtsPlaying = false;
             _activeSentenceIndex = -1;
          });
        }
      }
    });
  }

  Future<void> _speakSentence(String text, int index) async {
    setState(() {
      _activeSentenceIndex = index;
      _isTtsPlaying = true;
      _currentSentenceTranslation = null;
    });
    
    // Scroll to active sentence in paragraph mode
    if (!_isSentenceMode && !_isVideo) {
       _scrollToActiveLine(index);
    }
    
    await _flutterTts.speak(text);
  }

  Future<void> _stopTts() async {
    await _flutterTts.stop();
    setState(() => _isTtsPlaying = false);
  }

  Future<void> _toggleTtsFullLesson() async {
    if (_isTtsPlaying) {
      await _stopTts();
    } else {
      int startIndex = _activeSentenceIndex == -1 ? 0 : _activeSentenceIndex;
      if(startIndex >= widget.lesson.sentences.length) startIndex = 0;
      
      _speakSentence(widget.lesson.sentences[startIndex], startIndex);
    }
  }

  void _toggleSentenceMode() {
    if(_isVideo) _videoController?.pause();
    if(_isTtsPlaying) _stopTts();

    setState(() {
      _isSentenceMode = !_isSentenceMode;
      if (_activeSentenceIndex == -1 || _activeSentenceIndex >= _smartChunks.length) {
        _activeSentenceIndex = 0;
      }
      _currentSentenceTranslation = null;
    });
  }

  void _togglePlaybackInMode() {
    if (_isVideo && _videoController != null) {
      if (_isPlaying) {
        _videoController!.pause();
      } else {
        _videoController!.play();
      }
    } else {
      if (_isTtsPlaying) {
        _stopTts();
      } else {
        _playCurrentSentenceInMode();
      }
    }
  }

  void _handleSwipeMarking(int leavingIndex) {
    if (leavingIndex < 0 || leavingIndex >= _smartChunks.length) return;
    String sentenceText = _smartChunks[leavingIndex];
    if (sentenceText.isEmpty) return;

    final words = sentenceText.split(RegExp(r'(\s+)'));
    bool markedAny = false;

    for (var word in words) {
      final clean = _generateCleanId(word);
      if (clean.isEmpty) continue;
      final item = _vocabulary[clean];
      if (item == null || item.status == 0) {
        _updateWordStatus(clean, word.trim(), "", 5, showDialog: false);
        markedAny = true;
      }
    }

    if (markedAny && !_hasShownSwipeHint) {
      _hasShownSwipeHint = true;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Swiping marks blue words as known"), duration: Duration(seconds: 3), behavior: SnackBarBehavior.floating));
    }
  }

  void _nextSentence() {
    if (_activeSentenceIndex < _smartChunks.length - 1) {
      _handleSwipeMarking(_activeSentenceIndex);
      setState(() {
        _activeSentenceIndex++;
        _currentSentenceTranslation = null;
      });
    }
  }

  void _prevSentence() {
    if (_activeSentenceIndex > 0) {
      setState(() {
        _activeSentenceIndex--;
        _currentSentenceTranslation = null;
      });
    }
  }

  void _playCurrentSentenceInMode() {
    if (_activeSentenceIndex == -1) return;
    if (_isVideo && widget.lesson.transcript.isNotEmpty) {
      if (_activeSentenceIndex < widget.lesson.transcript.length) {
        final line = widget.lesson.transcript[_activeSentenceIndex];
        _seekToTime(line.start);
      }
    } else {
      if (_activeSentenceIndex < _smartChunks.length) {
        final chunk = _smartChunks[_activeSentenceIndex];
        _speakSentence(chunk, _activeSentenceIndex);
      }
    }
  }

  Future<void> _translateCurrentSentence() async {
    String text = "";
    if (_activeSentenceIndex < _smartChunks.length) text = _smartChunks[_activeSentenceIndex];
    if (text.isEmpty) return;

    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    final translationService = context.read<TranslationService>();

    try {
      final translated = await translationService.translate(text, user.nativeLanguage, widget.lesson.language);
      setState(() => _currentSentenceTranslation = translated);
    } catch (e) {
      setState(() => _currentSentenceTranslation = "Translation unavailable");
    }
  }

  void _onSliderChanged(double value) {
    if (_isSentenceMode || (_isVideo && widget.lesson.transcript.isNotEmpty)) {
      final newIndex = value.toInt();
      setState(() {
        _activeSentenceIndex = newIndex;
        _currentSentenceTranslation = null;
      });
    } else {
      final newPage = value.toInt();
      setState(() => _currentPage = newPage);
      _pageController.jumpToPage(newPage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    double sliderValue = 0.0;
    double sliderMax = 1.0;

    if (_isSentenceMode || (_isVideo && widget.lesson.transcript.isNotEmpty)) {
      final total = _smartChunks.length;
      sliderMax = (total > 0) ? (total - 1).toDouble() : 0.0;
      sliderValue = (_activeSentenceIndex >= 0) ? _activeSentenceIndex.toDouble() : 0.0;
    } else {
      final totalPages = _bookPages.length;
      sliderMax = (totalPages > 0) ? (totalPages - 1).toDouble() : 0.0;
      sliderValue = _currentPage.toDouble();
    }
    
    if (sliderValue > sliderMax) sliderValue = sliderMax;
    if (sliderValue < 0) sliderValue = 0;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: null, 
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // --- TOP BAR ---
                ReaderTopBar(
                  isDark: isDark,
                  isVideo: _isVideo,
                  title: widget.lesson.title,
                  sliderValue: sliderValue,
                  sliderMax: sliderMax,
                  onSliderChanged: _onSliderChanged,
                  onBackPressed: () => Navigator.pop(context),
                  // Show play button ONLY if NOT video and NOT Chunk mode
                  showPlayButton: !_isVideo && !_isSentenceMode,
                  isPlaying: _isTtsPlaying,
                  onPlayPressed: _toggleTtsFullLesson,
                ),

                if (_isVideo) _buildVideoHeader(isDark),

                Expanded(
                  child: _isSentenceMode
                      ? _buildSentenceModeView(isDark, textColor)
                      : _buildParagraphModeView(isDark),
                ),
              ],
            ),

            // --- FLOATING BUTTON ---
            if (!_isSelectionMode)
              Positioned(
                bottom: 24,
                right: 24,
                child: ReaderModeToggleButton(
                  isDark: isDark,
                  isSentenceMode: _isSentenceMode,
                  onToggle: _toggleSentenceMode,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildParagraphModeView(bool isDark) {
    if (widget.lesson.transcript.isNotEmpty) {
      return SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ...widget.lesson.transcript.asMap().entries.map((entry) {
            return _buildTranscriptRow(entry.key, entry.value.text, entry.value.start, entry.key == _activeSentenceIndex, isDark);
          }),
          SizedBox(height: 100),
        ]),
      );
    }
    if (_bookPages.isEmpty) return Center(child: CircularProgressIndicator());
    return PageView.builder(
      controller: _pageController, itemCount: _bookPages.length, onPageChanged: (index) => setState(() => _currentPage = index),
      itemBuilder: (context, pageIndex) {
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ..._bookPages[pageIndex].map((index) => _buildTextRow(index, widget.lesson.sentences[index], index == _activeSentenceIndex, isDark)).toList(),
            SizedBox(height: 100),
          ]),
        );
      },
    );
  }

  Widget _buildSentenceModeView(bool isDark, Color? textColor) {
    final count = _smartChunks.length;
    if (count == 0) return Center(child: Text("No content"));
    if (_activeSentenceIndex < 0) _activeSentenceIndex = 0;
    if (_activeSentenceIndex >= count) _activeSentenceIndex = count - 1;

    String currentText = _smartChunks[_activeSentenceIndex];

    return Column(
      children: [
        SizedBox(height: 40),
        Center(
          child: GestureDetector(
            onTap: _togglePlaybackInMode,
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.5), width: 2)),
              child: Icon(
                _isVideo 
                  ? (_isPlaying ? Icons.pause : Icons.play_arrow)
                  : (_isTtsPlaying ? Icons.stop : Icons.play_arrow),
                size: 40, color: isDark ? Colors.white : Colors.black87
              ),
            ),
          ),
        ),
        Spacer(),
        Expanded(
          flex: 3,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity! < 0) _nextSentence();
              else if (details.primaryVelocity! > 0) _prevSentence();
            },
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity! < 0) _nextSentence();
              else if (details.primaryVelocity! > 0) _prevSentence();
            },
            child: Container(
              width: double.infinity, padding: EdgeInsets.symmetric(horizontal: 24), alignment: Alignment.center,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildSentence(currentText, _activeSentenceIndex, isBigMode: true),
                    SizedBox(height: 24),
                    if (_currentSentenceTranslation == null)
                      TextButton.icon(icon: Icon(Icons.translate, size: 16, color: Colors.grey), label: Text("Translate Sentence", style: TextStyle(color: Colors.grey)), onPressed: _translateCurrentSentence)
                    else
                      Padding(padding: const EdgeInsets.all(8.0), child: Text(_currentSentenceTranslation!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[400], fontStyle: FontStyle.italic, fontSize: 16))),
                  ],
                ),
              ),
            ),
          ),
        ),
        Spacer(),
        Padding(padding: const EdgeInsets.only(bottom: 20), child: Text("Swipe LEFT/UP for next • RIGHT/DOWN for previous", style: TextStyle(color: Colors.grey, fontSize: 12))),
      ],
    );
  }

  // --- ROWS ---
  Widget _buildTranscriptRow(int index, String text, double startTime, bool isActive, bool isDark) {
    return Container(
      key: _itemKeys[index], margin: EdgeInsets.only(bottom: 12), padding: isActive ? EdgeInsets.all(12) : EdgeInsets.zero,
      decoration: BoxDecoration(color: isActive ? (isDark ? Colors.white10 : Colors.grey[100]) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_isVideo) GestureDetector(onTap: () => _seekToTime(startTime), child: Padding(padding: EdgeInsets.only(top: 4, right: 12), child: Icon(isActive ? Icons.play_arrow : Icons.play_arrow_outlined, color: isActive ? Colors.blue : Colors.grey[400], size: 24))),
        Expanded(child: GestureDetector(onLongPress: () => _showLingQDialog("sentence_$index", text, isPhrase: true), child: _buildSentence(text, index))),
      ]),
    );
  }

  Widget _buildTextRow(int index, String sentence, bool isActive, bool isDark) {
    return GestureDetector(
      onLongPress: () => _showLingQDialog("sentence_$index", sentence, isPhrase: true),
      onDoubleTap: () => _speakSentence(sentence, index),
      child: Container(
        key: _itemKeys[index], margin: EdgeInsets.only(bottom: 24), padding: isActive ? EdgeInsets.all(12) : EdgeInsets.zero,
        decoration: BoxDecoration(color: isActive ? Colors.yellow.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
        child: _buildSentence(sentence, index),
      ),
    );
  }

  Widget _buildSentence(String sentence, int sentenceIndex, {bool isBigMode = false}) {
    final words = sentence.split(RegExp(r'(\s+)'));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    double fontSize = 18;
    if (isBigMode) fontSize = _isVideo ? 26 : 22;
    final double lineHeight = isBigMode ? 1.6 : 1.5;

    return Wrap(
      spacing: 0, runSpacing: isBigMode ? 12 : 6, alignment: isBigMode ? WrapAlignment.center : WrapAlignment.start,
      children: words.asMap().entries.map((entry) {
        final int wordIndex = entry.key;
        final String word = entry.value;
        final cleanWord = _generateCleanId(word);
        final GlobalKey wordKey = GlobalKey(); 

        if (cleanWord.isEmpty || word.trim().isEmpty) return Container(key: wordKey, padding: EdgeInsets.symmetric(horizontal: 2, vertical: 1), child: Text(word, style: TextStyle(fontSize: fontSize, height: lineHeight, color: isDark ? Colors.white : Colors.black87)));

        bool isSelected = false;
        if (_isSelectionMode && _selectionSentenceIndex == sentenceIndex) {
          int start = _selectionStartIndex < _selectionEndIndex ? _selectionStartIndex : _selectionEndIndex;
          int end = _selectionStartIndex < _selectionEndIndex ? _selectionEndIndex : _selectionStartIndex;
          if (wordIndex >= start && wordIndex <= end) isSelected = true;
        }

        final vocabItem = _vocabulary[cleanWord];
        Color bgColor = _getWordColor(vocabItem);
        Color textColor = (isSelected || vocabItem?.status == 5 || vocabItem == null) ? (isDark ? Colors.white : Colors.black87) : Colors.black87;
        if(isSelected) { bgColor = Colors.purple.withOpacity(0.3); textColor = Colors.white; }

        return GestureDetector(
          key: wordKey, behavior: HitTestBehavior.translucent,
          onLongPressStart: (_) => _startSelection(sentenceIndex, wordIndex),
          onLongPressMoveUpdate: (details) => _handleDragUpdate(sentenceIndex, words.length, details.globalPosition),
          onLongPressEnd: (_) => _finishSelection(sentence),
          onTap: () { if (_isSelectionMode) _clearSelection(); else _onWordTap(cleanWord, word); },
          child: Container(
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(4), border: isSelected ? Border.all(color: Colors.purple.withOpacity(0.5), width: 1) : null),
            padding: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Text(word, style: TextStyle(fontSize: fontSize, height: lineHeight, color: textColor, fontFamily: 'Roboto')),
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
    return Column(children: [SizedBox(height: _isAudioMode ? 1 : 220, child: YoutubePlayer(controller: _videoController!, showVideoProgressIndicator: true, progressIndicatorColor: Colors.red)), if (_isAudioMode) _buildAudioPlayerUI(isDark)]);
  }

  Widget _buildAudioPlayerUI(bool isDark) {
    return Container(color: isDark ? Color(0xFF1E1E1E) : Colors.grey[100], padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16), child: Row(children: [IconButton(iconSize: 42, icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.blue), onPressed: () => _isPlaying ? _videoController!.pause() : _videoController!.play()), SizedBox(width: 8), Text("Audio Mode", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))]));
  }

  void _showLingQDialog(String cleanId, String originalText, {required bool isPhrase}) {
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    final translationService = context.read<TranslationService>();
    VocabularyItem? existingItem = isPhrase ? null : _vocabulary[cleanId];
    if (_isVideo) _videoController!.pause();

    Future<String> translationFuture;
    if (existingItem != null) translationFuture = Future.value(existingItem.translation);
    else translationFuture = translationService.translate(originalText, user.nativeLanguage, widget.lesson.language).catchError((e) => "Translation unavailable");

    final geminiPrompt = isPhrase ? "Translate this ${user.currentLanguage} phrase to ${user.nativeLanguage}: \"$originalText\"..." : "Translate this ${user.currentLanguage} word to ${user.nativeLanguage}: \"$originalText\"...";
    final Future<String?> geminiFuture = Gemini.instance.prompt(parts: [Part.text(geminiPrompt)]).then((value) => value?.output).catchError((e) => "Gemini unavailable");

    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) {
      return TranslationSheet(originalText: originalText, translationFuture: translationFuture, geminiFuture: geminiFuture, isPhrase: isPhrase, existingItem: existingItem, targetLanguage: widget.lesson.language, nativeLanguage: user.nativeLanguage, onSpeak: () => _flutterTts.speak(originalText), onUpdateStatus: (status, translation) => _updateWordStatus(cleanId, originalText, translation, status), onSaveToFirebase: () => _saveWordToFirebase(originalText), onClose: () => Navigator.pop(context));
    }).then((_) => _clearSelection());
  }

  void _saveWordToFirebase(String word) async {
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    try { await FirebaseFirestore.instance.collection('users').doc(user.id).collection('saved_words').add({'word': word, 'added_at': FieldValue.serverTimestamp(), 'source_lesson': widget.lesson.id}); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Saved to your list!"))); } catch (e) { print("Error saving word: $e"); }
  }

  Future<void> _updateWordStatus(String cleanWord, String originalWord, String translation, int status, {bool showDialog = true}) async {
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    VocabularyItem? existingItem = _vocabulary[cleanWord];
    VocabularyItem newItem;
    if (existingItem != null) newItem = existingItem.copyWith(status: status, translation: translation.isNotEmpty ? translation : existingItem.translation, timesEncountered: existingItem.timesEncountered + 1, lastReviewed: DateTime.now());
    else newItem = VocabularyItem(id: cleanWord, userId: user.id, word: cleanWord, baseForm: cleanWord, language: widget.lesson.language, translation: translation, status: status, timesEncountered: 1, lastReviewed: DateTime.now(), createdAt: DateTime.now());

    setState(() => _vocabulary[cleanWord] = newItem);
    if (existingItem != null) context.read<VocabularyBloc>().add(VocabularyUpdateRequested(newItem));
    else context.read<VocabularyBloc>().add(VocabularyAddRequested(newItem));

    try { await FirebaseFirestore.instance.collection('users').doc(user.id).collection('vocabulary').doc(cleanWord).set({'id': cleanWord, 'userId': user.id, 'word': cleanWord, 'baseForm': cleanWord, 'language': widget.lesson.language, 'translation': translation, 'status': status, 'timesEncountered': newItem.timesEncountered, 'lastReviewed': FieldValue.serverTimestamp(), 'createdAt': existingItem != null ? existingItem.createdAt : FieldValue.serverTimestamp()}, SetOptions(merge: true)); } catch (e) { print("Error saving ranking to Firestore: $e"); }
    if (showDialog) { ScaffoldMessenger.of(context).hideCurrentSnackBar(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Word status updated"), duration: Duration(seconds: 1), behavior: SnackBarBehavior.floating)); }
  }
}
