
class LanguageHelper {
  /// 1. Map of Supported Languages (Code -> Name)
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
    'sv': 'Swedish',
    'no': 'Norwegian',
    'da': 'Danish',
    'fi': 'Finnish',
    'cs': 'Czech',
    'el': 'Greek',
    'ro': 'Romanian',
    'hu': 'Hungarian',
    'id': 'Indonesian',
    'uk': 'Ukrainian',
    'vi': 'Vietnamese',
    'th': 'Thai',
  };

  /// 2. Resolve Language Code
  /// Handles inputs like "Spanish", " Spanish ", "es" -> returns "es"
  static String getLangCode(String input) {
    if (input.isEmpty) return 'en';

    final clean = input.toLowerCase().trim();

    // If it's already a short code (2-3 chars), assume it's valid or return as is
    if (clean.length <= 3) return clean;

    // Inverse map for Name -> Code lookup
    final Map<String, String> nameToCode = {
      'english': 'en',
      'spanish': 'es',
      'french': 'fr',
      'german': 'de',
      'italian': 'it',
      'portuguese': 'pt',
      'russian': 'ru',
      'chinese': 'zh',
      'japanese': 'ja',
      'korean': 'ko',
      'dutch': 'nl',
      'polish': 'pl',
      'turkish': 'tr',
      'arabic': 'ar',
      'hindi': 'hi',
      'bengali': 'bn',
      'indonesian': 'id',
      'ukrainian': 'uk',
      'swedish': 'sv',
      'norwegian': 'no',
      'danish': 'da',
      'finnish': 'fi',
      'vietnamese': 'vi',
      'thai': 'th',
      'greek': 'el',
      'czech': 'cs',
      'romanian': 'ro',
      'hungarian': 'hu',
    };

    return nameToCode[clean] ?? 'en'; // Default to English if unknown
  }

  /// 3. Get Flag Emoji from Code
  static String getFlagEmoji(String langCode) {
    // Ensure we are working with a clean code (e.g. handle "Spanish" -> "es" first if needed)
    final code = getLangCode(langCode);

    switch (code) {
      case 'en':
        return '🇬🇧';
      case 'es':
        return '🇪🇸';
      case 'fr':
        return '🇫🇷';
      case 'de':
        return '🇩🇪';
      case 'it':
        return '🇮🇹';
      case 'pt':
        return '🇵🇹';
      case 'ru':
        return '🇷🇺';
      case 'zh':
        return '🇨🇳';
      case 'ja':
        return '🇯🇵';
      case 'ko':
        return '🇰🇷';
      case 'nl':
        return '🇳🇱';
      case 'pl':
        return '🇵🇱';
      case 'tr':
        return '🇹🇷';
      case 'ar':
        return '🇸🇦';
      case 'hi':
        return '🇮🇳';
      case 'sv':
        return '🇸🇪';
      case 'no':
        return '🇳🇴';
      case 'da':
        return '🇩🇰';
      case 'fi':
        return '🇫🇮';
      case 'cs':
        return '🇨🇿';
      case 'el':
        return '🇬🇷';
      case 'ro':
        return '🇷🇴';
      case 'hu':
        return '🇭🇺';
      case 'id':
        return '🇮🇩';
      case 'uk':
        return '🇺🇦';
      case 'vi':
        return '🇻🇳';
      case 'th':
        return '🇹🇭';
      default:
        return '🇬🇧'; // Default fallback
    }
  }

  /// 4. Get Language Name from Code (e.g., "es" -> "Spanish")
  static String getLanguageName(String code) {
    final clean = getLangCode(code);
    return availableLanguages[clean] ?? 'English';
  }
}
