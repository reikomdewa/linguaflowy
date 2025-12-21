import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_event.dart';
import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';
import 'package:linguaflow/blocs/vocabulary/vocabulary_bloc.dart';
import 'package:linguaflow/models/vocabulary_item.dart';
import 'package:linguaflow/screens/home/widgets/home_dialogs.dart';
import 'package:linguaflow/screens/home/widgets/home_language_dialogs.dart';
import 'package:linguaflow/screens/reader/reader_screen.dart'; // Import Reader
import 'package:linguaflow/screens/reader/reader_screen_web.dart';
import 'package:linguaflow/screens/search/library_search_delegate.dart';
import 'package:linguaflow/utils/centered_views.dart';
import 'package:linguaflow/utils/language_helper.dart';
import 'package:linguaflow/widgets/buttons/build_ai_button.dart';
import 'package:linguaflow/widgets/premium_lock_dialog.dart';

PreferredSizeWidget buildAppBar(
  BuildContext context,
  dynamic user,
  bool isDark,
  Color? textColor,
  bool isDesktop,
) {
  final bool isPremium = user.isPremium;

  return AppBar(
    scrolledUnderElevation: 0,
    elevation: 0,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    foregroundColor: textColor,
    toolbarHeight: 70,

    // --- TITLE SECTION (Flag + Level) ---
    title: BlocBuilder<VocabularyBloc, VocabularyState>(
      builder: (context, vocabState) {
        int knownCount = 0;
        if (vocabState is VocabularyLoaded) {
          knownCount = vocabState.items
              .where((v) => v.status > 0 && v.language == user.currentLanguage)
              .length;
        }
        final levelStats = HomeDialogs.getLevelDetails(knownCount);
        final String displayLevel = knownCount > 0
            ? levelStats['fullLabel']
            : user.currentLevel;
        final int nextGoal = levelStats['nextGoal'];

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Flag Icon
            GestureDetector(
              onTap: () =>
                  HomeLanguageDialogs.showTargetLanguageSelector(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.grey.shade300,
                    width: 2,
                  ),
                  color: isDark ? Colors.black26 : Colors.white,
                ),
                alignment: Alignment.center,
                child: Text(
                  LanguageHelper.getFlagEmoji(user.currentLanguage),
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Level Text
            Flexible(
              child: InkWell(
                onTap: () => HomeLanguageDialogs.showLevelSelector(
                  context,
                  displayLevel,
                  user.currentLanguage,
                ),
                borderRadius: BorderRadius.circular(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            displayLevel,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: isDark ? Colors.white54 : Colors.grey.shade600,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "$knownCount / $nextGoal words",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // --- SPACER & SEARCH BAR (Moved nside Title Row for centering alignment) ---
            if (isDesktop) ...[
              BlocBuilder<LessonBloc, LessonState>(
                builder: (context, state) {
                  final isLoaded = state is LessonLoaded;

                  // If not loaded, show a disabled placeholder
                  if (!isLoaded) return const SizedBox();

                  final lessons = state.lessons;

                  // SEARCH ANCHOR: The modern "Type here to search" widget
                  return SizedBox(
                    width: isDesktop ? 700 : 180, // Control width
                    height: 42,
                    child: SearchAnchor(
                      // 1. Configure the "Bar" (The input field)
                      builder:
                          (BuildContext context, SearchController controller) {
                            return SearchBar(
                              controller: controller,
                              padding:
                                  const MaterialStatePropertyAll<EdgeInsets>(
                                    EdgeInsets.symmetric(horizontal: 16.0),
                                  ),
                              onTap: () => controller.openView(),
                              onChanged: (_) => controller.openView(),
                              leading: FaIcon(
                                FontAwesomeIcons.magnifyingGlass,
                                size: 15,
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                              hintText: 'Search library...',
                              hintStyle: MaterialStatePropertyAll(
                                TextStyle(
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black45,
                                  fontSize: 14,
                                ),
                              ),
                              // YouTube Style Styling
                              backgroundColor: MaterialStatePropertyAll(
                                isDark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : Colors.grey.shade200,
                              ),
                              elevation: const MaterialStatePropertyAll(0),
                              shape: MaterialStatePropertyAll(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                  side: BorderSide(
                                    color: isDark
                                        ? Colors.white10
                                        : Colors.transparent,
                                  ),
                                ),
                              ),
                              textStyle: MaterialStatePropertyAll(
                                TextStyle(
                                  color: isDark ? Colors.white : Colors.black,
                                  fontSize: 14,
                                ),
                              ),
                            );
                          },

                      // 2. Configure the "View" (The dropdown results)
                      suggestionsBuilder:
                          (BuildContext context, SearchController controller) {
                            final keyword = controller.text.toLowerCase();

                            // Filter Logic (Same as your Delegate)
                            final results = lessons.where((lesson) {
                              final title = lesson.title.toLowerCase();
                              final genre = lesson.genre.toLowerCase();
                              return title.contains(keyword) ||
                                  genre.contains(keyword);
                            }).toList();

                            return results.map((lesson) {
                              return ListTile(
                                leading: Icon(
                                  lesson.type == 'video'
                                      ? Icons.play_circle_outline
                                      : Icons.book_outlined,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                                title: Text(
                                  lesson.title,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  lesson.genre,
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.grey
                                        : Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                                onTap: () {
                                  // Close search and navigate
                                  controller.closeView(lesson.title);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          kIsWeb? ReaderScreenWeb(lesson: lesson) : ReaderScreen(lesson: lesson),
                                    ),
                                  );
                                },
                              );
                            });
                          },
                      // Style the Dropdown View
                      viewBackgroundColor: isDark
                          ? const Color(0xFF1E1E1E)
                          : Colors.white,
                      dividerColor: isDark ? Colors.white10 : Colors.grey[200],
                      viewConstraints: const BoxConstraints(
                        maxHeight: 400, // Limit dropdown height
                      ),
                    ),
                  );
                },
              ),
            ],

            // This is the Search Bar Area
          ],
        );
      },
    ),

    // --- ACTIONS (Stats, Premium, AI) ---
    actions: [
      if (isDesktop) buildAIStoryButton(context, isDark),
      if (!isDesktop)
        BlocBuilder<LessonBloc, LessonState>(
          builder: (context, state) {
            final isLoaded = state is LessonLoaded;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: InkWell(
                onTap: isLoaded
                    ? () {
                        showSearch(
                          context: context,
                          delegate: LibrarySearchDelegate(
                            lessons: state.lessons,
                            isDark: isDark,
                          ),
                        );
                      }
                    : null,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: FaIcon(
                    FontAwesomeIcons.magnifyingGlass,
                    size: 18,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
            );
          },
        ),
      // --- STATS BUTTON ---
      Padding(
        padding: isDesktop
            ? const EdgeInsets.only(right: 8.0, left: 8.0)
            : const EdgeInsets.only(right: 4.0, left: 4.0),
        child: InkWell(
          onTap: () {
            final vocabState = context.read<VocabularyBloc>().state;
            List<VocabularyItem> allItems = [];
            if (vocabState is VocabularyLoaded) {
              allItems = vocabState.items;
            }
            HomeDialogs.showStatsDialog(
              context,
              user,
              allItems,
              LanguageHelper.availableLanguages,
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: isDesktop ? 40 : 36,
            padding: isDesktop
                ? const EdgeInsets.symmetric(horizontal: 12)
                : const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_graph_rounded,
                  size: 20,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
                const SizedBox(width: 6),
                if (isDesktop)
                  Text(
                    "Stats",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),

      // --- PRO / PREMIUM BUTTON ---
      Padding(
        padding: const EdgeInsets.only(right: 16, top: 12, bottom: 12, left: 4),
        child: Center(
          child: InkWell(
            onTap: () {
              if (!isPremium) {
                showDialog(
                  context: context,
                  builder: (context) => LayoutBuilder(
                    builder: (context, constraints) {
                      bool isDesktop = constraints.maxWidth > 600;
                      return isDesktop
                          ? CenteredView(
                              horizontalPadding: 500,
                              child:  PremiumLockDialog(
                                    onClose: () {},
                              ),
                            )
                          :  PremiumLockDialog(    onClose: () {},);
                    },
                  ),
                ).then((unlocked) {
                  if (unlocked == true && context.mounted) {
                    context.read<AuthBloc>().add(AuthCheckRequested());
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Welcome to Premium!"),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                });
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "You are a PRO member!",
                      style: TextStyle(color: Colors.white),
                    ),
                    backgroundColor: Colors.amber,
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: isDesktop
                  ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
                  : const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: isPremium
                    ? const Color(0xFFFFC107).withValues(alpha: 0.15)
                    : (isDark ? Colors.white10 : Colors.grey.shade100),
                border: Border.all(
                  color: isPremium
                      ? const Color(0xFFFFC107)
                      : Colors.grey.shade400,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPremium
                        ? Icons.workspace_premium_rounded
                        : Icons.lock_outline_rounded,
                    size: 18,
                    color: isPremium
                        ? const Color(0xFFFFA000)
                        : (isDark ? Colors.white70 : Colors.grey.shade600),
                  ),
                  if (isPremium) ...[
                    const SizedBox(width: 6),
                    if (isDesktop)
                      const Text(
                        "PRO",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFFA000),
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
