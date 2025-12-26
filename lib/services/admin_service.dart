import 'package:cloud_firestore/cloud_firestore.dart';

// ==========================================
// 1. REPORT MODEL
// ==========================================
class ReportModel {
  final String id;
  final String targetId;   // The ID of the Tutor or User being reported
  final String reporterId; // Who sent the report
  final String reason;
  final String type;       // 'tutor_profile' or 'user'
  final String status;     // 'pending', 'resolved'
  final DateTime timestamp;

  ReportModel({
    required this.id,
    required this.targetId,
    required this.reporterId,
    required this.reason,
    required this.type,
    required this.status,
    required this.timestamp,
  });

  factory ReportModel.fromMap(Map<String, dynamic> map, String id) {
    return ReportModel(
      id: id,
      targetId: map['targetId'] ?? '',
      reporterId: map['reporterId'] ?? '',
      reason: map['reason'] ?? 'No reason provided',
      type: map['type'] ?? 'user',
      status: map['status'] ?? 'pending',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

// ==========================================
// 2. ADMIN SERVICE
// ==========================================
class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream of Reports filtered by Type (Tutor vs User)
  Stream<List<ReportModel>> getReportsStream({required String type}) {
    return _firestore
        .collection('reports')
        .where('type', isEqualTo: type)
        .where('status', isEqualTo: 'pending') // Only show unresolved
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ReportModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // Action: Dismiss Report (Mark as Resolved)
  Future<void> dismissReport(String reportId) async {
    await _firestore.collection('reports').doc(reportId).update({
      'status': 'resolved',
      'resolvedAt': FieldValue.serverTimestamp(),
      'actionTaken': 'dismissed',
    });
  }

  // Action: Ban User/Tutor
  // This disables their account in your database
  Future<void> banTarget(String targetId, String reportId, String collection) async {
    final batch = _firestore.batch();

    // 1. Mark user as banned
    final targetRef = _firestore.collection(collection).doc(targetId);
    batch.update(targetRef, {'isBanned': true});

    // 2. Mark report as resolved
    final reportRef = _firestore.collection('reports').doc(reportId);
    batch.update(reportRef, {
      'status': 'resolved',
      'resolvedAt': FieldValue.serverTimestamp(),
      'actionTaken': 'banned',
    });

    await batch.commit();
  }

  // Helper to fetch details of the accused person
  Future<Map<String, dynamic>?> getTargetDetails(String collection, String id) async {
    try {
      final doc = await _firestore.collection(collection).doc(id).get();
      return doc.data();
    } catch (e) {
      return null;
    }
  }
}