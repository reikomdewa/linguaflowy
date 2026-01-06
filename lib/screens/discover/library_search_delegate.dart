import 'package:flutter/material.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/screens/library/widgets/cards/library_text_card.dart';
import 'package:linguaflow/screens/library/widgets/cards/library_video_card.dart';

class LibrarySearchDelegate extends SearchDelegate {
  final List<LessonModel> lessons;
  final bool isDark;
  final String? initialQuery;

  LibrarySearchDelegate({
    required this.lessons,
    required this.isDark,
    this.initialQuery,
  }) {
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
        // Stop color change on scroll
        scrolledUnderElevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle:
            TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
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
    return _buildFilteredList(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildFilteredList(context);
  }

  Widget _buildFilteredList(BuildContext context) {
    // 1. Filter Logic
    final filteredLessons = lessons.where((lesson) {
      final titleLower = lesson.title.toLowerCase();
      final genreLower = lesson.genre.toLowerCase();
      final searchLower = query.toLowerCase();

      return titleLower.contains(searchLower) ||
          genreLower.contains(searchLower);
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

    // 3. Responsive Results List
    return Container(
      color: isDark ? const Color(0xFF121212) : Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 750;

          if (isDesktop) {
            // --- DESKTOP GRID VIEW ---
            return GridView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: filteredLessons.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 400, // Card width limit
                mainAxisExtent: 280, // Fixed Card height
                crossAxisSpacing: 24,
                mainAxisSpacing: 24,
              ),
              itemBuilder: (context, index) => _buildCard(filteredLessons[index]),
            );
          } else {
            // --- MOBILE LIST VIEW ---
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: filteredLessons.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) => _buildCard(filteredLessons[index]),
            );
          }
        },
      ),
    );
  }

  // Helper to build the correct card type
  Widget _buildCard(LessonModel lesson) {
    if (lesson.type == 'video' || lesson.videoUrl != null) {
      return LibraryVideoCard(lesson: lesson, isDark: isDark);
    } else {
      return LibraryTextCard(lesson: lesson, isDark: isDark);
    }
  }
}