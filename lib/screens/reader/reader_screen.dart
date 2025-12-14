import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

// --- Internal App Imports ---
import 'package:linguaflow/screens/reader/widgets/reader_media_widgets.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/vocabulary/vocabulary_bloc.dart';
import 'package:linguaflow/blocs/settings/settings_bloc.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/vocabulary_item.dart';
import 'package:linguaflow/models/transcript_line.dart';
import 'package:linguaflow/services/translation_service.dart';
import 'package:linguaflow/services/mymemory_service.dart';
import 'package:linguaflow/widgets/floating_translation_card.dart';
import 'package:linguaflow/widgets/premium_lock_dialog.dart';
import 'package:linguaflow/utils/subtitle_parser.dart';

import 'reader_utils.dart';
import 'widgets/reader_view_modes.dart';
import 'widgets/interactive_text_display.dart';

// --- NEW IMPORTS ---
import 'widgets/video_controls_overlay.dart';
import 'widgets/fullscreen_translation_card.dart';

class ReaderScreen extends StatefulWidget {
  final LessonModel lesson;
  const ReaderScreen({super.key, required this.lesson});

  @override
  _ReaderScreenState createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen>
    with WidgetsBindingObserver {
  // --- Data & Config ---
  Map<String, VocabularyItem> _vocabulary = {};
  bool _autoMarkOnSwipe = false;
  bool _hasSeenStatusHint = false;
  bool _isListeningMode = false;
  bool _hasMarkedLessonComplete = false;
  // Subtitle Toggle State
  bool _showSubtitles = true;

  // --- Media Players ---
  YoutubePlayerController? _youtubeController;
  Player? _localPlayer;
  VideoController? _localVideoController;
  Timer? _syncTimer;

  // --- Media State ---
  bool _isVideo = false;
  bool _isAudio = false;
  bool _isYoutubeAudio = false;
  bool _isLocalMedia = false;
  bool _isInitializingMedia = false;
  bool _isParsingSubtitles = true;
  bool _isPlaying = false;
  bool _isSeeking = false;
  bool _isPlayingSingleSentence = false;

  // Optimistic Seek State
  Duration? _optimisticPosition;
  Timer? _seekResetTimer;

  // Track if video was playing before opening card
  bool _wasPlayingBeforeCard = false;

  // --- Fullscreen State ---
  bool _isFullScreen = false;
  bool _isTransitioningFullscreen = false;

  // GLOBAL KEY FOR SHARED PLAYER
  final GlobalKey _videoPlayerKey = GlobalKey();

  // --- Controls State (YouTube Style) ---
  bool _showControls = false;
  Timer? _controlsHideTimer;

  // --- TTS ---
  final FlutterTts _flutterTts = FlutterTts();
  bool _isTtsPlaying = false;
  final double _ttsSpeed = 0.5;

  // --- Scroll & Text ---
  final ScrollController _listScrollController = ScrollController();
  int _activeSentenceIndex = -1;
  final PageController _pageController = PageController();
  List<List<int>> _bookPages = [];
  int _currentPage = 0;
  final int _wordsPerPage = 100;
  List<GlobalKey> _itemKeys = [];
  List<String> _smartChunks = [];
  List<TranscriptLine> _activeTranscript = [];
  bool _isSentenceMode = false;

  // --- Translation State ---
  String? _googleTranslation;
  String? _myMemoryTranslation;
  bool _isLoadingTranslation = false;
  bool _showError = false;
  bool _isCheckingLimit = false;

  // --- Card State ---
  bool _showCard = false;
  String _selectedText = "";
  String _selectedCleanId = "";
  bool _isSelectionPhrase = false;
  Offset _cardAnchor = Offset.zero;
  Future<String>? _cardTranslationFuture;
  VoidCallback? _activeSelectionClearer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    _initGemini();
    _loadVocabulary();
    _loadUserPreferences();
    _determineMediaType();

    _activeTranscript = widget.lesson.transcript;
    final hasSubtitleUrl =
        widget.lesson.subtitleUrl != null &&
        widget.lesson.subtitleUrl!.isNotEmpty;

    if (hasSubtitleUrl && _activeTranscript.isEmpty) {
      _initializeLocalContent();
    } else {
      _finalizeContentInitialization();
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!_isTransitioningFullscreen &&
        (_isVideo || _isAudio || _isYoutubeAudio)) {
      final view = View.of(context);
      final physicalSize = view.physicalSize;
      final bool isLandscape = physicalSize.width > physicalSize.height;

      if (isLandscape != _isFullScreen) {
        setState(() {
          _isFullScreen = isLandscape;
        });

        if (isLandscape) {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        } else {
          SystemChrome.setEnabledSystemUIMode(
            SystemUiMode.manual,
            overlays: SystemUiOverlay.values,
          );
        }
      }
    }
  }

  void _determineMediaType() {
    // 1. Check if the URL indicates YouTube
    final bool isYoutubeUrl =
        widget.lesson.videoUrl != null &&
        (widget.lesson.videoUrl!.toLowerCase().contains('youtube.com') ||
            widget.lesson.videoUrl!.toLowerCase().contains('youtu.be'));

    // 2. Check for Youtube Audio
    // Logic: If ID indicates it OR (It's a YouTube URL AND the lesson type is 'audio')
    if (widget.lesson.id.startsWith('yt_audio_') ||
        (isYoutubeUrl && widget.lesson.type == 'audio')) {
      _isYoutubeAudio = true;
      _isAudio = false;
      _isVideo = false;
      return;
    }

    if (widget.lesson.type == 'audio') {
      _isAudio = true;
    } else if (widget.lesson.type == 'video') {
      _isVideo = true;
    } else if (widget.lesson.videoUrl != null) {
      final ext = widget.lesson.videoUrl!.split('.').last.toLowerCase();
      if (['mp3', 'wav', 'm4a', 'aac', 'flac'].contains(ext)) {
        _isAudio = true;
      } else {
        _isVideo = true;
      }
    }
  }

