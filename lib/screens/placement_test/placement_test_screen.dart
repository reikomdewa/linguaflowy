import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/quiz/quiz_bloc.dart';
import 'package:linguaflow/screens/story_mode/widgets/loading_view.dart';
import 'package:linguaflow/services/quiz_service.dart';

class PlacementTestScreen extends StatelessWidget {
  final String nativeLanguage;
  final String targetLanguage;
  final String userId;
  final String targetLevelToCheck;

  const PlacementTestScreen({
    super.key,
    required this.nativeLanguage,
    required this.targetLanguage,
    required this.targetLevelToCheck,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => QuizBloc()
        ..add(
          QuizLoadRequested(
            userId: userId,
            targetLanguage: targetLanguage,
            nativeLanguage: nativeLanguage,
            isPremium: true,
            promptType: QuizPromptType.placementTest,
          ),
        ),
      child: _PlacementTestView(
        targetLevel: targetLevelToCheck,
        userId: userId,
        targetLanguage: targetLanguage,
        nativeLanguage: nativeLanguage,
      ),
    );
  }
}

class _PlacementTestView extends StatefulWidget {
  final String targetLevel;
  final String userId;
  final String targetLanguage;
  final String nativeLanguage;

  const _PlacementTestView({
    required this.targetLevel,
    required this.userId,
    required this.targetLanguage,
    required this.nativeLanguage,
  });

  @override
  State<_PlacementTestView> createState() => _PlacementTestViewState();
}

class _PlacementTestViewState extends State<_PlacementTestView> {
  late String _randomTip;
  // Track how many times the user has hit "Retry"
  int _retryCount = 0;

  final List<String> _placementTips = [
    "This test helps us recommend the perfect content for you.",
    "Don't worry about mistakes. They help us gauge your level accurately.",
    "Accuracy is more important than speed right now.",
    "We are calibrating your vocabulary and grammar profile.",
    "You can always change your difficulty level later in settings.",
  ];

  @override
  void initState() {
    super.initState();
    _randomTip = _placementTips[Random().nextInt(_placementTips.length)];
  }

  /// Helper to convert technical exceptions into user-friendly text
  String _getFriendlyErrorMessage(String error) {
    // If we have already retried and failed again
    if (_retryCount >= 1) {
      return "The AI cannot make the test right now as it is busy. Please try again later.";
    }

    if (error.contains("429") || error.contains("Too Many Requests")) {
      return "The AI server is currently busy. Please wait a moment and try again.";
    }
    if (error.contains("SocketException") || error.contains("Network")) {
      return "Please check your internet connection.";
    }
    return "Unable to generate test due to api calls. Upgrade to premium to help us so solve this. Please try again later.";
  }

