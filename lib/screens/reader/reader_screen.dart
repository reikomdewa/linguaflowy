import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:linguaflow/screens/reader/widgets/reader_media_widgets.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/vocabulary/vocabulary_bloc.dart';
import 'package:linguaflow/blocs/settings/settings_bloc.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/vocabulary_item.dart';
import 'package:linguaflow/models/transcript_line.dart';
import 'package:linguaflow/services/translation_service.dart';
import 'package:linguaflow/services/vocabulary_service.dart';
import 'package:linguaflow/services/mymemory_service.dart';
import 'package:linguaflow/widgets/floating_translation_card.dart';
import 'package:linguaflow/widgets/premium_lock_dialog.dart';
import 'package:linguaflow/widgets/gemini_formatted_text.dart';
import 'package:linguaflow/utils/subtitle_parser.dart';
import 'package:linguaflow/utils/language_helper.dart';

import 'reader_utils.dart';
import 'widgets/reader_view_modes.dart';
import 'widgets/interactive_text_display.dart';

class ReaderScreen extends StatefulWidget {
  final LessonModel lesson;
  const ReaderScreen({super.key, required this.lesson});

  @override
  _ReaderScreenState createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
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
  bool _isFullScreen = false;
  bool _isTransitioningFullscreen = false;
  bool _isPlayingSingleSentence = false;

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

  // ... [Vocabulary Loading & Prefs - Kept Same] ...
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
    _resetControlsTimer(); // Show controls when paused
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

  // --- CONTROLS VISIBILITY LOGIC ---
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

  // ... [Other navigation/audio methods - kept same] ...

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
    if (_isVideo || _isAudio) _pauseMedia();
    if (_isTtsPlaying) _flutterTts.stop();
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

