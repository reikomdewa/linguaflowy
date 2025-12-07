import 'dart:async'; // Required for TimeoutException
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_gemini/flutter_gemini.dart' as gem;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md; // Import for ExtensionSet
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

    // UPDATED PROMPT: Explicitly forbid HTML to prevent </blockquote > issues
    final systemPrompt = '''
You are a language tutor.
Context: User just learned "${widget.lesson.title}" (${widget.lesson.type}).
Goal: Roleplay a scenario related to this topic.
INSTRUCTIONS:
1. Correct grammar mistakes gently in **bold**.
2. Keep replies under 40 words.
3. Start by welcoming the user to the topic.
4. IMPORTANT: Use standard Markdown only (stars for bold/italics). Do NOT use HTML tags like <b>, <i>, or <blockquote>.
''';

    setState(() {
      _chats.add(gem.Content(
        role: 'user',
        parts: [gem.Part.text(systemPrompt)],
      ));
    });

    _sendInitialTrigger();
  }

  Future<void> _sendInitialTrigger() async {
    setState(() => _isLoading = true);
    try {
      // Added 20-second timeout
      final response = await gem.Gemini.instance.chat(_chats)
          .timeout(const Duration(seconds: 20));

      if (mounted && response?.output != null) {
        setState(() {
          _chats.add(gem.Content(
            role: 'model',
            parts: [gem.Part.text(response!.output!)],
          ));
          _isLoading = false;
        });
      }
    } on TimeoutException {
      _handleError("AI is taking too long. It might be busy or failed.");
    } catch (e) {
      _handleError("Connection error: $e");
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
      _isLoading = true;
      _textController.clear();
    });
    _scrollToBottom();

    try {
      // Added 20-second timeout
      final response = await gem.Gemini.instance.chat(_chats)
          .timeout(const Duration(seconds: 20));

      if (mounted && response?.output != null) {
        setState(() {
          _chats.add(gem.Content(
            role: 'model',
            parts: [gem.Part.text(response!.output!)],
          ));
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } on TimeoutException {
      _handleError("AI is maybe too busy or failed.");
    } catch (e) {
      _handleError("An error occurred. Please try again.");
      debugPrint("Gemini Error: $e");
    }
  }

  void _handleError(String msg) {
    if (!mounted) return;
    
    setState(() => _isLoading = false);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: () {
            // Remove the last user message if it failed so they can try again?
            // Or just leave it. Leaving it is usually safer.
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5);
    final cardColor = isDark ? const Color(0xFF1E272E) : Colors.white;

    final visibleChats = _chats.length > 1 ? _chats.sublist(1) : <gem.Content>[];

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(widget.lesson.title, style: const TextStyle(fontSize: 16)),
        backgroundColor: cardColor,
        elevation: 0,
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
                  child: const Text("AI is thinking...", style: TextStyle(fontSize: 12)),
                ),
              ),
            ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, -2),
                    blurRadius: 10,
                  )
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      textCapitalization: TextCapitalization.sentences,
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
                  CircleAvatar(
                    backgroundColor: const Color(0xFF42A5F5),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _sendMessage,
                    ),
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
    // 1. Extract text safely
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
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
          ),
          boxShadow: [
             if (!isUser && !isDark)
               BoxShadow(
                 color: Colors.black.withOpacity(0.05),
                 blurRadius: 4,
                 offset: const Offset(0, 2),
               ),
          ],
        ),
        // 2. Updated Markdown Body configuration
        child: MarkdownBody(
          data: text,
          selectable: true, // Allows user to copy text
          // GitHub Flavored Markdown handles things like strikethrough and tables better
          extensionSet: md.ExtensionSet.gitHubFlavored, 
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(color: textColor, fontSize: 16, height: 1.4),
            strong: TextStyle(color: textColor, fontWeight: FontWeight.bold),
            em: TextStyle(color: textColor, fontStyle: FontStyle.italic),
            listBullet: TextStyle(color: textColor),
            blockquote: TextStyle(
              color: textColor.withOpacity(0.8),
              fontStyle: FontStyle.italic,
            ),
            blockquoteDecoration: BoxDecoration(
              color: isUser ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}