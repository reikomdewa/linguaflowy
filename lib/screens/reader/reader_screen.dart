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
import 'package:video_player/video_player.dart';

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
import 'package:linguaflow/utils/subtitle_parser.dart'; 

import 'reader_utils.dart';
import 'widgets/reader_view_modes.dart';

class ReaderScreen extends StatefulWidget {
  final LessonModel lesson;
  const ReaderScreen({super.key, required this.lesson});

  @override
  _ReaderScreenState createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  // --- State Variables ---
  Map<String, VocabularyItem> _vocabulary = {};
  bool _autoMarkOnSwipe = false;
  bool _hasSeenStatusHint = false;
  bool _isListeningMode = false;

  // --- Media Controllers ---
  YoutubePlayerController? _youtubeController;
  VideoPlayerController? _localMediaController;
  
  // --- Media Flags ---
  bool _isVideo = false; 
  bool _isAudio = false; 
  bool _isLocalMedia = false;
  bool _isInitializingMedia = false;
  
  // Start true. We turn it off once content is ready.
  bool _isParsingSubtitles = true; 
  
  bool _isPlaying = false;
  bool _isFullScreen = false;
  bool _isTransitioningFullscreen = false;
  bool _isPlayingSingleSentence = false;

  // --- TTS ---
  final FlutterTts _flutterTts = FlutterTts();
  bool _isTtsPlaying = false;
  final double _ttsSpeed = 0.5;

  // --- Scrolling & Pagination ---
  final ScrollController _listScrollController = ScrollController();
  int _activeSentenceIndex = -1;
  final PageController _pageController = PageController();
  List<List<int>> _bookPages = [];
  int _currentPage = 0;
  final int _wordsPerPage = 100;

  // Keys for Auto-Scroll
  List<GlobalKey> _itemKeys = [];

  // --- Content ---
  List<String> _smartChunks = [];
  // This holds the parsed subtitles (with timestamps)
  List<TranscriptLine> _activeTranscript = []; 

  bool _isSentenceMode = false;
  bool _hasShownSwipeHint = false;

  // --- Translation State ---
  String? _googleTranslation;
  String? _myMemoryTranslation;
  bool _isLoadingTranslation = false;
  bool _showError = false;
  bool _isCheckingLimit = false;

  // --- Floating Card State ---
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
    
    // 1. Determine Media Type
    _determineMediaType();

    // 2. Initialize Content
    _activeTranscript = widget.lesson.transcript;
    
    // 3. Handle Content & Keys
    final hasSubtitleUrl = widget.lesson.subtitleUrl != null && widget.lesson.subtitleUrl!.isNotEmpty;
    
