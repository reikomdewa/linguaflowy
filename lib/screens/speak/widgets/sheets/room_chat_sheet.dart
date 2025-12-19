import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:linguaflow/services/speak/chat_service.dart';
import 'package:livekit_client/livekit_client.dart'; // To get local user info

class RoomChatSheet extends StatefulWidget {
  final Room room;

  const RoomChatSheet({super.key, required this.room});

  @override
  State<RoomChatSheet> createState() => _RoomChatSheetState();
}

class _RoomChatSheetState extends State<RoomChatSheet> {
  final ChatService _chatService = ChatService();
  late types.User _currentUser;

  @override
  void initState() {
    super.initState();
    // Connect service to this room
    _chatService.connect(widget.room);
    
    // Define the local user for the UI
    _currentUser = types.User(
      id: widget.room.localParticipant?.identity ?? 'local',
      firstName: widget.room.localParticipant?.name ?? 'Me',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      // Height control for BottomSheet
      height: MediaQuery.of(context).size.height * 0.85, 
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
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
          
          // Chat UI
          Expanded(
            child: StreamBuilder<List<types.Message>>(
              stream: _chatService.messagesStream,
              initialData: const [],
              builder: (context, snapshot) {
                return Chat(
                  messages: snapshot.data ?? [],
                  onSendPressed: _handleSendPressed,
                  user: _currentUser,
                  theme: isDark 
                      ? const DarkChatTheme() 
                      : const DefaultChatTheme(),
                  // Optional: Customize theme to match your 'charcoal' look
                  // theme: DefaultChatTheme(
                  //   primaryColor: theme.primaryColor,
                  //   backgroundColor: theme.scaffoldBackgroundColor,
                  // ),
                  showUserAvatars: true,
                  showUserNames: true,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _handleSendPressed(types.PartialText message) {
    _chatService.sendMessage(message.text);
  }
}