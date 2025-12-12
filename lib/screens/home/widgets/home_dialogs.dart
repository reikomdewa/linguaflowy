
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/utils/constants.dart';

class HomeDialogs {
  
  // --- STATS DIALOG ---
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

  // --- LESSON OPTIONS DIALOG ---
  static void showLessonOptions(
      BuildContext context, LessonModel lesson, bool isDark) {
    
    // 1. Capture parent context for Bloc access
    final parentContext = context;
    
    final authState = parentContext.read<AuthBloc>().state;
    String currentUserId = ''; 
    bool canDelete = false;
    bool isOwner = false;

    if (authState is AuthAuthenticated) {
      final user = authState.user;
      currentUserId = user.id; 

      isOwner = (user.id == lesson.userId);
      final bool isAdmin = AppConstants.isAdmin(user.email); 

      canDelete = isAdmin || isOwner;
    }

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
                lesson.isFavorite ? 'Remove from Favorites' : 'Save to Library',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              subtitle: Text(
                isOwner 
                  ? (lesson.isFavorite ? 'Removed from library.' : 'Saved to library.')
                  : 'Create a copy in your cloud library.',
                style: const TextStyle(color: Colors.grey),
              ),
              onTap: () {
                // DEBUG PRINT
                print("🔵 [Dialog] User tapped Favorite. CurrentUser: '$currentUserId', LessonOwner: '${lesson.userId}'");

                if (currentUserId.isEmpty) {
                   print("🔴 [Dialog] User is not authenticated. Aborting.");
                   Navigator.pop(builderContext);
                   return;
                }

                if (isOwner) {
                  // I own this lesson, so I just update the existing one
                  print("🟢 [Dialog] User is Owner. Updating existing document.");
                  final updatedLesson = lesson.copyWith(
                    isFavorite: !lesson.isFavorite,
                  );
                  parentContext.read<LessonBloc>().add(LessonUpdateRequested(updatedLesson));
                } else {
                  // I DO NOT own this lesson (System Lesson)
                  // I must CREATE A COPY in the cloud
                  print("🟠 [Dialog] System Lesson detected. Creating Cloud Copy.");
                  
                  final newLesson = lesson.copyWith(
                    id: '', // EMPTY ID indicates a new creation
                    userId: currentUserId, // Assign to ME
                    isFavorite: true, 
                    isLocal: false, // FORCE CLOUD SAVE
                    createdAt: DateTime.now(),
                  );
                  
                  parentContext.read<LessonBloc>().add(LessonCreateRequested(newLesson));
                  
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    const SnackBar(content: Text("Saving copy to your cloud library...")),
                  );
                }
                Navigator.pop(builderContext);
              },
            ),

            if (canDelete) ...[
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
                title: const Text('Delete Lesson',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text("Delete Lesson?"),
                      content: const Text("This cannot be undone. Are you sure?"),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("Cancel"),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            parentContext
                                .read<LessonBloc>()
                                .add(LessonDeleteRequested(lesson.id));
                            Navigator.pop(builderContext);
                          },
                          child: const Text("Delete",
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}