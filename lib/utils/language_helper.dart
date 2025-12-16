import 'package:flutter/material.dart';

class LanguageHelper {
  // =========================================================
  // 1. Map of Supported Languages
  // =========================================================
  static const Map<String, String> availableLanguages = {
    'en': 'English',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'zh': 'Chinese',
    'ja': 'Japanese',
    'ar': 'Arabic',
    'pt': 'Portuguese',
    'it': 'Italian',
    'ru': 'Russian',
    'ko': 'Korean',
    'hi': 'Hindi',
    'sw': 'Swahili',
    'ach': 'Acholi',
    'ada': 'Adangme',
    'adh': 'Adhola',
    'af': 'Afrikaans',
    'alz': 'Alur',
    'am': 'Amharic',
    'anu': 'Anuak',
    'luc': 'Aringa',
    'bem': 'Bemba',
    'bxk': 'Bukusu',
    'ny': 'Chichewa',
    'cs': 'Czech',
    'dga': 'Dagaare',
    'dag': 'Dagbani',
    'da': 'Danish',
    'nl': 'Dutch',
    'ee': 'Ewe',
    'fat': 'Fanti',
    'fi': 'Finnish',
    'gur': 'Frafra',
    'ff': 'Fula',
    'gaa': 'Ga',
    'toh': 'Gitonga',
    'gjn': 'Gonja',
    'el': 'Greek',
    'guz': 'Gusii',
    'ha': 'Hausa',
    'ha-ne': 'Hausa (Niger)',
    'hz': 'Herero',
    'hu': 'Hungarian',
    'id': 'Indonesian',
    'keo': 'Kakwa',
    'kln': 'Kalenjin',
    'kam': 'Kamba',
    'kr': 'Kanuri',
    'kdj': 'Karamojong',
    'xsm': 'Kasem',
    'ki': 'Kikuyu',
    'rw': 'Kinyarwanda',
    'koo': 'Konjo',
    'kj': 'Kuanyama',
    'kpz': 'Kupsabiny',
    'kwn': 'Kwangali',
    'laj': 'Lango',
    'loz': 'Lozi',
    'lg': 'Luganda',
    'lgg': 'Lugbara',
    'lgg-official': 'Lugbara (Official)',
    'nle': 'Lunyole',
    'luo': 'Luo',
    'mhi': 'Ma\'di',
    'mas': 'Maasai',
    'myx': 'Masaba',
    'mhw': 'Mbukushu',
    'mer': 'Meru',
    'naq': 'Nama',
    'ng': 'Ndonga',
    'nso': 'Northern Sotho (Sepedi)',
    'no': 'Norwegian',
    'nuj': 'Nyole',
    'nzi': 'Nzema',
    'lko': 'Olukhayo',
    'om': 'Oromo',
    'pl': 'Polish',
    'ro': 'Romanian',
    'cce': 'Rukiga',
    'nyn': 'Runyankore',
    'nyu': 'Runyoro',
    'ttj': 'Rutooro',
    'lsm': 'Saamia',
    'saq': 'Samburu',
    'xog': 'Soga',
    'so': 'Somali',
    'nr': 'South Ndebele',
    'st': 'Southern Sotho',
    'ss': 'Swati',
    'sv': 'Swedish',
    'teo': 'Teso',
    'th': 'Thai',
    'ti': 'Tigrinya',
    'toi': 'Tonga (Zambia)',
    'ts': 'Tsonga',
    'tsc': 'Tswa',
    'tn': 'Tswana',
    'tuv': 'Turkana',
    'tr': 'Turkish',
    'tw-akua': 'Twi (Akuapem)',
    'tw-asan': 'Twi (Asante)',
    'uk': 'Ukrainian',
    've': 'Venda',
    'vi': 'Vietnamese',
    'lwg': 'Wanga',
    'xh': 'Xhosa',
    'yo': 'Yoruba',
    'zne': 'Zande',
    'dje': 'Zarma',
    'zu': 'Zulu',
  };

  // =========================================================
  // 2. Resolve Language Code
  // =========================================================
  static String getLangCode(String input) {
    if (input.isEmpty) return 'en';
    final clean = input.toLowerCase().trim();
    if (availableLanguages.containsKey(clean)) return clean;
    for (var entry in availableLanguages.entries) {
      if (entry.value.toLowerCase() == clean) return entry.key;
    }
    for (var entry in availableLanguages.entries) {
      if (entry.value.toLowerCase().contains(clean)) return entry.key;
    }
    return 'en';
  }

