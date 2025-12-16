import 'dart:io';

import 'package:flutter/material.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/vocabulary_item.dart';
import 'package:linguaflow/widgets/lesson_cards.dart'
    as home_logic; // Ensure correct import path

class VideoLessonCard extends StatelessWidget {
  final LessonModel lesson;
  final Map<String, VocabularyItem> vocabMap;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onOptionTap;

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
    final stats = home_logic.getLessonStats(lesson, vocabMap);
    final int newCount = stats['new']!;
    final int knownCount = stats['known']!;

    // 1. Calculate the Vocabulary Percentage (For the text label)
    final int totalWords = newCount + knownCount;
    final int knownPercentage = totalWords == 0
        ? 0
        : ((knownCount / totalWords) * 100).toInt();

    // 2. Calculate Video Progress (For the red/green bar at the bottom image)
    // Priority: Video Playback Progress > Vocab Progress
    double progressBarValue = lesson.progress > 0 ? lesson.progress / 100 : 0.0;

    // Fallback: If no video progress, show vocab progress on the bar
    if (lesson.progress == 0 && totalWords > 0) {
      progressBarValue = knownCount / totalWords;
    }

    return Container(
      width: 280,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- THUMBNAIL SECTION ---
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 160,
                    width: 280,
                    color: isDark ? Colors.white10 : Colors.grey[200],
                    child:
                        (lesson.imageUrl != null &&
                            (lesson.type == 'video' ||
                                lesson.type == 'video_native' ||
                                lesson.type == 'audio'))
                        ? (lesson.imageUrl!.startsWith('http')
                              ? Image.network(
                                  lesson.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Center(
                                        child: Icon(
                                          Icons.broken_image,
                                          size: 32,
                                        ),
                                      ),
                                )
                              : Image.file(
                                  File(lesson.imageUrl!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Center(
                                        child: Icon(
                                          Icons.broken_image,
                                          size: 32,
                                        ),
                                      ),
                                ))
                        : (lesson.type == 'text'
                              ? Center(
                                  child: Icon(
                                    Icons.menu_book_rounded,
                                    size: 64,
                                    color: Colors.blue.withValues(alpha: 0.5),
                                  ),
                                )
                              : (lesson.type == 'audio')
                              ? const Center(
                                  child: Icon(
                                    Icons.music_note,
                                    size: 64,
                                    color: Colors.grey,
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

                // Difficulty Badge
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
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

                // Imported Badge
                if (lesson.isLocal)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Imported',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                // Progress Bar (Visual)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(12),
                    ),
                    child: LinearProgressIndicator(
                      value: progressBarValue,
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

            // --- TITLE ---
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

            // --- STATS ROW (UPDATED) ---
            SizedBox(
              height: 20,
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        // 1. NEW WORDS (Critical for CI)
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

                        // 2. KNOWN PERCENTAGE (Updated)
                        const Icon(Icons.circle, size: 8, color: Colors.green),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            "$knownPercentage% Known", // <--- UPDATED HERE
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

class TextLessonCard extends StatelessWidget {
  final LessonModel lesson;
  final Map<String, VocabularyItem> vocabMap;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onOptionTap;

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
    final stats = home_logic.getLessonStats(lesson, vocabMap);
    final int newCount = stats['new']!;
    final int knownCount = stats['known']!;

    // Calculate Percentage
    final int totalWords = newCount + knownCount;
    final double progressRatio = totalWords == 0
        ? 0.0
        : knownCount / totalWords;
    final int knownPercentage = (progressRatio * 100).toInt();

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
        onTap: onTap,
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
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.article, color: Colors.blue),
                  ),
                  const SizedBox(width: 12),
                  // Expanded(
                  //   child: Column(
                  //     crossAxisAlignment: CrossAxisAlignment.start,
                  //     children: [
                  //       Text(
                  //         lesson.title,
                  //         style: TextStyle(
                  //           fontWeight: FontWeight.bold,
                  //           color: isDark ? Colors.white70 : Colors.grey[800],
                  //         ),
                  //         maxLines: 1,
                  //         overflow: TextOverflow.ellipsis,
                  //       ),
                  //       const SizedBox(height: 4),
                  //       Text(
                  //         lesson.content.replaceAll('\n', ' '),
                  //         maxLines: 2,
                  //         overflow: TextOverflow.ellipsis,
                  //         style:
                  //             const TextStyle(color: Colors.grey, fontSize: 13),
                  //       ),
                  //     ],
                  //   ),
                  // ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Add a small tag above the title
                        if (lesson.genre == 'short_story')
                          Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "Short Story",
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange[800],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                        Text(lesson.title),
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
                    onPressed: onOptionTap,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // --- STATS ROW ---
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progressRatio,
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

                  // Percentage
                  Text(
                    "$knownPercentage%",
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),

                  const SizedBox(width: 8),
                  Container(width: 1, height: 12, color: Colors.grey),
                  const SizedBox(width: 8),

                  // New Words
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
