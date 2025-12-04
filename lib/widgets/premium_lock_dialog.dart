
// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:url_launcher/url_launcher.dart'; // Import this
// import 'package:linguaflow/blocs/auth/auth_bloc.dart';
// import 'package:linguaflow/services/premium_service.dart';
// import 'package:linguaflow/screens/premium/premium_purchase_screen.dart';

// class PremiumLockDialog extends StatefulWidget {
//   const PremiumLockDialog({super.key});

//   @override
//   State<PremiumLockDialog> createState() => _PremiumLockDialogState();
// }

// class _PremiumLockDialogState extends State<PremiumLockDialog> {
//   final TextEditingController _controller = TextEditingController();
//   bool _isLoading = false;
//   String? _error;

//   // --- CONFIGURATION ---
//   // Replace with your actual links
//   final String _gumroadLink = "https://reikom.gumroad.com/l/linguaflow"; 
//   final String _adminEmail = "reikomuk@gmail.com";

//   Future<void> _launchURL(String url) async {
//     final Uri uri = Uri.parse(url);
//     if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Could not open link")));
//     }
//   }

//   Future<void> _contactAdmin() async {
//     final Uri emailLaunchUri = Uri(
//       scheme: 'mailto',
//       path: _adminEmail,
//       query: 'subject=Linguaflow Premium Request&body=Hello, I would like to purchase a premium code via bank transfer/other method.',
//     );
//     if (!await launchUrl(emailLaunchUri)) {
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Could not open email client")));
//     }
//   }

//   void _handleRedeem() async {
//     if (_controller.text.trim().isEmpty) return;

//     setState(() {
//       _isLoading = true;
//       _error = null;
//     });

//     final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
//     final service = PremiumService();
    
//     try {
//       final success = await service.redeemCode(user.id, _controller.text);
//       if (success && mounted) {
//         Navigator.pop(context, true); // Success
//       }
//     } catch (e) {
//       if (mounted) {
//         setState(() {
//           _isLoading = false;
//           _error = e.toString().replaceAll("Exception:", "").trim();
//         });
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final isDark = Theme.of(context).brightness == Brightness.dark;
//     final textColor = isDark ? Colors.white : Colors.black;

//     return AlertDialog(
//       backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//       title: Row(
//         children: [
//           const Icon(Icons.lock_open_rounded, color: Colors.amber, size: 28),
//           const SizedBox(width: 10),
//           Text("Unlock Premium", style: TextStyle(color: textColor)),
//         ],
//       ),
//       content: SizedBox(
//         width: double.maxFinite,
//         child: SingleChildScrollView(
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 "Get unlimited access to quizzes, translations, and the full library.",
//                 style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 14),
//               ),
//               const SizedBox(height: 20),
              
//               // 1. PAYPAL DIRECT
//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton.icon(
//                   icon: const Icon(Icons.paypal, color: Colors.white),
//                   label: const Text("Instant Unlock (\$5.99)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: const Color(0xFF003087), // PayPal Blue
//                     padding: const EdgeInsets.symmetric(vertical: 12),
//                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//                   ),
//                   onPressed: () {
//                     Navigator.pop(context);
//                     Navigator.push(context, MaterialPageRoute(builder: (context) => const PremiumPurchaseScreen()));
//                   },
//                 ),
//               ),

//               const Padding(
//                 padding: EdgeInsets.symmetric(vertical: 16.0),
//                 child: Row(children: [
//                   Expanded(child: Divider()),
//                   Padding(
//                     padding: EdgeInsets.symmetric(horizontal: 8.0),
//                     child: Text("OR USE CODE", style: TextStyle(fontSize: 12, color: Colors.grey)),
//                   ),
//                   Expanded(child: Divider()),
//                 ]),
//               ),

//               // 2. CODE INPUT
//               TextField(
//                 controller: _controller,
//                 style: TextStyle(color: textColor),
//                 decoration: InputDecoration(
//                   labelText: "Enter License Key / Promo Code",
//                   labelStyle: const TextStyle(color: Colors.grey),
//                   border: const OutlineInputBorder(),
//                   errorText: _error,
//                   suffixIcon: _isLoading 
//                     ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2))
//                     : IconButton(
//                         icon: const Icon(Icons.arrow_forward, color: Colors.amber),
//                         onPressed: _handleRedeem,
//                       ),
//                 ),
//               ),

//               const SizedBox(height: 20),
              
//               // 3. HELP LINKS
//               Text("Don't have a code?", style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 12)),
//               const SizedBox(height: 8),
              
