import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/screens/home/widgets/lesson_import_dialog.dart';
import 'package:linguaflow/utils/language_helper.dart'; // Import your helper

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

// --- IMPORT DIALOG WRAPPER ---
void showCreateLessonDialog(
  BuildContext context,
  String userId,
  String currentLanguage, {
  required bool isFavoriteByDefault,
}) {
  // Use LanguageHelper to get the map automatically
  LessonImportDialog.show(
    context,
    userId,
    currentLanguage,
    LanguageHelper.availableLanguages, 
    isFavoriteByDefault: isFavoriteByDefault,
  );
}