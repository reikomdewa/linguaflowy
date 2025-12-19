import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:linguaflow/blocs/speak/speak_bloc.dart';
import 'package:linguaflow/blocs/speak/speak_event.dart';
import 'package:linguaflow/models/speak_models.dart';
import 'package:linguaflow/screens/speak/widgets/active_room_screen.dart';
import 'package:linguaflow/services/speak/speak_service.dart';
import 'package:linguaflow/utils/language_helper.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:dotted_border/dotted_border.dart'; // Import Model

class RoomCard extends StatelessWidget {
  final ChatRoom room; // Add this field

  const RoomCard({
    super.key,
    required this.room, // Require it in constructor
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Use Real Data from 'this.room'
    final bool isPaid = room.isPaid;
    final int currentMembers = room.memberCount;
    final int limit = room.maxMembers;
    final String language = room.language;
    final String level = room.level;
    final String title = room.title;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: theme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: Colors.blueGrey,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        LanguageHelper.getFlagEmoji(
                          language,
                        ), // Example for English
                        style: TextStyle(fontSize: 14),
                      ), // You can map flags later
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "$language ($level)",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: currentMembers >= limit
                        ? Colors.red.withOpacity(0.1)
                        : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.mic,
                        size: 14,
                        color: currentMembers >= limit
                            ? Colors.red
                            : Colors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "$currentMembers/$limit",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: currentMembers >= limit
                              ? Colors.red
                              : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  radius: 40,

                  child: Text(
                    room.hostName?[0] ?? "U",
                    style: const TextStyle(fontSize: 8, color: Colors.white),
                  ),
                ),
                CircleAvatar(
                  radius: 40,

                  child: Text(
                    room.hostName?[0] ?? "U",
                    style: const TextStyle(fontSize: 8, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Spacer(),

                // Avatars
                SizedBox(
                  width: 35,
                  height: 20,
                  child: Stack(
                    children: [
                      const Positioned(
                        left: 0,
                        child: CircleAvatar(
                          radius: 10,
                          backgroundColor: Colors.grey,
                        ),
                      ),
                      Positioned(
                        left: 14,
                        child: CircleAvatar(
                          radius: 10,
                          backgroundColor: theme.primaryColor,
                          child: Text(
                            room.hostName?[0] ?? "U",
                            style: const TextStyle(
                              fontSize: 8,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  "+${currentMembers > 0 ? currentMembers - 1 : 0} others",
                  style: TextStyle(fontSize: 12, color: theme.hintColor),
                ),
              ],
            ),
            const SizedBox(height: 8),

            /// Join Button
            SizedBox(
              width: double.infinity * 0.2,
              child: DottedBorder(
                // Version 3.x uses the options parameter for styling
                options: RoundedRectDottedBorderOptions(
                  color: const Color.fromRGBO(
                    145,
                    155,
                    162,
                    1,
                  ), // Light blue color from your screenshot
                  strokeWidth: 1.2,
                  dashPattern: const [6, 3], // Length of dash, length of space
                  radius: const Radius.circular(12),
                ),
                child: TextButton(
                  onPressed: () => isPaid
                      ? _showPaymentDialog(context)
                      : _joinRoom(context, room),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(double.infinity * 0.2, 48),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        Icons
                            .call_outlined, // Matches the thin phone icon in your image
                        color: Color(0xFF2196F3),
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        "Join and talk", // Exact text from your screenshot
                        style: TextStyle(
                          color: Color(0xFF2196F3),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (isPaid)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.amber),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  "\$ PAID",
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _joinRoom(BuildContext context, ChatRoom roomData) async {
    // 1. Show Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      const liveKitUrl = 'wss://linguaflow-7eemmnrq.livekit.cloud';

      // 3. Get Real Token
      final currentUser = FirebaseAuth.instance.currentUser;
      final username = currentUser?.displayName ?? "Guest";

      // CALL THE SERVICE HERE
      final token = await SpeakService().getLiveKitToken(roomData.id, username);

      // 4. Connect
      final room = Room();
      final options = const RoomOptions(adaptiveStream: true, dynacast: true);

      await room.connect(liveKitUrl, token, roomOptions: options);

      // 5. Update Bloc
      if (context.mounted) {
        context.read<SpeakBloc>().add(RoomJoined(room)); // Notify Bloc
        Navigator.pop(context); // Remove Loading

        // 6. Navigate to Room View
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ActiveRoomScreen(roomData: roomData, livekitRoom: room),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Remove Loading
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to connect: $e")));
      }
    }
  }

  void _showPaymentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Join Paid Session"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("This host requires payment."),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(
                labelText: "Enter Access Code",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            const Divider(),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(FontAwesomeIcons.googlePay),
                label: const Text("Pay \$5.00"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(onPressed: () {}, child: const Text("Join")),
        ],
      ),
    );
  }
}
