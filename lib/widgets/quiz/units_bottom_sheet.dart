import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/screens/quiz/quiz_screen.dart';
import 'package:linguaflow/services/quiz_limit_service.dart';
import 'package:linguaflow/widgets/premium_lock_dialog.dart';
import 'package:linguaflow/widgets/quiz/unit_path_card.dart';

class UnitsBottomSheet extends StatefulWidget {
  final dynamic user; // Pass your User model here

  const UnitsBottomSheet({super.key, required this.user});

  @override
  State<UnitsBottomSheet> createState() => _UnitsBottomSheetState();
}

class _UnitsBottomSheetState extends State<UnitsBottomSheet> {
  final QuizLimitService _limitService = QuizLimitService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String targetLang = widget.user.currentLanguage;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F7FA), // Slight off-white for path bg
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Handle Bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text(
                    "Your Learning Path",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  if (_isLoading)
                    const SizedBox(
                      width: 20, 
                      height: 20, 
                      child: CircularProgressIndicator(strokeWidth: 2)
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Content
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('quiz_levels')
                    .where('language', isEqualTo: targetLang)
                    .orderBy('unitIndex')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text("Unable to load the path."));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.school_outlined, size: 60, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          const Text("No units available yet."),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: controller,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final String title = data['topic'] ?? 'Unit ${index + 1}';
                      final int qCount = data['questionCount'] ?? 0;
                      final List<dynamic> questions = data['questions'] ?? [];

                      return UnitPathCard(
                        index: index,
                        title: title,
                        questionCount: qCount,
                        isLast: index == docs.length - 1,
                        onTap: () => _handleUnitSelection(questions),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleUnitSelection(List<dynamic> questions) async {
    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This unit is currently being built.")),
      );
      return;
    }

    if (_isLoading) return;

    // 1. Premium Check
    if (widget.user.isPremium) {
      _navigateToQuiz(questions);
      return;
    }

    // 2. Free Tier Logic
    setState(() => _isLoading = true);

    try {
      final canAccess = await _limitService.checkAndIncrementQuizLimit(widget.user.id);
      
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (canAccess) {
        _navigateToQuiz(questions);
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

  void _navigateToQuiz(List<dynamic> questions) {
    // Close the bottom sheet first
    Navigator.pop(context);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizScreen(initialQuestions: questions),
      ),
    );
  }

  void _showLimitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Daily Limit Reached"),
        content: Text(
          "Free accounts can take ${_limitService.limit} guided practices every ${_limitService.resetMinutes} minutes.\n\n"
          "Upgrade to Premium for unlimited access.",
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
              showDialog(
                context: context,
                builder: (context) => const PremiumLockDialog(),
              ).then((unlocked) {
                if (unlocked == true) {
                  // Refresh auth state if they bought premium
                  context.read<AuthBloc>().add(AuthCheckRequested());
                }
              });
            },
            child: const Text("Upgrade"),
          ),
        ],
      ),
    );
  }
}