import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/screens/reader/reader_screen.dart';
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

              // Imported lessons are LOCAL by default usually, but passed to BLoC
              // which handles the repository logic.
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
                isLocal: true, // Explicitly marking as local import
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

// --- VIDEO CARD WIDGET ---
class LibraryVideoCard extends StatelessWidget {
  final LessonModel lesson;
  final bool isDark;
  final double? width; // Added for horizontal scrolling

  const LibraryVideoCard({
    super.key, 
    required this.lesson, 
    required this.isDark,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ReaderScreen(lesson: lesson)),
        );
      },
      child: Container(
        width: width, // Apply width if provided
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Container(
                    height: 140, // Slightly shorter to fit layouts better
                    width: double.infinity,
                    color: isDark ? Colors.white10 : Colors.grey[200],
                    child: lesson.imageUrl != null
                        ? Image.network(lesson.imageUrl!, fit: BoxFit.cover)
                        : Icon(
                            Icons.video_library,
                            size: 50,
                            color: Colors.grey[400],
                          ),
                  ),
                ),
                Positioned.fill(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow, color: Colors.white, size: 24),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          lesson.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => showLessonOptions(context, lesson, isDark),
                        child: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- TEXT CARD WIDGET ---
class LibraryTextCard extends StatelessWidget {
  final LessonModel lesson;
  final bool isDark;
  final double? width; // Added for horizontal usage

  const LibraryTextCard({
    super.key, 
    required this.lesson, 
    required this.isDark,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    // If width is provided (Horizontal Mode), we need a container logic
    // If width is null (Vertical Mode), we can use the ListTile logic
    
    if (width != null) {
      // HORIZONTAL CARD STYLE
      return GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ReaderScreen(lesson: lesson)),
        ),
        child: Container(
          width: width,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.article, color: Colors.amber[800], size: 20),
                  ),
                   GestureDetector(
                        onTap: () => showLessonOptions(context, lesson, isDark),
                        child: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
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
                "Imported Text",
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    // VERTICAL LIST TILE STYLE (Original)
    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? Colors.transparent : Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.article, color: Colors.amber[800]),
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
              builder: (context) => ReaderScreen(lesson: lesson),
            ),
          );
        },
      ),
    );
  }
}