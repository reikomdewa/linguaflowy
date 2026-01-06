
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
       case 'ml': return '🇲🇱';
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




///smart brain stop words for various languages
  static Set<String> getStopWords(String langCode) {
    final code = getLangCode(langCode);
    final Map<String, Set<String>> stopWordsMap = {
      'en': {'the', 'and', 'for', 'that', 'with', 'this', 'have', 'from', 'was', 'not'},
      'es': {'el', 'la', 'los', 'las', 'un', 'una', 'y', 'de', 'en', 'que', 'no', 'por'},
      'fr': {'le', 'la', 'les', 'un', 'une', 'et', 'de', 'du', 'en', 'que', 'ne', 'pas'},
      'de': {'der', 'die', 'das', 'ein', 'eine', 'und', 'in', 'zu', 'von', 'mit', 'nicht'},
      'it': {'il', 'lo', 'la', 'i', 'gli', 'le', 'un', 'uno', 'una', 'e', 'di', 'in'},
      'pt': {'o', 'a', 'os', 'as', 'um', 'uma', 'e', 'de', 'em', 'que', 'com', 'nao'},
      'ar': {'في', 'من', 'على', 'و', 'ان', 'هذا', 'كان', 'إلى', 'مع'},
      'zh': {'的', '了', '是', '我', '你', '他', '在', '有', '个', '这'},
      'ja': {'の', 'に', 'は', 'を', 'た', 'て', 'です', 'ます', 'だ', 'が'},
      'sw': {'na', 'ya', 'wa', 'kwa', 'ni', 'katika', 'la', 'vya', 'za', 'si'},
      'lg': {'na', 'wa', 'mu', 'ku', 'era', 'nga', 'nti', 'ye', 'ba', 'za'},
    };

    return stopWordsMap[code] ?? {};
  }

   // NEW: Complexity Calculation
  // =========================================================
  static double getWordComplexityMultiplier(String word, String langCode) {
    double multiplier = 1.0;
    final code = getLangCode(langCode);

    // 1. Length-based difficulty (for space-based languages)
    if (!usesNoSpaces(word, code)) {
      if (word.length > 8) multiplier += 0.4;
      if (word.length > 12) multiplier += 0.6;
    } else {
      // 2. CJK / Thai: Longer character strings in a row usually indicate complex compounds
      if (word.length > 2) multiplier += 0.5;
      if (word.length > 4) multiplier += 1.0;
    }

    // 3. Rare Character Script Bonus
    // Award slightly more for scripts that are generally harder for foreigners
    if (['ar', 'hi', 'th', 'am', 'ti'].contains(code)) {
      multiplier += 0.2;
    }

    return multiplier;
  }

  // =========================================================
  // NEW: Master Smart XP Engine
  // =========================================================
  static int calculateSmartXP({
    required String word,
    required String langCode,
    required int oldStatus,
    required int newStatus,
    required String userLevel, // e.g. "A1 - Newcomer"
  }) {
    final cleanWord = word.toLowerCase().trim();
    if (cleanWord.isEmpty) return 0;

    // A. Base Values
    double totalMultiplier = getWordComplexityMultiplier(cleanWord, langCode);
    int baseReward = 5;
    int progressionBonus = 0;

    // B. Stop Word Penalty (Basic words shouldn't give much XP)
    final stopWords = getStopWords(langCode);
    if (stopWords.contains(cleanWord)) {
      return 1; // Return flat 1 XP for words like "the", "a", "na"
    }

    // C. Progression Logic
    if (oldStatus == 0 && newStatus > 0) {
      progressionBonus = 15; // Reward for "learning" a word for the first time
    } else if (newStatus > oldStatus) {
      progressionBonus = 5;  // Reward for moving a word up the status chain
    }

    // D. Stretch Goal Bonus (Hard word for a beginner)
    bool isBeginner = userLevel.contains('A1') || userLevel.contains('A2');
    if (isBeginner && totalMultiplier > 1.4) {
      progressionBonus += 10; // Extra credit for tackling hard words early
    }

    // E. Mastered Word Penalty
    // If user is just clicking a word they already know perfectly (Status 5)
    if (oldStatus >= 5) {
      baseReward = 1; 
      progressionBonus = 0;
      totalMultiplier = 1.0;
    }

    return ((baseReward * totalMultiplier) + progressionBonus).round();
  }

}