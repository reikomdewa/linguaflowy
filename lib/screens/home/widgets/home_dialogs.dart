import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/services/lesson_service.dart';

class HomeDialogs {
  static void showStatsDialog(
    BuildContext context,
    int knownWords,
    String languageCode,
    Map<String, String> languageNames,
  ) {
    String currentLevel = "Beginner";
    String nextLevel = "A1";
    int nextGoal = 500;
    double progress = 0.0;

    if (knownWords < 500) {
      currentLevel = "Newcomer";
      nextLevel = "A1";
      nextGoal = 500;
      progress = knownWords / 500;
    } else if (knownWords < 1000) {
      currentLevel = "A1 (Beginner)";
      nextLevel = "A2";
      nextGoal = 1000;
      progress = (knownWords - 500) / 500;
    } else if (knownWords < 2000) {
      currentLevel = "A2 (Elementary)";
      nextLevel = "B1";
      nextGoal = 2000;
      progress = (knownWords - 1000) / 1000;
    } else if (knownWords < 4000) {
      currentLevel = "B1 (Intermediate)";
      nextLevel = "B2";
      nextGoal = 4000;
      progress = (knownWords - 2000) / 2000;
    } else if (knownWords < 8000) {
      currentLevel = "B2 (Upper Int.)";
      nextLevel = "C1";
      nextGoal = 8000;
      progress = (knownWords - 4000) / 4000;
    } else {
      currentLevel = "C1 (Advanced)";
      nextLevel = "C2";
      nextGoal = 16000;
      progress = (knownWords - 8000) / 8000;
    }

    final langName = languageNames[languageCode] ?? 'Target Language';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.of(context).viewPadding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.auto_graph,
                      color: Colors.amber[800], size: 28),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("$langName Progress",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor)),
                    const Text("You probably know more words.",
                        style: TextStyle(fontSize: 14, color: Colors.grey)),
                  ],
                ),
              ],
            ),
            const Divider(height: 32),
            Center(
              child: Column(
                children: [
                  const Text("Current Level",
                      style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text(currentLevel,
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.blue)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Next Goal: $nextLevel",
                    style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                Text("${nextGoal - knownWords} words to go",
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation(Colors.blue),
              ),
            ),
            Text("$knownWords words known",
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.white : Colors.black,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Keep Learning"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void showLessonOptions(
      BuildContext context, LessonModel lesson, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (builderContext) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          top: 20,
          left: 0,
          right: 0,
          bottom: MediaQuery.of(builderContext).viewPadding.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: lesson.isFavorite
                      ? Colors.amber.withOpacity(0.1)
                      : (isDark ? Colors.white10 : Colors.grey[100]),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  lesson.isFavorite ? Icons.star : Icons.star_border,
                  color: lesson.isFavorite ? Colors.amber : Colors.grey,
                ),
              ),
              title: Text(
                lesson.isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              subtitle: Text(
                lesson.isFavorite ? 'Removed from library.' : 'Saved to library.',
                style: const TextStyle(color: Colors.grey),
              ),
              onTap: () {
                final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
                final updatedLesson = lesson.copyWith(
                  isFavorite: !lesson.isFavorite,
                  userId: user.id,
                );
                context.read<LessonBloc>().add(LessonUpdateRequested(updatedLesson));
                Navigator.pop(builderContext);
              },
            ),
            Divider(color: Colors.grey[800]),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline, color: Colors.red),
              ),
              title: const Text('Delete Lesson', style: TextStyle(color: Colors.red)),
              onTap: () {
                context.read<LessonBloc>().add(LessonDeleteRequested(lesson.id));
                Navigator.pop(builderContext);
              },
            ),
          ],
        ),
      ),
    );
  }

  static void showCreateLessonDialog(
    BuildContext context,
    String userId,
    String currentLanguage,
    Map<String, String> languageNames, {
    required bool isFavoriteByDefault,
  }) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    final lessonBloc = context.read<LessonBloc>();
    final lessonService = context.read<LessonService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final fullLangName = languageNames[currentLanguage] ?? currentLanguage.toUpperCase();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(
          'Create New Lesson for $fullLangName',
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: contentController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: const InputDecoration(
                  labelText: 'Content',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(color: Colors.grey),
                ),
                maxLines: 6,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty && contentController.text.isNotEmpty) {
                final sentences = lessonService.splitIntoSentences(contentController.text);
                final lesson = LessonModel(
                  id: '',
                  userId: userId,
                  title: titleController.text,
                  language: currentLanguage,
                  content: contentController.text,
                  sentences: sentences,
                  createdAt: DateTime.now(),
                  progress: 0,
                  isFavorite: isFavoriteByDefault,
                  type: 'text',
                );
                lessonBloc.add(LessonCreateRequested(lesson));
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}