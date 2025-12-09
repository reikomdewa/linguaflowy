import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/quiz/quiz_bloc.dart';
import 'package:linguaflow/services/quiz_service.dart';
import 'package:linguaflow/services/translation_service.dart';
import 'package:linguaflow/widgets/premium_lock_dialog.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final FlutterTts _tts = FlutterTts();
  String _targetLangCode = 'en';
  String _targetLangName = 'Target Language';

  // --- ERROR HANDLING VARIABLES ---
  Timer? _cooldownTimer;
  int _secondsRemaining = 0;
  int _retryCount = 0;
  
  // --- GUARD VARIABLE ---
  bool _hasLoaded = false; // Ensures load happens only once

  @override
  void initState() {
    super.initState();
    // Only load if the bloc is in initial state or we explicitly want to start
    final currentState = context.read<QuizBloc>().state;
    if (currentState.status == QuizStatus.initial) {
      _loadQuiz();
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _loadQuiz() {
    if (_hasLoaded) return; // Prevent double execution
    _hasLoaded = true;

    final authState = context.read<AuthBloc>().state;
    String targetLang = 'es';
    String nativeLang = 'en';
    String userId = '';
    bool isPremium = false;

    if (authState is AuthAuthenticated) {
      targetLang = authState.user.currentLanguage;
      nativeLang = authState.user.nativeLanguage;
      userId = authState.user.id;
      isPremium = authState.user.isPremium;

      setState(() {
        _targetLangCode = targetLang;
        _targetLangName = targetLang.toUpperCase();
      });
    }

    _tts.setLanguage(_targetLangCode);

    context.read<QuizBloc>().add(
          QuizLoadRequested(
            promptType: QuizPromptType.dailyPractice,
            userId: userId,
            targetLanguage: targetLang,
            nativeLanguage: nativeLang,
            isPremium: isPremium,
          ),
        );
  }

  void _retryQuizLoad() {
    setState(() {
      _retryCount++;
      _hasLoaded = false; // Allow loading again
    });
    _loadQuiz();
  }

  // --- ERROR HELPERS ---

  void _startCooldown() {
    setState(() {
      _secondsRemaining = 60; 
    });

    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
          } else {
            _cooldownTimer?.cancel();
          }
        });
      }
    });
  }

  String _getFriendlyErrorMessage(String error) {
    if (_retryCount >= 1) {
      return "The AI is busy. Please try again in 1 minute.";
    }
    // Handle the custom exception we threw in the Service
    if (error.contains("429") || error.contains("Too many requests")) {
      return "Server is busy. Please wait a moment.";
    }
    if (error.contains("SocketException") || error.contains("Network")) {
      return "Check your internet connection.";
    }
    return "Unable to generate quiz. Please retry.";
  }

  void _speakIfTargetLanguage(String text, bool isTargetLanguage) async {
    if (isTargetLanguage) {
      await _tts.setLanguage(_targetLangCode);
      await _tts.speak(text);
    }
  }

  void _showWordHint(String cleanWord, String originalWord) {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    final user = authState.user;
    final translationService = context.read<TranslationService>();

    final translationFuture = translationService.translate(
      originalWord,
      user.nativeLanguage,
      user.currentLanguage,
    );

    showDialog(
      context: context,
      barrierColor: Colors.black12,
      builder: (context) {
        return _HintDialog(
          originalWord: originalWord,
          translationFuture: translationFuture.then((value) => value ?? ''),
          onSpeak: () => _speakIfTargetLanguage(originalWord, true),
        );
      },
    );
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
            if (state.status == QuizStatus.loading ||
                state.status == QuizStatus.error) {
              return const SizedBox();
            }

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
              if (state.status == QuizStatus.loading ||
                  state.status == QuizStatus.error) {
                return const SizedBox();
              }

              return Padding(
                padding: const EdgeInsets.only(right: 20.0),
                child: Row(
                  children: [
                    const Icon(
                      Icons.favorite,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      state.isPremium
                          ? "∞"
                          : "${state.hearts}",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
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
            _showCompletionDialog(context, isDark);
          }
          if (state.hearts <= 0 &&
              !state.isPremium &&
              state.status != QuizStatus.loading &&
              state.status != QuizStatus.error) {
            _showGameOverDialog(context, isDark);
          }

          // --- ERROR HANDLING LISTENER ---
          if (state.status == QuizStatus.error) {
            _startCooldown();
            
            // Only show snackbar if we aren't showing the full error screen
            // (The builder below handles the full screen error view)
            if (state.errorMessage != null && !state.errorMessage!.contains("429")) {
               ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage ?? "An error occurred"),
                  backgroundColor: Colors.redAccent,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        },
        builder: (context, state) {
          // 1. LOADING
          if (state.status == QuizStatus.loading) {
            return _LoadingWithTips(languageName: _targetLangName);
          }

          // 2. ERROR / RETRY VIEW
          if (state.status == QuizStatus.error) {
            final bool isFinalFailure = _retryCount >= 2;
            final errorMessage =
                _getFriendlyErrorMessage(state.errorMessage ?? "");

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isFinalFailure ? Icons.block : Icons.access_time_filled,
                      size: 64,
                      color: isFinalFailure ? Colors.red : Colors.orange,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isFinalFailure ? "Limit Reached" : "Server Busy",
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isFinalFailure
                          ? "We cannot generate the quiz right now. Please try again tomorrow."
                          : errorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                    const SizedBox(height: 30),

                    if (!isFinalFailure)
                      ElevatedButton(
                        onPressed: _secondsRemaining > 0
                            ? null
                            : _retryQuizLoad,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 14),
                          backgroundColor: Colors.blueAccent,
                        ),
                        child: Text(
                          _secondsRemaining > 0
                              ? "Wait ${_secondsRemaining}s"
                              : "Retry Now",
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),

                    if (isFinalFailure)
                      ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text("Go Back"),
                      ),
                  ],
                ),
              ),
            );
          }

          final question = state.currentQuestion;
          // Fallback initial state
          if (question == null) return const SizedBox();

          // 3. MAIN QUIZ UI
          final bool isQuestionTargetLang = question.type == 'target_to_native';
          final bool areOptionsTargetLang = question.type == 'native_to_target';

          return Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      const Text(
                        "Translate this sentence",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isQuestionTargetLang)
                            GestureDetector(
                              onTap: () => _speakIfTargetLanguage(
                                question.targetSentence,
                                true,
                              ),
                              child: Container(
                                margin: const EdgeInsets.only(right: 16),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.volume_up,
                                  color: Colors.blueAccent,
                                  size: 24,
                                ),
                              ),
                            ),

                          // CLICKABLE WORDS WRAP
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: question.targetSentence.split(' ').map((
                                word,
                              ) {
                                final cleanWord = word.replaceAll(
                                  RegExp(r'[^\w\s]'),
                                  '',
                                );

                                if (isQuestionTargetLang) {
                                  return GestureDetector(
                                    onTap: () => _showWordHint(cleanWord, word),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Colors.grey.withOpacity(0.5),
                                            width: 1.5,
                                            style: BorderStyle.solid,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        word,
                                        style: TextStyle(
                                          fontSize: 22,
                                          height: 1.4,
                                          color: textColor,
                                        ),
                                      ),
                                    ),
                                  );
                                } else {
                                  return Text(
                                    word,
                                    style: TextStyle(
                                      fontSize: 22,
                                      height: 1.4,
                                      color: textColor,
                                    ),
                                  );
                                }
                              }).toList(),
                            ),
                          ),
                        ],
                      ),

                      const Spacer(),

                      // SENTENCE BUILDER AREA
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(minHeight: 80),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: isDark ? Colors.white24 : Colors.black12,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 12,
                          children: state.selectedWords.map((word) {
                            return _buildWordChip(
                              context,
                              word,
                              isSelectedArea: true,
                              shouldSpeak: false,
                              onTap: () => context.read<QuizBloc>().add(
                                    QuizOptionDeselected(word),
                                  ),
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
                            return _buildWordChip(
                              context,
                              word,
                              isSelectedArea: false,
                              shouldSpeak: areOptionsTargetLang,
                              onTap: () {
                                context.read<QuizBloc>().add(
                                      QuizOptionSelected(word),
                                    );
                              },
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),

              _buildBottomBar(context, state, isDark),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWordChip(
    BuildContext context,
    String word, {
    required VoidCallback onTap,
    required bool isSelectedArea,
    required bool shouldSpeak,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        if (shouldSpeak) {
          _speakIfTargetLanguage(word, true);
        }
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelectedArea
              ? (isDark ? Colors.blueAccent.withOpacity(0.2) : Colors.blue[50])
              : (isDark ? Colors.grey[800] : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelectedArea
                ? Colors.transparent
                : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
            width: 1,
          ),
          boxShadow: isSelectedArea
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Text(
          word,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: isSelectedArea
                ? Colors.blueAccent
                : (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, QuizState state, bool isDark) {
    Widget content;
    Color bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    Color borderColor = isDark ? Colors.white10 : Colors.grey[200]!;

    if (state.status == QuizStatus.answering) {
      content = SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: state.selectedWords.isEmpty
              ? null
              : () => context.read<QuizBloc>().add(QuizCheckAnswer()),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            disabledBackgroundColor:
                isDark ? Colors.grey[800] : Colors.grey[300],
            disabledForegroundColor: Colors.grey[500],
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: const Text(
            "Check Answer",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    } else {
      final isCorrect = state.status == QuizStatus.correct;
      final correctTranslation = state.currentQuestion?.correctAnswer ?? "";

      bgColor = isCorrect
          ? (isDark ? const Color(0xFF0F291E) : const Color(0xFFE8F5E9))
          : (isDark ? const Color(0xFF2C1515) : const Color(0xFFFFEBEE));
      borderColor = Colors.transparent;

      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle_outline : Icons.error_outline,
                color: isCorrect ? Colors.green : Colors.redAccent,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                isCorrect ? "Correct!" : "Incorrect",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isCorrect ? Colors.green : Colors.redAccent,
                ),
              ),
            ],
          ),
          if (!isCorrect) ...[
            const SizedBox(height: 8),
            Text(
              "Correct solution:",
              style: TextStyle(
                color: isCorrect ? Colors.green[800] : Colors.red[900],
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              correctTranslation,
              style: TextStyle(
                color: isCorrect ? Colors.green[800] : Colors.red[900],
                fontSize: 16,
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.read<QuizBloc>().add(QuizNextQuestion()),
              style: ElevatedButton.styleFrom(
                backgroundColor: isCorrect ? Colors.green : Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                "Continue",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(top: BorderSide(color: borderColor, width: 1)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: content,
        ),
      ),
    );
  }

  void _showCompletionDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            const Icon(Icons.emoji_events, size: 48, color: Colors.amber),
            const SizedBox(height: 16),
            Text(
              "Practice Complete",
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
          ],
        ),
        content: const Text(
          "You've reviewed these words successfully!",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text(
              "Finish",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showGameOverDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            const Icon(Icons.heart_broken, size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              "Out of Hearts!",
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
          ],
        ),
        content: const Text(
          "You made too many mistakes. Upgrade to Premium for infinite hearts and continue learning!",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text(
              "Quit",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const PremiumLockDialog(),
              ).then((unlocked) {
                if (unlocked == true) {
                  context.read<AuthBloc>().add(AuthCheckRequested());
                  context.read<QuizBloc>().add(QuizReviveRequested());
                  Navigator.pop(context);
                }
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
              elevation: 4,
            ),
            child: const Text("Get Unlimited Hearts"),
          ),
        ],
      ),
    );
  }
}

// --- POPUP DIALOG ---
class _HintDialog extends StatelessWidget {
  final String originalWord;
  final Future<String> translationFuture;
  final VoidCallback onSpeak;

  const _HintDialog({
    required this.originalWord,
    required this.translationFuture,
    required this.onSpeak,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      alignment: Alignment.center,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  originalWord,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                IconButton(
                  onPressed: onSpeak,
                  icon: const Icon(Icons.volume_up, color: Colors.blueAccent),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const Divider(height: 20),
            const Text(
              "Meaning:",
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            FutureBuilder<String>(
              future: translationFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }
                if (snapshot.hasError) {
                  return const Text("-", style: TextStyle(color: Colors.grey));
                }
                return Text(
                  snapshot.data ?? "...",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.blueAccent,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// --- LOADING TIPS ---
class _LoadingWithTips extends StatefulWidget {
  final String languageName;

  const _LoadingWithTips({required this.languageName});

  @override
  State<_LoadingWithTips> createState() => _LoadingWithTipsState();
}

class _LoadingWithTipsState extends State<_LoadingWithTips> {
  int _currentTipIndex = 0;
  Timer? _timer;
  late final List<String> _tips;

  @override
  void initState() {
    super.initState();
    _tips = [
      "Speaking out loud helps your memory retain words up to 50% better.",
      "Don't worry about making mistakes. They are just proof that you are learning.",
      "Consistency is key! 15 minutes a day is better than 2 hours once a week.",
      "Sleep is crucial. Your brain processes new vocabulary while you rest.",
      "Set small, achievable goals. 'Learn 5 words today' is better than 'Learn ${widget.languageName} this year'.",
      "Learning a language changes your brain structure and improves cognitive flexibility.",
      "Try to think in ${widget.languageName} for just 1 minute a day.",
      "Immersion is the fastest way to learn. Watch videos in ${widget.languageName}!",
      "Spaced Repetition helps move words from short-term to long-term memory.",
      "Polyglots often talk to themselves in their target language. Give it a try!",
      "Try the 'Shadowing' technique: Repeat audio immediately after hearing it to improve your accent.",
      "Label items in your house with post-it notes in ${widget.languageName}.",
      "Record yourself speaking ${widget.languageName} and compare it to a native speaker.",
      "Switch your phone's interface language to ${widget.languageName} for constant exposure.",
      "Listening to music in ${widget.languageName} helps you master the rhythm and intonation.",
      "Watch movies with ${widget.languageName} subtitles to connect spoken sounds with written words.",
      "Learn the 1,000 most common words first. They make up 80% of daily conversation.",
      "Look for 'cognates'—words that look and sound similar in your native language and ${widget.languageName}.",
      "Try to guess a word's meaning from the context before looking up the translation.",
      "Don't just learn words; learn phrases. Context makes memory stickier!",
    ];

    _tips.shuffle();

    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          _currentTipIndex = (_currentTipIndex + 1) % _tips.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Loading...",
              style: TextStyle(fontSize: 24, color: Colors.grey[400]),
            ),
            const SizedBox(height: 20),

            SizedBox(
              height: 100,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: Text(
                  _tips[_currentTipIndex],
                  key: ValueKey<int>(_currentTipIndex),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}