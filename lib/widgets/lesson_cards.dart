import 'package:flutter/material.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/vocabulary_item.dart';

// --- HELPER LOGIC ---
Map<String, int> getLessonStats(
  LessonModel lesson,
  Map<String, VocabularyItem> vocabMap,
) {
  String fullText = lesson.content;
  if (lesson.transcript.isNotEmpty) {
    fullText = lesson.transcript.map((e) => e.text).join(" ");
  }

  final List<String> words = fullText.split(RegExp(r'(\s+)'));
  int newWords = 0;
  int knownWords = 0;
  final Set<String> uniqueWords = {};

  for (var word in words) {
    final cleanWord = word.toLowerCase().trim().replaceAll(
      RegExp(r'[^\w\s]'),
      '',
    );
    if (cleanWord.isEmpty) continue;
    if (uniqueWords.contains(cleanWord)) continue;

    uniqueWords.add(cleanWord);
    final vocabItem = vocabMap[cleanWord];

    // Status 0 or null = New. Status > 0 = Known (to some degree)
    if (vocabItem == null || vocabItem.status == 0) {
      newWords++;
    } else {
      knownWords++;
    }
  }
  return {'new': newWords, 'known': knownWords};
}

// --- VIDEO LESSON CARD ---
class VideoLessonCard extends StatelessWidget {
  final LessonModel lesson;
  final Map<String, VocabularyItem> vocabMap;
  final bool isDark;
  final Color? textColor;
  final VoidCallback onTap;
  final VoidCallback onOptionTap;

  const VideoLessonCard({super.key, 
    required this.lesson,
    required this.vocabMap,
    required this.isDark,
    this.textColor,
    required this.onTap,
    required this.onOptionTap,
  });

  @override
  Widget build(BuildContext context) {
    final stats = getLessonStats(lesson, vocabMap);
    final int newCount = stats['new']!;
    final int knownCount = stats['known']!;
    final double progress = (knownCount + newCount) == 0
        ? 0
        : knownCount / (knownCount + newCount);

    return SizedBox(
      width: 280,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 160,
                    width: 280,
                    color: isDark ? Colors.white10 : Colors.grey[200],
                    child: lesson.imageUrl != null
                        ? Image.network(lesson.imageUrl!, fit: BoxFit.cover)
                        : Icon(
                            Icons.play_circle_outline,
                            size: 50,
                            color: Colors.grey,
                          ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      lesson.difficulty.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(12),
                    ),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor: Colors.black26,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.greenAccent[400]!,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Text(
              lesson.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                height: 1.2,
                color: isDark ? Colors.grey[200] : Colors.grey[800],
              ),
            ),
            SizedBox(height: 6),
            Expanded(
              child: Row(
                children: [
                  // Icon(Icons.circle, size: 8, color: Colors.blue),
                  // SizedBox(width: 4),
                  // Text("$newCount New", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  // SizedBox(width: 12),
                  // Icon(Icons.circle, size: 8, color: Colors.green), // Changed to Green for 'Known' alignment
                  // SizedBox(width: 4),
                  Text(
                    "$knownCount known",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.more_vert, color: Colors.grey, size: 16),
                    constraints: BoxConstraints(),
                    padding: EdgeInsets.zero,
                    onPressed: onOptionTap,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- TEXT LESSON CARD (UPDATED WITH STATS) ---
class TextLessonCard extends StatelessWidget {
  final LessonModel lesson;
  final Map<String, VocabularyItem> vocabMap;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onOptionTap;

  const TextLessonCard({super.key, 
    required this.lesson,
    required this.vocabMap,
    required this.isDark,
    required this.onTap,
    required this.onOptionTap,
  });

  @override
  Widget build(BuildContext context) {
    final stats = getLessonStats(lesson, vocabMap);
    final int newCount = stats['new']!;
    final int knownCount = stats['known']!;
    final double progress = (knownCount + newCount) == 0
        ? 0
        : knownCount / (knownCount + newCount);

    return Card(
      elevation: 0,
      color: isDark ? Colors.white10 : Colors.grey[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.transparent : Colors.grey.shade200,
        ),
      ),
      margin: EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              // Top Row: Icon + Title + Menu
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.article, color: Colors.blue),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lesson.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isDark ? Colors.white70 : Colors.grey[800],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          lesson.content.replaceAll('\n', ' '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.more_vert, color: Colors.grey, size: 20),
                    constraints: BoxConstraints(),
                    padding: EdgeInsets.zero,
                    onPressed: onOptionTap,
                  ),
                ],
              ),

              SizedBox(height: 12),

              // Bottom Row: Stats and Progress Bar
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: isDark
                            ? Colors.black26
                            : Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.greenAccent[400]!,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  // Compact Stats
                  Text(
                    "${(progress * 100).toInt()}%",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(width: 1, height: 12, color: Colors.grey),
                  SizedBox(width: 8),
                  Text(
                    "$knownCount known",
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
