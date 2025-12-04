import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';
import 'package:linguaflow/services/youtube_import_service.dart';

Future<void> handleYoutubeImport(BuildContext context, String url) async {
  // 1. Validation
  if (url.isEmpty) return;
  
  // 2. Get dependencies
  final ytService = YoutubeImportService();
  // We assume the user is authenticated if they are on the Home Screen
  final authState = context.read<AuthBloc>().state;
  
  String? userId;
  String targetLang = 'en'; // Default fallback

  if (authState is AuthAuthenticated) {
    userId = authState.user.id;
    targetLang = authState.user.currentLanguage;
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("You must be logged in to import videos.")),
    );
    return;
  }

  // 3. Show Loading Dialog
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => Center(child: CircularProgressIndicator()),
  );

  try {
    // 4. Run the Import Service
    final lesson = await ytService.importVideo(url, targetLang, userId);

    // 5. Close Loading Dialog
    if (context.mounted) Navigator.pop(context); 

    if (lesson != null) {
      // 6. Add to Bloc
      if (context.mounted) {
        context.read<LessonBloc>().add(LessonCreateRequested(lesson));
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Video imported successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  } catch (e) {
    // Close Loading Dialog on Error
    if (context.mounted) {
      Navigator.pop(context); 
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Import Failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    // ytService.dispose();
  }
}