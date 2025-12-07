import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/vocabulary/vocabulary_bloc.dart';
import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/vocabulary_item.dart';
import 'package:linguaflow/services/translation_service.dart';
import 'package:linguaflow/services/vocabulary_service.dart';
import 'package:linguaflow/widgets/floating_translation_card.dart'; 
import 'package:linguaflow/widgets/premium_lock_dialog.dart';

class StoryModeScreen extends StatefulWidget {
  final LessonModel lesson;

  const StoryModeScreen({super.key, required this.lesson});

  @override
  State<StoryModeScreen> createState() => _StoryModeScreenState();
}

class _StoryModeScreenState extends State<StoryModeScreen> {
  final PageController _pageController = PageController();
  List<String> _storyPages = [];
  int _currentPage = 0;
  static const int _wordsPerPage = 80;
  bool _autoMarkOnSwipe = false;
  final FlutterTts _flutterTts = FlutterTts();
  bool _isTtsPlaying = false;
  Map<String, VocabularyItem> _vocabulary = {};
  static const int _kFreeLookupLimit = 50;
  static const int _kResetMinutes = 10;
  bool _isCheckingLimit = false;
  late bool _isSavedToLibrary;

  @override
  void initState() {
    super.initState();
    _isSavedToLibrary = widget.lesson.isFavorite;
    _paginateStory();
    _initializeTts();
    _loadVocabulary();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  void _paginateStory() {
    if (widget.lesson.content.isEmpty) {
      setState(() => _storyPages = ["No content available."]);
      return;
    }
    final words = widget.lesson.content.split(RegExp(r'\s+'));
    List<String> pages = [];
    int startIndex = 0;
    while (startIndex < words.length) {
      int endIndex = (startIndex + _wordsPerPage).clamp(0, words.length);
      final pageWords = words.sublist(startIndex, endIndex);
      pages.add(pageWords.join(' '));
      startIndex = endIndex;
    }
    // Safety check: ensure we have at least one page if content exists
    if (pages.isEmpty && widget.lesson.content.isNotEmpty) {
      pages.add(widget.lesson.content);
    }
    setState(() => _storyPages = pages);
  }

  void _markPageAsKnown(String pageContent) {
    if (!_autoMarkOnSwipe) return;
    final words = pageContent.split(RegExp(r'\s+'));
    for (var word in words) {
      final clean = _generateCleanId(word);
      if (clean.isEmpty) continue;
      final item = _vocabulary[clean];
      if (item == null || item.status == 0) {
        _updateWordStatus(clean, word.trim(), "", 5, showDialog: false);
      }
    }
  }

  Widget _buildInteractiveText(String content, bool isDark) {
    final words = content.split(' ');
    List<InlineSpan> spans = [];
    final Color baseTextColor = isDark ? Colors.white : Colors.black87;

    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      if (word.isEmpty) continue;
      final cleanWord = _generateCleanId(word);

      Color? highlightColor;
      Color wordColor = baseTextColor;
      FontWeight wordWeight = FontWeight.normal;

      final vocabItem = _vocabulary[cleanWord];
      if (vocabItem != null && vocabItem.status >= 1 && vocabItem.status <= 4) {
        highlightColor = _getStatusColor(vocabItem.status); 
        wordColor = Colors.black87;
        wordWeight = FontWeight.w600;
      } else if (vocabItem == null || vocabItem.status == 0) {
        highlightColor = Colors.blue.withOpacity(0.05); 
      }

      if (cleanWord.isEmpty) {
        spans.add(TextSpan(text: word, style: TextStyle(color: baseTextColor)));
      } else {
        spans.add(
          TextSpan(
            text: word,
            style: TextStyle(backgroundColor: highlightColor, color: wordColor, fontWeight: wordWeight),
            recognizer: TapGestureRecognizer()
              ..onTapUp = (TapUpDetails details) {
                _handleWordTap(cleanWord, word.trim(), isPhrase: false, tapPosition: details.globalPosition);
              },
          ),
        );
      }
      if (i < words.length - 1) spans.add(const TextSpan(text: ' '));
    }
    return Text.rich(TextSpan(style: TextStyle(fontSize: 19, height: 1.6, color: baseTextColor), children: spans));
  }

  Color _getStatusColor(int s) {
    if (s == 1) return const Color(0xFFFFF9C4);
    if (s == 2) return const Color(0xFFFFF59D);
    if (s == 3) return const Color(0xFFFFCC80);
    if (s == 4) return const Color(0xFFFFB74D);
    return Colors.transparent;
  }

  void _initializeTts() async {
    await _flutterTts.setLanguage(widget.lesson.language);
    await _flutterTts.setSpeechRate(0.5);
    if (!mounted) return;
    _flutterTts.setCompletionHandler(() {
      if (mounted) setState(() => _isTtsPlaying = false);
    });
  }

