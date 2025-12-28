import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/screens/reader/reader_screen.dart';
import 'package:linguaflow/screens/reader/reader_screen_web.dart';
import 'package:linguaflow/utils/utils.dart';

class LibraryTextCard extends StatelessWidget {
  final LessonModel lesson;
  final bool isDark;
  final double? width;

  const LibraryTextCard({
    super.key,
    required this.lesson,
    required this.isDark,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    // Logic to detect AI content:
    // 1. Explicit type 'ai_story'
    // 2. OR it's a Text lesson with a title containing parenthesis like "(A1)", indicating a rewrite
    final bool isAI = lesson.type == 'ai_story' || 
                      (lesson.type == 'text' && lesson.title.contains('(') && lesson.title.contains(')'));

    // Styling constants for AI vs Normal
    final Color iconBgColor = isAI 
        ? Colors.purpleAccent.withValues(alpha: 0.15) 
        : Colors.amber.withValues(alpha: 0.1);
    final Color iconColor = isAI 
        ? Colors.purpleAccent 
        : Colors.amber[800]!;
    final IconData iconData = isAI 
        ? Icons.auto_awesome 
        : Icons.article;
    final String labelText = isAI 
        ? "AI Story" 
        : "Imported Text";

    // --- HORIZONTAL CARD STYLE ---
    if (width != null) {
      return GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => kIsWeb
                ? ReaderScreenWeb(lesson: lesson)
                : ReaderScreen(lesson: lesson),
          ),
        ),
        child: Container(
          width: width,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.grey.shade200,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Icon + Badge + Menu
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: iconBgColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(iconData, color: iconColor, size: 20),
                      ),
                      // AI BADGE
                      if (isAI) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.deepPurple, Colors.purpleAccent],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            "AI",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  GestureDetector(
                    onTap: () => showLessonOptions(context, lesson, isDark),
                    child: const Icon(Icons.more_vert,
                        color: Colors.grey, size: 20),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                lesson.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                labelText,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    // --- VERTICAL LIST TILE STYLE ---
    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.transparent : Colors.grey.shade200,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: iconBgColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(iconData, color: iconColor),
        ),
        title: Text(
          lesson.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : Colors.grey[800],
          ),
        ),
        subtitle: Text(
          lesson.content.replaceAll('\n', ' '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.grey),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert, color: Colors.grey),
          onPressed: () => showLessonOptions(context, lesson, isDark),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => kIsWeb
                  ? ReaderScreenWeb(lesson: lesson)
                  : ReaderScreen(lesson: lesson),
            ),
          );
        },
      ),
    );
  }
}