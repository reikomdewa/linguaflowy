
// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:linguaflow/blocs/auth/auth_bloc.dart';
// import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';
// import 'package:linguaflow/models/lesson_model.dart';
// import 'package:linguaflow/screens/reader/reader_screen.dart';
// import 'package:linguaflow/services/lesson_service.dart';

// class LibraryScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     final user = (context.watch<AuthBloc>().state as AuthAuthenticated).user;

//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         title: Text('My Favorites'),
//         backgroundColor: Colors.white,
//         elevation: 0,
//         foregroundColor: Colors.black,
//       ),
//       body: BlocBuilder<LessonBloc, LessonState>(
//         builder: (context, state) {
//           if (state is LessonInitial) {
//             context
//                 .read<LessonBloc>()
//                 .add(LessonLoadRequested(user.id, user.currentLanguage));
//             return Center(child: CircularProgressIndicator());
//           }
//           if (state is LessonLoading) {
//             return Center(child: CircularProgressIndicator());
//           }
//           if (state is LessonLoaded) {
//             // FILTER: Only show favorites
//             final favoriteLessons =
//                 state.lessons.where((l) => l.isFavorite == true).toList();

//             if (favoriteLessons.isEmpty) {
//               return Center(
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Icon(Icons.star_border, size: 80, color: Colors.grey[300]),
//                     SizedBox(height: 16),
//                     Text(
//                       'No favorites yet',
//                       style: TextStyle(fontSize: 18, color: Colors.grey[600]),
//                     ),
//                     SizedBox(height: 8),
//                     Text('Lessons created here are auto-favorited.'),
//                   ],
//                 ),
//               );
//             }

//             return ListView.separated(
//               padding: EdgeInsets.all(16),
//               itemCount: favoriteLessons.length,
//               separatorBuilder: (context, index) => SizedBox(height: 16),
//               itemBuilder: (context, index) {
//                 final lesson = favoriteLessons[index];

//                 // SWITCH based on type
//                 if (lesson.type == 'video' || lesson.videoUrl != null) {
//                   return _buildVideoCard(context, lesson);
//                 } else {
//                   return _buildTextCard(context, lesson);
//                 }
//               },
//             );
//           }
//           return Center(child: Text('Something went wrong'));
//         },
//       ),
//       // --- CUSTOM DARK GLASSY BUTTON ---
//       floatingActionButton: Material(
//         color: Colors.transparent,
//         elevation: 10,
//         shadowColor: Colors.black.withOpacity(0.3),
//         borderRadius: BorderRadius.circular(30),
//         child: InkWell(
//           onTap: () {
//             // PASSED user.currentLanguage here
//             _showCreateLessonDialog(
//               context,
//               user.id,
//               user.currentLanguage,
//               isFavoriteByDefault: true,
//             );
//           },
//           borderRadius: BorderRadius.circular(30),
//           child: Container(
//             padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
//             decoration: BoxDecoration(
//               // The "Glassy" Dark Color
//               color: const Color(0xFF1E1E1E).withOpacity(0.90),
//               borderRadius: BorderRadius.circular(30),
//               // The "Glass" Edge Highlight
//               border: Border.all(
//                 color: Colors.white.withOpacity(0.15),
//                 width: 1,
//               ),
//             ),
//             child: Row(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Icon(Icons.add_rounded, color: Colors.white, size: 22),
//                 SizedBox(width: 8),
//                 Text(
//                   'Import to library',
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 15,
//                     fontWeight: FontWeight.w600,
//                     letterSpacing: 0.5,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   // --- 1. MENU DIALOG ---
//   void _showLessonOptions(BuildContext context, LessonModel lesson) {
//     showModalBottomSheet(
//       context: context,
//       backgroundColor: Colors.transparent,
//       isScrollControlled: true,
//       builder: (builderContext) => Container(
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//         ),
//         padding: EdgeInsets.only(
//           top: 20,
//           left: 0,
//           right: 0,
//           bottom: MediaQuery.of(builderContext).viewPadding.bottom + 20,
//         ),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Center(
//               child: Container(
//                 width: 40,
//                 height: 4,
//                 margin: EdgeInsets.only(bottom: 20),
//                 decoration: BoxDecoration(
//                   color: Colors.grey[300],
//                   borderRadius: BorderRadius.circular(2),
//                 ),
//               ),
//             ),
//             ListTile(
//               leading: Container(
//                 padding: EdgeInsets.all(8),
//                 decoration: BoxDecoration(
//                   color:
//                       lesson.isFavorite ? Colors.amber[50] : Colors.grey[100],
//                   shape: BoxShape.circle,
//                 ),
//                 child: Icon(
//                   lesson.isFavorite ? Icons.star : Icons.star_border,
//                   color: lesson.isFavorite ? Colors.amber : Colors.grey,
//                 ),
//               ),
//               title: Text(
//                 lesson.isFavorite
//                     ? 'Remove from Favorites'
//                     : 'Add to Favorites',
//                 style: TextStyle(fontWeight: FontWeight.bold),
//               ),
//               subtitle: Text(
//                 lesson.isFavorite
//                     ? 'This lesson will be removed from your library.'
//                     : 'Save this lesson to your library.',
//               ),
//               onTap: () {
//                 final user =
//                     (context.read<AuthBloc>().state as AuthAuthenticated).user;

