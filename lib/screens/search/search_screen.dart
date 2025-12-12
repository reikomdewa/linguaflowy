import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Add this import
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/screens/library/widgets/cards/library_text_card.dart';
import 'package:linguaflow/screens/library/widgets/cards/library_video_card.dart';

import 'library_search.dart'; // The new search file

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
          // --- SEARCH BUTTON ---
          BlocBuilder<LessonBloc, LessonState>(
            builder: (context, state) {
              // Only enable search if lessons are loaded
              final bool isLoaded = state is LessonLoaded;

              return IconButton(
                // Use the specific icon requested
                icon: const FaIcon(FontAwesomeIcons.magnifyingGlass, size: 20),
                color: textColor,
                onPressed: isLoaded
                    ? () {
                        // Pass the current list of lessons to the search delegate
                        showSearch(
                          context: context,
                          delegate: LibrarySearchDelegate(
                            lessons: state.lessons,
                            isDark: isDark,
                          ),
                        );
                      }
                    : null, // Disable button if loading
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: BlocBuilder<LessonBloc, LessonState>(
        // ... (Rest of your body code remains exactly the same as previous step)
        builder: (context, state) {
          if (state is LessonInitial) {
            context.read<LessonBloc>().add(
              LessonLoadRequested(user.id, user.currentLanguage),
            );
            return const Center(child: CircularProgressIndicator());
          }
          // ... rest of your existing builders
          if (state is LessonLoaded) {
            // ... your list view logic
            // I'm omitting the body here for brevity since it was provided in the previous answer
            // Just make sure you don't delete your imported/favorite lists!
            return _buildLibraryContent(
              state.lessons,
              isDark,
              textColor,
              context,
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  // Helper just to keep the snippet above clean, paste your Body logic here
  Widget _buildLibraryContent(
    List<LessonModel> lessons,
    bool isDark,
    Color? textColor,
    BuildContext context,
  ) {
    // 1. Filter
    final importedLessons = lessons.where((l) => l.isLocal).toList();
    final favoriteLessons = lessons.where((l) => l.isFavorite).toList();

    if (importedLessons.isEmpty && favoriteLessons.isEmpty) {
      return _buildEmptyState();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Horizontal Imports
          if (importedLessons.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.download_for_offline, color: textColor, size: 20),
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
              height: 230,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: importedLessons.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final lesson = importedLessons[index];
                  const double cardWidth = 200;
                  if (lesson.type == 'video' || lesson.videoUrl != null) {
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
          // Vertical Favorites
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
                if (lesson.type == 'video' || lesson.videoUrl != null) {
                  return LibraryVideoCard(lesson: lesson, isDark: isDark);
                } else {
                  return LibraryTextCard(lesson: lesson, isDark: isDark);
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    // ... your empty state
    return Container();
  }
}
