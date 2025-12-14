import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/utils/constants.dart';
// import 'package:linguaflow/models/user_model.dart'; // Ensure this is imported if you use strict typing

class HomeDialogs {
  // --- 1. SHARED LEVEL CALCULATION LOGIC ---
  static Map<String, dynamic> getLevelDetails(int knownWords) {
    String currentLevel;
    String shortLevel;
    String nextLevel;
    int nextGoal;
    double progress;

    if (knownWords < 500) {
      currentLevel = "Newcomer";
      shortLevel = "Newcomer";
      nextLevel = "A1";
      nextGoal = 500;
      progress = knownWords / 500;
    } else if (knownWords < 1000) {
      currentLevel = "A1 - Beginner";
      shortLevel = "A1";
      nextLevel = "A2";
      nextGoal = 1000;
      progress = (knownWords - 500) / 500;
    } else if (knownWords < 2000) {
      currentLevel = "A2 - Elementary";
      shortLevel = "A2";
      nextLevel = "B1";
      nextGoal = 2000;
      progress = (knownWords - 1000) / 1000;
    } else if (knownWords < 4000) {
      currentLevel = "B1 - Intermediate";
      shortLevel = "B1";
      nextLevel = "B2";
      nextGoal = 4000;
      progress = (knownWords - 2000) / 2000;
    } else if (knownWords < 8000) {
      currentLevel = "B2 - Upper Intermediate";
      shortLevel = "B2";
      nextLevel = "C1";
      nextGoal = 8000;
      progress = (knownWords - 4000) / 4000;
    } else {
      currentLevel = "C1 - Advanced";
      shortLevel = "C1";
      nextLevel = "C2";
      nextGoal = 16000;
      progress = (knownWords - 8000) / 8000;
    }

    return {
      'fullLabel': currentLevel,
      'shortLabel': shortLevel,
      'nextLabel': nextLevel,
      'nextGoal': nextGoal,
      'progress': progress,
    };
  }

