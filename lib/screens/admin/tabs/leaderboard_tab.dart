import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LeaderboardTab extends StatelessWidget {
  const LeaderboardTab({super.key});

  // Admin Tool: Manually modify a user's score
  void _adjustScore(BuildContext context, String userId, int currentXp, String name) {
    final controller = TextEditingController(text: currentXp.toString());
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Manage XP: $name"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Set new XP value (0 to reset/ban):", style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(), 
                labelText: "XP Amount",
                suffixText: "XP"
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              final newXp = int.tryParse(controller.text) ?? 0;
              FirebaseFirestore.instance.collection('users').doc(userId).update({
                'xp': newXp 
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Updated $name to $newXp XP")));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
            child: const Text("Update Score"),
          ),
        ],
      ),
    );
  }

  Color _getRankColor(int index) {
    switch (index) {
      case 0: return const Color(0xFFFFD700); // Gold
      case 1: return const Color(0xFFC0C0C0); // Silver
      case 2: return const Color(0xFFCD7F32); // Bronze
      default: return Colors.grey.withOpacity(0.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<QuerySnapshot>(
        // Only users with the 'xp' field will appear here due to Firestore indexing rules
        stream: FirebaseFirestore.instance
            .collection('users')
            .orderBy('xp', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error loading leaderboard: ${snapshot.error}"));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.leaderboard, size: 50, color: Colors.grey),
                  SizedBox(height: 10),
                  Text("No users with XP found yet."),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (ctx, i) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              
              final name = data['displayName'] ?? 'Unknown';
              final email = data['email'] ?? 'No Email';
              final xp = (data['xp'] as num?)?.toInt() ?? 0;
              final isPremium = data['isPremium'] == true;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                // Rank Badge
                leading: CircleAvatar(
                  backgroundColor: _getRankColor(index),
                  foregroundColor: index < 3 ? Colors.white : Colors.white,
                  child: Text(
                    "#${index + 1}", 
                    style: const TextStyle(fontWeight: FontWeight.bold)
                  ),
                ),
                // User Info
                title: Row(
                  children: [
                    Flexible(child: Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold))),
                    if (isPremium) 
                      const Padding(
                        padding: EdgeInsets.only(left: 6.0),
                        child: Icon(Icons.star, size: 14, color: Colors.amber),
                      )
                  ],
                ),
                subtitle: Text(email, maxLines: 1, overflow: TextOverflow.ellipsis),
                // XP & Edit Button
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Text(
                        "$xp XP", 
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      tooltip: "Moderate Score",
                      onPressed: () => _adjustScore(context, doc.id, xp, name),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}