//               // Gumroad Button
//               OutlinedButton(
//                 onPressed: () => _launchURL(_gumroadLink),
//                 style: OutlinedButton.styleFrom(
//                   side: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
//                   foregroundColor: textColor,
//                 ),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: const [
//                     Text("Buy Key via Gumroad"),
//                     Icon(Icons.open_in_new, size: 16),
//                   ],
//                 ),
//               ),
              
//               const SizedBox(height: 8),
              
//               // Admin Contact
//               InkWell(
//                 onTap: _contactAdmin,
//                 child: Padding(
//                   padding: const EdgeInsets.symmetric(vertical: 8.0),
//                   child: Row(
//                     children: [
//                       Icon(Icons.mail_outline, size: 16, color: Colors.grey[500]),
//                       const SizedBox(width: 8),
//                       Text(
//                         "Contact Admin for manual payment",
//                         style: TextStyle(color: Colors.grey[500], fontSize: 12, decoration: TextDecoration.underline),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//       actions: [
//         TextButton(
//           onPressed: () => Navigator.pop(context),
//           child: const Text("Close"),
//         ),
//       ],
//     );
//   }
// }



import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/services/premium_service.dart';
import 'package:linguaflow/screens/premium/premium_purchase_screen.dart';

class PremiumLockDialog extends StatefulWidget {
  const PremiumLockDialog({super.key});

  @override
  State<PremiumLockDialog> createState() => _PremiumLockDialogState();
}

class _PremiumLockDialogState extends State<PremiumLockDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  String? _error;

  // --- CONFIGURATION ---
  final String _gumroadLink = "https://reikom.gumroad.com/l/linguaflow"; 
  final String _adminEmail = "reikomuk@gmail.com";

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not open link")));
      }
    }
  }

  Future<void> _contactAdmin() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: _adminEmail,
      query: 'subject=Linguaflow Premium Request&body=Hello, I would like to purchase a premium code via bank transfer/other method.',
    );
    if (!await launchUrl(emailLaunchUri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not open email client")));
      }
    }
  }

  void _handleRedeem() async {
    if (_controller.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Handle authentication check safely
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      setState(() {
        _isLoading = false;
        _error = "User not authenticated";
      });
      return;
    }

    final service = PremiumService();
    
    try {
      final success = await service.redeemCode(authState.user.id, _controller.text);
      
      if (success && mounted) {
        // --- SHOW SUCCESS SNACKBAR HERE ---
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Expanded(child: Text("Code redeemed! You are now a Pro member.")),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );

        // Close the dialog and return true
        Navigator.pop(context, true); 
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Clean up the exception message for the UI
          _error = e.toString().replaceAll("Exception:", "").trim();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.lock_open_rounded, color: Colors.amber, size: 28),
          const SizedBox(width: 10),
          Text("Unlock Premium", style: TextStyle(color: textColor)),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Get unlimited access to quizzes, translations, and the full library.",
                style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 14),
              ),
              const SizedBox(height: 20),
              
              // 1. PAYPAL DIRECT
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.paypal, color: Colors.white),
                  label: const Text("Instant Unlock (\$5.99)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003087), // PayPal Blue
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const PremiumPurchaseScreen()));
                  },
                ),
              ),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Row(children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text("OR USE CODE", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ),
                  Expanded(child: Divider()),
                ]),
              ),

              // 2. CODE INPUT
              TextField(
                controller: _controller,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: "Enter License Key / Promo Code",
                  labelStyle: const TextStyle(color: Colors.grey),
                  border: const OutlineInputBorder(),
                  errorText: _error,
                  suffixIcon: _isLoading 
                    ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2))
                    : IconButton(
                        icon: const Icon(Icons.arrow_forward, color: Colors.amber),
                        onPressed: _handleRedeem,
                      ),
                ),
              ),

              const SizedBox(height: 20),
              
              // 3. HELP LINKS
              Text("Don't have a code?", style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 12)),
              const SizedBox(height: 8),
              
              // Gumroad Button
              OutlinedButton(
                onPressed: () => _launchURL(_gumroadLink),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                  foregroundColor: textColor,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text("Buy Key via Gumroad"),
                    Icon(Icons.open_in_new, size: 16),
                  ],
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Admin Contact
              InkWell(
                onTap: _contactAdmin,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Icon(Icons.mail_outline, size: 16, color: Colors.grey[500]),
                      const SizedBox(width: 8),
                      Text(
                        "Contact Admin for manual payment",
                        style: TextStyle(color: Colors.grey[500], fontSize: 12, decoration: TextDecoration.underline),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Close"),
        ),
      ],
    );
  }
}