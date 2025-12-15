import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; // Required for 'compute'

// 1. Top-Level Function (Must be outside the class)
// This runs in a separate thread to avoid freezing the UI.
Map<String, String> _parseDictionaryInIsolate(String content) {
  final Map<String, String> map = {};
  
  // Splitting a massive string is heavy CPU work
  final List<String> lines = content.split('\n');
  
  for (var line in lines) {
    if (line.trim().isEmpty) continue;
    
    // Format: lemma <tab> token
    var parts = line.split('\t');
    if (parts.length >= 2) {
      final lemma = parts[0].trim();
      final token = parts[1].trim();
      map[token.toLowerCase()] = lemma; 
    }
  }
  return map;
}

class LocalLemmatizer {
  static final LocalLemmatizer _instance = LocalLemmatizer._internal();
  factory LocalLemmatizer() => _instance;
  LocalLemmatizer._internal();

  Map<String, String> _dictionary = {};
  String? _currentLanguage;
  bool _isLoading = false;

  Future<void> load(String languageCode) async {
    // Prevent double loading
    if (_currentLanguage == languageCode && _dictionary.isNotEmpty) return;
    if (_isLoading) return;

    _isLoading = true;
    _dictionary.clear();
    _currentLanguage = languageCode;

    try {
      final path = 'assets/dictionaries/lemmatization-$languageCode.txt';
      
      // 1. Load string from assets (Async I/O - Fast)
      final String content = await rootBundle.loadString(path);
      
      // 2. Parse the massive text in a BACKGROUND thread (Compute)
      // This is the fix: It stops the UI from freezing/lagging
      _dictionary = await compute(_parseDictionaryInIsolate, content);
      
      debugPrint("✅ Loaded ${_dictionary.length} lemmas for $languageCode (Background)");
    } catch (e) {
      debugPrint("⚠️ Could not load dictionary for $languageCode: $e");
    } finally {
      _isLoading = false;
    }
  }

  String getLemma(String word) {
    if (_dictionary.isEmpty) return word;
    
    final lowerWord = word.toLowerCase().trim();
    if (_dictionary.containsKey(lowerWord)) {
      return _dictionary[lowerWord]!;
    }
    return word; 
  }
}