import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/quiz/quiz_bloc.dart'; 

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final FlutterTts _tts = FlutterTts();
  String _targetLangCode = 'en';

  @override
  void initState() {
    super.initState();
    
    final authState = context.read<AuthBloc>().state;
    String targetLang = 'es';
    String nativeLang = 'en';

    if (authState is AuthAuthenticated) {
      targetLang = authState.user.currentLanguage;
      nativeLang = authState.user.nativeLanguage;
      _targetLangCode = targetLang; 
    }

    // Initialize TTS
    _tts.setLanguage(_targetLangCode);

    context.read<QuizBloc>().add(
      QuizLoadRequested(
        targetLanguage: targetLang,
        nativeLanguage: nativeLang,
      ),
    );
  }

  // --- SMART SPEAK HELPER ---
  // Only speaks if the text is in the target language.
  void _speakIfTargetLanguage(String text, bool isTargetLanguage) async {
    if (isTargetLanguage) {
      await _tts.setLanguage(_targetLangCode);
      await _tts.speak(text);
    }
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
            return ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: state.progress, 
                minHeight: 6,
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(Colors.blueAccent),
              ),
            );
          },
        ),
        actions: [
          BlocBuilder<QuizBloc, QuizState>(
            builder: (context, state) {
              return Padding(
                padding: const EdgeInsets.only(right: 20.0),
                child: Row(
                  children: [
                    Icon(Icons.favorite, color: Colors.redAccent, size: 20),
                    SizedBox(width: 6),
                    Text(
                      "${state.hearts}", 
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)
                    ),
                  ],
                ),
              );
            },
          )
        ],
      ),
      body: BlocConsumer<QuizBloc, QuizState>(
        listener: (context, state) {
          if (state.status == QuizStatus.completed) {
            _showCompletionDialog(context, isDark);
          }
        },
        builder: (context, state) {
          if (state.status == QuizStatus.loading) {
            return Center(child: CircularProgressIndicator());
          }

          final question = state.currentQuestion;
          if (question == null) return SizedBox();

          // --- DETERMINE AUDIO LOGIC ---
          // target_to_native: Question is Target (Speak), Options are Native (Silent)
          // native_to_target: Question is Native (Silent), Options are Target (Speak)
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
                      SizedBox(height: 20),
                      Text(
                        "Translate this sentence", 
                        style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)
                      ),
                      SizedBox(height: 24),
                      
                      // TARGET SENTENCE
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Only show speaker if question is in Target Language
                          if (isQuestionTargetLang) 
                            GestureDetector(
                              onTap: () => _speakIfTargetLanguage(question.targetSentence, true),
                              child: Container(
                                margin: EdgeInsets.only(right: 16),
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.volume_up, color: Colors.blueAccent, size: 24),
                              ),
                            ),
                          
                          Expanded(
                            child: Text(
                              question.targetSentence,
                              style: TextStyle(fontSize: 22, height: 1.4, color: textColor),
                            ),
                          ),
                        ],
                      ),
                      
                      Spacer(),

                      // SENTENCE BUILDER AREA
                      Container(
                        width: double.infinity,
                        constraints: BoxConstraints(minHeight: 80),
                        padding: EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: isDark ? Colors.white24 : Colors.black12, width: 1)),
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 12,
                          children: state.selectedWords.map((word) {
                            return _buildWordChip(
                              context,
                              word, 
                              isSelectedArea: true,
                              // Generally don't speak on deselect, or logic gets annoying
                              shouldSpeak: false, 
                              onTap: () => context.read<QuizBloc>().add(QuizOptionDeselected(word)),
                            );
                          }).toList(),
                        ),
                      ),
                      
                      Spacer(),

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
                                context.read<QuizBloc>().add(QuizOptionSelected(word));
                              },
                            );
                          }).toList(),
                        ),
                      ),
                      SizedBox(height: 40),
                    ],
                  ),
                ),
              ),

              // BOTTOM INTERACTION BAR
              _buildBottomBar(context, state, isDark),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWordChip(
    BuildContext context, 
    String word, 
    {
      required VoidCallback onTap, 
      required bool isSelectedArea,
      required bool shouldSpeak
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
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
          boxShadow: isSelectedArea ? [] : [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2,
              offset: Offset(0, 2),
            )
          ]
        ),
        child: Text(
          word, 
          style: TextStyle(
            fontSize: 16, 
            fontWeight: FontWeight.w500,
            color: isSelectedArea 
                ? Colors.blueAccent 
                : (isDark ? Colors.white : Colors.black87)
          )
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, QuizState state, bool isDark) {
    Widget content;
    Color bgColor = isDark ? Color(0xFF1E1E1E) : Colors.white;
    Color borderColor = isDark ? Colors.white10 : Colors.grey[200]!;

    // 1. ANSWERING
    if (state.status == QuizStatus.answering) {
      content = SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: state.selectedWords.isEmpty 
              ? null 
              : () => context.read<QuizBloc>().add(QuizCheckAnswer()),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            disabledBackgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
            disabledForegroundColor: Colors.grey[500],
            padding: EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: Text("Check Answer", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      );
    } 
    // 2. RESULT (Correct/Incorrect)
    else {
      final isCorrect = state.status == QuizStatus.correct;
      final correctTranslation = state.currentQuestion?.correctAnswer ?? "";
      
      bgColor = isCorrect ? (isDark ? Color(0xFF0F291E) : Color(0xFFE8F5E9)) : (isDark ? Color(0xFF2C1515) : Color(0xFFFFEBEE));
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
                size: 28
              ),
              SizedBox(width: 12),
              Text(
                isCorrect ? "Correct!" : "Incorrect",
                style: TextStyle(
                  fontSize: 20, 
                  fontWeight: FontWeight.bold, 
                  color: isCorrect ? Colors.green : Colors.redAccent
                ),
              ),
            ],
          ),
          if (!isCorrect) ...[
            SizedBox(height: 8),
            Text("Correct solution:", style: TextStyle(color: isCorrect ? Colors.green[800] : Colors.red[900], fontSize: 12, fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text(correctTranslation, style: TextStyle(color: isCorrect ? Colors.green[800] : Colors.red[900], fontSize: 16)),
          ],
          SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.read<QuizBloc>().add(QuizNextQuestion()),
              style: ElevatedButton.styleFrom(
                backgroundColor: isCorrect ? Colors.green : Colors.redAccent,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text("Continue", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      );
    }

    // Wrap in SafeArea to avoid overlap with Home Indicator on iOS
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
        backgroundColor: isDark ? Color(0xFF2C2C2C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Icon(Icons.emoji_events, size: 48, color: Colors.amber),
            SizedBox(height: 16),
            Text("Practice Complete", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
          ],
        ),
        content: Text("You've reviewed these words successfully!", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close Dialog
              Navigator.pop(context); // Close Quiz Screen
            },
            child: Text("Finish", style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}