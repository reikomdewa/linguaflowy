// File: lib/services/translation_service.dart

import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:translator/translator.dart';
import 'package:linguaflow/utils/language_helper.dart'; // Import your helper

class TranslationService {
  // 1. Create a single instance (Optimization)
  final GoogleTranslator _translator = GoogleTranslator();

  // 2. Return String? (Nullable) to handle errors gracefully in UI
  Future<String?> translate(String text, String targetLang, String sourceLang) async {
    if (text.trim().isEmpty) return null;

    try {
      // 3. Resolve Language Codes (e.g., "Spanish" -> "es")
      // If you don't do this, the package will throw an error
      final sCode = LanguageHelper.resolveCode(sourceLang);
      final tCode = LanguageHelper.resolveCode(targetLang);

      // Don't translate if languages are the same
      if (sCode == tCode) return null; 

      final translation = await _translator.translate(
        text,
        from: sCode,
        to: tCode,
      );

      return translation.text;
    } catch (e) {
      // 4. Log error but don't crash
      debugPrint("Google Translate Error: $e");
      return null; 
    }
  }
}