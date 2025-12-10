import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:linguaflow/models/vocabulary_item.dart';

class ReaderUtils {
  static const int kFreeLookupLimit = 50;
  static const int kResetMinutes = 10;

  static String generateCleanId(String text) {
    return text.toLowerCase().trim().replaceAll(RegExp(r'[^\w\s]'), '');
  }

  static DateTime parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  static Color getWordColor(VocabularyItem? item, bool isDark) {
    if (item == null || item.status == 0) {
      return Colors.blue.withOpacity(0.15);
    }
    switch (item.status) {
      case 1:
        return const Color(0xFFFFF9C4);
      case 2:
        return const Color(0xFFFFF59D);
      case 3:
        return const Color(0xFFFFCC80);
      case 4:
        return const Color(0xFFFFB74D);
      case 5:
        return Colors.transparent;
      default:
        return Colors.transparent;
    }
  }

  static Color getTextColorForStatus(VocabularyItem? item, bool isSelected, bool isDark) {
    if (isSelected) return Colors.white;
    if (item?.status == 5 || item == null) {
      return isDark ? Colors.white : Colors.black87;
    }
    return Colors.black87;
  }
}