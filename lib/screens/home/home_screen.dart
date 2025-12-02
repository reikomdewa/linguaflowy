// // import 'package:flutter/material.dart';
// // import 'package:flutter_bloc/flutter_bloc.dart';
// // import 'package:linguaflow/blocs/auth/auth_bloc.dart';
// // import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';
// // import 'package:linguaflow/blocs/lesson/lesson_event.dart';
// // import 'package:linguaflow/models/lesson_model.dart';
// // import 'package:linguaflow/screens/reader/reader_screen.dart';
// // import 'package:linguaflow/services/lesson_service.dart';

// // class HomeScreen extends StatefulWidget {
// //   @override
// //   _HomeScreenState createState() => _HomeScreenState();
// // }

// // class _HomeScreenState extends State<HomeScreen> {
// //   // Filter State
// //   String _selectedCategory = 'All';
// //   final List<String> _categories = ['All', 'Videos', 'Audio', 'Text'];

// //   @override
// //   Widget build(BuildContext context) {
// //     final user = (context.watch<AuthBloc>().state as AuthAuthenticated).user;

// //     return Scaffold(
// //       appBar: AppBar(
// //         elevation: 0,
// //         backgroundColor: Colors.white,
// //         foregroundColor: Colors.black,
// //         title: Row(
// //           children: [
// //             // Language Dropdown
// //             DropdownButtonHideUnderline(
// //               child: DropdownButton<String>(
// //                 value: user.currentLanguage,
// //                 icon: Icon(Icons.keyboard_arrow_down),
// //                 style: TextStyle(
// //                   fontSize: 18,
// //                   fontWeight: FontWeight.bold,
// //                   color: Colors.black,
// //                 ),
// //                 onChanged: (String? newValue) {
// //                   if (newValue != null) {
// //                     context.read<AuthBloc>().add(
// //                           AuthTargetLanguageChanged(newValue),
// //                         );
// //                     context.read<LessonBloc>().add(
// //                           LessonLoadRequested(user.id, newValue),
// //                         );
// //                   }
// //                 },
// //                 items: [
// //                   DropdownMenuItem(value: 'es', child: Text('Spanish')),
// //                   DropdownMenuItem(value: 'fr', child: Text('French')),
// //                   DropdownMenuItem(value: 'de', child: Text('German')),
// //                   DropdownMenuItem(value: 'en', child: Text('English')),
// //                 ],
// //               ),
// //             ),
// //             SizedBox(width: 12),
// //             // Known Words Indicator
// //             Container(
// //               padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
// //               decoration: BoxDecoration(
// //                 color: Colors.grey[100],
// //                 borderRadius: BorderRadius.circular(12),
// //               ),
// //               child: Row(
// //                 children: [
// //                   Icon(Icons.check_circle, size: 14, color: Colors.green),
// //                   SizedBox(width: 4),
// //                   Text(
// //                     '1,204 known words',
// //                     style: TextStyle(fontSize: 12, color: Colors.grey[700]),
// //                   ),
// //                 ],
// //               ),
// //             ),
// //           ],
// //         ),
// //       ),
// //       body: Column(
// //         children: [
// //           // 1. YouTube-style Filter Chips
// //           _buildCategoryChips(),

// //           // 2. Lesson Feed
// //           Expanded(
// //             child: BlocBuilder<LessonBloc, LessonState>(
// //               builder: (context, state) {
// //                 if (state is LessonInitial) {
// //                   context.read<LessonBloc>().add(LessonLoadRequested(user.id, user.currentLanguage));
// //                   return Center(child: CircularProgressIndicator());
// //                 }
// //                 if (state is LessonLoading) {
// //                   return Center(child: CircularProgressIndicator());
// //                 }
// //                 if (state is LessonLoaded) {
// //                   // FILTER LOGIC
// //                   final filteredLessons = state.lessons.where((lesson) {
// //                     if (_selectedCategory == 'All') return true;
// //                     if (_selectedCategory == 'Videos') return lesson.type == 'video';
// //                     if (_selectedCategory == 'Audio') return lesson.type == 'audio';
// //                     if (_selectedCategory == 'Text') return lesson.type == 'text';
// //                     return true;
// //                   }).toList();

// //                   if (filteredLessons.isEmpty) {
// //                     return _buildEmptyState();
// //                   }

// //                   return ListView.separated(
// //                     padding: EdgeInsets.all(16),
// //                     itemCount: filteredLessons.length,
// //                     separatorBuilder: (ctx, i) => SizedBox(height: 16),
// //                     itemBuilder: (context, index) {
// //                       final lesson = filteredLessons[index];
// //                       return _buildLessonCard(context, lesson);
// //                     },
// //                   );
// //                 }
// //                 return Center(child: Text('Something went wrong'));
// //               },
// //             ),
// //           ),
// //         ],
// //       ),
// //       floatingActionButton: FloatingActionButton.extended(
// //         onPressed: () {
// //           // PASS CURRENT LANGUAGE HERE
// //           _showCreateLessonDialog(
// //             context,
// //             user.id,
// //             user.currentLanguage,
// //             isFavoriteByDefault: false
// //           );
// //         },
// //         icon: Icon(Icons.add),
// //         label: Text('New Lesson'),
// //       ),
// //     );
// //   }

