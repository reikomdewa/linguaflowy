import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:linguaflow/widgets/gemini_formatted_text.dart';

class FloatingTranslationCard extends StatefulWidget {
  final String originalText;
  final Future<String> translationFuture;
  final Future<String?> geminiFuture;
  final String targetLanguage;
  final String nativeLanguage;
  final int currentStatus;
  final Offset anchorPosition;
  final VoidCallback onSpeak;
  final Function(int, String) onUpdateStatus;
  final VoidCallback onClose;

  const FloatingTranslationCard({
    Key? key,
    required this.originalText,
    required this.translationFuture,
    required this.geminiFuture,
    required this.targetLanguage,
    required this.nativeLanguage,
    required this.currentStatus,
    required this.anchorPosition,
    required this.onSpeak,
    required this.onUpdateStatus,
    required this.onClose,
  }) : super(key: key);

  @override
  State<FloatingTranslationCard> createState() => _FloatingTranslationCardState();
}

class _FloatingTranslationCardState extends State<FloatingTranslationCard> {
  String _translationText = "Loading...";
  
  // Dragging State
  Offset _dragOffset = Offset.zero;

  // Tabs: 0=Editor, 1=MyMemory, 2=WordRef, 3=Glosbe, 4=Reverso
  int _selectedTabIndex = 0; 
  bool _isExpanded = false;
  
  // API Cache
  final Map<int, Future<String>> _externalDictFutures = {};

  // WebView Controller
  WebViewController? _webViewController;
  bool _isLoadingWeb = false;

  @override
  void initState() {
    super.initState();
    widget.translationFuture.then((value) {
      if (mounted) setState(() => _translationText = value);
    });
  }

