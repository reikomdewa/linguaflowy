import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/screens/quiz/quiz_screen.dart';
import 'package:linguaflow/screens/learn/learn_screen.dart';
import 'package:linguaflow/screens/quiz/widgets/unit_path_card.dart'; 
import 'package:linguaflow/services/quiz_limit_service.dart';
import 'package:linguaflow/widgets/premium_lock_dialog.dart';

class UnitsBottomSheet extends StatefulWidget {
  final dynamic user; 

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

    return DefaultTabController(
      length: 2,
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F7FA),
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
              const SizedBox(height: 10),

              // --- TABS HEADER ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TabBar(
                        dividerColor: Colors.transparent,
                        labelColor: const Color(0xFF6C63FF),
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: const Color(0xFF6C63FF),
                        indicatorSize: TabBarIndicatorSize.label,
                        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        tabs: const [
                          Tab(text: "Practice Path"),
                          Tab(text: "Content Library"),
                        ],
                      ),
                    ),
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.only(left: 10),
                        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // --- TAB VIEW ---
              Expanded(
                child: TabBarView(
                  children: [
                    // Tab 1: The Timeline
                    _buildPracticePath(scrollController),
                    
                    // Tab 2: The Learn Screen (Content)
                    const ClipRRect(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      child: LearnScreen(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- LOGIC FOR THE BUSUU-STYLE PATH ---
  Widget _buildPracticePath(ScrollController controller) {
    final String targetLang = widget.user.currentLanguage;
    final List<dynamic> completedIds = widget.user.completedLevels ?? [];

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('quiz_levels')
          .where('language', isEqualTo: targetLang)
          .orderBy('unitIndex')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text("Unable to load path."));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map_outlined, size: 60, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text("No practice units available yet."),
              ],
            ),
          );
        }

        // --- 1. DETERMINE PROGRESS STATE ---
        int firstIncompleteIndex = -1;

        for (int i = 0; i < docs.length; i++) {
          final docId = docs[i].id;
          if (!completedIds.contains(docId)) {
            firstIncompleteIndex = i;
            break;
          }
        }
        
        if (firstIncompleteIndex == -1 && completedIds.isNotEmpty) {
          firstIncompleteIndex = docs.length;
        }
        if (completedIds.isEmpty) firstIncompleteIndex = 0;

        // --- 2. BUILD THE LIST ---
        return ListView.builder(
          controller: controller,
          padding: const EdgeInsets.only(bottom: 30),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            
            final String title = data['topic'] ?? 'Lesson';
            final int qCount = data['questionCount'] ?? 0;
            final int unitIndex = data['unitIndex'] ?? 1;
            final List<dynamic> questions = data['questions'] ?? [];

            // A. Determine Status
            LessonStatus status;
            if (index < firstIncompleteIndex) {
              status = LessonStatus.completed;
            } else if (index == firstIncompleteIndex) {
              status = LessonStatus.current;
            } else {
              status = LessonStatus.locked;
            }

            // B. Determine Grouping
            bool isFirstInUnit = false;
            if (index == 0) {
              isFirstInUnit = true;
            } else {
              final prevData = docs[index - 1].data() as Map<String, dynamic>;
              if (unitIndex != (prevData['unitIndex'] ?? 0)) {
                isFirstInUnit = true;
              }
            }

            bool isLastInUnit = false;
            if (index == docs.length - 1) {
              isLastInUnit = true;
            } else {
              final nextData = docs[index + 1].data() as Map<String, dynamic>;
              if (unitIndex != (nextData['unitIndex'] ?? 0)) {
                isLastInUnit = true;
              }
            }

            return UnitPathCard(
              unitNumber: unitIndex,
              title: title,
              questionCount: qCount,
              status: status,
              isFirstInUnit: isFirstInUnit,
              isLastInUnit: isLastInUnit,
              isLastGlobal: index == docs.length - 1,
              onTap: () {
                if (status != LessonStatus.locked) {
                  _handleUnitSelection(questions, doc.id);
                }
              },
            );
          },
        );
      },
    );
  }

  // --- SELECTION & LIMIT LOGIC ---

  Future<void> _handleUnitSelection(List<dynamic> questions, String levelId) async {
    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("This unit is empty.")));
      return;
    }

    if (_isLoading) return;

    if (widget.user.isPremium) {
      _navigateToQuiz(questions, levelId);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final canAccess = await _limitService.checkAndIncrementQuizLimit(widget.user.id);
      
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (canAccess) {
        _navigateToQuiz(questions, levelId);
      } else {
        _showLimitDialog();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connection error.")),
      );
    }
  }

  // --- FIX START: Capture Context safely ---
  void _navigateToQuiz(List<dynamic> questions, String levelId) {
    // 1. Capture the AuthBloc and Navigator BEFORE the widget is disposed/popped
    final authBloc = context.read<AuthBloc>();
    final navigator = Navigator.of(context);

    // 2. Close the Bottom Sheet
    navigator.pop(); 
    
    // 3. Navigate to Quiz
    navigator.push(
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          initialQuestions: questions,
          levelId: levelId, 
        ),
      ),
    ).then((_) {
      // 4. Use the captured Bloc instance. 
      // DO NOT USE 'context' here because the Bottom Sheet is gone.
      authBloc.add(AuthCheckRequested());
    });
  }
  // --- FIX END ---

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
              Navigator.pop(context); 
              showDialog(
                context: context,
                builder: (context) => const PremiumLockDialog(),
              ).then((unlocked) {
                if (unlocked == true) {
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