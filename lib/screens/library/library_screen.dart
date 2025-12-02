
// // File: lib/screens/library/library_screen.dart

// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:linguaflow/blocs/auth/auth_bloc.dart';
// import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';
// import 'package:linguaflow/models/lesson_model.dart';
// import 'package:linguaflow/models/user_model.dart';
// import 'package:linguaflow/screens/reader/reader_screen.dart';
// import 'package:linguaflow/services/lesson_service.dart';

// class LibraryScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     final user = (context.watch<AuthBloc>().state as AuthAuthenticated).user;

//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Library'),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.search),
//             onPressed: () {},
//           ),
//         ],
//       ),
//       body: BlocBuilder<LessonBloc, LessonState>(
//         builder: (context, state) {
//           if (state is LessonInitial) {
//             context.read<LessonBloc>().add(LessonLoadRequested(user.id));
//             return Center(child: CircularProgressIndicator());
//           }
//           if (state is LessonLoading) {
//             return Center(child: CircularProgressIndicator());
//           }
//           if (state is LessonLoaded) {
//             if (state.lessons.isEmpty) {
//               return Center(
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Icon(Icons.library_books, size: 100, color: Colors.grey[300]),
//                     SizedBox(height: 24),
//                     Text(
//                       'No lessons yet',
//                       style: TextStyle(fontSize: 20, color: Colors.grey[600]),
//                     ),
//                     SizedBox(height: 8),
//                     Text(
//                       'Create your first lesson to start learning',
//                       style: TextStyle(color: Colors.grey[500]),
//                     ),
//                   ],
//                 ),
//               );
//             }
//             return ListView.builder(
//               padding: EdgeInsets.all(16),
//               itemCount: state.lessons.length,
//               itemBuilder: (context, index) {
//                 final lesson = state.lessons[index];
//                 return Card(
//                   margin: EdgeInsets.only(bottom: 16),
//                   child: InkWell(
//                     onTap: () {
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (context) => ReaderScreen(lesson: lesson),
//                         ),
//                       );
//                     },
//                     child: Padding(
//                       padding: EdgeInsets.all(16),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Row(
//                             children: [
//                               Container(
//                                 padding: EdgeInsets.symmetric(
//                                   horizontal: 8,
//                                   vertical: 4,
//                                 ),
//                                 decoration: BoxDecoration(
//                                   color: Colors.blue,
//                                   borderRadius: BorderRadius.circular(4),
//                                 ),
//                                 child: Text(
//                                   lesson.language.toUpperCase(),
//                                   style: TextStyle(
//                                     color: Colors.white,
//                                     fontSize: 12,
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                 ),
//                               ),
//                               Spacer(),
//                               IconButton(
//                                 icon: Icon(Icons.delete_outline),
//                                 onPressed: () {
//                                   _showDeleteDialog(context, lesson.id);
//                                 },
//                               ),
//                             ],
//                           ),
//                           SizedBox(height: 8),
//                           Text(
//                             lesson.title,
//                             style: TextStyle(
//                               fontSize: 18,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                           SizedBox(height: 8),
//                           Text(
//                             lesson.content.length > 100
//                                 ? '${lesson.content.substring(0, 100)}...'
//                                 : lesson.content,
//                             style: TextStyle(color: Colors.grey[600]),
//                           ),
//                           SizedBox(height: 12),
//                           Row(
//                             children: [
//                               Icon(Icons.article, size: 16, color: Colors.grey),
//                               SizedBox(width: 4),
//                               Text(
//                                 '${lesson.sentences.length} sentences',
//                                 style: TextStyle(color: Colors.grey[600]),
//                               ),
//                               SizedBox(width: 16),
//                               Icon(Icons.access_time, size: 16, color: Colors.grey),
//                               SizedBox(width: 4),
//                               Text(
//                                 _formatDate(lesson.createdAt),
//                                 style: TextStyle(color: Colors.grey[600]),
//                               ),
//                             ],
//                           ),
//                           if (lesson.progress > 0) ...[
//                             SizedBox(height: 12),
//                             LinearProgressIndicator(
//                               value: lesson.progress / 100,
//                               backgroundColor: Colors.grey[200],
//                               valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
//                             ),
//                             SizedBox(height: 4),
//                             Text(
//                               '${lesson.progress}% complete',
//                               style: TextStyle(fontSize: 12, color: Colors.grey[600]),
//                             ),
//                           ],
//                         ],
//                       ),
//                     ),
//                   ),
//                 );
//               },
//             );
//           }
//           return Center(child: Text('Something went wrong'));
//         },
//       ),
//       floatingActionButton: FloatingActionButton.extended(
//         onPressed: () {
//           _showCreateLessonDialog(context, user.id);
//         },
//         icon: Icon(Icons.add),
//         label: Text('New Lesson'),
//       ),
//     );
//   }

//   String _formatDate(DateTime date) {
//     final now = DateTime.now();
//     final difference = now.difference(date);

//     if (difference.inDays == 0) {
//       return 'Today';
//     } else if (difference.inDays == 1) {
//       return 'Yesterday';
//     } else if (difference.inDays < 7) {
//       return '${difference.inDays} days ago';
//     } else {
//       return '${date.day}/${date.month}/${date.year}';
//     }
//   }

