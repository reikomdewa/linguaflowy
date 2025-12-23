import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_event.dart';
import 'package:linguaflow/blocs/auth/auth_state.dart';
import 'package:linguaflow/constants/firebase_constants.dart';
import 'package:linguaflow/models/user_model.dart';
import 'package:linguaflow/screens/premium/payment_details_screen.dart';
import 'package:linguaflow/theme/colors.dart';
import 'package:linguaflow/constants/styles.dart';
import 'package:linguaflow/constants/values.dart';
import 'package:linguaflow/screens/premium/how_to_pay_screen.dart';
import 'package:linguaflow/screens/premium/payment_details_page.dart';
import 'package:linguaflow/utils/centered_views.dart';
import 'package:linguaflow/utils/utils.dart';
import 'package:linguaflow/widgets/premium_lock_dialog.dart';
// NEW IMPORT
import 'package:linguaflow/utils/firebase_utils.dart';

class PremiumScreen extends StatefulWidget {
  static const String routeName = 'premium';
  bool isPremium;
  PremiumScreen({required this.isPremium, Key? key}) : super(key: key);

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  static const List prices = [
    {'duration': 'Forever', 'price': '100', 'per': 'One time payment'},
    {'duration': '6 months', 'price': '20', 'per': 'per 6 months'},
    {'duration': '1 month', 'price': subscriptionPrice, 'per': 'per month'},
  ];
  @override
  void initState() {
    super.initState();
  }

