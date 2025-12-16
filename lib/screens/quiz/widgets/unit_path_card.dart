import 'package:flutter/material.dart';

enum LessonStatus { locked, current, completed }

class UnitPathCard extends StatelessWidget {
  final int unitNumber;
  final String title;
  final int questionCount;
  final LessonStatus status;
  final bool isFirstInUnit; // Is this the Main Point?
  final bool isLastInUnit;  // To add a gap before next unit
  final bool isLastGlobal;  // To hide bottom line
  final VoidCallback onTap;

  const UnitPathCard({
    super.key,
    required this.unitNumber,
    required this.title,
    required this.questionCount,
    required this.status,
    required this.isFirstInUnit,
    required this.isLastInUnit,
    required this.isLastGlobal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- 1. THE TIMELINE LINE ---
          SizedBox(
            width: 60,
            child: Column(
              children: [
                // Top Line (Hide if it's the very first item, OR if it's a new unit header)
                Expanded(
                  child: Container(
                    width: 4, // Thicker line like Busuu
                    color: isFirstInUnit 
                        ? Colors.transparent 
                        : _getLineColor(context, isTop: true), 
                  ),
                ),
                // The Node Indicator
                _buildNodeIndicator(context),
                // Bottom Line
                Expanded(
                  child: Container(
                    width: 4,
                    color: isLastGlobal ? Colors.transparent : _getLineColor(context, isTop: false),
                  ),
                ),
              ],
            ),
          ),

          // --- 2. THE CONTENT CARD ---
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, isFirstInUnit ? 0 : 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // If this is the "Main Point" (First in Unit), show a Section Header
                  if (isFirstInUnit) ...[
                    const SizedBox(height: 20),
                    Text(
                      "UNIT $unitNumber",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[500],
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],

                  // The Actual Lesson Card
                  InkWell(
                    onTap: status == LessonStatus.locked ? null : onTap,
                    borderRadius: BorderRadius.circular(16),
                    child: Opacity(
                      opacity: status == LessonStatus.locked ? 0.6 : 1.0,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _getCardColor(isDark),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: status == LessonStatus.current 
                                ? const Color(0xFF6C63FF) 
                                : (isDark ? Colors.white10 : Colors.grey.shade200),
                            width: status == LessonStatus.current ? 2 : 1,
                          ),
                          boxShadow: [
                            if (status == LessonStatus.current)
                              BoxShadow(
                                color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: isFirstInUnit ? 18 : 16, // Main point is bigger
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(Icons.quiz_outlined, size: 14, color: Colors.grey[500]),
                                      const SizedBox(width: 4),
                                      Text(
                                        "$questionCount Questions",
                                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                      ),
                                      if (status == LessonStatus.current) ...[
                                        const SizedBox(width: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF6C63FF),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text("START HERE", style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                                        )
                                      ]
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Trailing Icon
                            Icon(
                              _getStatusIcon(),
                              color: _getStatusColor(),
                              size: 28,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Add extra spacing if it's the last lesson in the unit
                  if (isLastInUnit && !isLastGlobal)
                    const SizedBox(height: 24), 
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPERS ---

  Widget _buildNodeIndicator(BuildContext context) {
    // If it's the main point, use a large icon. If sub-lesson, small dot.
    double size = isFirstInUnit ? 40 : 24;
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _getStatusColor(),
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).scaffoldBackgroundColor,
          width: 3,
        ),
        boxShadow: [
          if (status == LessonStatus.current)
            BoxShadow(color: _getStatusColor().withValues(alpha: 0.5), blurRadius: 10)
        ],
      ),
      child: isFirstInUnit 
        ? Icon(_getStatusIcon(), size: 20, color: Colors.white) // Icon for main
        : null, // Just a dot for sub-lessons
    );
  }

  Color _getLineColor(BuildContext context, {required bool isTop}) {
    // Logic: The line is colored if the path is completed "through" this node
    if (status == LessonStatus.completed) return const Color(0xFF4CAF50); // Green
    if (status == LessonStatus.current && isTop) return const Color(0xFF4CAF50); // Line coming into current is green
    return Colors.grey.withValues(alpha: 0.3);
  }

  Color _getCardColor(bool isDark) {
    if (status == LessonStatus.locked) return isDark ? Colors.white10 : Colors.grey.shade100;
    return isDark ? const Color(0xFF2C2C2C) : Colors.white;
  }

  Color _getStatusColor() {
    switch (status) {
      case LessonStatus.completed: return const Color(0xFF4CAF50); // Green
      case LessonStatus.current: return const Color(0xFF6C63FF);   // Purple/Main
      case LessonStatus.locked: return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (status) {
      case LessonStatus.completed: return Icons.check;
      case LessonStatus.current: return Icons.play_arrow_rounded;
      case LessonStatus.locked: return Icons.lock_outline;
    }
  }
}