  Future<void> _loadVocabulary() async {
    if (!mounted) return;
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;
    try {
      final vocabService = context.read<VocabularyService>();
      final items = await vocabService.getVocabulary(authState.user.id);
      if (mounted) {
        setState(() => _vocabulary = {for (var item in items) item.word.toLowerCase(): item});
      }
    } catch (_) {}
  }

  String _generateCleanId(String text) => text.toLowerCase().trim().replaceAll(RegExp(r'[^\w\s]'), '');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final int totalPages = _storyPages.length + 1;
    final double progress = (_currentPage + 1) / totalPages;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        title: Text(widget.lesson.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) => _handleMenuAction(value),
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'toggle_mark_swipe',
                child: Row(children: [Icon(_autoMarkOnSwipe ? Icons.check_box : Icons.check_box_outline_blank, color: _autoMarkOnSwipe ? theme.primaryColor : Colors.grey), const SizedBox(width: 8), const Text('Mark known on swipe')]),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'save_library',
                child: Row(children: [Icon(_isSavedToLibrary ? Icons.bookmark : Icons.bookmark_border, color: _isSavedToLibrary ? theme.primaryColor : Colors.grey), const SizedBox(width: 8), Text(_isSavedToLibrary ? 'Saved to Library' : 'Save to Library')]),
              ),
              const PopupMenuItem<String>(
                value: 'copy_text',
                child: Row(children: [Icon(Icons.copy, color: Colors.grey), SizedBox(width: 8), Text('Copy Story Text')]),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: progress, backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200], valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor), minHeight: 4),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: totalPages,
        onPageChanged: (index) {
          if (index > _currentPage && _currentPage < _storyPages.length) _markPageAsKnown(_storyPages[_currentPage]);
          setState(() => _currentPage = index);
        },
        itemBuilder: (context, index) {
          if (index < _storyPages.length) return _buildStoryPage(_storyPages[index], isDark);
          else return _buildKeyPhrasesPage(isDark);
        },
      ),
      
      // --- UPDATED FLOATING ACTION BUTTON ---
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: "btn_audio",
            backgroundColor: isDark ? Colors.grey[800] : Colors.white,
            foregroundColor: _isTtsPlaying ? theme.primaryColor : (isDark ? Colors.white : Colors.black),
            onPressed: () {
              if (_isTtsPlaying) {
                _flutterTts.stop();
                setState(() => _isTtsPlaying = false);
              } else {
                setState(() => _isTtsPlaying = true);
                
                // Logic Fix:
                // 1. If on a story page, read THAT page.
                // 2. If on the Key Phrases page (last page), read the FULL STORY.
                if (_currentPage < _storyPages.length) {
                  _flutterTts.speak(_storyPages[_currentPage]);
                } else {
                   // Fallback: Read the full story if on Key Phrases page
                   // This prevents reading the key phrases list again.
                   _flutterTts.speak(widget.lesson.content);
                }
              }
            },
            child: Icon(_isTtsPlaying ? Icons.stop : Icons.volume_up),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: "btn_key",
            backgroundColor: theme.primaryColor,
            child: const Icon(Icons.vpn_key, color: Colors.white),
            onPressed: () => _pageController.animateToPage(_storyPages.length, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut),
          ),
          const SizedBox(height: 10),
        ],
      ),
      
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Launching Quiz..."))),
            style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            child: const Text("Start Practice Quiz", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
      ),
    );
  }

  void _handleMenuAction(String value) {
    if (value == 'toggle_mark_swipe') {
      setState(() => _autoMarkOnSwipe = !_autoMarkOnSwipe);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_autoMarkOnSwipe ? "Swipe will now mark pages as known" : "Swipe marking disabled"), duration: const Duration(seconds: 1)));
    } else if (value == 'save_library') {
      _toggleSaveToLibrary();
    } else if (value == 'copy_text') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Text copied to clipboard")));
    }
  }

  void _toggleSaveToLibrary() {
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    setState(() => _isSavedToLibrary = !_isSavedToLibrary);
    final updatedLesson = widget.lesson.copyWith(isFavorite: _isSavedToLibrary, userId: user.id);
    context.read<LessonBloc>().add(LessonUpdateRequested(updatedLesson));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isSavedToLibrary ? "Saved to your Library" : "Removed from Library"), duration: const Duration(seconds: 1)));
  }

  Widget _buildStoryPage(String content, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildInteractiveText(content, isDark), const SizedBox(height: 100)]),
    );
  }

  Widget _buildKeyPhrasesPage(bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      children: [
        Text("Key Phrases", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 5),
        Text("Tap to listen, Long press to translate", style: TextStyle(color: Colors.grey[600])),
        const SizedBox(height: 20),
        if (widget.lesson.sentences.isEmpty) const Padding(padding: EdgeInsets.all(16.0), child: Text("No key phrases available.")),
        ...widget.lesson.sentences.map((sentence) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[100],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.withOpacity(0.2))),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1), child: Icon(Icons.volume_up, color: Theme.of(context).primaryColor, size: 20)),
              title: Text(sentence, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87)),
              onTap: () => _flutterTts.speak(sentence),
              onLongPress: () {
                final size = MediaQuery.of(context).size;
                _handleWordTap(_generateCleanId(sentence), sentence, isPhrase: true, tapPosition: Offset(size.width / 2, size.height / 2));
              },
            ),
          );
        }),
        const SizedBox(height: 100),
      ],
    );
  }

  Future<void> _handleWordTap(String cleanWord, String originalWord, {required bool isPhrase, required Offset tapPosition}) async {
    if (_isCheckingLimit || !mounted) return;
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;
    final user = authState.user;

    if (user.isPremium) {
      _showDefinitionDialog(cleanWord, originalWord, isPhrase, user, tapPosition);
      return;
    }
    setState(() => _isCheckingLimit = true);
    try {
      final canAccess = await _checkAndIncrementFreeLimit(user.id);
      if (!mounted) return;
      setState(() => _isCheckingLimit = false);
      if (canAccess) _showDefinitionDialog(cleanWord, originalWord, isPhrase, user, tapPosition);
      else _showLimitDialog();
    } catch (e) {
      if (mounted) setState(() => _isCheckingLimit = false);
    }
  }

  Future<bool> _checkAndIncrementFreeLimit(String userId) async {
    final docRef = FirebaseFirestore.instance.collection('users').doc(userId).collection('limits').doc('dictionary');
    final snapshot = await docRef.get();
    final now = DateTime.now();
    if (!snapshot.exists) {
      await docRef.set({'count': 1, 'lastReset': FieldValue.serverTimestamp()});
      return true;
    }
    final data = snapshot.data()!;
    final DateTime lastReset = (data['lastReset'] as Timestamp?)?.toDate() ?? now;
    final int count = data['count'] ?? 0;
    if (now.difference(lastReset).inMinutes >= _kResetMinutes) {
      await docRef.set({'count': 1, 'lastReset': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      return true;
    } else {
      if (count < _kFreeLookupLimit) {
        await docRef.update({'count': FieldValue.increment(1)});
        return true;
      }
      return false;
    }
  }

  void _showDefinitionDialog(String cleanId, String originalText, bool isPhrase, dynamic user, Offset tapPosition) {
    if (_isTtsPlaying) _flutterTts.stop();
    if (!mounted) return;
    final translationService = context.read<TranslationService>();
    final VocabularyItem? existingItem = isPhrase ? null : _vocabulary[cleanId];
    final translationFuture = existingItem != null ? Future.value(existingItem.translation) : translationService.translate(originalText, user.nativeLanguage, widget.lesson.language);
    final geminiPrompt = "Translate and explain: '$originalText' (Language: ${widget.lesson.language} -> ${user.nativeLanguage}).";
    final geminiFuture = Gemini.instance.prompt(parts: [Part.text(geminiPrompt)]).then((v) => v?.output);

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => FloatingTranslationCard(
        originalText: originalText,
        translationFuture: translationFuture,
        geminiFuture: geminiFuture,
        targetLanguage: widget.lesson.language,
        nativeLanguage: user.nativeLanguage,
        currentStatus: existingItem?.status ?? 0,
        anchorPosition: tapPosition,
        onUpdateStatus: (status, translation) => _updateWordStatus(cleanId, originalText, translation, status),
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }

  void _showLimitDialog() {
    if (!mounted) return;
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text("Limit Reached"), content: const Text("Free translation limit reached. Upgrade to Premium for unlimited access."), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")), ElevatedButton(onPressed: () {Navigator.pop(context); showDialog(context: context, builder: (_) => const PremiumLockDialog());}, child: const Text("Upgrade"))]));
  }

  Future<void> _updateWordStatus(String cleanWord, String originalWord, String translation, int status, {bool showDialog = true}) async {
    if (!mounted) return;
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    final newItem = VocabularyItem(id: cleanWord, userId: user.id, word: originalWord, baseForm: cleanWord, language: widget.lesson.language, translation: translation, status: status, timesEncountered: 1, lastReviewed: DateTime.now(), createdAt: DateTime.now());
    if (mounted) {
      setState(() => _vocabulary[cleanWord] = newItem);
      context.read<VocabularyBloc>().add(VocabularyUpdateRequested(newItem));
    }
  }
}