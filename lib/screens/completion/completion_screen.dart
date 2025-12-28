// import 'package:flutter/material.dart';

// class LessonCompletionScreen extends StatelessWidget {
//   final String lessonTitle;
//   final int wordsLearnedCount;
//   final int xpEarned;

//   const LessonCompletionScreen({
//     super.key,
//     required this.lessonTitle,
//     required this.wordsLearnedCount,
//     required this.xpEarned,
//   });

//   @override
//   Widget build(BuildContext context) {
//     // Determine brightness for status bar and theme
//     final isDark = Theme.of(context).brightness == Brightness.dark;

//     return Scaffold(
//       backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
//       body: SafeArea(
//         child: Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             crossAxisAlignment: CrossAxisAlignment.center,
//             children: [
//               const Spacer(),

//               // 1. Success Icon
//               Container(
//                 padding: const EdgeInsets.all(24),
//                 decoration: BoxDecoration(
//                   color: Colors.green.withValues(alpha: 0.15),
//                   shape: BoxShape.circle,
//                 ),
//                 child: const Icon(
//                   Icons.check_rounded,
//                   color: Colors.green,
//                   size: 64,
//                 ),
//               ),
//               const SizedBox(height: 32),

//               // 2. Title & Message
//               Text(
//                 "Lesson Complete!",
//                 style: Theme.of(context).textTheme.headlineMedium?.copyWith(
//                   fontWeight: FontWeight.bold,
//                   color: isDark ? Colors.white : Colors.black,
//                 ),
//                 textAlign: TextAlign.center,
//               ),
//               const SizedBox(height: 12),
//               Text(
//                 lessonTitle,
//                 style: TextStyle(
//                   fontSize: 18,
//                   color: isDark ? Colors.grey[400] : Colors.grey[600],
//                 ),
//                 textAlign: TextAlign.center,
//                 maxLines: 2,
//                 overflow: TextOverflow.ellipsis,
//               ),

//               const SizedBox(height: 48),

//               // 3. Stats Card
//               Container(
//                 width: double.infinity,
//                 padding: const EdgeInsets.all(24),
//                 decoration: BoxDecoration(
//                   color: isDark
//                       ? Colors.white.withValues(alpha: 0.05)
//                       : Colors.grey[100],
//                   borderRadius: BorderRadius.circular(20),
//                 ),
//                 child: Column(
//                   children: [
//                     Text(
//                       "SESSION PERFORMANCE",
//                       style: TextStyle(
//                         fontSize: 12,
//                         fontWeight: FontWeight.bold,
//                         letterSpacing: 1.2,
//                         color: isDark ? Colors.grey[500] : Colors.grey[600],
//                       ),
//                     ),
//                     const SizedBox(height: 24),
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                       children: [
//                         _buildStatItem(
//                           context,
//                           count: "1",
//                           label: "Lessons",
//                           icon: Icons.menu_book_rounded,
//                           color: Colors.blue,
//                         ),
//                         _buildVerticalDivider(isDark),
//                         _buildStatItem(
//                           context,
//                           count: "$wordsLearnedCount",
//                           label: "Words",
//                           icon: Icons.trending_up_rounded,
//                           color: Colors.orange,
//                         ),
//                         _buildVerticalDivider(isDark),
//                         _buildStatItem(
//                           context,
//                           count: xpEarned.toString(),
//                           label: 'XP',
//                           icon: Icons.bolt,
//                           color: Colors.amber,
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),

//               const Spacer(),

//               // 4. Finish Button (Safe Area)
//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton(
//                   onPressed: () {
//                     // Pop Completion Screen AND Reader Screen
//                     // Assuming stack is: Home -> Reader -> Completion
//                     Navigator.of(context).pop(); // Pop Completion
//                     Navigator.of(context).pop(); // Pop Reader
//                   },
//                   style: ElevatedButton.styleFrom(
//                     padding: const EdgeInsets.symmetric(vertical: 18),
//                     backgroundColor: Theme.of(context).primaryColor,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(16),
//                     ),
//                     elevation: 4,
//                     shadowColor: Theme.of(
//                       context,
//                     ).primaryColor.withValues(alpha: 0.4),
//                   ),
//                   child: const Text(
//                     "Finish",
//                     style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 16),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildStatItem(
//     BuildContext context, {
//     required String count,
//     required String label,
//     required IconData icon,
//     required Color color,
//   }) {
//     final isDark = Theme.of(context).brightness == Brightness.dark;

//     return Column(
//       children: [
//         Container(
//           padding: const EdgeInsets.all(12),
//           decoration: BoxDecoration(
//             color: color.withValues(alpha: 0.15),
//             shape: BoxShape.circle,
//           ),
//           child: Icon(icon, color: color, size: 24),
//         ),
//         const SizedBox(height: 12),
//         Text(
//           count,
//           style: TextStyle(
//             fontSize: 24,
//             fontWeight: FontWeight.bold,
//             color: isDark ? Colors.white : Colors.black,
//           ),
//         ),
//         const SizedBox(height: 4),
//         Text(
//           label,
//           style: TextStyle(
//             fontSize: 14,
//             color: isDark ? Colors.grey[400] : Colors.grey[600],
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildVerticalDivider(bool isDark) {
//     return Container(
//       height: 40,
//       width: 1,
//       color: isDark ? Colors.white24 : Colors.grey[300],
//     );
//   }
// }
