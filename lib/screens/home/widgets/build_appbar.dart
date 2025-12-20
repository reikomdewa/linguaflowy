
  // --- APP BAR ---
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
import 'package:linguaflow/screens/search/library_search_delegate.dart';
import 'package:linguaflow/utils/language_helper.dart';
import 'package:linguaflow/widgets/premium_lock_dialog.dart';

PreferredSizeWidget buildAppBar(
    BuildContext context,
    dynamic user,
    bool isDark,
    Color? textColor,
  ) {
    final bool isPremium = user.isPremium;

    return AppBar(
      elevation: 0,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      foregroundColor: textColor,
      toolbarHeight: 70,
      title: BlocBuilder<VocabularyBloc, VocabularyState>(
        builder: (context, vocabState) {
          int knownCount = 0;
          if (vocabState is VocabularyLoaded) {
            knownCount = vocabState.items
                .where(
                  (v) => v.status > 0 && v.language == user.currentLanguage,
                )
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
              Expanded(
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
                        children: [
                          Flexible(
                            child: Text(
                              displayLevel,
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
                            color: isDark
                                ? Colors.white54
                                : Colors.grey.shade600,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
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
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      actions: [
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
                  width: 35,
                  height: 35,
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
        InkWell(
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
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.auto_graph_rounded,
              size: 20,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(
            right: 16,
            top: 12,
            bottom: 12,
            left: 6,
          ),
          child: Center(
            child: InkWell(
              onTap: () {
                if (!isPremium) {
                  showDialog(
                    context: context,
                    builder: (context) => const PremiumLockDialog(),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
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
                      const SizedBox(width: 4),
                      // Text(
                      //   "PRO",
                      //   style: TextStyle(
                      //     fontWeight: FontWeight.w900,
                      //     color: const Color(0xFFFFA000),
                      //     fontSize: 12,
                      //     letterSpacing: 0.5,
                      //   ),
                      // ),
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