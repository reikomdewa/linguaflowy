import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/screens/quiz/quiz_screen.dart';
import 'package:linguaflow/screens/learn/learn_screen.dart';
import 'package:linguaflow/screens/quiz/widgets/unit_path_card.dart';
import 'package:linguaflow/services/quiz_limit_service.dart';
import 'package:linguaflow/utils/logger.dart';
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
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 10),
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
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        tabs: const [
                          Tab(text: "Practice Path"),
                          Tab(text: "Content Library"),
                        ],
                      ),
                    ),
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.only(left: 10),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildPracticePath(scrollController),
                    LearnScreen(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPracticePath(ScrollController controller) {
    final String targetLang = widget.user.currentLanguage;
    final List<dynamic> completedIds = widget.user.completedLevels ?? [];

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('quiz_levels')
          .where('language', isEqualTo: targetLang)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          printLog("SNAPSHOT ERROR: ${snapshot.error}");
          return const Center(child: Text("Load error. Check Console."));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        List<QueryDocumentSnapshot> docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map_outlined, size: 60, color: Colors.grey[400]),
                SizedBox(height: 16),
                Text("No practice units available yet."),
              ],
            ),
          );
        }

        // --- SORT WITH DEBUGGING ---
        docs = _sortLessons(docs);

        // --- PROGRESS LOGIC ---
        int firstIncompleteIndex = -1;
        for (int i = 0; i < docs.length; i++) {
          if (!completedIds.contains(docs[i].id)) {
            firstIncompleteIndex = i;
            break;
          }
        }
        if (firstIncompleteIndex == -1 && completedIds.isNotEmpty) {
          firstIncompleteIndex = docs.length;
        }
        if (completedIds.isEmpty) firstIncompleteIndex = 0;

        return ListView.builder(
          controller: controller,
          padding: const EdgeInsets.only(bottom: 30),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final String title = data['topic'] ?? 'Lesson';
            final int qCount = data['questionCount'] ?? 0;
            // Parse Unit Index for Display (Visual only, not for sorting)
            final int unitIndex =
                int.tryParse(data['unitIndex']?.toString() ?? '1') ?? 1;
            final List<dynamic> questions = data['questions'] ?? [];

            LessonStatus status;
            if (index < firstIncompleteIndex) {
              status = LessonStatus.completed;
            } else if (index == firstIncompleteIndex)
              status = LessonStatus.current;
            else
              status = LessonStatus.locked;

            // UI Grouping
            bool isFirstInUnit = false;
            if (index == 0) {
              isFirstInUnit = true;
            } else {
              final prevData = docs[index - 1].data() as Map<String, dynamic>;
              final int prevUnit =
                  int.tryParse(prevData['unitIndex']?.toString() ?? '0') ?? 0;
              if (unitIndex != prevUnit) isFirstInUnit = true;
            }

            bool isLastInUnit = false;
            if (index == docs.length - 1) {
              isLastInUnit = true;
            } else {
              final nextData = docs[index + 1].data() as Map<String, dynamic>;
              final int nextUnit =
                  int.tryParse(nextData['unitIndex']?.toString() ?? '0') ?? 0;
              if (unitIndex != nextUnit) isLastInUnit = true;
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

  /// Sorts lessons by unitIndex (ascending), then by createdAt (ascending within each unit)
  /// This ensures Unit 1 comes before Unit 2, and within each unit, oldest lessons appear first
  List<QueryDocumentSnapshot> _sortLessons(
    List<QueryDocumentSnapshot> unsortedDocs,
  ) {
    printLog("--- START SORTING (${unsortedDocs.length} items) ---");

    List<QueryDocumentSnapshot> sorted = List.from(unsortedDocs);

    sorted.sort((a, b) {
      final dataA = a.data() as Map<String, dynamic>;
      final dataB = b.data() as Map<String, dynamic>;

      // 1. PRIMARY SORT: Unit Index (ascending)
      int unitA = int.tryParse(dataA['unitIndex']?.toString() ?? '999') ?? 999;
      int unitB = int.tryParse(dataB['unitIndex']?.toString() ?? '999') ?? 999;

      int unitCompare = unitA.compareTo(unitB);

      // If units are different, sort by unit
      if (unitCompare != 0) {
        printLog(
          "Different units: ${dataA['topic']} (Unit $unitA) vs ${dataB['topic']} (Unit $unitB) -> $unitCompare",
        );
        return unitCompare;
      }

      // 2. SECONDARY SORT: Created At (ascending within same unit)
      final rawDateA = dataA['createdAt'] ?? dataA['updatedAt'];
      final rawDateB = dataB['createdAt'] ?? dataB['updatedAt'];

      DateTime dateA = _parseAnyDate(rawDateA) ?? DateTime(1970);
      DateTime dateB = _parseAnyDate(rawDateB) ?? DateTime(1970);

      int dateCompare = dateA.compareTo(dateB);

      printLog("Same unit ($unitA): ${dataA['topic']} vs ${dataB['topic']}");
      printLog("   DateA: $dateA | DateB: $dateB -> $dateCompare");

      // If dates are the same, use document ID as final tiebreaker
      if (dateCompare == 0) {
        return a.id.compareTo(b.id);
      }

      return dateCompare;
    });

    printLog("--- END SORTING ---");
    printLog("Final order:");
    for (int i = 0; i < sorted.length; i++) {
      final data = sorted[i].data() as Map<String, dynamic>;
      printLog("  $i: ${data['topic']} (Unit ${data['unitIndex']})");
    }

    return sorted;
  }

  DateTime? _parseAnyDate(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is String) {
      // Try ISO format (2025-12-10T...)
      try {
        return DateTime.parse(val);
      } catch (_) {}
      // Try Verbose format
      return _parseVerboseString(val);
    }
    return null;
  }

  DateTime? _parseVerboseString(String input) {
    try {
      final parts = input.split(' ');
      if (parts.length < 3) return null;
      String monthStr = parts[0];
      String dayStr = parts[1].replaceAll(',', '');
      String yearStr = parts[2];
      return DateTime(
        int.parse(yearStr),
        _getMonthIndex(monthStr),
        int.parse(dayStr),
      );
    } catch (_) {
      return null;
    }
  }

  int _getMonthIndex(String m) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    int index = months.indexOf(m);
    return index != -1 ? index + 1 : 1;
  }

  Future<void> _handleUnitSelection(
    List<dynamic> questions,
    String levelId,
  ) async {
    if (questions.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("This unit is empty.")));
      return;
    }
    if (_isLoading) return;
    if (widget.user.isPremium) {
      _navigateToQuiz(questions, levelId);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final canAccess = await _limitService.checkAndIncrementQuizLimit(
        widget.user.id,
      );
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Connection error.")));
    }
  }

  void _navigateToQuiz(List<dynamic> questions, String levelId) {
    final authBloc = context.read<AuthBloc>();
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator
        .push(
          MaterialPageRoute(
            builder: (_) =>
                QuizScreen(initialQuestions: questions, levelId: levelId),
          ),
        )
        .then((_) => authBloc.add(AuthCheckRequested()));
  }

  void _showLimitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Daily Limit Reached"),
        content: Text(
          "Free accounts can take ${_limitService.limit} guided practices every ${_limitService.resetMinutes} minutes.\n\nUpgrade to Premium.",
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
