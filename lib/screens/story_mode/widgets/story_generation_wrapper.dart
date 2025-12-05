import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';
import 'package:linguaflow/screens/story_mode/story_mode_screen.dart';

class StoryGenerationWrapper extends StatelessWidget {
  const StoryGenerationWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<LessonBloc, LessonState>(
        builder: (context, state) {
          // 1. LOADING STATE (Making your story)
          if (state is LessonLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // const CircularProgressIndicator(),
                     const Text(
                    "Loading...",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Making your story...",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "This usually takes 5-10 seconds",
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                ],
              ),
            );
          }

          // 2. SUCCESS STATE (Show the actual Story Mode)
          if (state is LessonGenerationSuccess) {
            return StoryModeScreen(lesson: state.lesson);
          }

          // 3. ERROR STATE
          if (state is LessonError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      "Something went wrong",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Go Back"),
                    )
                  ],
                ),
              ),
            );
          }

          // Default fallback
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}