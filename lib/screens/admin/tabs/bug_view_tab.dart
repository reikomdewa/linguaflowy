import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Add intl to pubspec.yaml for date formatting

class BugViewTab extends StatefulWidget {
  const BugViewTab({super.key});

  @override
  State<BugViewTab> createState() => _BugViewTabState();
}

class _BugViewTabState extends State<BugViewTab> {
  String _filterStatus = 'open'; // 'open', 'in_progress', 'resolved'

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.amber;
      default:
        return Colors.green;
    }
  }

  void _openDetailDialog(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final status = data['status'] ?? 'open';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.bug_report,
              color: _getSeverityColor(data['severity'] ?? 'low'),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(data['title'] ?? 'No Title')),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow("User:", "${data['userEmail']} (${data['userId']})"),
                _detailRow("Device:", data['deviceInfo'] ?? 'Unknown'),
                _detailRow("App Version:", data['appVersion'] ?? 'Unknown'),
                _detailRow(
                  "Date:",
                  data['createdAt'] != null
                      ? (data['createdAt'] as Timestamp).toDate().toString()
                      : 'Unknown',
                ),
                const Divider(),
                const Text(
                  "Description:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.all(10),
                  width: double.infinity,
                  color: Colors.grey.withOpacity(0.1),
                  child: Text(
                    data['description'] ?? 'No description provided.',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (status != 'resolved')
            TextButton(
              onPressed: () {
                doc.reference.update({'status': 'resolved'});
                Navigator.pop(ctx);
              },
              child: const Text(
                "Mark Resolved",
                style: TextStyle(color: Colors.green),
              ),
            ),
          if (status == 'open')
            TextButton(
              onPressed: () {
                doc.reference.update({'status': 'in_progress'});
                Navigator.pop(ctx);
              },
              child: const Text(
                "Mark In Progress",
                style: TextStyle(color: Colors.blue),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter Bar
        Padding(
          padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
          child: Row(
            children: [
              // const Text("Filter: ", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              FilterChip(
                label: const Text("Open & In Progress"),
                selected: _filterStatus == 'open',
                onSelected: (val) => setState(() => _filterStatus = 'open'),
              ),
              const SizedBox(width: 10),
              FilterChip(
                label: const Text("Resolved / Closed"),
                selected: _filterStatus == 'resolved',
                onSelected: (val) => setState(() => _filterStatus = 'resolved'),
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('bug_reports')
                .where(
                  'status',
                  whereIn: _filterStatus == 'open'
                      ? ['open', 'in_progress']
                      : ['resolved'],
                )
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return Center(child: Text("Error: ${snapshot.error}"));
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());

              if (snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 60,
                        color: Colors.green.withOpacity(0.5),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _filterStatus == 'open'
                            ? "No open bugs!"
                            : "No resolved history.",
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final severity = data['severity'] ?? 'medium';
                  final status = data['status'] ?? 'open';

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: ListTile(
                      onTap: () => _openDetailDialog(doc),
                      leading: CircleAvatar(
                        backgroundColor: _getSeverityColor(severity),
                        child: Icon(
                          severity == 'critical'
                              ? Icons.warning
                              : Icons.bug_report,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        data['title'] ?? 'Error',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        "${DateFormat('MMM d').format((data['createdAt'] as Timestamp).toDate())} • ${data['userEmail']}",
                        maxLines: 1,
                      ),
                      trailing: Chip(
                        label: Text(
                          status.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                          ),
                        ),
                        backgroundColor: status == 'in_progress'
                            ? Colors.blue
                            : (status == 'resolved'
                                  ? Colors.grey
                                  : Colors.green),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