// //   Widget _buildCategoryChips() {
// //     return Container(
// //       height: 60,
// //       padding: EdgeInsets.symmetric(vertical: 10),
// //       child: ListView.separated(
// //         padding: EdgeInsets.symmetric(horizontal: 16),
// //         scrollDirection: Axis.horizontal,
// //         itemCount: _categories.length,
// //         separatorBuilder: (ctx, i) => SizedBox(width: 8),
// //         itemBuilder: (context, index) {
// //           final category = _categories[index];
// //           final isSelected = _selectedCategory == category;

// //           return GestureDetector(
// //             onTap: () {
// //               setState(() {
// //                 _selectedCategory = category;
// //               });
// //             },
// //             child: AnimatedContainer(
// //               duration: Duration(milliseconds: 200),
// //               padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
// //               decoration: BoxDecoration(
// //                 color: isSelected ? Colors.black : Colors.grey[200],
// //                 borderRadius: BorderRadius.circular(8),
// //               ),
// //               alignment: Alignment.center,
// //               child: Text(
// //                 category,
// //                 style: TextStyle(
// //                   color: isSelected ? Colors.white : Colors.black,
// //                   fontWeight: FontWeight.w500,
// //                   fontSize: 14,
// //                 ),
// //               ),
// //             ),
// //           );
// //         },
// //       ),
// //     );
// //   }
// //  Color _getDifficultyColor(String difficulty) {
// //     switch (difficulty.toLowerCase()) {
// //       case 'beginner': return Colors.green;
// //       case 'intermediate': return Colors.orange;
// //       case 'advanced': return Colors.red;
// //       default: return Colors.grey;
// //     }
// //   }
// //   Widget _buildLessonCard(BuildContext context, LessonModel lesson) {
// //     IconData typeIcon;
// //     if (lesson.type == 'video') typeIcon = Icons.play_circle_fill;
// //     else if (lesson.type == 'audio') typeIcon = Icons.audiotrack;
// //     else typeIcon = Icons.article;

// //     return Card(
// //       elevation: 0,
// //       color: Colors.white,
// //       shape: RoundedRectangleBorder(
// //         borderRadius: BorderRadius.circular(12),
// //         side: BorderSide(color: Colors.grey.shade200),
// //       ),
// //       child: InkWell(
// //         borderRadius: BorderRadius.circular(12),
// //         onTap: () {
// //           // If it's a YouTube video that hasn't been saved to DB yet (id starts with yt_)
// //           // You might want to save it when opened, or just pass it to reader.
// //           Navigator.push(
// //             context,
// //             MaterialPageRoute(
// //               builder: (context) => ReaderScreen(lesson: lesson),
// //             ),
// //           );
// //         },
// //         child: Padding(
// //           padding: EdgeInsets.all(12),
// //           child: Row(
// //             crossAxisAlignment: CrossAxisAlignment.start,
// //             children: [
// //               // Image Stack
// //               Stack(
// //                 children: [
// //                   Container(
// //                     width: 80,
// //                     height: 80,
// //                     decoration: BoxDecoration(
// //                       color: Colors.grey.shade100,
// //                       borderRadius: BorderRadius.circular(8),
// //                       image: lesson.imageUrl != null
// //                           ? DecorationImage(
// //                               image: NetworkImage(lesson.imageUrl!),
// //                               fit: BoxFit.cover,
// //                             )
// //                           : null,
// //                     ),
// //                     child: lesson.imageUrl == null
// //                         ? Center(
// //                             child: Text(
// //                               lesson.language.toUpperCase(),
// //                               style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
// //                             ),
// //                           )
// //                         : null,
// //                   ),
// //                   Positioned(
// //                     bottom: 4,
// //                     right: 4,
// //                     child: Container(
// //                       padding: EdgeInsets.all(4),
// //                       decoration: BoxDecoration(
// //                         color: Colors.black.withOpacity(0.7),
// //                         borderRadius: BorderRadius.circular(4),
// //                       ),
// //                       child: Icon(typeIcon, size: 12, color: Colors.white),
// //                     ),
// //                   )
// //                 ],
// //               ),
// //               SizedBox(width: 16),
// //               // Content
// //               Expanded(
// //                 child: Column(
// //                   crossAxisAlignment: CrossAxisAlignment.start,
// //                   children: [
// //                     Row(
// //                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
// //                       children: [
// //                         Expanded(
// //                           child: Text(
// //                             lesson.title,
// //                             style: TextStyle(
// //                               fontSize: 16,
// //                               fontWeight: FontWeight.bold,
// //                             ),
// //                             maxLines: 2,
// //                             overflow: TextOverflow.ellipsis,
// //                           ),
// //                         ),
// //                       ],
// //                     ),
// //                     SizedBox(height: 6),
// //                     // Stats Row
// //                     Row(
// //                       children: [
// //                          // DIFFICULTY TAG
// //                         Container(
// //                           padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
// //                           decoration: BoxDecoration(
// //                             color: _getDifficultyColor(lesson.difficulty).withOpacity(0.1),
// //                             borderRadius: BorderRadius.circular(4),
// //                             border: Border.all(
// //                               color: _getDifficultyColor(lesson.difficulty).withOpacity(0.5),
// //                               width: 0.5
// //                             ),
// //                           ),
// //                           child: Text(
// //                             lesson.difficulty.toUpperCase(),
// //                             style: TextStyle(
// //                               fontSize: 10,
// //                               fontWeight: FontWeight.bold,
// //                               color: _getDifficultyColor(lesson.difficulty)
// //                             ),
// //                           ),
// //                         ),
// //                         SizedBox(width: 8),
// //                         Text(
// //                           "${lesson.sentences.length} sentences",
// //                           style: TextStyle(color: Colors.grey[600], fontSize: 12),
// //                         ),
// //                       ],
// //                     ),
// //                     SizedBox(height: 8),
// //                     // Progress Bar
// //                     ClipRRect(
// //                       borderRadius: BorderRadius.circular(4),
// //                       child: LinearProgressIndicator(
// //                         value: lesson.progress / 100,
// //                         backgroundColor: Colors.grey[100],
// //                         valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
// //                         minHeight: 4,
// //                       ),
// //                     ),
// //                   ],
// //                 ),
// //               ),
// //             ],
// //           ),
// //         ),
// //       ),
// //     );
// //   }

