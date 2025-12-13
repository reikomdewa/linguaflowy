import 'package:flutter/material.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/screens/library/widgets/cards/library_video_card.dart'; // Ensure correct import

class CategoryVideoSection extends StatelessWidget {
  final String title;
  final List<LessonModel> lessons;
  final VoidCallback? onSeeAll; // If null, "See All" is hidden

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
            // Show max 10 items in the preview carousel
            itemCount: lessons.length > 10 ? 10 : lessons.length, 
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return SizedBox(
                width: 260,
                child: LibraryVideoCard(
                  lesson: lessons[index],
                  isDark: isDark,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}