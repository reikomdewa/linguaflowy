import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:livekit_client/livekit_client.dart';
import 'package:linguaflow/services/speak/chat_service.dart';

class RoomChatSheet extends StatefulWidget {
  final Room room;
  // FIX: Add this callback to handle closing without Navigator
  final VoidCallback? onClose; 

  const RoomChatSheet({
    super.key, 
    required this.room,
    this.onClose, // Optional parameter
  });

  @override
  State<RoomChatSheet> createState() => _RoomChatSheetState();
}

class _RoomChatSheetState extends State<RoomChatSheet> {
  final ChatService _chatService = ChatService();
  final TextEditingController _textController = TextEditingController();
  late String _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = widget.room.localParticipant?.identity ?? 'local';
    _chatService.connect(widget.room);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _chatService.sendMessage(text);
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = theme.scaffoldBackgroundColor;
    final inputColor = isDark ? Colors.grey[900] : Colors.grey[100];

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // HEADER
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Room Chat",
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    // --- FIX: HYBRID CLOSE LOGIC ---
                    onPressed: () {
                      if (widget.onClose != null) {
                        // Manual Mode (Overlay)
                        widget.onClose!();
                      } else {
                        // Modal Mode (Navigator)
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
      
            // MESSAGE LIST
            Expanded(
              child: StreamBuilder<List<types.Message>>(
                stream: _chatService.messagesStream,
                initialData: _chatService.currentMessages, 
                builder: (context, snapshot) {
                  final messages = snapshot.data ?? [];
      
                  if (messages.isEmpty) {
                    return Center(
                      child: Text(
                        "No messages yet.",
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    );
                  }
      
                  return ListView.builder(
                    reverse: true, 
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMe = message.author.id == _currentUserId;
                      
                      return _MessageBubble(
                        message: message, 
                        isMe: isMe,
                        isDark: isDark,
                      );
                    },
                  );
                },
              ),
            ),
      
            // INPUT AREA
            Container(
              padding: const EdgeInsets.only(
                left: 16, 
                right: 16, 
                top: 10, 
                bottom: 10 
              ),
              decoration: BoxDecoration(
                color: backgroundColor,
                border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: inputColor,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _textController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: "Type a message...",
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send),
                    color: Colors.blueAccent,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final types.Message message;
  final bool isMe;
  final bool isDark;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (message is! types.TextMessage) return const SizedBox.shrink();

    final textMessage = message as types.TextMessage;
    final time = message.createdAt != null 
        ? DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(message.createdAt!))
        : '';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe 
              ? Colors.blueAccent 
              : (isDark ? Colors.grey[800] : Colors.grey[200]),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text(
                  message.author.firstName ?? 'User',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                  ),
                ),
              ),
            
            Text(
              textMessage.text,
              style: TextStyle(
                color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
                fontSize: 16,
              ),
            ),

            if (time.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  time,
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe ? Colors.white70 : Colors.grey[500],
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
          ],
        ),
      ),
    );
  }
}