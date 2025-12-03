// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:linguaflow/blocs/auth/auth_bloc.dart';
// import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';
// import 'package:linguaflow/blocs/vocabulary/vocabulary_bloc.dart';
// import 'package:linguaflow/models/lesson_model.dart';
// import 'package:linguaflow/models/vocabulary_item.dart';
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

//   // Video Section Specific Filter
//   String _videoDifficultyTab = 'All';
//   final List<String> _difficultyTabs = [
//     'All',
//     'Beginner',
//     'Intermediate',
//     'Advanced',
//   ];

//   @override
//   void initState() {
//     super.initState();
//     final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
//     // Load Vocabulary when Home Screen inits so we have the data for calculations
//     context.read<VocabularyBloc>().add(VocabularyLoadRequested(user.id));
//   }

//   // --- HELPER: Calculate Stats for a Lesson ---
//   Map<String, int> _getLessonStats(
//     LessonModel lesson,
//     Map<String, VocabularyItem> vocabMap,
//   ) {
//     // 1. Get all text
//     String fullText = lesson.content;
//     if (lesson.transcript.isNotEmpty) {
//       fullText = lesson.transcript.map((e) => e.text).join(" ");
//     }

//     // 2. Split into words (Regex matches whitespace)
//     final List<String> words = fullText.split(RegExp(r'(\s+)'));

//     int newWords = 0;
//     int knownWords = 0;
//     // Use a Set to avoid counting the same word twice in one lesson (Unique word count)
//     final Set<String> uniqueWords = {};

//     for (var word in words) {
//       final cleanWord = word.toLowerCase().trim().replaceAll(
//         RegExp(r'[^\w\s]'),
//         '',
//       );
//       if (cleanWord.isEmpty) continue;
//       if (uniqueWords.contains(cleanWord)) continue; // Skip duplicates

//       uniqueWords.add(cleanWord);

//       final vocabItem = vocabMap[cleanWord];

//       // Logic:
//       // If item is null or status is 0 -> New
//       // If status > 0 (1,2,3,4,5) -> Known (or learning)
//       if (vocabItem == null || vocabItem.status == 0) {
//         newWords++;
//       } else {
//         knownWords++;
//       }
//     }

//     return {'new': newWords, 'known': knownWords};
//   }

//   void _showStatsDialog(
//     BuildContext context,
//     int knownWords,
//     String languageCode,
//   ) {
//     // --- CEFR Level Logic ---
//     String currentLevel = "Beginner";
//     String nextLevel = "A1";
//     int nextGoal = 500;
//     double progress = 0.0;

//     if (knownWords < 500) {
//       currentLevel = "Newcomer";
//       nextLevel = "A1";
//       nextGoal = 500;
//       progress = knownWords / 500;
//     } else if (knownWords < 1000) {
//       currentLevel = "A1 (Beginner)";
//       nextLevel = "A2";
//       nextGoal = 1000;
//       progress = (knownWords - 500) / 500;
//     } else if (knownWords < 2000) {
//       currentLevel = "A2 (Elementary)";
//       nextLevel = "B1";
//       nextGoal = 2000;
//       progress = (knownWords - 1000) / 1000;
//     } else if (knownWords < 4000) {
//       currentLevel = "B1 (Intermediate)";
//       nextLevel = "B2";
//       nextGoal = 4000;
//       progress = (knownWords - 2000) / 2000;
//     } else if (knownWords < 8000) {
//       currentLevel = "B2 (Upper Int.)";
//       nextLevel = "C1";
//       nextGoal = 8000;
//       progress = (knownWords - 4000) / 4000;
//     } else {
//       currentLevel = "C1 (Advanced)";
//       nextLevel = "C2";
//       nextGoal = 16000;
//       progress = (knownWords - 8000) / 8000;
//     }

//     // Language Name Map
//     final langNames = {
//       'es': 'Spanish',
//       'fr': 'French',
//       'de': 'German',
//       'en': 'English',
//       'it': 'Italian',
//       'pt': 'Portuguese',
//       'ja': 'Japanese',
//     };
//     final langName = langNames[languageCode] ?? 'Target Language';