// //   Widget _buildEmptyState() {
// //     String message = "Your feed is empty.";
// //     if (_selectedCategory != 'All') {
// //       message = "No $_selectedCategory lessons found.";
// //     }

// //     return Center(
// //       child: Column(
// //         mainAxisAlignment: MainAxisAlignment.center,
// //         children: [
// //           Icon(Icons.filter_list_off, size: 64, color: Colors.grey[300]),
// //           SizedBox(height: 16),
// //           Text(
// //             message,
// //             style: TextStyle(fontSize: 18, color: Colors.grey[600]),
// //           ),
// //           SizedBox(height: 8),
// //           TextButton(
// //             onPressed: () => setState(() => _selectedCategory = 'All'),
// //             child: Text('Clear Filters'),
// //           )
// //         ],
// //       ),
// //     );
// //   }

// //   void _showCreateLessonDialog(
// //     BuildContext context,
// //     String userId,
// //     String currentLanguage, // ADDED THIS PARAMETER
// //     {
// //     required bool isFavoriteByDefault,
// //   }) {
// //     final titleController = TextEditingController();
// //     final contentController = TextEditingController();

// //     // CAPTURE CONTEXT
// //     final lessonBloc = context.read<LessonBloc>();
// //     final lessonService = context.read<LessonService>();
// //     final scaffoldMessenger = ScaffoldMessenger.of(context);

// //     showDialog(
// //       context: context,
// //       builder: (dialogContext) => AlertDialog(
// //         title: Text('Create New Lesson'),
// //         content: SingleChildScrollView(
// //           child: Column(
// //             mainAxisSize: MainAxisSize.min,
// //             children: [
// //               TextField(
// //                 controller: titleController,
// //                 decoration: InputDecoration(
// //                   labelText: 'Title',
// //                   border: OutlineInputBorder(),
// //                 ),
// //               ),
// //               SizedBox(height: 16),
// //               // Show Language (Read-only)
// //               Container(
// //                 width: double.infinity,
// //                 padding: EdgeInsets.all(12),
// //                 decoration: BoxDecoration(
// //                   color: Colors.grey[100],
// //                   borderRadius: BorderRadius.circular(4)
// //                 ),
// //                 child: Text(
// //                   "Language: ${currentLanguage.toUpperCase()}",
// //                   style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold)
// //                 ),
// //               ),
// //               SizedBox(height: 16),
// //               // Show Type (Read-only)
// //               Container(
// //                 width: double.infinity,
// //                 padding: EdgeInsets.all(12),
// //                 decoration: BoxDecoration(
// //                   color: Colors.grey[100],
// //                   borderRadius: BorderRadius.circular(4)
// //                 ),
// //                 child: Text("Type: Text Lesson", style: TextStyle(color: Colors.grey)),
// //               ),
// //               SizedBox(height: 16),
// //               TextField(
// //                 controller: contentController,
// //                 decoration: InputDecoration(
// //                   labelText: 'Content',
// //                   border: OutlineInputBorder(),
// //                   hintText: 'Paste text here...',
// //                 ),
// //                 maxLines: 6,
// //               ),
// //             ],
// //           ),
// //         ),
// //         actions: [
// //           TextButton(
// //             onPressed: () => Navigator.pop(dialogContext),
// //             child: Text('Cancel'),
// //           ),
// //           ElevatedButton(
// //             onPressed: () {
// //               if (titleController.text.isNotEmpty &&
// //                   contentController.text.isNotEmpty) {
// //                 final sentences = lessonService.splitIntoSentences(
// //                   contentController.text,
// //                 );

// //                 final lesson = LessonModel(
// //                   id: '',
// //                   userId: userId,
// //                   title: titleController.text,
// //                   language: currentLanguage, // USE PASSED LANGUAGE
// //                   content: contentController.text,
// //                   sentences: sentences,
// //                   createdAt: DateTime.now(),
// //                   progress: 0,
// //                   isFavorite: isFavoriteByDefault,
// //                   type: 'text',
// //                 );

