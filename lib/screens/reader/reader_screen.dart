import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/vocabulary/vocabulary_bloc.dart';
import 'package:linguaflow/blocs/settings/settings_bloc.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/vocabulary_item.dart';
import 'package:linguaflow/services/translation_service.dart';
import 'package:linguaflow/services/vocabulary_service.dart';
import 'package:linguaflow/services/mymemory_service.dart';
import 'package:linguaflow/widgets/floating_translation_card.dart';
import 'package:linguaflow/widgets/premium_lock_dialog.dart';

import 'reader_utils.dart';
import 'widgets/reader_view_modes.dart';

class ReaderScreen extends StatefulWidget {
  final LessonModel lesson;
  const ReaderScreen({super.key, required this.lesson});

  @override
  _ReaderScreenState createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  // State Variables
  Map<String, VocabularyItem> _vocabulary = {};
  bool _autoMarkOnSwipe = false;
  bool _hasSeenStatusHint = false;

  // Video / Audio
  YoutubePlayerController? _videoController;
  bool _isVideo = false;
  bool _isAudioMode = false;
  bool _isPlaying = false;
  bool _isFullScreen = false;
  bool _isTransitioningFullscreen = false;
  bool _isPlayingSingleSentence = false;

  // TTS
  final FlutterTts _flutterTts = FlutterTts();
  bool _isTtsPlaying = false;
  final double _ttsSpeed = 0.5;

  // Scrolling & Pagination
  final ScrollController _listScrollController = ScrollController();
  int _activeSentenceIndex = -1;
  final PageController _pageController = PageController();
  List<List<int>> _bookPages = [];
  int _currentPage = 0;
  final int _wordsPerPage = 100;

  // Content
  List<String> _smartChunks = [];
  bool _isSentenceMode = false;
  bool _hasShownSwipeHint = false;

  // Translation
  String? _googleTranslation;
  String? _myMemoryTranslation;
  bool _isLoadingTranslation = false;
  bool _showError = false;
  bool _isCheckingLimit = false;

  // Floating Card
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
    _generateSmartChunks();

