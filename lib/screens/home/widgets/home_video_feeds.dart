import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/widgets/category_video_section.dart';
import 'package:linguaflow/screens/search/category_results_screen.dart';

// IMPORT THE NEW CONSTANTS FILE
import 'package:linguaflow/constants/genre_constants.dart'; 

class HomeVideoFeeds extends StatelessWidget {
  const HomeVideoFeeds({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LessonBloc, LessonState>(
      builder: (context, state) {
        if (state is LessonLoaded) {
          final allLessons = state.lessons;

          // --- HELPER: Filter Logic ---
          List<LessonModel> getByGenre(String genreKey) {
            return allLessons.where((l) {
              // Ensure it is a video
              if (l.type != 'video' && l.videoUrl == null) return false;

              final g = l.genre.toLowerCase();
              final t = l.title.toLowerCase();
              final k = genreKey.toLowerCase();
              
              // Match genre tag strictly OR title loosely if genre is generic
              return g.contains(k) || (g == 'general' && t.contains(k));
            }).toList();
          }

          // --- DYNAMIC SECTION GENERATION ---
          final List<Widget> sections = [];

          // Iterate using the shared GenreConstants map
          GenreConstants.categoryMap.forEach((displayTitle, genreKey) {
            final categoryVideos = getByGenre(genreKey);

            if (categoryVideos.isNotEmpty) {
              sections.add(
                _buildSection(context, displayTitle, categoryVideos)
              );
            }
          });

          return Column(
            children: sections,
          );
        }
        
        return const SizedBox.shrink(); 
      },
    );
  }

  // --- INTERNAL HELPER ---
  Widget _buildSection(BuildContext context, String title, List<LessonModel> lessons) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: CategoryVideoSection(
        title: title,
        lessons: lessons,
        onSeeAll: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CategoryResultsScreen(
                categoryTitle: title,
                lessons: lessons,
              ),
            ),
          );
        },
      ),
    );
  }
}