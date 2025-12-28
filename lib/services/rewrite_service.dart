import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/user_model.dart';
import 'package:linguaflow/services/gemini_service.dart';
import 'package:linguaflow/utils/logger.dart';
import 'package:uuid/uuid.dart';

class RewriteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GeminiService _geminiService = GeminiService();

  static const int _freeDailyLimit = 2;

  Future<LessonModel> createRewrittenLesson({
    required UserModel user,
    required LessonModel originalLesson,
    required String targetLevel,
  }) async {
    // 1. Check Limits
    await _checkAndEnforceLimit(user);

    // 2. Perform AI Rewrite
    String newContent = await _geminiService.rewriteContent(
      originalContent: originalLesson.content,
      targetLevel: targetLevel,
      targetLanguage: originalLesson.language,
    );

    // 3. Clean Formatting (Strip Markdown)
    newContent = newContent
        .replaceAll(RegExp(r'\*\*'), '') 
        .replaceAll(RegExp(r'\*'), '')   
        .replaceAll(RegExp(r'__'), '')   
        .replaceAll(RegExp(r'_'), '')    
        .replaceAll(RegExp(r'#'), '')    
        .replaceAll(RegExp(r'`'), '')    
        .trim();

    // 4. CREATE NEW OBJECT (Do NOT use copyWith)
    // Using the constructor ensures videoUrl is null.
    final newLesson = LessonModel(
      id: const Uuid().v4(),
      userId: user.id, // The current user owns this new copy
      title: "${originalLesson.title} ($targetLevel)",
      language: originalLesson.language,
      content: newContent,
      
      // --- CRITICAL FIXES ---
      type: 'text',       // Explicitly set to text
      videoUrl: null,     // Explicitly null (Constructor defaults allow this)
      subtitleUrl: null,  // Explicitly null
      transcript: [],     // Empty list (removes old video timestamps)
      sentences: [],      // Empty list (removes old keywords)
      // ----------------------

      difficulty: targetLevel,
      createdAt: DateTime.now(),
      progress: 0,
      isFavorite: false,
      isLocal: false,
      
      // Inherit Metadata
      genre: originalLesson.genre,
      imageUrl: originalLesson.imageUrl, // Keep the image if it exists
      originalAuthorId: originalLesson.userId, // Link lineage
      seriesId: originalLesson.seriesId,
      seriesTitle: originalLesson.seriesTitle,
      seriesIndex: originalLesson.seriesIndex,
    );

    // 5. Increment Usage
    if (!user.isPremium) {
      await _incrementDailyUsage(user.id);
    }

    return newLesson;
  }

  // ... (Keep the existing _checkAndEnforceLimit and _incrementDailyUsage methods)
  Future<void> _checkAndEnforceLimit(UserModel user) async {
    if (user.isPremium) return; 

    try {
      final userDoc = await _firestore.collection('users').doc(user.id).get();
      final data = userDoc.data();

      if (data == null) return;

      final lastRewrite = (data['lastRewriteDate'] as Timestamp?)?.toDate();
      final usageCount = data['rewriteUsageCount'] as int? ?? 0;
      final now = DateTime.now();

      bool isNewDay = true;
      if (lastRewrite != null) {
        isNewDay =
            lastRewrite.year != now.year ||
            lastRewrite.month != now.month ||
            lastRewrite.day != now.day;
      }

      if (isNewDay) {
        await _firestore.collection('users').doc(user.id).update({
          'rewriteUsageCount': 0,
          'lastRewriteDate': FieldValue.serverTimestamp(),
        });
        return; 
      }

      if (usageCount >= _freeDailyLimit) {
        throw Exception("LIMIT_REACHED");
      }
    } catch (e) {
      if (e.toString().contains("LIMIT_REACHED")) rethrow;
      printLog("Error checking limits: $e");
    }
  }

  Future<void> _incrementDailyUsage(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'rewriteUsageCount': FieldValue.increment(1),
        'lastRewriteDate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      printLog("Failed to increment usage stats: $e");
    }
  }
}