import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:linguaflow/utils/language_helper.dart';
import 'package:linguaflow/widgets/gemini_formatted_text.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
// 1. ADD THIS IMPORT
import 'package:shared_preferences/shared_preferences.dart';

class FullscreenTranslationCard extends StatefulWidget {
  final String originalText;
  final String? baseForm;
  final Future<String> translationFuture;
  final Future<String?> Function() onGetAiExplanation;
  final String targetLanguage;
  final String nativeLanguage;
  final int currentStatus;
  final Function(int, String) onUpdateStatus;
  final VoidCallback onClose;

  const FullscreenTranslationCard({
    super.key,
    required this.originalText,
    this.baseForm,
    required this.translationFuture,
    required this.onGetAiExplanation,
    required this.targetLanguage,
    required this.nativeLanguage,
    required this.currentStatus,
    required this.onUpdateStatus,
    required this.onClose,
  });

  @override
  State<FullscreenTranslationCard> createState() =>
      _FullscreenTranslationCardState();
}

class _FullscreenTranslationCardState extends State<FullscreenTranslationCard> {
  String _translationText = "Loading...";
  String? _rootTranslation; // Stores meaning of root
  String? _aiText;
  bool _isAiLoading = false;
  final FlutterTts _cardTts = FlutterTts();
  Offset _position = const Offset(100, 50);
  int _selectedTabIndex = 0;
  bool _isExpanded = false;
  WebViewController? _webViewController;
  bool _isLoadingWeb = false;

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadCombinedTranslations();
    _loadRootTranslation();
  }

  // ---------------------------------------------------------------------------
  // 2. HELPER: Apply the Saved Voice from Preferences
  // ---------------------------------------------------------------------------
  Future<void> _applySavedVoice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Resolve Code (e.g., "Spanish" -> "es")
      final String cleanLangCode = LanguageHelper.getLangCode(widget.targetLanguage);
      
      // Construct Keys
      final String nameKey = 'tts_voice_name_$cleanLangCode';
      final String localeKey = 'tts_voice_locale_$cleanLangCode';

      // Load Values
      final savedVoiceName = prefs.getString(nameKey);
      final savedVoiceLocale = prefs.getString(localeKey);

      // Apply Voice
      if (savedVoiceName != null && savedVoiceLocale != null) {
        await _cardTts.setVoice({
          "name": savedVoiceName,
          "locale": savedVoiceLocale,
        });
      }
    } catch (e) {
      debugPrint("Fullscreen TTS Error: $e");
    }
  }

  // ---------------------------------------------------------------------------
  // 3. UPDATED INIT TTS
  // ---------------------------------------------------------------------------
  void _initTts() async {
    await _cardTts.setLanguage(widget.targetLanguage);
    await _cardTts.setSpeechRate(0.5);
    // Apply voice AFTER setting language
    await _applySavedVoice();
  }

  // ---------------------------------------------------------------------------
  // 4. UPDATED SPEAK FUNCTION
  // ---------------------------------------------------------------------------
  Future<void> _speakText() async {
    // Re-apply voice before speaking to prevent reverting to default
    await _applySavedVoice();
    await _cardTts.speak(widget.originalText);
  }

  @override
  void dispose() {
    _cardTts.stop();
     // Clear the webview controller to help GC
    if (_webViewController != null) {
      _webViewController!.clearCache();
      _webViewController = null;
    }
    super.dispose();
  }

  // --- ROOT TRANSLATION LOGIC ---
  Future<void> _loadRootTranslation() async {
    if (widget.baseForm == null || widget.baseForm == widget.originalText) {
      return;
    }

    // Simple fetch for the root word
    final result = await _fetchTranslationApi(widget.baseForm!);
    if (result.isNotEmpty &&
        !result.startsWith("Error") &&
        !result.startsWith("No results")) {
      if (mounted) {
        setState(() {
          _rootTranslation = result;
        });
      }
    }
  }

  // --- MAIN TRANSLATION LOGIC ---
  Future<void> _loadCombinedTranslations() async {
    final googleFuture = widget.translationFuture;
    final myMemoryFuture = _fetchTranslationApi(widget.originalText);

    String googleResult = "";
    try {
      googleResult = await googleFuture;
    } catch (_) {}

    String myMemoryResult = "";
    try {
      myMemoryResult = await myMemoryFuture;
    } catch (_) {}

    bool myMemoryValid =
        myMemoryResult.isNotEmpty &&
        !myMemoryResult.startsWith("Error") &&
        !myMemoryResult.startsWith("No results");
    
    bool isPhrase = widget.originalText.trim().contains(' ');

    // Collect unique translations into a list
    List<String> translationList = [];

    if (isPhrase) {
      if (googleResult.isNotEmpty) {
        translationList.add(googleResult);
      }
      if (myMemoryValid) {
        // Only add if it's different from Google result
        if (googleResult.isEmpty || 
            myMemoryResult.trim().toLowerCase() != googleResult.trim().toLowerCase()) {
          translationList.add(myMemoryResult);
        }
      }
    } else {
      // For single words
      if (myMemoryValid) {
        translationList.add(myMemoryResult);
      }
      if (googleResult.isNotEmpty) {
        // Only add if different
        if (translationList.isEmpty || 
            translationList.first.trim().toLowerCase() != googleResult.trim().toLowerCase()) {
          translationList.add(googleResult);
        }
      }
    }

    String finalOutput;
    if (translationList.isEmpty) {
      finalOutput = "Translation not found.";
    } else {
      // Format as Markdown bullets: "- Translation"
      finalOutput = translationList.map((t) => "- $t").join("\n");
    }

    if (mounted) {
      setState(() {
        _translationText = finalOutput;
      });
    }
  }

  // Helper method to fetch translation for ANY text
  Future<String> _fetchTranslationApi(String textToTranslate) async {
    try {
      final src = LanguageHelper.getLangCode(widget.targetLanguage);
      final tgt = LanguageHelper.getLangCode(widget.nativeLanguage);
      final cleanText = textToTranslate.replaceAll('\n', ' ').trim();
      if (cleanText.isEmpty || cleanText.length > 500) return "";

      final queryParameters = {
        'q': cleanText,
        'langpair': '$src|$tgt',
        'mt': '1',
      };
      final uri = Uri.https(
        'api.mymemory.translated.net',
        '/get',
        queryParameters,
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['responseStatus'] == 200 && data['responseData'] != null) {
          String result = data['responseData']['translatedText'] ?? "";
          if (!result.contains("MYMEMORY WARNING")) return result;
        }
      }
      return "";
    } catch (e) {
      return "";
    }
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

  Future<void> _fetchAiExplanation() async {
    setState(() => _isAiLoading = true);
    try {
      final result = await widget.onGetAiExplanation();
      if (mounted) setState(() => _aiText = result ?? "No explanation.");
    } catch (e) {
      if (mounted) setState(() => _aiText = "Error: $e");
    } finally {
      if (mounted) setState(() => _isAiLoading = false);
    }
  }

  void _initializeWebView(int index) {
    setState(() => _isLoadingWeb = true);
    final src = LanguageHelper.getLangCode(widget.targetLanguage);
    final tgt = LanguageHelper.getLangCode(widget.nativeLanguage);

    // Use base form for better dictionary lookup
    final searchText = widget.baseForm ?? widget.originalText;
    final word = Uri.encodeComponent(searchText);

    String url = "";
    if (index == 2) url = "https://www.wordreference.com/${src}en/$word";
    if (index == 3) url = "https://glosbe.com/$src/$tgt/$word";
    if (index == 4) {
      url = "https://context.reverso.net/translation/$src-$tgt/$word";
    }

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF1C1C1E))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoadingWeb = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    final flag = LanguageHelper.getFlagEmoji(widget.nativeLanguage);
    final size = MediaQuery.of(context).size;
    final width = _isExpanded ? size.width * 0.8 : 400.0;
    final height = _isExpanded ? size.height * 0.8 : null;

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position += details.delta;
          });
        },
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: width,
            height: height,
            constraints: BoxConstraints(maxHeight: size.height * 0.9),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.volume_up, color: Colors.blue),
                        // 5. USE UPDATED SPEAK FUNCTION
                        onPressed: _speakText, 
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.originalText,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: widget.onClose,
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white10, height: 1),

                // Body
                _isExpanded
                    ? Expanded(child: _buildBodyContent(flag))
                    : Flexible(child: _buildBodyContent(flag)),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // ... [Rest of your build methods remain exactly the same] ...
  Widget _buildBodyContent(String flag) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      // REPLACED Text with MarkdownBody
                      child: MarkdownBody(
                        data: _translationText,
                        styleSheet: MarkdownStyleSheet(
                          p: const TextStyle(
                            fontSize: 18,
                            color: Colors.white70,
                            height: 1.4,
                          ),
                          listBullet: const TextStyle(
                            fontSize: 18,
                            color: Colors.white70,
                          ),
                          listIndent: 20.0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(flag, style: const TextStyle(fontSize: 20)),
                  ],
                ),

                // --- ROOT + MEANING DISPLAY ---
                if (widget.baseForm != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: RichText(
                      text: TextSpan(
                        children: [
                          const TextSpan(
                            text: "Root: ",
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          TextSpan(
                            text: widget.baseForm,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          // If we have fetched the meaning, show it
                          if (_rootTranslation != null)
                            TextSpan(
                              text: " ($_rootTranslation)",
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],

                // ----------------------------------------
                const SizedBox(height: 16),
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
          ),
          if (_isExpanded)
            Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
              ),
              child: _buildExpandedContent(),
            ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent() {
    if (_selectedTabIndex == 0) {
      if (_isAiLoading) return const Center(child: CircularProgressIndicator());
      if (_aiText != null) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: GeminiFormattedText(text: _aiText!),
        );
      }
      return const Center(
        child: Text(
          "Tap AI tab to load.",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    if (_webViewController != null) {
      return Stack(
        children: [
          WebViewWidget(controller: _webViewController!),
          if (_isLoadingWeb) const Center(child: CircularProgressIndicator()),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildRankButton(String label, int status, Color color) {
    final isActive =
        (widget.currentStatus == 0 ? 0 : widget.currentStatus) == status;
    return GestureDetector(
      onTap: () => widget.onUpdateStatus(status, _translationText),
      child: Container(
        width: 40,
        height: 35,
        decoration: BoxDecoration(
          color: isActive ? color : color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? Colors.transparent : color.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : color,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
        ),
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
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}