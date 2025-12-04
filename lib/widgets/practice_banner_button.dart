import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/screens/quiz/quiz_screen.dart';
import 'package:linguaflow/widgets/premium_lock_dialog.dart'; // Import dialog

class PracticeBannerButton extends StatelessWidget {
  const PracticeBannerButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFF5A4FCF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C63FF).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              // 1. GET USER STATE
              final authState = context.read<AuthBloc>().state;
              
              if (authState is AuthAuthenticated) {
                if (authState.user.isPremium) {
                  // --- USER IS PREMIUM: GO TO QUIZ ---
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const QuizScreen()),
                  );
                } else {
                  // --- USER IS FREE: SHOW LOCK ---
                  showDialog(
                    context: context,
                    builder: (context) => const PremiumLockDialog(),
                  ).then((unlocked) {
                    // Ideally, trigger an Auth reload here if unlocked == true
                    if (unlocked == true) {
                      // Reload user to update UI immediately
                      context.read<AuthBloc>().add(AuthCheckRequested());
                    }
                  });
                }
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sports_esports, color: Colors.white, size: 28),
                SizedBox(width: 12),
                Text(
                  "Practice Words",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                // Add a Lock Icon if not premium
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    if (state is AuthAuthenticated && !state.user.isPremium) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Icon(Icons.lock, color: Colors.white70, size: 20),
                      );
                    }
                    return SizedBox();
                  },
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}