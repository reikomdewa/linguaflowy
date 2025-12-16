import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/quiz/quiz_bloc.dart';
import 'package:linguaflow/widgets/premium_lock_dialog.dart';

class QuizDialogs {
  static void showCompletion(BuildContext context, bool isDark) {
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
            Text("Practice Complete",
                style: TextStyle(color: isDark ? Colors.white : Colors.black)),
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
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close screen
            },
            child: const Text("Finish",
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static void showGameOver(BuildContext context, bool isDark) {
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
            Text("Out of Hearts!",
                style: TextStyle(color: isDark ? Colors.white : Colors.black)),
          ],
        ),
        content: const Text(
          "You made too many mistakes. Upgrade to Premium for infinite hearts!",
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
            child: const Text("Quit",
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.redAccent)),
          ),
          ElevatedButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const PremiumLockDialog(),
              ).then((unlocked) {
                if (unlocked == true && context.mounted) {
                  context.read<AuthBloc>().add(AuthCheckRequested());
                  context.read<QuizBloc>().add(QuizReviveRequested());
                
                  Navigator.pop(context);
                }
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
            ),
            child: const Text("Get Unlimited Hearts"),
          ),
        ],
      ),
    );
  }
}

// Separate Widget for the Hint because it has state/futures
class QuizHintDialog extends StatelessWidget {
  final String originalWord;
  final Future<String> translationFuture;
  final VoidCallback onSpeak;

  const QuizHintDialog({
    super.key,
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