import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/screens/search/library_search_delegate.dart';

// --- IMPORTS FOR REUSABLE WIDGETS ---
import 'package:linguaflow/widgets/category_video_section.dart';
import 'package:linguaflow/screens/search/category_results_screen.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black;
    final chipColor = isDark ? const Color(0xFF2C2C2E) : Colors.grey[200];
    final searchBarColor = isDark ? const Color(0xFF1C1C1E) : Colors.grey[100];

    // 1. MASTER LIST: All possible categories (Kept for future use)
    final Map<String, String> genreMap = {
      "History": "history",
      "Info": "news",
      "True Crime": "crime",
      "Fiction": "fiction",
      "Environment": "environment",
      "Learn & Revise": "education",
      "Grand Formats": "documentary",
      "Portraits": "biography",
      "Ideas": "philosophy",
      "Documentaries": "documentary",
      "Health": "health",
      "Daily Life": "vlog",
      "Cinema": "cinema",
      "Humor": "comedy",
      "Society": "society",
      "Knowledge+": "science",
      "Arts": "culture",
      "Vlogs & Escape": "travel",
      "Books": "literature",
      "Music": "music",
      "Science": "science",
      "Tech": "tech",
    };

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: BlocBuilder<LessonBloc, LessonState>(
          builder: (context, state) {
            List<LessonModel> allLessons = (state is LessonLoaded)
                ? state.lessons
                : [];
            
            // Get all videos
            final allVideos = allLessons
                .where((l) => l.type == 'video' || l.videoUrl != null)
                .toList();

            // 2. FILTER LOGIC: Only show chips that have matching videos
            // We iterate through the master list keys and keep only those that return results.
            final List<String> activeCategories = genreMap.keys.where((uiCategory) {
              final mappedGenre = genreMap[uiCategory]!;
              final matches = _filterLessons(allVideos, mappedGenre);
              return matches.isNotEmpty;
            }).toList();

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Search Bar
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickySearchBarDelegate(
                    isDark: isDark,
                    searchBarColor: searchBarColor!,
                    textColor: textColor,
                    onTap: () => _openSearch(context, isDark),
                  ),
                ),

                // "Browse Categories" Header
                if (activeCategories.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 5, 16, 5),
                      child: Text(
                        "Browse Categories",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),

                // 3. CHIP GRID: Now uses 'activeCategories' instead of the full list
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 3.5,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final uiCategory = activeCategories[index];
                      return _buildMinimalistChip(
                        title: uiCategory,
                        bgColor: chipColor!,
                        textColor: textColor,
                        onTap: () => _navigateToCategory(
                          context,
                          uiCategory,
                          genreMap[uiCategory]!,
                          allVideos,
                        ),
                      );
                    }, childCount: activeCategories.length),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // --- 1. TRENDING SECTION ---
                if (allVideos.isNotEmpty)
                  SliverToBoxAdapter(
                    child: CategoryVideoSection(
                      title: "Trending Now",
                      lessons: allVideos.take(8).toList(),
                      onSeeAll: () =>
                          _navigateToScreen(context, "Trending Now", allVideos),
                    ),
                  ),

                // --- 2. DYNAMIC CATEGORIES (Vertical List) ---
                // We also use 'activeCategories' here so the order matches the chips
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final uiCategory = activeCategories[index];
                    final categoryLessons = _filterLessons(
                      allVideos,
                      genreMap[uiCategory]!,
                    );

                    // (Double check, though activeCategories logic ensures this is not empty)
                    if (categoryLessons.isEmpty) return const SizedBox.shrink();

                    return Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: CategoryVideoSection(
                        title: uiCategory,
                        lessons: categoryLessons,
                        onSeeAll: () => _navigateToScreen(
                          context,
                          uiCategory,
                          categoryLessons,
                        ),
                      ),
                    );
                  }, childCount: activeCategories.length),
                ),
                
                // Show a friendly message if everything is empty
                if (allVideos.isEmpty)
                   SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Center(child: Text("No videos found.", style: TextStyle(color: Colors.grey))),
                    ),
                   ),

                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            );
          },
        ),
      ),
    );
  }

  // --- HELPERS ---

  List<LessonModel> _filterLessons(
    List<LessonModel> videos,
    String mappedGenre,
  ) {
    return videos.where((l) {
      final g = l.genre.toLowerCase();
      final t = l.title.toLowerCase();
      final k = mappedGenre.toLowerCase();
      // Strict genre match OR loose title match
      return g.contains(k) || (g == 'general' && t.contains(k));
    }).toList();
  }

  void _navigateToCategory(
    BuildContext context,
    String uiCategory,
    String mappedGenre,
    List<LessonModel> allVideos,
  ) {
    final filtered = _filterLessons(allVideos, mappedGenre);
    _navigateToScreen(context, uiCategory, filtered);
  }

  void _navigateToScreen(
    BuildContext context,
    String title,
    List<LessonModel> lessons,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CategoryResultsScreen(categoryTitle: title, lessons: lessons),
      ),
    );
  }

  void _openSearch(BuildContext context, bool isDark) {
    final state = context.read<LessonBloc>().state;
    if (state is LessonLoaded) {
      showSearch(
        context: context,
        delegate: LibrarySearchDelegate(lessons: state.lessons, isDark: isDark),
      );
    }
  }

  Widget _buildMinimalistChip({
    required String title,
    required Color bgColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ... _StickySearchBarDelegate (keep as is)
class _StickySearchBarDelegate extends SliverPersistentHeaderDelegate {
  final bool isDark;
  final Color searchBarColor;
  final Color textColor;
  final VoidCallback onTap;

  _StickySearchBarDelegate({
    required this.isDark,
    required this.searchBarColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 45,
          decoration: BoxDecoration(
            color: searchBarColor,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(
                FontAwesomeIcons.magnifyingGlass,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
                size: 16,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Podcasts, episodes, topics...",
                  style: TextStyle(
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  double get maxExtent => 65;
  @override
  double get minExtent => 65;
  @override
  bool shouldRebuild(covariant _StickySearchBarDelegate oldDelegate) =>
      oldDelegate.isDark != isDark;
}