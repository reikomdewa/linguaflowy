import 'package:cloud_firestore/cloud_firestore.dart';

class QuizLimitService {
  static const int _kQuizLimit = 3; // Max quizzes allowed per window
  static const int _kResetMinutes = 10; // Reset window in minutes

  /// Checks if the user is allowed to take a quiz based on free tier limits.
  /// Returns [true] if allowed, [false] if limit reached.
  Future<bool> checkAndIncrementQuizLimit(String userId) async {
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('limits')
        .doc('quizzes');

    final snapshot = await docRef.get();
    final now = DateTime.now();

    // 1. If never used, create and allow
    if (!snapshot.exists) {
      await docRef.set({
        'count': 1,
        'lastReset': FieldValue.serverTimestamp(),
      });
      return true;
    }

    final data = snapshot.data()!;
    final Timestamp? lastResetTs = data['lastReset'] as Timestamp?;
    final DateTime lastReset = lastResetTs?.toDate() ?? now;
    final int count = data['count'] ?? 0;

    // 2. Check if time window has passed
    if (now.difference(lastReset).inMinutes >= _kResetMinutes) {
      // Reset counter
      await docRef.set({
        'count': 1,
        'lastReset': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } else {
      // 3. Still in window, check limit
      if (count < _kQuizLimit) {
        await docRef.update({'count': FieldValue.increment(1)});
        return true;
      } else {
        return false; // Limit reached
      }
    }
  }

  int get limit => _kQuizLimit;
  int get resetMinutes => _kResetMinutes;
}