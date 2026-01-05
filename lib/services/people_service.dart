import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:linguaflow/models/user_model.dart';

class PeopleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- 1. FETCH ALL COMMUNITY MEMBERS ---
  // Fetches users for the "All" tab. 
  // Filters out the current user and anyone they have blocked.
  Future<List<UserModel>> getCommunityUsers({
    required String currentUserId,
    List<String>? blockedUserIds,
    int limit = 20,
    DocumentSnapshot? lastDocument, // For pagination
  }) async {
    try {
      Query query = _firestore
          .collection('users')
          .orderBy('lastLoginDate', descending: true) // Show active users first
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final querySnapshot = await query.get();
      
      final List<UserModel> users = [];
      final blocked = blockedUserIds ?? [];

      for (var doc in querySnapshot.docs) {
        // Skip self
        if (doc.id == currentUserId) continue;
        
        // Skip blocked users
        if (blocked.contains(doc.id)) continue;

        // Map to Model
        try {
          final user = UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
          users.add(user);
        } catch (e) {
          print("Error parsing user ${doc.id}: $e");
        }
      }

      return users;
    } catch (e) {
      print("Error fetching community users: $e");
      return [];
    }
  }

  // --- 2. FETCH NEARBY USERS ---
  // Simple implementation: Matches "Country" or "City".
  // For precise radius (e.g., 10km), you would need GeoFlutterFire, 
  // but this is the standard "Tandem-style" location filter.
  Future<List<UserModel>> getNearbyUsers({
    required String currentUserId,
    required String myCountryCode, // e.g., 'MA'
    List<String>? blockedUserIds,
  }) async {
    try {
      // Query users in the same country
      final querySnapshot = await _firestore
          .collection('users')
          .where('countryCode', isEqualTo: myCountryCode)
          .limit(30)
          .get();

      final List<UserModel> users = [];
      final blocked = blockedUserIds ?? [];

      for (var doc in querySnapshot.docs) {
        if (doc.id == currentUserId) continue;
        if (blocked.contains(doc.id)) continue;

        users.add(UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id));
      }
      
      return users;
    } catch (e) {
      print("Error fetching nearby users: $e");
      return [];
    }
  }

  // --- 3. REFERENCE HELPERS ---
  // Since we store references as a List in the User Document (per the Model),
  // we don't need a separate database call. 
  // The 'referenceCount' is automatically calculated by the getter in your UserModel.
  
  // However, if you need to ADD a reference:
  Future<void> addReference({
    required String targetUserId,
    required UserReference reference,
  }) async {
    try {
      await _firestore.collection('users').doc(targetUserId).update({
        'references': FieldValue.arrayUnion([reference.toMap()]),
      });
    } catch (e) {
      print("Error adding reference: $e");
      rethrow;
    }
  }
}