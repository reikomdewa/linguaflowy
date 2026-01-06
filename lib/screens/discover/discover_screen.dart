import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_state.dart';

// BLOCS
import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/vocabulary/vocabulary_bloc.dart';

// MODELS
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/vocabulary_item.dart';
import 'package:linguaflow/screens/community/community_screen.dart';

// WIDGETS
import 'package:linguaflow/screens/home/widgets/sections/genre_feed_section.dart';
import 'package:linguaflow/screens/home/widgets/tap_button.dart';
import 'package:linguaflow/widgets/category_video_section.dart';
import 'package:linguaflow/screens/discover/library_search_delegate.dart';

// SCREENS
import 'package:linguaflow/screens/discover/category_results_screen.dart';

// UTILS & CONSTANTS
import 'package:linguaflow/constants/genre_constants.dart';
import 'package:linguaflow/utils/language_helper.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Theme & Colors
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black;
    final chipColor = isDark ? const Color(0xFF2C2C2E) : Colors.grey[200];
    final searchBarColor = isDark ? const Color(0xFF1C1C1E) : Colors.grey[100];

    // 2. Get User Info (For Language Code)
    final authState = context.watch<AuthBloc>().state;
    String currentLangCode = 'en';
    if (authState is AuthAuthenticated) {
      currentLangCode = LanguageHelper.getLangCode(
        authState.user.currentLanguage,
      );
    }

    // 3. Get Vocabulary (For Cards)
    final vocabState = context.watch<VocabularyBloc>().state;
    Map<String, VocabularyItem> vocabMap = {};
    if (vocabState is VocabularyLoaded) {
      vocabMap = {
        for (var item in vocabState.items) item.word.toLowerCase(): item,
      };
    }

    // 4. Get Categories List
    final List<String> allUiCategories = GenreConstants.categoryMap.keys
        .toList();

    // RESPONSIVE CHECK: Is Desktop/Web or Mobile?
    final bool isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: BlocBuilder<LessonBloc, LessonState>(
          builder: (context, state) {
            // Get initial loaded lessons (for Trending section)
            List<LessonModel> loadedLessons = (state is LessonLoaded)
                ? state.lessons
                : [];

            // Filter locally loaded videos for "Trending"
            final trendingVideos = loadedLessons
                .where((l) => l.type == 'video' || l.type == 'video_native')
                .take(8)
                .toList();

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // --- A. SEARCH BAR ---
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickySearchBarDelegate(
                    isDark: isDark,
                    searchBarColor: searchBarColor!,
                    textColor: textColor,
                    onTap: () => _openSearch(context, isDark),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 5, 16, 5),
                    child: TabButton(
                      title: "Community",
                      icon: Icons.people,
                      destinationScreen:
                          CommunityScreen(), // The widget you want to go to
                    ),
                  ),
                ),
                // --- B. CHIPS HEADER ---
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

                // --- C. CHIPS GRID (Responsive) ---
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      // RESPONSIVE: 4 columns on Desktop, 2 on Mobile
                      crossAxisCount: isDesktop ? 4 : 2,
                      // RESPONSIVE: Taller chips on Desktop (using your nice design), wider on Mobile
                      childAspectRatio: isDesktop ? 4.5 : 3.5,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final uiCategory = allUiCategories[index];
                      final genreKey = GenreConstants.categoryMap[uiCategory];

                      return _buildMinimalistChip(
                        title: uiCategory,
                        bgColor: chipColor!,
                        textColor: textColor,
                        isDesktop: isDesktop,
                        onTap: () {
                          // Navigate using GENRE KEYS (Server Fetch)
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CategoryResultsScreen(
                                categoryTitle: uiCategory,
                                genreKey: genreKey,
                                languageCode: currentLangCode,
                              ),
                            ),
                          );
                        },
                      );
                    }, childCount: allUiCategories.length),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // --- D. TRENDING SECTION (From Local Bloc Data) ---
                if (trendingVideos.isNotEmpty)
                  SliverToBoxAdapter(
                    child: CategoryVideoSection(
                      title: "Trending Now",
                      lessons: trendingVideos,
                      onSeeAll: () {
                        // Navigate using STATIC LIST (Local Data)
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CategoryResultsScreen(
                              categoryTitle: "Trending Now",
                              initialLessons: trendingVideos,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                // --- E. DYNAMIC PAGINATED GENRES ---
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final uiCategory = allUiCategories[index];
                    final genreKey = GenreConstants.categoryMap[uiCategory]!;

                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: GenreFeedSection(
                        title: uiCategory,
                        genreKey: genreKey,
                        languageCode: currentLangCode,
                        vocabMap: vocabMap,
                        isDark: isDark,
                      ),
                    );
                  }, childCount: allUiCategories.length),
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
    required bool isDesktop,
  }) {
    // WEB/DESKTOP: Use the nice compact chip
    if (isDesktop && kIsWeb) {
      return _webChipContainer(bgColor, onTap, title, textColor);
    }
    // MOBILE: Use the original larger touch target
    else {
      return _chipContainer(bgColor, onTap, title, textColor);
    }
  }

  // Original Mobile Container
  Container _chipContainer(
    Color bgColor,
    VoidCallback onTap,
    String title,
    Color textColor,
  ) {
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

  // The Nice Web Container
  Widget _webChipContainer(
    Color bgColor,
    VoidCallback onTap,
    String title,
    Color textColor,
  ) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        height: 24, // Compact height for web
        constraints: const BoxConstraints(minWidth: 40),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12), // Pill shape
          border: Border.all(color: textColor.withOpacity(0.15), width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            hoverColor: textColor.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Center(
                widthFactor: 1.0,
                child: Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    letterSpacing: 0.2,
                    height: 1.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- STICKY SEARCH BAR DELEGATE ---
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
    // RESPONSIVE: Limit search bar width on Desktop
    final bool isDesktop = MediaQuery.of(context).size.width > 800;

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      alignment: Alignment.center,
      child: Center(
        // Center on desktop
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isDesktop ? 600 : double.infinity,
          ),
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
