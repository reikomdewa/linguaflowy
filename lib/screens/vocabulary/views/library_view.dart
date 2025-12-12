
import 'package:flutter/material.dart';

import 'package:linguaflow/models/vocabulary_item.dart';

// ==========================================
// 📚 LIBRARY VIEW
// ==========================================
class LibraryView extends StatelessWidget {
  final List<VocabularyItem> items;
  const LibraryView({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (items.isEmpty) {
      return const Center(child: Text("No words in library yet."));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          elevation: 0,
          color: isDark ? Colors.white10 : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.withOpacity(0.2)),
          ),
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(item.status).withOpacity(0.2),
              child: Text(
                '${item.status}',
                style: TextStyle(
                    color: _getStatusColor(item.status),
                    fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(item.word,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(item.translation),
            trailing: Text(
              _daysAgo(item.lastReviewed),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        );
      },
    );
  }

  String _daysAgo(DateTime date) {
    final diff = DateTime.now().difference(date).inDays;
    if (diff == 0) return "Today";
    return "$diff days ago";
  }

  Color _getStatusColor(int status) {
    if (status == 0) return Colors.blue;
    if (status < 5) return Colors.orange;
    return Colors.green;
  }
}