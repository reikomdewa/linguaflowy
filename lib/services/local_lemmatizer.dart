import 'package:flutter/services.dart';
import 'package:linguaflow/utils/logger.dart';

class LocalLemmatizer {
  static final LocalLemmatizer _instance = LocalLemmatizer._internal();
  factory LocalLemmatizer() => _instance;
  LocalLemmatizer._internal();

  // Map: "mangeons" -> "manger"
  Map<String, String> _dictionary = {};
  String? _currentLanguage;

  Future<void> load(String languageCode) async {
    // Avoid reloading if we already have this language loaded
    if (_currentLanguage == languageCode && _dictionary.isNotEmpty) return;

    _dictionary.clear();
    _currentLanguage = languageCode;

    try {
      // 1. Construct filename (e.g., "lemmatization-fr.txt")
      // Ensure your asset filenames match this pattern!
      final path = 'assets/dictionaries/lemmatization-$languageCode.txt';
      
      final String content = await rootBundle.loadString(path);
      
      // 2. Parse Line by Line
      final List<String> lines = content.split('\n');
      
      for (var line in lines) {
        if (line.trim().isEmpty) continue;
        
        // Format is: lemma <tab> token
        // Example: manger    mangeons
        var parts = line.split('\t');
        
        if (parts.length >= 2) {
          final lemma = parts[0].trim();
          final token = parts[1].trim();
          
          // Store it as: _dictionary['mangeons'] = 'manger'
          _dictionary[token.toLowerCase()] = lemma; 
        }
      }
      printLog("✅ Loaded ${_dictionary.length} lemmas for $languageCode");
    } catch (e) {
      printLog("⚠️ Could not load dictionary for $languageCode (Path: assets/dictionaries/lemmatization-$languageCode.txt). Using raw words.");
    }
  }

  String getLemma(String word) {
    if (_dictionary.isEmpty) return word;
    
    final lowerWord = word.toLowerCase().trim();
    
    // 1. Direct lookup
    if (_dictionary.containsKey(lowerWord)) {
      return _dictionary[lowerWord]!;
    }
    
    // 2. Fallback: Return original word if not found
    return word; 
  }
}