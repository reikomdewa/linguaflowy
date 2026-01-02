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
import 'package:linguaflow/utils/firebase_utils.dart';

class PremiumScreen extends StatefulWidget {
  static const String routeName = 'premium';
  final bool isPremium; // Changed to final
  const PremiumScreen({required this.isPremium, Key? key}) : super(key: key);

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  static const List prices = [
    {'duration': 'Forever', 'price': '100', 'per': 'One time payment'},
    {'duration': '6 months', 'price': '20', 'per': 'per 6 months'},
    {'duration': '1 month', 'price': subscriptionPrice, 'per': 'per month'},
  ];

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
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgColor,

      // Desktop AppBar: Show standard if desktop, otherwise standard logic
      appBar: (kIsWeb)
          ? AppBar(
              scrolledUnderElevation: 0,
              backgroundColor: bgColor,
              elevation: 0,
              iconTheme: IconThemeData(
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            )
          : AppBar(toolbarHeight: 0, backgroundColor: bgColor),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Determine if Desktop
            final bool isDesktop = constraints.maxWidth > 800;

            // Constrain max width for desktop view
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isDesktop ? 800 : double.infinity,
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 0 : 16.0,
                    vertical: 16.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- TITLE ---
                      Padding(
                        padding: const EdgeInsets.only(top: 20, bottom: 20),
                        child: Text(
                          ' Linguaflow Pro prices',
                          style: AppStyles.titleStyleBig(context),
                        ),
                      ),

                      // --- GRID LAYOUT FOR DESKTOP (Prices) ---
                      if (isDesktop)
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                childAspectRatio: 2.5,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                          itemCount: prices.length,
                          itemBuilder: (context, index) =>
                              _buildPriceCard(context, index),
                        )
                      else
                        ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: prices.length,
                          itemBuilder: (context, index) =>
                              _buildPriceCard(context, index),
                        ),

                      const SizedBox(height: 20),

                      // --- BUTTONS ---
                      Row(
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                            onPressed: () {
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
                            },
                            child: widget.isPremium
                                ? const Text('Upgrade')
                                : const Text('Get Premium'),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                            onPressed: () {
                              _contactAdmin();
                            },
                            child: const Text('Contact Support'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // --- USER STATUS INFO ---
                      if (widget.isPremium) ...[
                        Text(
                          "You are a Pro Member",
                          style: AppStyles.titleStyleBig(
                            context,
                          ).copyWith(color: Colors.greenAccent),
                        ),
                        const SizedBox(height: 8),
                      ],

                      BlocBuilder<AuthBloc, AuthState>(
                        builder: (context, state) {
                          if (state is AuthAuthenticated &&
                              state.user.premiumDetails != null) {
                            final data = state.user.premiumDetails!;
                            final expiration = _calculateExpiration(data);
                            return Text(
                              "Paid: \$${data['amount_paid'] / 100} at ${_formatDate((data["createdAt"] as Timestamp).toDate())} • $expiration",
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            );
                          }
                          return const SizedBox();
                        },
                      ),

                      const SizedBox(height: 30),
                      const Divider(),
                      const SizedBox(height: 20),

                      // --- BENEFITS ---
                      Text("Benefits", style: AppStyles.titleStyleBig(context)),
                      const SizedBox(height: 20),

                      if (isDesktop)
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2, // 2 benefits per row
                                childAspectRatio: 2.8,
                                crossAxisSpacing: 24,
                                mainAxisSpacing: 24,
                              ),
                          itemCount: proBenefits.length,
                          itemBuilder: (ctx, i) => _buildBenefitItem(ctx, i),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: proBenefits.length,
                          itemBuilder: (ctx, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: _buildBenefitItem(ctx, i),
                          ),
                        ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildPriceCard(BuildContext context, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => showPremiumDialog(context),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.symmetric(
          vertical: 6,
        ), // reduced margin for list
        decoration: BoxDecoration(
          border: Border.all(
            color: isDark ? Colors.white24 : Colors.grey.shade300,
            width: 2,
          ),
          // color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                prices[index]['duration'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '\$' + prices[index]['price'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    prices[index]['per'],
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitItem(BuildContext context, int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.blueAccent, size: 20),
            const SizedBox(width: 8),
            Text(
              proBenefits[index]['note'],
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6.0, left: 28),
          child: Text(
            proBenefits[index]['description'],
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withOpacity(0.8),
            ),
          ),
        ),
      ],
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
                    title: widget.isPremium ? "Upgrade" : null,
                    onClose: () {
                      Navigator.pop(context);
                    },
                  ),
                )
              : PremiumLockDialog(
                  title: widget.isPremium ? "Upgrade" : null,
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
      if (data['claimedAt'] != null) {
        purchaseDate = (data['claimedAt'] as Timestamp).toDate();
      } else if (data['purchased_at'] != null) {
        purchaseDate = DateTime.parse(data['purchased_at']);
      } else {
        return "Unknown";
      }

      final int amountPaid = data['amount_paid'] ?? 0;

      if (amountPaid >= 10000) {
        return "Lifetime Access";
      }

      DateTime expireDate;
      if (amountPaid >= 2000) {
        expireDate = purchaseDate.add(const Duration(days: 30 * 6));
      } else {
        expireDate = purchaseDate.add(const Duration(days: 30));
      }

      if (DateTime.now().isAfter(expireDate)) {
        return "Expired on ${_formatDate(expireDate)}";
      }

      return "Expires: ${_formatDate(expireDate)}";
    } catch (e) {
      return "Active";
    }
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }
}
