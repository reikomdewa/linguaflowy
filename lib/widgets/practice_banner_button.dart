// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:linguaflow/blocs/auth/auth_bloc.dart';
// import 'package:linguaflow/screens/quiz/quiz_screen.dart';
// import 'package:linguaflow/widgets/premium_lock_dialog.dart'; // Import dialog

// class PracticeBannerButton extends StatelessWidget {
//   const PracticeBannerButton({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//       child: Container(
//         height: 40,
//         decoration: BoxDecoration(
//           gradient: const LinearGradient(
//             colors: [Color(0xFF6C63FF), Color(0xFF5A4FCF)],
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//           ),
//           borderRadius: BorderRadius.circular(16),
//           boxShadow: [
//             BoxShadow(
//               color: const Color(0xFF6C63FF).withOpacity(0.3),
//               blurRadius: 8,
//               offset: const Offset(0, 4),
//             ),
//           ],
//         ),
//         child: Material(
//           color: Colors.transparent,
//           child: InkWell(
//             onTap: () {
//               // 1. GET USER STATE
//               final authState = context.read<AuthBloc>().state;

//               if (authState is AuthAuthenticated) {
//                 if (authState.user.isPremium) {
//                   // --- USER IS PREMIUM: GO TO QUIZ ---
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(builder: (context) => const QuizScreen()),
//                   );
//                 } else {
//                   // --- USER IS FREE: SHOW LOCK ---
//                   showDialog(
//                     context: context,
//                     builder: (context) => const PremiumLockDialog(),
//                   ).then((unlocked) {
//                     // Ideally, trigger an Auth reload here if unlocked == true
//                     if (unlocked == true) {
//                       // Reload user to update UI immediately
//                       context.read<AuthBloc>().add(AuthCheckRequested());
//                     }
//                   });
//                 }
//               }
//             },
//             borderRadius: BorderRadius.circular(16),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Icon(Icons.sports_esports, color: Colors.white, size: 20),
//                 SizedBox(width: 6),
//                 Text(
//                   "Practice Words",
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 16,
//                     fontWeight: FontWeight.bold,
//                     letterSpacing: 0.5,
//                   ),
//                 ),
//                 // Add a Lock Icon if not premium
//                 BlocBuilder<AuthBloc, AuthState>(
//                   builder: (context, state) {
//                     if (state is AuthAuthenticated && !state.user.isPremium) {
//                       return Padding(
//                         padding: const EdgeInsets.only(left: 8.0),
//                         child: Icon(
//                           Icons.lock,
//                           color: Colors.white70,
//                           size: 20,
//                         ),
//                       );
//                     }
//                     return SizedBox();
//                   },
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }



import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/screens/quiz/quiz_screen.dart';
import 'package:linguaflow/widgets/premium_lock_dialog.dart';

class PracticeBannerButton extends StatefulWidget {
  const PracticeBannerButton({super.key});

  @override
  State<PracticeBannerButton> createState() => _PracticeBannerButtonState();
}

class _PracticeBannerButtonState extends State<PracticeBannerButton> {
  // --- CONSTANTS ---
  static const int _kQuizLimit = 3; // Max quizzes allowed per window
  static const int _kResetMinutes = 10; // Reset window in minutes

  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        height: 40,
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
            onTap: _handleQuizTap,
            borderRadius: BorderRadius.circular(16),
            child: _isLoading
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.sports_esports,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 6),
                      const Text(
                        "Practice Words",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      // Optional: We removed the Lock icon because it is now
                      // technically "open" for everyone (until limited)
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleQuizTap() async {
    if (_isLoading) return;

    // 1. GET USER STATE
    final authState = context.read<AuthBloc>().state;

    if (authState is AuthAuthenticated) {
      final user = authState.user;

      if (user.isPremium) {
        // --- USER IS PREMIUM: GO TO QUIZ IMMEDIATELY ---
        _navigateToQuiz();
      } else {
        // --- USER IS FREE: CHECK FIRESTORE LIMITS ---
        setState(() => _isLoading = true);

        try {
          final canAccess = await _checkAndIncrementQuizLimit(user.id);
          
          if (!mounted) return;
          setState(() => _isLoading = false);

          if (canAccess) {
            _navigateToQuiz();
          } else {
            _showLimitDialog();
          }
        } catch (e) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          
          // Log error and maybe show snackbar
          print("Error checking quiz limit: $e");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Connection error. Please try again.")),
          );
        }
      }
    }
  }

  void _navigateToQuiz() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QuizScreen()),
    );
  }

  Future<bool> _checkAndIncrementQuizLimit(String userId) async {
    // Note: This uses a different document ('quizzes') than the dictionary limit
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('limits')
        .doc('quizzes');

    final snapshot = await docRef.get();
    final now = DateTime.now();

    // 1. If never used, create and allow
    if (!snapshot.exists) {
      await docRef.set({
        'count': 1,
        'lastReset': FieldValue.serverTimestamp(),
      });
      return true;
    }

    final data = snapshot.data()!;
    final Timestamp? lastResetTs = data['lastReset'] as Timestamp?;
    final DateTime lastReset = lastResetTs?.toDate() ?? now;
    final int count = data['count'] ?? 0;

    // 2. Check if time window (10 mins) has passed
    if (now.difference(lastReset).inMinutes >= _kResetMinutes) {
      // Reset counter
      await docRef.set({
        'count': 1,
        'lastReset': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } else {
      // 3. Still in window, check limit (3)
      if (count < _kQuizLimit) {
        await docRef.update({'count': FieldValue.increment(1)});
        return true;
      } else {
        return false; // Limit reached
      }
    }
  }

  void _showLimitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Practice Limit Reached"),
        content: const Text(
          "Great job practicing! \n\n"
          "Free accounts can take $_kQuizLimit quizzes every $_kResetMinutes minutes.\n\n"
          "Upgrade to Premium for unlimited practice sessions anytime.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Wait"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context); // Close warning
              // Open Premium Upsell
              showDialog(
                context: context,
                builder: (context) => const PremiumLockDialog(),
              ).then((unlocked) {
                if (unlocked == true) {
                  context.read<AuthBloc>().add(AuthCheckRequested());
                }
              });
            },
            child: const Text("Upgrade Now"),
          ),
        ],
      ),
    );
  }
}
