import 'package:flutter/material.dart';
import 'package:linguaflow/models/speak/speak_models.dart';

class JoinRequestsSheet extends StatelessWidget {
  final ChatRoom room;
  final VoidCallback onClose;
  final Function(String userId, Map<String, dynamic> req) onAccept;
  final Function(Map<String, dynamic> req) onDeny;

  const JoinRequestsSheet({
    super.key,
    required this.room,
    required this.onClose,
    required this.onAccept,
    required this.onDeny,
  });

  @override
  Widget build(BuildContext context) {
    final requests = room.joinRequests;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        color: const Color(0xFF1E1E1E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 40),
                  const Text(
                    "Join Requests",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: onClose,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (requests.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    "No pending requests.",
                    style: TextStyle(color: Colors.white54),
                  ),
                ),

              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final req = requests[index];
                    final name = req['displayName'] ?? "Unknown";
                    final uid = req['uid'];
                    final avatar = req['avatarUrl'];

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: (avatar != null) ? NetworkImage(avatar) : null,
                        child: (avatar == null) ? const Icon(Icons.person) : null,
                      ),
                      title: Text(name, style: const TextStyle(color: Colors.white)),
                      subtitle: const Text("Banned User", style: TextStyle(color: Colors.redAccent, fontSize: 10)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () => onDeny(req),
                          ),
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () => onAccept(uid, req),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}