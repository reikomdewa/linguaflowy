import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:linguaflow/blocs/auth/auth_event.dart';
import 'package:linguaflow/blocs/auth/auth_state.dart';
import 'package:linguaflow/services/local_lemmatizer.dart';
import 'package:linguaflow/services/repositories/lesson_repository.dart'; // Needed for playlist fetch
import 'package:linguaflow/utils/language_helper.dart';
import 'package:linguaflow/utils/utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart' as mobile;
import 'package:youtube_player_iframe/youtube_player_iframe.dart' as web;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

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

class ReaderScreenWeb extends StatefulWidget {
  final LessonModel lesson;
  const ReaderScreenWeb({super.key, required this.lesson});

  @override
  _ReaderScreenWebState createState() => _ReaderScreenWebState();
}

class _ReaderScreenWebState extends State<ReaderScreenWeb>
    with WidgetsBindingObserver {
  // --- Data & Config ---
  Map<String, VocabularyItem> _vocabulary = {};

  // Playlist State for Desktop
  List<LessonModel> _playlistLessons = [];
  bool _isLoadingPlaylist = false;

  final Set<String> _sessionWordsLearned = {};

  bool _autoMarkOnSwipe = false;
  bool _hasSeenStatusHint = false;
  bool _isListeningMode = false;
  bool _hasMarkedLessonComplete = false;
  bool _showSubtitles = true;

  // --- Media Players ---
  // Mobile Controller
  mobile.YoutubePlayerController? _mobileYoutubeController;
  // Web Controller
  web.YoutubePlayerController? _webYoutubeController;
  Player? _localPlayer;
  VideoController? _localVideoController;
  Timer? _syncTimer;
  Timer? _listeningTrackingTimer;
  int _secondsListenedInSession = 0;

  bool _isVideo = false;
  bool _isAudio = false;
  bool _isYoutubeAudio = false;
  bool _isLocalMedia = false;
  bool _isInitializingMedia = false;
  bool _isParsingSubtitles = true;
  bool _isPlaying = false;
  bool _isSeeking = false;
  bool _isPlayingSingleSentence = false;

  Duration? _optimisticPosition;
  Timer? _seekResetTimer;
  bool _wasPlayingBeforeCard = false;

  bool _isFullScreen = false;
  bool _isTransitioningFullscreen = false;
  final GlobalKey _videoPlayerKey = GlobalKey();

  bool _showControls = false;
  Timer? _controlsHideTimer;

  final FlutterTts _flutterTts = FlutterTts();
  bool _isTtsPlaying = false;
  final double _ttsSpeed = 0.5;

  final ScrollController _listScrollController = ScrollController();
  int _activeSentenceIndex = -1;
  final PageController _pageController = PageController();
  List<List<int>> _bookPages = [];
  int _currentPage = 0;
  List<GlobalKey> _itemKeys = [];
  List<String> _smartChunks = [];
  List<TranscriptLine> _activeTranscript = [];
  bool _isSentenceMode = false;

  String? _googleTranslation;
  String? _myMemoryTranslation;
  bool _isLoadingTranslation = false;
  bool _showError = false;
  bool _isCheckingLimit = false;

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

  static const int xpPerMinuteRead = 2;
  // --- ADD THESE NEW VARIABLES ---
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isLimitDialogOpen = false;

 @override
  void initState() {
    super.initState();

    _authBloc = context.read<AuthBloc>();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    
    // --- 1. CHECK GUEST ACCESS LIMITS ---
    _checkGuestAccess(); 

    LocalLemmatizer().load(widget.lesson.language);
    
    // Only start stream if NOT guest (Guests don't have Firestore vocab)
    if (!_authBloc.state.isGuest) {
      _startVocabularyStream();
      _loadUserPreferences();
    }
    
    _determineMediaType();

    // Fetch Playlist if needed
    if (widget.lesson.seriesId != null) {
      _fetchSeriesData();
    }

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
  Future<void> _checkGuestAccess() async {
    final state = context.read<AuthBloc>().state;
    if (!state.isGuest) return; // Users are fine

    final prefs = await SharedPreferences.getInstance();
    List<String> viewedLessons = prefs.getStringList('guest_viewed_ids') ?? [];

    // If this lesson is new to the guest
    if (!viewedLessons.contains(widget.lesson.id)) {
      if (viewedLessons.length >= 2) {
        // LIMIT REACHED: Show blocking dialog immediately
        if (mounted) {
           // Delay slightly to ensure context is ready
           Future.delayed(Duration.zero, () => _showGuestBlockingDialog());
        }
      } else {
        // Allow, but track it
        viewedLessons.add(widget.lesson.id);
        await prefs.setStringList('guest_viewed_ids', viewedLessons);
      }
    }
  }

  void _showGuestBlockingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Cannot click away
      builder: (context) => AlertDialog(
        title: const Text("Guest Limit Reached"),
        content: const Text(
          "You have viewed your 2 free preview lessons.\n\nPlease login or create an account to continue learning freely!",
        ),
        actions: [
          TextButton(
            onPressed: () => context.go('/'), // Go Home
            child: const Text("Go Home"),
          ),
          FilledButton(
            onPressed: () => context.push('/login'),
            child: const Text("Login / Sign Up"),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchSeriesData() async {
    if (widget.lesson.seriesId == null) return;
    setState(() => _isLoadingPlaylist = true);

    try {
      final repo = context.read<LessonRepository>();
      final list = await repo.fetchLessonsBySeries(
        widget.lesson.language,
        widget.lesson.seriesId!,
      );
      if (mounted) {
        setState(() {
          _playlistLessons = list;
          _isLoadingPlaylist = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingPlaylist = false);
    }
  }

  // ... [Existing didChangeMetrics, dispose, tracking methods remain exactly the same] ...

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // Only auto-fullscreen on mobile
    final isDesktop = MediaQuery.of(context).size.width > 900;
    if (isDesktop) return;

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

  // ... [Include all your existing initialization, media control, seek, sync methods here unchanged] ...
  // To save space in this answer, I am omitting methods like _determineMediaType, _initializeMedia,
  // _checkSync, _markLessonAsComplete, etc. Assume they are present exactly as in your provided code.
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
    _flutterTts.setLanguage(widget.lesson.language);
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

  // --- HELPER: START/STOP TRACKING ---
  void _startListeningTracker() {
    _listeningTrackingTimer?.cancel();
    _listeningTrackingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _secondsListenedInSession++;
      if (_secondsListenedInSession % 300 == 0) {
        context.read<AuthBloc>().add(AuthUpdateXP(xpPerMinuteRead * 2));
        _logActivitySession(5, xpPerMinuteRead * 2);
      }
    });
  }

  void _stopListeningTracker() {
    _listeningTrackingTimer?.cancel();
  }

  @override
  void dispose() {
    _stopListeningTracker();
    _vocabSubscription?.cancel();
    if (_secondsListenedInSession > 10) {
      final int minutes = (_secondsListenedInSession / 60).ceil();
      _authBloc.add(AuthUpdateListeningTime(minutes));
    }
    if (kIsWeb) {
      _webYoutubeController?.close();
    } else {
      _mobileYoutubeController?.dispose();
    }
    WidgetsBinding.instance.removeObserver(this);
    _syncTimer?.cancel();
    _seekResetTimer?.cancel();
    _controlsHideTimer?.cancel();

    if (_localPlayer != null) {
      try {
        _localPlayer!.stop();
        _localPlayer!.dispose();
      } catch (e) {}
    }
    _localVideoController = null;
    _localPlayer = null;

    _flutterTts.stop();
    _pageController.dispose();
    _listScrollController.dispose();

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

  // --- MARK COMPLETE & XP LOGIC ---
  void _markLessonAsComplete() {
    if (!_hasMarkedLessonComplete) {
      setState(() => _hasMarkedLessonComplete = true);
      _pauseMedia();
      if (_isTtsPlaying) _flutterTts.stop();

      const int baseXP = 5;
      const int bonusPerWord = 3;
      int calculatedXp = (baseXP + (_sessionWordsLearned.length * bonusPerWord))
          .clamp(50, 200);

      context.read<AuthBloc>().add(AuthUpdateXP(calculatedXp));
      context.read<AuthBloc>().add(AuthIncrementLessonsCompleted());
      _logActivitySession(0, calculatedXp);
    }
  }

  // --- VOCABULARY STREAM ---
  void _startVocabularyStream() {
    final state = context.read<AuthBloc>().state;
    if (state is! AuthAuthenticated) return;
    final user = state.user;

    _vocabSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.id)
        .collection('vocabulary')
        .snapshots(includeMetadataChanges: true)
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

  // ... [Other loading/init methods skipped for brevity, include them from your original code] ...
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
    final int limit = LanguageHelper.getItemsPerPage(widget.lesson.language);

    for (int i = 0; i < _smartChunks.length; i++) {
      String s = _smartChunks[i];
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
      videoId = mobile.YoutubePlayer.convertUrlToId(url);
    }

    if (videoId != null) {
      if (kIsWeb) {
        // --- WEB STRICT CONFIGURATION ---
        _webYoutubeController = web.YoutubePlayerController.fromVideoId(
          videoId: videoId,
          params: const web.YoutubePlayerParams(
            showControls: false, // Hides bottom bar
            showFullscreenButton: false, // Hides FS button
            playsInline: true, // <--- CRITICAL: Prevents native player override
            showVideoAnnotations: false, // Hides info cards
            strictRelatedVideos: true,
            mute: false,
            // 'color': 'white' // Sometimes helps force "Modest" mode
          ),
        );

        _webYoutubeController!.listen((event) {
          final isPlaying = event.playerState == web.PlayerState.playing;
          if (isPlaying != _isPlaying) {
            setState(() {
              _isPlaying = isPlaying;
              if (isPlaying) {
                // When playing starts, we can show OUR controls
                _showControls = true;
                _resetControlsTimer();
              }
            });
          }
          if (event.playerState == web.PlayerState.ended) {
            _markLessonAsComplete();
          }
        });
      } else {
        // --- MOBILE APP CONFIGURATION ---
        _mobileYoutubeController = mobile.YoutubePlayerController(
          initialVideoId: videoId,
          flags: const mobile.YoutubePlayerFlags(
            autoPlay: false,
            mute: false,
            enableCaption: false,
            hideControls: true,
            controlsVisibleAtStart: false,
            disableDragSeek: true,

            forceHD: false,
          ),
        );
      }
      setState(() {
        _isLocalMedia = false;
        _isVideo = !_isYoutubeAudio;
      });
      _startSyncTimer();
    }
  }

  // Update this getter to be safer
  bool get _isYoutubePlaying {
    if (kIsWeb) {
      // On web, checking value directly can be stale.
      // Reliance on the stream listener (above) is better,
      // but for polling, we check the generic value.
      return _webYoutubeController?.value.playerState ==
          web.PlayerState.playing;
    }
    return _mobileYoutubeController?.value.isPlaying ?? false;
  }

  Future<double> get _youtubeCurrentTimeInSeconds async {
    if (kIsWeb && _webYoutubeController != null) {
      return await _webYoutubeController!.currentTime;
    }
    if (_mobileYoutubeController != null) {
      return _mobileYoutubeController!.value.position.inMilliseconds / 1000.0;
    }
    return 0.0;
  }

  Future<double> get _youtubeTotalDurationInSeconds async {
    if (kIsWeb && _webYoutubeController != null) {
      return await _webYoutubeController!.duration;
    }
    if (_mobileYoutubeController != null) {
      return _mobileYoutubeController!.metadata.duration.inSeconds.toDouble();
    }
    return 0.0;
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

  // [Include _checkSync, _pauseMedia, _playMedia, _seekRelative, _seekToTime, _toggleControls, _resetControlsTimer]
  // Assumed existing
  Future<void> _checkSync() async {
    if (_isSeeking || _isTransitioningFullscreen) return;

    bool isPlaying = false;
    double currentSeconds = 0.0;
    double totalSeconds = 0.0;

    // 1. Fetch Data
    if (_isLocalMedia && _localPlayer != null) {
      isPlaying = _localPlayer!.state.playing;
      currentSeconds = _localPlayer!.state.position.inMilliseconds / 1000.0;
      totalSeconds = _localPlayer!.state.duration.inSeconds.toDouble();
    } else if (kIsWeb && _webYoutubeController != null) {
      isPlaying = _isPlaying;
      try {
        currentSeconds = await _webYoutubeController!.currentTime;
        totalSeconds = await _webYoutubeController!.duration;
      } catch (e) {
        return;
      }
    } else if (!kIsWeb && _mobileYoutubeController != null) {
      isPlaying = _mobileYoutubeController!.value.isPlaying;
      currentSeconds =
          _mobileYoutubeController!.value.position.inMilliseconds / 1000.0;
      totalSeconds = _mobileYoutubeController!.metadata.duration.inSeconds
          .toDouble();
    } else {
      return;
    }

    if (!mounted) return;

    // 2. Update UI
    setState(() {
      _isPlaying = isPlaying;
      _currentPosition = Duration(
        milliseconds: (currentSeconds * 1000).toInt(),
      );
      _totalDuration = Duration(milliseconds: (totalSeconds * 1000).toInt());
    });

    if (isPlaying)
      _startListeningTracker();
    else
      _stopListeningTracker();

    // 3. Check Completion (Skip math check on Web)
    if ((_isVideo || _isAudio || _isYoutubeAudio) && totalSeconds > 0) {
      if (!kIsWeb) {
        if (totalSeconds > 10 && currentSeconds > 0.5) {
          if (currentSeconds >= totalSeconds - 2) _markLessonAsComplete();
        }
      }
    }

    // 4. Transcript Logic (Kept same)
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

    bool shouldSync =
        MediaQuery.of(context).size.width > 900 || !_isSentenceMode;
    if (shouldSync) {
      int activeIndex = -1;
      if (_activeSentenceIndex != -1 &&
          _activeSentenceIndex < _activeTranscript.length &&
          currentSeconds >= _activeTranscript[_activeSentenceIndex].start &&
          currentSeconds < _activeTranscript[_activeSentenceIndex].end) {
        activeIndex = _activeSentenceIndex;
      } else {
        for (int i = 0; i < _activeTranscript.length; i++) {
          if (currentSeconds >= _activeTranscript[i].start &&
              currentSeconds < _activeTranscript[i].end) {
            activeIndex = i;
            break;
          }
        }
      }
      if (activeIndex == -1) {
        for (int i = 0; i < _activeTranscript.length; i++) {
          if (_activeTranscript[i].start > currentSeconds) {
            activeIndex = i > 0 ? i - 1 : 0;
            break;
          }
        }
        if (activeIndex == -1 && _activeTranscript.isNotEmpty)
          activeIndex = _activeTranscript.length - 1;
      }
      if (activeIndex != -1 && activeIndex != _activeSentenceIndex) {
        setState(() {
          _activeSentenceIndex = activeIndex;
          _resetTranslationState();
        });
        if (MediaQuery.of(context).size.width <= 900)
          _scrollToActiveLine(activeIndex);
      }
    }
  }

  void _pauseMedia() {
    if (_isLocalMedia && _localPlayer != null) {
      _localPlayer!.pause();
    } else if (kIsWeb) {
      _webYoutubeController?.pauseVideo();
    } else {
      _mobileYoutubeController?.pause();
    }
    _resetControlsTimer();
  }

  void _playMedia() {
    if (_isLocalMedia && _localPlayer != null) {
      _localPlayer!.play();
    } else if (kIsWeb) {
      _webYoutubeController?.playVideo();
    } else {
      _mobileYoutubeController?.play();
    }
    _resetControlsTimer();
  }

  Future<void> _seekToTime(double seconds) async {
    _seekResetTimer?.cancel();
    final d = Duration(milliseconds: (seconds * 1000).toInt());

    // Set UI to optimistic state immediately
    setState(() {
      _isSeeking = true;
      _optimisticPosition = d;
      _currentPosition = d; // Force UI update
    });

    if (_isLocalMedia && _localPlayer != null) {
      await _localPlayer!.seek(d);
    } else if (kIsWeb) {
      // Web uses Seconds (double)
      _webYoutubeController?.seekTo(seconds: seconds, allowSeekAhead: true);
    } else {
      // Mobile uses Duration
      _mobileYoutubeController?.seekTo(d);
    }

    // Reset seeking flag after a delay to allow player to catch up
    _seekResetTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _isSeeking = false;
          _optimisticPosition = null;
        });
      }
    });
  }

  // Update _seekRelative similarly
  void _seekRelative(int offsetSeconds) async {
    // Use the Unified variables we are already tracking!
    double currentSeconds = _currentPosition.inMilliseconds / 1000.0;
    double totalSeconds = _totalDuration.inMilliseconds / 1000.0;

    double newPos = currentSeconds + offsetSeconds;

    if (newPos < 0) newPos = 0;
    if (totalSeconds > 0 && newPos > totalSeconds) newPos = totalSeconds;

    await _seekToTime(newPos);
    _resetControlsTimer();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _resetControlsTimer();
    }
  }

  void _resetControlsTimer() {
    _controlsHideTimer?.cancel();
    _controlsHideTimer = Timer(const Duration(seconds: 3), () {
      // Only auto-hide if:
      // 1. The widget is still active (mounted)
      // 2. The video is PLAYING (don't hide play button if paused)
      // 3. The user is NOT actively scrubbing/seeking
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

    final authState = context.read<AuthBloc>().state;
    
    // --- GUEST LOGIC START ---
    if (authState.isGuest) {
      _checkGuestTapLimit(word, cleanId, pos, isPhrase: false);
      return;
    }
    // --- GUEST LOGIC END ---

    final user = authState.user; // Safe because we checked isGuest
    
    // Existing Logic for Users...
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
    if (user!.isPremium) {
      _activateCard(word, cleanId, pos, isPhrase: false);
    } else {
      _checkLimitAndActivate(user.id, cleanId, word, pos, false);
    }
  }
  String _restoreSpaces(String compressedPhrase) {
    if (_activeSentenceIndex >= 0 &&
        _activeSentenceIndex < _smartChunks.length) {
      if (_smartChunks[_activeSentenceIndex].contains(compressedPhrase))
        return compressedPhrase;
    }
    for (final chunk in _smartChunks) {
      if (chunk.contains(compressedPhrase)) return compressedPhrase;
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
        if (match != null)
          return _smartChunks[_activeSentenceIndex].substring(
            match.start,
            match.end,
          );
      } catch (_) {}
    }
    for (String chunk in _smartChunks) {
      try {
        final match = regex.firstMatch(chunk);
        if (match != null) return chunk.substring(match.start, match.end);
      } catch (_) {}
    }
    return compressedPhrase;
  }

void _handlePhraseSelected(String phrase, Offset pos, VoidCallback clear) {
    final restoredPhrase = _restoreSpaces(phrase);
    _activeSelectionClearer?.call();
    _activeSelectionClearer = clear;
    
    final authState = context.read<AuthBloc>().state;
    
    // --- GUEST LOGIC START ---
    if (authState.isGuest) {
       _checkGuestTapLimit(
         restoredPhrase, 
         ReaderUtils.generateCleanId(restoredPhrase), 
         pos, 
         isPhrase: true
       );
       return;
    }
    // --- GUEST LOGIC END ---

    final user = authState.user;
    
    if (user!.isPremium) {
      _activateCard(
        restoredPhrase,
        ReaderUtils.generateCleanId(restoredPhrase),
        pos,
        isPhrase: true,
      );
    } else {
      _checkLimitAndActivate(
        user.id,
        ReaderUtils.generateCleanId(restoredPhrase),
        restoredPhrase,
        pos,
        true,
      );
    }
  }
  Future<void> _checkGuestTapLimit(
    String text,
    String cleanId,
    Offset pos, {
    required bool isPhrase,
  }) async {
    setState(() => _isCheckingLimit = true);
    
    final prefs = await SharedPreferences.getInstance();
    
    // Get today's usage for guest
    final todayStr = DateTime.now().toIso8601String().split('T').first;
    final lastDate = prefs.getString('guest_tap_date') ?? '';
    int currentCount = prefs.getInt('guest_tap_count') ?? 0;

    // Reset if new day
    if (lastDate != todayStr) {
      currentCount = 0;
      await prefs.setString('guest_tap_date', todayStr);
    }

    setState(() => _isCheckingLimit = false);

    const int guestLimit = 5; // Allow 5 clicks

    if (currentCount < guestLimit) {
      // Increment and Allow
      await prefs.setInt('guest_tap_count', currentCount + 1);
      
      // Activate card directly (No saving to Firestore for guests)
      _activateCard(text, cleanId, pos, isPhrase: isPhrase);
    } else {
      // Block
      _showLimitDialog(isGuest: true);
    }
  }

  void _activateCard(
    String text,
    String cleanId,
    Offset pos, {
    required bool isPhrase,
  }) {
    if (_isVideo || _isAudio || _isYoutubeAudio) {
      _wasPlayingBeforeCard = _isPlaying;
      if (_isPlaying) _pauseMedia();
    }
    if (_isTtsPlaying) {
      _flutterTts.stop();
      setState(() => _isTtsPlaying = false);
    }
    _flutterTts.speak(text);
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    final svc = context.read<TranslationService>();
    final String lemma = isPhrase ? text : LocalLemmatizer().getLemma(text);
    setState(() {
      _showCard = true;
      _selectedText = text;
      _selectedCleanId = cleanId;
      _selectedBaseForm = lemma;
      _isSelectionPhrase = isPhrase;
      _cardAnchor = pos;
      _cardTranslationFuture = svc
          .translate(text, user.nativeLanguage, widget.lesson.language)
          .then((v) => v ?? "");
    });
  }

  // [Include _buildTranslationOverlay, _checkLimitAndActivate, _logActivitySession, _updateWordStatus, etc.]
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

  static const int _dailyLookupsLimit = 5;
  Future<bool> _checkAndIncrementFreeLimit(String uid) async {
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
          transaction.set(usageRef, {'date': todayStr, 'count': 1});
          return true;
        }
        final data = snapshot.data() as Map<String, dynamic>;
        final String lastDate = data['date'] ?? '';
        final int currentCount = data['count'] ?? 0;
        if (lastDate != todayStr) {
          transaction.set(usageRef, {'date': todayStr, 'count': 1});
          return true;
        } else {
          if (currentCount < _dailyLookupsLimit) {
            transaction.update(usageRef, {'count': currentCount + 1});
            return true;
          } else {
            return false;
          }
        }
      });
    } catch (e) {
      return false;
    }
  }

  // Simple toggle now
