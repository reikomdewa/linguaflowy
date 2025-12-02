// // // File: lib/screens/home/home_screen.dart

// // import 'package:flutter/material.dart';
// // import 'package:flutter_bloc/flutter_bloc.dart';
// // import 'package:linguaflow/blocs/auth/auth_bloc.dart';
// // import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';
// // import 'package:linguaflow/screens/reader/reader_screen.dart';

// // class HomeScreen extends StatelessWidget {
// //   @override
// //   Widget build(BuildContext context) {
// //     final user = (context.watch<AuthBloc>().state as AuthAuthenticated).user;

// //     return Scaffold(
// //       appBar: AppBar(
// //         title: Text('Home'),
// //       ),
// //       body: SingleChildScrollView(
// //         padding: EdgeInsets.all(16),
// //         child: Column(
// //           crossAxisAlignment: CrossAxisAlignment.start,
// //           children: [
// //             Text(
// //               'Welcome, ${user.displayName}!',
// //               style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
// //             ),
// //             SizedBox(height: 24),
// //             _StatCard(
// //               title: 'Known Words',
// //               value: '0',
// //               icon: Icons.check_circle,
// //               color: Colors.green,
// //             ),
// //             SizedBox(height: 16),
// //             _StatCard(
// //               title: 'Learning Words',
// //               value: '0',
// //               icon: Icons.school,
// //               color: Colors.orange,
// //             ),
// //             SizedBox(height: 16),
// //             _StatCard(
// //               title: 'Lessons Completed',
// //               value: '0',
// //               icon: Icons.book,
// //               color: Colors.blue,
// //             ),
// //             SizedBox(height: 32),
// //             Text(
// //               'Recent Lessons',
// //               style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
// //             ),
// //             SizedBox(height: 16),
// //             BlocBuilder<LessonBloc, LessonState>(
// //               builder: (context, state) {
// //                 if (state is LessonInitial) {
// //                   context.read<LessonBloc>().add(LessonLoadRequested(user.id));
// //                   return Center(child: CircularProgressIndicator());
// //                 }
// //                 if (state is LessonLoading) {
// //                   return Center(child: CircularProgressIndicator());
// //                 }
// //                 if (state is LessonLoaded) {
// //                   if (state.lessons.isEmpty) {
// //                     return Center(
// //                       child: Column(
// //                         children: [
// //                           Icon(Icons.library_books, size: 64, color: Colors.grey),
// //                           SizedBox(height: 16),
// //                           Text('No lessons yet. Create your first lesson!'),
// //                         ],
// //                       ),
// //                     );
// //                   }
// //                   return Column(
// //                     children: state.lessons.take(5).map((lesson) {
// //                       return Card(
// //                         child: ListTile(
// //                           leading: CircleAvatar(
// //                             child: Text(lesson.language.toUpperCase()),
// //                           ),
// //                           title: Text(lesson.title),
// //                           subtitle: Text('${lesson.progress}% complete'),
// //                           trailing: Icon(Icons.arrow_forward_ios),
// //                           onTap: () {
// //                             Navigator.push(
// //                               context,
// //                               MaterialPageRoute(
// //                                 builder: (context) => ReaderScreen(lesson: lesson),
// //                               ),
// //                             );
// //                           },
// //                         ),
// //                       );
// //                     }).toList(),
// //                   );
// //                 }
// //                 return SizedBox();
// //               },
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// // }

// // class _StatCard extends StatelessWidget {
// //   final String title;
// //   final String value;
// //   final IconData icon;
// //   final Color color;

// //   const _StatCard({
// //     required this.title,
// //     required this.value,
// //     required this.icon,
// //     required this.color,
// //   });

// //   @override
// //   Widget build(BuildContext context) {
// //     return Container(
// //       padding: EdgeInsets.all(20),
// //       decoration: BoxDecoration(
// //         color: color.withOpacity(0.1),
// //         borderRadius: BorderRadius.circular(12),
// //         border: Border.all(color: color.withOpacity(0.3)),
// //       ),
// //       child: Row(
// //         children: [
// //           Icon(icon, size: 40, color: color),
// //           SizedBox(width: 16),
// //           Expanded(
// //             child: Column(
// //               crossAxisAlignment: CrossAxisAlignment.start,
// //               children: [
// //                 Text(
// //                   title,
// //                   style: TextStyle(fontSize: 14, color: Colors.grey[600]),
// //                 ),
// //                 SizedBox(height: 4),
// //                 Text(
// //                   value,
// //                   style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
// //                 ),
// //               ],
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }
// // }

// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:linguaflow/blocs/auth/auth_bloc.dart';
// import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';
// import 'package:linguaflow/models/lesson_model.dart';
// import 'package:linguaflow/screens/reader/reader_screen.dart';
// import 'package:linguaflow/services/lesson_service.dart';

// class HomeScreen extends StatefulWidget {
//   @override
//   _HomeScreenState createState() => _HomeScreenState();
// }

// class _HomeScreenState extends State<HomeScreen> {
//   String _selectedLanguage = 'es'; // Default language for the filter

//   @override
//   Widget build(BuildContext context) {
//     final user = (context.watch<AuthBloc>().state as AuthAuthenticated).user;

//     return Scaffold(
//       appBar: AppBar(
//         elevation: 0,
//         backgroundColor: Colors.white,
//         foregroundColor: Colors.black,
//         title: Row(
//           children: [
//             // Language Dropdown
//             DropdownButtonHideUnderline(
//               child: DropdownButton<String>(
//                 value: user.currentLanguage,
//                 icon: Icon(Icons.keyboard_arrow_down),
//                 style: TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.black,
//                 ),
//                 onChanged: (String? newValue) {
//                   // if (newValue != null) {
//                   //   setState(() {
//                   //     _selectedLanguage = newValue;
//                   //   });
//                   //   // Optional: Trigger a bloc event to filter by language here
//                   // }
//                   if (newValue != null) {
//                     // 1. Update Global User Language
//                     context.read<AuthBloc>().add(
//                       AuthTargetLanguageChanged(newValue),
//                     );

