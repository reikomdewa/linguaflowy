import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';
import 'package:linguaflow/screens/library/widgets/library_widgets.dart';
// Make sure to import the widgets file you just created

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = (context.watch<AuthBloc>().state as AuthAuthenticated).user;
    
    // THEME VARIABLES
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
      ),
      body: BlocBuilder<LessonBloc, LessonState>(
        builder: (context, state) {
          if (state is LessonInitial) {
            context
                .read<LessonBloc>()
                .add(LessonLoadRequested(user.id, user.currentLanguage));
            return const Center(child: CircularProgressIndicator());
          }
          if (state is LessonGenerationSuccess) {
             return const Center(child: CircularProgressIndicator());
          }
          if (state is LessonLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is LessonLoaded) {
            // --- FILTERING ---
            
            // 1. Imported Lessons (Local)
            final importedLessons = state.lessons.where((l) => l.isLocal).toList();
            
            // 2. Favorite Lessons (Cloud or System)
            // Note: Imported lessons can also be favorites, but if you want 
            // to show them ONLY in the top horizontal list, add "&& !l.isLocal" to this filter.
            // If you want them in both if favorited, leave as is.
            final favoriteLessons = state.lessons.where((l) => l.isFavorite).toList();

            if (importedLessons.isEmpty && favoriteLessons.isEmpty) {
              return _buildEmptyState();
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 80), // Space for FAB
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  
                  // --- SECTION 1: IMPORTED LESSONS (Horizontal) ---
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
                              color: textColor
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 230, // Fixed height for horizontal cards
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: importedLessons.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final lesson = importedLessons[index];
                          // Force a width for horizontal items
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

                  // --- SECTION 2: FAVORITES (Vertical) ---
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
                              color: textColor
                            ),
                          ),
                        ],
                      ),
                    ),
                    ListView.separated(
                      padding: const EdgeInsets.all(16),
                      shrinkWrap: true, // Vital for nesting in SingleChildScrollView
                      physics: const NeverScrollableScrollPhysics(), // Scroll handled by parent
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