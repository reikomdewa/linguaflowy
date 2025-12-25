import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_state.dart';
import 'package:linguaflow/models/private_chat_models.dart';
import 'package:linguaflow/screens/inbox/private_chat_screen.dart'; // Ensure path is correct
import 'package:linguaflow/services/speak/private_chat_service.dart'; // Ensure path is correct

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

          // 2. HANDLE ERRORS (CRITICAL FIX)
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
                orElse: () => '', // Fallback if something is wrong
              );

              // Get their data
              final otherData = chat.participantData[otherId] ?? {};
              final name = otherData['name'] ?? 'User';
              final photo = otherData['photo'];

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
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
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