// //                 lessonBloc.add(LessonCreateRequested(lesson));
// //                 Navigator.pop(dialogContext);

// //                 scaffoldMessenger.showSnackBar(
// //                   SnackBar(content: Text('Lesson created!')),
// //                 );
// //               }
// //             },
// //             child: Text('Create'),
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
//   // Global Filter (Top of screen)
//   String _selectedGlobalFilter = 'All';
//   final List<String> _globalFilters = ['All', 'Videos', 'Audio', 'Text'];

//   // Video Section Specific Filter (The tabs you asked for)
//   String _videoDifficultyTab = 'All';
//   final List<String> _difficultyTabs = [
//     'All',
//     'Beginner',
//     'Intermediate',
//     'Advanced',
//   ];

//   @override
//   Widget build(BuildContext context) {
//     final user = (context.watch<AuthBloc>().state as AuthAuthenticated).user;

//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         elevation: 0,
//         backgroundColor: Colors.white,
//         foregroundColor: Colors.black,
//         title: Row(
//           children: [
//             DropdownButtonHideUnderline(
//               child: DropdownButton<String>(
//                 value: user.currentLanguage,
//                 icon: Icon(Icons.keyboard_arrow_down, color: Colors.blue),
//                 style: TextStyle(
//                   fontSize: 20,
//                   fontWeight: FontWeight.w800,
//                   color: Colors.black,
//                 ),
//                 onChanged: (String? newValue) {
//                   if (newValue != null) {
//                     context.read<AuthBloc>().add(
//                       AuthTargetLanguageChanged(newValue),
//                     );
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
//                   DropdownMenuItem(value: 'it', child: Text('Italian')),
//                   DropdownMenuItem(value: 'pt', child: Text('Portuguese')),
//                   DropdownMenuItem(value: 'ja', child: Text('Japanese')),
//                 ],
//               ),
//             ),
//             Spacer(),
//             Container(
//               padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//               decoration: BoxDecoration(
//                 color: Colors.amber.withOpacity(0.2),
//                 borderRadius: BorderRadius.circular(20),
//               ),
//               child: Row(
//                 children: [
//                   Icon(Icons.emoji_events, size: 16, color: Colors.amber[800]),
//                   SizedBox(width: 4),
//                   Text(
//                     '1,204',
//                     style: TextStyle(
//                       fontSize: 14,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.amber[900],
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//       body: Column(
//         children: [
//           // 1. Top Global Filters (All, Videos, Text...)
//           _buildGlobalFilterChips(),

//           // 2. Main Content
//           Expanded(
//             child: BlocBuilder<LessonBloc, LessonState>(
//               builder: (context, state) {
//                 if (state is LessonInitial) {
//                   context.read<LessonBloc>().add(
//                     LessonLoadRequested(user.id, user.currentLanguage),
//                   );
//                   return Center(child: CircularProgressIndicator());
//                 }
//                 if (state is LessonLoading)
//                   return Center(child: CircularProgressIndicator());

//                 if (state is LessonLoaded) {
//                   // If "Text" or "Audio" is selected at top, show simple list
//                   if (_selectedGlobalFilter != 'All' &&
//                       _selectedGlobalFilter != 'Videos') {
//                     return _buildFilteredList(state.lessons);
//                   }

//                   // Default Dashboard Layout (Like Screenshot)
//                   return RefreshIndicator(
//                     onRefresh: () async {
//                       context.read<LessonBloc>().add(
//                         LessonLoadRequested(user.id, user.currentLanguage),
//                       );
//                     },
//                     child: SingleChildScrollView(
//                       padding: EdgeInsets.only(bottom: 80),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           _buildVideoSection(state.lessons),
//                           _buildPopularTextSection(state.lessons),
//                         ],
//                       ),
//                     ),
//                   );
//                 }
//                 return Center(child: Text('Something went wrong'));
//               },
//             ),
//           ),
//         ],
//       ),
//       floatingActionButton: FloatingActionButton.extended(
//         onPressed: () {
//           _showCreateLessonDialog(
//             context,
//             user.id,
//             user.currentLanguage,
//             isFavoriteByDefault: false,
//           );
//         },
//         backgroundColor: Colors.blue,
//         icon: Icon(Icons.add),
//         label: Text('New Lesson'),
//       ),
//     );
//   }

//   // --- SECTION 1: VIDEO LESSONS WITH TABS ---
//   Widget _buildVideoSection(List<LessonModel> allLessons) {
//     // 1. Filter only videos first
//     final allVideos = allLessons.where((l) => l.type == 'video').toList();

//     // 2. Filter by Difficulty Tab
//     final displayVideos = _videoDifficultyTab == 'All'
//         ? allVideos
//         : allVideos
//               .where(
//                 (l) =>
//                     l.difficulty.toLowerCase() ==
//                     _videoDifficultyTab.toLowerCase(),
//               )
//               .toList();

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         // Title
//         Padding(
//           padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
//           child: Row(
//             children: [
//               Text(
//                 "Guided Courses",
//                 style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
//               ),
//               SizedBox(width: 8),
//               Icon(Icons.auto_awesome, size: 18, color: Colors.blue),
//             ],
//           ),
//         ),

