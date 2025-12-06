import 'dart:math'; // For random tip
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
    required this.targetLevelToCheck, required this.userId,
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
            // PASS THE TYPE HERE
            promptType: QuizPromptType.placementTest,
          ),
        ),
      child: _PlacementTestView(targetLevel: targetLevelToCheck),
    );
  }
}

class _PlacementTestView extends StatefulWidget {
  final String targetLevel;
  const _PlacementTestView({required this.targetLevel});

  @override
  State<_PlacementTestView> createState() => _PlacementTestViewState();
}

class _PlacementTestViewState extends State<_PlacementTestView> {
  late String _randomTip;

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
    // Pick a random tip when the screen loads
    _randomTip = _placementTips[Random().nextInt(_placementTips.length)];
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
      },
      builder: (context, state) {
        // --- 1. USE THE REUSABLE LOADING VIEW ---
        if (state.status == QuizStatus.loading) {
          return LoadingView(
            tip: _randomTip,
            title: "Preparing Test...",
            subtitle: "Calibrating questions for ${widget.targetLevel}",
          );
        }

        final question = state.currentQuestion;
        if (question == null) {
          return const Center(child: Text("Preparing test..."));
        }

        // --- 2. REGULAR QUIZ UI ---
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
                      ? Colors.white.withOpacity(0.05)
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

  // ... (Keep existing _buildWordChip and _calculateAndReturnLevel methods) ...

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
                    ? Colors.blueAccent.withOpacity(0.2)
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
          ? Colors.green.withOpacity(0.2)
          : Colors.red.withOpacity(0.2);
      feedbackTextColor = isCorrect ? Colors.greenAccent : Colors.redAccent;
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isAnswered ? feedbackColor : Colors.transparent,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      // SAFE AREA FIX for bottom button
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
    // REAL LOGIC: Use the score from state
    final total = state.questions.length;
    final score = state.correctAnswersCount;

    // Safety check div by zero
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
