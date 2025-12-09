import 'package:flutter/foundation.dart';

class LanguageHelper {
  // Single source of truth for supported languages
  static const Map<String, String> availableLanguages = {
    'en': 'English',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'it': 'Italian',
    'pt': 'Portuguese',
    'ru': 'Russian',
    'zh': 'Chinese',
    'ja': 'Japanese',
    'ko': 'Korean',
    'nl': 'Dutch',
    'pl': 'Polish',
    'tr': 'Turkish',
    'ar': 'Arabic',
    'hi': 'Hindi',
  };

  static String resolveCode(String input) {
    final clean = input.toLowerCase().trim();
    if (clean.length <= 3) return clean;

    // Inverse map for name -> code lookup if needed
    final Map<String, String> nameToCode = {
      'english': 'en', 'spanish': 'es', 'french': 'fr', 'german': 'de',
      'italian': 'it', 'portuguese': 'pt', 'russian': 'ru', 'chinese': 'zh',
      'japanese': 'ja', 'korean': 'ko', 'dutch': 'nl', 'polish': 'pl',
      'turkish': 'tr', 'arabic': 'ar', 'hindi': 'hi', 'bengali': 'bn',
      'indonesian': 'id', 'ukrainian': 'uk', 'swedish': 'sv', 'norwegian': 'no',
      'danish': 'da', 'finnish': 'fi', 'vietnamese': 'vi', 'thai': 'th',
      'greek': 'el', 'czech': 'cs', 'romanian': 'ro', 'hungarian': 'hu',
    };

    final code = nameToCode[clean] ?? 'en';
    return code;
  }
  
  static String getFlagEmoji(String langCode) {
    switch (langCode) {
      case 'es': return '🇪🇸';
      case 'fr': return '🇫🇷';
      case 'de': return '🇩🇪';
      case 'en': return '🇬🇧';
      case 'it': return '🇮🇹';
      case 'pt': return '🇵🇹';
      case 'ja': return '🇯🇵';
      case 'zh': return '🇨🇳';
      case 'ru': return '🇷🇺';
      case 'ar': return '🇸🇦';
      default: return '🏳️';
    }
  }
}