  // --- 2. UPDATED STATS DIALOG ---
  static void showStatsDialog(
    BuildContext context,
    dynamic user, // Expecting User model
    List<dynamic> vocabItems, // Expecting List<VocabularyItem>
    Map<String, String> languageNames,
  ) {
    // A. FILTER VOCAB FOR CURRENT LANGUAGE
    final currentLangVocab = vocabItems
        .where((v) => v.status > 0 && v.language == user.currentLanguage)
        .toList();

    // B. CALCULATE BASIC LEVEL
    final int knownWords = currentLangVocab.length;
    final stats = getLevelDetails(knownWords);

    final String currentLevel = stats['fullLabel'];
    final String nextLevel = stats['nextLabel'];
    final int nextGoal = stats['nextGoal'];
    final double progress = stats['progress'];

    // C. CALCULATE NEW METRICS

    // 1. 🔥 Streak
    // Assuming User model has 'streakDays'. Default to 0.
    final int streak = (user.toMap().containsKey('streakDays'))
        ? user.streakDays
        : 0;

    // 2. 📚 Content Consumed
    // Assuming User model has 'lessonsCompleted'. Default to 0.
    final int lessonsRead = (user.toMap().containsKey('lessonsCompleted'))
        ? user.lessonsCompleted
        : 0;

    // 3. 📈 Learning Velocity (Words this week)
    final DateTime oneWeekAgo = DateTime.now().subtract(
      const Duration(days: 7),
    );
    final int wordsThisWeek = currentLangVocab.where((v) {
      // Check if item has a date field (learnedAt or similar).
      // Adjust 'learnedAt' to match your VocabularyItem field name.
      if (v.toMap().containsKey('learnedAt') && v.learnedAt != null) {
        return (v.learnedAt as DateTime).isAfter(oneWeekAgo);
      }
      return false;
    }).length;

    // 4. 🧠 Text Comprehension %
    double comprehension = 0.0;
    if (knownWords < 1000)
      comprehension = (knownWords / 1000) * 72;
    else if (knownWords < 2000)
      comprehension = 72 + ((knownWords - 1000) / 1000) * 8;
    else if (knownWords < 4000)
      comprehension = 80 + ((knownWords - 2000) / 2000) * 10;
    else if (knownWords < 8000)
      comprehension = 90 + ((knownWords - 4000) / 4000) * 8;
    else
      comprehension = 98.0;

    // 5. 🎧 Listening Hours
    // Assuming User model has 'totalListeningMinutes'.
    final int totalMinutes = (user.toMap().containsKey('totalListeningMinutes'))
        ? user.totalListeningMinutes
        : 0;
    final double listeningHours = totalMinutes / 60;

    // D. UI STYLING
    final langName = languageNames[user.currentLanguage] ?? 'Target Language';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final cardBgColor = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.grey[100];

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
        child: SingleChildScrollView(
          // Added for safety on small screens
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- HEADER ---
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.auto_graph_rounded,
                      color: Colors.amber[800],
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "$langName Progress",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const Text(
                        "Consistency is key!",
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 32),

              // --- MAIN LEVEL ---
              Center(
                child: Column(
                  children: [
                    const Text(
                      "Current Level",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentLevel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // --- PROGRESS BAR ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Next: $nextLevel",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  Text(
                    "${nextGoal - knownWords} to go",
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
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

              const SizedBox(height: 30),

              // --- STATS GRID (The New Part) ---
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.5, // Controls height of cards
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: [
                  // 1. Streak
                  _buildStatCard(
                    icon: Icons.local_fire_department_rounded,
                    iconColor: Colors.deepOrangeAccent,
                    value: "$streak Days",
                    label: "Daily Streak",
                    bgColor: cardBgColor!,
                    textColor: textColor,
                  ),
                  // 2. Velocity
                  _buildStatCard(
                    icon: Icons.trending_up_rounded,
                    iconColor: Colors.greenAccent.shade700,
                    value: "+$wordsThisWeek",
                    label: "Words this Week",
                    bgColor: cardBgColor,
                    textColor: textColor,
                  ),
                  // 3. Comprehension
                  _buildStatCard(
                    icon: Icons.psychology_rounded,
                    iconColor: Colors.purpleAccent,
                    value: "${comprehension.toStringAsFixed(1)}%",
                    label: "Text Understanding",
                    bgColor: cardBgColor,
                    textColor: textColor,
                  ),
                  // 4. Content Consumed
                  _buildStatCard(
                    icon: Icons.library_books_rounded,
                    iconColor: Colors.blueAccent,
                    value: "$lessonsRead",
                    label: "Lessons Read",
                    bgColor: cardBgColor,
                    textColor: textColor,
                  ),
                  // 5. Listening Hours (Spans full width or just fits in grid)
                  _buildStatCard(
                    icon: Icons.headphones_rounded,
                    iconColor: Colors.pinkAccent,
                    value: "${listeningHours.toStringAsFixed(1)} h",
                    label: "Listening/Watch Time",
                    bgColor: cardBgColor,
                    textColor: textColor,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // --- BUTTON ---
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white : Colors.black,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("Keep Learning"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- HELPER: STAT CARD WIDGET ---
  static Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    required Color bgColor,
    required Color? textColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Icon(icon, color: iconColor, size: 22)],
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: textColor?.withOpacity(0.6)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // --- 3. LESSON OPTIONS DIALOG (No changes here) ---
  static void showLessonOptions(
    BuildContext context,
    LessonModel lesson,
    bool isDark,
  ) {
    // ... [Previous code remains exactly the same] ...
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
                    ? (lesson.isFavorite
                          ? 'Removed from library.'
                          : 'Saved to library.')
                    : 'Create a copy in your cloud library.',
                style: const TextStyle(color: Colors.grey),
              ),
              onTap: () {
                if (currentUserId.isEmpty) {
                  Navigator.pop(builderContext);
                  return;
                }
                if (isOwner) {
                  final updatedLesson = lesson.copyWith(
                    isFavorite: !lesson.isFavorite,
                  );
                  parentContext.read<LessonBloc>().add(
                    LessonUpdateRequested(updatedLesson),
                  );
                } else {
                  final newLesson = lesson.copyWith(
                    id: '',
                    userId: currentUserId,
                    isFavorite: true,
                    isLocal: false,
                    createdAt: DateTime.now(),
                  );
                  parentContext.read<LessonBloc>().add(
                    LessonCreateRequested(newLesson),
                  );
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    const SnackBar(
                      content: Text("Saving copy to your cloud library..."),
                    ),
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
                title: const Text(
                  'Delete Lesson',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text("Delete Lesson?"),
                      content: const Text(
                        "This cannot be undone. Are you sure?",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("Cancel"),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            parentContext.read<LessonBloc>().add(
                              LessonDeleteRequested(lesson.id),
                            );
                            Navigator.pop(builderContext);
                          },
                          child: const Text(
                            "Delete",
                            style: TextStyle(color: Colors.red),
                          ),
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
