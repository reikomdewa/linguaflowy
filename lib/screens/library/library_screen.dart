

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/screens/reader/reader_screen.dart';
import 'package:linguaflow/services/lesson_service.dart';

class LibraryScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = (context.watch<AuthBloc>().state as AuthAuthenticated).user;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('My Favorites'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: BlocBuilder<LessonBloc, LessonState>(
        builder: (context, state) {
          if (state is LessonInitial) {
            context.read<LessonBloc>().add(LessonLoadRequested(user.id, user.currentLanguage));
            return Center(child: CircularProgressIndicator());
          }
          if (state is LessonLoading) {
            return Center(child: CircularProgressIndicator());
          }
          if (state is LessonLoaded) {
            // FILTER: Only show favorites
            final favoriteLessons = state.lessons.where((l) => l.isFavorite == true).toList();

            if (favoriteLessons.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.star_border, size: 80, color: Colors.grey[300]),
                    SizedBox(height: 16),
                    Text(
                      'No favorites yet',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 8),
                    Text('Lessons created here are auto-favorited.'),
                  ],
                ),
              );
            }
            
            return ListView.separated(
              padding: EdgeInsets.all(16),
              itemCount: favoriteLessons.length,
              separatorBuilder: (context, index) => SizedBox(height: 16),
              itemBuilder: (context, index) {
                final lesson = favoriteLessons[index];
                
                // SWITCH based on type
                if (lesson.type == 'video' || lesson.videoUrl != null) {
                  return _buildVideoCard(context, lesson);
                } else {
                  return _buildTextCard(context, lesson);
                }
              },
            );
          }
          return Center(child: Text('Something went wrong'));
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showCreateLessonDialog(context, user.id, isFavoriteByDefault: true);
        },
        backgroundColor: Colors.blue,
        icon: Icon(Icons.add),
        label: Text('New Lesson'),
      ),
    );
  }

  // --- 1. VIDEO CARD (With Thumbnail) ---
  Widget _buildVideoCard(BuildContext context, LessonModel lesson) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ReaderScreen(lesson: lesson)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  child: Container(
                    height: 180,
                    width: double.infinity,
                    color: Colors.grey[200],
                    child: lesson.imageUrl != null
                        ? Image.network(lesson.imageUrl!, fit: BoxFit.cover)
                        : Icon(Icons.video_library, size: 50, color: Colors.grey[400]),
                  ),
                ),
                // Play Icon Overlay
                Positioned.fill(
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.play_arrow, color: Colors.white, size: 30),
                    ),
                  ),
                ),
                // Difficulty Badge
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      lesson.difficulty.toUpperCase(),
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            
            // Details Section
            Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.video_camera_back, size: 14, color: Colors.blue),
                      SizedBox(width: 4),
                      Text("Video Lesson", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Spacer(),
                      // You can add logic here to calculate % words known if you want
                      Icon(Icons.star, size: 16, color: Colors.amber),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 2. TEXT CARD ---
  Widget _buildTextCard(BuildContext context, LessonModel lesson) {
    return Card(
      elevation: 0,
      color: Colors.grey[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(12),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.article, color: Colors.amber[800]),
        ),
        title: Text(lesson.title, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          lesson.content.replaceAll('\n', ' '), 
          maxLines: 1, 
          overflow: TextOverflow.ellipsis
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReaderScreen(lesson: lesson),
            ),
          );
        },
      ),
    );
  }

  // Helper for manual creation
  void _showCreateLessonDialog(BuildContext context, String userId, {required bool isFavoriteByDefault}) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    String selectedLanguage = 'es'; // Default

    final lessonBloc = context.read<LessonBloc>();
    final lessonService = context.read<LessonService>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Import Text'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              // In a real app, use the user's current target language automatically
              DropdownButtonFormField<String>(
                value: selectedLanguage,
                decoration: InputDecoration(
                  labelText: 'Language',
                  border: OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(value: 'es', child: Text('Spanish')),
                  DropdownMenuItem(value: 'fr', child: Text('French')),
                  DropdownMenuItem(value: 'de', child: Text('German')),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                ],
                onChanged: (value) {
                  if (value != null) selectedLanguage = value;
                },
              ),
              SizedBox(height: 16),
              TextField(
                controller: contentController,
                decoration: InputDecoration(
                  labelText: 'Content',
                  border: OutlineInputBorder(),
                  hintText: 'Paste text here...',
                ),
                maxLines: 8,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty && contentController.text.isNotEmpty) {
                final sentences = lessonService.splitIntoSentences(contentController.text);

                final lesson = LessonModel(
                  id: '',
                  userId: userId,
                  title: titleController.text,
                  language: selectedLanguage,
                  content: contentController.text,
                  sentences: sentences,
                  createdAt: DateTime.now(),
                  progress: 0,
                  isFavorite: isFavoriteByDefault, 
                  type: 'text',
                );

                lessonBloc.add(LessonCreateRequested(lesson));
                Navigator.pop(dialogContext);
                
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text('Lesson imported successfully!')),
                );
              }
            },
            child: Text('Import'),
          ),
        ],
      ),
    );
  }
}