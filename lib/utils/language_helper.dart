class LanguageHelper {
  // =========================================================
  // 1. Map of Supported Languages
  //    (Popular first, then A-Z)
  // =========================================================
  static const Map<String, String> availableLanguages = {
    // --- 🌟 POPULAR / MOST COMMON ---
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
    'sw': 'Swahili', // Included in top list as it's a major lingua franca

    // --- 🔤 A-Z LIST (All Others) ---
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
  // Handles inputs like "Bemba", "bem ", "es" -> returns "bem", "es"
  // =========================================================
  static String getLangCode(String input) {
    if (input.isEmpty) return 'en';

    final clean = input.toLowerCase().trim();

    // 1. Check if the input is already a valid KEY (code)
    if (availableLanguages.containsKey(clean)) {
      return clean;
    }

    // 2. Check if the input matches a VALUE (name)
    // We iterate through the map to find the key associated with the name.
    for (var entry in availableLanguages.entries) {
      if (entry.value.toLowerCase() == clean) {
        return entry.key;
      }
    }

    // 3. Fallback / Fuzzy search
    for (var entry in availableLanguages.entries) {
      if (entry.value.toLowerCase().contains(clean)) {
        return entry.key;
      }
    }

    return 'en'; // Default to English if not found
  }

  // =========================================================
  // 3. Get Flag Emoji from Code
  // =========================================================
  static String getFlagEmoji(String langCode) {
    final code = getLangCode(langCode);

    switch (code) {
      // --- Europe / Americas / Asia ---
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

      // --- ZAMBIA 🇿🇲 ---
      case 'bem': // Bemba
      case 'loz': // Lozi
      case 'toi': // Tonga (Zambia)
        return '🇿🇲';

      // --- UGANDA 🇺🇬 ---
      case 'ach': // Acholi
      case 'adh': // Adhola
      case 'alz': // Alur
      case 'kdj': // Karamojong
      case 'koo': // Konjo
      case 'laj': // Lango
      case 'lg':  // Luganda
      case 'lgg': // Lugbara
      case 'lgg-official':
      case 'lko': // Olukhayo
      case 'lsm': // Saamia
      case 'luc': // Aringa
      case 'lwg': // Wanga
      case 'mhi': // Ma'di
      case 'myx': // Masaba
      case 'nle': // Lunyole
      case 'nuj': // Nyole
      case 'nyn': // Runyankore
      case 'nyu': // Runyoro
      case 'te':  // Teso
      case 'teo': // Teso
      case 'ttj': // Rutooro
      case 'cce': // Rukiga
      case 'xog': // Soga
        return '🇺🇬';

      // --- GHANA 🇬🇭 ---
      case 'ada': // Adangme
      case 'dag': // Dagbani
      case 'dga': // Dagaare
      case 'ee':  // Ewe
      case 'fat': // Fanti
      case 'gaa': // Ga
      case 'gjn': // Gonja
      case 'gur': // Frafra
      case 'nzi': // Nzema
      case 'tw-akua': // Twi
      case 'tw-asan': // Twi
      case 'xsm': // Kasem
        return '🇬🇭';

      // --- SOUTH AFRICA 🇿🇦 ---
      case 'af':  // Afrikaans
      case 'nr':  // Ndebele
      case 'nso': // Northern Sotho
      case 'ss':  // Swati
      case 'st':  // Southern Sotho
      case 'tn':  // Tswana
      case 'ts':  // Tsonga
      case 've':  // Venda
      case 'xh':  // Xhosa
      case 'zu':  // Zulu
        return '🇿🇦';

      // --- KENYA 🇰🇪 ---
      case 'bxk': // Bukusu
      case 'guz': // Gusii
      case 'kam': // Kamba
      case 'keo': // Kakwa
      case 'ki':  // Kikuyu
      case 'kln': // Kalenjin
      case 'kpz': // Kupsabiny
      case 'luo': // Luo
      case 'mas': // Maasai
      case 'mer': // Meru
      case 'saq': // Samburu
      case 'tuv': // Turkana
        return '🇰🇪';

      // --- NIGERIA 🇳🇬 ---
      case 'ha': // Hausa
      case 'yo': // Yoruba
      case 'kr': // Kanuri
        return '🇳🇬';

      // --- NAMIBIA 🇳🇦 ---
      case 'hz':  // Herero
      case 'kj':  // Kuanyama
      case 'kwn': // Kwangali
      case 'mhw': // Mbukushu
      case 'naq': // Nama
      case 'ng':  // Ndonga
        return '🇳🇦';

      // --- ETHIOPIA 🇪🇹 ---
      case 'am':  // Amharic
      case 'om':  // Oromo
      case 'ti':  // Tigrinya
      case 'anu': // Anuak
        return '🇪🇹';

      // --- NIGER 🇳🇪 ---
      case 'dje':   // Zarma
      case 'ha-ne': // Hausa (Niger dialect)
        return '🇳🇪';

      // --- MOZAMBIQUE 🇲🇿 ---
      case 'toh': // Gitonga
      case 'tsc': // Tswa
        return '🇲🇿';

      // --- TANZANIA 🇹🇿 ---
      case 'sw': // Swahili
        return '🇹🇿';

      // --- OTHERS ---
      case 'rw': return '🇷🇼'; // Kinyarwanda
      case 'so': return '🇸🇴'; // Somali
      case 'ny': return '🇲🇼'; // Chichewa
      case 'ff': return '🇸🇳'; // Fula
      case 'zne': return '🇸🇸'; // Zande

      default:
        return '🌍';
    }
  }

  // =========================================================
  // 4. Get Language Name from Code
  // =========================================================
  static String getLanguageName(String code) {
    final clean = getLangCode(code);
    return availableLanguages[clean] ?? 'English';
  }
}