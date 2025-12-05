import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';// -----------------------------------------------------------------------------
// PUSH NOTIFICATIONS TAB
// -----------------------------------------------------------------------------
// NEEDS INFO: Sending notifications usually requires a Cloud Function triggering
// off a Firestore write, or a direct HTTP request to FCM.
// This UI writes to a 'admin_notifications_queue' collection.
// You need a Backend script to watch this collection and actually send the FCM.
class PushNotificationsTab extends StatefulWidget {
  const PushNotificationsTab({super.key});
  @override
  State<PushNotificationsTab> createState() => _PushNotificationsTabState();
}

class _PushNotificationsTabState extends State<PushNotificationsTab> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _isSending = false;

  void _sendNotification() async {
    if(_titleCtrl.text.isEmpty || _bodyCtrl.text.isEmpty) return;
    setState(() => _isSending = true);

    // Write to Firestore Queue
    await FirebaseFirestore.instance.collection('admin_notifications_queue').add({
      'title': _titleCtrl.text,
      'body': _bodyCtrl.text,
      'target': 'all_users', // or specific segments
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    if(mounted) {
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Notification Queued! Backend will process it.")));
      _titleCtrl.clear();
      _bodyCtrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Send Global Push Notification", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: "Title (e.g. 50% Off)", border: OutlineInputBorder())),
          const SizedBox(height: 15),
          TextField(controller: _bodyCtrl, maxLines: 3, decoration: const InputDecoration(labelText: "Body Message", border: OutlineInputBorder())),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isSending ? null : _sendNotification,
              icon: _isSending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
              label: const Text("SEND BLAST"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            ),
          ),
          const SizedBox(height: 20),
          const Text("Make sure you have a Cloud Function watching 'admin_notifications_queue'!", style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}