import 'package:flutter/material.dart';

class QuizWordChip extends StatelessWidget {
  final String word;
  final VoidCallback onTap;
  final bool isSelectedArea;
  final bool shouldSpeak;
  final Function(String)? onSpeak; // Optional callback if we need to speak

  const QuizWordChip({
    super.key,
    required this.word,
    required this.onTap,
    required this.isSelectedArea,
    this.shouldSpeak = false,
    this.onSpeak,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        if (shouldSpeak && onSpeak != null) {
          onSpeak!(word);
        }
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelectedArea
              ? (isDark
                    ? Colors.blueAccent.withValues(alpha: 0.2)
                    : Colors.blue[50])
              : (isDark ? Colors.grey[800] : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelectedArea
                ? Colors.transparent
                : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
          ),
          boxShadow: isSelectedArea
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
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
}
