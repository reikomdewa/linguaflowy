import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';
import 'package:linguaflow/models/lesson_model.dart';
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