//         // Difficulty Tabs (Like screenshot)
//         SingleChildScrollView(
//           scrollDirection: Axis.horizontal,
//           padding: EdgeInsets.symmetric(horizontal: 16),
//           child: Row(
//             children: _difficultyTabs.map((tab) {
//               final isSelected = _videoDifficultyTab == tab;
//               return Padding(
//                 padding: const EdgeInsets.only(right: 24.0, bottom: 12),
//                 child: InkWell(
//                   onTap: () => setState(() => _videoDifficultyTab = tab),
//                   child: Column(
//                     children: [
//                       Text(
//                         tab,
//                         style: TextStyle(
//                           fontSize: 16,
//                           fontWeight: isSelected
//                               ? FontWeight.bold
//                               : FontWeight.normal,
//                           color: isSelected ? Colors.black : Colors.grey[500],
//                         ),
//                       ),
//                       if (isSelected)
//                         Container(
//                           margin: EdgeInsets.only(top: 4),
//                           height: 2,
//                           width: 20,
//                           color: Colors.red, // The little underline indicator
//                         ),
//                     ],
//                   ),
//                 ),
//               );
//             }).toList(),
//           ),
//         ),

//         // Horizontal Video List
//         if (displayVideos.isEmpty)
//           Container(
//             height: 200,
//             alignment: Alignment.center,
//             child: Text(
//               "No videos found for $_videoDifficultyTab",
//               style: TextStyle(color: Colors.grey),
//             ),
//           )
//         else
//           SizedBox(
//             height: 260, // Adjusted height for card + text
//             child: ListView.separated(
//               padding: EdgeInsets.symmetric(horizontal: 16),
//               scrollDirection: Axis.horizontal,
//               itemCount: displayVideos.length,
//               separatorBuilder: (ctx, i) => SizedBox(width: 16),
//               itemBuilder: (context, index) {
//                 return _buildVideoCardLarge(context, displayVideos[index]);
//               },
//             ),
//           ),
//       ],
//     );
//   }

//   // --- SECTION 2: POPULAR TEXT LESSONS ---
//   Widget _buildPopularTextSection(List<LessonModel> allLessons) {
//     final textLessons = allLessons.where((l) => l.type == 'text').toList();

