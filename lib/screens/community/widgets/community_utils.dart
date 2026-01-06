import 'package:flutter/material.dart';
import 'package:linguaflow/services/community_service.dart';
import 'package:linguaflow/models/user_model.dart';

void showReportDialog(
  BuildContext context,
  String contentId,
  String type,
  CommunityService service,
  UserModel user,
) {
  final controller = TextEditingController();
  String reason = "Spam";

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text("Report Content"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButton<String>(
              value: reason,
              isExpanded: true,
              items: [
                'Spam',
                'Abusive',
                'Copyright Violation',
                'Inappropriate',
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => reason = v!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: "Additional details (optional)",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              service.reportContent(
                reporterId: user.id,
                contentId: contentId,
                contentType: type,
                reason: reason,
                description: controller.text,
              );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Report received. We will review it shortly."),
                ),
              );
            },
            child: const Text("Report", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ),
  );
}

class StatBadge extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color color;
  const StatBadge({
    super.key,
    required this.icon,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          "$count",
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}