    // If we have a local subtitle file, we MUST parse it to get timestamps for auto-scroll
    // even if the text content is already loaded.
    if (hasSubtitleUrl && _activeTranscript.isEmpty) {
      _initializeLocalContent();
    } else {
      // Content already exists or no subtitles needed
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
        final lines = await SubtitleParser.parseFile(widget.lesson.subtitleUrl!);
        // Using setState to ensure the variable update is safe
        if (mounted && lines.isNotEmpty) {
          setState(() {
            _activeTranscript = lines;
          });
        }
      }
    } catch (e) {
      debugPrint("Error parsing local subtitles: $e");
    } finally {
      if (mounted) {
        _finalizeContentInitialization();
      }
    }
  }

  void _finalizeContentInitialization() {
    setState(() {
      // 1. Fill _smartChunks (UI text) based on _activeTranscript
      _generateSmartChunks();
      
      // 2. Generate Keys matching _smartChunks length exactly
      _itemKeys = List.generate(_smartChunks.length, (_) => GlobalKey());
      
      // 3. Generate Pagination matching _smartChunks
      _prepareBookPages();
      
      // 4. Unlock the view
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
    bool isYoutube = url.toLowerCase().contains('youtube.com') || url.toLowerCase().contains('youtu.be');
    
    if (isYoutube) {
      _initializeYoutubePlayer(url);
    } else if (!isNetwork) {
      _initializeLocalMediaPlayer(url);
    } else {
      _initializeTts(); 
    }
  }

  // ... [Gemini, Dispose, Vocabulary, Prefs - Same as before] ...
  void _initGemini() {
    final envKey = dotenv.env['GEMINI_API_KEY'];
    if (envKey != null && envKey.isNotEmpty) {
      try {
        Gemini.init(apiKey: envKey);
      } catch (e) {
        debugPrint("Gemini Init Error: $e");
      }
    }
  }

  @override
  void dispose() {
    _youtubeController?.dispose();
    _localMediaController?.dispose(); 
    _pageController.dispose();
    _listScrollController.dispose();
    _flutterTts.stop();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
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

  // --- CONTENT GENERATION ---
  void _generateSmartChunks() {
    _smartChunks = [];
    
    // Priority: Use Transcript Lines (Subtitle Text)
    // This is vital for auto-scroll because the timing indices match these chunks.
    if (_activeTranscript.isNotEmpty) {
      for (var t in _activeTranscript) {
        _smartChunks.add(t.text);
      }
      return;
    }

    // Fallback: Use Sentence Split (Regex) - No auto-scroll available usually
    List<String> rawSentences = widget.lesson.sentences;
    if (rawSentences.isEmpty) {
      rawSentences = widget.lesson.content.split(RegExp(r'(?<=[.!?])\s+'));
    }
    for (String sentence in rawSentences) {
      if (sentence.trim().isNotEmpty) _smartChunks.add(sentence.trim());
    }
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

  void _initializeYoutubePlayer(String url) {
    String? videoId;
    if (widget.lesson.id.startsWith('yt_audio_')) {
      videoId = widget.lesson.id.replaceAll('yt_audio_', '');
    } else if (widget.lesson.id.startsWith('yt_')) {
      videoId = widget.lesson.id.replaceAll('yt_', '');
    } else {
      videoId = YoutubePlayer.convertUrlToId(url);
    }
    
    if (videoId != null) {
      _youtubeController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
          enableCaption: false,
        ),
      );
      _youtubeController!.addListener(_mediaListener);
      setState(() {
        _isLocalMedia = false;
        _isVideo = true; 
      });
    }
  }

  Future<void> _initializeLocalMediaPlayer(String path) async {
    setState(() => _isInitializingMedia = true);
    final file = File(path);
    
    if (await file.exists()) {
      _localMediaController = VideoPlayerController.file(file);
      try {
        await _localMediaController!.initialize();
        if (mounted) {
          setState(() {
            _isLocalMedia = true;
            _isInitializingMedia = false;
          });
          _localMediaController!.addListener(_mediaListener);
        }
      } catch (e) {
        debugPrint("Local Media Init Error: $e");
        if (mounted) setState(() => _isInitializingMedia = false);
      }
    } else {
      debugPrint("Local Media File Not Found: $path");
      if (mounted) setState(() => _isInitializingMedia = false);
    }
  }

  // --- CRITICAL AUTO-SCROLL LOGIC ---
  void _mediaListener() {
    if (!mounted || _isTransitioningFullscreen) return;

    bool isPlayerPlaying = false;
    double currentSeconds = 0.0;

    if (_isLocalMedia && _localMediaController != null && _localMediaController!.value.isInitialized) {
      isPlayerPlaying = _localMediaController!.value.isPlaying;
      currentSeconds = _localMediaController!.value.position.inMilliseconds / 1000;
    } else if (_youtubeController != null) {
      isPlayerPlaying = _youtubeController!.value.isPlaying;
      currentSeconds = _youtubeController!.value.position.inMilliseconds / 1000;
    } else {
      return;
    }

    if (isPlayerPlaying != _isPlaying)
      setState(() => _isPlaying = isPlayerPlaying);

    if (_activeTranscript.isEmpty) return;

    if (_isSentenceMode && _isPlayingSingleSentence && _isPlaying) {
      if (_activeSentenceIndex >= 0 &&
          _activeSentenceIndex < _activeTranscript.length) {
        if (currentSeconds >=
            _activeTranscript[_activeSentenceIndex].end) {
          _pauseMedia();
          setState(() {
            _isPlayingSingleSentence = false;
            _isPlaying = false;
          });
          return;
        }
      }
    }
    
    // Continuous Playback with Auto-Scroll
    if (_isPlaying && !_isPlayingSingleSentence) {
      int realTimeIndex = -1;
      
      // Find the subtitle line matching current time
      for (int i = 0; i < _activeTranscript.length; i++) {
        if (currentSeconds >= _activeTranscript[i].start &&
            currentSeconds < _activeTranscript[i].end) {
          realTimeIndex = i;
          break;
        }
      }

      // If index changed, update UI and Scroll
      if (realTimeIndex != -1 && realTimeIndex != _activeSentenceIndex) {
        setState(() {
          _activeSentenceIndex = realTimeIndex;
          _resetTranslationState();
        });
        
        // Ensure scroll happens
        if (!_isSentenceMode) {
          _scrollToActiveLine(realTimeIndex); 
        }
      }
    }
  }

  void _pauseMedia() {
    if (_isLocalMedia) {
      _localMediaController?.pause();
    } else {
      _youtubeController?.pause();
    }
  }
  
  void _playMedia() {
    if (_isLocalMedia) {
      _localMediaController?.play();
    } else {
      _youtubeController?.play();
    }
  }

  void _resetTranslationState() {
    _googleTranslation = null;
    _myMemoryTranslation = null;
    _isLoadingTranslation = false;
    _showError = false;
  }

  void _scrollToActiveLine(int index) {
    if (index >= 0 && index < _itemKeys.length) {
      final key = _itemKeys[index];
      if (key.currentContext != null) {
        Scrollable.ensureVisible(
          key.currentContext!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.5,
        );
      }
    }
  }

  void _seekToTime(double seconds) {
    final d = Duration(milliseconds: (seconds * 1000).toInt());
    if (_isLocalMedia && _localMediaController != null) {
      _localMediaController!.seekTo(d);
    } else if (_youtubeController != null) {
      _youtubeController!.seekTo(d);
    }
  }

  // --- NAVIGATION ---
  void _goToNextSentence() {
    if (_activeSentenceIndex < _smartChunks.length - 1) {
      _handleSwipeMarking(_activeSentenceIndex);
      setState(() {
        _activeSentenceIndex++;
        _resetTranslationState();
      });
      if ((_isVideo || _isAudio) && _activeTranscript.isNotEmpty) {
        if (_activeSentenceIndex < _activeTranscript.length) {
          _seekToTime(_activeTranscript[_activeSentenceIndex].start);
        }
      }
    }
  }

  void _goToPrevSentence() {
    if (_activeSentenceIndex > 0) {
      setState(() {
        _activeSentenceIndex--;
        _resetTranslationState();
      });
      if ((_isVideo || _isAudio) && _activeTranscript.isNotEmpty) {
        if (_activeSentenceIndex < _activeTranscript.length) {
          _seekToTime(_activeTranscript[_activeSentenceIndex].start);
        }
      }
    }
  }

  // --- PLAYBACK CONTROLS ---
  void _playFromStartContinuous() {
    if (_isVideo || _isAudio) {
      if (_activeSentenceIndex != -1 &&
          _activeTranscript.isNotEmpty &&
          _activeSentenceIndex < _activeTranscript.length) {
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
      } else {
        setState(() => _isPlayingSingleSentence = false);
        _playMedia();
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
        if (_activeSentenceIndex != -1 &&
            _activeTranscript.isNotEmpty &&
            _activeSentenceIndex < _activeTranscript.length) {
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
      if (_isSentenceMode) {
        setState(() => _isTtsPlaying = false);
      } else {
        _playNextTtsSentence();
      }
    });
  }

  void _playNextTtsSentence() {
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
      int startIndex = _activeSentenceIndex == -1 ? 0 : _activeSentenceIndex;
      if (startIndex >= widget.lesson.sentences.length) startIndex = 0;
      _speakSentence(widget.lesson.sentences[startIndex], startIndex);
    }
  }

  // --- ACTIONS ---
  void _closeTranslationCard() {
    if (_showCard) {
      _activeSelectionClearer?.call();
      setState(() {
        _showCard = false;
        _activeSelectionClearer = null;
      });
    }
  }

  void _handleWordTap(String originalWord, String cleanId, Offset pos) async {
    _activeSelectionClearer?.call();
    _activeSelectionClearer = null;

    if (_isCheckingLimit) return;
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    final existingItem = _vocabulary[cleanId];
    final int newStatus = _calculateSmartStatus(existingItem);

    if (existingItem == null || existingItem.status != newStatus) {
      await _updateWordStatus(
        cleanId,
        originalWord,
        existingItem?.translation ?? "",
        newStatus,
        showDialog: false,
      );
    }

    if (authState.user.isPremium) {
      _activateCard(originalWord, cleanId, pos, isPhrase: false);
    } else {
      _checkLimitAndActivate(
        authState.user.id,
        cleanId,
        originalWord,
        pos,
        false,
      );
    }
  }

  void _handlePhraseSelected(
    String phrase,
    Offset pos,
    VoidCallback clearSelection,
  ) {
    if (_isVideo || _isAudio) _pauseMedia();
    if (_isTtsPlaying) _flutterTts.stop();
    _activeSelectionClearer?.call();
    _activeSelectionClearer = clearSelection;
    final cleanId = ReaderUtils.generateCleanId(phrase);
    _activateCard(phrase, cleanId, pos, isPhrase: true);
  }

  void _activateCard(
    String text,
    String cleanId,
    Offset pos, {
    required bool isPhrase,
  }) {
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    final translationService = context.read<TranslationService>();
    setState(() {
      _showCard = true;
      _selectedText = text;
      _selectedCleanId = cleanId;
      _isSelectionPhrase = isPhrase;
      _cardAnchor = pos;
      _cardTranslationFuture = translationService
          .translate(text, user.nativeLanguage, widget.lesson.language)
          .then((v) => v ?? "");
    });
  }

  Widget _buildTranslationOverlay() {
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    final VocabularyItem? existingItem = _isSelectionPhrase
        ? null
        : _vocabulary[_selectedCleanId];

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
      currentStatus: existingItem?.status ?? 0,
      anchorPosition: _cardAnchor,
      onUpdateStatus: (status, translation) {
        _updateWordStatus(_selectedCleanId, _selectedText, translation, status);
        _closeTranslationCard();
      },
      onClose: _closeTranslationCard,
    );
  }

  Future<void> _checkLimitAndActivate(
    String userId,
    String cleanId,
    String word,
    Offset pos,
    bool isPhrase,
  ) async {
    setState(() => _isCheckingLimit = true);
    final canAccess = await _checkAndIncrementFreeLimit(userId);
    setState(() => _isCheckingLimit = false);
    if (canAccess) {
      _activateCard(word, cleanId, pos, isPhrase: isPhrase);
    } else {
      _showLimitDialog();
    }
  }

  Future<bool> _checkAndIncrementFreeLimit(String userId) async {
    return true;
  }

  void _showLimitDialog() {
    showDialog(context: context, builder: (c) => const PremiumLockDialog());
  }

  Future<void> _updateWordStatus(
    String cleanWord,
    String originalWord,
    String translation,
    int status, {
    bool showDialog = true,
  }) async {
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    final newItem = VocabularyItem(
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
    setState(() => _vocabulary[cleanWord] = newItem);
    context.read<VocabularyBloc>().add(VocabularyUpdateRequested(newItem));
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.id)
        .collection('vocabulary')
        .doc(cleanWord)
        .set({
          'status': status,
          'translation': translation,
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

    String text = "";
    if (_activeSentenceIndex < _smartChunks.length) {
      text = _smartChunks[_activeSentenceIndex];
    }

    if (text.isEmpty) return;

    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    setState(() {
      _isLoadingTranslation = true;
      _showError = false;
    });

    try {
      final gRes = await context.read<TranslationService>().translate(
        text,
        user.nativeLanguage,
        widget.lesson.language,
      );
      final mRes = await MyMemoryService.translate(
        text: text,
        sourceLang: widget.lesson.language,
        targetLang: user.nativeLanguage,
      );

      if (mounted) {
        setState(() {
          _googleTranslation = gRes;
          _myMemoryTranslation = mRes;
          _isLoadingTranslation = false;
        });
      }
    } catch (_) {
      if (mounted)
        setState(() {
          _isLoadingTranslation = false;
          _showError = true;
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
      final clean = ReaderUtils.generateCleanId(word);
      if (clean.isEmpty) continue;
      final item = _vocabulary[clean];
      if (item == null || item.status == 0) {
        _updateWordStatus(clean, word.trim(), "", 5, showDialog: false);
        markedAny = true;
      }
    }
    if (markedAny && !_hasShownSwipeHint) {
      _hasShownSwipeHint = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Marked previous words as known"),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _showGeminiHint() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.auto_awesome, color: Colors.blueAccent),
            SizedBox(width: 10),
            Text("Use Gemini Assistant", style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "You can use your phone's Gemini AI (or Google Assistant) to analyze this screen!",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text("1. Invoke Assistant (Long-press Power/Home)."),
            SizedBox(height: 8),
            Text("2. Tap 'Share Screen With Live' or 'Ask about this screen'."),
            SizedBox(height: 8),
            Text(
              "3. Ask: 'Read or Translate this paragraph' or 'Explain the grammar'.",
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Got it"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullScreen && (_isVideo || _isAudio)) {
      return _buildFullscreenMedia();
    }

    final settings = context.watch<SettingsBloc>().state;
    Color bgColor;
    Color textColor;
    Brightness readerBrightness;

    switch (settings.readerTheme) {
      case ReaderTheme.sepia:
        bgColor = const Color(0xFFF4ECD8);
        textColor = const Color(0xFF5D4037);
        readerBrightness = Brightness.light;
        break;
      case ReaderTheme.dark:
        bgColor = const Color(0xFF1E1E1E);
        textColor = Colors.white;
        readerBrightness = Brightness.dark;
        break;
      case ReaderTheme.light:
      default:
        bgColor = Colors.white;
        textColor = Colors.black87;
        readerBrightness = Brightness.light;
        break;
    }

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: readerBrightness == Brightness.light
            ? Brightness.dark
            : Brightness.light,
      ),
    );

    final readerThemeData = Theme.of(context).copyWith(
      brightness: readerBrightness,
      scaffoldBackgroundColor: bgColor,
      appBarTheme: AppBarTheme(
        backgroundColor: bgColor,
        foregroundColor: textColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      iconTheme: IconThemeData(color: textColor),
      textTheme: Theme.of(context).textTheme.apply(
        bodyColor: textColor,
        displayColor: textColor,
        fontFamily: settings.fontFamily,
      ),
    );

    // --- CRITICAL FIX FOR LOCAL AUTO-SCROLL ---
    // If we have a local transcript active, we MUST inject it into the display model.
    // The view (ParagraphModeView) checks 'transcript.isNotEmpty' to decide if it renders a scrolling list.
    // Without this, local files (which start with empty transcript in lesson model) render as Book Mode.
    final displayLesson = widget.lesson.copyWith(
      sentences: _smartChunks, 
      transcript: _activeTranscript, // <--- THIS LINE FIXES THE SCROLLING
    );

    return Theme(
      data: readerThemeData,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          title: Text(
            widget.lesson.title,
            style: TextStyle(color: textColor, fontSize: 18),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.assistant),
              tooltip: "Use Gemini Assistant",
              onPressed: _showGeminiHint,
            ),
            if (_isSentenceMode)
              IconButton(
                icon: Icon(
                  _isListeningMode ? Icons.hearing : Icons.hearing_disabled,
                  color: _isListeningMode ? Colors.blue : Colors.grey,
                ),
                tooltip: "Listening Mode",
                onPressed: () {
                  setState(() => _isListeningMode = !_isListeningMode);
                },
              ),
            if (!(_isVideo || _isAudio) && !_isSentenceMode)
              IconButton(
                icon: Icon(
                  _isPlaying || _isTtsPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  color: Colors.blue,
                ),
                onPressed: _toggleTtsFullLesson,
              ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: textColor),
              onSelected: (value) {
                if (value == 'toggle_mark_swipe')
                  setState(() => _autoMarkOnSwipe = !_autoMarkOnSwipe);
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
                            ? Theme.of(context).primaryColor
                            : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      const Text('Mark known on swipe'),
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
                  // --- Media Header ---
                  if (_isVideo || _isAudio) _buildMediaHeader(),
                  
                  if (_isCheckingLimit || _isParsingSubtitles)
                     const LinearProgressIndicator(minHeight: 2),

                  // --- Reader Content ---
                  Expanded(
                    child: _isParsingSubtitles 
                        ? const Center(child: Text("Preparing lesson content..."))
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
                                onTranslateRequest: _handleTranslationToggle,
                                onRetryTranslation: _handleTranslationToggle,
                                isListeningMode: _isListeningMode,
                              )
                            : ParagraphModeView(
                                lesson: displayLesson, // <--- Using the synced lesson model
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
                                   if ((_isVideo || _isAudio) && i < _activeTranscript.length) {
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
                                itemKeys: _itemKeys, // <--- KEYS MATCH _smartChunks
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
              if (_showCard && _cardTranslationFuture != null)
                _buildTranslationOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaHeader() {
    if (_isInitializingMedia) {
      return Container(
        height: _isAudio ? 120 : 220,
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 10),
              Text("Loading Media...", style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    }

    if (_isLocalMedia && _localMediaController != null && _localMediaController!.value.isInitialized) {
      if (_isAudio) {
        return Container(
          height: 120,
          color: Colors.grey.shade900,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               const Icon(Icons.music_note, color: Colors.white54, size: 40),
               _buildLocalMediaControls(),
            ],
          ),
        );
      }
      return Container(
        height: 220,
        color: Colors.black,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: _localMediaController!.value.aspectRatio,
                child: VideoPlayer(_localMediaController!),
              ),
            ),
            _buildLocalMediaControls(),
          ],
        ),
      );
    }
    
    if (_youtubeController != null) {
      return SizedBox(
        height: 220,
        child: YoutubePlayer(controller: _youtubeController!),
      );
    }
    
    return const SizedBox.shrink();
  }

  Widget _buildLocalMediaControls() {
    return Container(
      color: Colors.black45,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _localMediaController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _localMediaController!.value.isPlaying
                  ? _localMediaController!.pause()
                  : _localMediaController!.play();
              });
            },
          ),
          Expanded(
            child: VideoProgressIndicator(
              _localMediaController!,
              allowScrubbing: true,
              colors: VideoProgressColors(
                playedColor: Colors.blueAccent,
                backgroundColor: Colors.grey.withOpacity(0.5),
              ),
            ),
          ),
          if (!_isAudio)
            IconButton(
              icon: const Icon(Icons.fullscreen, color: Colors.white),
              onPressed: _toggleCustomFullScreen,
            ),
        ],
      ),
    );
  }

  void _toggleCustomFullScreen() {
    setState(() => _isFullScreen = !_isFullScreen);
  }

  Widget _buildFullscreenMedia() {
    return WillPopScope(
      onWillPop: () async {
        _toggleCustomFullScreen();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: _isLocalMedia && _localMediaController != null
              ? AspectRatio(
                  aspectRatio: _localMediaController!.value.aspectRatio,
                  child: VideoPlayer(_localMediaController!),
                )
              : (_youtubeController != null 
                  ? YoutubePlayer(controller: _youtubeController!) 
                  : const CircularProgressIndicator()),
        ),
        floatingActionButton: _isLocalMedia 
          ? FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white24,
              onPressed: _toggleCustomFullScreen,
              child: const Icon(Icons.fullscreen_exit),
            ) 
          : null,
      ),
    );
  }
}