//                 // Toggle Favorite
//                 final updatedLesson = lesson.copyWith(
//                   isFavorite: !lesson.isFavorite,
//                   userId: user.id, // Ensure ownership
//                 );

//                 context.read<LessonBloc>().add(
//                       LessonUpdateRequested(updatedLesson),
//                     );

//                 Navigator.pop(builderContext);

//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(
//                     content: Text(
//                       updatedLesson.isFavorite
//                           ? "Added to favorites"
//                           : "Removed from favorites",
//                     ),
//                     duration: Duration(seconds: 1),
//                   ),
//                 );
//               },
//             ),
//             Divider(),
//             ListTile(
//               leading: Container(
//                 padding: EdgeInsets.all(8),
//                 decoration: BoxDecoration(
//                   color: Colors.red[50],
//                   shape: BoxShape.circle,
//                 ),
//                 child: Icon(Icons.delete_outline, color: Colors.red),
//               ),
//               title: Text('Delete Lesson', style: TextStyle(color: Colors.red)),
//               onTap: () {
//                 context
//                     .read<LessonBloc>()
//                     .add(LessonDeleteRequested(lesson.id));
//                 Navigator.pop(builderContext);
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // --- 2. VIDEO CARD ---
//   Widget _buildVideoCard(BuildContext context, LessonModel lesson) {
//     return GestureDetector(
//       onTap: () {
//         Navigator.push(
//           context,
//           MaterialPageRoute(builder: (context) => ReaderScreen(lesson: lesson)),
//         );
//       },
//       child: Container(
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(12),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(0.05),
//               blurRadius: 10,
//               offset: Offset(0, 4),
//             ),
//           ],
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Image Section
//             Stack(
//               children: [
//                 ClipRRect(
//                   borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
//                   child: Container(
//                     height: 180,
//                     width: double.infinity,
//                     color: Colors.grey[200],
//                     child: lesson.imageUrl != null
//                         ? Image.network(lesson.imageUrl!, fit: BoxFit.cover)
//                         : Icon(
//                             Icons.video_library,
//                             size: 50,
//                             color: Colors.grey[400],
//                           ),
//                   ),
//                 ),
//                 // Play Icon Overlay
//                 Positioned.fill(
//                   child: Center(
//                     child: Container(
//                       padding: EdgeInsets.all(12),
//                       decoration: BoxDecoration(
//                         color: Colors.black.withOpacity(0.5),
//                         shape: BoxShape.circle,
//                       ),
//                       child: Icon(
//                         Icons.play_arrow,
//                         color: Colors.white,
//                         size: 30,
//                       ),
//                     ),
//                   ),
//                 ),
//                 // Difficulty Badge
//                 Positioned(
//                   top: 10,
//                   left: 10,
//                   child: Container(
//                     padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                     decoration: BoxDecoration(
//                       color: Colors.black.withOpacity(0.7),
//                       borderRadius: BorderRadius.circular(4),
//                     ),
//                     child: Text(
//                       lesson.difficulty.toUpperCase(),
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 10,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ),

