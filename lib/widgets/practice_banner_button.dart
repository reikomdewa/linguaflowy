



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
                        "Guided Practice",
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

  void _handleQuizTap() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      // Pass the user so we know their language and premium status
      _showUnitSelector(context, authState.user);
    }
  }
  // 1. THE UI: Shows the list of units
  void _showUnitSelector(BuildContext context, dynamic user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String targetLang = user.currentLanguage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.only(top: 20),
          child: Column(
            children: [
              // Handle Bar
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 15),
                decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)),
              ),
              Text(
                "Learning Path",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  // Query: Get levels for current language, sorted by Unit 1, 2, 3...
                  stream: FirebaseFirestore.instance
                      .collection('quiz_levels')
                      .where('language', isEqualTo: targetLang)
                      .orderBy('unitIndex') 
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return const Center(child: Text("Error loading path."));
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Center(child: Text("No units available for this language yet."));
                    }

                    return ListView.separated(
                      controller: controller,
                      padding: const EdgeInsets.all(20),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final String title = data['topic'] ?? 'Unit ${index + 1}';
                        final int qCount = data['questionCount'] ?? 0;
                        final int unitIndex = data['unitIndex'] ?? (index + 1);
                        final List<dynamic> questions = data['questions'] ?? [];

                        // Optional: Check if user completed this level
                        // You can store 'completed_levels' list in user profile later
                        // final bool isCompleted = user.completedLevels.contains(docs[index].id); 

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          tileColor: isDark ? Colors.white10 : Colors.grey[50],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                            side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade200)
                          ),
                          leading: CircleAvatar(
                            backgroundColor: Colors.blueAccent,
                            child: Text("$unitIndex", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                          title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                          subtitle: Text("$qCount Questions", style: const TextStyle(color: Colors.grey)),
                          trailing: const Icon(Icons.play_circle_fill, color: Colors.blue, size: 32),
                          onTap: () {
                             // Close sheet first
                             Navigator.pop(ctx);
                             // Trigger Logic
                             _startSelectedUnit(user, questions);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 2. THE LOGIC: Checks limits, then starts the specific unit
  Future<void> _startSelectedUnit(dynamic user, List<dynamic> questions) async {
    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("This unit has no questions.")));
      return;
    }

    if (_isLoading) return;

    // --- A. PREMIUM CHECK ---
    if (user.isPremium) {
      _navigateToQuizScreen(questions); // Create this helper
      return;
    }

    // --- B. FREE USER CHECK ---
    setState(() => _isLoading = true);

    try {
      // Re-using your existing logic
      final canAccess = await _checkAndIncrementQuizLimit(user.id);
      
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (canAccess) {
        _navigateToQuizScreen(questions);
      } else {
        _showLimitDialog();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connection error. Please try again.")),
      );
    }
  }

  // 3. NAVIGATION HELPER
  void _navigateToQuizScreen(List<dynamic> questions) {
    // Navigate to your existing Quiz Runner
    // Ensure your QuizRunner accepts a 'questions' list parameter
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          initialQuestions: questions, 
          // ... other params
        ),
      ),
    );
    
    print("NAVIGATING TO QUIZ with ${questions.length} questions");
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
