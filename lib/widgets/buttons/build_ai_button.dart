
//   import 'package:flutter/material.dart';
// import 'package:linguaflow/screens/home/utils/home_utils.dart';

// Widget buildAIStoryButton(BuildContext context, bool isDark) {
//     final List<Color> gradientColors = isDark
//         ? [const Color(0xFFFFFFFF), const Color(0xFFE0E0E0)]
//         : [const Color(0xFF2C3E50), const Color(0xFF000000)];
//     final Color textColor = isDark ? Colors.black : Colors.white;
//     final Color shadowColor = isDark
//         ? Colors.white.withValues(alpha: 0.15)
//         : Colors.black.withValues(alpha: 0.3);

//     return Padding(
//       padding: const EdgeInsets.only(left: 16.0, right: 16),
//       child: Container(
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             colors: gradientColors,
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//           ),
//           borderRadius: BorderRadius.circular(30),
//           boxShadow: [
//             BoxShadow(
//               color: shadowColor,
//               blurRadius: 12,
//               offset: const Offset(0, 4),
//               spreadRadius: 1,
//             ),
//           ],
//         ),
//         child: ElevatedButton(
//           onPressed: () => HomeUtils.showAIStoryGenerator(context),
//           style: ElevatedButton.styleFrom(
//             backgroundColor: Colors.transparent,
//             shadowColor: Colors.transparent,
//             padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(30),
//             ),
//           ),
//           child: Row(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Icon(Icons.auto_awesome, color: textColor, size: 20),
//               const SizedBox(width: 10),
//               Text(
//                 "Personalized",
//                 style: TextStyle(
//                   color: textColor,
//                   fontWeight: FontWeight.bold,
//                   fontSize: 16,
//                   letterSpacing: 0.5,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }