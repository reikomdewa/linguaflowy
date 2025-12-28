import 'package:flutter/material.dart';
import 'package:linguaflow/models/community_models.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/user_model.dart';
import 'package:linguaflow/services/community_service.dart';
import 'package:linguaflow/screens/community/widgets/community_lesson_card.dart';
import 'package:linguaflow/screens/community/widgets/forum_post_card.dart';

class CommunitySearchDelegate extends SearchDelegate {
  final UserModel currentUser;
  final CommunityService service;

  CommunitySearchDelegate({required this.currentUser, required this.service});

  @override
  ThemeData appBarTheme(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Theme.of(context).copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: isDark ? Colors.grey : Colors.grey[600]),
        border: InputBorder.none,
      ),
      textTheme: TextTheme(
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
          onPressed: () => query = '',
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
    if (query.trim().isEmpty) {
      return const Center(child: Text("Type to search..."));
    }

    // Use a Tabbed view for results
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: const TabBar(
              labelColor: Colors.blueAccent,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blueAccent,
              tabs: [
                Tab(text: "Lessons"),
                Tab(text: "Forum Posts"),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildLessonResults(context),
                _buildForumResults(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    // Optional: Show recent searches or popular tags here
    if (query.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            const Text("Search for community lessons or questions", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    // Show results as suggestions for instant feedback
    return buildResults(context); 
  }

  Widget _buildLessonResults(BuildContext context) {
    return StreamBuilder<List<LessonModel>>(
      stream: service.searchPublicLessons(query, currentUser.currentLanguage),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmpty("No lessons found matching '$query'");
        }

        final lessons = snapshot.data!;
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: lessons.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            return CommunityLessonCard(
              lesson: lessons[index],
              currentUser: currentUser,
              service: service,
            );
          },
        );
      },
    );
  }

  Widget _buildForumResults(BuildContext context) {
    return StreamBuilder<List<ForumPost>>(
      stream: service.searchForumPosts(query, currentUser.currentLanguage),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmpty("No posts found matching '$query'");
        }

        final posts = snapshot.data!;
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: posts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            return ForumPostCard(
              post: posts[index],
              currentUser: currentUser,
              service: service,
            );
          },
        );
      },
    );
  }

  Widget _buildEmpty(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Text(text, style: const TextStyle(color: Colors.grey)),
      ),
    );
  }
}