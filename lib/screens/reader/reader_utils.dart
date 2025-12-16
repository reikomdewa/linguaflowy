import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:linguaflow/models/vocabulary_item.dart';

class ReaderUtils {
  static const int kFreeLookupLimit = 50;
  static const int kResetMinutes = 10;

  /// Clean text ID for vocabulary lookups
  /// FIXED: Now supports Unicode (Arabic, Chinese, etc.) using unicode: true
  static String generateCleanId(String text) {
    if (text.isEmpty) return "";
    
    return text.toLowerCase().trim().replaceAll(
      // Match anything that is NOT a Letter, NOT a Number, and NOT a Space/Underscore
      // \p{L} = Any Unicode Letter
      // \p{N} = Any Unicode Number
      RegExp(r'[^\p{L}\p{N}\s_]', unicode: true), 
      ''
    );
  }

  /// Safe parsing for Firestore Timestamps or Strings
  static DateTime parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  /// Determines the background highlight color based on learning status
  static Color getWordColor(VocabularyItem? item, bool isDark) {
    if (item == null || item.status == 0) {
      // New word / unknown: Slight blue highlight
      return Colors.blue.withOpacity(isDark ? 0.3 : 0.15);
    }
    switch (item.status) {
      case 1:
        return const Color(0xFFFFF9C4).withOpacity(isDark ? 0.8 : 1.0); // Light Yellow
      case 2:
        return const Color(0xFFFFF59D).withOpacity(isDark ? 0.8 : 1.0); // Yellow
      case 3:
        return const Color(0xFFFFCC80).withOpacity(isDark ? 0.8 : 1.0); // Orange-ish
      case 4:
        return const Color(0xFFFFB74D).withOpacity(isDark ? 0.8 : 1.0); // Orange
      case 5:
        return Colors.transparent; // Learned (No highlight)
      default:
        return Colors.transparent;
    }
  }

  /// Determines text color to ensure readability against highlights
  static Color getTextColorForStatus(VocabularyItem? item, bool isSelected, bool isDark) {
    if (isSelected) return Colors.white;
    
    // Status 0 (New/Blue) needs white text in Dark Mode, Black in Light Mode
    if (item == null || item.status == 0) {
      return isDark ? Colors.white : Colors.black87;
    }

    // Status 5 (Known) -> Standard text color
    if (item.status == 5) {
      return isDark ? Colors.white : Colors.black87;
    }

    // For highlighted words (status 1-4, Yellow/Orange), 
    // Black text is almost always more readable than White, even in Dark Mode.
    return Colors.black87;
  }

  /// Formats a duration into MM:SS or HH:MM:SS
  static String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$minutes:$seconds";
    }
    return "$minutes:$seconds";
  }
}