//             // Details Section
//             Padding(
//               padding: EdgeInsets.all(12),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Row(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Expanded(
//                         child: Text(
//                           lesson.title,
//                           maxLines: 2,
//                           overflow: TextOverflow.ellipsis,
//                           style: TextStyle(
//                             fontWeight: FontWeight.bold,
//                             fontSize: 16,
//                           ),
//                         ),
//                       ),
//                       // MENU BUTTON
//                       IconButton(
//                         icon: Icon(Icons.more_vert, color: Colors.grey),
//                         padding: EdgeInsets.zero,
//                         constraints: BoxConstraints(),
//                         onPressed: () => _showLessonOptions(context, lesson),
//                       ),
//                     ],
//                   ),
//                   SizedBox(height: 8),
//                   Row(
//                     children: [
//                       Icon(
//                         Icons.video_camera_back,
//                         size: 14,
//                         color: Colors.blue,
//                       ),
//                       SizedBox(width: 4),
//                       Text(
//                         "Video Lesson",
//                         style: TextStyle(fontSize: 12, color: Colors.grey),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // --- 3. TEXT CARD ---
//   Widget _buildTextCard(BuildContext context, LessonModel lesson) {
//     return Card(
//       elevation: 0,
//       color: Colors.grey[50],
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(12),
//         side: BorderSide(color: Colors.grey.shade200),
//       ),
//       child: ListTile(
//         contentPadding: EdgeInsets.all(12),
//         leading: Container(
//           width: 50,
//           height: 50,
//           decoration: BoxDecoration(
//             color: Colors.amber.withOpacity(0.1),
//             borderRadius: BorderRadius.circular(8),
//           ),
//           child: Icon(Icons.article, color: Colors.amber[800]),
//         ),
//         title: Text(
//           lesson.title,
//           style: TextStyle(fontWeight: FontWeight.bold),
//         ),
//         subtitle: Text(
//           lesson.content.replaceAll('\n', ' '),
//           maxLines: 1,
//           overflow: TextOverflow.ellipsis,
//         ),
//         // MENU BUTTON
//         trailing: IconButton(
//           icon: Icon(Icons.more_vert, color: Colors.grey),
//           onPressed: () => _showLessonOptions(context, lesson),
//         ),
//         onTap: () {
//           Navigator.push(
//             context,
//             MaterialPageRoute(
//               builder: (context) => ReaderScreen(lesson: lesson),
//             ),
//           );
//         },
//       ),
//     );
//   }

//   // --- 4. IMPORT DIALOG (Updated) ---
//   void _showCreateLessonDialog(
//     BuildContext context,
//     String userId,
//     String currentLanguage, // PASSED HERE
//     {
//     required bool isFavoriteByDefault,
//   }) {
//     final titleController = TextEditingController();
//     final contentController = TextEditingController();
//     // Removed language selector

//     final lessonBloc = context.read<LessonBloc>();
//     final lessonService = context.read<LessonService>();
//     final scaffoldMessenger = ScaffoldMessenger.of(context);

//     showDialog(
//       context: context,
//       builder: (dialogContext) => AlertDialog(
//         title: Text('Import Text'),
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
//               // Language is auto-assigned now
//               TextField(
//                 controller: contentController,
//                 decoration: InputDecoration(
//                   labelText: 'Content',
//                   border: OutlineInputBorder(),
//                   hintText: 'Paste text here...',
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
//                 final sentences = lessonService.splitIntoSentences(
//                   contentController.text,
//                 );

//                 final lesson = LessonModel(
//                   id: '',
//                   userId: userId,
//                   title: titleController.text,
//                   language: currentLanguage, // AUTO ASSIGNED
//                   content: contentController.text,
//                   sentences: sentences,
//                   createdAt: DateTime.now(),
//                   progress: 0,
//                   isFavorite: isFavoriteByDefault,
//                   type: 'text',
//                 );

//                 lessonBloc.add(LessonCreateRequested(lesson));
//                 Navigator.pop(dialogContext);

