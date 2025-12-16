import 'package:flutter/material.dart';
import 'package:linguaflow/models/lesson_model.dart';

// --- SCREEN IMPORTS ---
import 'package:linguaflow/screens/learn/active_lesson_screen.dart';
import 'package:linguaflow/screens/reader/reader_screen.dart';
import 'package:linguaflow/screens/learn/ai_conversation_screen.dart'; 

class LessonUnitCard extends StatelessWidget {
  final int lessonIndex;
  final LessonModel lesson;
  final List<Map<String, dynamic>> lessonSteps;
  final int expandedLessonIndex;
  final int expandedStepIndex;
  final int demoCompletedSteps;
  final Function(int lessonIndex, int stepIndex) onExpand;

  const LessonUnitCard({
    super.key,
    required this.lessonIndex,
    required this.lesson,
    required this.lessonSteps,
    required this.expandedLessonIndex,
    required this.expandedStepIndex,
    required this.demoCompletedSteps,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Header (Unit X - Title)
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      "${lessonIndex + 1}",
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Unit ${lessonIndex + 1} • ${lesson.type}",
                    style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                lesson.title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        // 2. The Timeline Steps for this Lesson
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: lessonSteps.length,
            itemBuilder: (context, stepIndex) {
              return _buildTimelineItem(
                context,
                stepIndex,
                isDark,
                textColor,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineItem(
    BuildContext context,
    int stepIndex,
    bool isDark,
    Color? textColor,
  ) {
    final stepData = lessonSteps[stepIndex];
    final bool isLastStep = stepIndex == lessonSteps.length - 1;

    // --- STATE LOGIC ---
    // Is this specific card expanded?
    bool isExpanded =
        (lessonIndex == expandedLessonIndex && stepIndex == expandedStepIndex);

    // Is Completed? (Simulated logic passed from parent)
    bool isCompleted = (lessonIndex == 0 && stepIndex < demoCompletedSteps);

    // --- COLOR LOGIC ---
    Color baseColor = stepData['color'];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT SIDE: Line + Icon
          SizedBox(
            width: 50,
            child: Column(
              children: [
                // Clickable Icon
                GestureDetector(
                  onTap: () => onExpand(lessonIndex, stepIndex),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: baseColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: baseColor.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      stepData['icon'],
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
                // Vertical Line
                if (!isLastStep)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: baseColor.withValues(alpha: 0.3),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // RIGHT SIDE: Card or Text
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 32.0),
              child: isExpanded
                  ? _buildActiveCard(context, stepData, isDark, stepIndex)
                  : GestureDetector(
                      onTap: () => onExpand(lessonIndex, stepIndex),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 12),
                          Text(
                            stepData['title'],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 4),

                          // SUBTITLE: Time + Checkmark (if completed)
                          Row(
                            children: [
                              Text(
                                stepData['time'],
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                              if (isCompleted) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    size: 10,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveCard(
    BuildContext context,
    Map<String, dynamic> stepData,
    bool isDark,
    int stepIndex,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E272E) : const Color(0xFF263238),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          const BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 5),
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
                  stepData['title'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  stepData['time'],
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              // --- NAVIGATION ROUTING ---
              
              // 1. If Video Context -> Reader Screen
              if (stepData['title'] == 'Video Context') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReaderScreen(lesson: lesson),
                  ),
                );
              } 
              // 2. If AI Conversation -> AI Conversation Screen
              else if (stepData['title'] == 'AI Conversation') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AiConversationScreen(lesson: lesson),
                  ),
                );
              } 
              // 3. Default -> Active Lesson Screen (Vocab, Grammar, etc.)
              else {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ActiveLessonScreen(
                      lesson: lesson,
                      initialStep: stepIndex,
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
            ),
            child: const Text("Start", style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}