  Future<void> _initializeLocalContent() async {
    try {
      final file = File(widget.lesson.subtitleUrl!);
      if (await file.exists()) {
        final lines = await SubtitleParser.parseFile(
          widget.lesson.subtitleUrl!,
        );
        if (mounted && lines.isNotEmpty) {
          _activeTranscript = lines;
        }
      }
    } catch (e) {
      debugPrint("❌ Error parsing local subtitles: $e");
    } finally {
      if (mounted) _finalizeContentInitialization();
    }
  }

  void _finalizeContentInitialization() {
    setState(() {
      _generateSmartChunks();
      _itemKeys = List.generate(_smartChunks.length, (_) => GlobalKey());
      _prepareBookPages();
      _isParsingSubtitles = false;
    });
    _initializeMedia();
  }

  void _initializeMedia() {
    if ((_isVideo || _isAudio || _isYoutubeAudio) &&
        widget.lesson.videoUrl != null) {
      _initPlayerController();
    } else {
      _initializeTts();
    }
  }

  void _initPlayerController() {
    final url = widget.lesson.videoUrl!;
    bool isNetwork = url.toLowerCase().startsWith('http');
    bool isYoutube =
        url.toLowerCase().contains('youtube.com') ||
        url.toLowerCase().contains('youtu.be');

    if (isYoutube) {
      _initializeYoutubePlayer(url);
    } else if (!isNetwork) {
      _initializeLocalMediaPlayer(url);
    } else {
      _initializeTts();
    }
  }

  void _initGemini() {
    final envKey = dotenv.env['GEMINI_API_KEY'];
    if (envKey != null && envKey.isNotEmpty) Gemini.init(apiKey: envKey);
  }

  @override
  void dispose() {
    // 1. Remove Window Observer first to stop listening to metric changes
    WidgetsBinding.instance.removeObserver(this);

    // 2. Cancel ALL timers immediately.
    // This is crucial to stop '_checkSync' from trying to access the player
    // while we are busy disposing it.
    _syncTimer?.cancel();
    _seekResetTimer?.cancel();
    _controlsHideTimer?.cancel();

    // 3. Safe MediaKit Disposal
    // We wrap this in try-catch because if Hot Restart happened,
    // the native side might already be gone, causing the SIGABRT crash.
    if (_localPlayer != null) {
      try {
        _localPlayer!.stop(); // Stop playback to halt frame callbacks
        _localPlayer!.dispose(); // Release resources
      } catch (e) {
        debugPrint("⚠️ MediaKit dispose warning: $e");
      }
    }
    // Nullify references to prevent accidental access
    _localVideoController = null;
    _localPlayer = null;

    // 4. Dispose YouTube Controller
    _youtubeController?.dispose();
    _youtubeController = null;

    // 5. Stop TTS
    _flutterTts.stop();

    // 6. Dispose Scroll Controllers
    _pageController.dispose();
    _listScrollController.dispose();

    // 7. Reset System UI (Orientation & Status Bar)
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    super.dispose();
  }