//                 scaffoldMessenger.showSnackBar(
//                   SnackBar(content: Text('Lesson imported successfully!')),
//                 );
//               }
//             },
//             child: Text('Import'),
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
    
    // THEME VARIABLES
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('My Favorites'),
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
            return Center(child: CircularProgressIndicator());
          }
          if (state is LessonLoading) {
            return Center(child: CircularProgressIndicator());
          }
          if (state is LessonLoaded) {
            // FILTER: Only show favorites
            final favoriteLessons =
                state.lessons.where((l) => l.isFavorite == true).toList();

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
                    Text(
                      'Lessons created here are auto-favorited.',
                      style: TextStyle(color: Colors.grey),
                    ),
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
                  return _buildVideoCard(context, lesson, isDark);
                } else {
                  return _buildTextCard(context, lesson, isDark);
                }
              },
            );
          }
          return Center(child: Text('Something went wrong'));
        },
      ),
      // --- CUSTOM DARK GLASSY BUTTON ---
      floatingActionButton: Material(
        color: Colors.transparent,
        elevation: 10,
        shadowColor: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          onTap: () {
            _showCreateLessonDialog(
              context,
              user.id,
              user.currentLanguage,
              isFavoriteByDefault: true,
            );
          },
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              // Adaptive Glassy Color
              color: isDark 
                  ? Color(0xFF2C2C2C).withOpacity(0.9) 
                  : Color(0xFF1E1E1E).withOpacity(0.9),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
                width: 1,
              ),
            ),
            child: Row(
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

  // --- 1. MENU DIALOG (Theme Aware) ---
  void _showLessonOptions(BuildContext context, LessonModel lesson, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (builderContext) => Container(
        decoration: BoxDecoration(
          color: isDark ? Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          top: 20,
          left: 0,
          right: 0,
          bottom: MediaQuery.of(builderContext).viewPadding.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: lesson.isFavorite 
                      ? Colors.amber.withOpacity(0.1) 
                      : (isDark ? Colors.white10 : Colors.grey[100]),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  lesson.isFavorite ? Icons.star : Icons.star_border,
                  color: lesson.isFavorite ? Colors.amber : Colors.grey,
                ),
              ),
              title: Text(
                lesson.isFavorite
                    ? 'Remove from Favorites'
                    : 'Add to Favorites',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              subtitle: Text(
                lesson.isFavorite
                    ? 'This lesson will be removed from your library.'
                    : 'Save this lesson to your library.',
                style: TextStyle(color: Colors.grey),
              ),
              onTap: () {
                final user =
                    (context.read<AuthBloc>().state as AuthAuthenticated).user;

                final updatedLesson = lesson.copyWith(
                  isFavorite: !lesson.isFavorite,
                  userId: user.id,
                );

                context.read<LessonBloc>().add(
                      LessonUpdateRequested(updatedLesson),
                    );

                Navigator.pop(builderContext);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      updatedLesson.isFavorite
                          ? "Added to favorites"
                          : "Removed from favorites",
                    ),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
            Divider(color: Colors.grey[800]),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.delete_outline, color: Colors.red),
              ),
              title: Text('Delete Lesson', style: TextStyle(color: Colors.red)),
              onTap: () {
                context
                    .read<LessonBloc>()
                    .add(LessonDeleteRequested(lesson.id));
                Navigator.pop(builderContext);
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- 2. VIDEO CARD (Theme Aware) ---
  Widget _buildVideoCard(BuildContext context, LessonModel lesson, bool isDark) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ReaderScreen(lesson: lesson)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Color(0xFF1E1E1E) : Colors.white,
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
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  child: Container(
                    height: 180,
                    width: double.infinity,
                    color: isDark ? Colors.white10 : Colors.grey[200],
                    child: lesson.imageUrl != null
                        ? Image.network(lesson.imageUrl!, fit: BoxFit.cover)
                        : Icon(
                            Icons.video_library,
                            size: 50,
                            color: Colors.grey[400],
                          ),
                  ),
                ),
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
            Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          lesson.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.more_vert, color: Colors.grey),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                        onPressed: () => _showLessonOptions(context, lesson, isDark),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.video_camera_back, size: 14, color: Colors.blue),
                      SizedBox(width: 4),
                      Text("Video Lesson", style: TextStyle(fontSize: 12, color: Colors.grey)),
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

  // --- 3. TEXT CARD (Theme Aware) ---
  Widget _buildTextCard(BuildContext context, LessonModel lesson, bool isDark) {
    return Card(
      elevation: 0,
      color: isDark ? Color(0xFF1E1E1E) : Colors.grey[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? Colors.transparent : Colors.grey.shade200),
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
        title: Text(
          lesson.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : Colors.grey[800],
          ),
        ),
        subtitle: Text(
          lesson.content.replaceAll('\n', ' '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.grey),
        ),
        trailing: IconButton(
          icon: Icon(Icons.more_vert, color: Colors.grey),
          onPressed: () => _showLessonOptions(context, lesson, isDark),
        ),
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

  // --- 4. IMPORT DIALOG (Theme Aware) ---
  void _showCreateLessonDialog(
    BuildContext context,
    String userId,
    String currentLanguage, {
    required bool isFavoriteByDefault,
  }) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    
    final lessonBloc = context.read<LessonBloc>();
    final lessonService = context.read<LessonService>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? Color(0xFF1E1E1E) : Colors.white,
        title: Text(
          'Import Text', 
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: 'Title',
                  labelStyle: TextStyle(color: Colors.grey),
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: contentController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: 'Content',
                  labelStyle: TextStyle(color: Colors.grey),
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                  hintText: 'Paste text here...',
                  hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
                ),
                maxLines: 8,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty &&
                  contentController.text.isNotEmpty) {
                final sentences = lessonService.splitIntoSentences(
                  contentController.text,
                );

                final lesson = LessonModel(
                  id: '',
                  userId: userId,
                  title: titleController.text,
                  language: currentLanguage, 
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