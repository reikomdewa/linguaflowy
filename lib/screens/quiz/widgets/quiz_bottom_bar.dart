import 'package:flutter/material.dart';
import 'package:linguaflow/blocs/quiz/quiz_bloc.dart';

class QuizBottomBar extends StatelessWidget {
  final QuizState state;
  final VoidCallback onCheck;
  final VoidCallback onNext;

  const QuizBottomBar({
    super.key,
    required this.state,
    required this.onCheck,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Widget content;
    Color bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    Color borderColor = isDark ? Colors.white10 : Colors.grey[200]!;

    if (state.status == QuizStatus.answering) {
      // --- STATE: ANSWERING ---
      content = SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: state.selectedWords.isEmpty ? null : onCheck,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            disabledBackgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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
      // --- STATE: FEEDBACK (Correct/Incorrect) ---
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
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: isCorrect ? Colors.green : Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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

    // --- SAFEAREA FIX ---
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(top: BorderSide(color: borderColor, width: 1)),
      ),
      child: SafeArea(
        top: false, // Color extends to content
        child: Padding(
          padding: const EdgeInsets.only(left: 24, right: 24, top: 20, bottom: 12),
          child: content,
        ),
      ),
    );
  }
}