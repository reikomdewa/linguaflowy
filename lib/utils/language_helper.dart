class LanguageHelper {
  // =========================================================
  // 1. Map of Supported Languages (Code -> Name)
  // =========================================================
  static const Map<String, String> availableLanguages = {
    // --- Global / European / Asian ---
    'ar': 'Arabic',
    'cs': 'Czech',
    'da': 'Danish',
    'de': 'German',
    'el': 'Greek',
    'en': 'English',
    'es': 'Spanish',
    'fi': 'Finnish',
    'fr': 'French',
    'hi': 'Hindi',
    'hu': 'Hungarian',
    'id': 'Indonesian',
    'it': 'Italian',
    'ja': 'Japanese',
    'ko': 'Korean',
    'nl': 'Dutch',
    'no': 'Norwegian',
    'pl': 'Polish',
    'pt': 'Portuguese',
    'ro': 'Romanian',
    'ru': 'Russian',
    'sv': 'Swedish',
    'th': 'Thai',
    'tr': 'Turkish',
    'uk': 'Ukrainian',
    'vi': 'Vietnamese',
    'zh': 'Chinese',

    // --- African Languages (Masakhane / Local) ---
    'ach': 'Acholi',
    'ada': 'Adangme',
    'adh': 'Adhola',
    'af': 'Afrikaans',
    'alz': 'Alur',
    'am': 'Amharic',
    'anu': 'Anuak',
    'bem': 'Bemba',
    'bxk': 'Bukusu',
    'cce': 'Rukiga',
    'dag': 'Dagbani',
    'dga': 'Dagaare',
    'dje': 'Zarma',
    'ee': 'Ewe',
    'fat': 'Fanti',
    'ff': 'Fula',
    'gaa': 'Ga',
    'gjn': 'Gonja',
    'gur': 'Frafra',
    'guz': 'Gusii',
    'ha': 'Hausa',
    'ha-ne': 'Hausa (Niger)',
    'hz': 'Herero',
    'kam': 'Kamba',
    'kdj': 'Karamojong',
    'keo': 'Kakwa',
    'ki': 'Kikuyu',
    'kj': 'Kuanyama',
    'kln': 'Kalenjin',
    'koo': 'Konjo',
    'kpz': 'Kupsabiny',
    'kr': 'Kanuri',
    'kwn': 'Kwangali',
    'laj': 'Lango',
    'lg': 'Luganda',
    'lgg': 'Lugbara',
    'lgg-official': 'Lugbara (Official)',
    'lko': 'Olukhayo',
    'loz': 'Lozi',
    'lsm': 'Saamia',
    'luc': 'Aringa',
    'luo': 'Luo',
    'lwg': 'Wanga',
    'mas': 'Maasai',
    'mer': 'Meru',
    'mhi': 'Ma\'di',
    'mhw': 'Mbukushu',
    'myx': 'Masaba',
    'naq': 'Nama',
    'ng': 'Ndonga',
    'nle': 'Lunyole',
    'nr': 'South Ndebele',
    'nso': 'Northern Sotho (Sepedi)',
    'nuj': 'Nyole',
    'ny': 'Chichewa',
    'nyn': 'Runyankore',
    'nyu': 'Runyoro',
    'nzi': 'Nzema',
    'om': 'Oromo',
    'rw': 'Kinyarwanda',
    'saq': 'Samburu',
    'so': 'Somali',
    'ss': 'Swati',
    'st': 'Southern Sotho',
    'sw': 'Swahili',
    'teo': 'Teso',
    'ti': 'Tigrinya',
    'tn': 'Tswana',
    'toh': 'Gitonga',
    'toi': 'Tonga (Zambia)',
    'ts': 'Tsonga',
    'tsc': 'Tswa',
    'ttj': 'Rutooro',
    'tuv': 'Turkana',
    'tw-akua': 'Twi (Akuapem)',
    'tw-asan': 'Twi (Asante)',
    've': 'Venda',
    'xh': 'Xhosa',
    'xog': 'Soga',
    'xsm': 'Kasem',
    'yo': 'Yoruba',
    'zne': 'Zande',
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

    // 3. Fallback / Fuzzy search (optional: remove if strict matching is preferred)
    // This catches cases like "Tonga" matching "Tonga (Zambia)"
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
      case 'pt': return '🇵🇹'; // Or 🇧🇷 depending on preference
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
      case 'te':  // Teso (Standard code usually teo)
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
      case 'mas': // Maasai (also TZ)
      case 'mer': // Meru
      case 'saq': // Samburu
      case 'tuv': // Turkana
        return '🇰🇪';

      // --- NIGERIA 🇳🇬 ---
      case 'ha': // Hausa
      case 'yo': // Yoruba
      case 'kr': // Kanuri (also Chad/Niger/Cameroon)
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
      case 'ti':  // Tigrinya (also Eritrea)
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
      case 'sw': // Swahili (Official in TZ, KE, UG) - usually mapped to TZ or KE
        return '🇹🇿';

      // --- OTHERS ---
      case 'rw': return '🇷🇼'; // Kinyarwanda -> Rwanda
      case 'so': return '🇸🇴'; // Somali -> Somalia
      case 'ny': return '🇲🇼'; // Chichewa -> Malawi
      case 'ff': return '🇸🇳'; // Fula -> Senegal (Pan-African, but Senegal is common)
      case 'zne': return '🇸🇸'; // Zande -> South Sudan

      default:
        return '🌍'; // Universal / Unknown
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