//     if (textLessons.isEmpty) return SizedBox();

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Padding(
//           padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
//           child: Row(
//             children: [
//               Text(
//                 "Popular Text Lessons",
//                 style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//               ),
//               Spacer(),
//               Text("All >", style: TextStyle(color: Colors.grey, fontSize: 14)),
//             ],
//           ),
//         ),
//         ListView.builder(
//           padding: EdgeInsets.symmetric(horizontal: 16),
//           shrinkWrap: true,
//           physics: NeverScrollableScrollPhysics(),
//           itemCount: textLessons.length,
//           itemBuilder: (context, index) {
//             return _buildTextLessonCard(context, textLessons[index]);
//           },
//         ),
//       ],
//     );
//   }

//   // --- WIDGETS ---

//   Widget _buildVideoCardLarge(BuildContext context, LessonModel lesson) {
//     return Container(
//       width: 280,
//       child: InkWell(
//         onTap: () {
//           Navigator.push(
//             context,
//             MaterialPageRoute(
//               builder: (context) => ReaderScreen(lesson: lesson),
//             ),
//           );
//         },
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Image
//             Stack(
//               children: [
//                 ClipRRect(
//                   borderRadius: BorderRadius.circular(12),
//                   child: Container(
//                     height: 160,
//                     width: 280,
//                     color: Colors.grey[200],
//                     child: lesson.imageUrl != null
//                         ? Image.network(lesson.imageUrl!, fit: BoxFit.cover)
//                         : null,
//                   ),
//                 ),
//                 // Difficulty Badge (Overlay)
//                 Positioned(
//                   top: 8,
//                   left: 8,
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
//                 // Progress Bar
//                 Positioned(
//                   bottom: 0,
//                   left: 0,
//                   right: 0,
//                   child: ClipRRect(
//                     borderRadius: BorderRadius.vertical(
//                       bottom: Radius.circular(12),
//                     ),
//                     child: LinearProgressIndicator(
//                       value: 0.05, // Mock progress
//                       minHeight: 4,
//                       backgroundColor: Colors.transparent,
//                       valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//             SizedBox(height: 10),
//             // Info
//             Text(
//               lesson.title,
//               maxLines: 2,
//               overflow: TextOverflow.ellipsis,
//               style: TextStyle(
//                 fontWeight: FontWeight.bold,
//                 fontSize: 16,
//                 height: 1.2,
//               ),
//             ),
//             SizedBox(height: 6),
//             Row(
//               children: [
//                 Icon(Icons.circle, size: 8, color: Colors.blue),
//                 SizedBox(width: 4),
//                 Text(
//                   "200 New",
//                   style: TextStyle(fontSize: 12, color: Colors.grey[600]),
//                 ),
//                 SizedBox(width: 12),
//                 Icon(Icons.circle, size: 8, color: Colors.amber),
//                 SizedBox(width: 4),
//                 Text(
//                   "5 words known",
//                   style: TextStyle(fontSize: 12, color: Colors.grey[600]),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildTextLessonCard(BuildContext context, LessonModel lesson) {
//     return Card(
//       elevation: 0,
//       color: Colors.grey[50],
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(12),
//         side: BorderSide(color: Colors.grey.shade200),
//       ),
//       margin: EdgeInsets.only(bottom: 12),
//       child: ListTile(
//         onTap: () {
//           Navigator.push(
//             context,
//             MaterialPageRoute(
//               builder: (context) => ReaderScreen(lesson: lesson),
//             ),
//           );
//         },
//         contentPadding: EdgeInsets.all(12),
//         leading: Container(
//           width: 50,
//           height: 50,
//           decoration: BoxDecoration(
//             color: Colors.blue.withOpacity(0.1),
//             borderRadius: BorderRadius.circular(8),
//           ),
//           child: Icon(Icons.article, color: Colors.blue),
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
//         trailing: Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
//       ),
//     );
//   }

//   Widget _buildGlobalFilterChips() {
//     return Container(
//       height: 60,
//       padding: EdgeInsets.symmetric(vertical: 10),
//       child: ListView.separated(
//         padding: EdgeInsets.symmetric(horizontal: 16),
//         scrollDirection: Axis.horizontal,
//         itemCount: _globalFilters.length,
//         separatorBuilder: (ctx, i) => SizedBox(width: 8),
//         itemBuilder: (context, index) {
//           final category = _globalFilters[index];
//           final isSelected = _selectedGlobalFilter == category;
//           return GestureDetector(
//             onTap: () => setState(() => _selectedGlobalFilter = category),
//             child: AnimatedContainer(
//               duration: Duration(milliseconds: 200),
//               padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
//               decoration: BoxDecoration(
//                 color: isSelected ? Colors.black : Colors.grey[100],
//                 borderRadius: BorderRadius.circular(20),
//                 border: isSelected
//                     ? null
//                     : Border.all(color: Colors.grey.shade300),
//               ),
//               alignment: Alignment.center,
//               child: Text(
//                 category,
//                 style: TextStyle(
//                   color: isSelected ? Colors.white : Colors.black,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }

//   Widget _buildFilteredList(List<LessonModel> lessons) {
//     final filtered = lessons.where((l) {
//       if (_selectedGlobalFilter == 'Videos') return l.type == 'video';
//       if (_selectedGlobalFilter == 'Audio') return l.type == 'audio';
//       if (_selectedGlobalFilter == 'Text') return l.type == 'text';
//       return true;
//     }).toList();

//     return ListView.separated(
//       padding: EdgeInsets.all(16),
//       itemCount: filtered.length,
//       separatorBuilder: (ctx, i) => SizedBox(height: 16),
//       itemBuilder: (context, index) {
//         return _buildTextLessonCard(context, filtered[index]);
//       },
//     );
//   }

//   Widget _buildEmptyState() {
//     return Center(child: Text("No lessons available"));
//   }

//   void _showCreateLessonDialog(
//     BuildContext context,
//     String userId,
//     String currentLanguage, {
//     required bool isFavoriteByDefault,
//   }) {
//     final titleController = TextEditingController();
//     final contentController = TextEditingController();
//     final lessonBloc = context.read<LessonBloc>();
//     final lessonService = context.read<LessonService>();

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
//               TextField(
//                 controller: contentController,
//                 decoration: InputDecoration(
//                   labelText: 'Content',
//                   border: OutlineInputBorder(),
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
//                   language: currentLanguage,
//                   content: contentController.text,
//                   sentences: sentences,
//                   createdAt: DateTime.now(),
//                   progress: 0,
//                   isFavorite: isFavoriteByDefault,
//                   type: 'text',
//                 );
//                 lessonBloc.add(LessonCreateRequested(lesson));
//                 Navigator.pop(dialogContext);
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
import 'package:linguaflow/blocs/vocabulary/vocabulary_bloc.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/vocabulary_item.dart';
import 'package:linguaflow/screens/reader/reader_screen.dart';
import 'package:linguaflow/services/lesson_service.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Global Filter (Top of screen)
  String _selectedGlobalFilter = 'All';
  final List<String> _globalFilters = ['All', 'Videos', 'Audio', 'Text'];

  // Video Section Specific Filter
  String _videoDifficultyTab = 'All';
  final List<String> _difficultyTabs = [
    'All',
    'Beginner',
    'Intermediate',
    'Advanced',
  ];

  @override
  void initState() {
    super.initState();
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    // Load Vocabulary when Home Screen inits so we have the data for calculations
    context.read<VocabularyBloc>().add(VocabularyLoadRequested(user.id));
  }

  // --- HELPER: Calculate Stats for a Lesson ---
  Map<String, int> _getLessonStats(LessonModel lesson, Map<String, VocabularyItem> vocabMap) {
    // 1. Get all text
    String fullText = lesson.content;
    if (lesson.transcript.isNotEmpty) {
      fullText = lesson.transcript.map((e) => e.text).join(" ");
    }

    // 2. Split into words (Regex matches whitespace)
    final List<String> words = fullText.split(RegExp(r'(\s+)'));
    
    int newWords = 0;
    int knownWords = 0;
    // Use a Set to avoid counting the same word twice in one lesson (Unique word count)
    final Set<String> uniqueWords = {};

    for (var word in words) {
      final cleanWord = word.toLowerCase().trim().replaceAll(RegExp(r'[^\w\s]'), '');
      if (cleanWord.isEmpty) continue;
      if (uniqueWords.contains(cleanWord)) continue; // Skip duplicates

      uniqueWords.add(cleanWord);

      final vocabItem = vocabMap[cleanWord];

      // Logic: 
      // If item is null or status is 0 -> New
      // If status > 0 (1,2,3,4,5) -> Known (or learning)
      if (vocabItem == null || vocabItem.status == 0) {
        newWords++;
      } else {
        knownWords++;
      }
    }

    return {'new': newWords, 'known': knownWords};
  }

  @override
  Widget build(BuildContext context) {
    final user = (context.watch<AuthBloc>().state as AuthAuthenticated).user;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: Row(
          children: [
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: user.currentLanguage,
                icon: Icon(Icons.keyboard_arrow_down, color: Colors.blue),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    context.read<AuthBloc>().add(AuthTargetLanguageChanged(newValue));
                    context.read<LessonBloc>().add(LessonLoadRequested(user.id, newValue));
                    context.read<VocabularyBloc>().add(VocabularyLoadRequested(user.id)); 
                  }
                },
                items: [
                  DropdownMenuItem(value: 'es', child: Text('Spanish')),
                  DropdownMenuItem(value: 'fr', child: Text('French')),
                  DropdownMenuItem(value: 'de', child: Text('German')),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'it', child: Text('Italian')),
                  DropdownMenuItem(value: 'pt', child: Text('Portuguese')),
                  DropdownMenuItem(value: 'ja', child: Text('Japanese')),
                ],
              ),
            ),
            Spacer(),
            // REAL TOTAL KNOWN WORDS COUNT
            BlocBuilder<VocabularyBloc, VocabularyState>(
              builder: (context, vocabState) {
                int totalKnown = 0;
                if (vocabState is VocabularyLoaded) {
                  // FIXED: used vocabState.items instead of vocabulary
                  totalKnown = vocabState.items.where((v) => v.status > 0).length;
                }

                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.emoji_events, size: 16, color: Colors.amber[800]),
                      SizedBox(width: 4),
                      Text(
                        totalKnown.toString(), 
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber[900],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
      // Wrap Body with Vocabulary Builder to pass data down
      body: BlocBuilder<VocabularyBloc, VocabularyState>(
        builder: (context, vocabState) {
          // Prepare a fast lookup map for calculations
          Map<String, VocabularyItem> vocabMap = {};
          if (vocabState is VocabularyLoaded) {
            // FIXED: used vocabState.items instead of vocabulary
            vocabMap = {for (var item in vocabState.items) item.word.toLowerCase(): item};
          }

          return Column(
            children: [
              _buildGlobalFilterChips(),
              Expanded(
                child: BlocBuilder<LessonBloc, LessonState>(
                  builder: (context, lessonState) {
                    if (lessonState is LessonInitial) {
                      context.read<LessonBloc>().add(LessonLoadRequested(user.id, user.currentLanguage));
                      return Center(child: CircularProgressIndicator());
                    }
                    if (lessonState is LessonLoading) return Center(child: CircularProgressIndicator());

                    if (lessonState is LessonLoaded) {
                      if (_selectedGlobalFilter != 'All' && _selectedGlobalFilter != 'Videos') {
                        return _buildFilteredList(lessonState.lessons);
                      }

                      return RefreshIndicator(
                        onRefresh: () async {
                          context.read<LessonBloc>().add(LessonLoadRequested(user.id, user.currentLanguage));
                          context.read<VocabularyBloc>().add(VocabularyLoadRequested(user.id));
                        },
                        child: SingleChildScrollView(
                          padding: EdgeInsets.only(bottom: 80),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // PASS VOCAB MAP TO SECTIONS
                              _buildVideoSection(lessonState.lessons, vocabMap),
                              _buildPopularTextSection(lessonState.lessons),
                            ],
                          ),
                        ),
                      );
                    }
                    return Center(child: Text('Something went wrong'));
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showCreateLessonDialog(
            context,
            user.id,
            user.currentLanguage,
            isFavoriteByDefault: false,
          );
        },
        backgroundColor: Colors.blue,
        icon: Icon(Icons.add),
        label: Text('New Lesson'),
      ),
    );
  }

  // --- SECTION 1: VIDEO LESSONS ---
  Widget _buildVideoSection(List<LessonModel> allLessons, Map<String, VocabularyItem> vocabMap) {
    final allVideos = allLessons.where((l) => l.type == 'video').toList();

    final displayVideos = _videoDifficultyTab == 'All'
        ? allVideos
        : allVideos.where((l) => l.difficulty.toLowerCase() == _videoDifficultyTab.toLowerCase()).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Row(
            children: [
              Text(
                "Guided Courses",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              SizedBox(width: 8),
              Icon(Icons.auto_awesome, size: 18, color: Colors.blue),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: _difficultyTabs.map((tab) {
              final isSelected = _videoDifficultyTab == tab;
              return Padding(
                padding: const EdgeInsets.only(right: 24.0, bottom: 12),
                child: InkWell(
                  onTap: () => setState(() => _videoDifficultyTab = tab),
                  child: Column(
                    children: [
                      Text(
                        tab,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.black : Colors.grey[500],
                        ),
                      ),
                      if (isSelected)
                        Container(
                          margin: EdgeInsets.only(top: 4),
                          height: 2,
                          width: 20,
                          color: Colors.red,
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        if (displayVideos.isEmpty)
          Container(
            height: 200,
            alignment: Alignment.center,
            child: Text("No videos found", style: TextStyle(color: Colors.grey)),
          )
        else
          SizedBox(
            height: 260,
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: displayVideos.length,
              separatorBuilder: (ctx, i) => SizedBox(width: 16),
              itemBuilder: (context, index) {
                return _buildVideoCardLarge(context, displayVideos[index], vocabMap);
              },
            ),
          ),
      ],
    );
  }

  // --- SECTION 2: TEXT LESSONS ---
  Widget _buildPopularTextSection(List<LessonModel> allLessons) {
    final textLessons = allLessons.where((l) => l.type == 'text').toList();
    if (textLessons.isEmpty) return SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Row(
            children: [
              Text("Popular Text Lessons", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Spacer(),
              Text("All >", style: TextStyle(color: Colors.grey, fontSize: 14)),
            ],
          ),
        ),
        ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: 16),
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: textLessons.length,
          itemBuilder: (context, index) {
            return _buildTextLessonCard(context, textLessons[index]);
          },
        ),
      ],
    );
  }

  // --- WIDGETS ---

  Widget _buildVideoCardLarge(BuildContext context, LessonModel lesson, Map<String, VocabularyItem> vocabMap) {
    // CALCULATE STATS HERE
    final stats = _getLessonStats(lesson, vocabMap);
    final int newCount = stats['new']!;
    final int knownCount = stats['known']!;

    return Container(
      width: 280,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReaderScreen(lesson: lesson),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 160,
                    width: 280,
                    color: Colors.grey[200],
                    child: lesson.imageUrl != null
                        ? Image.network(lesson.imageUrl!, fit: BoxFit.cover)
                        : null,
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      lesson.difficulty.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                    child: LinearProgressIndicator(
                      value: (knownCount + newCount) == 0 ? 0 : knownCount / (knownCount + newCount),
                      minHeight: 4,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Text(
              lesson.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, height: 1.2),
            ),
            SizedBox(height: 6),
            // REAL STATS DISPLAY
            Row(
              children: [
                Icon(Icons.circle, size: 8, color: Colors.blue),
                SizedBox(width: 4),
                Text(
                  "$newCount New",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                SizedBox(width: 12),
                Icon(Icons.circle, size: 8, color: Colors.amber),
                SizedBox(width: 4),
                Text(
                  "$knownCount known",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextLessonCard(BuildContext context, LessonModel lesson) {
    return Card(
      elevation: 0,
      color: Colors.grey[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReaderScreen(lesson: lesson),
            ),
          );
        },
        contentPadding: EdgeInsets.all(12),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.article, color: Colors.blue),
        ),
        title: Text(lesson.title, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          lesson.content.replaceAll('\n', ' '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      ),
    );
  }

  Widget _buildGlobalFilterChips() {
    return Container(
      height: 60,
      padding: EdgeInsets.symmetric(vertical: 10),
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _globalFilters.length,
        separatorBuilder: (ctx, i) => SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = _globalFilters[index];
          final isSelected = _selectedGlobalFilter == category;
          return GestureDetector(
            onTap: () => setState(() => _selectedGlobalFilter = category),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.black : Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
                border: isSelected ? null : Border.all(color: Colors.grey.shade300),
              ),
              alignment: Alignment.center,
              child: Text(
                category,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilteredList(List<LessonModel> lessons) {
    final filtered = lessons.where((l) {
      if (_selectedGlobalFilter == 'Videos') return l.type == 'video';
      if (_selectedGlobalFilter == 'Audio') return l.type == 'audio';
      if (_selectedGlobalFilter == 'Text') return l.type == 'text';
      return true;
    }).toList();

    return ListView.separated(
      padding: EdgeInsets.all(16),
      itemCount: filtered.length,
      separatorBuilder: (ctx, i) => SizedBox(height: 16),
      itemBuilder: (context, index) {
        return _buildTextLessonCard(context, filtered[index]);
      },
    );
  }

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
                decoration: InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
              ),
              SizedBox(height: 16),
              TextField(
                controller: contentController,
                decoration: InputDecoration(labelText: 'Content', border: OutlineInputBorder()),
                maxLines: 6,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty && contentController.text.isNotEmpty) {
                final sentences = lessonService.splitIntoSentences(contentController.text);
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
              }
            },
            child: Text('Create'),
          ),
        ],
      ),
    );
  }
}
