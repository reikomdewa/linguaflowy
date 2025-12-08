import 'package:flutter/foundation.dart';

class LanguageHelper {
  static String resolveCode(String input) {
    final clean = input.toLowerCase().trim();
    if (clean.length <= 3) return clean;

    final Map<String, String> codes = {
      'english': 'en', 'spanish': 'es', 'french': 'fr', 'german': 'de',
      'italian': 'it', 'portuguese': 'pt', 'russian': 'ru', 'chinese': 'zh',
      'japanese': 'ja', 'korean': 'ko', 'dutch': 'nl', 'polish': 'pl',
      'turkish': 'tr', 'arabic': 'ar', 'hindi': 'hi', 'bengali': 'bn',
      'indonesian': 'id', 'ukrainian': 'uk', 'swedish': 'sv', 'norwegian': 'no',
      'danish': 'da', 'finnish': 'fi', 'vietnamese': 'vi', 'thai': 'th',
      'greek': 'el', 'czech': 'cs', 'romanian': 'ro', 'hungarian': 'hu',
    };

    final code = codes[clean] ?? 'en';
    // debugPrint("DEBUG: Converted '$input' -> '$code'");
    return code;
  }
}