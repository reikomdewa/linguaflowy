import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_state.dart';
import 'package:linguaflow/models/private_chat_models.dart';
import 'package:linguaflow/screens/inbox/private_chat_screen.dart';
import 'package:linguaflow/services/speak/private_chat_service.dart';

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      return const Scaffold(body: Center(child: Text("Please log in")));
    }

    final myUser = authState.user;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Messages")),
      body: StreamBuilder<List<PrivateConversation>>(
        stream: PrivateChatService().getInbox(myUser.id),
        builder: (context, snapshot) {
          // 1. HANDLE LOADING
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. HANDLE ERRORS
          if (snapshot.hasError) {
            debugPrint("❌ Inbox Query Error: ${snapshot.error}");
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "Could not load messages.\n\nCheck debug console for Firestore Index link.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            );
          }

          // 3. HANDLE EMPTY DATA
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: theme.hintColor,
                  ),
                  const SizedBox(height: 16),
                  const Text("No messages yet"),
                ],
              ),
            );
          }

          final chats = snapshot.data!;

          // 4. SHOW LIST
          return ListView.separated(
            itemCount: chats.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final chat = chats[index];

              // Find the other person's ID safely
              final otherId = chat.participants.firstWhere(
                (id) => id != myUser.id,
                orElse: () => '',
              );

              // Get their data
              final otherData = chat.participantData[otherId] ?? {};
              final name = otherData['name'] ?? 'User';
              final photo = otherData['photo'];

              // --- UNREAD LOGIC ---
              // 1. Did I send the last message?
              final bool isLastMsgFromMe = chat.lastSenderId == myUser.id;
              // 2. Is it marked read?
              final bool isRead = chat.isRead;
              // 3. Result: It is unread ONLY if I didn't send it AND it's marked false
              final bool isUnread = !isLastMsgFromMe && !isRead;

              // Color for unread text (Black/White vs Grey)
              final Color messageColor = isUnread
                  ? (theme.brightness == Brightness.dark ? Colors.white : Colors.black)
                  : theme.hintColor;

              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: photo != null ? NetworkImage(photo) : null,
                  child: photo == null ? Text(name.isNotEmpty ? name[0] : '?') : null,
                ),
                title: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  chat.lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    // --- BOLD IF UNREAD ---
                    fontWeight: isUnread ? FontWeight.w800 : FontWeight.normal,
                    color: messageColor,
                  ),
                ),
                // Optional: Show a blue dot if unread
                trailing: isUnread 
                    ? Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: theme.primaryColor, 
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PrivateChatScreen(
                        chatId: chat.id,
                        otherUserName: name,
                        otherUserPhoto: photo,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}