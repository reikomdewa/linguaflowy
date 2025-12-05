import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// -----------------------------------------------------------------------------
// LEADERBOARD CONTROL TAB
// -----------------------------------------------------------------------------
// Functionality: View top players and BAN them if they are cheating.
// Assumes users have an 'xp' field (int).
class LeaderboardTab extends StatelessWidget {
  const LeaderboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users')
          .orderBy('xp', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            final uid = snapshot.data!.docs[index].id;
            final xp = data['xp'] ?? 0;
            
            return ListTile(
              leading: CircleAvatar(child: Text("${index + 1}")),
              title: Text(data['displayName'] ?? "Unknown"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("$xp XP", style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.gavel, color: Colors.red),
                    tooltip: "Reset Score (Ban)",
                    onPressed: () {
                      // RESET USER SCORE LOGIC
                      FirebaseFirestore.instance.collection('users').doc(uid).update({'xp': 0});
                    },
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }
}