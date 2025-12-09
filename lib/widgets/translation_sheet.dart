

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:linguaflow/models/vocabulary_item.dart';
// Ensure this widget exists in your project, or replace with Text()
import 'package:linguaflow/widgets/gemini_formatted_text.dart'; 

class TranslationSheet extends StatefulWidget {
  final String originalText;
  final Future<String> translationFuture;
  final Future<String?> geminiFuture;
  final bool isPhrase;
  final VocabularyItem? existingItem;
  final String targetLanguage; 
  final String nativeLanguage; 
  final VoidCallback onSpeak;
  final Function(int, String) onUpdateStatus;
  final VoidCallback onSaveToFirebase;
  final VoidCallback onClose;

  const TranslationSheet({
    super.key,
    required this.originalText,
    required this.translationFuture,
    required this.geminiFuture,
    required this.isPhrase,
    this.existingItem,
    required this.targetLanguage,
    required this.nativeLanguage,
    required this.onSpeak,
    required this.onUpdateStatus,
    required this.onSaveToFirebase,
    required this.onClose,
  });

  @override
  _TranslationSheetState createState() => _TranslationSheetState();
}

class _TranslationSheetState extends State<TranslationSheet> {
  // 0 = Editor, 1 = MyMemory, 2 = Glosbe
  int _selectedTabIndex = 0;
  String _cachedTranslation = "Loading...";
  
  // Cache to store API results so we don't re-fetch on tab switch
  final Map<int, Future<String>> _externalDictFutures = {};

  @override
  void initState() {
    super.initState();
    // Cache the main translation
    widget.translationFuture.then((val) {
      if (mounted) setState(() => _cachedTranslation = val);
    });
  }

