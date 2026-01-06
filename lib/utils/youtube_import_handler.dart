import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_state.dart';
import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/utils/logger.dart';
// Import the new widget created in the previous step
import 'package:linguaflow/widgets/youtube_extractor_view.dart';

Future<void> handleYoutubeImport(BuildContext context, String url) async {
  // 1. Validation
  if (url.isEmpty) return;

  // 2. Get User Info
  final authState = context.read<AuthBloc>().state;

  String userId;
  String targetLang = 'en'; // Default fallback

  if (authState is AuthAuthenticated) {
    userId = authState.user.id;
    targetLang = authState.user.currentLanguage;
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("You must be logged in to import videos.")),
    );
    return;
  }

  // 3. Navigate to the Extractor Widget
  // We DO NOT use showDialog here because the ExtractorView *is* the UI
  // that holds the WebView and shows the progress spinner.
  final LessonModel? lesson = await Navigator.push(
    context,
    MaterialPageRoute(
      fullscreenDialog: true, // Opens as a modal (optional)
      builder: (context) => YoutubeExtractorView(
        videoUrl: url,
        targetLang: targetLang,
        userId: userId,
      ),
    ),
  );

  // 4. Handle Result
  if (context.mounted) {
    if (lesson != null) {
      // Success: Add to Bloc
      context.read<LessonBloc>().add(LessonCreateRequested(lesson));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Video imported successfully!"),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      // Failure or Cancelled (The view handles showing the specific error snackbar internally)
      // We just ensure no empty state is left hanging if needed.
      print("Import cancelled or returned null.");
    }
  }
}
