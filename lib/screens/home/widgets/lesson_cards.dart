import 'package:flutter/material.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/vocabulary_item.dart';
import 'package:linguaflow/widgets/lesson_cards.dart'
    as HomeLogic; // Ensure correct import path

class VideoLessonCard extends StatelessWidget {
  final LessonModel lesson;
  final Map<String, VocabularyItem> vocabMap;
  final bool isDark;
  final VoidCallback onTap; // <--- REQUIRED
  final VoidCallback onOptionTap; // <--- REQUIRED

  const VideoLessonCard({
    super.key,
    required this.lesson,
    required this.vocabMap,
    required this.isDark,
    required this.onTap,
    required this.onOptionTap,
  });

  @override
  Widget build(BuildContext context) {
    final stats = HomeLogic.getLessonStats(lesson, vocabMap);
    final int newCount = stats['new']!;
    final int knownCount = stats['known']!;

    double progress = lesson.progress > 0 ? lesson.progress / 100 : 0.0;
    if (progress == 0 && (knownCount + newCount) > 0) {
      progress = knownCount / (knownCount + newCount);
    }

    return Container(
      width: 280,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap, // <--- Used here
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
                    child: (lesson.imageUrl != null && (lesson.type == 'video' || lesson.type == 'video_native')) 
                        ? Image.network(lesson.imageUrl!, fit: BoxFit.cover)
                        : (lesson.type == 'text'
                              ? Center(
                                  child: Icon(
                                    Icons.menu_book_rounded,
                                    size: 64,
                                    color: Colors.blue.withOpacity(0.5),
                                  ),
                                )
                              : const Center(
                                  child: Icon(
                                    Icons.play_circle,
                                    size: 64,
                                    color: Colors.grey,
                                  ),
                                )),
                  ),
                ),
                // ... (Keep existing badges/progress bar code) ...
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      lesson.difficulty.toUpperCase(),
                      style: const TextStyle(
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
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(12),
                    ),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor: Colors.transparent,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.green,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              lesson.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                height: 1.2,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            SizedBox(
              height: 20,
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.circle, size: 8, color: Colors.blue),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            "$newCount New",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.circle, size: 8, color: Colors.green),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            "$knownCount known",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.more_vert,
                      color: Colors.grey,
                      size: 16,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    onPressed: onOptionTap, // <--- Used here
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

class TextLessonCard extends StatelessWidget {
  final LessonModel lesson;
  final Map<String, VocabularyItem> vocabMap;
  final bool isDark;
  final VoidCallback onTap; // <--- REQUIRED
  final VoidCallback onOptionTap; // <--- REQUIRED

  const TextLessonCard({
    super.key,
    required this.lesson,
    required this.vocabMap,
    required this.isDark,
    required this.onTap,
    required this.onOptionTap,
  });

  @override
  Widget build(BuildContext context) {
    // ... Logic ...
    final stats = HomeLogic.getLessonStats(lesson, vocabMap);
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
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap, // <--- Used here
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
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
                    child: const Icon(Icons.article, color: Colors.blue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lesson.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : Colors.grey[800],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lesson.content.replaceAll('\n', ' '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.more_vert,
                      color: Colors.grey,
                      size: 16,
                    ),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    onPressed: onOptionTap, // <--- Used here
                  ),
                ],
              ),
              // ... (Progress bar code) ...
              const SizedBox(height: 12),
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
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.green,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "${(progress * 100).toInt()}%",
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(width: 1, height: 12, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    "$newCount New",
                    style: const TextStyle(fontSize: 11, color: Colors.blue),
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
