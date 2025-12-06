import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:linguaflow/widgets/floating_translation_card.dart';
import 'package:linguaflow/widgets/premium_lock_dialog.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class ReaderScreen extends StatefulWidget {
  final LessonModel lesson;

  const ReaderScreen({super.key, required this.lesson});

  @override
  _ReaderScreenState createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  // --- CONSTANTS ---
  static const int _kFreeLookupLimit = 50;
  static const int _kResetMinutes = 10;

  Map<String, VocabularyItem> _vocabulary = {};

  // --- SETTINGS ---
  bool _autoMarkOnSwipe = false;

  // --- VIDEO / AUDIOBOOK STATE ---
  YoutubePlayerController? _videoController;
  bool _isVideo = false; 
  bool _isAudioMode = false;
  bool _isPlaying = false;
  bool _isFullScreen = false;
  bool _isTransitioningFullscreen = false;

  // --- TTS STATE ---
  final FlutterTts _flutterTts = FlutterTts();
  bool _isTtsPlaying = false;
  final double _ttsSpeed = 0.5;

  // --- SCROLLING & LISTS ---
  // We use ScrollController for the ListView to handle lazy loading
  final ScrollController _listScrollController = ScrollController();
  int _activeSentenceIndex = -1;
  
  // Keys to find items for auto-scrolling (only works if item is rendered)
  final List<GlobalKey> _itemKeys = [];

  // --- CONTENT ---
  List<String> _smartChunks = [];
  List<int> _chunkToTranscriptMap = [];

  // --- PAGINATION (Text Only Mode) ---
  final PageController _pageController = PageController();
  List<List<int>> _bookPages = [];
  int _currentPage = 0;
  final int _wordsPerPage = 100;

  // --- SELECTION ---
  bool _isSelectionMode = false;
  int _selectionSentenceIndex = -1;
  int _selectionStartIndex = -1;
  int _selectionEndIndex = -1;
  Offset _lastDragPosition = Offset.zero;

  // --- SENTENCE MODE ---
  bool _isSentenceMode = false;
  bool _hasShownSwipeHint = false;
  String? _currentSentenceTranslation;

  // --- UTILS ---
  final Map<String, GlobalKey> _stableWordKeys = {};
  bool _isCheckingLimit = false;

  @override
  void initState() {
    super.initState();
    
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    
    final envKey = dotenv.env['GEMINI_API_KEY'];
    if (envKey != null && envKey.isNotEmpty) {
      try {
        Gemini.init(apiKey: envKey);
      } catch (e) {
        print("Gemini Init Error: $e");
      }
    }
    _loadVocabulary();
    _loadUserPreferences();
    _generateSmartChunks();

    // Generate keys for potential scrolling
    final maxCount = (_smartChunks.length > widget.lesson.sentences.length)
        ? _smartChunks.length
        : widget.lesson.sentences.length;

    for (var i = 0; i < maxCount + 50; i++) {
      _itemKeys.add(GlobalKey());
    }

    // Pagination for pure text books
    if (widget.lesson.transcript.isEmpty) {
      _prepareBookPages();
    }

    // --- FIX: DETECT AUDIOBOOKS & VIDEOS ---
    // This checks if we have a URL, even if the type says 'audio'
    if (widget.lesson.videoUrl != null && widget.lesson.videoUrl!.isNotEmpty) {
      _initializeVideoPlayer();
    } else {
      _initializeTts();
    }
  }

  Future<void> _loadUserPreferences() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(authState.user.id)
            .collection('preferences')
            .doc('reader')
            .get();

        if (doc.exists && mounted) {
          setState(() {
            _autoMarkOnSwipe = doc.data()?['autoMarkOnSwipe'] ?? false;
          });
        }
      } catch (e) {
        // ignore
      }
    }
  }

  Future<void> _toggleAutoMarkOnSwipe() async {
    final authState = context.read<AuthBloc>().state;
    final newValue = !_autoMarkOnSwipe;

    setState(() => _autoMarkOnSwipe = newValue);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(newValue
            ? "Mark known on swipe enabled"
            : "Mark known on swipe disabled"),
        duration: const Duration(seconds: 1),
      ),
    );

    if (authState is AuthAuthenticated) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(authState.user.id)
            .collection('preferences')
            .doc('reader')
            .set({'autoMarkOnSwipe': newValue}, SetOptions(merge: true));
      } catch (e) {
        // ignore
      }
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
      if (currentWordCount + wordCount > _wordsPerPage &&
          currentPageIndices.isNotEmpty) {
        _bookPages.add(currentPageIndices);
        currentPageIndices = [];
        currentWordCount = 0;
      }
      currentPageIndices.add(i);
      currentWordCount += wordCount;
    }
    if (currentPageIndices.isNotEmpty) _bookPages.add(currentPageIndices);
  }

  @override
  void dispose() {
    try {
      _videoController?.removeListener(_videoListener);
    } catch (_) {}
    _videoController?.dispose();
    _pageController.dispose();
    _listScrollController.dispose(); // Dispose new controller
    _flutterTts.stop();
    _stableWordKeys.clear();
    
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
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
          timesEncountered:
              (data['timesEncountered'] is int) ? data['timesEncountered'] : 1,
          lastReviewed: _parseDateTime(data['lastReviewed']),
          createdAt: _parseDateTime(data['createdAt']),
        );
      }
      if (mounted) setState(() => _vocabulary = loadedVocab);
    } catch (e) {
      try {
        final vocabService = context.read<VocabularyService>();
        final items = await vocabService.getVocabulary(user.id);
        if (mounted) {
          setState(() => _vocabulary = {
                for (var item in items) item.word.toLowerCase(): item
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
        return const Color(0xFFFFF9C4);
      case 2:
        return const Color(0xFFFFF59D);
      case 3:
        return const Color(0xFFFFCC80);
      case 4:
        return const Color(0xFFFFB74D);
      case 5:
        return Colors.transparent;
      default:
        return Colors.transparent;
    }
  }

  // --- VIDEO PLAYER INIT ---
  void _initializeVideoPlayer() {
    String? videoId;
    
    // --- FIX: Handle Synced Audiobook IDs ---
    if (widget.lesson.id.startsWith('yt_audio_')) {
      videoId = widget.lesson.id.replaceAll('yt_audio_', '');
    } else if (widget.lesson.id.startsWith('yt_')) {
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
          disableDragSeek: false,
        ),
      );
      _videoController!.addListener(_videoListener);
    }
  }

  // --- SYNC ENGINE ---
  void _videoListener() {
    if (_videoController == null || !mounted) return;
    if (_isTransitioningFullscreen) return;

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
        setState(() {
          _activeSentenceIndex = realTimeIndex;
          _currentSentenceTranslation = null;
        });
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

  void _toggleCustomFullScreen() {
    if (_videoController == null) return;

    final wasPlaying = _videoController!.value.isPlaying;
    final currentPosition = _videoController!.value.position;

    setState(() {
      _isTransitioningFullscreen = true;
      _isFullScreen = !_isFullScreen;
    });

    _videoController!.removeListener(_videoListener);

    if (_isFullScreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
          overlays: SystemUiOverlay.values);
    }

    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted || _videoController == null) return;

      _videoController!.addListener(_videoListener);
      _videoController!.seekTo(currentPosition);

      if (wasPlaying) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _videoController != null) {
            _videoController!.play();
            setState(() => _isPlaying = true);
          }
        });
      }

      setState(() => _isTransitioningFullscreen = false);
    });
  }

  // --- SAFE AUTO SCROLL ---
  void _scrollToActiveLine(int index) {
    if (!_isSentenceMode && !_isFullScreen) {
      // FIX: Only scroll if item is likely rendered or within list bounds
      if (index >= 0 && index < _itemKeys.length) {
        final key = _itemKeys[index];
        // Ensure context exists (item is rendered in ListView) before scrolling
        if (key.currentContext != null) {
          Scrollable.ensureVisible(
            key.currentContext!,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: 0.5, // Center it
          );
        } else {
          // Fallback: If not rendered (lazy loaded), we could animate the scroll controller
          // roughly. For now, we skip to avoid crashes.
        }
      }
    }
  }

  void _seekToTime(double seconds) {
    if (_videoController != null) {
      _videoController!
          .seekTo(Duration(milliseconds: (seconds * 1000).toInt()));
      _videoController!.play();
    }
  }

  void _initializeTts() async {
    await _flutterTts.setLanguage(widget.lesson.language);
    await _flutterTts.setSpeechRate(_ttsSpeed);
    _flutterTts.setCompletionHandler(() {
      if (_isSentenceMode) {
        setState(() => _isTtsPlaying = false);
      } else {
        if (_activeSentenceIndex < widget.lesson.sentences.length - 1) {
          int nextIndex = _activeSentenceIndex + 1;
          if (_bookPages.isNotEmpty) {
            for (int i = 0; i < _bookPages.length; i++) {
              if (_bookPages[i].contains(nextIndex)) {
                if (_currentPage != i) {
                  _pageController.jumpToPage(i);
                  setState(() => _currentPage = i);
                }
                break;
              }
            }
          }
          _speakSentence(widget.lesson.sentences[nextIndex], nextIndex);
        } else {
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
      if (startIndex >= widget.lesson.sentences.length) startIndex = 0;
      _speakSentence(widget.lesson.sentences[startIndex], startIndex);
    }
  }

  void _toggleSentenceMode() {
    if (_isVideo) _videoController?.pause();
    if (_isTtsPlaying) _stopTts();
    setState(() {
      _isSentenceMode = !_isSentenceMode;
      if (_activeSentenceIndex == -1 ||
          _activeSentenceIndex >= _smartChunks.length) {
        _activeSentenceIndex = 0;
      }
      _currentSentenceTranslation = null;
    });
  }

  void _togglePlaybackInMode() {
    if (_isVideo && _videoController != null) {
      _isPlaying ? _videoController!.pause() : _videoController!.play();
    } else {
      _isTtsPlaying ? _stopTts() : _playCurrentSentenceInMode();
    }
  }

  void _playCurrentSentenceInMode() {
    if (_activeSentenceIndex == -1) return;
    if (_isVideo && widget.lesson.transcript.isNotEmpty) {
      if (_activeSentenceIndex < widget.lesson.transcript.length) {
        _seekToTime(widget.lesson.transcript[_activeSentenceIndex].start);
      }
    } else {
      if (_activeSentenceIndex < _smartChunks.length) {
        _speakSentence(_smartChunks[_activeSentenceIndex], _activeSentenceIndex);
      }
    }
  }

  Future<void> _translateCurrentSentence() async {
    String text = "";
    if (_activeSentenceIndex < _smartChunks.length) {
      text = _smartChunks[_activeSentenceIndex];
    }
    if (text.isEmpty) return;
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    final translationService = context.read<TranslationService>();
    try {
      final translated = await translationService.translate(
          text, user.nativeLanguage, widget.lesson.language);
      setState(() => _currentSentenceTranslation = translated);
    } catch (e) {
      setState(() => _currentSentenceTranslation = "Translation unavailable");
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

  void _handleSwipeMarking(int leavingIndex) {
    if (!_autoMarkOnSwipe) return;
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Marked previous words as known"),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating));
    }
  }

  void _handleDragUpdate(
      int sentenceIndex, int maxWords, Offset globalPosition) {
    _lastDragPosition = globalPosition;
    for (int i = 0; i < maxWords; i++) {
      final key = _getWordKey(sentenceIndex, i);
      final context = key.currentContext;
      if (context != null) {
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          final rect =
              (renderBox.localToGlobal(Offset.zero) & renderBox.size)
                  .inflate(10.0);
          if (rect.contains(globalPosition)) {
            if (_selectionEndIndex != i) {
              setState(() => _selectionEndIndex = i);
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
    final phrase = words.sublist(start, end + 1).join(" ");

    _showDefinitionDialog(_generateCleanId(phrase), phrase.trim(),
        isPhrase: words.sublist(start, end + 1).length > 1,
        tapPosition: _lastDragPosition);
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

  @override
  Widget build(BuildContext context) {
    // --- FULLSCREEN VIDEO MODE ---
    if (_isFullScreen && _isVideo && _videoController != null) {
      return WillPopScope(
        onWillPop: () async {
          _toggleCustomFullScreen();
          return false;
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Center(
                child: YoutubePlayer(
                  controller: _videoController!,
                  showVideoProgressIndicator: true,
                  progressIndicatorColor: Colors.red,
                  bottomActions: [
                    const SizedBox(width: 14.0),
                    CurrentPosition(),
                    const SizedBox(width: 8.0),
                    ProgressBar(isExpanded: true),
                    RemainingDuration(),
                    const PlaybackSpeedButton(),
                    IconButton(
                      icon: const Icon(Icons.fullscreen_exit,
                          color: Colors.white),
                      onPressed: _toggleCustomFullScreen,
                    ),
                  ],
                ),
              ),
              if (_activeSentenceIndex != -1 &&
                  _activeSentenceIndex < _smartChunks.length)
                Positioned(
                  left: 40,
                  right: 40,
                  bottom: 35,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12)),
                      child: _buildSentence(
                          _smartChunks[_activeSentenceIndex],
                          _activeSentenceIndex,
                          isOverlay: true),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final theme = Theme.of(context);

    // Progress Bar Calculation
    double sliderValue = 0.0;
    double sliderMax = 1.0;

    if (_isSentenceMode ||
        (_isVideo && widget.lesson.transcript.isNotEmpty)) {
      final total = _smartChunks.length;
      sliderMax = (total > 0) ? (total - 1).toDouble() : 0.0;
      sliderValue =
          (_activeSentenceIndex >= 0) ? _activeSentenceIndex.toDouble() : 0.0;
    } else {
      final totalPages = _bookPages.length;
      sliderMax = (totalPages > 0) ? (totalPages - 1).toDouble() : 0.0;
      sliderValue = _currentPage.toDouble();
    }
    if (sliderValue > sliderMax) sliderValue = sliderMax;
    if (sliderValue < 0) sliderValue = 0;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bgColor,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        title: Text(widget.lesson.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        actions: [
          if (!_isVideo && !_isSentenceMode)
            IconButton(
              icon: Icon(_isPlaying || _isTtsPlaying
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_filled),
              color: Colors.blue,
              onPressed: _isVideo ? () {} : _toggleTtsFullLesson,
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'toggle_mark_swipe') {
                _toggleAutoMarkOnSwipe();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'toggle_mark_swipe',
                child: Row(
                  children: [
                    Icon(
                        _autoMarkOnSwipe
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        color: _autoMarkOnSwipe
                            ? theme.primaryColor
                            : Colors.grey),
                    const SizedBox(width: 8),
                    const Text('Mark known on swipe'),
                  ],
                ),
              ),
            ],
          )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: LinearProgressIndicator(
              value: (sliderMax > 0) ? (sliderValue / sliderMax) : 0,
              backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
              minHeight: 4),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                if (_isVideo) _buildVideoHeader(isDark),
                if (_isCheckingLimit)
                  const LinearProgressIndicator(minHeight: 2),
                
                // --- MAIN CONTENT AREA ---
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
                child: FloatingActionButton(
                  backgroundColor: theme.primaryColor,
                  onPressed: _toggleSentenceMode,
                  child: Icon(
                      _isSentenceMode ? Icons.menu_book : Icons.short_text,
                      color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
Widget _buildVideoHeader(bool isDark) {
if (_videoController == null) return const SizedBox.shrink();
return Column(
children: [
SizedBox(
height: _isAudioMode ? 1 : 220,
child: YoutubePlayer(
controller: _videoController!,
showVideoProgressIndicator: true,
progressIndicatorColor: Colors.red,
bottomActions: [
const SizedBox(width: 14.0),
CurrentPosition(),
const SizedBox(width: 8.0),
ProgressBar(isExpanded: true),
RemainingDuration(),
const PlaybackSpeedButton(),
IconButton(
icon: const Icon(Icons.fullscreen, color: Colors.white),
onPressed: _toggleCustomFullScreen,
),
],
),
),
if (_isAudioMode) _buildAudioPlayerUI(isDark),
],
);
}
 Widget _buildAudioPlayerUI(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[100],
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
          const SizedBox(width: 8),
          const Text("Audio Mode",
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        ],
      ),
    );
  }

  // --- REPLACED COLUMN WITH LISTVIEW TO FIX LAG/CRASH ---
  Widget _buildParagraphModeView(bool isDark) {
    if (widget.lesson.transcript.isNotEmpty) {
      // OPTIMIZATION: Use ListView.builder for Lazy Loading
      return ListView.separated(
        controller: _listScrollController, // Attach controller for potential manual scrolling
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        itemCount: widget.lesson.transcript.length + 1, // +1 for bottom padding
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == widget.lesson.transcript.length) {
            return const SizedBox(height: 100); // Bottom padding
          }
          final entry = widget.lesson.transcript[index];
          return _buildTranscriptRow(
            index, 
            entry.text, 
            entry.start, 
            index == _activeSentenceIndex, 
            isDark
          );
        },
      );
    }
    
    // For pure text (no transcript), we still use PageView which is safe
    if (_bookPages.isEmpty) return const Center(child: CircularProgressIndicator());
    
    return PageView.builder(
      controller: _pageController,
      itemCount: _bookPages.length,
      onPageChanged: (index) => setState(() => _currentPage = index),
      itemBuilder: (context, pageIndex) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ..._bookPages[pageIndex]
                  .map((index) => _buildTextRow(
                      index,
                      widget.lesson.sentences[index],
                      index == _activeSentenceIndex,
                      isDark))
                  ,
              const SizedBox(height: 100),
            ],
          ),
        );
      },
    );
  }

  // ... [Keep other methods like _buildSentenceModeView, _buildTranscriptRow, etc. exactly as they were] ...
  
  // (Include the rest of the file helper methods here to ensure complete file)
  Widget _buildSentenceModeView(bool isDark, Color? textColor) {
    final count = _smartChunks.length;
    if (count == 0) return const Center(child: Text("No content"));
    if (_activeSentenceIndex < 0) _activeSentenceIndex = 0;
    if (_activeSentenceIndex >= count) _activeSentenceIndex = count - 1;

    String currentText = _smartChunks[_activeSentenceIndex];

    return Column(
      children: [
        const SizedBox(height: 40),
        Center(
          child: GestureDetector(
            onTap: _togglePlaybackInMode,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withOpacity(0.5), width: 2),
              ),
              child: Icon(
                _isVideo
                    ? (_isPlaying ? Icons.pause : Icons.play_arrow)
                    : (_isTtsPlaying ? Icons.stop : Icons.play_arrow),
                size: 40,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ),
        const Spacer(),
        Expanded(
          flex: 3,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity! < 0) {
                _nextSentence();
              } else if (details.primaryVelocity! > 0) {
                _prevSentence();
              }
            },
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity! < 0) {
                _nextSentence();
              } else if (details.primaryVelocity! > 0) {
                _prevSentence();
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              alignment: Alignment.center,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildSentence(currentText, _activeSentenceIndex,
                        isBigMode: true),
                    const SizedBox(height: 24),
                    if (_currentSentenceTranslation == null)
                      TextButton.icon(
                        icon: const Icon(Icons.translate,
                            size: 16, color: Colors.grey),
                        label: const Text("Translate Sentence",
                            style: TextStyle(color: Colors.grey)),
                        onPressed: _translateCurrentSentence,
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          _currentSentenceTranslation!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.grey[400],
                              fontStyle: FontStyle.italic,
                              fontSize: 16),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const Spacer(),
        const Padding(
          padding: EdgeInsets.only(bottom: 20),
          child: Text(
            "Swipe LEFT/UP for next • RIGHT/DOWN for previous",
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildTranscriptRow(
      int index, String text, double startTime, bool isActive, bool isDark) {
    return Container(
      key: _itemKeys[index],
      margin: const EdgeInsets.only(bottom: 12),
      padding: isActive ? const EdgeInsets.all(12) : EdgeInsets.zero,
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
                padding: const EdgeInsets.only(top: 4, right: 12),
                child: Icon(
                    isActive ? Icons.play_arrow : Icons.play_arrow_outlined,
                    color: isActive ? Colors.blue : Colors.grey[400],
                    size: 24),
              ),
            ),
          Expanded(
            child: GestureDetector(
              onLongPress: () {
                final size = MediaQuery.of(context).size;
                _showDefinitionDialog("sentence_$index", text,
                    isPhrase: true,
                    tapPosition: Offset(size.width / 2, size.height / 2));
              },
              child: _buildSentence(text, index),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextRow(
      int index, String sentence, bool isActive, bool isDark) {
    return GestureDetector(
      onLongPress: () {
        final size = MediaQuery.of(context).size;
        _showDefinitionDialog("sentence_$index", sentence,
            isPhrase: true,
            tapPosition: Offset(size.width / 2, size.height / 2));
      },
      onDoubleTap: () => _speakSentence(sentence, index),
      child: Container(
        key: _itemKeys[index],
        margin: const EdgeInsets.only(bottom: 24),
        padding: isActive ? const EdgeInsets.all(12) : EdgeInsets.zero,
        decoration: BoxDecoration(
          color: isActive
              ? Colors.yellow.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: _buildSentence(sentence, index),
      ),
    );
  }

  Widget _buildSentence(String sentence, int sentenceIndex,
      {bool isBigMode = false, bool isOverlay = false}) {
    final words = sentence.split(RegExp(r'(\s+)'));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    double fontSize = 18;
    if (isBigMode) fontSize = _isVideo ? 26 : 22;
    if (isOverlay) fontSize = 20;
    final double lineHeight = isBigMode ? 1.6 : 1.5;

    return Wrap(
      spacing: 0,
      runSpacing: isBigMode ? 12 : 6,
      alignment:
          (isBigMode || isOverlay) ? WrapAlignment.center : WrapAlignment.start,
      children: words.asMap().entries.map((entry) {
        final int wordIndex = entry.key;
        final String word = entry.value;
        final cleanWord = _generateCleanId(word);
        final GlobalKey wordKey = GlobalKey();

        if (cleanWord.isEmpty || word.trim().isEmpty) {
          return Container(
            key: wordKey,
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
            child: Text(word,
                style: TextStyle(
                    fontSize: fontSize,
                    height: lineHeight,
                    color: isOverlay
                        ? Colors.white
                        : (isDark ? Colors.white : Colors.black87))),
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
        Color bgColor = _getWordColor(vocabItem);
        Color textColor;
        if (isOverlay) {
          textColor = Colors.white;
          if (bgColor != Colors.transparent &&
              bgColor != Colors.blue.withOpacity(0.15)) {
            bgColor = bgColor.withOpacity(0.8);
            textColor = Colors.black;
          }
        } else {
          textColor = (isSelected ||
                  vocabItem?.status == 5 ||
                  vocabItem == null)
              ? (isDark ? Colors.white : Colors.black87)
              : Colors.black87;
        }
        if (isSelected) {
          bgColor = Colors.purple.withOpacity(0.3);
          textColor = Colors.white;
        }

        return GestureDetector(
          key: wordKey,
          behavior: HitTestBehavior.translucent,
          onLongPressStart: (_) => _startSelection(sentenceIndex, wordIndex),
          onLongPressMoveUpdate: (details) =>
              _handleDragUpdate(sentenceIndex, words.length, details.globalPosition),
          onLongPressEnd: (_) => _finishSelection(sentence),
          onTapUp: (details) {
            if (_isSelectionMode) {
              _clearSelection();
            } else {
              _handleWordTap(cleanWord, word,
                  tapPosition: details.globalPosition);
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
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Text(
              word,
              style: TextStyle(
                fontSize: fontSize,
                height: lineHeight,
                color: textColor,
                fontWeight: (bgColor != Colors.transparent &&
                        bgColor != Colors.blue.withOpacity(0.15))
                    ? FontWeight.w600
                    : FontWeight.normal,
                fontFamily: 'Roboto',
                shadows: isOverlay
                    ? [
                        const Shadow(
                            offset: Offset(0, 1),
                            blurRadius: 2,
                            color: Colors.black)
                      ]
                    : null,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _handleWordTap(String cleanWord, String originalWord,
      {Offset? tapPosition}) async {
    if (_isCheckingLimit) return;
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;
    final user = authState.user;

    final safePosition =
        tapPosition ?? MediaQuery.of(context).size.center(Offset.zero);

    if (user.isPremium) {
      _showDefinitionDialog(cleanWord, originalWord,
          isPhrase: false, tapPosition: safePosition);
      return;
    }

    setState(() => _isCheckingLimit = true);
    try {
      final canAccess = await _checkAndIncrementFreeLimit(user.id);
      setState(() => _isCheckingLimit = false);
      if (canAccess) {
        _showDefinitionDialog(cleanWord, originalWord,
            isPhrase: false, tapPosition: safePosition);
      } else {
        _showLimitDialog();
      }
    } catch (e) {
      setState(() => _isCheckingLimit = false);
      print("ERROR checking limit: $e");
    }
  }

  Future<bool> _checkAndIncrementFreeLimit(String userId) async {
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('limits')
        .doc('dictionary');
    final snapshot = await docRef.get();
    final now = DateTime.now();
    if (!snapshot.exists) {
      await docRef
          .set({'count': 1, 'lastReset': FieldValue.serverTimestamp()});
      return true;
    }
    final data = snapshot.data()!;
    final DateTime lastReset =
        (data['lastReset'] as Timestamp?)?.toDate() ?? now;
    final int count = data['count'] ?? 0;
    if (now.difference(lastReset).inMinutes >= _kResetMinutes) {
      await docRef.set(
          {'count': 1, 'lastReset': FieldValue.serverTimestamp()},
          SetOptions(merge: true));
      return true;
    } else {
      if (count < _kFreeLookupLimit) {
        await docRef.update({'count': FieldValue.increment(1)});
        return true;
      }
      return false;
    }
  }

  void _showDefinitionDialog(String cleanId, String originalText,
      {required bool isPhrase, required Offset tapPosition}) {
    if (_isVideo) _videoController!.pause();
    if (_isTtsPlaying) _flutterTts.stop();

    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    final translationService = context.read<TranslationService>();
    final VocabularyItem? existingItem = isPhrase ? null : _vocabulary[cleanId];

    final translationFuture = existingItem != null
        ? Future.value(existingItem.translation)
        : translationService
            .translate(
                originalText, user.nativeLanguage, widget.lesson.language)
            .catchError((e) => "Translation unavailable");

    final geminiPrompt = isPhrase
        ? "Translate this ${user.currentLanguage} phrase to ${user.nativeLanguage}: \"$originalText\"..."
        : "Translate this ${user.currentLanguage} word to ${user.nativeLanguage}: \"$originalText\"...";
    final Future<String?> geminiFuture = Gemini.instance
        .prompt(parts: [Part.text(geminiPrompt)])
        .then((value) => value?.output)
        .catchError((e) => "Gemini unavailable");

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) {
        return FloatingTranslationCard(
          originalText: originalText,
          translationFuture: translationFuture,
          geminiFuture: geminiFuture,
          targetLanguage: widget.lesson.language,
          nativeLanguage: user.nativeLanguage,
          currentStatus: existingItem?.status ?? 0,
          anchorPosition: tapPosition,
          onUpdateStatus: (status, translation) =>
              _updateWordStatus(cleanId, originalText, translation, status),
          onClose: () {
            Navigator.of(context).pop();
            _clearSelection();
          },
        );
      },
    );
  }

  void _showLimitDialog() {
    if (_isTtsPlaying) _flutterTts.stop();
    if (_isVideo && _isPlaying) _videoController!.pause();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Free Limit Reached"),
        content: const Text(
            "Limit reached. Upgrade to Premium for unlimited access."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Wait")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              showDialog(
                  context: context,
                  builder: (context) => const PremiumLockDialog());
            },
            child: const Text("Upgrade Now"),
          ),
        ],
      ),
    );
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Saved to your list!")));
    } catch (e) {}
  }

  Future<void> _updateWordStatus(String cleanWord, String originalWord,
      String translation, int status,
      {bool showDialog = true}) async {
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    VocabularyItem? existingItem = _vocabulary[cleanWord];
    VocabularyItem newItem;
    if (existingItem != null) {
      newItem = existingItem.copyWith(
          status: status,
          translation:
              translation.isNotEmpty ? translation : existingItem.translation,
          timesEncountered: existingItem.timesEncountered + 1,
          lastReviewed: DateTime.now());
    } else {
      newItem = VocabularyItem(
        id: cleanWord,
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

    setState(() => _vocabulary[cleanWord] = newItem);
    if (existingItem != null) {
      context.read<VocabularyBloc>().add(VocabularyUpdateRequested(newItem));
    } else {
      context.read<VocabularyBloc>().add(VocabularyAddRequested(newItem));
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .collection('vocabulary')
          .doc(cleanWord)
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
        'createdAt': existingItem != null
            ? existingItem.createdAt
            : FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {}

    if (showDialog) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Word status updated"),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating));
    }
  }
}