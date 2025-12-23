import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseUtils {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  

  /// Fetches the purchase details for a specific user.
  /// Returns null if the user has not redeemed a code or if no data is found.
  Future<Map<String, dynamic>?> getPurchaseData(String userId) async {
    try {
      // Query the 'promo_codes' collection to find the document
      // where 'claimedBy' matches the current userId.
      final querySnapshot = await _db
          .collection('promo_codes')
          .where('claimedBy', isEqualTo: userId)
          .limit(1) // We assume one code per user for now
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        // Return the data map from the first matching document
        // return querySnapshot.docs.first.data();
        final doc = querySnapshot.docs.first;
        final data = doc.data();
        data['code_id'] =
            doc.id; // <--- ADD THIS LINE (Stores the key/ID in the map)
        return data;
      }
      return null;
    } catch (e) {
      print("Error fetching purchase data: $e");
      return null;
    }
  }
}