  // =========================================================
  // 3. Get Flag Emoji
  // =========================================================
  static String getFlagEmoji(String langCode) {
    final code = getLangCode(langCode);
    switch (code) {
      case 'en': return '🇬🇧';
      case 'es': return '🇪🇸';
      case 'fr': return '🇫🇷';
      case 'de': return '🇩🇪';
      case 'it': return '🇮🇹';
      case 'pt': return '🇵🇹';
      case 'ru': return '🇷🇺';
      case 'zh': return '🇨🇳';
      case 'ja': return '🇯🇵';
      case 'ko': return '🇰🇷';
      case 'nl': return '🇳🇱';
      case 'pl': return '🇵🇱';
      case 'tr': return '🇹🇷';
      case 'ar': return '🇸🇦';
      case 'hi': return '🇮🇳';
      case 'sv': return '🇸🇪';
      case 'no': return '🇳🇴';
      case 'da': return '🇩🇰';
      case 'fi': return '🇫🇮';
      case 'cs': return '🇨🇿';
      case 'el': return '🇬🇷';
      case 'ro': return '🇷🇴';
      case 'hu': return '🇭🇺';
      case 'id': return '🇮🇩';
      case 'uk': return '🇺🇦';
      case 'vi': return '🇻🇳';
      case 'th': return '🇹🇭';
      case 'bem': case 'loz': case 'toi': return '🇿🇲';
      case 'ach': case 'adh': case 'alz': case 'kdj': case 'koo': case 'laj': 
      case 'lg': case 'lgg': case 'lgg-official': case 'lko': case 'lsm': 
      case 'luc': case 'lwg': case 'mhi': case 'myx': case 'nle': case 'nuj': 
      case 'nyn': case 'nyu': case 'te': case 'teo': case 'ttj': case 'cce': 
      case 'xog': return '🇺🇬';
      case 'ada': case 'dag': case 'dga': case 'ee': case 'fat': case 'gaa': 
      case 'gjn': case 'gur': case 'nzi': case 'tw-akua': case 'tw-asan': 
      case 'xsm': return '🇬🇭';
      case 'af': case 'nr': case 'nso': case 'ss': case 'st': case 'tn': 
      case 'ts': case 've': case 'xh': case 'zu': return '🇿🇦';
      case 'bxk': case 'guz': case 'kam': case 'keo': case 'ki': case 'kln': 
      case 'kpz': case 'luo': case 'mas': case 'mer': case 'saq': case 'tuv': 
        return '🇰🇪';
      case 'ha': case 'yo': case 'kr': return '🇳🇬';
      case 'hz': case 'kj': case 'kwn': case 'mhw': case 'naq': case 'ng': 
        return '🇳🇦';
      case 'am': case 'om': case 'ti': case 'anu': return '🇪🇹';
      case 'dje': case 'ha-ne': return '🇳🇪';
      case 'toh': case 'tsc': return '🇲🇿';
      case 'sw': return '🇹🇿';
      case 'rw': return '🇷🇼';
      case 'so': return '🇸🇴';
      case 'ny': return '🇲🇼';
      case 'ff': return '🇸🇳';
      case 'zne': return '🇸🇸';
      default: return '🌍';
    }
  }

  static String getLanguageName(String code) {
    final clean = getLangCode(code);
    return availableLanguages[clean] ?? 'English';
  }

  // Checks if text contains CJK (Chinese, Japanese, Korean) characters
  static bool hasCJK(String text) {
    return RegExp(r'[\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff\uff66-\uff9f]').hasMatch(text);
  }

  /// Checks if text contains Thai characters
  static bool hasThai(String text) {
    return RegExp(r'[\u0E00-\u0E7F]').hasMatch(text);
  }

  /// Checks if we should split by character instead of space.
  /// 1. Checks the Language Code.
  /// 2. Checks the ACTUAL TEXT content for CJK/Thai characters.
  static bool usesNoSpaces(String text, String langCode) {
    // 1. Check Config
    final code = getLangCode(langCode);
    if (['zh', 'ja', 'th', 'lo', 'km', 'my'].contains(code)) return true;

    // 2. Check Content (Auto-detect)
    // This fixes issues where langCode might be wrong (e.g. 'en' but text is Chinese)
    if (hasCJK(text)) return true;
    if (hasThai(text)) return true;

    return false;
  }

  static bool isRTL(String langCode) {
    final code = getLangCode(langCode);
    return ['ar', 'he', 'fa', 'ur', 'ps'].contains(code);
  }

  /// THE FIX: Tokenizes text into tappable chunks.
static List<String> tokenizeText(String text, String langCode) {
    if (usesNoSpaces(text, langCode)) {
      // CJK/Thai: Split by character
      return text.split('');
    } else {
      // Space-based languages (English, Arabic, Russian, etc.):
      // We use a Regex to find all distinct parts:
      // 1. Words (Letters/Numbers, potentially with internal apostrophes/hyphens like "l'eau" or "don't")
      // 2. Whitespace
      // 3. Punctuation/Symbols (Anything else)
      
      // Explanation of Regex:
      // [\p{L}\p{N}]+  -> Starts with letters or numbers
      // (?:['’_-][\p{L}\p{N}]+)* -> Optionally followed by ' or - or _ and more letters (keeps "don't" together)
      // | (\s+) -> OR Whitespace
      // | ([^\p{L}\p{N}\s]+) -> OR Punctuation (anything not letter, number, or space)
      
      final RegExp tokenizer = RegExp(
        r"([\p{L}\p{N}]+(?:['’_-][\p{L}\p{N}]+)*)|(\s+)|([^\p{L}\p{N}\s]+)", 
        unicode: true,
      );

      return tokenizer.allMatches(text).map((m) => m.group(0)!).toList();
    }
  }

  /// Returns the regex used to split sentences.
  static RegExp getSentenceSplitter(String langCode) {
    final code = getLangCode(langCode);
    if (['zh', 'ja'].contains(code)) return RegExp(r'(?<=[.!?。！？])\s*');
    if (['am', 'ti'].contains(code)) return RegExp(r'(?<=[.!?።])\s*');
    if (['ar', 'fa', 'ur'].contains(code)) return RegExp(r'(?<=[.!?؟])\s+');
    return RegExp(r'(?<=[.!?])\s+');
  }

  static int getItemsPerPage(String langCode) {
    // We assume 'zh' here just for page size, or default to 100
    final code = getLangCode(langCode);
    return ['zh', 'ja', 'th'].contains(code) ? 300 : 100;
  }
  
  static int measureTextLength(String text, String langCode) {
    return usesNoSpaces(text, langCode) ? text.length : text.split(' ').length;
  }
}