  void _markLessonAsComplete() {
    if (!_hasMarkedLessonComplete) {
      _hasMarkedLessonComplete = true;

      // Trigger Auth Event
      context.read<AuthBloc>().add(AuthIncrementLessonsCompleted());

      // Optional: Show UI feedback
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Lesson Completed! 📚 (+1 to stats)"),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // ... (LoadVocab and Preferences methods unchanged) ...
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
          word: data['word'] ?? doc.id,
          baseForm: data['baseForm'] ?? doc.id,
          language: data['language'] ?? '',
          translation: data['translation'] ?? '',
          status: data['status'] ?? 0,
          timesEncountered: data['timesEncountered'] ?? 1,
          lastReviewed: ReaderUtils.parseDateTime(data['lastReviewed']),
          createdAt: ReaderUtils.parseDateTime(data['createdAt']),
        );
      }
      if (mounted) setState(() => _vocabulary = loadedVocab);
    } catch (e) {}
  }

  Future<void> _loadUserPreferences() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(authState.user.id)
          .collection('preferences')
          .doc('reader')
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _autoMarkOnSwipe = doc.data()?['autoMarkOnSwipe'] ?? false;
          _hasSeenStatusHint = doc.data()?['hasSeenStatusHint'] ?? false;
        });
      }
    }
  }

  void _generateSmartChunks() {
    _smartChunks = [];
    if (_activeTranscript.isNotEmpty) {
      for (var t in _activeTranscript) _smartChunks.add(t.text);
      return;
    }
    List<String> rawSentences = widget.lesson.sentences;
    if (rawSentences.isEmpty)
      rawSentences = widget.lesson.content.split(RegExp(r'(?<=[.!?])\s+'));
    for (String sentence in rawSentences)
      if (sentence.trim().isNotEmpty) _smartChunks.add(sentence.trim());
  }

  void _prepareBookPages() {
    _bookPages = [];
    List<int> currentPageIndices = [];
    int currentWordCount = 0;
    for (int i = 0; i < _smartChunks.length; i++) {
      String s = _smartChunks[i];
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

  // --- PLAYER INITIALIZATION ---
  void _initializeYoutubePlayer(String url) {
    String? videoId;

    // 1. Try to get ID from Lesson ID (Legacy/Optimization)
    if (widget.lesson.id.startsWith('yt_audio_')) {
      videoId = widget.lesson.id.replaceAll('yt_audio_', '');
      _isYoutubeAudio = true;
    } else if (widget.lesson.id.startsWith('yt_')) {
      videoId = widget.lesson.id.replaceAll('yt_', '');
    }

    // 2. If not found in ID, extract from URL (Robust Fallback for Favorites)
    if (videoId == null || videoId.isEmpty) {
      videoId = YoutubePlayer.convertUrlToId(url);
    }

    if (videoId != null) {
      _youtubeController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: false, // Don't auto-play, let the UI handle it
          mute: false,
          enableCaption: false,
          hideControls: true,
          disableDragSeek: false,
          loop: false,
          isLive: false,
          forceHD: false,
        ),
      );

      setState(() {
        _isLocalMedia = false;
        // Ensure UI knows it's NOT video if we determined it's audio earlier
        _isVideo = !_isYoutubeAudio;
      });
      _startSyncTimer();
    }
  }

  Future<void> _initializeLocalMediaPlayer(String path) async {
    setState(() => _isInitializingMedia = true);
    try {
      _localPlayer = Player();
      _localVideoController = VideoController(_localPlayer!);

      // FIX 1: GHOST AUDIO FIX
      // Force play: false so it doesn't start in background
      await _localPlayer!.open(Media(path), play: false);

      int retries = 0;
      while (_localPlayer!.state.duration == Duration.zero && retries < 15) {
        await Future.delayed(const Duration(milliseconds: 100));
        retries++;
      }

      if (mounted) {
        setState(() {
          _isLocalMedia = true;
          _isInitializingMedia = false;
        });
        _startSyncTimer();
      }
    } catch (e) {
      debugPrint("❌ MediaKit Init Error: $e");
      if (mounted) setState(() => _isInitializingMedia = false);
    }
  }

  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _checkSync();
    });
  }

  void _checkSync() {
    if (_isSeeking || _isTransitioningFullscreen) return;

    bool isPlaying = false;
    double currentSeconds = 0.0;

    if (_isLocalMedia && _localPlayer != null) {
      isPlaying = _localPlayer!.state.playing;
      currentSeconds = _localPlayer!.state.position.inMilliseconds / 1000.0;
    } else if (_youtubeController != null) {
      isPlaying = _youtubeController!.value.isPlaying;
      currentSeconds =
          _youtubeController!.value.position.inMilliseconds / 1000.0;
    } else {
      return;
    }

    if (isPlaying != _isPlaying) setState(() => _isPlaying = isPlaying);

    if (!isPlaying || _activeTranscript.isEmpty) return;

    if (_isSentenceMode && _isPlayingSingleSentence) {
      if (_activeSentenceIndex >= 0 &&
          _activeSentenceIndex < _activeTranscript.length) {
        if (currentSeconds >=
            _activeTranscript[_activeSentenceIndex].end - 0.05) {
          _pauseMedia();
          setState(() {
            _isPlayingSingleSentence = false;
            _isPlaying = false;
          });
          return;
        }
      }
    }

    bool shouldSync = !_isSentenceMode;

    if (shouldSync) {
      int activeIndex = -1;

      for (int i = 0; i < _activeTranscript.length; i++) {
        if (currentSeconds >= _activeTranscript[i].start &&
            currentSeconds < _activeTranscript[i].end) {
          activeIndex = i;
          break;
        }
      }

      if (activeIndex == -1) {
        for (int i = 0; i < _activeTranscript.length; i++) {
          if (_activeTranscript[i].start > currentSeconds) {
            activeIndex = i > 0 ? i - 1 : 0;
            break;
          }
        }
        if (activeIndex == -1 && _activeTranscript.isNotEmpty) {
          activeIndex = _activeTranscript.length - 1;
        }
      }

      if (activeIndex != -1 && activeIndex != _activeSentenceIndex) {
        setState(() {
          _activeSentenceIndex = activeIndex;
          _resetTranslationState();
        });
        _scrollToActiveLine(activeIndex);
      }
    }
    // NEW: Check for media completion
    if (_isVideo || _isAudio || _isYoutubeAudio) {
      double totalDuration = 0;
      double currentPos = 0;

      if (_isLocalMedia && _localPlayer != null) {
        totalDuration = _localPlayer!.state.duration.inSeconds.toDouble();
        currentPos = _localPlayer!.state.position.inSeconds.toDouble();
      } else if (_youtubeController != null) {
        totalDuration = _youtubeController!.metadata.duration.inSeconds
            .toDouble();
        currentPos = _youtubeController!.value.position.inSeconds.toDouble();
      }

      // If we are within 5 seconds of the end, mark as complete
      if (totalDuration > 0 && currentPos >= totalDuration - 5) {
        _markLessonAsComplete();
      }
    }
  }

  // --- PLAYBACK CONTROLS ---
  void _pauseMedia() {
    if (_isLocalMedia && _localPlayer != null) {
      _localPlayer!.pause();
    } else {
      _youtubeController?.pause();
    }
    _resetControlsTimer();
  }

  void _playMedia() {
    if (_isLocalMedia && _localPlayer != null) {
      _localPlayer!.play();
    } else {
      _youtubeController?.play();
    }
    _resetControlsTimer();
  }

  void _seekRelative(int seconds) async {
    Duration current = Duration.zero;
    Duration total = Duration.zero;

    if (_isLocalMedia && _localPlayer != null) {
      current = _localPlayer!.state.position;
      total = _localPlayer!.state.duration;
    } else if (_youtubeController != null) {
      current = _youtubeController!.value.position;
      total = _youtubeController!.metadata.duration;
    }

    final newPos = current + Duration(seconds: seconds);
    final clamped = newPos < Duration.zero
        ? Duration.zero
        : (newPos > total ? total : newPos);

    await _seekToTime(clamped.inMilliseconds / 1000.0);
    _resetControlsTimer();
  }

  Future<void> _seekToTime(double seconds) async {
    _seekResetTimer?.cancel();
    final d = Duration(milliseconds: (seconds * 1000).toInt());

    setState(() {
      _isSeeking = true;
      _optimisticPosition = d;
    });

    if (_isLocalMedia && _localPlayer != null) {
      await _localPlayer!.seek(d);
    } else if (_youtubeController != null) {
      _youtubeController!.seekTo(d);
    }

    _seekResetTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _isSeeking = false;
          _optimisticPosition = null;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _resetControlsTimer();
  }

  void _resetControlsTimer() {
    _controlsHideTimer?.cancel();
    _controlsHideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isPlaying && !_isSeeking) {
        setState(() => _showControls = false);
      }
    });
  }

  // ... (Nav functions _goToNextSentence etc. unchanged) ...
  void _goToNextSentence() {
    if (_activeSentenceIndex < _smartChunks.length - 1) {
      _handleSwipeMarking(_activeSentenceIndex);
      final next = _activeSentenceIndex + 1;
      setState(() {
        _activeSentenceIndex = next;
        _resetTranslationState();
        if (_isSentenceMode) _isPlayingSingleSentence = true;
      });
      if ((_isVideo || _isAudio || _isYoutubeAudio) &&
          _activeTranscript.isNotEmpty &&
          next < _activeTranscript.length) {
        _seekToTime(_activeTranscript[next].start);
        _playMedia();
      }
    }
  }

  void _goToPrevSentence() {
    if (_activeSentenceIndex > 0) {
      final prev = _activeSentenceIndex - 1;
      setState(() {
        _activeSentenceIndex = prev;
        _resetTranslationState();
        if (_isSentenceMode) _isPlayingSingleSentence = true;
      });
      if ((_isVideo || _isAudio || _isYoutubeAudio) &&
          _activeTranscript.isNotEmpty &&
          prev < _activeTranscript.length) {
        _seekToTime(_activeTranscript[prev].start);
        _playMedia();
      }
    }
  }

  void _playFromStartContinuous() {
    if (_isVideo || _isAudio || _isYoutubeAudio) {
      if (_activeSentenceIndex != -1 && _activeTranscript.isNotEmpty) {
        setState(() => _isPlayingSingleSentence = false);
        _seekToTime(_activeTranscript[_activeSentenceIndex].start);
        _playMedia();
      }
    } else {
      _speakSentence(_smartChunks[_activeSentenceIndex], _activeSentenceIndex);
    }
  }

  void _playNextContinuous() {
    if (_isVideo || _isAudio || _isYoutubeAudio) {
      if (_activeSentenceIndex < _smartChunks.length - 1) {
        _handleSwipeMarking(_activeSentenceIndex);
        setState(() {
          _activeSentenceIndex++;
          _resetTranslationState();
          _isPlayingSingleSentence = false;
        });
        if (_activeSentenceIndex < _activeTranscript.length) {
          _seekToTime(_activeTranscript[_activeSentenceIndex].start);
          _playMedia();
        }
      }
    } else {
      _goToNextSentence();
      _speakSentence(_smartChunks[_activeSentenceIndex], _activeSentenceIndex);
    }
  }

  void _togglePlayback() {
    if (_isVideo || _isAudio || _isYoutubeAudio) {
      if (_isPlaying) {
        _pauseMedia();
        setState(() => _isPlayingSingleSentence = false);
      } else {
        if (_activeSentenceIndex != -1 && _activeTranscript.isNotEmpty) {
          setState(() => _isPlayingSingleSentence = true);
          _seekToTime(_activeTranscript[_activeSentenceIndex].start);
          _playMedia();
        } else {
          _playMedia();
        }
      }
    } else {
      _isTtsPlaying
          ? _flutterTts.stop()
          : _speakSentence(
              _smartChunks[_activeSentenceIndex],
              _activeSentenceIndex,
            );
    }
  }

  void _initializeTts() async {
    await _flutterTts.setLanguage(widget.lesson.language);
    await _flutterTts.setSpeechRate(_ttsSpeed);
    _flutterTts.setCompletionHandler(() {
      if (!_isSentenceMode)
        _playNextTtsSentence();
      else
        setState(() => _isTtsPlaying = false);
    });
  }

  void _playNextTtsSentence() {
    if (_activeSentenceIndex < widget.lesson.sentences.length - 1) {
      int next = _activeSentenceIndex + 1;
      _speakSentence(widget.lesson.sentences[next], next);
    } else {
      setState(() {
        _isTtsPlaying = false;
        _activeSentenceIndex = -1;
      });
    }
  }

  Future<void> _speakSentence(String text, int index) async {
    setState(() {
      _activeSentenceIndex = index;
      _isTtsPlaying = true;
    });
    if (!_isSentenceMode) _scrollToActiveLine(index);
    await _flutterTts.speak(text);
  }

  void _toggleTtsFullLesson() async {
    if (_isTtsPlaying) {
      await _flutterTts.stop();
      setState(() => _isTtsPlaying = false);
    } else {
      int start = _activeSentenceIndex == -1 ? 0 : _activeSentenceIndex;
      _speakSentence(widget.lesson.sentences[start], start);
    }
  }

  void _toggleSubtitles() {
    setState(() => _showSubtitles = !_showSubtitles);
  }

  // FIX 2: DRAG SELECT FIX (Reset Focus)
  void _closeTranslationCard() {
    if (_showCard) {
      // Unfocus triggers the SelectableText to release its internal selection state
      // This allows you to select a new phrase immediately.
      FocusManager.instance.primaryFocus?.unfocus();

      _activeSelectionClearer?.call();
      setState(() {
        _showCard = false;
        _activeSelectionClearer = null;
      });

      // RESUME: Check if video was playing before card opened
      if (_wasPlayingBeforeCard && (_isVideo || _isAudio || _isYoutubeAudio)) {
        _playMedia();
      }
      _wasPlayingBeforeCard = false;
    }
  }

  void _handleWordTap(String word, String cleanId, Offset pos) async {
    _activeSelectionClearer?.call();
    _activeSelectionClearer = null;
    if (_isCheckingLimit) return;
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;
    final existing = _vocabulary[cleanId];
    final status = _calculateSmartStatus(existing);
    if (existing == null || existing.status != status)
      _updateWordStatus(
        cleanId,
        word,
        existing?.translation ?? "",
        status,
        showDialog: false,
      );
    if (auth.user.isPremium)
      _activateCard(word, cleanId, pos, isPhrase: false);
    else
      _checkLimitAndActivate(auth.user.id, cleanId, word, pos, false);
  }

  String _restoreSpaces(String compressedPhrase) {
    if (_activeSentenceIndex >= 0 &&
        _activeSentenceIndex < _smartChunks.length) {
      if (_smartChunks[_activeSentenceIndex].contains(compressedPhrase)) {
        return compressedPhrase;
      }
    }
    for (final chunk in _smartChunks) {
      if (chunk.contains(compressedPhrase)) {
        return compressedPhrase;
      }
    }

    String pattern = compressedPhrase
        .split('')
        .map((c) => RegExp.escape(c))
        .join(r'\s*');

    final regex = RegExp(pattern, caseSensitive: false);

    if (_activeSentenceIndex >= 0 &&
        _activeSentenceIndex < _smartChunks.length) {
      try {
        final match = regex.firstMatch(_smartChunks[_activeSentenceIndex]);
        if (match != null) {
          return _smartChunks[_activeSentenceIndex].substring(
            match.start,
            match.end,
          );
        }
      } catch (_) {}
    }

    for (String chunk in _smartChunks) {
      try {
        final match = regex.firstMatch(chunk);
        if (match != null) {
          return chunk.substring(match.start, match.end);
        }
      } catch (_) {}
    }

    return compressedPhrase;
  }

  void _handlePhraseSelected(String phrase, Offset pos, VoidCallback clear) {
    final restoredPhrase = _restoreSpaces(phrase);

    _activeSelectionClearer?.call();
    _activeSelectionClearer = clear;

    _activateCard(
      restoredPhrase,
      ReaderUtils.generateCleanId(restoredPhrase),
      pos,
      isPhrase: true,
    );
  }

  void _activateCard(
    String text,
    String cleanId,
    Offset pos, {
    required bool isPhrase,
  }) {
    // 1. Pause Video if playing
    if (_isVideo || _isAudio || _isYoutubeAudio) {
      _wasPlayingBeforeCard = _isPlaying;
      if (_isPlaying) {
        _pauseMedia();
      }
    }

    // 2. Stop any existing Lesson TTS loop
    if (_isTtsPlaying) {
      _flutterTts.stop();
      setState(() => _isTtsPlaying = false);
    }

    // 3. Play word/phrase TTS immediately
    _flutterTts.speak(text);

    // 4. Show Card
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    final svc = context.read<TranslationService>();
    setState(() {
      _showCard = true;
      _selectedText = text;
      _selectedCleanId = cleanId;
      _isSelectionPhrase = isPhrase;
      _cardAnchor = pos;
      _cardTranslationFuture = svc
          .translate(text, user.nativeLanguage, widget.lesson.language)
          .then((v) => v ?? "");
    });
  }

  Widget _buildTranslationOverlay() {
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    final existing = _isSelectionPhrase ? null : _vocabulary[_selectedCleanId];

    if (!_isFullScreen) {
      return FloatingTranslationCard(
        key: ValueKey(_selectedText), // This was already correct
        originalText: _selectedText,
        translationFuture: _cardTranslationFuture!,
        onGetAiExplanation: () => Gemini.instance
            .prompt(
              parts: [
                Part.text(
                  "Explain '$_selectedText' in ${widget.lesson.language} for ${user.nativeLanguage} speaker",
                ),
              ],
            )
            .then((v) => v?.output)
            .catchError((_) => "AI Error"),
        targetLanguage: widget.lesson.language,
        nativeLanguage: user.nativeLanguage,
        currentStatus: existing?.status ?? 0,
        anchorPosition: _cardAnchor,
        onUpdateStatus: (s, t) {
          _updateWordStatus(_selectedCleanId, _selectedText, t, s);
          _closeTranslationCard();
        },
        onClose: _closeTranslationCard,
      );
    }

    return FullscreenTranslationCard(
      // -----------------------------------------------------------
      // FIX: Add a ValueKey here based on the selected text/ID.
      // This forces the widget to rebuild completely when the word changes.
      // -----------------------------------------------------------
      key: ValueKey("$_selectedText$_selectedCleanId"),

      originalText: _selectedText,
      translationFuture: _cardTranslationFuture!,
      onGetAiExplanation: () => Gemini.instance
          .prompt(
            parts: [
              Part.text(
                "Explain '$_selectedText' in ${widget.lesson.language} for ${user.nativeLanguage} speaker",
              ),
            ],
          )
          .then((v) => v?.output)
          .catchError((_) => "AI Error"),
      targetLanguage: widget.lesson.language,
      nativeLanguage: user.nativeLanguage,
      currentStatus: existing?.status ?? 0,
      onUpdateStatus: (s, t) {
        _updateWordStatus(_selectedCleanId, _selectedText, t, s);
      },
      onClose: _closeTranslationCard,
    );
  }

  Future<void> _checkLimitAndActivate(
    String uid,
    String cid,
    String w,
    Offset p,
    bool phrase,
  ) async {
    setState(() => _isCheckingLimit = true);
    final access = await _checkAndIncrementFreeLimit(uid);
    setState(() => _isCheckingLimit = false);
    if (access)
      _activateCard(w, cid, p, isPhrase: phrase);
    else
      _showLimitDialog();
  }

  Future<bool> _checkAndIncrementFreeLimit(String uid) async => true;
  void _showLimitDialog() =>
      showDialog(context: context, builder: (c) => const PremiumLockDialog());

  Future<void> _updateWordStatus(
    String clean,
    String orig,
    String trans,
    int status, {
    bool showDialog = true,
  }) async {
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;

    // --- VIDEO SRS DATA CAPTURE ---
    String? videoUrl;
    double? timestamp;
    String? sentenceContext;

    if (_isVideo || _isAudio || _isYoutubeAudio) {
      videoUrl = widget.lesson.videoUrl;

      // Capture timestamp from current active sentence start time
      if (_activeSentenceIndex != -1 &&
          _activeSentenceIndex < _activeTranscript.length) {
        timestamp = _activeTranscript[_activeSentenceIndex].start;
        sentenceContext = _activeTranscript[_activeSentenceIndex].text;
      }
    }

    final item = VocabularyItem(
      id: clean,
      userId: user.id,
      word: clean,
      baseForm: clean,
      language: widget.lesson.language,
      translation: trans,
      status: status,
      timesEncountered: 1,
      lastReviewed: DateTime.now(),
      createdAt: DateTime.now(),
      // Store Video Context
      sourceVideoUrl: videoUrl,
      timestamp: timestamp,
      sentenceContext: sentenceContext,
    );

    setState(() => _vocabulary[clean] = item);
    context.read<VocabularyBloc>().add(VocabularyUpdateRequested(item));

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.id)
        .collection('vocabulary')
        .doc(clean)
        .set({
          'status': status,
          'translation': trans,
          'lastReviewed': FieldValue.serverTimestamp(),
          // Store Video Context in Firestore
          'sourceVideoUrl': videoUrl,
          'timestamp': timestamp,
          'sentenceContext': sentenceContext,
        }, SetOptions(merge: true));

    if (showDialog && !_hasSeenStatusHint) {
      setState(() => _hasSeenStatusHint = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Word status updated"),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  int _calculateSmartStatus(VocabularyItem? item) {
    if (item == null || item.status == 0) return 1;
    if (item.status >= 5) return 5;
    if (DateTime.now().difference(item.lastReviewed).inHours >= 1)
      return item.status + 1;
    return item.status;
  }

  Future<void> _handleTranslationToggle() async {
    if (_googleTranslation != null || _myMemoryTranslation != null) {
      setState(() {
        _googleTranslation = null;
        _myMemoryTranslation = null;
      });
      return;
    }
    String text = (_activeSentenceIndex < _smartChunks.length)
        ? _smartChunks[_activeSentenceIndex]
        : "";
    if (text.isEmpty) return;
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    setState(() {
      _isLoadingTranslation = true;
      _showError = false;
    });
    try {
      final g = await context.read<TranslationService>().translate(
        text,
        user.nativeLanguage,
        widget.lesson.language,
      );
      final m = await MyMemoryService.translate(
        text: text,
        sourceLang: widget.lesson.language,
        targetLang: user.nativeLanguage,
      );
      if (mounted)
        setState(() {
          _googleTranslation = g;
          _myMemoryTranslation = m;
          _isLoadingTranslation = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _isLoadingTranslation = false;
          _showError = true;
        });
    }
  }

  void _handleSwipeMarking(int index) {
    if (!_autoMarkOnSwipe || index < 0 || index >= _smartChunks.length) return;
    for (var w in _smartChunks[index].split(RegExp(r'(\s+)'))) {
      final c = ReaderUtils.generateCleanId(w);
      if (c.isNotEmpty && (_vocabulary[c]?.status ?? 0) == 0)
        _updateWordStatus(c, w.trim(), "", 5, showDialog: false);
    }
  }

  void _showGeminiHint() => showDialog(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text("Use Gemini"),
      content: const Text("Analyze this screen with Gemini!"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text("OK")),
      ],
    ),
  );

  void _resetTranslationState() {
    _googleTranslation = null;
    _myMemoryTranslation = null;
    _isLoadingTranslation = false;
    _showError = false;
  }

  void _scrollToActiveLine(int index) {
    if (index >= 0 &&
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

  // --- FULLSCREEN LOGIC ---

  // SHARED PLAYER: Reuses the exact same widget instance via GlobalKey
  Widget _buildSharedPlayer() {
    Widget playerWidget;

    if (_isLocalMedia && _localVideoController != null) {
      playerWidget = Video(
        controller: _localVideoController!,
        // We use our custom overlay exclusively now
        controls: NoVideoControls,
      );
    } else if (_youtubeController != null) {
      playerWidget = YoutubePlayer(
        controller: _youtubeController!,
        showVideoProgressIndicator: false,
        width: MediaQuery.of(context).size.width,
      );
    } else {
      return const SizedBox.shrink();
    }

    // Keep it wrapped in a Container with the GlobalKey to prevent reparenting issues
    return Container(
      key: _videoPlayerKey,
      color: Colors.black,
      child: playerWidget,
    );
  }

  void _toggleCustomFullScreen() {
    setState(() => _isTransitioningFullscreen = true);

    final bool targetState = !_isFullScreen;
    setState(() => _isFullScreen = targetState);

    if (targetState) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    }

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _isTransitioningFullscreen = false);
    });
  }

  Widget _buildYoutubeAudioControls() {
    final duration = _youtubeController?.metadata.duration ?? Duration.zero;
    final position = _youtubeController?.value.position ?? Duration.zero;
    final max = duration.inSeconds.toDouble();
    final value = position.inSeconds.toDouble().clamp(0.0, max);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF222222),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(
                  _isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                ),
                iconSize: 48,
                color: Colors.white,
                onPressed: _isPlaying ? _pauseMedia : _playMedia,
              ),
              Expanded(
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                      ),
                      child: Slider(
                        value: value,
                        min: 0,
                        max: max > 0 ? max : 1,
                        activeColor: Colors.red,
                        inactiveColor: Colors.grey[700],
                        onChanged: (v) {
                          _seekToTime(v);
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(position),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 10,
                            ),
                          ),
                          Text(
                            _formatDuration(duration),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  @override
  Widget build(BuildContext context) {
    // A. FULLSCREEN WIDGET
    if (_isFullScreen && (_isVideo || _isAudio || _isYoutubeAudio)) {
      return _buildFullscreenMedia();
    }

    // B. PORTRAIT WIDGET
    final settings = context.watch<SettingsBloc>().state;
    final themeData = Theme.of(context).copyWith(
      scaffoldBackgroundColor: settings.readerTheme == ReaderTheme.dark
          ? const Color(0xFF1E1E1E)
          : Colors.white,
      appBarTheme: AppBarTheme(
        backgroundColor: settings.readerTheme == ReaderTheme.dark
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        iconTheme: IconThemeData(
          color: settings.readerTheme == ReaderTheme.dark
              ? Colors.white
              : Colors.black,
        ),
      ),
      textTheme: Theme.of(context).textTheme.apply(
        bodyColor: settings.readerTheme == ReaderTheme.dark
            ? Colors.white
            : Colors.black,
      ),
    );

    final displayLesson = widget.lesson.copyWith(
      sentences: _smartChunks,
      transcript: _activeTranscript,
    );

    return Theme(
      data: themeData,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: Text(widget.lesson.title),
          actions: [
            IconButton(
              icon: Icon(
                _isListeningMode ? Icons.hearing : Icons.hearing_disabled,
              ),
              onPressed: () =>
                  setState(() => _isListeningMode = !_isListeningMode),
            ),
            if (!(_isVideo || _isAudio || _isYoutubeAudio) && !_isSentenceMode)
              IconButton(
                icon: Icon(
                  _isPlaying || _isTtsPlaying ? Icons.pause : Icons.play_arrow,
                ),
                onPressed: _toggleTtsFullLesson,
              ),
            // Menu: Swipe Toggle AND Captions Toggle
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'toggle_swipe') {
                  setState(() => _autoMarkOnSwipe = !_autoMarkOnSwipe);
                  final user =
                      (context.read<AuthBloc>().state as AuthAuthenticated)
                          .user;
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.id)
                      .collection('preferences')
                      .doc('reader')
                      .set({
                        'autoMarkOnSwipe': _autoMarkOnSwipe,
                      }, SetOptions(merge: true));
                } else if (value == 'toggle_cc') {
                  _toggleSubtitles();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'toggle_swipe',
                  child: Row(
                    children: [
                      Icon(
                        _autoMarkOnSwipe
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        color: Theme.of(context).iconTheme.color,
                      ),
                      const SizedBox(width: 8),
                      const Text('Auto-mark on swipe'),
                    ],
                  ),
                ),
                if (_isVideo || _isAudio || _isYoutubeAudio)
                  PopupMenuItem(
                    value: 'toggle_cc',
                    child: Row(
                      children: [
                        Icon(
                          _showSubtitles
                              ? Icons.closed_caption
                              : Icons.closed_caption_off,
                          color: Theme.of(context).iconTheme.color,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _showSubtitles ? 'Hide Captions' : 'Show Captions',
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // --- HEADER AREA ---
                  if (_isVideo || _isAudio || _isYoutubeAudio)
                    Container(
                      width: double.infinity,
                      color: Colors.black,
                      child: _isYoutubeAudio
                          // 1. YOUTUBE AUDIO: Video Hidden + Custom Controls
                          // Use IndexedStack to hide video but keep it active
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  height: 1,
                                  child: IndexedStack(
                                    index: 0,
                                    children: [
                                      _buildSharedPlayer(),
                                      Container(color: Colors.black),
                                    ],
                                  ),
                                ),
                                _buildYoutubeAudioControls(),
                              ],
                            )
                          : _isAudio
                          // 2. NORMAL AUDIO (FILE/LOCAL)
                          ? ReaderMediaHeader(
                              isInitializing: _isInitializingMedia,
                              isAudio: true,
                              isLocalMedia: _isLocalMedia,
                              localVideoController: null,
                              localPlayer: _localPlayer,
                              youtubeController: _youtubeController,
                              onToggleFullscreen: _toggleCustomFullScreen,
                            )
                          // 3. VIDEO MODE (YOUTUBE VIDEO OR FILE VIDEO)
                          : AspectRatio(
                              aspectRatio: 16 / 9,
                              child: GestureDetector(
                                onTap: _toggleControls,
                                // --- NEW: SWIPE UP TO ENTER FULL SCREEN ---
                                onVerticalDragEnd: (details) {
                                  // Check for Upward Swipe (Negative Velocity)
                                  if (details.primaryVelocity != null &&
                                      details.primaryVelocity! < -400) {
                                    _toggleCustomFullScreen();
                                  }
                                },
                                child: Stack(
                                  children: [
                                    _buildSharedPlayer(),
                                    VideoControlsOverlay(
                                      isPlaying: _isPlaying,
                                      position:
                                          (_isSeeking &&
                                              _optimisticPosition != null)
                                          ? _optimisticPosition!
                                          : (_isLocalMedia &&
                                                    _localPlayer != null
                                                ? _localPlayer!.state.position
                                                : (_youtubeController
                                                          ?.value
                                                          .position ??
                                                      Duration.zero)),
                                      duration:
                                          _isLocalMedia && _localPlayer != null
                                          ? _localPlayer!.state.duration
                                          : (_youtubeController
                                                    ?.metadata
                                                    .duration ??
                                                Duration.zero),
                                      showControls: _showControls,
                                      onPlayPause: _isPlaying
                                          ? _pauseMedia
                                          : _playMedia,
                                      onSeekRelative: _seekRelative,
                                      onSeekTo: (d) => _seekToTime(
                                        d.inMilliseconds / 1000.0,
                                      ),
                                      onToggleFullscreen:
                                          _toggleCustomFullScreen,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ),

                  if (_isCheckingLimit || _isParsingSubtitles)
                    const LinearProgressIndicator(minHeight: 2),

                  Expanded(
                    child: _isParsingSubtitles
                        ? const Center(child: Text("Loading content..."))
                        : _isSentenceMode
                        ? NotificationListener<ScrollNotification>(
                            // 1. Wrap Sentence Mode
                            onNotification: (scrollInfo) {
                              // Check if at bottom
                              if (scrollInfo.metrics.pixels >=
                                  scrollInfo.metrics.maxScrollExtent - 50) {
                                _markLessonAsComplete();
                              }
                              return false;
                            },
                            child: NotificationListener<ScrollNotification>(
                              // 2. Wrap Paragraph Mode
                              onNotification: (scrollInfo) {
                                // Check if at bottom
                                if (scrollInfo.metrics.pixels >=
                                    scrollInfo.metrics.maxScrollExtent - 50) {
                                  _markLessonAsComplete();
                                }
                                return false;
                              },
                              child: SentenceModeView(
                                chunks: _smartChunks,
                                activeIndex: _activeSentenceIndex,
                                vocabulary: _vocabulary,
                                isVideo:
                                    _isVideo || _isAudio || _isYoutubeAudio,
                                isPlaying:
                                    _isPlaying || _isPlayingSingleSentence,
                                isTtsPlaying: _isTtsPlaying,
                                onTogglePlayback: _togglePlayback,
                                onPlayFromStartContinuous:
                                    _playFromStartContinuous,
                                onPlayContinuous: _playNextContinuous,
                                onNext: _goToNextSentence,
                                onPrev: _goToPrevSentence,
                                onWordTap: _handleWordTap,
                                onPhraseSelected: _handlePhraseSelected,
                                isLoadingTranslation: _isLoadingTranslation,
                                googleTranslation: _googleTranslation,
                                myMemoryTranslation: _myMemoryTranslation,
                                showError: _showError,
                                onRetryTranslation: _handleTranslationToggle,
                                onTranslateRequest: _handleTranslationToggle,
                                isListeningMode: _isListeningMode,
                              ),
                            ),
                          )
                        : ParagraphModeView(
                            lesson: displayLesson,
                            bookPages: _bookPages,
                            activeSentenceIndex: _activeSentenceIndex,
                            currentPage: _currentPage,
                            vocabulary: _vocabulary,
                            isVideo: _isVideo || _isAudio || _isYoutubeAudio,
                            listScrollController: _listScrollController,
                            pageController: _pageController,
                            onPageChanged: (i) =>
                                setState(() => _currentPage = i),
                            onSentenceTap: (i) {
                              if ((_isVideo || _isAudio || _isYoutubeAudio) &&
                                  i < _activeTranscript.length) {
                                _seekToTime(_activeTranscript[i].start);
                                _playMedia();
                              } else
                                _speakSentence(_smartChunks[i], i);
                            },
                            onVideoSeek: (t) => _seekToTime(t),
                            onWordTap: _handleWordTap,
                            onPhraseSelected: _handlePhraseSelected,
                            isListeningMode: _isListeningMode,
                            itemKeys: _itemKeys,
                          ),
                  ),
                ],
              ),
              Positioned(
                bottom: 24,
                right: 24,
                child: FloatingActionButton(
                  backgroundColor: Theme.of(context).primaryColor,
                  onPressed: () =>
                      setState(() => _isSentenceMode = !_isSentenceMode),
                  child: Icon(
                    _isSentenceMode ? Icons.menu_book : Icons.short_text,
                    color: Colors.white,
                  ),
                ),
              ),

              // --- TAP OUTSIDE BARRIER (Portrait) ---
              if (_showCard && !_isFullScreen)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _closeTranslationCard,
                    child: Container(color: Colors.transparent),
                  ),
                ),

              if (_showCard && _cardTranslationFuture != null && !_isFullScreen)
                _buildTranslationOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullscreenMedia() {
    return WillPopScope(
      onWillPop: () async {
        _toggleCustomFullScreen();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          // --- EXISTING CONTROLS ---
          onTap: _toggleControls,
          onDoubleTapDown: (details) {
            final w = MediaQuery.of(context).size.width;
            if (details.globalPosition.dx < w / 3) {
              _seekRelative(-10);
            } else if (details.globalPosition.dx > (w * 2 / 3)) {
              _seekRelative(10);
            } else {
              _toggleControls();
            }
          },

          // --- NEW: SWIPE DOWN TO EXIT ---
          onVerticalDragEnd: (details) {
            // Check if the velocity is downward (positive) and strong enough
            if (details.primaryVelocity != null &&
                details.primaryVelocity! > 400) {
              _toggleCustomFullScreen();
            }
          },

          child: Stack(
            alignment: Alignment.center,
            fit: StackFit.expand,
            children: [
              Center(
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _buildSharedPlayer(),
                ),
              ),

              if (_showCard)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _closeTranslationCard,
                  child: Container(color: Colors.black.withOpacity(0.5)),
                ),

              if (_showSubtitles)
                Positioned(
                  bottom: _showControls ? 60 : 20,
                  left: 80,
                  right: 80,
                  child: _buildInteractiveSubtitleOverlay(),
                ),

              if (!_showCard)
                VideoControlsOverlay(
                  isPlaying: _isPlaying,
                  position: (_isSeeking && _optimisticPosition != null)
                      ? _optimisticPosition!
                      : (_isLocalMedia && _localPlayer != null
                            ? _localPlayer!.state.position
                            : (_youtubeController?.value.position ??
                                  Duration.zero)),
                  duration: _isLocalMedia && _localPlayer != null
                      ? _localPlayer!.state.duration
                      : (_youtubeController?.metadata.duration ??
                            Duration.zero),
                  showControls: _showControls,
                  onPlayPause: _isPlaying ? _pauseMedia : _playMedia,
                  onSeekRelative: _seekRelative,
                  onSeekTo: (d) => _seekToTime(d.inMilliseconds / 1000.0),
                  onToggleFullscreen: _toggleCustomFullScreen,
                ),

              if (!_showCard)
                Positioned(
                  bottom: 100,
                  left: 15,
                  child: SafeArea(
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black45,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.replay, color: Colors.white),
                        onPressed: _replayPreviousSentence,
                      ),
                    ),
                  ),
                ),

              if (!_showCard && _showControls) ...[
                Positioned(
                  top: 20,
                  right: 20,
                  child: SafeArea(
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black45,
                      ),
                      child: IconButton(
                        icon: Icon(
                          _showSubtitles
                              ? Icons.closed_caption
                              : Icons.closed_caption_off,
                          color: _showSubtitles ? Colors.white : Colors.grey,
                        ),
                        onPressed: _toggleSubtitles,
                      ),
                    ),
                  ),
                ),
              ],

              if (_showCard && _cardTranslationFuture != null)
                _buildTranslationOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  void _replayPreviousSentence() {
    // 1. Fallback if no transcript is available
    if (_activeTranscript.isEmpty) {
      _seekRelative(-5);
      return;
    }

    // 2. Calculate previous index
    int targetIndex = _activeSentenceIndex - 1;
    if (targetIndex < 0) targetIndex = 0;

    // 3. Update state and seek
    setState(() {
      _activeSentenceIndex = targetIndex;
      // Reset translation state since we moved to a new line
      _resetTranslationState();
    });

    // 4. Seek to the start of that sentence and ensure playing
    _seekToTime(_activeTranscript[targetIndex].start);
    if (!_isPlaying) {
      _playMedia();
    }
  }

  Widget _buildInteractiveSubtitleOverlay() {
    if (!_showSubtitles ||
        _activeSentenceIndex == -1 ||
        _activeSentenceIndex >= _smartChunks.length) {
      return const SizedBox.shrink();
    }
    return Center(
      child: Container(
        decoration: BoxDecoration(),
        child: InteractiveTextDisplay(
          text: _smartChunks[_activeSentenceIndex],
          sentenceIndex: _activeSentenceIndex,
          vocabulary: _vocabulary,
          onWordTap: _handleWordTap,
          onPhraseSelected: _handlePhraseSelected,
          isBigMode: true,
          isListeningMode: false,
          isOverlay: true,
        ),
      ),
    );
  }
}
