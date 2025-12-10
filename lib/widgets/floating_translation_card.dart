import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_tts/flutter_tts.dart'; 
import 'package:linguaflow/widgets/gemini_formatted_text.dart';
import 'package:linguaflow/utils/language_helper.dart';

class FloatingTranslationCard extends StatefulWidget {
  final String originalText;
  final Future<String> translationFuture; // Google Translation from parent
  
  // Passed as a function for Lazy Loading (only calls API when clicked)
  final Future<String?> Function() onGetAiExplanation; 
  
  final String targetLanguage;
  final String nativeLanguage;
  final int currentStatus;
  final Offset anchorPosition;
  final Function(int, String) onUpdateStatus;
  final VoidCallback onClose;

  const FloatingTranslationCard({
    super.key,
    required this.originalText,
    required this.translationFuture,
    required this.onGetAiExplanation, 
    required this.targetLanguage,
    required this.nativeLanguage,
    required this.currentStatus,
    required this.anchorPosition,
    required this.onUpdateStatus,
    required this.onClose,
  });

  @override
  State<FloatingTranslationCard> createState() => _FloatingTranslationCardState();
}

class _FloatingTranslationCardState extends State<FloatingTranslationCard> {
  String _translationText = "Loading...";
  
  // AI State
  String? _aiText;
  bool _isAiLoading = false;

  // Internal TTS
  final FlutterTts _cardTts = FlutterTts();
  
  // Dragging State
  Offset _dragOffset = Offset.zero;

  // Tabs: 0=AI, 1=Reserved, 2=WordRef, 3=Glosbe, 4=Reverso
  int _selectedTabIndex = 0; 
  bool _isExpanded = false;
  
