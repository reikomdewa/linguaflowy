import 'package:flutter/material.dart';
import 'package:linguaflow/services/admin_service.dart'; // Import the service above
import 'package:timeago/timeago.dart' as timeago;

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // 1. Standalone TabBar
          Container(
            color: theme.cardColor, // Optional: background color for the tab bar
            child: TabBar(
              labelColor: theme.primaryColor,
              unselectedLabelColor: theme.hintColor,
              indicatorColor: theme.primaryColor,
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: const [
                Tab(
                  icon: Icon(Icons.school),
                  text: "Reported Tutors",
                ),
                Tab(
                  icon: Icon(Icons.person),
                  text: "Reported Users",
                ),
              ],
            ),
          ),
          
          // 2. The Content
          const Expanded(
            child: TabBarView(
              children: [
                _ReportsList(type: 'tutor_profile', collection: 'tutors'),
                _ReportsList(type: 'user', collection: 'users'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportsList extends StatelessWidget {
  final String type;
  final String collection; // 'tutors' or 'users' collection name in Firestore

  const _ReportsList({required this.type, required this.collection});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ReportModel>>(
      stream: AdminService().getReportsStream(type: type),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        final reports = snapshot.data ?? [];

        if (reports.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: Colors.green.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                const Text("All clear! No pending reports."),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: reports.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            return _ReportCard(
              report: reports[index],
              targetCollection: collection,
            );
          },
        );
      },
    );
  }
}

class _ReportCard extends StatelessWidget {
  final ReportModel report;
  final String targetCollection;

  const _ReportCard({required this.report, required this.targetCollection});

  void _handleDismiss(BuildContext context) async {
    await AdminService().dismissReport(report.id);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Report dismissed")));
    }
  }

  void _handleBan(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Ban User?"),
        content: const Text(
          "This will prevent the user from accessing the platform. This action is severe.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await AdminService().banTarget(
                report.targetId,
                report.id,
                targetCollection,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("User Banned & Report Closed")),
                );
              }
            },
            child: const Text(
              "Ban User",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header (Timestamp & ID)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "REPORT",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[700],
                    ),
                  ),
                ),
                Text(
                  timeago.format(report.timestamp),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 2. Target Info (Async Fetch)
            FutureBuilder<Map<String, dynamic>?>(
              future: AdminService().getTargetDetails(
                targetCollection,
                report.targetId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator();
                }

                final data = snapshot.data;
                final name =
                    data?['name'] ?? data?['displayName'] ?? 'Unknown User';
                final photo =
                    data?['imageUrl'] ??
                    data?['photoUrl']; // Handle Tutor vs User schema differences

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundImage: photo != null ? NetworkImage(photo) : null,
                    child: photo == null ? Text(name[0].toUpperCase()) : null,
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "ID: ${report.targetId}",
                    style: TextStyle(fontSize: 10, color: theme.hintColor),
                  ),
                );
              },
            ),

            const Divider(),

            // 3. Reason
            Text(
              "Reason:",
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.hintColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(report.reason, style: theme.textTheme.bodyMedium),

            const SizedBox(height: 16),

            // 4. Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleDismiss(context),
                    icon: const Icon(Icons.check),
                    label: const Text("Dismiss"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleBan(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.1),
                      foregroundColor: Colors.red,
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.block),
                    label: const Text("Ban User"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
