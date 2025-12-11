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

  // --- Media Players ---
  YoutubePlayerController? _youtubeController;
  Player? _localPlayer;
  VideoController? _localVideoController;
  Timer? _syncTimer;

  // --- Media State ---
  bool _isVideo = false;
  bool _isAudio = false;
  bool _isLocalMedia = false;
  bool _isInitializingMedia = false;
  bool _isParsingSubtitles = true;
  bool _isPlaying = false;
  bool _isSeeking = false;
  bool _isPlayingSingleSentence = false;

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
    if (!_isTransitioningFullscreen && (_isVideo || _isAudio)) {
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
    if ((_isVideo || _isAudio) && widget.lesson.videoUrl != null) {
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
    WidgetsBinding.instance.removeObserver(this);
    _syncTimer?.cancel();
    _controlsHideTimer?.cancel();
    _localPlayer?.dispose();
    _youtubeController?.dispose();
    _pageController.dispose();
    _listScrollController.dispose();
    _flutterTts.stop();
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
    if (widget.lesson.id.startsWith('yt_audio_'))
      videoId = widget.lesson.id.replaceAll('yt_audio_', '');
    else if (widget.lesson.id.startsWith('yt_'))
      videoId = widget.lesson.id.replaceAll('yt_', '');
    else
      videoId = YoutubePlayer.convertUrlToId(url);

    if (videoId != null) {
      _youtubeController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
          enableCaption: false,
          hideControls: false,
          disableDragSeek: false,
          loop: false,
          isLive: false,
          forceHD: false,
        ),
      );
      setState(() {
        _isLocalMedia = false;
        _isVideo = true;
      });
      _startSyncTimer();
    }
  }

  Future<void> _initializeLocalMediaPlayer(String path) async {
    setState(() => _isInitializingMedia = true);
    try {
      _localPlayer = Player();
      _localVideoController = VideoController(_localPlayer!);
      await _localPlayer!.open(Media(path));

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
    setState(() => _isSeeking = true);
    final d = Duration(milliseconds: (seconds * 1000).toInt());

    if (_isLocalMedia && _localPlayer != null) {
      await _localPlayer!.seek(d);
    } else if (_youtubeController != null) {
      _youtubeController!.seekTo(d);
    }

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _isSeeking = false);
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
      if ((_isVideo || _isAudio) &&
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
      if ((_isVideo || _isAudio) &&
          _activeTranscript.isNotEmpty &&
          prev < _activeTranscript.length) {
        _seekToTime(_activeTranscript[prev].start);
        _playMedia();
      }
    }
  }

  void _playFromStartContinuous() {
    if (_isVideo || _isAudio) {
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
    if (_isVideo || _isAudio) {
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
    if (_isVideo || _isAudio) {
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

  void _closeTranslationCard() {
    if (_showCard) {
      _activeSelectionClearer?.call();
      setState(() {
        _showCard = false;
        _activeSelectionClearer = null;
      });

      // RESUME: Check if video was playing before card opened
      if (_wasPlayingBeforeCard && (_isVideo || _isAudio)) {
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

  void _handlePhraseSelected(String phrase, Offset pos, VoidCallback clear) {
    _activeSelectionClearer?.call();
    _activeSelectionClearer = clear;
    _activateCard(
      phrase,
      ReaderUtils.generateCleanId(phrase),
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
    if (_isVideo || _isAudio) {
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

  // --- CARD BUILDER ---
  Widget _buildTranslationOverlay() {
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    final existing = _isSelectionPhrase ? null : _vocabulary[_selectedCleanId];

    if (!_isFullScreen) {
      return FloatingTranslationCard(
        key: ValueKey(_selectedText),
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

  @override
  Widget build(BuildContext context) {
    // A. FULLSCREEN WIDGET
    if (_isFullScreen && (_isVideo || _isAudio)) {
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
            if (!(_isVideo || _isAudio) && !_isSentenceMode)
              IconButton(
                icon: Icon(
                  _isPlaying || _isTtsPlaying ? Icons.pause : Icons.play_arrow,
                ),
                onPressed: _toggleTtsFullLesson,
              ),
            IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // --- HEADER AREA ---
                  if (_isVideo || _isAudio)
                    Container(
                      width: double.infinity,
                      color: Colors.black,
                      child: _isAudio
                          ? ReaderMediaHeader(
                              isInitializing: _isInitializingMedia,
                              isAudio: true,
                              isLocalMedia: _isLocalMedia,
                              localVideoController: null,
                              localPlayer: _localPlayer,
                              youtubeController: _youtubeController,
                              onToggleFullscreen: _toggleCustomFullScreen,
                            )
                          // VIDEO: Use Shared Player in Portrait
                          : AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Stack(
                                children: [
                                  _buildSharedPlayer(),
                                  Positioned(
                                    bottom: 8,
                                    right: 8,
                                    child: GestureDetector(
                                      onTap: _toggleCustomFullScreen,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.fullscreen,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),

                  if (_isCheckingLimit || _isParsingSubtitles)
                    const LinearProgressIndicator(minHeight: 2),

                  Expanded(
                    child: _isParsingSubtitles
                        ? const Center(child: Text("Loading content..."))
                        : _isSentenceMode
                        ? SentenceModeView(
                            chunks: _smartChunks,
                            activeIndex: _activeSentenceIndex,
                            vocabulary: _vocabulary,
                            isVideo: _isVideo || _isAudio,
                            isPlaying: _isPlaying || _isPlayingSingleSentence,
                            isTtsPlaying: _isTtsPlaying,
                            onTogglePlayback: _togglePlayback,
                            onPlayFromStartContinuous: _playFromStartContinuous,
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
                            lesson: displayLesson,
                            bookPages: _bookPages,
                            activeSentenceIndex: _activeSentenceIndex,
                            currentPage: _currentPage,
                            vocabulary: _vocabulary,
                            isVideo: _isVideo || _isAudio,
                            listScrollController: _listScrollController,
                            pageController: _pageController,
                            onPageChanged: (i) =>
                                setState(() => _currentPage = i),
                            onSentenceTap: (i) {
                              if ((_isVideo || _isAudio) &&
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
          onTap: _toggleControls,
          onDoubleTapDown: (details) {
            final w = MediaQuery.of(context).size.width;
            if (details.globalPosition.dx < w / 3)
              _seekRelative(-10);
            else if (details.globalPosition.dx > (w * 2 / 3))
              _seekRelative(10);
            else
              _toggleControls();
          },
          child: Stack(
            alignment: Alignment.center,
            fit: StackFit.expand,
            children: [
              // SHARED PLAYER - State Preserved via Key
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

              Positioned(
                bottom: _showControls ? 60 : 20,
                left: 80,
                right: 80,
                child: _buildInteractiveSubtitleOverlay(),
              ),

              if (!_showCard)
                VideoControlsOverlay(
                  isPlaying: _isPlaying,
                  position: _isLocalMedia && _localPlayer != null
                      ? _localPlayer!.state.position
                      : (_youtubeController?.value.position ?? Duration.zero),
                  duration: _isLocalMedia && _localPlayer != null
                      ? _localPlayer!.state.duration
                      : (_youtubeController?.metadata.duration ??
                            Duration.zero),
                  showControls: _showControls,
                  onPlayPause: _isPlaying ? _pauseMedia : _playMedia,
                  onSeekRelative: _seekRelative,
                  onSeekTo: (d) {
                    _resetControlsTimer();
                    if (_isLocalMedia)
                      _localPlayer?.seek(d);
                    else
                      _youtubeController?.seekTo(d);
                  },
                  onToggleFullscreen: _toggleCustomFullScreen,
                ),

              if (!_showCard && _showControls)
                Positioned(
                  top: 20,
                  left: 20,
                  child: SafeArea(
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black45,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: _toggleCustomFullScreen,
                      ),
                    ),
                  ),
                ),

              if (_showCard && _cardTranslationFuture != null)
                _buildTranslationOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInteractiveSubtitleOverlay() {
    if (_activeSentenceIndex == -1 ||
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
