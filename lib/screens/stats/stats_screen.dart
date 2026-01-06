import 'package:flutter/material.dart';

class StatsScreen extends StatelessWidget {
  final dynamic user;
  final List<dynamic> vocabItems;
  final Map<String, String> languageNames;

  const StatsScreen({
    super.key,
    required this.user,
    required this.vocabItems,
    required this.languageNames,
  });

  // --- LOGIC HELPERS ---
  
  Map<String, dynamic> _getLevelDetails(int knownWords) {
    if (knownWords < 500) return {'label': "Newcomer", 'next': "A1", 'goal': 500, 'progress': knownWords / 500};
    if (knownWords < 1000) return {'label': "A1 - Beginner", 'next': "A2", 'goal': 1000, 'progress': (knownWords - 500) / 500};
    if (knownWords < 2000) return {'label': "A2 - Elementary", 'next': "B1", 'goal': 2000, 'progress': (knownWords - 1000) / 1000};
    if (knownWords < 4000) return {'label': "B1 - Intermediate", 'next': "B2", 'goal': 4000, 'progress': (knownWords - 2000) / 2000};
    if (knownWords < 8000) return {'label': "B2 - Upper Int.", 'next': "C1", 'goal': 8000, 'progress': (knownWords - 4000) / 4000};
    return {'label': "C1 - Advanced", 'next': "C2", 'goal': 16000, 'progress': (knownWords - 8000) / 8000};
  }

  String _getSmartFeedback(int streak, int velocity, double hours, int totalWords) {
    if (streak <= 1) return "Habit Check: Just 5 minutes a day is better than 2 hours once a week.";
    if (streak >= 7) return "You're on fire! 🔥 Keep this momentum going!";
    if (hours > 2.0 && velocity < 5) return "Great listening! 🎧 Tap words in the reader to track vocab growth.";
    if (velocity > 50) return "Huge vocab growth! 🚀 Try some Audio/Video lessons now.";
    if (totalWords < 500) return "Focus on the basics. Top 500 words unlock 60% of conversation.";
    return "You're making progress. Review flashcards to master your new words.";
  }

  @override
  Widget build(BuildContext context) {
    // A. DATA PREP
    final currentLangVocab = vocabItems.where((v) => v.status > 0 && v.language == user.currentLanguage).toList();
    final int knownWords = currentLangVocab.length;
    final stats = _getLevelDetails(knownWords);
    
    // Metrics
    final int streak = (user.toMap().containsKey('streakDays')) ? user.streakDays : 0;
    final int lessonsRead = (user.toMap().containsKey('lessonsCompleted')) ? user.lessonsCompleted : 0;
    final int totalXp = (user.toMap().containsKey('xp')) ? user.xp : 0;
    final int totalMinutes = (user.toMap().containsKey('totalListeningMinutes')) ? user.totalListeningMinutes : 0;
    final double listeningHours = totalMinutes / 60;

    // Velocity (Words this week)
    final DateTime oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));
    final int wordsThisWeek = currentLangVocab.where((v) {
      return (v.toMap().containsKey('learnedAt') && v.learnedAt != null) 
          ? (v.learnedAt as DateTime).isAfter(oneWeekAgo) 
          : false;
    }).length;

    // Comprehension Calc
    double comprehension = 98.0;
    if (knownWords < 8000) comprehension = 90 + ((knownWords - 4000) / 4000) * 8;
    if (knownWords < 4000) comprehension = 80 + ((knownWords - 2000) / 2000) * 10;
    if (knownWords < 2000) comprehension = 72 + ((knownWords - 1000) / 1000) * 8;
    if (knownWords < 1000) comprehension = (knownWords / 1000) * 72;

    final feedback = _getSmartFeedback(streak, wordsThisWeek, listeningHours, knownWords);
    final langName = languageNames[user.currentLanguage] ?? 'Language';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardBgColor = isDark ? Colors.white.withOpacity(0.08) : Colors.grey[100]!;

    // B. RESPONSIVE BUILDER
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700), // Desktop Constraint
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            physics: const BouncingScrollPhysics(),
            children: [
              // HEADER
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.auto_graph_rounded, color: Colors.amber[800], size: 28),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("$langName Progress", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
                      Text(stats['label'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.blue)),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 30),

              // PROGRESS BAR
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Next: ${stats['next']}", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                  Text("${stats['goal'] - knownWords} words to go", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: stats['progress'],
                  minHeight: 12,
                  backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation(Colors.blue),
                ),
              ),

              const SizedBox(height: 30),

              // FEEDBACK BOX
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.amber.withOpacity(0.1) : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline_rounded, color: Colors.amber.shade700, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        feedback,
                        style: TextStyle(fontSize: 14, height: 1.4, color: isDark ? Colors.grey[300] : Colors.black87, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // STATS GRID
              GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2, // Responsive Cols
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: [
                  _buildStatCard("Daily Streak", "$streak Days", Icons.local_fire_department_rounded, Colors.deepOrangeAccent, cardBgColor, textColor),
                  _buildStatCard("Words (Week)", "+$wordsThisWeek", Icons.trending_up_rounded, Colors.greenAccent.shade700, cardBgColor, textColor),
                  _buildStatCard("Text Understanding", "${comprehension.toStringAsFixed(1)}%", Icons.psychology_rounded, Colors.purpleAccent, cardBgColor, textColor),
                  _buildStatCard("Lessons Read", "$lessonsRead", Icons.library_books_rounded, Colors.blueAccent, cardBgColor, textColor),
                  _buildStatCard("Listening Time", "${listeningHours.toStringAsFixed(1)} h", Icons.headphones_rounded, Colors.pinkAccent, cardBgColor, textColor),
                  _buildStatCard("Total XP", "$totalXp", Icons.bolt_rounded, Colors.amber.shade700, cardBgColor, textColor),
                ],
              ),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color iconColor, Color bg, Color? text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: text)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: text?.withOpacity(0.6)), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}