  void _toggleCustomFullScreen() {
    setState(() => _isTransitioningFullscreen = true);

    if (_isFullScreen) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
      setState(() => _isFullScreen = false);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      setState(() => _isFullScreen = true);
    }

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _isTransitioningFullscreen = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullScreen && (_isVideo || _isAudio)) return _buildFullscreenMedia();
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
                  if (_isVideo || _isAudio)
                    ReaderMediaHeader(
                      isInitializing: _isInitializingMedia,
                      isAudio: _isAudio,
                      isLocalMedia: _isLocalMedia,
                      localVideoController: _localVideoController,
                      localPlayer: _localPlayer,
                      youtubeController: _youtubeController,
                      onToggleFullscreen: _toggleCustomFullScreen,
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
              if (_showCard && _cardTranslationFuture != null && !_isFullScreen)
                _buildTranslationOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  // --- FULLSCREEN MODE ---
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
          // DOUBLE TAP GESTURES for Seek
          onDoubleTapDown: (details) {
            final w = MediaQuery.of(context).size.width;
            if (details.globalPosition.dx < w / 3) {
              _seekRelative(-10); // Left side
            } else if (details.globalPosition.dx > (w * 2 / 3)) {
              _seekRelative(10); // Right side
            } else {
              _toggleControls();
            }
          },
          child: Stack(
            alignment: Alignment.center,
            fit: StackFit.expand,
            children: [
              // 1. Video Layer
              Center(
                child: _isLocalMedia && _localVideoController != null
                    ? Video(
                        controller: _localVideoController!,
                        fit: BoxFit.contain,
                         controls: NoVideoControls,
                      )
                    : (_youtubeController != null
                          ? FittedBox(
                              fit: BoxFit.contain,
                              child: SizedBox(
                                width: 1920,
                                height: 1080,
                                child: YoutubePlayer(
                                  controller: _youtubeController!,
                                  showVideoProgressIndicator: false,
                                ),
                              ),
                            )
                          : const SizedBox.shrink()),
              ),

              // 2. Dimmer (when card open)
              if (_showCard)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _closeTranslationCard,
                  child: Container(color: Colors.black.withOpacity(0.5)),
                ),

              // 3. Subtitles
              Positioned(
                bottom: _showControls ? 80 : 40,
                left: 32,
                right: 32,
                child: _buildInteractiveSubtitleOverlay(),
              ),

              // 4. CUSTOM YOUTUBE-STYLE CONTROLS
              if (!_showCard) _buildEnhancedVideoControls(),

              // 5. Back Button (Always visible if controls shown)
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

              // 6. Translation Card
              if (_showCard && _cardTranslationFuture != null)
                _buildTranslationOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  // --- NEW YOUTUBE-STYLE OVERLAY ---
  Widget _buildEnhancedVideoControls() {
    bool isPlaying = false;
    Duration position = Duration.zero;
    Duration duration = const Duration(seconds: 1);

    if (_isLocalMedia && _localPlayer != null) {
      isPlaying = _localPlayer!.state.playing;
      position = _localPlayer!.state.position;
      duration = _localPlayer!.state.duration;
    } else if (_youtubeController != null) {
      isPlaying = _youtubeController!.value.isPlaying;
      position = _youtubeController!.value.position;
      duration = _youtubeController!.metadata.duration;
    }

    if (duration.inSeconds == 0) duration = const Duration(seconds: 1);

    return AnimatedOpacity(
      opacity: _showControls ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: IgnorePointer(
        ignoring: !_showControls,
        child: Container(
          color: Colors.black.withOpacity(0.4), // Dim overlay
          child: Stack(
            children: [
              // CENTER CONTROLS (Back 10, Play/Pause, Fwd 10)
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      iconSize: 40,
                      icon: const Icon(Icons.replay_10, color: Colors.white),
                      onPressed: () => _seekRelative(-10),
                    ),
                    const SizedBox(width: 40),
                    Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black45,
                      ),
                      child: IconButton(
                        iconSize: 64,
                        icon: Icon(
                          isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_fill,
                          color: Colors.white,
                        ),
                        onPressed: isPlaying ? _pauseMedia : _playMedia,
                      ),
                    ),
                    const SizedBox(width: 40),
                    IconButton(
                      iconSize: 40,
                      icon: const Icon(Icons.forward_10, color: Colors.white),
                      onPressed: () => _seekRelative(10),
                    ),
                  ],
                ),
              ),

              // BOTTOM PROGRESS BAR
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              "${ReaderUtils.formatDuration(position)} / ${ReaderUtils.formatDuration(duration)}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(
                                Icons.fullscreen_exit,
                                color: Colors.white,
                              ),
                              onPressed: _toggleCustomFullScreen,
                            ),
                          ],
                        ),
                        SizedBox(
                          height: 20,
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: Colors.red, // YouTube Red
                              inactiveTrackColor: Colors.white24,
                              thumbColor: Colors.red,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6,
                              ),
                              trackHeight: 2,
                            ),
                            child: Slider(
                              value: position.inMilliseconds.toDouble().clamp(
                                0,
                                duration.inMilliseconds.toDouble(),
                              ),
                              min: 0,
                              max: duration.inMilliseconds.toDouble(),
                              onChanged: (v) {
                                _resetControlsTimer(); // Keep controls visible while dragging
                                final p = Duration(milliseconds: v.toInt());
                                if (_isLocalMedia) {
                                  _localPlayer?.seek(p);
                                } else {
                                  _youtubeController?.seekTo(p);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- SUBTITLES ---
  Widget _buildInteractiveSubtitleOverlay() {
    if (_activeSentenceIndex == -1 ||
        _activeSentenceIndex >= _smartChunks.length) {
      return const SizedBox.shrink();
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.75),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Theme(
          data: ThemeData.dark(),
          child: InteractiveTextDisplay(
            text: _smartChunks[_activeSentenceIndex],
            sentenceIndex: _activeSentenceIndex,
            vocabulary: _vocabulary,
            onWordTap: _handleWordTap,
            onPhraseSelected: _handlePhraseSelected,
            isBigMode: true,
            isListeningMode: false,
          ),
        ),
      ),
    );
  }
}

