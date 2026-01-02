import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';
import 'package:linguaflow/blocs/vocabulary/vocabulary_bloc.dart';
import 'package:linguaflow/models/vocabulary_item.dart';
import 'package:linguaflow/screens/home/utils/home_utils.dart';
import 'package:linguaflow/screens/home/widgets/home_dialogs.dart';
import 'package:linguaflow/screens/home/widgets/home_language_dialogs.dart';
import 'package:linguaflow/screens/home/widgets/tap_button.dart';
import 'package:linguaflow/screens/premium/premium_screen.dart';
import 'package:linguaflow/screens/reader/reader_screen.dart';
import 'package:linguaflow/screens/reader/reader_screen_web.dart';
import 'package:linguaflow/screens/discover/library_search_delegate.dart';
import 'package:linguaflow/utils/auth_guard.dart';
import 'package:linguaflow/utils/language_helper.dart';

PreferredSizeWidget buildAppBar(
  BuildContext context,
  dynamic user,
  bool isDark,
  Color? textColor,
  bool isDesktop, {
  // NEW PARAMETER: Pass the local guest language from HomeScreen
  String guestLanguage = 'English',
}) {
  // 1. Determine Guest Status
  final bool isGuest = user == null;
  final bool isPremium = !isGuest && (user.isPremium == true);

  // 2. Determine Language & Level
  // If guest, use the passed string. If user, use their profile data.
  final String currentLanguage = isGuest ? guestLanguage : user.currentLanguage;
  final String currentLevel = isGuest ? 'Beginner' : user.currentLevel;

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
        // Only calculate known count for logged-in users
        if (!isGuest && vocabState is VocabularyLoaded) {
          knownCount = vocabState.items
              .where((v) => v.status > 0 && v.language == currentLanguage)
              .length;
        }

        final levelStats = HomeDialogs.getLevelDetails(knownCount);
        final String displayLevel = knownCount > 0
            ? levelStats['fullLabel']
            : currentLevel;
        final int nextGoal = levelStats['nextGoal'];

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // --- FLAG ICON (LANGUAGE SELECTOR) ---
            GestureDetector(
              // FIX: Allow everyone (Guest & User) to open the selector
              onTap: () {
                AuthGuard.run(
                  context,
                  onAuthenticated: () {
                    HomeLanguageDialogs.showTargetLanguageSelector(context);
                  },
                );
              },
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
                  LanguageHelper.getFlagEmoji(currentLanguage),
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // --- LEVEL TEXT ---
            Flexible(
              child: InkWell(
                onTap: () => HomeLanguageDialogs.showLevelSelector(
                  context,
                  displayLevel,
                  currentLanguage,
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
                      isGuest
                          ? "Start learning"
                          : "$knownCount / $nextGoal words",
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

            // --- SEARCH BAR (Desktop) ---
            if (isDesktop) ...[
              BlocBuilder<LessonBloc, LessonState>(
                builder: (context, state) {
                  // Only show search if we have lessons loaded
                  if (state is! LessonLoaded) return const SizedBox();

                  final lessons = state.lessons;

                  return SizedBox(
                    width: 700,
                    height: 42,
                    child: SearchAnchor(
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
                      suggestionsBuilder:
                          (BuildContext context, SearchController controller) {
                            final keyword = controller.text.toLowerCase();
                            final results = lessons.where((lesson) {
                              return lesson.title.toLowerCase().contains(
                                    keyword,
                                  ) ||
                                  lesson.genre.toLowerCase().contains(keyword);
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
                                onTap: () {
                                  controller.closeView(lesson.title);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => kIsWeb
                                          ? ReaderScreenWeb(lesson: lesson)
                                          : ReaderScreen(lesson: lesson),
                                    ),
                                  );
                                },
                              );
                            });
                          },
                      viewBackgroundColor: isDark
                          ? const Color(0xFF1E1E1E)
                          : Colors.white,
                      dividerColor: isDark ? Colors.white10 : Colors.grey[200],
                      viewConstraints: const BoxConstraints(maxHeight: 400),
                    ),
                  );
                },
              ),
            ],
          ],
        );
      },
    ),

    // --- ACTIONS ---
    actions: [
      if (isDesktop)
        TabButton(
          title: "Personalized Story Lesson",
          icon: Icons.auto_awesome,
          onCustomTap: () => HomeUtils.showAIStoryGenerator(context),
        ),

      // Mobile Search Button
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

      // Stats Button
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
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: isDesktop ? 40 : 36,
            padding: isDesktop
                ? const EdgeInsets.symmetric(horizontal: 12)
                : const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_graph_rounded,
                  size: 20,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
                if (isDesktop) ...[
                  const SizedBox(width: 6),
                  Text(
                    "Stats",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),

      // Premium Button
      Padding(
        padding: const EdgeInsets.only(right: 12, top: 12, bottom: 12, left: 4),
        child: Center(
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PremiumScreen(isPremium: isPremium),
                ),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
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
                  Padding(
                    padding: const EdgeInsets.only(left: 2.0, right: 2),
                    child: Icon(
                      isPremium
                          ? Icons.workspace_premium_rounded
                          : Icons.lock_outline_rounded,
                      size: 18,
                      color: isPremium
                          ? const Color(0xFFFFA000)
                          : (isDark ? Colors.white70 : Colors.grey.shade600),
                    ),
                  ),
                  if (isPremium) ...[
                    if (isDesktop) const SizedBox(width: 6),
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
