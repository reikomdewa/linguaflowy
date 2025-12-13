import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';
import 'package:linguaflow/screens/library/widgets/dialogs/library_actions.dart';
import 'package:linguaflow/screens/library/widgets/cards/library_text_card.dart';
import 'package:linguaflow/screens/library/widgets/cards/library_video_card.dart';
import 'package:linguaflow/screens/search/library_search_delegate.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = (context.watch<AuthBloc>().state as AuthAuthenticated).user;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('My Library'),
        backgroundColor: bgColor,
        elevation: 0,
        foregroundColor: textColor,
        actions: [
          // --- UPDATED SEARCH BUTTON (MATCHING SCREENSHOT) ---
          BlocBuilder<LessonBloc, LessonState>(
            builder: (context, state) {
              final bool isLoaded = state is LessonLoaded;

              return Padding(
                padding: const EdgeInsets.only(right: 16.0), // Margin from edge
                child: Center(
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
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        // Glassy background style
                        color: isDark
                            ? Colors.white.withOpacity(0.1)
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
                ),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<LessonBloc, LessonState>(
        builder: (context, state) {
          if (state is LessonInitial) {
            context.read<LessonBloc>().add(
              LessonLoadRequested(user.id, user.currentLanguage),
            );
            return const Center(child: CircularProgressIndicator());
          }
          if (state is LessonLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is LessonLoaded) {
            final importedLessons = state.lessons
                .where((l) => l.isLocal)
                .toList();
            final favoriteLessons = state.lessons
                .where((l) => l.isFavorite)
                .toList();

            if (importedLessons.isEmpty && favoriteLessons.isEmpty) {
              return _buildEmptyState();
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- IMPORTED (Horizontal) ---
                  if (importedLessons.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.download_for_offline,
                            color: textColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Imported",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 240,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        scrollDirection: Axis.horizontal,
                        itemCount: importedLessons.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final lesson = importedLessons[index];
                          const double cardWidth = 220;

                          if (lesson.type == 'video' ||
                              (lesson.videoUrl != null &&
                                  lesson.videoUrl!.isNotEmpty)) {
                            return LibraryVideoCard(
                              lesson: lesson,
                              isDark: isDark,
                              width: cardWidth,
                            );
                          } else {
                            return LibraryTextCard(
                              lesson: lesson,
                              isDark: isDark,
                              width: cardWidth,
                            );
                          }
                        },
                      ),
                    ),
                  ],

                  // --- FAVORITES (Vertical) ---
                  if (favoriteLessons.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                      child: Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber[700], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            "Favorites",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ListView.separated(
                      padding: const EdgeInsets.all(16),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: favoriteLessons.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final lesson = favoriteLessons[index];
                        if (lesson.type == 'video' ||
                            (lesson.videoUrl != null &&
                                lesson.videoUrl!.isNotEmpty)) {
                          return LibraryVideoCard(
                            lesson: lesson,
                            isDark: isDark,
                          );
                        } else {
                          return LibraryTextCard(
                            lesson: lesson,
                            isDark: isDark,
                          );
                        }
                      },
                    ),
                  ],
                ],
              ),
            );
          }
          return const Center(child: Text('Something went wrong'));
        },
      ),

      // --- FAB ---
      floatingActionButton: Material(
        color: Colors.transparent,
        elevation: 10,
        shadowColor: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          onTap: () {
            showCreateLessonDialog(
              context,
              user.id,
              user.currentLanguage,
              isFavoriteByDefault: true,
            );
          },
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF2C2C2C).withOpacity(0.9)
                  : const Color(0xFF1E1E1E).withOpacity(0.9),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
                width: 1,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, color: Colors.white, size: 22),
                SizedBox(width: 8),
                Text(
                  'Import to library',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_stories, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Library is empty',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          const Text(
            'Import texts or favorite lessons to see them here.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
