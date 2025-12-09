import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/quiz/quiz_bloc.dart';
import 'package:linguaflow/services/quiz_service.dart';
import 'package:linguaflow/services/translation_service.dart';
import 'package:linguaflow/utils/language_helper.dart';

// --- IMPORT WIDGETS ---
import 'widgets/quiz_word_chip.dart';
import 'widgets/quiz_bottom_bar.dart';
import 'widgets/quiz_loading_view.dart';
import 'widgets/quiz_dialogs.dart';

class QuizScreen extends StatefulWidget {
  final List<dynamic>? initialQuestions;

  const QuizScreen({super.key, this.initialQuestions});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final FlutterTts _tts = FlutterTts();

  String _targetLangCode = 'en';
  String _targetLangName = 'English';
  String _targetFlag = '🇬🇧';

  Timer? _cooldownTimer;
  int _secondsRemaining = 0;
  int _retryCount = 0;
  bool _hasLoaded = false;

  @override
  void initState() {
    super.initState();
    _initializeAppSequence();
  }

  Future<void> _initializeAppSequence() async {
    if (Platform.isAndroid) await Future.delayed(const Duration(seconds: 1));
    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
    } catch (e) {
      print("TTS Config Warning: $e");
    }
    if (!mounted) return;
    if (context.read<QuizBloc>().state.status == QuizStatus.initial) {
      _loadQuiz();
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _tts.stop();
    super.dispose();
  }

  void _loadQuiz() async {
    if (_hasLoaded) return;
    _hasLoaded = true;

    final authState = context.read<AuthBloc>().state;
    String targetLang = 'es';
    String nativeLang = 'en';
    String userId = '';
    bool isPremium = false;

    if (authState is AuthAuthenticated) {
      targetLang = LanguageHelper.resolveCode(authState.user.currentLanguage);
      nativeLang = LanguageHelper.resolveCode(authState.user.nativeLanguage);
      userId = authState.user.id;
      isPremium = authState.user.isPremium;

      if (mounted) {
        setState(() {
          _targetLangCode = targetLang;
          _targetLangName = LanguageHelper.getLanguageName(targetLang);
          _targetFlag = LanguageHelper.getFlagEmoji(targetLang);
        });
      }
    }

    try {
      await _tts.setLanguage(_targetLangCode);
    } catch (e) {
      print("TTS setLanguage failed: $e");
    }

    if (!mounted) return;

    if (widget.initialQuestions != null && widget.initialQuestions!.isNotEmpty) {
      context.read<QuizBloc>().add(QuizStartWithQuestions(
          questions: widget.initialQuestions!,
          userId: userId,
          isPremium: isPremium));
    } else {
      context.read<QuizBloc>().add(QuizLoadRequested(
          promptType: QuizPromptType.dailyPractice,
          userId: userId,
          targetLanguage: targetLang,
          nativeLanguage: nativeLang,
          isPremium: isPremium));
    }
  }

  void _speakIfTargetLanguage(String text, bool isTargetLanguage) async {
    if (!isTargetLanguage || text.isEmpty) return;
    try {
      await _tts.setLanguage(_targetLangCode);
      await _tts.speak(text);
    } catch (e) {
      if (e.toString().contains("not bound")) {
        if (Platform.isAndroid) await Future.delayed(const Duration(milliseconds: 500));
        try {
          await _tts.setLanguage(_targetLangCode);
          await _tts.speak(text);
        } catch (_) {}
      }
    }
  }

  void _showWordHint(String cleanWord, String originalWord) {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    final translationFuture = context.read<TranslationService>().translate(
          originalWord,
          LanguageHelper.resolveCode(authState.user.nativeLanguage),
          LanguageHelper.resolveCode(authState.user.currentLanguage),
        );

    showDialog(
      context: context,
      barrierColor: Colors.black12,
      builder: (context) => QuizHintDialog(
        originalWord: originalWord,
        translationFuture: translationFuture.then((value) => value ?? ''),
        onSpeak: () => _speakIfTargetLanguage(originalWord, true),
      ),
    );
  }