//   void _showDeleteDialog(BuildContext context, String lessonId) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Delete Lesson'),
//         content: Text('Are you sure you want to delete this lesson?'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Cancel'),
//           ),
//           TextButton(
//             onPressed: () {
//               context.read<LessonBloc>().add(LessonDeleteRequested(lessonId));
//               Navigator.pop(context);
//             },
//             child: Text('Delete', style: TextStyle(color: Colors.red)),
//           ),
//         ],
//       ),
//     );
//   }

//   void _showCreateLessonDialog(BuildContext context, String userId) {
//     final titleController = TextEditingController();
//     final contentController = TextEditingController();
//     String selectedLanguage = 'es';

//     showDialog(
//       context: context,
//       builder: (dialogContext) => AlertDialog(
//         title: Text('Create New Lesson'),
//         content: SingleChildScrollView(
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               TextField(
//                 controller: titleController,
//                 decoration: InputDecoration(
//                   labelText: 'Title',
//                   border: OutlineInputBorder(),
//                 ),
//               ),
//               SizedBox(height: 16),
//               DropdownButtonFormField<String>(
//                 value: selectedLanguage,
//                 decoration: InputDecoration(
//                   labelText: 'Language',
//                   border: OutlineInputBorder(),
//                 ),
//                 items: [
//                   DropdownMenuItem(value: 'es', child: Text('Spanish')),
//                   DropdownMenuItem(value: 'fr', child: Text('French')),
//                   DropdownMenuItem(value: 'de', child: Text('German')),
//                   DropdownMenuItem(value: 'it', child: Text('Italian')),
//                   DropdownMenuItem(value: 'pt', child: Text('Portuguese')),
//                   DropdownMenuItem(value: 'ja', child: Text('Japanese')),
//                   DropdownMenuItem(value: 'ko', child: Text('Korean')),
//                   DropdownMenuItem(value: 'zh', child: Text('Chinese')),
//                 ],
//                 onChanged: (value) {
//                   if (value != null) selectedLanguage = value;
//                 },
//               ),
//               SizedBox(height: 16),
//               TextField(
//                 controller: contentController,
//                 decoration: InputDecoration(
//                   labelText: 'Content',
//                   border: OutlineInputBorder(),
//                   hintText: 'Paste or type your text here...',
//                 ),
//                 maxLines: 8,
//               ),
//             ],
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(dialogContext),
//             child: Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               if (titleController.text.isNotEmpty &&
//                   contentController.text.isNotEmpty) {
//                 final lessonService = context.read<LessonService>();
//                 final sentences = lessonService.splitIntoSentences(
//                   contentController.text,
//                 );

//                 final lesson = LessonModel(
//                   id: '',
//                   userId: userId,
//                   title: titleController.text,
//                   language: selectedLanguage,
//                   content: contentController.text,
//                   sentences: sentences,
//                   createdAt: DateTime.now(),
//                 );

//                 context.read<LessonBloc>().add(LessonCreateRequested(lesson));
//                 Navigator.pop(dialogContext);
                
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(content: Text('Lesson created successfully!')),
//                 );
//               }
//             },
//             child: Text('Create'),
//           ),
//         ],
//       ),
//     );
//   }
// }


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
      appBar: AppBar(
        title: Text('My Favorites'),
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
            
            return ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: favoriteLessons.length,
              itemBuilder: (context, index) {
                final lesson = favoriteLessons[index];
                return _buildLibraryCard(context, lesson);
              },
            );
          }
          return Center(child: Text('Something went wrong'));
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Creating from Library: Auto favorite
          _showCreateLessonDialog(context, user.id, isFavoriteByDefault: true);
        },
        icon: Icon(Icons.add),
        label: Text('New Lesson'),
      ),
    );
  }

  Widget _buildLibraryCard(BuildContext context, LessonModel lesson) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundColor: Colors.amber.shade100,
          child: Icon(Icons.star, color: Colors.amber),
        ),
        title: Text(lesson.title, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          lesson.content.replaceAll('\n', ' '), 
          maxLines: 1, 
          overflow: TextOverflow.ellipsis
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16),
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

  // Duplicated create logic to allow different 'isFavoriteByDefault' behavior
  // In a real app, this should be a shared widget/mixin.
  void _showCreateLessonDialog(BuildContext context, String userId, {required bool isFavoriteByDefault}) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    String selectedLanguage = 'es';

    // Safe capture of providers
    final lessonBloc = context.read<LessonBloc>();
    final lessonService = context.read<LessonService>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isFavoriteByDefault ? 'Create Favorite Lesson' : 'Create New Lesson'),
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
                  hintText: 'Paste or type your text here...',
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
                  isFavorite: isFavoriteByDefault, // Logic applied here
                );

                lessonBloc.add(LessonCreateRequested(lesson));
                Navigator.pop(dialogContext);
                
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text('Lesson created successfully!')),
                );
              }
            },
            child: Text('Create'),
          ),
        ],
      ),
    );
  }
}
