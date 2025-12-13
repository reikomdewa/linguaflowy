import 'package:flutter/material.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/screens/library/widgets/cards/library_text_card.dart';
import 'package:linguaflow/screens/library/widgets/cards/library_video_card.dart'; 

class LibrarySearchDelegate extends SearchDelegate {
  final List<LessonModel> lessons;
  final bool isDark;
  final String? initialQuery; // Add this

  LibrarySearchDelegate({
    required this.lessons,
    required this.isDark,
    this.initialQuery, 
  }) {
    // Set the query if passed (allows auto-search on open)
    if (initialQuery != null) {
      query = initialQuery!; 
    }
  }

  // --- THEME STYLING ---
  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontSize: 18,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
        border: InputBorder.none,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: isDark ? Colors.white : Colors.black,
      ),
      textTheme: theme.textTheme.copyWith(
        titleLarge: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontSize: 18,
        ),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildFilteredList();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildFilteredList();
  }

  Widget _buildFilteredList() {
    // 1. Filter Logic
    final filteredLessons = lessons.where((lesson) {
      final titleLower = lesson.title.toLowerCase();
      final genreLower = lesson.genre.toLowerCase(); // <--- CHECK GENRE
      final searchLower = query.toLowerCase();

      // Simple keyword matching: Title OR Genre
      return titleLower.contains(searchLower) || genreLower.contains(searchLower);
    }).toList();

    // 2. Empty State
    if (filteredLessons.isEmpty) {
      return Container(
        color: isDark ? const Color(0xFF121212) : Colors.white,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 60, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No results found for "$query"',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    // 3. Results List
    return Container(
      color: isDark ? const Color(0xFF121212) : Colors.white,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: filteredLessons.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final lesson = filteredLessons[index];

          if (lesson.type == 'video' || lesson.videoUrl != null) {
            return LibraryVideoCard(lesson: lesson, isDark: isDark);
          } else {
            return LibraryTextCard(lesson: lesson, isDark: isDark);
          }
        },
      ),
    );
  }
}