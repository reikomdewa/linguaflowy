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
      default: return Colors.blueGrey.withOpacity(0.2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .orderBy('xp', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text("No users found."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              
              // --- DATA EXTRACTION ---
              final name = data['displayName'] ?? 'Unknown';
              final email = data['email'] ?? 'No Email';
              final xp = (data['xp'] as num?)?.toInt() ?? 0;
              final isPremium = data['isPremium'] == true;
              
              // New Stats
              final streak = (data['streakDays'] as num?)?.toInt() ?? 0;
              final mins = (data['totalListeningMinutes'] as num?)?.toInt() ?? 0;
              final lessons = (data['lessonsCompleted'] as num?)?.toInt() ?? 0;
              final curLang = (data['currentLanguage'] ?? '--').toString().toUpperCase();
              
              // Get current level for current language
              final levels = data['languageLevels'] as Map<String, dynamic>? ?? {};
              final levelName = levels[data['currentLanguage']] ?? 'A1';

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                elevation: 0,
                color: Colors.white.withOpacity(0.05),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.white10)),
                child: ExpansionTile(
                  shape: const RoundedRectangleBorder(side: BorderSide.none),
                  collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
                  leading: CircleAvatar(
                    backgroundColor: _getRankColor(index),
                    child: Text("#${index + 1}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  title: Row(
                    children: [
                      Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                      if (isPremium) const Icon(Icons.verified, size: 16, color: Colors.amber),
                    ],
                  ),
                  subtitle: Text("$xp XP", style: TextStyle(color: Colors.blueAccent.shade100, fontWeight: FontWeight.w600)),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_note, color: Colors.grey),
                    onPressed: () => _adjustScore(context, doc.id, xp, name),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        children: [
                          const Divider(color: Colors.white10),
                          const SizedBox(height: 8),
                          // Stats Grid
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildMiniStat(Icons.local_fire_department, "$streak Days", "Streak", Colors.orange),
                              _buildMiniStat(Icons.headset, "${mins}m", "Listened", Colors.purpleAccent),
                              _buildMiniStat(Icons.task_alt, "$lessons", "Lessons", Colors.green),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Language Info
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(10)
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.translate, size: 18, color: Colors.grey),
                                const SizedBox(width: 8),
                                Text("Learning: $curLang", style: const TextStyle(color: Colors.white70)),
                                const Spacer(),
                                Text(levelName, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text("Contact: $email", style: const TextStyle(color: Colors.white38, fontSize: 11)),
                          )
                        ],
                      ),
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

  Widget _buildMiniStat(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    );
  }
}