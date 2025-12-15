// import 'dart:convert';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:http/http.dart' as http;

// class PremiumService {
//   final FirebaseFirestore _db = FirebaseFirestore.instance;

//   // FIX: Use the Product ID from your error log instead of the permalink
//   static const String _gumroadProductId = "uIq5F1GwaxHuVmADcfcbIw==";

//   Future<bool> redeemCode(String userId, String codeInput) async {
//     String code = codeInput.trim();

//     try {
//       // ---------------------------------------------------------
//       // STEP 1: Check if it's a Manual Code in Firebase
//       // ---------------------------------------------------------
//       final manualDocRef = _db.collection('promo_codes').doc(code.toUpperCase());
//       final manualDoc = await manualDocRef.get();

//       if (manualDoc.exists) {
//         final data = manualDoc.data();
//         if (data?['isClaimed'] == true) {
//           throw "Code already used.";
//         }
//         await _runUpgradeTransaction(userId, manualDocRef);
//         return true;
//       }

//       // ---------------------------------------------------------
//       // STEP 2: Check if it's a Gumroad License Key
//       // ---------------------------------------------------------
//       if (code.contains('-')) {
//         // Check Firebase cache first
//         if (await _isGumroadKeyUsed(code)) {
//           throw "License key already used on another account.";
//         }

//         // Verify with Gumroad API
//         final isValid = await _verifyGumroadApi(code);

//         if (isValid) {
//           await _db.collection('promo_codes').doc(code).set({
//             'isClaimed': true,
//             'claimedBy': userId,
//             'claimedAt': FieldValue.serverTimestamp(),
//             'source': 'gumroad',
//             'createdAt': FieldValue.serverTimestamp(),
//           });

//           await _db.collection('users').doc(userId).update({'isPremium': true});
//           return true;
//         }
//       }

//       throw "Invalid Code";

//     } catch (e) {
//       printLog("Redeem Error: $e");
//       throw e;
//     }
//   }

//   Future<void> _runUpgradeTransaction(String userId, DocumentReference docRef) async {
//     await _db.runTransaction((transaction) async {
//       transaction.update(docRef, {
//         'isClaimed': true,
//         'claimedBy': userId,
//         'claimedAt': FieldValue.serverTimestamp(),
//       });
//       final userRef = _db.collection('users').doc(userId);
//       transaction.update(userRef, {'isPremium': true});
//     });
//   }

//   Future<bool> _isGumroadKeyUsed(String code) async {
//     final doc = await _db.collection('promo_codes').doc(code).get();
//     return doc.exists;
//   }

//   Future<bool> _verifyGumroadApi(String licenseKey) async {
//     try {
//       printLog("--- GUMROAD VERIFICATION ---");
//       printLog("Checking Key: $licenseKey");
//       printLog("Product ID: $_gumroadProductId");

//       final response = await http.post(
//         Uri.parse('https://api.gumroad.com/v2/licenses/verify'),
//         body: {
//           'product_id': _gumroadProductId, // FIX: Using product_id now
//           'license_key': licenseKey,
//         },
//       );

//       printLog("Gumroad Status: ${response.statusCode}");
//       printLog("Gumroad Response: ${response.body}");
//       printLog("----------------------------");

//       final data = jsonDecode(response.body);

//       if (data['success'] == true && data['purchase']['refunded'] == false) {
//         return true;
//       }
//       return false;
//     } catch (e) {
//       printLog("Gumroad API Connection Error: $e");
//       return false;
//     }
//   }
// }

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:linguaflow/utils/logger.dart';

class PremiumService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _gumroadProductId = "uIq5F1GwaxHuVmADcfcbIw==";

  Future<bool> redeemCode(String userId, String codeInput) async {
    String code = codeInput.trim();

    try {
      // 1. Check for Manual Promo Codes in Firebase
      final manualDocRef = _db
          .collection('promo_codes')
          .doc(code.toUpperCase());
      final manualDoc = await manualDocRef.get();

      if (manualDoc.exists) {
        final data = manualDoc.data();
        if (data?['isClaimed'] == true) {
          throw Exception("This code has already been redeemed.");
        }
        await _runUpgradeTransaction(userId, manualDocRef);
        return true;
      }

      // 2. Check for Gumroad License Key
      if (code.contains('-')) {
        // Check local cache to prevent re-checking used keys via API
        if (await _isGumroadKeyUsed(code)) {
          throw Exception(
            "This license key is already associated with another account.",
          );
        }

        // Verify with Gumroad API
        final isValid = await _verifyGumroadApi(code);

        if (isValid) {
          // Mark as used in Firestore
          await _db.collection('promo_codes').doc(code).set({
            'isClaimed': true,
            'claimedBy': userId,
            'claimedAt': FieldValue.serverTimestamp(),
            'source': 'gumroad',
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Upgrade User
          await _db.collection('users').doc(userId).update({'isPremium': true});
          return true;
        }
      }

      throw Exception("Invalid Code");
    } catch (e) {
      // Keep runtime error logging
      printLog("CRITICAL REDEEM ERROR: $e");
      rethrow;
    }
  }

  Future<void> _runUpgradeTransaction(
    String userId,
    DocumentReference docRef,
  ) async {
    await _db.runTransaction((transaction) async {
      transaction.update(docRef, {
        'isClaimed': true,
        'claimedBy': userId,
        'claimedAt': FieldValue.serverTimestamp(),
      });
      final userRef = _db.collection('users').doc(userId);
      transaction.update(userRef, {'isPremium': true});
    });
  }

  Future<bool> _isGumroadKeyUsed(String code) async {
    final doc = await _db.collection('promo_codes').doc(code).get();
    return doc.exists;
  }

  Future<bool> _verifyGumroadApi(String licenseKey) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.gumroad.com/v2/licenses/verify'),
        body: {'product_id': _gumroadProductId, 'license_key': licenseKey},
      );

      if (response.statusCode != 200) {
        printLog(
          "Gumroad API Error: ${response.statusCode} - ${response.body}",
        );
        return false;
      }

      final data = jsonDecode(response.body);

      // Ensure key is successful and not refunded
      if (data['success'] == true && data['purchase']['refunded'] == false) {
        return true;
      }
      return false;
    } catch (e) {
      printLog("Gumroad Connection Failed: $e");
      return false;
    }
  }
}
