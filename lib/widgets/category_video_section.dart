import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart'; // Web-safe image loading
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/screens/reader/reader_screen.dart'; // Needed to open the video

class CategoryVideoSection extends StatelessWidget {
  final String title;
  final List<LessonModel> lessons;
  final VoidCallback? onSeeAll;

  const CategoryVideoSection({
    super.key,
    required this.title,
    required this.lessons,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    if (lessons.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Header (Title + See All) ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              if (onSeeAll != null)
                GestureDetector(
                  onTap: onSeeAll,
                  child: const Text(
                    "See All",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.blueAccent,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // --- Horizontal Carousel ---
        SizedBox(
          height: 240,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: lessons.length > 10 ? 10 : lessons.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return SizedBox(
                width: 260,
                // FIX: Replaced LibraryVideoCard with this local web-safe widget
                // This removes the "Unsupported operation" crash caused by the other file
                child: _buildSimpleCard(context, lessons[index], textColor),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- INTERNAL WEB-SAFE CARD ---
  Widget _buildSimpleCard(
    BuildContext context,
    LessonModel lesson,
    Color textColor,
  ) {
    return GestureDetector(
      onTap: () {
        // Navigate to the video player
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ReaderScreen(lesson: lesson)),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Image
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: (lesson.imageUrl != null && lesson.imageUrl!.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: lesson.imageUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      // Simple grey box while loading
                      placeholder: (context, url) =>
                          Container(color: Colors.grey[800]),
                      // Simple icon if error (CORS/etc)
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[800],
                        child: const Icon(
                          Icons.broken_image,
                          color: Colors.white54,
                        ),
                      ),
                    )
                  : Container(
                      color: Colors.grey[800],
                      child: const Icon(Icons.movie, color: Colors.white54),
                    ),
            ),
          ),

          const SizedBox(height: 8),

          // 2. Title
          Text(
            lesson.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
