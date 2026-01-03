import 'package:flutter/material.dart';
import 'package:linguaflow/models/speak/speak_models.dart';
// Import your room_member.dart if needed for type checking, though logic is below

class YouTubeRequestsSheet extends StatelessWidget {
  final ChatRoom room;
  final VoidCallback onClose;
  // Callback now sends the URL and the Map object to remove
  final Function(String url, Map<String, dynamic> requestMap) onAccept;

  const YouTubeRequestsSheet({
    super.key,
    required this.room,
    required this.onClose,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final requests = room.youtubeRequests ?? [];

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Material(
          color: const Color(0xFF1E1E1E),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Video Requests",
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: onClose,
                    )
                  ],
                ),
                const SizedBox(height: 10),

                if (requests.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text("No pending requests.", style: TextStyle(color: Colors.grey)),
                  ),

                ...requests.map((reqMap) {
                  final userId = reqMap['userId'];
                  final url = reqMap['url'] ?? '';
                  
                  // Find member object for Avatar/Name
                  final member = room.members.cast<dynamic>().firstWhere(
                    (m) => m.uid == userId, 
                    orElse: () => null
                  );
                  
                  final name = member?.displayName ?? "Unknown User";
                  final avatar = member?.avatarUrl;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey[800],
                      backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                      child: avatar == null ? const Icon(Icons.person, color: Colors.white) : null,
                    ),
                    title: Text(name, style: const TextStyle(color: Colors.white)),
                    // Show truncated URL
                    subtitle: Text(
                      url, 
                      maxLines: 1, 
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.blueAccent, fontSize: 12)
                    ),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        // Accept and Play directly
                        onAccept(url, reqMap);
                      },
                      child: const Text("Play"),
                    ),
                  );
                }),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}