void _showLimitDialog({bool isGuest = false}) {
    _pauseMedia();
    
    if (isGuest) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Guest Limit Reached"),
          content: const Text("You have used your 5 free translations for today.\n\nPlease login to get more!"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.go('/login');
              },
              child: const Text("Login"),
            ),
          ],
        ),
      );
    } else {
      // Original Premium Lock Dialog logic
      setState(() => _isLimitDialogOpen = true);
    }
  }

  // The Manual Stack Overlay
  Widget _buildLimitDialogOverlay() {
    return Stack(
      children: [
        // 1. Barrier
        GestureDetector(
          onTap: () => setState(() => _isLimitDialogOpen = false),
          child: Container(
            color: Colors.black.withOpacity(0.8),
          ), // Darker background since video is hidden
        ),

        // 2. Dialog
        Positioned.fill(
          child: PointerInterceptor(
            child: PremiumLockDialog(
              onClose: () => setState(() => _isLimitDialogOpen = false),
              onSuccess: () {
                setState(() => _isLimitDialogOpen = false);
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _logActivitySession(int minutes, int xpGained) async {
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    final dateId = DateTime.now().toIso8601String().split('T').first;
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

  int _calculateSmartStatus(VocabularyItem? item) {
    if (item == null || item.status == 0) return 1;
    if (item.status >= 5) return 5;
    if (DateTime.now().difference(item.lastReviewed).inHours >= 1)
      return item.status + 1;
    return item.status;
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
    final existingItem = _vocabulary[clean];
    final int oldStatus = existingItem?.status ?? 0;
    int xpGained = LanguageHelper.calculateSmartXP(
      word: orig,
      langCode: widget.lesson.language,
      oldStatus: existingItem?.status ?? 0,
      newStatus: status,
      userLevel: user.currentLevel,
    );
    DateTime? learnedAt = existingItem?.learnedAt;
    if (learnedAt == null && oldStatus == 0 && status > 0)
      learnedAt = DateTime.now();
    if (xpGained > 0) {
      context.read<AuthBloc>().add(AuthUpdateXP(xpGained));
    }
    final item = VocabularyItem(
      id: clean,
      userId: user.id,
      word: orig,
      baseForm: detectedBaseForm,
      language: widget.lesson.language,
      translation: trans,
      status: status,
      timesEncountered: (existingItem?.timesEncountered ?? 0) + 1,
      lastReviewed: DateTime.now(),
      createdAt: existingItem?.createdAt ?? DateTime.now(),
      learnedAt: learnedAt,
      sourceVideoUrl: videoUrl,
      timestamp: timestamp,
      sentenceContext: sentenceContext,
    );
    setState(() {
      _vocabulary[clean] = item;
      if (status > 0) _sessionWordsLearned.add(clean);
    });
    context.read<VocabularyBloc>().add(VocabularyUpdateRequested(item));
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
          'learnedAt': learnedAt != null ? Timestamp.fromDate(learnedAt) : null,
          'sourceVideoUrl': videoUrl,
          'timestamp': timestamp,
          'sentenceContext': sentenceContext,
        }, SetOptions(merge: true));
    if (showDialog && !_hasSeenStatusHint) {
      setState(() => _hasSeenStatusHint = true);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Word status updated"),
            duration: Duration(seconds: 1),
          ),
        );
    }
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
    final tokens = LanguageHelper.tokenizeText(
      _smartChunks[index],
      widget.lesson.language,
    );
    for (var w in tokens) {
      if (w.trim().isEmpty) continue;
      final c = ReaderUtils.generateCleanId(w);
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

  // --- BUILD METHOD: BRANCHING LOGIC ---
  @override
  Widget build(BuildContext context) {
    if (_isFullScreen && (_isVideo || _isAudio || _isYoutubeAudio)) {
      return _buildFullscreenMedia();
    }

    // 1. Theme Setup
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

    // 2. Prepare Data
    final displayLesson = widget.lesson.copyWith(
      sentences: _smartChunks,
      transcript: _activeTranscript,
    );

    // 3. Detect Platform
    final bool isDesktop = MediaQuery.of(context).size.width > 900;

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
              // Keep existing actions (Audio, Settings, etc.)
              IconButton(
                icon: Icon(
                  _isListeningMode ? Icons.hearing : Icons.hearing_disabled,
                ),
                onPressed: () =>
                    setState(() => _isListeningMode = !_isListeningMode),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'toggle_cc') _toggleSubtitles();
                  // Add other actions
                },
                itemBuilder: (context) => [
                  if (_isVideo || _isAudio || _isYoutubeAudio)
                    PopupMenuItem(
                      value: 'toggle_cc',
                      child: Text(
                        _showSubtitles ? 'Hide Captions' : 'Show Captions',
                      ),
                    ),
                ],
              ),
            ],
          ),
          body: isDesktop
              ? _buildDesktopBody(settings.readerTheme == ReaderTheme.dark)
              : _buildMobileBody(
                  displayLesson,
                  settings.readerTheme == ReaderTheme.dark,
                ),
        ),
      ),
    );
  }

  // --- MOBILE BODY (Existing Layout) ---
  Widget _buildMobileBody(LessonModel displayLesson, bool isDark) {
    const int baseXP = 50;
    const int bonusPerWord = 10;
    int currentXp = (baseXP + (_sessionWordsLearned.length * bonusPerWord))
        .clamp(50, 200);
    return SafeArea(
      child: Stack(
        children: [
          Column(
            children: [
              // Mobile Media Player
              if (_isVideo || _isAudio || _isYoutubeAudio)
                _buildMobilePlayerContainer(),

              if (_isCheckingLimit || _isParsingSubtitles)
                const LinearProgressIndicator(minHeight: 2),

              Expanded(
                child: _isParsingSubtitles
                    ? const Center(child: Text("Loading content..."))
                    : NotificationListener<ScrollNotification>(
                        onNotification: (scrollInfo) {
                          // Existing Scroll Logic
                          return false;
                        },
                        child: _isSentenceMode
                            ? SentenceModeView(
                                lessonTitle: widget.lesson.title,
                                onComplete: _markLessonAsComplete,
                                wordsLearnedCount: _sessionWordsLearned.length,
                                xpEarned: currentXp,
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
                              )
                            : ParagraphModeView(
                                onComplete: _markLessonAsComplete,
                                wordsLearnedCount: _sessionWordsLearned.length,
                                xpEarned: currentXp,
                                lesson: displayLesson,
                                bookPages: _bookPages,
                                activeSentenceIndex: _activeSentenceIndex,
                                currentPage: _currentPage,
                                vocabulary: _vocabulary,
                                isVideo:
                                    _isVideo || _isAudio || _isYoutubeAudio,
                                listScrollController: _listScrollController,
                                pageController: _pageController,
                                onPageChanged: (i) =>
                                    setState(() => _currentPage = i),
                                onSentenceTap: (i) {
                                  if ((_isVideo ||
                                          _isAudio ||
                                          _isYoutubeAudio) &&
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
                              ),
                      ),
              ),
            ],
          ),

          // Floating Action Button
          Positioned(
            bottom: 24,
            right: 24,
            child: FloatingActionButton(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              onPressed: () =>
                  setState(() => _isSentenceMode = !_isSentenceMode),
              child: Icon(
                _isSentenceMode ? Icons.menu_book : Icons.short_text,
                color: Colors.white,
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
          if (_showCard && _cardTranslationFuture != null && !_isFullScreen)
            _buildTranslationOverlay(),
        ],
      ),
    );
  }

  void _showControlsOnInteraction() {
    // Only verify state to prevent unnecessary rebuilds
    if (!_showControls) {
      setState(() => _showControls = true);
    }
    // Always reset the timer when interaction happens
    _resetControlsTimer();
  }

  // --- DESKTOP BODY (New Layout) ---
  Widget _buildDesktopBody(bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            children: [
              Expanded(
                flex: 4,
                child: Container(
                  color: Colors.black, // Background when video is hidden
                  child: MouseRegion(
                    onEnter: (_) => _showControlsOnInteraction(),
                    onHover: (_) => _showControlsOnInteraction(),
                    child: Stack(
                      children: [
                        // 1. VIDEO PLAYER (Hidden when dialog is open)
                        // This prevents the Iframe from stealing input focus
                        Center(
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Visibility(
                              visible:
                                  !_isLimitDialogOpen, // Hide when dialog is open
                              maintainState: true, // Keep video loaded
                              maintainAnimation: true,
                              maintainSize: true,
                              child: _buildSharedPlayer(),
                            ),
                          ),
                        ),

                        // 2. CONTROLS (Only show if video is visible)
                        if (!_isLimitDialogOpen)
                          IgnorePointer(
                            ignoring: !_showControls,
                            child: VideoControlsOverlay(
                              isPlaying: _isPlaying,
                              position:
                                  (_isSeeking && _optimisticPosition != null)
                                  ? _optimisticPosition!
                                  : _currentPosition,
                              duration: _totalDuration,
                              showControls: _showControls,
                              onPlayPause: _isPlaying
                                  ? _pauseMedia
                                  : _playMedia,
                              onSeekRelative: _seekRelative,
                              onSeekTo: (d) =>
                                  _seekToTime(d.inMilliseconds / 1000.0),
                              onToggleFullscreen: _toggleCustomFullScreen,
                            ),
                          ),

                        // 3. DIALOG OVERLAY (Top)
                        if (_isLimitDialogOpen) _buildLimitDialogOverlay(),
                      ],
                    ),
                  ),
                ),
              ),
              // ... subtitle area ...
              Expanded(
                flex: 1,
                child: Container(
                  width: double.infinity,
                  color: isDark
                      ? const Color(0xFF121212)
                      : const Color(0xFFF0F0F0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  alignment: Alignment.center,
                  child: _buildDesktopSubtitleArea(isDark),
                ),
              ),
            ],
          ),
        ),
        // ... sidebar ...
        if (widget.lesson.seriesId != null)
          Container(
            width: 350,
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: isDark ? Colors.white12 : Colors.grey[300]!,
                ),
              ),
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            ),
            child: _buildDesktopPlaylistSidebar(isDark),
          ),
      ],
    );
  }

  // --- DESKTOP SUBTITLE AREA ---
  Widget _buildDesktopSubtitleArea(bool isDark) {
    // 1. Safety Check: If data isn't loaded yet, show a loader.
    if (_smartChunks.isEmpty) {
      return Center(
        child: Text(
          "Loading text...",
          style: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
        ),
      );
    }

    // 2. Logic: Which sentence to display?
    // If _activeSentenceIndex is -1 (not started/silence), default to 0 (the first sentence).
    // This ensures there is ALWAYS text for the user to click.
    int displayIndex = _activeSentenceIndex;
    if (displayIndex < 0 || displayIndex >= _smartChunks.length) {
      displayIndex = 0;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // The Interactive Text (Always Visible)
        InteractiveTextDisplay(
          text: _smartChunks[displayIndex],
          sentenceIndex: displayIndex, // Use our safe 'displayIndex'
          vocabulary: _vocabulary,
          language: widget.lesson.language,
          onWordTap: _handleWordTap,
          onPhraseSelected: _handlePhraseSelected,
          isBigMode: true, // Large text for desktop
          isListeningMode: false,
          isOverlay: false,
        ),

        const SizedBox(height: 24), // Added a bit more breathing room
        // Translation Area (Only appears when a word is clicked)
        // We use AnimatedOpacity so it doesn't jump around when appearing
        AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: _showCard ? 1.0 : 0.0,
          child: _showCard
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? Colors.white10
                          : Colors.blueAccent.withOpacity(0.2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: FutureBuilder<String>(
                    future: _cardTranslationFuture,
                    builder: (context, snapshot) {
                      String translationContent = "";
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      } else if (snapshot.hasData) {
                        translationContent = snapshot.data!;
                      }

                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _selectedText,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward,
                            size: 16,
                            color: isDark ? Colors.white54 : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            translationContent,
                            style: TextStyle(
                              fontSize: 16,
                              color: isDark
                                  ? Colors.blueAccent[100]
                                  : Colors.blue[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                )
              : const SizedBox(
                  height: 48,
                ), // Placeholder to keep layout stable if you prefer
        ),
      ],
    );
  }

  // --- DESKTOP PLAYLIST SIDEBAR ---
  Widget _buildDesktopPlaylistSidebar(bool isDark) {
    if (_isLoadingPlaylist) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.lesson.seriesTitle ?? "Series Playlist",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              Text(
                "${_playlistLessons.length} Videos",
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: _playlistLessons.length,
            itemBuilder: (context, index) {
              final item = _playlistLessons[index];
              final isCurrent = item.id == widget.lesson.id;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                selected: isCurrent,
                selectedTileColor: isDark
                    ? Colors.blue.withOpacity(0.1)
                    : Colors.blue.withOpacity(0.05),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    width: 80,
                    height: 45,
                    child: item.imageUrl != null
                        ? Image.network(item.imageUrl!, fit: BoxFit.cover)
                        : Container(color: Colors.grey[800]),
                  ),
                ),
                title: Text(
                  "${index + 1}. ${item.title}",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isCurrent
                        ? Colors.blue
                        : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
                onTap: () {
                  if (isCurrent) return;
                  context.push('/lesson/${item.id}', extra: item);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMobilePlayerContainer() {
    return Container(
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
              youtubeController: kIsWeb ? null : _mobileYoutubeController,
              onToggleFullscreen: _toggleCustomFullScreen,
            )
          : AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand, // Ensures video fills the box
                children: [
                  // 1. VIDEO PLAYER
                  Visibility(
                    visible: !_isLimitDialogOpen,
                    maintainState: true,
                    maintainAnimation: true,
                    maintainSize: true,
                    child: IgnorePointer(
                      // WEB LOGIC:
                      // If Playing: Shield UP (true). User taps YOUR controls.
                      // If Paused: Shield DOWN (false). User taps YouTube Play Button.
                      ignoring: !kIsWeb || _isPlaying,
                      child: _buildSharedPlayer(),
                    ),
                  ),

                  // 2. TAP DETECTOR (Mobile Native Only)
                  // On Web, we let the IFrame handle the "Start" tap.
                  if (!kIsWeb)
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: _toggleControls,
                        onVerticalDragEnd: _handleVerticalSwipe,
                        behavior: HitTestBehavior.translucent,
                        child: Container(color: Colors.transparent),
                      ),
                    ),

                  // 3. YOUR CUSTOM CONTROLS
                  // We show these ON TOP of the YouTube player.
                  if (!_isLimitDialogOpen)
                    IgnorePointer(
                      ignoring: !_showControls,
                      child: VideoControlsOverlay(
                        isPlaying: _isPlaying,
                        position: (_isSeeking && _optimisticPosition != null)
                            ? _optimisticPosition!
                            : _currentPosition,
                        duration: _totalDuration,
                        showControls: _showControls,
                        onPlayPause: _isPlaying ? _pauseMedia : _playMedia,
                        onSeekRelative: _seekRelative,
                        onSeekTo: (d) => _seekToTime(d.inMilliseconds / 1000.0),
                        onToggleFullscreen: _toggleCustomFullScreen,
                      ),
                    ),

                  // 4. DIALOG OVERLAY
                  if (_isLimitDialogOpen) _buildLimitDialogOverlay(),
                ],
              ),
            ),
    );
  }

  // --- FULLSCREEN MEDIA (Unchanged from original) ---
  Widget _buildFullscreenMedia() {
    int displayIndex = _activeSentenceIndex;
    if (displayIndex < 0 || displayIndex >= _smartChunks.length) {
      displayIndex = 0;
    }

    final bool hasText = _smartChunks.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.black,
      body: MouseRegion(
        onEnter: (_) => _showControlsOnInteraction(),
        onHover: (_) => _showControlsOnInteraction(),
        child: Stack(
          children: [
            // 1. VIDEO LAYER
            Center(
              child: Visibility(
                visible: !_isLimitDialogOpen,
                maintainState: true,
                maintainAnimation: true,
                maintainSize: true,
                child: _buildSharedPlayer(),
              ),
            ),

            // 2. OPAQUE SHIELD (The Fix for Title/Recommendations)
            // FIX: Only enable this shield on Native Mobile (!kIsWeb).
            // On Web, enabling this shield blocks the "Click to Play" event required
            // by mobile browsers (Safari/Chrome).
            if (!kIsWeb)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _toggleControls,
                  onVerticalDragEnd: _handleVerticalSwipe,
                  behavior: HitTestBehavior.opaque,
                  child: Container(color: Colors.transparent),
                ),
              ),

            // 3. CONTROLS OVERLAY (Bottom)
            if (!_isLimitDialogOpen)
              IgnorePointer(
                ignoring: !_showControls,
                child: VideoControlsOverlay(
                  isPlaying: _isPlaying,
                  position: (_isSeeking && _optimisticPosition != null)
                      ? _optimisticPosition!
                      : _currentPosition,
                  duration: _totalDuration,
                  showControls: _showControls,
                  onPlayPause: _isPlaying ? _pauseMedia : _playMedia,
                  onSeekRelative: _seekRelative,
                  onSeekTo: (d) => _seekToTime(d.inMilliseconds / 1000.0),
                  onToggleFullscreen: _toggleCustomFullScreen,
                ),
              ),

            // 4. SUBTITLES (Above controls)
            if (hasText && _showSubtitles && !_isLimitDialogOpen)
              Positioned(
                left: 24,
                right: 24,
                bottom: 100,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: InteractiveTextDisplay(
                      text: _smartChunks[displayIndex],
                      sentenceIndex: displayIndex,
                      vocabulary: _vocabulary,
                      language: widget.lesson.language,
                      onWordTap: _handleWordTap,
                      onPhraseSelected: _handlePhraseSelected,
                      isBigMode: true,
                      isListeningMode: false,
                      isOverlay: true,
                    ),
                  ),
                ),
              ),

            // 5. REPLAY BUTTON
            if (_showControls && !_isLimitDialogOpen)
              Positioned(
                left: 30,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Material(
                    color: Colors.black.withOpacity(0.5),
                    shape: const CircleBorder(),
                    clipBehavior: Clip.hardEdge,
                    child: InkWell(
                      onTap: () {
                        _resetControlsTimer();
                        _goToPrevSentence();
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: Icon(
                          Icons.replay,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // 6. TRANSLATION CARD
            if (_showCard)
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: SizedBox(
                    width: 600,
                    child: _buildTranslationOverlay(),
                  ),
                ),
              ),

            // 7. DIALOG OVERLAY
            if (_isLimitDialogOpen) _buildLimitDialogOverlay(),
          ],
        ),
      ),
    );
  }

  void _handleVerticalSwipe(DragEndDetails details) {
    // If no velocity data, ignore
    if (details.primaryVelocity == null) return;

    const double sensitivity = 300; // Adjust sensitivity

    // Negative Velocity = Swipe UP (Go Fullscreen)
    if (details.primaryVelocity! < -sensitivity) {
      if (!_isFullScreen) {
        _toggleCustomFullScreen();
      }
    }
    // Positive Velocity = Swipe DOWN (Exit Fullscreen)
    else if (details.primaryVelocity! > sensitivity) {
      if (_isFullScreen) {
        _toggleCustomFullScreen();
      }
    }
  }

  Widget _buildSharedPlayer() {
    Widget playerWidget;

    if (_isLocalMedia && _localVideoController != null) {
      playerWidget = Video(
        controller: _localVideoController!,
        controls: NoVideoControls,
      );
    } else if (kIsWeb && _webYoutubeController != null) {
      // --- WEB PLAYER WIDGET FIX ---
      playerWidget = SizedBox(
        width: double.infinity, // Force full width
        height: double.infinity, // Force full height
        child: web.YoutubePlayer(
          controller: _webYoutubeController!,
          // We don't strictly need aspectRatio here because the parent defines it,
          // but keeping it ensures the iframe internal calculation is correct.
          aspectRatio: 16 / 9,
        ),
      );
    } else if (!kIsWeb && _mobileYoutubeController != null) {
      // --- MOBILE PLAYER WIDGET ---
      playerWidget = mobile.YoutubePlayer(
        controller: _mobileYoutubeController!,
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

  Widget _buildYoutubeAudioControls() {
    final duration =
        _mobileYoutubeController?.metadata.duration ?? Duration.zero;
    final position = _mobileYoutubeController?.value.position ?? Duration.zero;
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
                    Slider(
                      value: value,
                      min: 0,
                      max: max > 0 ? max : 1,
                      activeColor: Colors.red,
                      inactiveColor: Colors.grey[700],
                      onChanged: (v) {
                        _seekToTime(v);
                      },
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

  void _toggleCustomFullScreen() {
    setState(() => _isTransitioningFullscreen = true);

    final bool targetState = !_isFullScreen;
    setState(() => _isFullScreen = targetState);

    // FIX: Only change orientation on Mobile devices
    final bool isMobile =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android);

    if (isMobile) {
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
    }

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _isTransitioningFullscreen = false);
    });
  }
}
