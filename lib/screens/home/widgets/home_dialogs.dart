import 'package:flutter/material.dart';


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
    dynamic user,
    List<dynamic> vocabItems,
    Map<String, String> languageNames,
  ) {
    // A. FILTER VOCAB
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

    // C. CALCULATE METRICS
    final int streak = (user.toMap().containsKey('streakDays'))
        ? user.streakDays
        : 0;
    final int lessonsRead = (user.toMap().containsKey('lessonsCompleted'))
        ? user.lessonsCompleted
        : 0;

    final DateTime oneWeekAgo = DateTime.now().subtract(
      const Duration(days: 7),
    );
    final int wordsThisWeek = currentLangVocab.where((v) {
      if (v.toMap().containsKey('learnedAt') && v.learnedAt != null) {
        return (v.learnedAt as DateTime).isAfter(oneWeekAgo);
      }
      return false;
    }).length;

    double comprehension = 0.0;
    if (knownWords < 1000) {
      comprehension = (knownWords / 1000) * 72;
    } else if (knownWords < 2000)
      comprehension = 72 + ((knownWords - 1000) / 1000) * 8;
    else if (knownWords < 4000)
      comprehension = 80 + ((knownWords - 2000) / 2000) * 10;
    else if (knownWords < 8000)
      comprehension = 90 + ((knownWords - 4000) / 4000) * 8;
    else
      comprehension = 98.0;

    final int totalMinutes = (user.toMap().containsKey('totalListeningMinutes'))
        ? user.totalListeningMinutes
        : 0;
    final double listeningHours = totalMinutes / 60;

    // D. SMART FEEDBACK
    final String feedback = _getSmartFeedback(
      streak,
      wordsThisWeek,
      listeningHours,
      knownWords,
    );

    // E. UI VARS
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
      useSafeArea:
          true, // <--- FIX: This ensures it respects the top notch/status bar
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewPadding.bottom,
        ),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // 1. SCROLLABLE CONTENT
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 100),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- DRAG HANDLE ---
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

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
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: isDark
                          ? Colors.grey[800]
                          : Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation(Colors.blue),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- SMART FEEDBACK ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.amber.withOpacity(0.1)
                          : Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.amber.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb_outline_rounded,
                          color: Colors.amber.shade700,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            feedback,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: isDark ? Colors.grey[300] : Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- STATS GRID ---
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.5,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    children: [
                      _buildStatCard(
                        icon: Icons.local_fire_department_rounded,
                        iconColor: Colors.deepOrangeAccent,
                        value: "$streak Days",
                        label: "Daily Streak",
                        bgColor: cardBgColor!,
                        textColor: textColor,
                      ),
                      _buildStatCard(
                        icon: Icons.trending_up_rounded,
                        iconColor: Colors.greenAccent.shade700,
                        value: "+$wordsThisWeek",
                        label: "Words this Week",
                        bgColor: cardBgColor,
                        textColor: textColor,
                      ),
                      _buildStatCard(
                        icon: Icons.psychology_rounded,
                        iconColor: Colors.purpleAccent,
                        value: "${comprehension.toStringAsFixed(1)}%",
                        label: "Text Understanding",
                        bgColor: cardBgColor,
                        textColor: textColor,
                      ),
                      _buildStatCard(
                        icon: Icons.library_books_rounded,
                        iconColor: Colors.blueAccent,
                        value: "$lessonsRead",
                        label: "Lessons Read",
                        bgColor: cardBgColor,
                        textColor: textColor,
                      ),
                      _buildStatCard(
                        icon: Icons.headphones_rounded,
                        iconColor: Colors.pinkAccent,
                        value: "${listeningHours.toStringAsFixed(1)} h",
                        label: "Listening Time",
                        bgColor: cardBgColor,
                        textColor: textColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 2. FLOATING BUTTON
            Positioned(
              left: 24,
              right: 24,
              bottom: 24,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white : Colors.blue,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 6,
                    shadowColor: Colors.black38,
                  ),
                  child: const Text(
                    "Keep Learning",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- SMART FEEDBACK LOGIC ---
  static String _getSmartFeedback(
    int streak,
    int velocity,
    double hours,
    int totalWords,
  ) {
    if (streak <= 1) {
      return "Habit Check: Just 5 minutes a day is better than 2 hours once a week. Try to open the app tomorrow to start a streak!";
    }
    if (streak >= 7 && streak < 30) {
      return "You're on fire! 🔥 Staying consistent for a week is the hardest part. Keep this momentum going!";
    }
    if (hours > 2.0 && velocity < 5) {
      return "Great listening skills! 🎧 Don't forget to tap words in the reader to mark them as 'Known'. This tracks your vocabulary growth.";
    }
    if (velocity > 50 && hours < 0.5) {
      return "Huge vocabulary growth! 🚀 Try balancing it with some Audio/Video lessons to train your ear.";
    }
    if (totalWords < 500) {
      return "Focus on the basics. Learning the top 500 words will unlock about 60% of daily conversation.";
    }
    if (totalWords > 2000) {
      return "You have a strong foundation. 🏛️ Try challenging yourself with Native Content (Video Feeds) to test your comprehension.";
    }
    return "You're making progress every day. Review your flashcards to move words from 'Learning' to 'Known'.";
  }

  // --- HELPER: STAT CARD ---
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

}
