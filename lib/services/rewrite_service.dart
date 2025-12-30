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

    // 4. CREATE NEW OBJECT
    final newLesson = LessonModel(
      id: const Uuid().v4(),
      userId: user.id, 
      title: "${originalLesson.title} ($targetLevel)",
      language: originalLesson.language,
      content: newContent,
      
      // --- CRITICAL OVERRIDES ---
      type: 'text',       
      videoUrl: null,     
      subtitleUrl: null,  
      transcript: [],     
      sentences: [],      
      
      difficulty: targetLevel,
      createdAt: DateTime.now(),
      progress: 0,
      
      // --- UPDATED: Mark as AI Story ---
      originality: 'ai_story', 
      source: 'ai', 
      // --------------------------------
      
      // Set to TRUE so it shows in Library
      isFavorite: true, 
      
      isLocal: false,
      
      // Inherit Metadata
      genre: originalLesson.genre,
      imageUrl: originalLesson.imageUrl,
      originalAuthorId: originalLesson.userId,
      seriesId: originalLesson.seriesId,
      seriesTitle: originalLesson.seriesTitle,
      seriesIndex: originalLesson.seriesIndex,
    );

    // 5. Increment Usage if not premium
    if (!user.isPremium) {
      await _incrementDailyUsage(user.id);
    }

    return newLesson;
  }

  // --- HELPER: CHECK LIMITS ---
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

  // --- HELPER: INCREMENT USAGE ---
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