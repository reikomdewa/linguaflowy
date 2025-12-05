import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// -----------------------------------------------------------------------------
// BUG VIEW TAB
// -----------------------------------------------------------------------------
// Functionality: View error reports submitted by users.
// NEEDS INFO: You need to implement a function in your app that writes to 'bug_reports'
// when a user clicks "Report Problem".
class BugViewTab extends StatelessWidget {
  const BugViewTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('bug_reports')
          .where('status', isNotEqualTo: 'closed') // Only show open bugs
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No open bugs! Good job."));

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            
            return Card(
              margin: const EdgeInsets.all(8),
              child: ExpansionTile(
                leading: const Icon(Icons.bug_report, color: Colors.orange),
                title: Text(data['title'] ?? 'Error Report'),
                subtitle: Text("User: ${data['userId'] ?? 'Anon'}"),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Description: ${data['description']}"),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.check),
                          label: const Text("Mark Resolved"),
                          onPressed: () {
                            doc.reference.update({'status': 'closed'});
                          },
                        )
                      ],
                    ),
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