import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:linguaflow/utils/logger.dart';

class PremiumService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Your Gumroad Product ID
  static const String _gumroadProductId = "uIq5F1GwaxHuVmADcfcbIw==";

  /// Main function to redeem a code (Manual or Gumroad)
  Future<bool> redeemCode(String userId, String codeInput) async {
    String code = codeInput.trim();

    try {
      // ---------------------------------------------------------
      // A. GUMROAD KEYS (Contain '-')
      // ---------------------------------------------------------
      if (code.contains('-')) {
        // 1. Verify API First (Must happen outside the transaction)
        final purchaseData = await _verifyGumroadApi(code);

        if (purchaseData == null) {
          throw Exception("Invalid, Refunded, or Disputed License Key.");
        }

        // 2. Run Transaction (Prevents double-spending)
        return await _db.runTransaction((transaction) async {
          final docRef = _db.collection('promo_codes').doc(code);
          final snapshot = await transaction.get(docRef);

          // Check if this key was already saved/used in our DB
          if (snapshot.exists) {
            throw Exception("This license key has already been used.");
          }

          // Create the promo_code document safely
          transaction.set(docRef, {
            'isClaimed': true,
            'claimedBy': userId,
            'claimedAt': FieldValue.serverTimestamp(),
            'source': 'gumroad',
            'createdAt': FieldValue.serverTimestamp(),

            // Payment Metadata (Crucial for AuthBloc logic)
            'amount_paid': purchaseData['price'], // e.g. 500
            'currency': purchaseData['currency'], // e.g. 'usd'
            'purchaser_email': purchaseData['email'],
            'purchased_at':
                purchaseData['created_at'], // Keep Gumroad date string
            // Ensure manual fields are null so logic defaults to calculated price
            'manual_expires_at': null,
          });

          // Upgrade the User
          final userRef = _db.collection('users').doc(userId);
          transaction.update(userRef, {'isPremium': true});

          return true;
        });
      }
      // ---------------------------------------------------------
      // B. MANUAL / ADMIN CODES (No '-')
      // ---------------------------------------------------------
      else {
        // Note: Manual codes are stored in UPPERCASE usually
        final docRef = _db.collection('promo_codes').doc(code.toUpperCase());

        // Run Transaction (Prevents race conditions)
        return await _db.runTransaction((transaction) async {
          final snapshot = await transaction.get(docRef);

          // 1. Check if code exists
          if (!snapshot.exists) {
            throw Exception("Invalid Code");
          }

          // 2. Check if already claimed
          if (snapshot.data()?['isClaimed'] == true) {
            throw Exception("This code has already been redeemed.");
          }

          // 3. Claim it
          transaction.update(docRef, {
            'isClaimed': true,
            'claimedBy': userId,
            'claimedAt': FieldValue.serverTimestamp(),
          });

          // 4. Upgrade the User
          final userRef = _db.collection('users').doc(userId);
          transaction.update(userRef, {'isPremium': true});

          return true;
        });
      }
    } catch (e) {
      print("REDEEM ERROR: $e");
      rethrow; // Pass error to UI to show SnackBar
    }
  }

  /// Verifies key with Gumroad and returns purchase data map.
  /// Returns NULL if invalid, refunded, chargebacked, or disputed.
  Future<Map<String, dynamic>?> _verifyGumroadApi(String licenseKey) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.gumroad.com/v2/licenses/verify'),
        body: {'product_id': _gumroadProductId, 'license_key': licenseKey},
      );

      // If Gumroad API is down, we return null (fail safe)
      if (response.statusCode != 200) {
        print("Gumroad API Error: ${response.statusCode} - ${response.body}");
        return null;
      }

      final data = jsonDecode(response.body);

      // 1. Basic Success Check
      if (data['success'] != true) {
        return null;
      }

      final purchase = data['purchase'];

      // 2. SECURITY: Check for "Bad" States

      // A. Refunded (Voluntary refund)
      if (purchase['refunded'] == true) {
        print("Verification Failed: Purchase was refunded.");
        return null;
      }

      // B. Chargebacked (Fraud/Bank Reversal)
      if (purchase['chargebacked'] == true) {
        print("Verification Failed: Purchase was chargebacked.");
        return null;
      }

      // C. Disputed (PayPal/Bank Dispute)
      if (purchase['disputed'] == true) {
        print("Verification Failed: Purchase is disputed.");
        return null;
      }

      // D. Subscription Failed (Optional strict check)
      if (purchase['subscription_failed_at'] != null) {
        print("Verification Failed: Subscription payment failed.");
        // return null; // Uncomment if you want to be strict
      }

      // If all checks pass, return the data map
      return purchase as Map<String, dynamic>;
    } catch (e) {
      print("Gumroad Connection Failed: $e");
      return null;
    }
  }
}