  // --- API LOGIC (Fetches text content only) ---
  Future<String> _fetchExternalDictionary(int tabIndex) async {
    // 1. MyMemory (Free API)
    if (tabIndex == 1) {
      try {
        final src = widget.targetLanguage.isEmpty ? 'es' : widget.targetLanguage;
        final tgt = widget.nativeLanguage.isEmpty ? 'en' : widget.nativeLanguage;
        final text = Uri.encodeComponent(widget.originalText);
        
        final url = Uri.parse('https://api.mymemory.translated.net/get?q=$text&langpair=$src|$tgt');
        
        final response = await http.get(url).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['responseData'] != null) {
            String result = data['responseData']['translatedText'] ?? "";
            
            // Filter out exact matches if no translation found
            if (result.trim().toLowerCase() == widget.originalText.trim().toLowerCase()) {
              return "No direct translation match found in MyMemory database.";
            }
            return result;
          }
        }
        return "No results found.";
      } on TimeoutException {
        return "Connection timed out.";
      } catch (e) {
        return "Error fetching translation: $e";
      }
    }
    
    // 2. Glosbe (Note: Glosbe API is strictly rate-limited/paid now. 
    // This is a placeholder as direct scraping is brittle without a WebView)
    if (tabIndex == 2) {
      return "Glosbe API integration requires a specific key or web scraping implementation.\n\nUse the 'Editor' tab for the most accurate AI explanation.";
    }

    return "Unknown Dictionary";
  }

  Future<String> _getOrFetchDict(int index) {
    // Only fetch if we haven't already
    if (!_externalDictFutures.containsKey(index)) {
      _externalDictFutures[index] = _fetchExternalDictionary(index);
    }
    return _externalDictFutures[index]!;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Reader-style background color
    final backgroundColor = isDark ? const Color(0xFF1C1C1E) : Colors.white; 
    final primaryTextColor = isDark ? Colors.white : Colors.black87;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              // --- HANDLE ---
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),

              // --- CONTENT AREA ---
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildHeaderRow(primaryTextColor),
                    const SizedBox(height: 16),

                    // --- TABS (Editor, MyMemory, Glosbe) ---
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildTabButton("Editor", 0, isDark),
                          _buildTabButton("MyMemory", 1, isDark),
                          _buildTabButton("Glosbe", 2, isDark),
                        ],
                      ),
                    ),
                    Divider(color: Colors.grey.withOpacity(0.2), height: 24),

                    // --- TAB CONTENT ---
                    if (_selectedTabIndex == 0)
                      _buildEditorContent(isDark, primaryTextColor)
                    else
                      _buildDictionaryResult(_selectedTabIndex, isDark, primaryTextColor),
                      
                    // Space for scrolling above bottom bar
                    const SizedBox(height: 100), 
                  ],
                ),
              ),

              // --- BOTTOM RANKING BAR (Sticky) ---
              if (!widget.isPhrase)
                _buildBottomRankingBar(isDark),
            ],
          ),
        );
      },
    );
  }

  // --- SUB-WIDGETS ---

  Widget _buildHeaderRow(Color textColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Speaker
        GestureDetector(
          onTap: widget.onSpeak,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.volume_up_rounded, color: Colors.blue, size: 26),
          ),
        ),
        const SizedBox(width: 16),
        
        // Word
        Expanded(
          child: Text(
            widget.originalText,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
        
        // Save Button (Icon style)
        IconButton(
          onPressed: () {
            widget.onSaveToFirebase();
            widget.onClose();
          },
          icon: Icon(Icons.bookmark_add, color: Colors.blue[400], size: 28),
        ),
      ],
    );
  }

  Widget _buildTabButton(String label, int index, bool isDark) {
    final isSelected = _selectedTabIndex == index;
    // Dark mode inactive tab color vs Light mode
    final inactiveBg = isDark ? const Color(0xFF2C2C2E) : Colors.grey[200];
    
    return GestureDetector(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : inactiveBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : (isDark ? Colors.grey[400] : Colors.black87),
            fontSize: 14, 
            fontWeight: FontWeight.w600
          ),
        ),
      ),
    );
  }

  Widget _buildEditorContent(bool isDark, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("TRANSLATION", style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
        const SizedBox(height: 8),
        Text(
          _cachedTranslation,
          style: TextStyle(color: textColor, fontSize: 18, height: 1.4),
        ),
        const SizedBox(height: 24),
        
        const Text("AI EXPLANATION", style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
        const SizedBox(height: 12),
        FutureBuilder<String?>(
          future: widget.geminiFuture,
          builder: (context, gSnap) {
            if (gSnap.connectionState == ConnectionState.waiting) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: LinearProgressIndicator(color: Colors.blue.withOpacity(0.3), backgroundColor: Colors.transparent),
              );
            }
            if (gSnap.hasData && gSnap.data != null) {
              return GeminiFormattedText(text: gSnap.data!);
            }
            return const Text("AI details unavailable for this word.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic));
          },
        ),
      ],
    );
  }

  Widget _buildDictionaryResult(int index, bool isDark, Color textColor) {
    return FutureBuilder<String>(
      future: _getOrFetchDict(index),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Text("Error loading dictionary: ${snapshot.error}", style: const TextStyle(color: Colors.red)),
          );
        }
        // Dictionary Result Content
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            snapshot.data ?? "No result available",
            style: TextStyle(color: textColor, height: 1.5, fontSize: 16),
          ),
        );
      },
    );
  }

  Widget _buildBottomRankingBar(bool isDark) {
    // Styling to match Reader Screen Bottom Bar
    final barColor = isDark ? const Color(0xFF202022) : Colors.white;
    final borderColor = isDark ? Colors.white10 : Colors.grey[300]!;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: barColor,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "RANK WORD KNOWLEDGE",
            style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildRankButton("New", 0, Colors.blue, isDark),
              _buildRankButton("1", 1, const Color(0xFFFBC02D), isDark), // Yellow 700
              _buildRankButton("2", 2, const Color(0xFFFFA726), isDark), // Orange 400
              _buildRankButton("3", 3, const Color(0xFFF57C00), isDark), // Orange 700
              _buildRankButton("4", 4, const Color(0xFFEF5350), isDark), // Red 400
              _buildRankButton("Known", 5, Colors.green, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRankButton(String label, int status, Color color, bool isDark) {
    // Determine active status (Default to 0 if null)
    final currentStatus = widget.existingItem?.status ?? 0;
    final isActive = currentStatus == status;
    
    return InkWell(
      onTap: () {
        widget.onUpdateStatus(status, _cachedTranslation);
        widget.onClose();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 48, 
        height: 42,
        decoration: BoxDecoration(
          // Active = Full Color, Inactive = Subtle Opacity
          color: isActive ? color : color.withOpacity(isDark ? 0.15 : 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? Colors.transparent : color.withOpacity(0.5),
            width: 1.5
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : color,
            fontWeight: FontWeight.bold,
            fontSize: 12
          ),
        ),
      ),
    );
  }
}