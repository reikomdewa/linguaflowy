import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:linguaflow/utils/language_helper.dart';

class MyMemoryService {
  static Future<String?> translate({
    required String text,
    required String sourceLang,
    required String targetLang,
  }) async {
    if (text.trim().isEmpty) return null;

    final sCode = LanguageHelper.resolveCode(sourceLang);
    final tCode = LanguageHelper.resolveCode(targetLang);

    if (sCode == tCode) return null;

    debugPrint("DEBUG: [MyMemory] Requesting '$text' ($sCode|$tCode)");

    try {
      final langPair = '$sCode|$tCode';
      final encodedText = Uri.encodeComponent(text);
      
      final url = Uri.parse(
          'https://api.mymemory.translated.net/get?q=$encodedText&langpair=$langPair');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['responseData'] != null && 
            data['responseData']['translatedText'] != null) {
          
          String result = data['responseData']['translatedText'].toString();
          
          // MyMemory often returns the input text if it fails to translate
          if (result.trim().toLowerCase() == text.trim().toLowerCase()) {
             debugPrint("DEBUG: [MyMemory] Returned identical text (Failure)");
             return null;
          }
          
          if (result.contains("MYMEMORY WARNING") || result.contains("Invalid language pair")) {
            debugPrint("DEBUG: [MyMemory] API Warning received");
            return null;
          }

          debugPrint("DEBUG: [MyMemory] Success: $result");
          return result;
        }
      } else {
        debugPrint("DEBUG: [MyMemory] HTTP Error ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("DEBUG: [MyMemory] Exception: $e");
      return null;
    }
    return null;
  }
}