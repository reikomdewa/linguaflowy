import 'dart:async';
import 'dart:io'; // Required for SocketException
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_gemini/flutter_gemini.dart' as gem;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:linguaflow/models/lesson_model.dart';

class AiConversationScreen extends StatefulWidget {
  final LessonModel lesson;

  const AiConversationScreen({super.key, required this.lesson});

  @override
  State<AiConversationScreen> createState() => _AiConversationScreenState();
}

class _AiConversationScreenState extends State<AiConversationScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<gem.Content> _chats = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeGemini();
  }

  void _initializeGemini() {
    final apiKey = dotenv.env['GEMINI_API_KEY'];

    if (apiKey != null && apiKey.isNotEmpty) {
      gem.Gemini.init(apiKey: apiKey);
    }

    final systemPrompt = '''
You are a language tutor.
Context: User just learned "${widget.lesson.title}" (${widget.lesson.type}).
Goal: Roleplay a scenario related to this topic.
INSTRUCTIONS:
1. Correct grammar mistakes gently in **bold**.
2. Keep replies under 40 words.
3. Start by welcoming the user to the topic.
4. IMPORTANT: Use standard Markdown only. Do NOT use HTML tags.
''';

    setState(() {
      _chats.add(gem.Content(
        role: 'user',
        parts: [gem.Part.text(systemPrompt)],
      ));
    });

    // Send the initial trigger using the robust function
    _submitToGemini(isInitial: true);
  }

  /// Centralized function to handle API calls and Errors
  Future<void> _submitToGemini({bool isInitial = false}) async {
    setState(() => _isLoading = true);
    if (!isInitial) _scrollToBottom();

    try {
      // 1. Set a Timeout
      final response = await gem.Gemini.instance.chat(_chats)
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      // 2. Validate Response Content
      if (response != null && response.output != null && response.output!.isNotEmpty) {
        setState(() {
          _chats.add(gem.Content(
            role: 'model',
            parts: [gem.Part.text(response.output!)],
          ));
          _isLoading = false;
        });
        _scrollToBottom();
      } else {
        // 3. Handle Empty Response (AI returned OK but no text)
        throw Exception("Empty response from AI");
      }

    } on TimeoutException {
      _handleError("The AI took too long to respond. Please try again.");
    } on SocketException {
      _handleError("No internet connection.");
    } catch (e) {
      // 4. Handle Specific Status Codes
      _parseAndHandleException(e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendMessage() async {
    final message = _textController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _chats.add(gem.Content(
        role: 'user',
        parts: [gem.Part.text(message)],
      ));
      _textController.clear();
    });
    
    // Call the robust function
    await _submitToGemini();
  }

  /// Parses the error object to give the user specific advice
  void _parseAndHandleException(Object e) {
    String errorString = e.toString().toLowerCase();
    String userMessage = "Something went wrong. Please try again.";

    // Debug print for developer
    debugPrint("Gemini Error: $errorString");

    if (errorString.contains('429')) {
      userMessage = "High traffic limit reached. Please wait a minute before sending another message.";
    } else if (errorString.contains('400') || errorString.contains('403')) {
      userMessage = "Configuration error (API Key). Please contact support.";
    } else if (errorString.contains('500') || errorString.contains('503')) {
      userMessage = "AI Server is currently down. Try again later.";
    } else if (errorString.contains('finishreason')) {
      userMessage = "The AI stopped mainly due to safety filters.";
    }

    _handleError(userMessage);
  }

  void _handleError(String msg) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).hideCurrentSnackBar(); // Hide previous errors
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: Colors.red[700],
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: () {
            // Logic to retry the last request
            // We remove the loading state before retry, so just calling submit works
            _submitToGemini(); 
          },
        ),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // ... (Keep your existing build method UI exactly the same) ...
    // Below is just the abbreviated return for context
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5);
    final cardColor = isDark ? const Color(0xFF1E272E) : Colors.white;

    final visibleChats = _chats.length > 1 ? _chats.sublist(1) : <gem.Content>[];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(widget.lesson.title, style: const TextStyle(fontSize: 16)),
        backgroundColor: cardColor,
        leading: IconButton(
          icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: visibleChats.length,
              itemBuilder: (context, index) {
                final content = visibleChats[index];
                final isUser = content.role == 'user';
                return _buildMessageBubble(content, isUser, isDark);
              },
            ),
          ),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0, left: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF263238) : Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 10, height: 10, 
                        child: CircularProgressIndicator(strokeWidth: 2, color: isDark ? Colors.white : Colors.black)
                      ),
                      const SizedBox(width: 8),
                      const Text("Thinking...", style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          // Input Area
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(16),
              color: cardColor,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      textCapitalization: TextCapitalization.sentences,
                      enabled: !_isLoading, // Disable input while loading to prevent spam
                      decoration: InputDecoration(
                        hintText: "Type in target language...",
                        filled: true,
                        fillColor: isDark ? Colors.black26 : Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.send, color: _isLoading ? Colors.grey : const Color(0xFF42A5F5)),
                    onPressed: _isLoading ? null : _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(gem.Content content, bool isUser, bool isDark) {
    // ... (Keep your existing bubble UI exactly the same) ...
    final text = content.parts
            ?.whereType<gem.TextPart>()
            .map((part) => part.text)
            .join(" ") ?? "";

    final textColor = isUser
        ? Colors.white
        : (isDark ? Colors.white : Colors.black87);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xFF42A5F5)
              : (isDark ? const Color(0xFF263238) : Colors.white),
          borderRadius: BorderRadius.circular(16),
        ),
        child: MarkdownBody(
          data: text,
          selectable: true, 
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(color: textColor, fontSize: 16, height: 1.4),
            strong: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}