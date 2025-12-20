import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_paypal_payment/flutter_paypal_payment.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_event.dart';
import 'package:linguaflow/blocs/auth/auth_state.dart';
import 'package:linguaflow/utils/logger.dart';

class PremiumPurchaseScreen extends StatefulWidget {
  const PremiumPurchaseScreen({super.key});

  @override
  State<PremiumPurchaseScreen> createState() => _PremiumPurchaseScreenState();
}

class _PremiumPurchaseScreenState extends State<PremiumPurchaseScreen> {
  // Load keys from .env
  final String clientId = dotenv.env['PAYPAL_CLIENT_ID'] ?? '';
  final String secretKey = dotenv.env['PAYPAL_SECRET_KEY'] ?? '';

  void _buyPremium(BuildContext context) {
    if (clientId.isEmpty || secretKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("PayPal keys not found in .env")),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (BuildContext context) => PaypalCheckoutView(
          sandboxMode: true, // Set to false for Live Production
          clientId: clientId,
          secretKey: secretKey,
          transactions: const [
            {
              "amount": {
                "total": '9.99',
                "currency": 'USD',
                "details": {
                  "subtotal": '9.99',
                  "shipping": '0',
                  "shipping_discount": 0,
                },
              },
              "description": "Linguaflow Premium - Lifetime Access",
              "item_list": {
                "items": [
                  {
                    "name": "Premium Access",
                    "quantity": 1,
                    "price": '9.99',
                    "currency": 'USD',
                  },
                ],
              },
            },
          ],
          note: "Contact us for any questions on your order.",
          onSuccess: (Map params) async {
            printLog("onSuccess: $params");
            await _upgradeUserToPremium();
            if (context.mounted) {
              Navigator.pop(context); // Close PayPal View
            }
          },
          onError: (error) {
            printLog("onError: $error");
            if (mounted) Navigator.pop(context);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text("Payment failed: $error")));
          },
          onCancel: () {
            printLog('cancelled:');
            if (mounted) Navigator.pop(context);
          },
        ),
      ),
    );
  }

  Future<void> _upgradeUserToPremium() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    try {
      // 1. Update Firestore directly
      await FirebaseFirestore.instance
          .collection('users')
          .doc(authState.user.id)
          .update({'isPremium': true});

      // 2. Reload AuthBloc to update UI immediately
      if (mounted) {
        context.read<AuthBloc>().add(AuthCheckRequested());

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Success! You are now Premium."),
            backgroundColor: Colors.green,
          ),
        );

        // 3. Go back to Home
        Navigator.pop(context);
      }
    } catch (e) {
      printLog("Upgrade Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Payment successful but update failed. Contact support.",
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.workspace_premium, size: 80, color: Colors.amber),
                const SizedBox(height: 20),

                Text(
                  'Go Premium',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 10),

                Text(
                  'Unlock full access to practice quizzes, unlimited translations, and more.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 40),

                // Price Card
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        "\$9.99",
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Text(
                        "One-time payment",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // PAYPAL BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: () => _buyPremium(context),
                    icon: Icon(Icons.payment, color: Colors.white),
                    label: const Text(
                      'Pay with PayPal',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF003087), // PayPal Blue
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                Text(
                  "Secure payment via PayPal. No subscription.",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
