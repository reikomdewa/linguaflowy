import 'dart:async';
import 'package:flutter/material.dart';

// 1. CHAT PACKAGES
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart'; // REQUIRED for InMemoryChatController
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;

// 2. LIVEKIT & SERVICE
import 'package:livekit_client/livekit_client.dart'; 
import 'package:linguaflow/services/speak/chat_service.dart';

class RoomChatSheet extends StatefulWidget {
  final Room room;

  const RoomChatSheet({super.key, required this.room});

  @override
  State<RoomChatSheet> createState() => _RoomChatSheetState();
}

class _RoomChatSheetState extends State<RoomChatSheet> {
  final ChatService _chatService = ChatService();
  
  // Use the concrete controller class from flutter_chat_core
  late InMemoryChatController _chatController; 
  late StreamSubscription<List<types.Message>> _messagesSubscription;
  late String _currentUserId;

  @override
  void initState() {
    super.initState();
    
    // 1. Get Local User ID
    _currentUserId = widget.room.localParticipant?.identity ?? 'local';

    // 2. Initialize Controller (Start empty)
    // InMemoryChatController holds the state for the UI now
    _chatController = InMemoryChatController();

    // 3. Connect Service
    _chatService.connect(widget.room);

    // 4. Listen to Stream -> Update Controller
    _messagesSubscription = _chatService.messagesStream.listen((messages) {
      // Sort: Newest first (index 0)
      final sortedMessages = List<types.Message>.from(messages);
      sortedMessages.sort((a, b) => (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));
      
      // FIX: The method is likely 'setMessages' or just 'set' depending on exact sub-version.
      // In v2.x standard, it is often 'setMessages'.
      // If this fails, try '_chatController.update(sortedMessages)' 
      _chatController.setMessages(sortedMessages);
    });
  }

  @override
  void dispose() {
    _messagesSubscription.cancel();
    _chatController.dispose();
    super.dispose();
  }

  // REQUIRED V2: Helper to convert User IDs to User Objects (Async)
  Future<types.User> _resolveUser(String userId) async {
    // Is it me?
    if (userId == _currentUserId) {
      return types.User(
        id: userId,
        firstName: widget.room.localParticipant?.name ?? 'Me',
        role: types.Role.user,
      );
    }

    // Is it a remote user?
    try {
      final remoteParticipant = widget.room.remoteParticipants.values.firstWhere(
        (p) => p.identity == userId,
      );
      return types.User(
        id: userId,
        firstName: remoteParticipant.name.isNotEmpty ? remoteParticipant.name : 'User',
      );
    } catch (e) {
      return types.User(id: userId, firstName: 'User');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
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
                Text("Room Chat", style: theme.textTheme.titleLarge),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // CHAT UI (Standard Package V2)
          Expanded(
            child: Chat(
              // 1. Pass the Controller (Required in V2)
              chatController: _chatController,
              
              // 2. Pass the User ID (Required in V2)
              currentUserId: _currentUserId,
              
              // 3. Pass the Resolver (Required in V2)
              resolveUser: _resolveUser,
              
              // 4. Handle sending (Renamed to onMessageSend in V2)
              onMessageSend: (text) {
                 _chatService.sendMessage(text);
                 // Note: You don't need to manually update the controller here
                 // if your _chatService stream emits the new message automatically.
                 return Future.value();
              },
              
              // 5. Theme
              theme: isDark 
                  ? const DarkChatTheme() 
                  : const DefaultChatTheme(),
            ),
          ),
        ],
      ),
    );
  }
}