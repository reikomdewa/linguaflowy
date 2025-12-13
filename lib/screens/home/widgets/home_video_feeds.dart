import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/widgets/category_video_section.dart';
import 'package:linguaflow/screens/search/category_results_screen.dart';

class HomeVideoFeeds extends StatelessWidget {
  const HomeVideoFeeds({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LessonBloc, LessonState>(
      builder: (context, state) {
        if (state is LessonLoaded) {
          final allLessons = state.lessons;

          // --- HELPER: Filter Logic (Matches SearchScreen logic) ---
          List<LessonModel> getByGenre(String genreKey) {
            return allLessons.where((l) {
              // Ensure it is a video
              if (l.type != 'video' && l.videoUrl == null) return false;

              final g = l.genre.toLowerCase();
              final t = l.title.toLowerCase();
              final k = genreKey.toLowerCase();
              
              // Match genre tag OR title keyword
              return g.contains(k) || (g == 'general' && t.contains(k));
            }).toList();
          }

          // --- DEFINE YOUR HOME SECTIONS HERE ---
          final scienceVideos = getByGenre('science');
          final historyVideos = getByGenre('history');
          final newsVideos = getByGenre('news');
          final vlogVideos = getByGenre('vlog');

          // Return a Column so it fits inside your Home ListView
          return Column(
            children: [
              if (scienceVideos.isNotEmpty)
                _buildSection(context, "Science Picks", scienceVideos),
              
              if (historyVideos.isNotEmpty)
                _buildSection(context, "Historical Gems", historyVideos),
              
              if (newsVideos.isNotEmpty)
                _buildSection(context, "News & Society", newsVideos),

              if (vlogVideos.isNotEmpty)
                _buildSection(context, "Daily Life Vlogs", vlogVideos),
            ],
          );
        }
        
        // Return empty while loading (Home usually has its own global loader)
        return const SizedBox.shrink(); 
      },
    );
  }

  // --- INTERNAL HELPER TO REDUCE CODE DUPLICATION ---
  Widget _buildSection(BuildContext context, String title, List<LessonModel> lessons) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0), // Spacing between sections
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