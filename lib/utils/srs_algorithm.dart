import 'dart:math' as math;
import 'package:linguaflow/models/vocabulary_item.dart';

class SRSAlgorithm {
  // Returns true if the word should be reviewed today
  static bool isDue(VocabularyItem item) {
    if (item.status == 0) return true; // New words always due
    final now = DateTime.now();
    final difference = now.difference(item.lastReviewed).inDays;

    // Mapping Status (0-5) to Days required before next review
    int requiredGap;
    switch (item.status) {
      case 1: requiredGap = 0; break; 
      case 2: requiredGap = 2; break;
      case 3: requiredGap = 6; break;
      case 4: requiredGap = 13; break;
      case 5: requiredGap = 29; break;
      default: requiredGap = 0;
    }
    return difference >= requiredGap;
  }

  // Calculate Next Status based on Button Press
  // Rating: 1=Again, 2=Hard, 3=Good, 4=Easy
  static int nextStatus(int current, int rating) {
    if (rating == 1) return 1; // Forgot? Reset to 1.
    if (rating == 2) return current > 1 ? current : 1; // Hard? Don't advance.
    if (rating == 3) return math.min(current + 1, 5); // Good? Advance.
    if (rating == 4) return math.min(current + 2, 5); // Easy? Jump.
    return current;
  }

  // Helper text to show user when they will see the card again
  static String getNextIntervalText(int currentStatus, int rating) {
    int next = nextStatus(currentStatus, rating);
    if (next == 1) return "1d";
    if (next == 2) return "3d";
    if (next == 3) return "7d";
    if (next == 4) return "14d";
    if (next == 5) return "30d";
    return "1d";
  }
}