  void _retryQuizLoad() {
    // Increment retry count so we know if this next attempt fails, it's the second time
    setState(() {
      _retryCount++;
    });

    context.read<QuizBloc>().add(
      QuizLoadRequested(
        userId: widget.userId,
        targetLanguage: widget.targetLanguage,
        nativeLanguage: widget.nativeLanguage,
        isPremium: true,
        promptType: QuizPromptType.placementTest,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return BlocConsumer<QuizBloc, QuizState>(
      listener: (context, state) {
        if (state.status == QuizStatus.completed) {
          _calculateAndReturnLevel(context, state);
        }

        // --- 1. SHOW SNACKBAR ON ERROR ---
        if (state.status == QuizStatus.error) {
          final message = _getFriendlyErrorMessage(state.errorMessage ?? "");

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
              // Only show the "Retry" button on the SnackBar if we haven't failed twice yet
              action: _retryCount < 1
                  ? SnackBarAction(
                      label: "Retry",
                      textColor: Colors.white,
                      onPressed: _retryQuizLoad,
                    )
                  : null, // No retry action on second failure
            ),
          );
        }
      },
      builder: (context, state) {
        // --- 2. LOADING STATE ---
        if (state.status == QuizStatus.loading) {
          return LoadingView(
            tip: _randomTip,
            title: "Preparing Test...",
            subtitle: "Calibrating questions for ${widget.targetLevel}",
          );
        }

        // --- 3. ERROR STATE UI ---
        if (state.status == QuizStatus.error) {
          final bool isFinalFailure = _retryCount >= 1;
          final errorMessage = _getFriendlyErrorMessage(
            state.errorMessage ?? "",
          );

          return Scaffold(
            backgroundColor: bgColor,
            appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isFinalFailure
                          ? Icons.sentiment_dissatisfied
                          : Icons.cloud_off,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isFinalFailure ? "System Busy" : "Oops!",
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      errorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                    const SizedBox(height: 24),

                    // Button Logic: Retry if first time, Go Back if second time
                    ElevatedButton.icon(
                      onPressed: isFinalFailure
                          ? () => Navigator.of(context)
                                .pop() // Close screen
                          : _retryQuizLoad, // Try again
                      icon: Icon(
                        isFinalFailure ? Icons.arrow_back : Icons.refresh,
                      ),
                      label: Text(isFinalFailure ? "Go Back" : "Try Again"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        backgroundColor: isFinalFailure
                            ? Colors.grey
                            : Colors.blueAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final question = state.currentQuestion;

        // Handle "initial" or empty state
        if (question == null) {
          if (state.status == QuizStatus.initial) {
            return const Center(child: CircularProgressIndicator());
          }
          return const Center(child: Text("Initializing..."));
        }

        // --- 4. REGULAR QUIZ UI ---
        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            title: Text("Placement Test: ${widget.targetLevel}"),
            centerTitle: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
          ),
          body: Column(
            children: [
              // Progress Bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: state.progress,
                    minHeight: 12,
                    backgroundColor: isDark
                        ? Colors.grey[800]
                        : Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation(Colors.blueAccent),
                  ),
                ),
              ),

              const Spacer(flex: 1),

              // Prompt
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  question.targetSentence,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 30),

              // Selection Area
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 80),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.grey[300]!,
                    width: 2,
                  ),
                ),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: state.selectedWords.isEmpty
                      ? [
                          Padding(
                            padding: const EdgeInsets.only(top: 12.0),
                            child: Text(
                              "Tap words to translate",
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white38
                                    : Colors.grey[500],
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ]
                      : state.selectedWords.map((word) {
                          return _buildWordChip(
                            context,
                            word,
                            isDark,
                            isSelectedArea: true,
                          );
                        }).toList(),
                ),
              ),

              const Spacer(flex: 1),

              // Word Bank
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: state.availableWords.map((word) {
                    return _buildWordChip(
                      context,
                      word,
                      isDark,
                      isSelectedArea: false,
                    );
                  }).toList(),
                ),
              ),

              const Spacer(flex: 2),

              // Bottom Area
              _buildBottomActionArea(context, state, isDark),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWordChip(
    BuildContext context,
    String word,
    bool isDark, {
    required bool isSelectedArea,
  }) {
    return GestureDetector(
      onTap: () {
        if (isSelectedArea) {
          context.read<QuizBloc>().add(QuizOptionDeselected(word));
        } else {
          context.read<QuizBloc>().add(QuizOptionSelected(word));
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDark
              ? (isSelectedArea
                    ? Colors.blueAccent.withValues(alpha: 0.2)
                    : Colors.grey[800])
              : (isSelectedArea ? Colors.blue[50] : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelectedArea
                ? Colors.transparent
                : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
            width: 1.5,
          ),
        ),
        child: Text(
          word,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActionArea(
    BuildContext context,
    QuizState state,
    bool isDark,
  ) {
    bool isCorrect = state.status == QuizStatus.correct;
    bool isIncorrect = state.status == QuizStatus.incorrect;
    bool isAnswered = isCorrect || isIncorrect;

    Color feedbackColor = isCorrect
        ? Colors.green.shade100
        : Colors.red.shade100;
    Color feedbackTextColor = isCorrect
        ? Colors.green.shade900
        : Colors.red.shade900;
    if (isDark) {
      feedbackColor = isCorrect
          ? Colors.green.withValues(alpha: 0.2)
          : Colors.red.withValues(alpha: 0.2);
      feedbackTextColor = isCorrect ? Colors.greenAccent : Colors.redAccent;
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isAnswered ? feedbackColor : Colors.transparent,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isAnswered) ...[
                Row(
                  children: [
                    Icon(
                      isCorrect ? Icons.check_circle : Icons.error,
                      color: feedbackTextColor,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isCorrect ? "Excellent!" : "Not quite right",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: feedbackTextColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    if (isAnswered) {
                      context.read<QuizBloc>().add(QuizNextQuestion());
                    } else {
                      context.read<QuizBloc>().add(QuizCheckAnswer());
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAnswered
                        ? (isCorrect ? Colors.green : Colors.red)
                        : (state.selectedWords.isNotEmpty
                              ? Colors.blue
                              : Colors.grey),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    isAnswered ? "Continue" : "Check Answer",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
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

  void _calculateAndReturnLevel(BuildContext context, QuizState state) {
    final total = state.questions.length;
    final score = state.correctAnswersCount;

    double scorePercentage = total > 0 ? score / total : 0.0;

    String finalLevel;
    if (scorePercentage > 0.8) {
      finalLevel = widget.targetLevel;
    } else if (scorePercentage > 0.4) {
      finalLevel = _getLevelBelow(widget.targetLevel);
    } else {
      finalLevel = "A1 - Newcomer";
    }
    Navigator.of(context).pop(finalLevel);
  }

  String _getLevelBelow(String current) {
    if (current.contains("C1")) return "B2 - Upper Intermediate";
    if (current.contains("B2")) return "B1 - Intermediate";
    if (current.contains("B1")) return "A2 - Elementary";
    if (current.contains("A2")) return "A1 - Beginner";
    return "A1 - Newcomer";
  }
}
