import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:linguaflow/utils/language_helper.dart';

class MyMemoryService {
  static Future<String?> translate({
    required String text,
    required String sourceLang,
    required String targetLang,
  }) async {
    if (text.trim().isEmpty) return null;

    final sCode = LanguageHelper.getLangCode(sourceLang);
    final tCode = LanguageHelper.getLangCode(targetLang);

    if (sCode == tCode) return null;

    try {
      final langPair = '$sCode|$tCode';
      final encodedText = Uri.encodeComponent(text);

      final url = Uri.parse(
        'https://api.mymemory.translated.net/get?q=$encodedText&langpair=$langPair',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['responseData'] != null &&
            data['responseData']['translatedText'] != null) {
          String result = data['responseData']['translatedText'].toString();

          // MyMemory often returns the input text if it fails to translate
          if (result.trim().toLowerCase() == text.trim().toLowerCase()) {
            return null;
          }

          if (result.contains("MYMEMORY WARNING") ||
              result.contains("Invalid language pair")) {
            return null;
          }

          return result;
        }
      } else {}
    } catch (e) {
      return null;
    }
    return null;
  }
}