//                     // 2. Reload Lessons for new language
//                     context.read<LessonBloc>().add(
//                       LessonLoadRequested(user.id, newValue),
//                     );
//                   }
//                 },
//                 items: [
//                   DropdownMenuItem(value: 'es', child: Text('Spanish')),
//                   DropdownMenuItem(value: 'fr', child: Text('French')),
//                   DropdownMenuItem(value: 'de', child: Text('German')),
//                   DropdownMenuItem(value: 'en', child: Text('English')),
//                 ],
//               ),
//             ),
//             SizedBox(width: 12),
//             // Known Words Text
//             Container(
//               padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//               decoration: BoxDecoration(
//                 color: Colors.grey[100],
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: Row(
//                 children: [
//                   Icon(Icons.check_circle, size: 14, color: Colors.green),
//                   SizedBox(width: 4),
//                   Text(
//                     '1,204 known words', // This would typically come from a StatsBloc
//                     style: TextStyle(fontSize: 12, color: Colors.grey[700]),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//       body: BlocBuilder<LessonBloc, LessonState>(
//         builder: (context, state) {
//           if (state is LessonInitial) {
//             context.read<LessonBloc>().add(LessonLoadRequested(user.id, user.currentLanguage));
//             return Center(child: CircularProgressIndicator());
//           }
//           if (state is LessonLoading) {
//             return Center(child: CircularProgressIndicator());
//           }
//           if (state is LessonLoaded) {
//             if (state.lessons.isEmpty) {
//               return _buildEmptyState();
//             }

//             // In LingQ, Home usually shows all recent lessons
//             final displayLessons = state.lessons;

//             return ListView.separated(
//               padding: EdgeInsets.all(16),
//               itemCount: displayLessons.length,
//               separatorBuilder: (ctx, i) => SizedBox(height: 16),
//               itemBuilder: (context, index) {
//                 final lesson = displayLessons[index];
//                 return _buildLessonCard(context, lesson);
//               },
//             );
//           }
//           return Center(child: Text('Something went wrong'));
//         },
//       ),
//       floatingActionButton: FloatingActionButton.extended(
//         onPressed: () {
//           // Creating from Home: Not favorited by default
//           _showCreateLessonDialog(context, user.id, isFavoriteByDefault: false);
//         },
//         icon: Icon(Icons.add),
//         label: Text('New Lesson'),
//       ),
//     );
//   }

//   Widget _buildLessonCard(BuildContext context, LessonModel lesson) {
//     return Card(
//       elevation: 2,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       child: InkWell(
//         borderRadius: BorderRadius.circular(12),
//         onTap: () {
//           Navigator.push(
//             context,
//             MaterialPageRoute(
//               builder: (context) => ReaderScreen(lesson: lesson),
//             ),
//           );
//         },
//         child: Padding(
//           padding: EdgeInsets.all(16),
//           child: Row(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // Lesson Image / Placeholder
//               Container(
//                 width: 60,
//                 height: 80,
//                 decoration: BoxDecoration(
//                   color: Colors.blue.shade50,
//                   borderRadius: BorderRadius.circular(8),
//                   image: lesson.imageUrl != null
//                       ? DecorationImage(
//                           image: NetworkImage(lesson.imageUrl!),
//                           fit: BoxFit.cover,
//                         )
//                       : null,
//                 ),
//                 child: lesson.imageUrl == null
//                     ? Center(
//                         child: Text(
//                           lesson.language.toUpperCase(),
//                           style: TextStyle(fontWeight: FontWeight.bold),
//                         ),
//                       )
//                     : null,
//               ),
//               SizedBox(width: 16),
//               // Content
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       lesson.title,
//                       style: TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.bold,
//                       ),
//                       maxLines: 2,
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                     SizedBox(height: 4),
//                     Text(
//                       "${lesson.sentences.length} sentences",
//                       style: TextStyle(color: Colors.grey[600], fontSize: 12),
//                     ),
//                     SizedBox(height: 8),
//                     // Progress Bar
//                     ClipRRect(
//                       borderRadius: BorderRadius.circular(4),
//                       child: LinearProgressIndicator(
//                         value: lesson.progress / 100,
//                         backgroundColor: Colors.grey[200],
//                         valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
//                         minHeight: 4,
//                       ),
//                     ),
//                     SizedBox(height: 4),
//                     Text(
//                       '${lesson.progress}%',
//                       style: TextStyle(fontSize: 10, color: Colors.grey[500]),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildEmptyState() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(Icons.library_books, size: 64, color: Colors.grey[300]),
//           SizedBox(height: 16),
//           Text(
//             'Your feed is empty.',
//             style: TextStyle(fontSize: 18, color: Colors.grey[600]),
//           ),
//           SizedBox(height: 8),
//           Text('Create a lesson to start learning!'),
//         ],
//       ),
//     );
//   }

//   void _showCreateLessonDialog(
//     BuildContext context,
//     String userId, {
//     required bool isFavoriteByDefault,
//   }) {
//     final titleController = TextEditingController();
//     final contentController = TextEditingController();
//     String selectedLanguage = _selectedLanguage;

//     // CAPTURE CONTEXT BEFORE DIALOG
//     // This fixes the "Provider not found" or layout errors
//     final lessonBloc = context.read<LessonBloc>();
//     final lessonService = context.read<LessonService>();
//     final scaffoldMessenger = ScaffoldMessenger.of(context);

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
//                   DropdownMenuItem(value: 'en', child: Text('English')),
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
//                   hintText: 'Paste text here...',
//                 ),
//                 maxLines: 6,
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
//                   language: selectedLanguage,
//                   content: contentController.text,
//                   sentences: sentences,
//                   createdAt: DateTime.now(),
//                   progress: 0,
//                   isFavorite:
//                       isFavoriteByDefault, // Set based on where we created it
//                 );

//                 // Use the captured bloc instance
//                 lessonBloc.add(LessonCreateRequested(lesson));

//                 Navigator.pop(dialogContext);

//                 scaffoldMessenger.showSnackBar(
//                   SnackBar(
//                     content: Text(
//                       isFavoriteByDefault
//                           ? 'Lesson created and favorited!'
//                           : 'Lesson created!',
//                     ),
//                   ),
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

// File: lib/screens/home/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';
import 'package:linguaflow/blocs/lesson/lesson_event.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/screens/reader/reader_screen.dart';
import 'package:linguaflow/services/lesson_service.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Filter State
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Videos', 'Audio', 'Text'];

  @override
  Widget build(BuildContext context) {
    final user = (context.watch<AuthBloc>().state as AuthAuthenticated).user;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: Row(
          children: [
            // Language Dropdown
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: user.currentLanguage,
                icon: Icon(Icons.keyboard_arrow_down),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    context.read<AuthBloc>().add(
                          AuthTargetLanguageChanged(newValue),
                        );
                    context.read<LessonBloc>().add(
                          LessonLoadRequested(user.id, newValue),
                        );
                  }
                },
                items: [
                  DropdownMenuItem(value: 'es', child: Text('Spanish')),
                  DropdownMenuItem(value: 'fr', child: Text('French')),
                  DropdownMenuItem(value: 'de', child: Text('German')),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                ],
              ),
            ),
            SizedBox(width: 12),
            // Known Words Indicator
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 14, color: Colors.green),
                  SizedBox(width: 4),
                  Text(
                    '1,204 known words', 
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // 1. YouTube-style Filter Chips
          _buildCategoryChips(),
          
          // 2. Lesson Feed
          Expanded(
            child: BlocBuilder<LessonBloc, LessonState>(
              builder: (context, state) {
                if (state is LessonInitial) {
                  context.read<LessonBloc>().add(LessonLoadRequested(user.id, user.currentLanguage));
                  return Center(child: CircularProgressIndicator());
                }
                if (state is LessonLoading) {
                  return Center(child: CircularProgressIndicator());
                }
                if (state is LessonLoaded) {
                  // FILTER LOGIC
                  final filteredLessons = state.lessons.where((lesson) {
                    if (_selectedCategory == 'All') return true;
                    if (_selectedCategory == 'Videos') return lesson.type == 'video';
                    if (_selectedCategory == 'Audio') return lesson.type == 'audio';
                    if (_selectedCategory == 'Text') return lesson.type == 'text';
                    return true;
                  }).toList();

                  if (filteredLessons.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.separated(
                    padding: EdgeInsets.all(16),
                    itemCount: filteredLessons.length,
                    separatorBuilder: (ctx, i) => SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final lesson = filteredLessons[index];
                      return _buildLessonCard(context, lesson);
                    },
                  );
                }
                return Center(child: Text('Something went wrong'));
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // PASS CURRENT LANGUAGE HERE
          _showCreateLessonDialog(
            context, 
            user.id, 
            user.currentLanguage, 
            isFavoriteByDefault: false
          );
        },
        icon: Icon(Icons.add),
        label: Text('New Lesson'),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return Container(
      height: 60,
      padding: EdgeInsets.symmetric(vertical: 10),
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (ctx, i) => SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category;
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategory = category;
              });
            },
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.black : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                category,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
 Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'beginner': return Colors.green;
      case 'intermediate': return Colors.orange;
      case 'advanced': return Colors.red;
      default: return Colors.grey;
    }
  }
  Widget _buildLessonCard(BuildContext context, LessonModel lesson) {
    IconData typeIcon;
    if (lesson.type == 'video') typeIcon = Icons.play_circle_fill;
    else if (lesson.type == 'audio') typeIcon = Icons.audiotrack;
    else typeIcon = Icons.article;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // If it's a YouTube video that hasn't been saved to DB yet (id starts with yt_)
          // You might want to save it when opened, or just pass it to reader.
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReaderScreen(lesson: lesson),
            ),
          );
        },
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Stack
              Stack(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      image: lesson.imageUrl != null
                          ? DecorationImage(
                              image: NetworkImage(lesson.imageUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: lesson.imageUrl == null
                        ? Center(
                            child: Text(
                              lesson.language.toUpperCase(),
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(typeIcon, size: 12, color: Colors.white),
                    ),
                  )
                ],
              ),
              SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            lesson.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    // Stats Row
                    Row(
                      children: [
                         // DIFFICULTY TAG
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getDifficultyColor(lesson.difficulty).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: _getDifficultyColor(lesson.difficulty).withOpacity(0.5),
                              width: 0.5
                            ),
                          ),
                          child: Text(
                            lesson.difficulty.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10, 
                              fontWeight: FontWeight.bold,
                              color: _getDifficultyColor(lesson.difficulty)
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          "${lesson.sentences.length} sentences",
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: lesson.progress / 100,
                        backgroundColor: Colors.grey[100],
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String message = "Your feed is empty.";
    if (_selectedCategory != 'All') {
      message = "No $_selectedCategory lessons found.";
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.filter_list_off, size: 64, color: Colors.grey[300]),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() => _selectedCategory = 'All'),
            child: Text('Clear Filters'),
          )
        ],
      ),
    );
  }

  void _showCreateLessonDialog(
    BuildContext context,
    String userId,
    String currentLanguage, // ADDED THIS PARAMETER
    {
    required bool isFavoriteByDefault,
  }) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    
    // CAPTURE CONTEXT
    final lessonBloc = context.read<LessonBloc>();
    final lessonService = context.read<LessonService>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Create New Lesson'),
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
              // Show Language (Read-only)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4)
                ),
                child: Text(
                  "Language: ${currentLanguage.toUpperCase()}", 
                  style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold)
                ),
              ),
              SizedBox(height: 16),
              // Show Type (Read-only)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4)
                ),
                child: Text("Type: Text Lesson", style: TextStyle(color: Colors.grey)),
              ),
              SizedBox(height: 16),
              TextField(
                controller: contentController,
                decoration: InputDecoration(
                  labelText: 'Content',
                  border: OutlineInputBorder(),
                  hintText: 'Paste text here...',
                ),
                maxLines: 6,
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
              if (titleController.text.isNotEmpty &&
                  contentController.text.isNotEmpty) {
                final sentences = lessonService.splitIntoSentences(
                  contentController.text,
                );

                final lesson = LessonModel(
                  id: '',
                  userId: userId,
                  title: titleController.text,
                  language: currentLanguage, // USE PASSED LANGUAGE
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
                  SnackBar(content: Text('Lesson created!')),
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
