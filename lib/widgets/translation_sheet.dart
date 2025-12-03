import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http; 
import 'dart:convert';
import 'package:linguaflow/models/vocabulary_item.dart';
import 'gemini_formatted_text.dart'; // Make sure this import path is correct

class TranslationSheet extends StatefulWidget {
  final String originalText;
  final Future<String> translationFuture;
  final Future<String?> geminiFuture;
  final bool isPhrase;
  final VocabularyItem? existingItem;
  final String targetLanguage;
  final VoidCallback onSpeak;
  final Function(int, String) onUpdateStatus;
  final VoidCallback onSaveToFirebase;
  final VoidCallback onClose;

  const TranslationSheet({
    Key? key,
    required this.originalText,
    required this.translationFuture,
    required this.geminiFuture,
    required this.isPhrase,
    this.existingItem,
    required this.targetLanguage,
    required this.onSpeak,
    required this.onUpdateStatus,
    required this.onSaveToFirebase,
    required this.onClose,
  }) : super(key: key);

  @override
  _TranslationSheetState createState() => _TranslationSheetState();
}

class _TranslationSheetState extends State<TranslationSheet> {
  // 0 = Editor, 1 = WordRef, 2 = Glosbe, 3 = Reverso
  int _selectedTabIndex = 0; 
  String _cachedTranslation = "Loading...";
  
  // Cache for external API results
  Map<int, Future<String>> _externalDictFutures = {};

  @override
  void initState() {
    super.initState();
    widget.translationFuture.then((val) {
      if (mounted) setState(() => _cachedTranslation = val);
    });
  }

  // --- API LOGIC FOR EXTERNAL DICTIONARIES ---
  Future<String> _fetchExternalDictionary(int tabIndex) async {
    // 1. WordReference
    if (tabIndex == 1) {
      final key = dotenv.env['WORDREFERENCE_KEY'];
      if (key == null) return "Configure WORDREFERENCE_KEY in .env";
      // Implement actual HTTP call here
      await Future.delayed(Duration(milliseconds: 600)); 
      return "WordReference result for '${widget.originalText}'...\n(API implementation required)";
    }
    
    // 2. Glosbe
    if (tabIndex == 2) {
      await Future.delayed(Duration(milliseconds: 600));
      return "Glosbe examples for '${widget.originalText}'...";
    }

    // 3. Reverso
    if (tabIndex == 3) {
      await Future.delayed(Duration(milliseconds: 600));
      return "Reverso Context matches for '${widget.originalText}'...";
    }

    return "Unknown Dictionary";
  }

  Future<String> _getOrFetchDict(int index) {
    if (!_externalDictFutures.containsKey(index)) {
      _externalDictFutures[index] = _fetchExternalDictionary(index);
    }
    return _externalDictFutures[index]!;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Color(0xFF151517) : Colors.white;
    final primaryTextColor = isDark ? Colors.white : Colors.black87;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          margin: EdgeInsets.fromLTRB(10, 0, 10, 0), // Bottom handled by SafeArea inside
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 15,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              // --- HANDLE ---
              Center(
                child: Container(
                  margin: EdgeInsets.only(top: 8, bottom: 8),
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),

              // --- CONTENT ---
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildHeaderRow(primaryTextColor),
                    SizedBox(height: 12),

                    // Tabs
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildTabButton("Editor", 0, isDark),
                          _buildTabButton("WordRef", 1, isDark),
                          _buildTabButton("Glosbe", 2, isDark),
                          _buildTabButton("Reverso", 3, isDark),
                        ],
                      ),
                    ),
                    Divider(color: Colors.grey.withOpacity(0.2)),

                    if (_selectedTabIndex == 0)
                      _buildEditorContent(isDark, primaryTextColor)
                    else
                      _buildDictionaryResult(_selectedTabIndex, isDark, primaryTextColor),
                      
                    SizedBox(height: 80), // Extra space for bottom bar
                  ],
                ),
              ),

              // --- BOTTOM RANKING BAR (Sticky & Safe Area) ---
              if (!widget.isPhrase)
                _buildBottomRankingBar(isDark),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderRow(Color textColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: widget.onSpeak,
          child: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.volume_up_rounded, color: Colors.blue, size: 24),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            widget.originalText,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
        InkWell(
          onTap: widget.onSaveToFirebase,
          borderRadius: BorderRadius.circular(20),
          child: Container(
             padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
             decoration: BoxDecoration(
               color: Colors.blue[800], 
               borderRadius: BorderRadius.circular(20)
             ),
             child: Icon(Icons.bookmark_add, size: 20, color: Colors.white), 
          ),
        ),
      ],
    );
  }

  Widget _buildTabButton(String label, int index, bool isDark) {
    final isSelected = _selectedTabIndex == index;
    final inactiveBg = isDark ? Color(0xFF2C2C2E) : Colors.grey[200];
    
    return GestureDetector(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: Container(
        margin: EdgeInsets.only(right: 8),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : inactiveBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : Colors.black87),
            fontSize: 13, 
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
        Text("Translation", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text(
          _cachedTranslation,
          style: TextStyle(color: textColor, fontSize: 18, height: 1.4),
        ),
        SizedBox(height: 20),
        
        Text("AI Explanation", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        FutureBuilder<String?>(
          future: widget.geminiFuture,
          builder: (context, gSnap) {
            if (gSnap.connectionState == ConnectionState.waiting) {
              return LinearProgressIndicator(color: Colors.purple.withOpacity(0.3));
            }
            if (gSnap.hasData && gSnap.data != null) {
              return GeminiFormattedText(text: gSnap.data!);
            }
            return Text("AI details unavailable", style: TextStyle(color: Colors.grey));
          },
        ),
      ],
    );
  }

  Widget _buildDictionaryResult(int index, bool isDark, Color textColor) {
    return FutureBuilder<String>(
      future: _getOrFetchDict(index),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Text("Error", style: TextStyle(color: Colors.red));
        return Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(snapshot.data ?? "No results", style: TextStyle(color: textColor, height: 1.5)),
        );
      },
    );
  }

  // --- SAFE AREA FIX HERE ---
  Widget _buildBottomRankingBar(bool isDark) {
    final barColor = isDark ? Color(0xFF202022) : Colors.white;
    final borderColor = isDark ? Colors.white10 : Colors.grey[300]!;

    // Using MediaQuery viewPadding to handle bottom nav bars / home indicators
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: barColor,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding + 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "RANK WORD KNOWLEDGE",
            style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.0),
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildRankButton("New", 0, Colors.blue, isDark),
              _buildRankButton("1", 1, Colors.yellow[700]!, isDark),
              _buildRankButton("2", 2, Colors.orange[400]!, isDark),
              _buildRankButton("3", 3, Colors.orange[700]!, isDark),
              _buildRankButton("4", 4, Colors.red[400]!, isDark),
              _buildRankButton("Known", 5, Colors.green, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRankButton(String label, int status, Color color, bool isDark) {
    final isActive = widget.existingItem?.status == status;
    
    return InkWell(
      onTap: () => widget.onUpdateStatus(status, _cachedTranslation),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 48,
        height: 40,
        decoration: BoxDecoration(
          color: isActive ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? Colors.transparent : (isDark ? Colors.white24 : Colors.grey[300]!),
            width: 1.5
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[600]),
            fontWeight: FontWeight.bold,
            fontSize: 11
          ),
        ),
      ),
    );
  }
}