// ... [FullscreenTranslationCard - Kept Exact Same] ...
class FullscreenTranslationCard extends StatefulWidget {
  final String originalText;
  final Future<String> translationFuture;
  final Future<String?> Function() onGetAiExplanation;
  final String targetLanguage;
  final String nativeLanguage;
  final int currentStatus;
  final Function(int, String) onUpdateStatus;
  final VoidCallback onClose;

  const FullscreenTranslationCard({
    super.key,
    required this.originalText,
    required this.translationFuture,
    required this.onGetAiExplanation,
    required this.targetLanguage,
    required this.nativeLanguage,
    required this.currentStatus,
    required this.onUpdateStatus,
    required this.onClose,
  });

  @override
  State<FullscreenTranslationCard> createState() =>
      _FullscreenTranslationCardState();
}

class _FullscreenTranslationCardState extends State<FullscreenTranslationCard> {
  String _translationText = "Loading...";
  String? _aiText;
  bool _isAiLoading = false;
  final FlutterTts _cardTts = FlutterTts();
  Offset _position = const Offset(100, 50); // Initial position
  int _selectedTabIndex = 0;
  bool _isExpanded = false;
  WebViewController? _webViewController;
  bool _isLoadingWeb = false;

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadCombinedTranslations();
  }

  void _initTts() async {
    await _cardTts.setLanguage(widget.targetLanguage);
    await _cardTts.setSpeechRate(0.5);
  }

  @override
  void dispose() {
    _cardTts.stop();
    super.dispose();
  }

  Future<void> _loadCombinedTranslations() async {
    final googleFuture = widget.translationFuture;
    final myMemoryFuture = _fetchMyMemoryInternal();

    String googleResult = "";
    try {
      googleResult = await googleFuture;
    } catch (_) {}

    String myMemoryResult = "";
    try {
      myMemoryResult = await myMemoryFuture;
    } catch (_) {}

    String combined = "";
    bool myMemoryValid =
        myMemoryResult.isNotEmpty &&
        !myMemoryResult.startsWith("Error") &&
        !myMemoryResult.startsWith("No results");
    bool isPhrase = widget.originalText.trim().contains(' ');

    if (isPhrase) {
      if (googleResult.isNotEmpty) {
        combined = googleResult;
        if (myMemoryValid &&
            myMemoryResult.trim().toLowerCase() !=
                googleResult.trim().toLowerCase()) {
          combined += "\n\n[Alternative]\n$myMemoryResult";
        }
      } else if (myMemoryValid) {
        combined = myMemoryResult;
      }
    } else {
      if (myMemoryValid) combined = myMemoryResult;
      if (googleResult.isNotEmpty) {
        if (combined.isEmpty)
          combined = googleResult;
        else if (combined.trim().toLowerCase() !=
            googleResult.trim().toLowerCase()) {
          combined += "\n\n[Google]\n$googleResult";
        }
      }
    }
    if (mounted) {
      setState(() {
        _translationText = combined.isNotEmpty
            ? combined
            : "Translation not found.";
      });
    }
  }

  Future<String> _fetchMyMemoryInternal() async {
    try {
      final src = LanguageHelper.getLangCode(widget.targetLanguage);
      final tgt = LanguageHelper.getLangCode(widget.nativeLanguage);
      final cleanText = widget.originalText.replaceAll('\n', ' ').trim();
      if (cleanText.isEmpty || cleanText.length > 500) return "";

      final queryParameters = {
        'q': cleanText,
        'langpair': '$src|$tgt',
        'mt': '1',
      };
      final uri = Uri.https(
        'api.mymemory.translated.net',
        '/get',
        queryParameters,
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['responseStatus'] == 200 && data['responseData'] != null) {
          String result = data['responseData']['translatedText'] ?? "";
          if (!result.contains("MYMEMORY WARNING")) return result;
        }
      }
      return "";
    } catch (e) {
      return "";
    }
  }

  void _onTabSelected(int index) {
    setState(() {
      if (_isExpanded && _selectedTabIndex == index) {
        _isExpanded = false;
        _webViewController = null;
      } else {
        _selectedTabIndex = index;
        _isExpanded = true;
        if (index == 0 && _aiText == null && !_isAiLoading) {
          _fetchAiExplanation();
        }
        if (index > 1)
          _initializeWebView(index);
        else
          _webViewController = null;
      }
    });
  }

  Future<void> _fetchAiExplanation() async {
    setState(() => _isAiLoading = true);
    try {
      final result = await widget.onGetAiExplanation();
      if (mounted) setState(() => _aiText = result ?? "No explanation.");
    } catch (e) {
      if (mounted) setState(() => _aiText = "Error: $e");
    } finally {
      if (mounted) setState(() => _isAiLoading = false);
    }
  }

  void _initializeWebView(int index) {
    setState(() => _isLoadingWeb = true);
    final src = LanguageHelper.getLangCode(widget.targetLanguage);
    final tgt = LanguageHelper.getLangCode(widget.nativeLanguage);
    final word = Uri.encodeComponent(widget.originalText);
    String url = "";
    if (index == 2) url = "https://www.wordreference.com/${src}en/$word";
    if (index == 3) url = "https://glosbe.com/$src/$tgt/$word";
    if (index == 4)
      url = "https://context.reverso.net/translation/$src-$tgt/$word";

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF1C1C1E))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoadingWeb = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    final flag = LanguageHelper.getFlagEmoji(widget.nativeLanguage);
    final size = MediaQuery.of(context).size;
    final width = _isExpanded ? size.width * 0.8 : 400.0;
    final height = _isExpanded ? size.height * 0.8 : null;

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position += details.delta;
          });
        },
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: width,
            height: height,
            constraints: BoxConstraints(maxHeight: size.height * 0.9),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.volume_up, color: Colors.blue),
                        onPressed: () => _cardTts.speak(widget.originalText),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.originalText,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: widget.onClose,
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white10, height: 1),

                // Body
                _isExpanded
                    ? Expanded(child: _buildBodyContent(flag))
                    : Flexible(child: _buildBodyContent(flag)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBodyContent(String flag) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        _translationText,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white70,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(flag, style: const TextStyle(fontSize: 20)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildRankButton("New", 0, Colors.blue),
                    _buildRankButton("1", 1, const Color(0xFFFBC02D)),
                    _buildRankButton("2", 2, const Color(0xFFFFA726)),
                    _buildRankButton("3", 3, const Color(0xFFF57C00)),
                    _buildRankButton("4", 4, const Color(0xFFEF5350)),
                    _buildRankButton("Known", 5, Colors.green),
                  ],
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTabChip("AI", 0),
                      const SizedBox(width: 8),
                      _buildTabChip("WordRef", 2),
                      const SizedBox(width: 8),
                      _buildTabChip("Glosbe", 3),
                      const SizedBox(width: 8),
                      _buildTabChip("Reverso", 4),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isExpanded)
            Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05)),
              child: _buildExpandedContent(),
            ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent() {
    if (_selectedTabIndex == 0) {
      if (_isAiLoading) return const Center(child: CircularProgressIndicator());
      if (_aiText != null) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: GeminiFormattedText(text: _aiText!),
        );
      }
      return const Center(
        child: Text(
          "Tap AI tab to load.",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    if (_webViewController != null) {
      return Stack(
        children: [
          WebViewWidget(controller: _webViewController!),
          if (_isLoadingWeb) const Center(child: CircularProgressIndicator()),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildRankButton(String label, int status, Color color) {
    final isActive =
        (widget.currentStatus == 0 ? 0 : widget.currentStatus) == status;
    return GestureDetector(
      onTap: () => widget.onUpdateStatus(status, _translationText),
      child: Container(
        width: 40,
        height: 35,
        decoration: BoxDecoration(
          color: isActive ? color : color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? Colors.transparent : color.withOpacity(0.5),
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : color,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
        ),
      ),
    );
  }

  Widget _buildTabChip(String label, int index) {
    final isSelected = _isExpanded && _selectedTabIndex == index;
    return GestureDetector(
      onTap: () => _onTabSelected(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
