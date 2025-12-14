import 'package:flutter/material.dart';
import 'package:linguaflow/widgets/lesson_import_dialog.dart';
import 'package:linguaflow/utils/language_helper.dart'; // Import your helper



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