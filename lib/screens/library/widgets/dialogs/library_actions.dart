import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/services/lesson_service.dart';

// --- OPTIONS BOTTOM SHEET ---
void showLessonOptions(BuildContext context, LessonModel lesson, bool isDark) {
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
            onTap: () {
              final user =
                  (context.read<AuthBloc>().state as AuthAuthenticated).user;

              final updatedLesson = lesson.copyWith(
                isFavorite: !lesson.isFavorite,
                userId: user.id,
              );

              context.read<LessonBloc>().add(
                    LessonUpdateRequested(updatedLesson),
                  );

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

// --- IMPORT DIALOG ---
void showCreateLessonDialog(
  BuildContext context,
  String userId,
  String currentLanguage, {
  required bool isFavoriteByDefault,
}) {
  final titleController = TextEditingController();
  final contentController = TextEditingController();

  final lessonBloc = context.read<LessonBloc>();
  final lessonService = context.read<LessonService>();
  final scaffoldMessenger = ScaffoldMessenger.of(context);
  final isDark = Theme.of(context).brightness == Brightness.dark;

  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      title: Text(
        'Import Text',
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
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: contentController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: const InputDecoration(
                labelText: 'Content',
                border: OutlineInputBorder(),
                hintText: 'Paste text here...',
              ),
              maxLines: 8,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () {
            if (titleController.text.isNotEmpty &&
                contentController.text.isNotEmpty) {
              final sentences = lessonService.splitIntoSentences(
                contentController.text,
              );

              final lesson = LessonModel(
                id: '', // Repo will handle ID or assign temp
                userId: userId,
                title: titleController.text,
                language: currentLanguage,
                content: contentController.text,
                sentences: sentences,
                createdAt: DateTime.now(),
                progress: 0,
                isFavorite: isFavoriteByDefault,
                isLocal: true,
                type: 'text',
              );

              lessonBloc.add(LessonCreateRequested(lesson));
              Navigator.pop(dialogContext);

              scaffoldMessenger.showSnackBar(
                const SnackBar(content: Text('Lesson imported successfully!')),
              );
            }
          },
          child: const Text('Import'),
        ),
      ],
    ),
  );
}