  void _retryQuizLoad() {
    setState(() {
      _retryCount++;
      _hasLoaded = false;
    });
    _initializeAppSequence();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: BlocBuilder<QuizBloc, QuizState>(
          builder: (context, state) {
            if (state.status == QuizStatus.loading || state.status == QuizStatus.error) return const SizedBox();
            return ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: state.progress,
                minHeight: 6,
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation(Colors.blueAccent),
              ),
            );
          },
        ),
        actions: [
          BlocBuilder<QuizBloc, QuizState>(
            builder: (context, state) {
              if (state.status == QuizStatus.loading || state.status == QuizStatus.error) return const SizedBox();
              return Padding(
                padding: const EdgeInsets.only(right: 20.0),
                child: Row(
                  children: [
                    const Icon(Icons.favorite, color: Colors.redAccent, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      state.isPremium ? "∞" : "${state.hearts}",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<QuizBloc, QuizState>(
        listener: (context, state) {
          if (state.status == QuizStatus.completed) {
            QuizDialogs.showCompletion(context, isDark);
          }
          if (state.hearts <= 0 && !state.isPremium && state.status != QuizStatus.loading && state.status != QuizStatus.error) {
            QuizDialogs.showGameOver(context, isDark);
          }
          if (state.status == QuizStatus.error) {
            setState(() => _secondsRemaining = 60);
            _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
              if (mounted) setState(() => _secondsRemaining > 0 ? _secondsRemaining-- : t.cancel());
            });
            if (state.errorMessage != null && !state.errorMessage!.contains("429")) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.errorMessage!), backgroundColor: Colors.redAccent));
            }
          }
        },
        builder: (context, state) {
          if (state.status == QuizStatus.loading) {
            return QuizLoadingView(languageName: _targetLangName, flag: _targetFlag);
          }

          if (state.status == QuizStatus.error) {
            return _buildErrorView(state.errorMessage ?? "");
          }

          final question = state.currentQuestion;
          if (question == null) return const SizedBox();

          final isTargetQ = question.type == 'target_to_native';
          final areOptionsTarget = question.type == 'native_to_target';

          return Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      const Text("Translate this sentence", style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isTargetQ)
                            GestureDetector(
                              onTap: () => _speakIfTargetLanguage(question.targetSentence, true),
                              child: Container(
                                margin: const EdgeInsets.only(right: 16),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), shape: BoxShape.circle),
                                child: const Icon(Icons.volume_up, color: Colors.blueAccent, size: 24),
                              ),
                            ),
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: question.targetSentence.split(' ').map((word) {
                                final cleanWord = word.replaceAll(RegExp(r'[^\w\s]'), '');
                                if (isTargetQ) {
                                  return GestureDetector(
                                    onTap: () => _showWordHint(cleanWord, word),
                                    child: Container(
                                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.5), width: 1.5))),
                                      child: Text(word, style: TextStyle(fontSize: 22, height: 1.4, color: textColor)),
                                    ),
                                  );
                                } else {
                                  return Text(word, style: TextStyle(fontSize: 22, height: 1.4, color: textColor));
                                }
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      
                      // SELECTED AREA
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(minHeight: 80),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isDark ? Colors.white24 : Colors.black12, width: 1))),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 12,
                          children: state.selectedWords.map((word) {
                            return QuizWordChip(
                              word: word,
                              isSelectedArea: true,
                              onTap: () => context.read<QuizBloc>().add(QuizOptionDeselected(word)),
                            );
                          }).toList(),
                        ),
                      ),
                      const Spacer(),
                      
                      // WORD BANK
                      Center(
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 16,
                          alignment: WrapAlignment.center,
                          children: state.availableWords.map((word) {
                            return QuizWordChip(
                              word: word,
                              isSelectedArea: false,
                              shouldSpeak: areOptionsTarget,
                              onSpeak: (w) => _speakIfTargetLanguage(w, true),
                              onTap: () => context.read<QuizBloc>().add(QuizOptionSelected(word)),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
              QuizBottomBar(
                state: state,
                onCheck: () => context.read<QuizBloc>().add(QuizCheckAnswer()),
                onNext: () => context.read<QuizBloc>().add(QuizNextQuestion()),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildErrorView(String msg) {
    final bool isFinalFailure = _retryCount >= 2;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isFinalFailure ? Icons.block : Icons.access_time_filled, size: 64, color: isFinalFailure ? Colors.red : Colors.orange),
            const SizedBox(height: 16),
            Text(isFinalFailure ? "Limit Reached" : "Server Busy", style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(isFinalFailure ? "Please try again tomorrow." : "AI is busy. Please retry.", textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 30),
            if (!isFinalFailure)
              ElevatedButton(
                  onPressed: _secondsRemaining > 0 ? null : _retryQuizLoad,
                  child: Text(_secondsRemaining > 0 ? "Wait ${_secondsRemaining}s" : "Retry Now")),
            if (isFinalFailure)
              ElevatedButton.icon(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back), label: const Text("Go Back")),
          ],
        ),
      ),
    );
  }
}