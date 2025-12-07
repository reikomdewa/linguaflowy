import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
// 1. Alias the package to avoid "Part" vs "Parts" conflicts
import 'package:flutter_gemini/flutter_gemini.dart' as gem; 
import 'package:flutter_markdown/flutter_markdown.dart';
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
  
  // 2. Use the alias 'gem' to force the correct Content type
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
Correct grammar mistakes gently in bold. Keep replies under 40 words.
Start by welcoming the user to the topic.
''';

    // 3. CORRECT SYNTAX: Use 'gem.Parts' (Plural) with named 'text' parameter
    // We add this to history so the AI knows the context, but we will filter it out of the UI
    setState(() {
      _chats.add(gem.Content(
        role: 'user', 
        parts: [gem.Parts(text: systemPrompt)] 
      ));
    });

    _sendInitialTrigger();
  }

  Future<void> _sendInitialTrigger() async {
    setState(() => _isLoading = true);
    try {
      // 4. Use 'chat' instead of 'prompt'. 'chat' sends the whole history so the AI remembers context.
      final response = await gem.Gemini.instance.chat(_chats);
      
      if (mounted && response?.output != null) {
        setState(() {
          _chats.add(gem.Content(
            role: 'model', 
            parts: [gem.Parts(text: response!.output)]
          ));
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Gemini Init Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    final message = _textController.text.trim();
    if (message.isEmpty) return;

    // Add User Message
    setState(() {
      _chats.add(gem.Content(
        role: 'user', 
        parts: [gem.Parts(text: message)]
      ));
      _isLoading = true;
      _textController.clear();
    });
    _scrollToBottom();

    try {
      // Send History to AI
      final response = await gem.Gemini.instance.chat(_chats);

      if (mounted && response?.output != null) {
        setState(() {
          _chats.add(gem.Content(
            role: 'model', 
            parts: [gem.Parts(text: response!.output)]
          ));
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint("Gemini Error: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
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

    // Filter out the system prompt (index 0) so the user doesn't see the instructions
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
    // 5. SAFE TEXT EXTRACTION
    // 'content.parts' is a list of 'gem.Parts' objects. 
    // We map them to their 'text' property (handling nulls) and join them.
    final text = content.parts
            ?.map((part) => part.text ?? "")
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
        child: MarkdownBody(
          data: text,
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(color: textColor, fontSize: 16, height: 1.4),
            strong: TextStyle(color: textColor, fontWeight: FontWeight.bold),
            em: TextStyle(color: textColor, fontStyle: FontStyle.italic),
            listBullet: TextStyle(color: textColor),
          ),
        ),
      ),
    );
  }
}