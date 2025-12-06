import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/quiz/quiz_bloc.dart';

class PlacementTestScreen extends StatelessWidget {
  final String nativeLanguage;
  final String targetLanguage;
  final String targetLevelToCheck; // e.g. "B2 - Upper Intermediate"

  const PlacementTestScreen({
    super.key,
    required this.nativeLanguage,
    required this.targetLanguage,
    required this.targetLevelToCheck,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => QuizBloc()
        ..add(
          QuizLoadRequested(
            targetLanguage: targetLanguage,
            nativeLanguage: nativeLanguage,
            isPremium: true,
            // In a real app, you might pass the 'level' to the API here
            // level: targetLevelToCheck 
          ),
        ),
      child: _PlacementTestView(targetLevel: targetLevelToCheck),
    );
  }
}

class _PlacementTestView extends StatelessWidget {
  final String targetLevel;
  const _PlacementTestView({required this.targetLevel});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("Placement Test: $targetLevel"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: BlocConsumer<QuizBloc, QuizState>(
        listener: (context, state) {
          if (state.status == QuizStatus.completed) {
            _calculateAndReturnLevel(context, state);
          }
        },
        builder: (context, state) {
          if (state.status == QuizStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          final question = state.currentQuestion;
          if (question == null) {
            return const Center(child: Text("Preparing test..."));
          }

          // --- UI LAYOUT ---
          return Column(
            children: [
              // 1. Progress Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: state.progress,
                    minHeight: 12,
                    backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation(Colors.blueAccent),
                  ),
                ),
              ),

              const Spacer(flex: 1),

              // 2. Target Sentence (Prompt)
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

              // 3. Sentence Builder Area
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 80),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
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
                                color: isDark ? Colors.white38 : Colors.grey[500],
                                fontSize: 16,
                              ),
                            ),
                          )
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

              // 4. Word Bank
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
                      isSelectedArea: false
                    );
                  }).toList(),
                ),
              ),

              const Spacer(flex: 2),

              // 5. Action Area (Bottom Sheet style)
              _buildBottomActionArea(context, state, isDark),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWordChip(BuildContext context, String word, bool isDark, {required bool isSelectedArea}) {
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
              ? (isSelectedArea ? Colors.blueAccent.withOpacity(0.2) : Colors.grey[800]) 
              : (isSelectedArea ? Colors.blue[50] : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelectedArea ? Colors.transparent : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
            width: 1.5,
          ),
          boxShadow: isSelectedArea ? [] : [
             BoxShadow(color: Colors.black.withOpacity(0.05), offset: const Offset(0, 3), blurRadius: 0)
          ],
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

  Widget _buildBottomActionArea(BuildContext context, QuizState state, bool isDark) {
    bool isCorrect = state.status == QuizStatus.correct;
    bool isIncorrect = state.status == QuizStatus.incorrect;
    bool isAnswered = isCorrect || isIncorrect;

    Color feedbackColor = isCorrect ? Colors.green.shade100 : Colors.red.shade100;
    Color feedbackTextColor = isCorrect ? Colors.green.shade900 : Colors.red.shade900;
    if (isDark) {
      feedbackColor = isCorrect ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2);
      feedbackTextColor = isCorrect ? Colors.greenAccent : Colors.redAccent;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isAnswered ? feedbackColor : Colors.transparent,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                    : (state.selectedWords.isNotEmpty ? Colors.blue : Colors.grey),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text(
                isAnswered ? "Continue" : "Check Answer",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _calculateAndReturnLevel(BuildContext context, QuizState state) {
    // 1. Calculate Score (Assuming QuizState tracks 'correctCount' or we derive it)
    // If QuizBloc doesn't expose score directly, assume simpler logic or update Bloc.
    // Here we use the user's previous logic of progress/accuracy approximation.
    
    // For a placement test, we compare correctness vs total questions.
    // Let's assume state has `correctAnswersCount` added to it, 
    // OR we approximate that if they finished, we calculate accuracy.
    
    // MOCK CALCULATION based on "completion":
    // Ideally, pass the actual score from the Bloc.
    double scorePercentage = 0.85; // REPLACE THIS with `state.score / state.totalQuestions`
    
    String finalLevel;

    // 2. Determine Level based on the Target they wanted
    // If they ace the test (>80%), they get the level they asked for.
    // If they struggle (40-80%), they get one level lower.
    // If they fail (<40%), they get Beginner.
    
    if (scorePercentage > 0.8) {
      finalLevel = targetLevel; // e.g. "B2 - Upper Intermediate"
    } else if (scorePercentage > 0.4) {
      finalLevel = _getLevelBelow(targetLevel);
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