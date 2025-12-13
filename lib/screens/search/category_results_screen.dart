import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/screens/library/widgets/cards/library_video_card.dart';

class CategoryResultsScreen extends StatelessWidget {
  final String categoryTitle;
  final List<LessonModel> lessons;

  const CategoryResultsScreen({
    super.key,
    required this.categoryTitle,
    required this.lessons,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          categoryTitle, 
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: lessons.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(FontAwesomeIcons.ghost, size: 50, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    "No videos found",
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                ],
              ),
            )
          : ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: lessons.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                return LibraryVideoCard(
                  lesson: lessons[index],
                  isDark: isDark,
                );
              },
            ),
    );
  }
}