  // WebView Controller
  WebViewController? _webViewController;
  bool _isLoadingWeb = false;

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadCombinedTranslations();
  }

  // --- COMBINED LOADING LOGIC ---
  Future<void> _loadCombinedTranslations() async {
    // 1. Start fetching Google (Parent Future) immediately
    final googleFuture = widget.translationFuture;
    
    // 2. Start fetching MyMemory (Internal)
    final myMemoryFuture = _fetchMyMemoryInternal();

    // 3. Wait for Google first (Since you mentioned it works fine)
    String googleResult = "";
    try {
      googleResult = await googleFuture;
    } catch (_) {}

    String myMemoryResult = "";
    try {
      myMemoryResult = await myMemoryFuture;
    } catch (_) {}

    // 4. Combine Logic
    String combined = "";
    bool myMemoryValid = myMemoryResult.isNotEmpty && 
                         !myMemoryResult.startsWith("Error") && 
                         !myMemoryResult.startsWith("No results");

    // Strategy: For Sentences (spaces detected), prioritize Google. 
    // For single words, MyMemory often has better definitions, so show it first.
    bool isPhrase = widget.originalText.trim().contains(' ');

    if (isPhrase) {
      // --- PHRASE MODE: Google First ---
      if (googleResult.isNotEmpty) {
        combined = googleResult;
        if (myMemoryValid && myMemoryResult.trim().toLowerCase() != googleResult.trim().toLowerCase()) {
           combined += "\n\n[Alternative]\n$myMemoryResult";
        }
      } else if (myMemoryValid) {
        combined = myMemoryResult;
      }
    } else {
      // --- WORD MODE: MyMemory First ---
      if (myMemoryValid) {
        combined = myMemoryResult;
      }
      if (googleResult.isNotEmpty) {
        if (combined.isEmpty) {
          combined = googleResult;
        } else if (combined.trim().toLowerCase() != googleResult.trim().toLowerCase()) {
           combined += "\n\n[Google]\n$googleResult";
        }
      }
    }

    if (mounted) {
      setState(() {
        _translationText = combined.isNotEmpty ? combined : "Translation not found.";
      });
    }
  }

  void _initTts() async {
    await _cardTts.setLanguage(widget.targetLanguage);
    await _cardTts.setSpeechRate(0.5); 
    await _cardTts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers
        ],
        IosTextToSpeechAudioMode.voicePrompt
    );
  }

  void _speakWord() {
    _cardTts.speak(widget.originalText);
  }

  @override
  void dispose() {
    _cardTts.stop();
    super.dispose();
  }

  // --- API LOGIC (MyMemory Internal Helper) ---
  String _sanitizeLangCode(String code) {
    if (code.isEmpty) return 'en';
    // MyMemory expects "en", "es", not "en-US"
    if (code.contains('_')) return code.split('_')[0];
    if (code.contains('-')) return code.split('-')[0];
    return code;
  }

  Future<String> _fetchMyMemoryInternal() async {
    try {
      final src = _sanitizeLangCode(widget.targetLanguage);
      final tgt = _sanitizeLangCode(widget.nativeLanguage);
      
      final cleanText = widget.originalText.replaceAll('\n', ' ').trim();
      
      if (cleanText.isEmpty) return "";
      // MyMemory GET limit is around 500 chars. Longer phrases fail.
      if (cleanText.length > 500) return "No results (Text too long)";

      // Use Uri.https for safer encoding of phrases with special chars
      final queryParameters = {
        'q': cleanText,
        'langpair': '$src|$tgt',
        'mt': '1' // Force Machine Translation if no memory match
      };

      final uri = Uri.https('api.mymemory.translated.net', '/get', queryParameters);
      
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Check internal status (sometimes HTTP is 200 but status is 4xx)
        if (data['responseStatus'] != 200) return "No results found.";

        if (data['responseData'] != null) {
          String result = data['responseData']['translatedText'] ?? "";
          
          // Check for MyMemory errors or echoes (common with MT failures)
          if (result.contains("MYMEMORY WARNING") || 
              result.trim().toLowerCase() == cleanText.toLowerCase()) {
            return "No results found.";
          }
          return result;
        }
      }
      return "No results found.";
    } catch (e) {
      return "Error: $e";
    }
  }

  // --- WEBVIEW LOGIC ---
  String _getWebUrl(int index) {
    final src = _sanitizeLangCode(widget.targetLanguage);
    final tgt = _sanitizeLangCode(widget.nativeLanguage);
    // Use proper encoding for URLs
    final word = Uri.encodeComponent(widget.originalText);

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
          onWebResourceError: (error) {
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
        
        if (index == 0 && _aiText == null && !_isAiLoading) {
          _fetchAiExplanation();
        }
        
        if (index > 1) {
          _initializeWebView(index);
        } else {
          _webViewController = null;
        }
      }
    });
  }

  // --- LAZY AI FETCHER ---
  Future<void> _fetchAiExplanation() async {
    setState(() => _isAiLoading = true);
    try {
      final result = await widget.onGetAiExplanation();
      if (mounted) setState(() => _aiText = result ?? "No explanation available.");
    } catch (e) {
      if (mounted) setState(() => _aiText = "AI Error: $e");
    } finally {
      if (mounted) setState(() => _isAiLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    
    double? topPos, bottomPos, leftPos;
    double width;

    // --- POSITIONING LOGIC ---
    if (_isExpanded) {
      topPos = padding.top + 10;
      bottomPos = 0; 
      leftPos = 0; 
      width = screenSize.width; 
    } else {
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

    String flagAsset = LanguageHelper.getFlagEmoji(widget.nativeLanguage);

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
                                onPressed: _speakWord,
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
                      ? Expanded(child: _buildBodyContent(flagAsset)) 
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
    Widget metadata = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTabChip("AI", 0), 
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

    if (_isExpanded && _selectedTabIndex > 1) {
      return Column(
        children: [
          metadata,
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05)),
              child: _buildExpandedContent(),
            ),
          ),
        ],
      );
    }

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
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05)),
              child: _buildExpandedContent(),
            ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent() {
    if (_selectedTabIndex == 0) {
      if (_isAiLoading) {
        return Center(child: Padding(padding: const EdgeInsets.all(20), child: LinearProgressIndicator(color: Colors.blue.withOpacity(0.3), backgroundColor: Colors.transparent)));
      }
      if (_aiText != null) {
        return Padding(padding: const EdgeInsets.all(16), child: GeminiFormattedText(text: _aiText!));
      }
      return const Padding(padding: EdgeInsets.all(16), child: Text("Tap AI tab to load explanation.", style: TextStyle(color: Colors.grey)));
    }
    
    if (_webViewController != null) {
      return Stack(
        children: [
          WebViewWidget(controller: _webViewController!),
          if (_isLoadingWeb) const Center(child: CircularProgressIndicator(color: Colors.blue)),
        ],
      );
    }
    return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("Loading...", style: TextStyle(color: Colors.grey))));
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