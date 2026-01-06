import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:linguaflow/blocs/auth/auth_event.dart';
import 'package:linguaflow/blocs/auth/auth_state.dart';
import 'package:linguaflow/services/local_lemmatizer.dart';
import 'package:linguaflow/utils/language_helper.dart';
import 'package:linguaflow/utils/utils.dart';
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

  // Track words marked/learned in THIS session for the result screen
  final Set<String> _sessionWordsLearned = {};

  bool _autoMarkOnSwipe = false;
  bool _hasSeenStatusHint = false;
  bool _isListeningMode = false;

  // Track completion to prevent double triggers
  bool _hasMarkedLessonComplete = false;

  // Subtitle Toggle State
  bool _showSubtitles = true;

  // --- Media Players ---
  YoutubePlayerController? _youtubeController;
  Player? _localPlayer;
  VideoController? _localVideoController;
  Timer? _syncTimer;
  Timer? _listeningTrackingTimer;
  int _secondsListenedInSession = 0;
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

  // --- Swipe Gesture Tracking ---
  double _dragStartX = 0.0;
  double _dragStartY = 0.0;
  DateTime _dragStartTime = DateTime.now();

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
  late AuthBloc _authBloc;

  String? _selectedBaseForm;
  StreamSubscription? _vocabSubscription;
  // XP Reward Constants
  static const int xpPerWordLookup = 5;
  static const int xpPerWordLearned = 20; // When status moves from 0 to > 0
  static const int xpPerMinuteRead = 2; // Passive engagement
  static const int xpPerLessonComplete = 100;
  @override
  void initState() {
    super.initState();

    _authBloc = context.read<AuthBloc>();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    LocalLemmatizer().load(widget.lesson.language);
    _startVocabularyStream();
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
    final bool isYoutubeUrl =
        widget.lesson.videoUrl != null &&
        (widget.lesson.videoUrl!.toLowerCase().contains('youtube.com') ||
            widget.lesson.videoUrl!.toLowerCase().contains('youtu.be'));

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
    // --- FIX START: Always set TTS language immediately ---
    // This ensures that even in Video/Audio mode, tapping a word
    // works correctly on the very first try.
    _flutterTts.setLanguage(widget.lesson.language);
    // --- FIX END ---

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

  @override
  void dispose() {
    _stopListeningTracker();
    _vocabSubscription?.cancel();
    // 2. FLUSH DATA: Send Listening Hours to Bloc
    // FIX: Use '_authBloc' instead of 'context.read<AuthBloc>()'
    if (_secondsListenedInSession > 10) {
      final int minutes = (_secondsListenedInSession / 60).ceil();

      // ✅ SAFE CALL
      _authBloc.add(AuthUpdateListeningTime(minutes));
    }

    // 3. Remove Observers & Timers
    WidgetsBinding.instance.removeObserver(this);
    _syncTimer?.cancel();
    _seekResetTimer?.cancel();
    _controlsHideTimer?.cancel();

    // 4. Dispose Local Player (MediaKit)
    if (_localPlayer != null) {
      try {
        _localPlayer!.stop(); // Stop playback first
        _localPlayer!.dispose(); // Release native resources
      } catch (e) {}
    }
    _localVideoController = null;
    _localPlayer = null;

    // 5. Dispose YouTube Player
    _youtubeController?.dispose();
    _youtubeController = null;

    // 6. Stop TTS & Dispose Controllers
    _flutterTts.stop();
    _pageController.dispose();
    _listScrollController.dispose();

    // 7. Reset System UI
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

  void _startListeningTracker() {
    _listeningTrackingTimer?.cancel();
    _listeningTrackingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _secondsListenedInSession++;

      // Every 5 minutes (300 seconds), give a "Focus Bonus"
      if (_secondsListenedInSession % 300 == 0) {
        context.read<AuthBloc>().add(AuthUpdateXP(xpPerMinuteRead * 5));
        _logActivitySession(5, xpPerMinuteRead * 5); // Log increments
      }
    });
  }

  void _stopListeningTracker() {
    _listeningTrackingTimer?.cancel();
  }

  void _markLessonAsComplete() {
    if (!_hasMarkedLessonComplete) {
      setState(() => _hasMarkedLessonComplete = true);

      // 1. Pause Media
      _pauseMedia();
      if (_isTtsPlaying) _flutterTts.stop();

      // 2. Calculate XP (Same formula used for display)
      const int baseXP = 50;
      const int bonusPerWord = 10;
      int calculatedXp = (baseXP + (_sessionWordsLearned.length * bonusPerWord))
          .clamp(50, 200);

      // 3. Update Database
      context.read<AuthBloc>().add(AuthUpdateXP(calculatedXp));
      context.read<AuthBloc>().add(AuthIncrementLessonsCompleted());
      _logActivitySession(0, calculatedXp);

      // 4. EXIT READER (Since stats are now shown inline)
      Navigator.of(context).pop();
    }
  }

  // --- PRO FIX: Stream Vocabulary ---
  void _startVocabularyStream() {
    final state = context.read<AuthBloc>().state;
    if (state is! AuthAuthenticated) return;
    final user = state.user;

    _vocabSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.id)
        .collection('vocabulary')
        .snapshots(
          includeMetadataChanges: true,
        ) // This ensures cached data emits instantly
        .listen((snapshot) {
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
              learnedAt: ReaderUtils.parseDateTime(data['learnedAt']),
              sourceVideoUrl: data['sourceVideoUrl'],
              timestamp: data['timestamp'],
              sentenceContext: data['sentenceContext'],
            );
          }
          if (mounted) setState(() => _vocabulary = loadedVocab);
        });
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
      for (var t in _activeTranscript) {
        _smartChunks.add(t.text);
      }
      return;
    }
    List<String> rawSentences = widget.lesson.sentences;
    if (rawSentences.isEmpty) {
      // USE HELPER: Gets the correct Regex for the language
      final splitter = LanguageHelper.getSentenceSplitter(
        widget.lesson.language,
      );
      rawSentences = widget.lesson.content.split(splitter);
    }
    for (String sentence in rawSentences) {
      if (sentence.trim().isNotEmpty) _smartChunks.add(sentence.trim());
    }
  }

  void _prepareBookPages() {
    _bookPages = [];
    List<int> currentPageIndices = [];
    int currentCount = 0;

    // USE HELPER: Different page limits for CJK vs Latin
    final int limit = LanguageHelper.getItemsPerPage(widget.lesson.language);

    for (int i = 0; i < _smartChunks.length; i++) {
      String s = _smartChunks[i];

      // USE HELPER: Count chars for CJK, words for others
      int count = LanguageHelper.measureTextLength(s, widget.lesson.language);

      if (currentCount + count > limit && currentPageIndices.isNotEmpty) {
        _bookPages.add(currentPageIndices);
        currentPageIndices = [];
        currentCount = 0;
      }
      currentPageIndices.add(i);
      currentCount += count;
    }
    if (currentPageIndices.isNotEmpty) _bookPages.add(currentPageIndices);
  }

  void _initializeYoutubePlayer(String url) {
    String? videoId;
    if (widget.lesson.id.startsWith('yt_audio_')) {
      videoId = widget.lesson.id.replaceAll('yt_audio_', '');
      _isYoutubeAudio = true;
    } else if (widget.lesson.id.startsWith('yt_')) {
      videoId = widget.lesson.id.replaceAll('yt_', '');
    }

    if (videoId == null || videoId.isEmpty) {
      videoId = YoutubePlayer.convertUrlToId(url);
    }

    if (videoId != null) {
      _youtubeController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: YoutubePlayerFlags(
          autoPlay: false,
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
    double totalDuration = 0.0;

    // 1. Get status from active player
    if (_isLocalMedia && _localPlayer != null) {
      isPlaying = _localPlayer!.state.playing;
      currentSeconds = _localPlayer!.state.position.inMilliseconds / 1000.0;
      totalDuration = _localPlayer!.state.duration.inSeconds.toDouble();
    } else if (_youtubeController != null) {
      isPlaying = _youtubeController!.value.isPlaying;
      currentSeconds =
          _youtubeController!.value.position.inMilliseconds / 1000.0;
      totalDuration = _youtubeController!.metadata.duration.inSeconds
          .toDouble();
    } else {
      return;
    }

    // 2. Handle Play/Pause State Changes & Tracking
    if (isPlaying != _isPlaying) {
      setState(() => _isPlaying = isPlaying);

      // --- TRACKING LOGIC START ---
      if (isPlaying) {
        _startListeningTracker();
      } else {
        _stopListeningTracker();
      }
      // --- TRACKING LOGIC END ---
    }

    // 3. Handle Completion (Media Reached End)
    if ((_isVideo || _isAudio || _isYoutubeAudio) && totalDuration > 0) {
      // If within 2 seconds of the end (and actually playing/moved), mark complete
      if (currentSeconds >= totalDuration - 2) {
        _markLessonAsComplete();
      }
    }

    if (!isPlaying || _activeTranscript.isEmpty) return;

    // 4. Sentence Mode Specific Logic (Pause after single sentence)
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

    // 5. Standard Text Syncing (Highlight active line)
    bool shouldSync = !_isSentenceMode;

    if (shouldSync) {
      int activeIndex = -1;

      // Find current sentence based on time
      for (int i = 0; i < _activeTranscript.length; i++) {
        if (currentSeconds >= _activeTranscript[i].start &&
            currentSeconds < _activeTranscript[i].end) {
          activeIndex = i;
          break;
        }
      }

      // Fallback if inside a gap
      if (activeIndex == -1) {
        for (int i = 0; i < _activeTranscript.length; i++) {
          if (_activeTranscript[i].start > currentSeconds) {
            activeIndex = i > 0 ? i - 1 : 0;
            break;
          }
        }
        // If passed the last sentence
        if (activeIndex == -1 && _activeTranscript.isNotEmpty) {
          activeIndex = _activeTranscript.length - 1;
        }
      }

      // Update UI if changed
      if (activeIndex != -1 && activeIndex != _activeSentenceIndex) {
        setState(() {
          _activeSentenceIndex = activeIndex;
          _resetTranslationState();
        });
        _scrollToActiveLine(activeIndex);
      }
    }
  }

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
      // FIX: Don't auto-play TTS when navigating in sentence mode
      // User must explicitly press play button
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
      // FIX: Don't auto-play TTS when navigating in sentence mode
      // User must explicitly press play button
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
      // FIX: For text lessons in sentence mode, play current sentence only
      if (_activeSentenceIndex >= 0 &&
          _activeSentenceIndex < _smartChunks.length) {
        _speakSentence(
          _smartChunks[_activeSentenceIndex],
          _activeSentenceIndex,
        );
      }
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
      // FIX: For text lessons, advance to next sentence and play it
      if (_activeSentenceIndex < _smartChunks.length - 1) {
        _handleSwipeMarking(_activeSentenceIndex);
        setState(() {
          _activeSentenceIndex++;
          _resetTranslationState();
        });
        // Play the new sentence
        _speakSentence(
          _smartChunks[_activeSentenceIndex],
          _activeSentenceIndex,
        );
      }
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
      // FIX: For text lessons, stop or play current sentence only
      if (_isTtsPlaying) {
        _flutterTts.stop();
        setState(() => _isTtsPlaying = false);
      } else {
        // Play current sentence without auto-advance in sentence mode
        if (_activeSentenceIndex >= 0 &&
            _activeSentenceIndex < _smartChunks.length) {
          _speakSentence(
            _smartChunks[_activeSentenceIndex],
            _activeSentenceIndex,
          );
        }
      }
    }
  }

  void _initializeTts() async {
    await _flutterTts.setLanguage(widget.lesson.language);
    await _flutterTts.setSpeechRate(_ttsSpeed);
    _flutterTts.setCompletionHandler(() {
      // FIX: Check if in sentence mode before auto-advancing
      if (!_isSentenceMode) {
        _playNextTtsSentence();
      } else {
        // In sentence mode, just stop playing after current sentence
        setState(() => _isTtsPlaying = false);
      }
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
    // FIX: Don't scroll in sentence mode (user is already focused on this sentence)
    if (!_isSentenceMode) {
      _scrollToActiveLine(index);
    }
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

  void _closeTranslationCard() {
    if (_showCard) {
      FocusManager.instance.primaryFocus?.unfocus();
      _activeSelectionClearer?.call();
      setState(() {
        _showCard = false;
        _activeSelectionClearer = null;
      });
      if (_wasPlayingBeforeCard && (_isVideo || _isAudio || _isYoutubeAudio)) {
        _playMedia();
      }
      _wasPlayingBeforeCard = false;
    }
  }

  void _handleWordTap(String word, String cleanId, Offset pos) async {
    if (cleanId.trim().isEmpty) return;

    _activeSelectionClearer?.call();
    _activeSelectionClearer = null;
    if (_isCheckingLimit) return;
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;
    final existing = _vocabulary[cleanId];
    final status = _calculateSmartStatus(existing);
    if (existing == null || existing.status != status) {
      _updateWordStatus(
        cleanId,
        word,
        existing?.translation ?? "",
        status,
        showDialog: false,
      );
    }
    if (auth.user.isPremium) {
      _activateCard(word, cleanId, pos, isPhrase: false);
    } else {
      _checkLimitAndActivate(auth.user.id, cleanId, word, pos, false);
    }
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

    // --- NEW LOGIC START ---
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    // Check Premium Status
    if (authState.user.isPremium) {
      _activateCard(
        restoredPhrase,
        ReaderUtils.generateCleanId(restoredPhrase),
        pos,
        isPhrase: true,
      );
    } else {
      // Apply limit check for non-premium users on phrases too
      _checkLimitAndActivate(
        authState.user.id,
        ReaderUtils.generateCleanId(restoredPhrase),
        restoredPhrase,
        pos,
        true, // isPhrase
      );
    }
    // --- NEW LOGIC END ---
  }

  void _activateCard(
    String text,
    String cleanId,
    Offset pos, {
    required bool isPhrase,
  }) {
    if (_isVideo || _isAudio || _isYoutubeAudio) {
      _wasPlayingBeforeCard = _isPlaying;
      if (_isPlaying) {
        _pauseMedia();
      }
    }
    if (_isTtsPlaying) {
      _flutterTts.stop();
      setState(() => _isTtsPlaying = false);
    }
    _flutterTts.speak(text);

    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    final svc = context.read<TranslationService>();

    // --- NEW LOGIC: Get the Base Form ---
    // If it's a phrase, we usually don't lemmatize, so default to text.
    // If it's a word, look it up!
    final String lemma = isPhrase ? text : LocalLemmatizer().getLemma(text);

    setState(() {
      _showCard = true;
      _selectedText = text;
      _selectedCleanId = cleanId;
      _selectedBaseForm = lemma; // <--- Store it here
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
        key: ValueKey(_selectedText),
        originalText: _selectedText,
        baseForm: (_selectedBaseForm != _selectedText)
            ? _selectedBaseForm
            : null,
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
      key: ValueKey("$_selectedText$_selectedCleanId"),
      originalText: _selectedText,
      baseForm: (_selectedBaseForm != _selectedText) ? _selectedBaseForm : null,
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
    if (access) {
      _activateCard(w, cid, p, isPhrase: phrase);
    } else {
      _showLimitDialog();
    }
  }

  // Define your limit constant
  static const int _dailyLookupsLimit = 5;

  Future<bool> _checkAndIncrementFreeLimit(String uid) async {
    // 1. Get today's date string (YYYY-MM-DD) to reset limits daily
    final String todayStr = DateTime.now().toIso8601String().split('T').first;

    final DocumentReference usageRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('usage')
        .doc('dictionary_limit');

    try {
      return await FirebaseFirestore.instance.runTransaction((
        transaction,
      ) async {
        final snapshot = await transaction.get(usageRef);

        if (!snapshot.exists) {
          // First time using it today
          transaction.set(usageRef, {
            'date': todayStr,
            'count': 1, // Count this as the first one
          });
          return true; // ALLOW
        }

        final data = snapshot.data() as Map<String, dynamic>;
        final String lastDate = data['date'] ?? '';
        final int currentCount = data['count'] ?? 0;

        if (lastDate != todayStr) {
          // It's a new day, reset count
          transaction.set(usageRef, {'date': todayStr, 'count': 1});
          return true; // ALLOW
        } else {
          // Same day, check limit
          if (currentCount < _dailyLookupsLimit) {
            transaction.update(usageRef, {'count': currentCount + 1});
            return true; // ALLOW
          } else {
            return false; // DENY
          }
        }
      });
    } catch (e) {
      // In case of error (offline), you might want to allow or deny.
      // Denying prevents exploit, allowing prevents frustration.
      return false;
    }
  }

  void _showLimitDialog() => showDialog(
    context: context,
    builder: (c) => PremiumLockDialog(onClose: () {}),
  );
  Future<void> _logActivitySession(int minutes, int xpGained) async {
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    final dateId = DateTime.now()
        .toIso8601String()
        .split('T')
        .first; // YYYY-MM-DD

    final activityRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.id)
        .collection('activity_log')
        .doc(dateId);

    await activityRef.set({
      'date': Timestamp.now(),
      'totalMinutes': FieldValue.increment(minutes),
      'totalXP': FieldValue.increment(xpGained),
      'lastActive': FieldValue.serverTimestamp(),
      'lessonsInteracted': FieldValue.arrayUnion([widget.lesson.id]),
    }, SetOptions(merge: true));
  }

  int _calculateSmartXp({
    required String word,
    required int oldStatus,
    required int newStatus,
    required String userLevel, // e.g., "A1", "B2"
  }) {
    double multiplier = 1.0;
    int baseReward = 5;

    // 1. COMPLEXITY CHECK (Length proxy)
    // Short words (2-3 chars) are usually basic. Long words are usually harder.
    if (word.length > 8) multiplier += 0.5;
    if (word.length > 12) multiplier += 0.5;

    // 2. STOP-WORD FILTER (Prevent "cheating" by clicking common words)
    // You can expand this list or move it to a utility file
    const commonWords = {
      'the',
      'and',
      'for',
      'that',
      'with',
      'this',
      'have',
      'from',
      'des',
      'les',
      'une',
      'que',
    };
    if (commonWords.contains(word.toLowerCase())) {
      return 1; // Minimum possible XP for "the/a/an"
    }

    // 3. LEVEL CHALLENGE
    // If user is A1/A2 and tackles a long word, give a "Challenge Bonus"
    if ((userLevel.contains('A1') || userLevel.contains('A2')) &&
        word.length > 7) {
      multiplier += 1.0;
    }

    // 4. PROGRESSION REWARD
    int progressionBonus = 0;
    if (oldStatus == 0 && newStatus > 0) {
      progressionBonus = 15; // First time learning this word
    } else if (newStatus > oldStatus) {
      progressionBonus = 5; // Moving from "Learning" to "Mastered"
    }

    // 5. REPETITION PENALTY
    // If looking up a word already at status 5, reduce the base reward
    if (oldStatus >= 5) {
      baseReward = 1;
      progressionBonus = 0;
    }

    return ((baseReward * multiplier) + progressionBonus).round();
  }

  Future<void> _updateWordStatus(
    String clean,
    String orig,
    String trans,
    int status, {
    bool showDialog = true,
  }) async {
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    String detectedBaseForm = LocalLemmatizer().getLemma(orig);
    // 1. Get Video Context (Existing logic)
    String? videoUrl;
    double? timestamp;
    String? sentenceContext;

    if (_isVideo || _isAudio || _isYoutubeAudio) {
      videoUrl = widget.lesson.videoUrl;
      if (_activeSentenceIndex != -1 &&
          _activeSentenceIndex < _activeTranscript.length) {
        timestamp = _activeTranscript[_activeSentenceIndex].start;
        sentenceContext = _activeTranscript[_activeSentenceIndex].text;
      }
    }

    // 2. LOGIC FIX: Determine 'learnedAt'
    // Check local cache for the old status
    final existingItem = _vocabulary[clean];
    final int oldStatus = existingItem?.status ?? 0;

    int xpGained = LanguageHelper.calculateSmartXP(
      word: orig,
      langCode: widget.lesson.language,
      oldStatus: existingItem?.status ?? 0,
      newStatus: status,
      userLevel: user.currentLevel, // This is your string like "A1 - Newcomer"
    );
    // Keep existing date if valid.
    // If null AND we are moving from New(0) to Known(>0), set it to Now.
    DateTime? learnedAt = existingItem?.learnedAt;
    if (learnedAt == null && oldStatus == 0 && status > 0) {
      learnedAt = DateTime.now();
    }
    if (xpGained > 0) {
      context.read<AuthBloc>().add(AuthUpdateXP(xpGained));
    }
    // 3. Create Item with learnedAt
    final item = VocabularyItem(
      id: clean,
      userId: user.id,
      word: orig,
      baseForm: detectedBaseForm,
      language: widget.lesson.language,
      translation: trans,
      status: status,
      timesEncountered:
          (existingItem?.timesEncountered ?? 0) + 1, // Increment count
      lastReviewed: DateTime.now(),
      createdAt: existingItem?.createdAt ?? DateTime.now(),
      // Stats & Context
      learnedAt: learnedAt,
      sourceVideoUrl: videoUrl,
      timestamp: timestamp,
      sentenceContext: sentenceContext,
    );

    // 4. Update UI & Bloc
    setState(() {
      _vocabulary[clean] = item;
      if (status > 0) {
        _sessionWordsLearned.add(clean);
      }
    });

    context.read<VocabularyBloc>().add(VocabularyUpdateRequested(item));

    // 5. Update Firestore (Include learnedAt!)
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.id)
        .collection('vocabulary')
        .doc(clean)
        .set({
          'status': status,
          'xpGained': FieldValue.increment(xpGained),
          'translation': trans,
          'lastReviewed': FieldValue.serverTimestamp(),
          // Save the learnedAt field calculated above
          'learnedAt': learnedAt != null ? Timestamp.fromDate(learnedAt) : null,
          'sourceVideoUrl': videoUrl,
          'timestamp': timestamp,
          'sentenceContext': sentenceContext,
          // Merge to avoid overwriting other fields if any
        }, SetOptions(merge: true));

    if (showDialog && !_hasSeenStatusHint) {
      setState(() => _hasSeenStatusHint = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Word status updated"),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  int _calculateSmartStatus(VocabularyItem? item) {
    if (item == null || item.status == 0) return 1;
    if (item.status >= 5) return 5;
    if (DateTime.now().difference(item.lastReviewed).inHours >= 1) {
      return item.status + 1;
    }
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
      if (mounted) {
        setState(() {
          _googleTranslation = g;
          _myMemoryTranslation = m;
          _isLoadingTranslation = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingTranslation = false;
          _showError = true;
        });
      }
    }
  }

  void _handleSwipeMarking(int index) {
    if (!_autoMarkOnSwipe || index < 0 || index >= _smartChunks.length) return;

    // USE HELPER: Tokenize correctly (chars for CJK, words for others)
    final tokens = LanguageHelper.tokenizeText(
      _smartChunks[index],
      widget.lesson.language,
    );

    for (var w in tokens) {
      if (w.trim().isEmpty) continue;
      final c = ReaderUtils.generateCleanId(w);
      // Ensure we don't accidentally mark a single punctuation mark as a "word"
      if (c.isNotEmpty && (_vocabulary[c]?.status ?? 0) == 0) {
        _updateWordStatus(c, w.trim(), "", 5, showDialog: false);
      }
    }
  }

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

  void _showTutorial() {
    showDialog(
      context: context,
      builder: (context) {
        final PageController controller = PageController();
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                height: 450,
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Expanded(
                      child: PageView(
                        controller: controller,
                        children: [
                          _buildTutorialSlide(
                            icon: Icons.touch_app,
                            title: "Tap to Translate",
                            description:
                                "Tap any word to see its translation. \n\nPremium users see detailed definitions and base forms instantly.",
                          ),
                          _buildTutorialSlide(
                            icon: Icons.swipe,
                            title: "Select Phrases",
                            description:
                                "Drag your finger across multiple words to translate a whole phrase or idiom.",
                          ),
                          _buildTutorialSlide(
                            icon: Icons.signal_cellular_alt,
                            title: "Rank Your Vocabulary",
                            description:
                                "After tapping a word, change its status (New → Learning → Mastered). \n\nThe color changes to track your progress!",
                          ),
                          _buildTutorialSlide(
                            icon: Icons.compare_arrows, // Or Icons.swipe_left
                            title: "Navigate & Swipe",
                            description:
                                "In Sentence Mode, swipe Left/Right to change sentences.\n\nIn Paragraph Mode, scroll naturally like a book.",
                          ),
                          _buildTutorialSlide(
                            icon: Icons.menu_book,
                            title: "Switch Modes",
                            description:
                                "Use the button in the bottom right to switch between:\n\n📖 Paragraph Mode (Reading)\n📝 Sentence Mode (Focus)",
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Close"),
                        ),
                        SmoothPageIndicator(
                          controller: controller,
                          count: 5,
                        ), // Optional: needs package or just use simple dots
                        IconButton(
                          icon: const Icon(Icons.arrow_forward),
                          onPressed: () {
                            if (controller.page! < 4) {
                              controller.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            } else {
                              Navigator.pop(context);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Helper for the slides
  Widget _buildTutorialSlide({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
          child: Icon(icon, size: 40, color: Theme.of(context).primaryColor),
        ),
        const SizedBox(height: 24),
        Text(
          title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Text(
          description,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, height: 1.5),
        ),
      ],
    );
  }

  // Quick fix for the indicator if you don't have the package:
  Widget SmoothPageIndicator({
    required PageController controller,
    required int count,
  }) {
    return Row(
      children: List.generate(
        count,
        (index) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey.withOpacity(0.5),
          ),
        ),
      ),
    );
  }

  // --- FULLSCREEN LOGIC ---
  Widget _buildSharedPlayer() {
    Widget playerWidget;
    if (_isLocalMedia && _localVideoController != null) {
      playerWidget = Video(
        controller: _localVideoController!,
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
    if (_isFullScreen && (_isVideo || _isAudio || _isYoutubeAudio)) {
      return _buildFullscreenMedia();
    }

    const int baseXP = 50;
    const int bonusPerWord = 10;
    int currentXp = (baseXP + (_sessionWordsLearned.length * bonusPerWord))
        .clamp(50, 200);

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
      child: Directionality(
        textDirection: LanguageHelper.isRTL(widget.lesson.language)
            ? TextDirection.rtl
            : TextDirection.ltr,
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
              if (!(_isVideo || _isAudio || _isYoutubeAudio) &&
                  !_isSentenceMode)
                IconButton(
                  icon: Icon(
                    _isPlaying || _isTtsPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                  ),
                  onPressed: _toggleTtsFullLesson,
                ),
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
                  } else if (value == 'show_tutorial') {
                    // --- NEW: Handle the tutorial click ---
                    _showTutorial();
                  }
                },
                itemBuilder: (context) => [
                  // --- NEW: Add the Tutorial Option at the top ---
                  PopupMenuItem(
                    value: 'show_tutorial',
                    child: Row(
                      children: [
                        Icon(
                          Icons.help_outline,
                          color: Theme.of(context).iconTheme.color,
                        ),
                        const SizedBox(width: 8),
                        const Text('How to use'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    height: 1,
                    enabled: false,
                    child: Divider(),
                  ),
                  // ----------------------------------------------
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
                    if (_isVideo || _isAudio || _isYoutubeAudio)
                      Container(
                        width: double.infinity,
                        color: Colors.black,
                        child: _isYoutubeAudio
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
                            ? ReaderMediaHeader(
                                isInitializing: _isInitializingMedia,
                                isAudio: true,
                                isLocalMedia: _isLocalMedia,
                                localVideoController: null,
                                localPlayer: _localPlayer,
                                youtubeController: _youtubeController,
                                onToggleFullscreen: _toggleCustomFullScreen,
                              )
                            : AspectRatio(
                                aspectRatio: 16 / 9,
                                child: GestureDetector(
                                  onTap: _toggleControls,
                                  onVerticalDragEnd: (details) {
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
                                            _isLocalMedia &&
                                                _localPlayer != null
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
                          ? Listener(
                              onPointerDown: (event) {
                                _dragStartX = event.position.dx;
                                _dragStartY = event.position.dy;
                                _dragStartTime = DateTime.now();
                              },
                              onPointerUp: (event) {
                                final dx = event.position.dx - _dragStartX;
                                final dy = event.position.dy - _dragStartY;
                                final duration = DateTime.now()
                                    .difference(_dragStartTime)
                                    .inMilliseconds;

                                if (duration < 300 &&
                                    dx.abs() > 50 &&
                                    dy.abs() < 40) {
                                  if (dx < 0) {
                                    _goToNextSentence(); // Swipe Left
                                  } else {
                                    _goToPrevSentence(); // Swipe Right
                                  }
                                }
                              },
                              child: SentenceModeView(
                                chunks: _smartChunks,
                                activeIndex: _activeSentenceIndex,
                                vocabulary: _vocabulary,
                                language: widget.lesson.language,
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
                                onComplete: _markLessonAsComplete,
                                lessonTitle: widget.lesson.title,
                                wordsLearnedCount: _sessionWordsLearned.length,
                                xpEarned: currentXp,
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
                                } else {
                                  _speakSentence(_smartChunks[i], i);
                                }
                              },
                              onVideoSeek: (t) => _seekToTime(t),
                              onWordTap: _handleWordTap,
                              onPhraseSelected: _handlePhraseSelected,
                              isListeningMode: _isListeningMode,
                              itemKeys: _itemKeys,
                              onComplete: _markLessonAsComplete,
                              wordsLearnedCount: _sessionWordsLearned.length,
                              xpEarned: currentXp,
                            ),
                    ),
                  ],
                ),
                Positioned(
                  bottom: 24,
                  right: 24,
                  child: FloatingActionButton(
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    onPressed: () =>
                        setState(() => _isSentenceMode = !_isSentenceMode),
                    child: Icon(
                      _isSentenceMode ? Icons.menu_book : Icons.short_text,
                    ),
                  ),
                ),
                if (_showCard && !_isFullScreen)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _closeTranslationCard,
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                if (_showCard &&
                    _cardTranslationFuture != null &&
                    !_isFullScreen)
                  _buildTranslationOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFullscreenMedia() {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _toggleCustomFullScreen();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
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
          onVerticalDragEnd: (details) {
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
                  child: Container(color: Colors.black.withValues(alpha: 0.5)),
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
    if (_activeTranscript.isEmpty) {
      _seekRelative(-5);
      return;
    }
    int targetIndex = _activeSentenceIndex - 1;
    if (targetIndex < 0) targetIndex = 0;
    setState(() {
      _activeSentenceIndex = targetIndex;
      _resetTranslationState();
    });
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
          language: widget.lesson.language,
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