  // --- API LOGIC ---
  Future<String> _fetchTextDefinition(int tabIndex) async {
    if (tabIndex == 1) { // MyMemory
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
             if (result.trim().toLowerCase() == widget.originalText.trim().toLowerCase()) {
              return "No direct translation match found.";
            }
            return result;
          }
        }
        return "No results found.";
      } catch (e) {
        return "Error: $e";
      }
    }
    return "Unknown Source";
  }

  // --- WEBVIEW LOGIC ---
  String _getWebUrl(int index) {
    final src = widget.targetLanguage;
    final tgt = widget.nativeLanguage;
    final word = widget.originalText;

    switch(index) {
      case 2: return "https://www.wordreference.com/${src}en/$word";
      case 3: return "https://glosbe.com/$src/$tgt/$word";
      case 4: return "https://context.reverso.net/translation/$src-$tgt/$word";
      default: return "";
    }
  }

  void _initializeWebView(int index) {
    setState(() => _isLoadingWeb = true);
    final url = _getWebUrl(index);

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF1C1C1E))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (mounted) setState(() => _isLoadingWeb = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(url));
  }

  void _onTabSelected(int index) {
    setState(() {
      if (_isExpanded && _selectedTabIndex == index) {
        _isExpanded = false;
        _webViewController = null;
      } else {
        _selectedTabIndex = index;
        _isExpanded = true;
        if (index > 1) {
          _initializeWebView(index);
        } else {
          _webViewController = null;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    
    // --- POSITIONING LOGIC ---
    double? topPos, bottomPos, leftPos;
    double width;

    if (_isExpanded) {
      // FULL SCREEN MODE
      topPos = padding.top + 10;
      bottomPos = 0; 
      leftPos = 0; 
      width = screenSize.width; 
    } else {
      // COMPACT MODE
      width = screenSize.width * 0.9;
      leftPos = ((screenSize.width - width) / 2) + _dragOffset.dx;

      final bool showAbove = widget.anchorPosition.dy > (screenSize.height * 0.6);
      const double verticalPadding = 24.0; 

      if (showAbove) {
        bottomPos = (screenSize.height - widget.anchorPosition.dy) + verticalPadding - _dragOffset.dy;
        topPos = null; 
      } else {
        topPos = widget.anchorPosition.dy + verticalPadding + _dragOffset.dy;
        bottomPos = null;
      }
    }

    // Flag logic
    String flagAsset = "🇬🇧"; 
    if (widget.nativeLanguage == 'es') flagAsset = "🇪🇸";
    else if (widget.nativeLanguage == 'fr') flagAsset = "🇫🇷";

    return Stack(
      children: [
        Positioned(
          top: topPos,
          bottom: bottomPos,
          left: leftPos,
          width: width,
          child: GestureDetector(
            onPanUpdate: _isExpanded ? null : (details) => setState(() => _dragOffset += details.delta),
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: _isExpanded ? double.infinity : screenSize.height * 0.6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(_isExpanded ? 0 : 16),
                  border: Border.all(color: Colors.white10),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 10))
                  ],
                ),
                child: Column(
                  mainAxisSize: _isExpanded ? MainAxisSize.max : MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    
                    // --- 1. STICKY HEADER ---
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Column(
                        children: [
                          if (!_isExpanded)
                            Container(
                              width: 40, height: 4,
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)),
                            ),
                          
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.volume_up, color: Colors.blue),
                                onPressed: widget.onSpeak,
                                padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  widget.originalText,
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.grey),
                                onPressed: widget.onClose,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const Divider(color: Colors.white10, height: 1),

                    // --- 2. BODY CONTENT ---
                    _isExpanded 
                      ? Expanded(child: _buildBodyContent(flagAsset)) // Use Expanded to fill screen
                      : Flexible(fit: FlexFit.loose, child: _buildBodyContent(flagAsset)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBodyContent(String flagAsset) {
    // Shared Metadata Widget (Translation, Ranks, Tabs)
    Widget metadata = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Translation
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _translationText,
                  style: const TextStyle(fontSize: 18, color: Colors.white70, height: 1.4),
                ),
              ),
              const SizedBox(width: 8),
              Text(flagAsset, style: const TextStyle(fontSize: 20)),
            ],
          ),

          const SizedBox(height: 16),
          
          // Rank Bar
          const Text("RANK WORD KNOWLEDGE", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildRankButton("New", 0, Colors.blue),
              _buildRankButton("1", 1, const Color(0xFFFBC02D)),
              _buildRankButton("2", 2, const Color(0xFFFFA726)),
              _buildRankButton("3", 3, const Color(0xFFF57C00)),
              _buildRankButton("4", 4, const Color(0xFFEF5350)),
              _buildRankButton("Known", 5, Colors.green),
            ],
          ),

          const SizedBox(height: 16),

          // Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTabChip("Editor", 0),
                const SizedBox(width: 8),
                _buildTabChip("MyMemory", 1),
                const SizedBox(width: 8),
                _buildTabChip("WordRef", 2),
                const SizedBox(width: 8),
                _buildTabChip("Glosbe", 3),
                const SizedBox(width: 8),
                _buildTabChip("Reverso", 4),
              ],
            ),
          ),
        ],
      ),
    );

    // --- CASE 1: WEBVIEW MODE (Expanded) ---
    // We use a Column structure so the WebView takes up remaining space
    // WITHOUT being wrapped in a SingleChildScrollView
    if (_isExpanded && _selectedTabIndex > 1) {
      return Column(
        children: [
          metadata, // Metadata at the top
          Expanded( // WebView takes all remaining space
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
              ),
              child: _buildExpandedContent(),
            ),
          ),
        ],
      );
    }

    // --- CASE 2: NORMAL TEXT MODE (or Compact) ---
    // We wrap everything in SingleChildScrollView so it scrolls together
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          metadata,
          if (_isExpanded) 
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
              ),
              child: _buildExpandedContent(),
            ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent() {
    // 0 = Editor (Gemini)
    if (_selectedTabIndex == 0) {
      return FutureBuilder<String?>(
        future: widget.geminiFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
             return Center(child: Padding(padding: const EdgeInsets.all(20), child: LinearProgressIndicator(color: Colors.blue.withOpacity(0.3), backgroundColor: Colors.transparent)));
          }
          if (snapshot.hasData && snapshot.data != null) {
            return Padding(padding: const EdgeInsets.all(16), child: GeminiFormattedText(text: snapshot.data!));
          }
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text("AI explanation unavailable.", style: TextStyle(color: Colors.grey))
          );
        },
      );
    }
    
    // 1 = MyMemory (Text API)
    if (_selectedTabIndex == 1) {
      if (!_externalDictFutures.containsKey(1)) {
        _externalDictFutures[1] = _fetchTextDefinition(1);
      }
      return FutureBuilder<String>(
        future: _externalDictFutures[1],
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
          return Padding(padding: const EdgeInsets.all(16), child: Text(snapshot.data ?? "No result", style: const TextStyle(color: Colors.white70)));
        },
      );
    }

    // 2, 3, 4 = Embedded WebView
    if (_webViewController != null) {
      return Stack(
        children: [
          WebViewWidget(controller: _webViewController!),
          if (_isLoadingWeb)
            const Center(child: CircularProgressIndicator(color: Colors.blue)),
        ],
      );
    }
    
    return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("Initializing Browser...", style: TextStyle(color: Colors.grey))));
  }

  Widget _buildRankButton(String label, int status, Color color) {
    final isActive = (widget.currentStatus == 0 ? 0 : widget.currentStatus) == status;
    return GestureDetector(
      onTap: () {
        widget.onUpdateStatus(status, _translationText);
      },
      child: Container(
        width: 40, height: 35,
        decoration: BoxDecoration(
          color: isActive ? color : color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? Colors.transparent : color.withOpacity(0.5), width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(color: isActive ? Colors.white : color, fontWeight: FontWeight.bold, fontSize: 10)),
      ),
    );
  }

  Widget _buildTabChip(String label, int index) {
    final isSelected = _isExpanded && _selectedTabIndex == index;
    return GestureDetector(
      onTap: () => _onTabSelected(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? Border.all(color: Colors.blueAccent) : null,
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }
}