//     showModalBottomSheet(
//       context: context,
//       backgroundColor: Colors.transparent,
//       isScrollControlled: true, // IMPORTANT: Allows the sheet to size correctly
//       builder: (context) => Container(
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//         ),
//         // FIX: Add system bottom padding to the standard 24 padding
//         padding: EdgeInsets.fromLTRB(
//           24,
//           24,
//           24,
//           24 + MediaQuery.of(context).viewPadding.bottom,
//         ),
//         child: Column(
//           mainAxisSize: MainAxisSize.min, // Shrinks to fit content
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 Container(
//                   padding: EdgeInsets.all(12),
//                   decoration: BoxDecoration(
//                     color: Colors.amber[100],
//                     shape: BoxShape.circle,
//                   ),
//                   child: Icon(
//                     Icons.auto_graph,
//                     color: Colors.amber[800],
//                     size: 28,
//                   ),
//                 ),
//                 SizedBox(width: 16),
//                 Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       "$langName Progress",
//                       style: TextStyle(
//                         fontSize: 18,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.grey[800],
//                       ),
//                     ),
//                     Text(
//                       "$knownWords words known",
//                       style: TextStyle(fontSize: 14, color: Colors.grey[600]),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//             Divider(height: 32),

//             // Level Badge
//             Center(
//               child: Column(
//                 children: [
//                   Text(
//                     "Current Level",
//                     style: TextStyle(
//                       color: Colors.grey,
//                       fontSize: 12,
//                       fontWeight: FontWeight.bold,
//                       letterSpacing: 1,
//                     ),
//                   ),
//                   SizedBox(height: 4),
//                   Text(
//                     currentLevel,
//                     style: TextStyle(
//                       fontSize: 28,
//                       fontWeight: FontWeight.w800,
//                       color: Colors.blue[800],
//                     ),
//                   ),
//                 ],
//               ),
//             ),

//             SizedBox(height: 24),

//             // Progress Bar
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text(
//                   "Next Goal: $nextLevel",
//                   style: TextStyle(fontWeight: FontWeight.bold),
//                 ),
//                 Text(
//                   "${nextGoal - knownWords} words to go",
//                   style: TextStyle(color: Colors.grey[600], fontSize: 12),
//                 ),
//               ],
//             ),
//             SizedBox(height: 8),
//             ClipRRect(
//               borderRadius: BorderRadius.circular(10),
//               child: LinearProgressIndicator(
//                 value: progress,
//                 minHeight: 10,
//                 backgroundColor: Colors.grey[200],
//                 valueColor: AlwaysStoppedAnimation(Colors.blue),
//               ),
//             ),
//             SizedBox(height: 24),

//             // Motivation Text
//             Container(
//               padding: EdgeInsets.all(16),
//               decoration: BoxDecoration(
//                 color: Colors.blue[50],
//                 borderRadius: BorderRadius.circular(12),
//                 border: Border.all(color: Colors.blue.withOpacity(0.2)),
//               ),
//               child: Row(
//                 children: [
//                   Icon(Icons.lightbulb_outline, color: Colors.blue[700]),
//                   SizedBox(width: 12),
//                   Expanded(
//                     child: Text(
//                       "Knowing ${nextGoal - knownWords} more words will help you understand roughly 10% more of daily conversations!",
//                       style: TextStyle(
//                         color: Colors.blue[900],
//                         fontSize: 13,
//                         height: 1.4,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             SizedBox(height: 16),
//             SizedBox(
//               width: double.infinity,
//               child: ElevatedButton(
//                 onPressed: () => Navigator.pop(context),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.black,
//                   padding: EdgeInsets.symmetric(vertical: 16),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                 ),
//                 child: Text(
//                   "Keep Learning",
//                   style: TextStyle(color: Colors.white),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

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
//             Container(
//               padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//               decoration: BoxDecoration(
//                 // 1. The "Glassy" White/Grey Background
//                 color: Colors.grey[50],
//                 borderRadius: BorderRadius.circular(20),
//                 // 2. The Subtle Glass Border
//                 border: Border.all(color: Colors.grey.shade300, width: 1),
//                 // 3. Soft Shadow for depth
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.grey.withOpacity(0.1),
//                     blurRadius: 10,
//                     offset: Offset(0, 4),
//                   ),
//                 ],
//               ),
//               child: DropdownButtonHideUnderline(
//                 child: DropdownButton<String>(
//                   value: user.currentLanguage,
//                   icon: Padding(
//                     padding: const EdgeInsets.only(left: 8),
//                     child: Icon(
//                       Icons.keyboard_arrow_down_rounded,
//                       size: 20,
//                       color: Colors.grey[700],
//                     ),
//                   ),
//                   isDense: true, // Reduces default internal padding
//                   dropdownColor: Colors.white,
//                   style: TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.w700,
//                     color: Colors.grey[800],
//                     fontFamily:
//                         'Roboto', // Ensures emojis render well on some devices
//                   ),
//                   onChanged: (String? newValue) {
//                     if (newValue != null) {
//                       context.read<AuthBloc>().add(
//                         AuthTargetLanguageChanged(newValue),
//                       );
//                       context.read<LessonBloc>().add(
//                         LessonLoadRequested(user.id, newValue),
//                       );
//                       context.read<VocabularyBloc>().add(
//                         VocabularyLoadRequested(user.id),
//                       );
//                     }
//                   },
//                   items: [
//                     DropdownMenuItem(value: 'es', child: Text('🇪🇸 Spanish')),
//                     DropdownMenuItem(value: 'fr', child: Text('🇫🇷 French')),
//                     DropdownMenuItem(value: 'de', child: Text('🇩🇪 German')),
//                     DropdownMenuItem(value: 'en', child: Text('🇬🇧 English')),
//                     DropdownMenuItem(value: 'it', child: Text('🇮🇹 Italian')),
//                     DropdownMenuItem(
//                       value: 'pt',
//                       child: Text('🇵🇹 Portuguese'),
//                     ),
//                     DropdownMenuItem(value: 'ja', child: Text('🇯🇵 Japanese')),
//                   ],
//                 ),
//               ),
//             ),
//             Spacer(),

//             // --- STATS INDICATOR ---
//             BlocBuilder<VocabularyBloc, VocabularyState>(
//               builder: (context, vocabState) {
//                 int knownCount = 0;
//                 // Only count words for the CURRENT language
//                 if (vocabState is VocabularyLoaded) {
//                   knownCount = vocabState.items
//                       .where(
//                         (v) =>
//                             v.status > 0 && v.language == user.currentLanguage,
//                       )
//                       .length;
//                 }

//                 return Material(
//                   color: Colors.transparent,
//                   child: InkWell(
//                     borderRadius: BorderRadius.circular(20),
//                     onTap: () => _showStatsDialog(
//                       context,
//                       knownCount,
//                       user.currentLanguage,
//                     ),
//                     child: Container(
//                       padding: EdgeInsets.symmetric(
//                         horizontal: 12,
//                         vertical: 6,
//                       ),
//                       decoration: BoxDecoration(
//                         color: Colors.amber.withOpacity(0.15),
//                         borderRadius: BorderRadius.circular(20),
//                         border: Border.all(
//                           color: Colors.amber.withOpacity(0.3),
//                         ),
//                       ),
//                       child: Row(
//                         children: [
//                           Icon(
//                             Icons.emoji_events_rounded,
//                             size: 16,
//                             color: Colors.amber[800],
//                           ),
//                           SizedBox(width: 6),
//                           Text(
//                             knownCount.toString(),
//                             style: TextStyle(
//                               fontSize: 14,
//                               fontWeight: FontWeight.bold,
//                               color: Colors.amber[900],
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ],
//         ),
//       ),
//       // Wrap Body with Vocabulary Builder to pass data down
//       body: BlocBuilder<VocabularyBloc, VocabularyState>(
//         builder: (context, vocabState) {
//           // Prepare a fast lookup map for calculations
//           Map<String, VocabularyItem> vocabMap = {};
//           if (vocabState is VocabularyLoaded) {
//             // FIXED: used vocabState.items instead of vocabulary
//             vocabMap = {
//               for (var item in vocabState.items) item.word.toLowerCase(): item,
//             };
//           }

//           return Column(
//             children: [
//               _buildGlobalFilterChips(),
//               Expanded(
//                 child: BlocBuilder<LessonBloc, LessonState>(
//                   builder: (context, lessonState) {
//                     if (lessonState is LessonInitial) {
//                       context.read<LessonBloc>().add(
//                         LessonLoadRequested(user.id, user.currentLanguage),
//                       );
//                       return Center(child: CircularProgressIndicator());
//                     }
//                     if (lessonState is LessonLoading)
//                       return Center(child: CircularProgressIndicator());

//                     if (lessonState is LessonLoaded) {
//                       if (_selectedGlobalFilter != 'All' &&
//                           _selectedGlobalFilter != 'Videos') {
//                         return _buildFilteredList(lessonState.lessons);
//                       }

//                       return RefreshIndicator(
//                         onRefresh: () async {
//                           context.read<LessonBloc>().add(
//                             LessonLoadRequested(user.id, user.currentLanguage),
//                           );
//                           context.read<VocabularyBloc>().add(
//                             VocabularyLoadRequested(user.id),
//                           );
//                         },
//                         child: SingleChildScrollView(
//                           padding: EdgeInsets.only(bottom: 0),
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               // PASS VOCAB MAP TO SECTIONS
//                               _buildVideoSection(lessonState.lessons, vocabMap),
//                               _buildPopularTextSection(lessonState.lessons),
//                             ],
//                           ),
//                         ),
//                       );
//                     }
//                     return Center(child: Text('Something went wrong'));
//                   },
//                 ),
//               ),
//             ],
//           );
//         },
//       ),
     
//       floatingActionButton: Material(
//         color: Colors.transparent,
//         elevation: 10,
//         shadowColor: Colors.black.withOpacity(0.3),
//         borderRadius: BorderRadius.circular(30),
//         child: InkWell(
//           onTap: () {
//             _showCreateLessonDialog(
//               context,
//               user.id,
//               user.currentLanguage,
//               isFavoriteByDefault: false,
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
//                   'Import',
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

//   // --- SECTION 1: VIDEO LESSONS ---
//   Widget _buildVideoSection(
//     List<LessonModel> allLessons,
//     Map<String, VocabularyItem> vocabMap,
//   ) {
//     final allVideos = allLessons.where((l) => l.type == 'video').toList();

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
//         Padding(
//           padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
//           child: Row(
//             children: [
//               Text(
//                 "Guided Courses",
//                 style: TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.black45,
//                 ),
//               ),
//             ],
//           ),
//         ),
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
//                           color: Colors.red,
//                         ),
//                     ],
//                   ),
//                 ),
//               );
//             }).toList(),
//           ),
//         ),
//         if (displayVideos.isEmpty)
//           Container(
//             height: 200,
//             alignment: Alignment.center,
//             child: Text(
//               "No videos found",
//               style: TextStyle(color: Colors.grey),
//             ),
//           )
//         else
//           SizedBox(
//             height: 250,
//             child: ListView.separated(
//               padding: EdgeInsets.symmetric(horizontal: 16),
//               scrollDirection: Axis.horizontal,
//               itemCount: displayVideos.length,
//               separatorBuilder: (ctx, i) => SizedBox(width: 16),
//               itemBuilder: (context, index) {
//                 return _buildVideoCardLarge(
//                   context,
//                   displayVideos[index],
//                   vocabMap,
//                 );
//               },
//             ),
//           ),
//       ],
//     );
//   }

//   // --- SECTION 2: TEXT LESSONS ---
//   Widget _buildPopularTextSection(List<LessonModel> allLessons) {
//     final textLessons = allLessons.where((l) => l.type == 'text').toList();
//     if (textLessons.isEmpty) return SizedBox();

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Padding(
//           padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
//           child: Row(
//             children: [
//               Text(
//                 "Your Imported Lessons",
//                 style: TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.black45,
//                 ),
//               ),
//               Spacer(),
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

//   Widget _buildVideoCardLarge(
//     BuildContext context,
//     LessonModel lesson,
//     Map<String, VocabularyItem> vocabMap,
//   ) {
//     // CALCULATE STATS HERE
//     final stats = _getLessonStats(lesson, vocabMap);
//     final int newCount = stats['new']!;
//     final int knownCount = stats['known']!;

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
//                 Positioned(
//                   bottom: 0,
//                   left: 0,
//                   right: 0,
//                   child: ClipRRect(
//                     borderRadius: BorderRadius.vertical(
//                       bottom: Radius.circular(12),
//                     ),
//                     child: LinearProgressIndicator(
//                       value: (knownCount + newCount) == 0
//                           ? 0
//                           : knownCount / (knownCount + newCount),
//                       minHeight: 4,
//                       backgroundColor: Colors.transparent,
//                       valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//             SizedBox(height: 10),
//             Text(
//               lesson.title,
//               maxLines: 2,
//               overflow: TextOverflow.ellipsis,
//               style: TextStyle(
//                 fontWeight: FontWeight.bold,
//                 fontSize: 16,
//                 height: 1.2,
//                 color: Colors.grey[600],
//               ),
//             ),
//             SizedBox(height: 6),

//             // REAL STATS DISPLAY
//             Expanded(
//               child: Row(
//                 children: [
//                   Icon(Icons.circle, size: 8, color: Colors.blue),
//                   SizedBox(width: 4),
//                   Text(
//                     "$newCount New",
//                     style: TextStyle(fontSize: 12, color: Colors.grey[600]),
//                   ),
//                   SizedBox(width: 12),
//                   Icon(Icons.circle, size: 8, color: Colors.amber),
//                   SizedBox(width: 4),
//                   Text(
//                     "$knownCount known",
//                     style: TextStyle(fontSize: 12, color: Colors.grey[600]),
//                   ),
//                   Spacer(),
//                   IconButton(
//                     icon: Icon(
//                       Icons.more_vert,
//                       color: Colors.grey[400],
//                       size: 12,
//                     ),
//                     constraints: BoxConstraints(), // Removes default padding
//                     padding: EdgeInsets.zero,
//                     onPressed: () => _showLessonOptions(context, lesson),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   void _showLessonOptions(BuildContext context, LessonModel lesson) {
//     showModalBottomSheet(
//       context: context,
//       backgroundColor: Colors.transparent,
//       isScrollControlled:
//           true, // Required to handle the bottom padding correctly
//       builder: (builderContext) => Container(
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//         ),
//         // FIX: Add system bottom padding so buttons aren't hidden behind nav bar
//         padding: EdgeInsets.only(
//           top: 20,
//           left: 0,
//           right: 0,
//           bottom: MediaQuery.of(builderContext).viewPadding.bottom + 20,
//         ),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             // Handle Bar
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

//             // Favorite Option
//             ListTile(
//               leading: Container(
//                 padding: EdgeInsets.all(8),
//                 decoration: BoxDecoration(
//                   color: lesson.isFavorite
//                       ? Colors.amber[50]
//                       : Colors.grey[100],
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
//                 // 1. Get current user ID (Assuming you have access to 'user' object in this scope)
//                 // If 'user' isn't available here, pass it into _showLessonOptions function
//                 final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;

//                 // 2. Create updated lesson
//                 final updatedLesson = lesson.copyWith(
//                   isFavorite: !lesson.isFavorite,
//                   userId: user.id, // <--- IMPORTANT: Ensure lesson belongs to user
//                 );
                
//                 // 3. Update via Bloc
//                 context.read<LessonBloc>().add(
//                   LessonUpdateRequested(updatedLesson),
//                 );
                
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

//             // Delete Option
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
//                 // Use the parent 'context' to find the Bloc
//                 context.read<LessonBloc>().add(
//                   LessonDeleteRequested(lesson.id),
//                 );
//                 Navigator.pop(builderContext);
//               },
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
//           style: TextStyle(
//             fontWeight: FontWeight.bold,
//             color: Colors.grey[600],
//           ),
//         ),
//         subtitle: Text(
//           lesson.content.replaceAll('\n', ' '),
//           maxLines: 1,
//           overflow: TextOverflow.ellipsis,
//         ),
//         trailing: IconButton(
//           icon: Icon(Icons.more_vert, color: Colors.grey[400], size: 12),
//           constraints: BoxConstraints(), // Removes default padding
//           padding: EdgeInsets.zero,
//           onPressed: () => _showLessonOptions(context, lesson),
//         ),
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
  String _selectedGlobalFilter = 'All';
  final List<String> _globalFilters = ['All', 'Videos', 'Audio', 'Text'];

  String _videoDifficultyTab = 'All';
  final List<String> _difficultyTabs = ['All', 'Beginner', 'Intermediate', 'Advanced'];

  @override
  void initState() {
    super.initState();
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    context.read<VocabularyBloc>().add(VocabularyLoadRequested(user.id));
  }

  Map<String, int> _getLessonStats(LessonModel lesson, Map<String, VocabularyItem> vocabMap) {
    String fullText = lesson.content;
    if (lesson.transcript.isNotEmpty) {
      fullText = lesson.transcript.map((e) => e.text).join(" ");
    }

    final List<String> words = fullText.split(RegExp(r'(\s+)'));
    int newWords = 0;
    int knownWords = 0;
    final Set<String> uniqueWords = {};

    for (var word in words) {
      final cleanWord = word.toLowerCase().trim().replaceAll(RegExp(r'[^\w\s]'), '');
      if (cleanWord.isEmpty) continue;
      if (uniqueWords.contains(cleanWord)) continue; 

      uniqueWords.add(cleanWord);
      final vocabItem = vocabMap[cleanWord];

      if (vocabItem == null || vocabItem.status == 0) {
        newWords++;
      } else {
        knownWords++;
      }
    }
    return {'new': newWords, 'known': knownWords};
  }

  void _showStatsDialog(BuildContext context, int knownWords, String languageCode) {
    // ... [CEFR Logic - Kept same as previous] ...
    String currentLevel = "Beginner";
    String nextLevel = "A1";
    int nextGoal = 500;
    double progress = 0.0;

    if (knownWords < 500) {
      currentLevel = "Newcomer";
      nextLevel = "A1";
      nextGoal = 500;
      progress = knownWords / 500;
    } else if (knownWords < 1000) {
      currentLevel = "A1 (Beginner)";
      nextLevel = "A2";
      nextGoal = 1000;
      progress = (knownWords - 500) / 500;
    } else if (knownWords < 2000) {
      currentLevel = "A2 (Elementary)";
      nextLevel = "B1";
      nextGoal = 2000;
      progress = (knownWords - 1000) / 1000;
    } else if (knownWords < 4000) {
      currentLevel = "B1 (Intermediate)";
      nextLevel = "B2";
      nextGoal = 4000;
      progress = (knownWords - 2000) / 2000;
    } else if (knownWords < 8000) {
      currentLevel = "B2 (Upper Int.)";
      nextLevel = "C1";
      nextGoal = 8000;
      progress = (knownWords - 4000) / 4000;
    } else {
      currentLevel = "C1 (Advanced)";
      nextLevel = "C2";
      nextGoal = 16000;
      progress = (knownWords - 8000) / 8000;
    }

    final langNames = {
      'es': 'Spanish', 'fr': 'French', 'de': 'German', 'en': 'English',
      'it': 'Italian', 'pt': 'Portuguese', 'ja': 'Japanese'
    };
    final langName = langNames[languageCode] ?? 'Target Language';

    // THEME AWARE COLORS
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true, 
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(context).viewPadding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min, 
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.auto_graph, color: Colors.amber[800], size: 28),
                ),
                SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$langName Progress",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    Text(
                      "$knownWords words known",
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                )
              ],
            ),
            Divider(height: 32),
            Center(
              child: Column(
                children: [
                  Text("Current Level", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  SizedBox(height: 4),
                  Text(
                    currentLevel,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.blue),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Next Goal: $nextLevel", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                Text("${nextGoal - knownWords} words to go", style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(Colors.blue),
              ),
            ),
            SizedBox(height: 24),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.blue),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Knowing ${nextGoal - knownWords} more words will help you understand roughly 10% more of daily conversations!",
                      style: TextStyle(color: isDark ? Colors.blue[100] : Colors.blue[900], fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.white : Colors.black,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text("Keep Learning"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = (context.watch<AuthBloc>().state as AuthAuthenticated).user;
    
    // THEME VARIABLES
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final cardColor = Theme.of(context).cardColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bgColor,
        foregroundColor: textColor,
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey[50],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300, width: 1),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: user.currentLanguage,
                  icon: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Colors.grey),
                  ),
                  isDense: true,
                  dropdownColor: isDark ? Color(0xFF2C2C2C) : Colors.white,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor, fontFamily: 'Roboto'),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      context.read<AuthBloc>().add(AuthTargetLanguageChanged(newValue));
                      context.read<LessonBloc>().add(LessonLoadRequested(user.id, newValue));
                      context.read<VocabularyBloc>().add(VocabularyLoadRequested(user.id));
                    }
                  },
                  items: [
                    DropdownMenuItem(value: 'es', child: Text('🇪🇸 Spanish')),
                    DropdownMenuItem(value: 'fr', child: Text('🇫🇷 French')),
                    DropdownMenuItem(value: 'de', child: Text('🇩🇪 German')),
                    DropdownMenuItem(value: 'en', child: Text('🇬🇧 English')),
                    DropdownMenuItem(value: 'it', child: Text('🇮🇹 Italian')),
                    DropdownMenuItem(value: 'pt', child: Text('🇵🇹 Portuguese')),
                    DropdownMenuItem(value: 'ja', child: Text('🇯🇵 Japanese')),
                  ],
                ),
              ),
            ),
            Spacer(),
            BlocBuilder<VocabularyBloc, VocabularyState>(
              builder: (context, vocabState) {
                int knownCount = 0;
                if (vocabState is VocabularyLoaded) {
                  knownCount = vocabState.items.where((v) => v.status > 0 && v.language == user.currentLanguage).length;
                }
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _showStatsDialog(context, knownCount, user.currentLanguage),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.amber.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.emoji_events_rounded, size: 16, color: Colors.amber[800]),
                          SizedBox(width: 6),
                          Text(
                            knownCount.toString(),
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.amber[900]),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: BlocBuilder<VocabularyBloc, VocabularyState>(
        builder: (context, vocabState) {
          Map<String, VocabularyItem> vocabMap = {};
          if (vocabState is VocabularyLoaded) {
            vocabMap = {for (var item in vocabState.items) item.word.toLowerCase(): item};
          }

          return Column(
            children: [
              _buildGlobalFilterChips(isDark),
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
                        return _buildFilteredList(lessonState.lessons, isDark);
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
                              _buildVideoSection(lessonState.lessons, vocabMap, isDark, textColor),
                              _buildPopularTextSection(lessonState.lessons, isDark, textColor),
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
        isFavoriteByDefault: false,
      );
    },
    borderRadius: BorderRadius.circular(30),
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        // The "Glassy" Dark Color
        color: const Color(0xFF1E1E1E).withOpacity(0.90),
        borderRadius: BorderRadius.circular(30),
        // The "Glass" Edge Highlight
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
            'Import',
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

      // floatingActionButton: FloatingActionButton.extended(
      //   onPressed: () {
      //     _showCreateLessonDialog(context, user.id, user.currentLanguage, isFavoriteByDefault: false);
      //   },
      //   backgroundColor: Colors.blue,
      //   icon: Icon(Icons.add),
      //   label: Text('New Lesson'),
      // ),
    );
  }

  // --- SECTION 1: VIDEO LESSONS ---
  Widget _buildVideoSection(List<LessonModel> allLessons, Map<String, VocabularyItem> vocabMap, bool isDark, Color? textColor) {
    final allVideos = allLessons.where((l) => l.type == 'video').toList();
    final displayVideos = _videoDifficultyTab == 'All'
        ? allVideos
        : allVideos.where((l) => l.difficulty.toLowerCase() == _videoDifficultyTab.toLowerCase()).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Text(
                "Guided Courses",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black45),
              ),
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
                          color: isSelected ? (isDark ? Colors.white : Colors.black) : Colors.grey[500],
                        ),
                      ),
                      if (isSelected)
                        Container(margin: EdgeInsets.only(top: 4), height: 2, width: 20, color: Colors.red),
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
            height: 250,
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: displayVideos.length,
              separatorBuilder: (ctx, i) => SizedBox(width: 16),
              itemBuilder: (context, index) {
                return _buildVideoCardLarge(context, displayVideos[index], vocabMap, isDark, textColor);
              },
            ),
          ),
      ],
    );
  }

  // --- SECTION 2: TEXT LESSONS ---
  Widget _buildPopularTextSection(List<LessonModel> allLessons, bool isDark, Color? textColor) {
    final textLessons = allLessons.where((l) => l.type == 'text').toList();
    if (textLessons.isEmpty) return SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              Text(
                "Your Imported Lessons",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black45),
              ),
              Spacer(),
            ],
          ),
        ),
        ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: 16),
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: textLessons.length,
          itemBuilder: (context, index) {
            return _buildTextLessonCard(context, textLessons[index], isDark);
          },
        ),
      ],
    );
  }

  // --- WIDGETS ---

  Widget _buildVideoCardLarge(BuildContext context, LessonModel lesson, Map<String, VocabularyItem> vocabMap, bool isDark, Color? textColor) {
    final stats = _getLessonStats(lesson, vocabMap);
    final int newCount = stats['new']!;
    final int knownCount = stats['known']!;

    return Container(
      width: 280,
      child: InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => ReaderScreen(lesson: lesson)));
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
                    color: isDark ? Colors.white10 : Colors.grey[200],
                    child: lesson.imageUrl != null ? Image.network(lesson.imageUrl!, fit: BoxFit.cover) : null,
                  ),
                ),
                Positioned(
                  top: 8, left: 8,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(4)),
                    child: Text(lesson.difficulty.toUpperCase(), style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
                Positioned(
                  bottom: 0, left: 0, right: 0,
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
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, height: 1.2, color: isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
            SizedBox(height: 6),
            Expanded(
              child: Row(
                children: [
                  Icon(Icons.circle, size: 8, color: Colors.blue),
                  SizedBox(width: 4),
                  Text("$newCount New", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  SizedBox(width: 12),
                  Icon(Icons.circle, size: 8, color: Colors.amber),
                  SizedBox(width: 4),
                  Text("$knownCount known", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.more_vert, color: Colors.grey, size: 16),
                    constraints: BoxConstraints(),
                    padding: EdgeInsets.zero,
                    onPressed: () => _showLessonOptions(context, lesson, isDark),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
        padding: EdgeInsets.only(top: 20, left: 0, right: 0, bottom: MediaQuery.of(builderContext).viewPadding.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40, height: 4, margin: EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(color: lesson.isFavorite ? Colors.amber.withOpacity(0.1) : (isDark ? Colors.white10 : Colors.grey[100]), shape: BoxShape.circle),
                child: Icon(lesson.isFavorite ? Icons.star : Icons.star_border, color: lesson.isFavorite ? Colors.amber : Colors.grey),
              ),
              title: Text(lesson.isFavorite ? 'Remove from Favorites' : 'Add to Favorites', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
              subtitle: Text(lesson.isFavorite ? 'Removed from library.' : 'Saved to library.', style: TextStyle(color: Colors.grey)),
              onTap: () {
                final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
                final updatedLesson = lesson.copyWith(isFavorite: !lesson.isFavorite, userId: user.id);
                context.read<LessonBloc>().add(LessonUpdateRequested(updatedLesson));
                Navigator.pop(builderContext);
              },
            ),
            Divider(color: Colors.grey[800]),
            ListTile(
              leading: Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.delete_outline, color: Colors.red)),
              title: Text('Delete Lesson', style: TextStyle(color: Colors.red)),
              onTap: () {
                context.read<LessonBloc>().add(LessonDeleteRequested(lesson.id));
                Navigator.pop(builderContext);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextLessonCard(BuildContext context, LessonModel lesson, bool isDark) {
    return Card(
      elevation: 0,
      color: isDark ? Colors.white10 : Colors.grey[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isDark ? Colors.transparent : Colors.grey.shade200)),
      margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => ReaderScreen(lesson: lesson)));
        },
        contentPadding: EdgeInsets.all(12),
        leading: Container(
          width: 50, height: 50,
          decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.article, color: Colors.blue),
        ),
        title: Text(lesson.title, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.grey[600])),
        subtitle: Text(lesson.content.replaceAll('\n', ' '), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey)),
        trailing: IconButton(
          icon: Icon(Icons.more_vert, color: Colors.grey, size: 16),
          constraints: BoxConstraints(),
          padding: EdgeInsets.zero,
          onPressed: () => _showLessonOptions(context, lesson, isDark),
        ),
      ),
    );
  }

  Widget _buildGlobalFilterChips(bool isDark) {
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
                color: isSelected ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.white10 : Colors.grey[100]),
                borderRadius: BorderRadius.circular(20),
                border: isSelected ? null : Border.all(color: isDark ? Colors.transparent : Colors.grey.shade300),
              ),
              alignment: Alignment.center,
              child: Text(
                category,
                style: TextStyle(
                  color: isSelected ? (isDark ? Colors.black : Colors.white) : (isDark ? Colors.white70 : Colors.black),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilteredList(List<LessonModel> lessons, bool isDark) {
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
        return _buildTextLessonCard(context, filtered[index], isDark);
      },
    );
  }

  void _showCreateLessonDialog(BuildContext context, String userId, String currentLanguage, {required bool isFavoriteByDefault}) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    final lessonBloc = context.read<LessonBloc>();
    final lessonService = context.read<LessonService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? Color(0xFF1E1E1E) : Colors.white,
        title: Text('Create New Lesson', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(labelText: 'Title', border: OutlineInputBorder(), labelStyle: TextStyle(color: Colors.grey)),
              ),
              SizedBox(height: 16),
              TextField(
                controller: contentController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(labelText: 'Content', border: OutlineInputBorder(), labelStyle: TextStyle(color: Colors.grey)),
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
                  id: '', userId: userId, title: titleController.text, language: currentLanguage,
                  content: contentController.text, sentences: sentences, createdAt: DateTime.now(),
                  progress: 0, isFavorite: isFavoriteByDefault, type: 'text',
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