    if (widget.lesson.transcript.isEmpty) _prepareBookPages();
    if (widget.lesson.videoUrl != null && widget.lesson.videoUrl!.isNotEmpty) {
      _initializeVideoPlayer();
    } else {
      _initializeTts();
    }
  }

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
    _videoController?.dispose();
    _pageController.dispose();
    _listScrollController.dispose();
    _flutterTts.stop();
    
    // Reset Orientation & System UI
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // Default reset
    ));
    
    super.dispose();
  }

  // --- LOGIC METHODS ---
  void _generateSmartChunks() {
    _smartChunks = [];
    if (widget.lesson.transcript.isNotEmpty) {
      for (var t in widget.lesson.transcript) {
        _smartChunks.add(t.text);
      }
      return;
    }
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
    if (currentPageIndices.isNotEmpty) _bookPages.add(currentPageIndices);
  }

  Future<void> _loadVocabulary() async {
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users').doc(user.id).collection('vocabulary').get();
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
          .collection('users').doc(authState.user.id)
          .collection('preferences').doc('reader').get();
      if (doc.exists && mounted) {
        setState(() {
          _autoMarkOnSwipe = doc.data()?['autoMarkOnSwipe'] ?? false;
          _hasSeenStatusHint = doc.data()?['hasSeenStatusHint'] ?? false;
        });
      }
    }
  }

  void _initializeVideoPlayer() {
    String? videoId;
    if (widget.lesson.id.startsWith('yt_audio_')) {
      videoId = widget.lesson.id.replaceAll('yt_audio_', '');
      _isAudioMode = true;
    } else if (widget.lesson.id.startsWith('yt_')) {
      videoId = widget.lesson.id.replaceAll('yt_', '');
    } else if (widget.lesson.videoUrl != null) {
      videoId = YoutubePlayer.convertUrlToId(widget.lesson.videoUrl!);
    }
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
    if (_videoController == null || !mounted || _isTransitioningFullscreen) return;
    final isPlayerPlaying = _videoController!.value.isPlaying;
    if (isPlayerPlaying != _isPlaying) setState(() => _isPlaying = isPlayerPlaying);

    if (widget.lesson.transcript.isEmpty) return;
    final currentSeconds = _videoController!.value.position.inMilliseconds / 1000;

    if (_isSentenceMode && _isPlayingSingleSentence && _isPlaying) {
      if (_activeSentenceIndex >= 0 && _activeSentenceIndex < widget.lesson.transcript.length) {
        if (currentSeconds >= widget.lesson.transcript[_activeSentenceIndex].end) {
          _videoController!.pause();
          setState(() { _isPlayingSingleSentence = false; _isPlaying = false; });
          return;
        }
      }
    }
    if (_isPlaying && !_isPlayingSingleSentence) {
      int realTimeIndex = -1;
      for (int i = 0; i < widget.lesson.transcript.length; i++) {
        if (currentSeconds >= widget.lesson.transcript[i].start && currentSeconds < widget.lesson.transcript[i].end) {
          realTimeIndex = i;
          break;
        }
      }
      if (realTimeIndex != -1 && realTimeIndex != _activeSentenceIndex) {
        setState(() => _activeSentenceIndex = realTimeIndex);
        if (!_isSentenceMode) _scrollToActiveLine(realTimeIndex);
      }
    }
  }

  void _scrollToActiveLine(int index) {
    if (_listScrollController.hasClients) {
      // Auto-scroll implementation logic can go here
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
      setState(() { _isTtsPlaying = false; _activeSentenceIndex = -1; });
    }
  }

  Future<void> _speakSentence(String text, int index) async {
    setState(() { _activeSentenceIndex = index; _isTtsPlaying = true; });
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
      setState(() { _showCard = false; _activeSelectionClearer = null; });
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
      await _updateWordStatus(cleanId, originalWord, existingItem?.translation ?? "", newStatus, showDialog: false);
    }

    if (authState.user.isPremium) {
      _activateCard(originalWord, cleanId, pos, isPhrase: false);
    } else {
      _checkLimitAndActivate(authState.user.id, cleanId, originalWord, pos, false);
    }
  }

  void _handlePhraseSelected(String phrase, Offset pos, VoidCallback clearSelection) {
    if (_isVideo) _videoController?.pause();
    if (_isTtsPlaying) _flutterTts.stop();
    _activeSelectionClearer?.call();
    _activeSelectionClearer = clearSelection;
    final cleanId = ReaderUtils.generateCleanId(phrase);
    _activateCard(phrase, cleanId, pos, isPhrase: true);
  }

  void _activateCard(String text, String cleanId, Offset pos, {required bool isPhrase}) {
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

  Future<void> _checkLimitAndActivate(String userId, String cleanId, String word, Offset pos, bool isPhrase) async {
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
    // Basic implementation
    return true; 
  }

  void _showLimitDialog() {
    showDialog(context: context, builder: (c) => const PremiumLockDialog());
  }

  Future<void> _updateWordStatus(String cleanWord, String originalWord, String translation, int status, {bool showDialog = true}) async {
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    final newItem = VocabularyItem(
      id: cleanWord, userId: user.id, word: cleanWord, baseForm: cleanWord,
      language: widget.lesson.language, translation: translation,
      status: status, timesEncountered: 1, lastReviewed: DateTime.now(), createdAt: DateTime.now(),
    );
    setState(() => _vocabulary[cleanWord] = newItem);
    context.read<VocabularyBloc>().add(VocabularyUpdateRequested(newItem));
    await FirebaseFirestore.instance.collection('users').doc(user.id).collection('vocabulary').doc(cleanWord).set({
      'status': status, 'translation': translation, 'lastReviewed': FieldValue.serverTimestamp()
    }, SetOptions(merge: true));
    if (showDialog && !_hasSeenStatusHint) {
      setState(() => _hasSeenStatusHint = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Word status updated"), duration: Duration(seconds: 1)));
    }
  }

  int _calculateSmartStatus(VocabularyItem? item) {
    if (item == null || item.status == 0) return 1;
    if (item.status >= 5) return 5;
    if (DateTime.now().difference(item.lastReviewed).inHours >= 1) return item.status + 1;
    return item.status;
  }

  Future<void> _translateCurrentSentence() async {
    String text = (_activeSentenceIndex < _smartChunks.length) ? _smartChunks[_activeSentenceIndex] : "";
    if (text.isEmpty) return;
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    setState(() { _isLoadingTranslation = true; _showError = false; _googleTranslation = null; _myMemoryTranslation = null; });
    try {
      final gRes = await context.read<TranslationService>().translate(text, user.nativeLanguage, widget.lesson.language);
      final mRes = await MyMemoryService.translate(text: text, sourceLang: widget.lesson.language, targetLang: user.nativeLanguage);
      if (mounted) setState(() { _googleTranslation = gRes; _myMemoryTranslation = mRes; _isLoadingTranslation = false; });
    } catch (_) {
      if (mounted) setState(() { _isLoadingTranslation = false; _showError = true; });
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Marked previous words as known"), duration: Duration(seconds: 1)));
    }
  }

  // --- UI BUILDING ---

  @override
  Widget build(BuildContext context) {
    if (_isFullScreen && _isVideo && _videoController != null) {
      return _buildFullscreenVideo();
    }

    // 1. WATCH SETTINGS
    final settings = context.watch<SettingsBloc>().state;

    // 2. CALCULATE COLORS & BRIGHTNESS based on Reader Theme
    Color bgColor;
    Color textColor;
    Brightness readerBrightness;

    switch (settings.readerTheme) {
      case ReaderTheme.sepia:
        bgColor = const Color(0xFFF4ECD8);
        textColor = const Color(0xFF5D4037); // Dark Brown
        readerBrightness = Brightness.light; // FORCE Light status bar/icons
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

    // 3. SET STATUS BAR COLOR (To match theme)
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: readerBrightness == Brightness.light ? Brightness.dark : Brightness.light,
    ));

    // 4. OVERRIDE THEME for child widgets
    // This explicitly tells children "Hey, we are in Light/Dark mode"
    // regardless of what the main app theme is.
    final readerThemeData = Theme.of(context).copyWith(
      brightness: readerBrightness, // <--- THE FIX
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

    return Theme(
      data: readerThemeData,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          title: Text(widget.lesson.title, style: TextStyle(color: textColor, fontSize: 18)),
          actions: [
            if (!_isVideo && !_isSentenceMode)
              IconButton(
                icon: Icon(_isPlaying || _isTtsPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.blue),
                onPressed: _toggleTtsFullLesson,
              ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: textColor),
              onSelected: (value) {
                if (value == 'toggle_mark_swipe') setState(() => _autoMarkOnSwipe = !_autoMarkOnSwipe);
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'toggle_mark_swipe',
                  child: Row(children: [
                      Icon(_autoMarkOnSwipe ? Icons.check_box : Icons.check_box_outline_blank, color: _autoMarkOnSwipe ? Theme.of(context).primaryColor : Colors.grey),
                      const SizedBox(width: 8), const Text('Mark known on swipe'),
                  ]),
                ),
              ],
            )
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  if (_isVideo) _buildVideoHeader(),
                  if (_isCheckingLimit) const LinearProgressIndicator(minHeight: 2),
                  Expanded(
                    child: _isSentenceMode
                        ? SentenceModeView(
                            chunks: _smartChunks,
                            activeIndex: _activeSentenceIndex,
                            vocabulary: _vocabulary,
                            isVideo: _isVideo,
                            isPlaying: _isPlaying || _isPlayingSingleSentence,
                            isTtsPlaying: _isTtsPlaying,
                            onTogglePlayback: () {
                               if (_isVideo && _videoController != null) {
                                 if (_isPlaying) {
                                   _videoController!.pause();
                                   setState(() => _isPlayingSingleSentence = false);
                                 } else {
                                   if (_activeSentenceIndex != -1 && widget.lesson.transcript.isNotEmpty && _activeSentenceIndex < widget.lesson.transcript.length) {
                                      setState(() => _isPlayingSingleSentence = true);
                                      _videoController!.seekTo(Duration(seconds: widget.lesson.transcript[_activeSentenceIndex].start.toInt()));
                                      _videoController!.play();
                                   }
                                 }
                               } else {
                                 _isTtsPlaying ? _flutterTts.stop() : _speakSentence(_smartChunks[_activeSentenceIndex], _activeSentenceIndex);
                               }
                            },
                            onNext: () {
                              if (_activeSentenceIndex < _smartChunks.length - 1) {
                                _handleSwipeMarking(_activeSentenceIndex);
                                setState(() => _activeSentenceIndex++);
                              }
                            },
                            onPrev: () {
                              if (_activeSentenceIndex > 0) setState(() => _activeSentenceIndex--);
                            },
                            onWordTap: _handleWordTap,
                            onPhraseSelected: _handlePhraseSelected,
                            isLoadingTranslation: _isLoadingTranslation,
                            googleTranslation: _googleTranslation,
                            myMemoryTranslation: _myMemoryTranslation,
                            showError: _showError,
                            onRetryTranslation: _translateCurrentSentence,
                            onTranslateRequest: _translateCurrentSentence,
                          )
                        : ParagraphModeView(
                            lesson: widget.lesson,
                            bookPages: _bookPages,
                            activeSentenceIndex: _activeSentenceIndex,
                            currentPage: _currentPage,
                            vocabulary: _vocabulary,
                            isVideo: _isVideo,
                            listScrollController: _listScrollController,
                            pageController: _pageController,
                            onPageChanged: (i) => setState(() => _currentPage = i),
                            onSentenceTap: (i) => _speakSentence(widget.lesson.sentences[i], i),
                            onVideoSeek: (t) => _videoController?.seekTo(Duration(seconds: t.toInt())),
                            onWordTap: _handleWordTap,
                            onPhraseSelected: _handlePhraseSelected,
                          ),
                  ),
                ],
              ),
              Positioned(
                bottom: 24, right: 24,
                child: FloatingActionButton(
                  backgroundColor: Theme.of(context).primaryColor,
                  onPressed: () => setState(() => _isSentenceMode = !_isSentenceMode),
                  child: Icon(_isSentenceMode ? Icons.menu_book : Icons.short_text, color: Colors.white),
                ),
              ),
              if (_showCard && _cardTranslationFuture != null) _buildTranslationOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTranslationOverlay() {
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    final VocabularyItem? existingItem = _isSelectionPhrase ? null : _vocabulary[_selectedCleanId];

    return FloatingTranslationCard(
      key: ValueKey(_selectedText),
      originalText: _selectedText,
      translationFuture: _cardTranslationFuture!,
      onGetAiExplanation: () => Gemini.instance.prompt(
        parts: [Part.text("Explain '$_selectedText' in ${widget.lesson.language} for ${user.nativeLanguage} speaker")]
      ).then((v) => v?.output).catchError((_) => "AI Error"),
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

  Widget _buildVideoHeader() {
    if (_videoController == null) return const SizedBox.shrink();
    return SizedBox(height: 220, child: YoutubePlayer(controller: _videoController!));
  }

  void _toggleCustomFullScreen() {
    setState(() => _isFullScreen = !_isFullScreen);
  }

  Widget _buildFullscreenVideo() {
    return WillPopScope(
      onWillPop: () async { _toggleCustomFullScreen(); return false; },
      child: Scaffold(backgroundColor: Colors.black, body: Center(child: YoutubePlayer(controller: _videoController!))),
    );
  }
}