  static const List proBenefits = [
    {
      'note': 'Unlimited Immersion',
      'description':
          'Import and learn from unlimited movies, videos, books, and articles. Immerse yourself in the content you love without restrictions.',
    },
    {
      'note': 'Support Our Mission',
      'description':
          'Help us expand support for 80+ African languages and create quality learning resources for underserved language communities worldwide.',
    },
    {
      'note': 'Distraction-Free Learning',
      'description':
          'No ads interrupting your flow state. Stay immersed in your content and reach fluency faster with uninterrupted learning sessions.',
    },
    {
      'note': 'Advanced Vocabulary Tools',
      'description':
          'Unlock premium flashcard features, advanced spaced repetition algorithms, and detailed analytics to accelerate your language mastery.',
    },
    {
      'note': 'Premium Badge',
      'description':
          'Display your premium status and show you\'re part of the community supporting language diversity and accessible education.',
    },
  ];
  Future<void> _contactAdmin() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.email),
                title: const Text('Contact via Email'),
                onTap: () {
                  Navigator.pop(context);
                  Utils().launchEmail();
                },
              ),
              ListTile(
                leading: const Icon(Icons.chat),
                title: const Text('Contact via WhatsApp'),
                onTap: () {
                  Navigator.pop(context);
                  Utils().launchWhatsApp();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    //  final prices = FirebaseConstants.appData['prices'];
    final size = MediaQuery.of(context).size;
    return ClipRRect(
      borderRadius: (MediaQuery.of(context).size.width > 640)
          ? BorderRadius.circular(15)
          : BorderRadius.circular(0),
      child: Scaffold(
        backgroundColor: secondary,
        appBar: (kIsWeb)
            ? null
            : AppBar(toolbarHeight: 0, backgroundColor: secondary),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Container(
              child: Padding(
                padding: const EdgeInsets.only(
                  right: 16.0,
                  left: 16.0,
                  top: 16.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 20),
                      child: Text(
                        ' Linguaflow Pro prices',
                        style: titleStyleBig,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: prices.length,
                      itemBuilder: (context, index) {
                        return InkWell(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => LayoutBuilder(
                                builder: (context, constraints) {
                                  bool isDesktop = constraints.maxWidth > 600;
                                  return isDesktop
                                      ? CenteredView(
                                          horizontalPadding: 500,
                                          child: PremiumLockDialog(
                                            onClose: () {
                                              Navigator.pop(context);
                                            },
                                          ),
                                        )
                                      : PremiumLockDialog(
                                          title: 'Upgrade',
                                          onClose: () {
                                            Navigator.pop(context);
                                          },
                                        );
                                },
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 10),
                            height: 60,
                            width: size.width,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white, width: 2),
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      prices[index]['duration'],
                                      style: smallSubtitleStyle,
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          '\$' + prices[index]['price'],
                                          style: smallSubtitleStyle,
                                        ),
                                        Text(
                                          prices[index]['per'],
                                          style: smallSubtitleStyle,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            if (!widget.isPremium) {
                              showPremiumDialog(context).then((unlocked) {
                                if (unlocked == true && context.mounted) {
                                  context.read<AuthBloc>().add(
                                    AuthCheckRequested(),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Welcome to Premium!"),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              });
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "You are a PRO member!",
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  backgroundColor: Colors.amber,
                                  duration: Duration(seconds: 5),
                                ),
                              );
                            }
                          },
                          child: widget.isPremium
                              ? const Text('Upgrade')
                              : const Text('Get Premium'),
                        ),
                        SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () {
                            _contactAdmin();
                          },
                          child: const Text('Contact Support'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // --------------------------------------------------------
                    // UPDATED SECTION: Payment Data Display
                    // --------------------------------------------------------
                    // Inside your PremiumScreen or any Widget
                    if (widget.isPremium)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "You are a Pro Member",
                            style: titleStyleBig.copyWith(
                              color: Colors.greenAccent,
                            ),
                          ),
                        ],
                      ),
                    BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, state) {
                        if (state is AuthAuthenticated &&
                            state.user.premiumDetails != null) {
                          final data = state.user.premiumDetails!;
                          // Use your _calculateExpiration logic here
                          final expiration = _calculateExpiration(data);

                          return Text(
                            "Paid: ${data['amount_paid'] / 100} at ${_formatDate((data["createdAt"] as Timestamp).toDate())} • $expiration",
                          );
                        }

                        return const SizedBox(); // Or loading/default text
                      },
                    ),

                    // --------------------------------------------------------
                    const SizedBox(height: 10),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: proBenefits.length,
                      itemBuilder: (context, index) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              proBenefits[index]['note'],
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 8.0,
                                bottom: 14,
                              ),
                              child: Text(
                                proBenefits[index]['description'],
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<dynamic> showPremiumDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => LayoutBuilder(
        builder: (context, constraints) {
          bool isDesktop = constraints.maxWidth > 600;
          return isDesktop
              ? CenteredView(
                  horizontalPadding: 500,
                  child: PremiumLockDialog(
                    onClose: () {
                      Navigator.pop(context);
                    },
                  ),
                )
              : PremiumLockDialog(
                  onClose: () {
                    Navigator.pop(context);
                  },
                );
        },
      ),
    );
  }

  String _calculateExpiration(Map<String, dynamic> data) {
    try {
      DateTime purchaseDate;

      // 1. Try to get the date from 'claimedAt' (Timestamp)
      if (data['claimedAt'] != null) {
        // Firestore stores dates as Timestamp objects
        purchaseDate = (data['claimedAt'] as Timestamp).toDate();
      }
      // 2. Fallback: Try 'purchased_at' (String from Gumroad)
      else if (data['purchased_at'] != null) {
        purchaseDate = DateTime.parse(data['purchased_at']);
      } else {
        return "Unknown";
      }

      final int amountPaid =
          data['amount_paid'] ?? 0; // In cents (e.g. 2000 = $20)

      // 3. Determine Duration based on Price Ranges

      // Range: $100+ (10000 cents) -> Lifetime
      if (amountPaid >= 10000) {
        return "Lifetime Access";
      }

      DateTime expireDate;

      // Range: $20.00 to $99.99 (2000 - 9999 cents) -> 6 Months
      if (amountPaid >= 2000) {
        expireDate = purchaseDate.add(const Duration(days: 30 * 6));
      }
      // Range: $4.99 to $19.99 (499 - 1999 cents) -> 1 Month
      // Also catches $0 test keys by default logic below, or you can check >= 499
      else {
        // Default -> 1 Month
        expireDate = purchaseDate.add(const Duration(days: 30));
      }

      // 4. Check if Expired
      if (DateTime.now().isAfter(expireDate)) {
        return "Expired on ${_formatDate(expireDate)}";
      }

      return "Renews: ${_formatDate(expireDate)}";
    } catch (e) {
      print("Date Error: $e");
      return "Active";
    }
  }

  // Simple date formatter (DD/MM/YYYY)
  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }
}
