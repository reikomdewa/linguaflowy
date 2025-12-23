import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_event.dart';
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
    FirebaseConstants.fetchAppData();
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
    FirebaseConstants.fetchAppData();

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
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const PaymentDetailsPage(),
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
                        if (!widget.isPremium)
                          ElevatedButton(
                            onPressed: () {
                              if (!widget.isPremium) {
                                showDialog(
                                  context: context,
                                  builder: (context) => LayoutBuilder(
                                    builder: (context, constraints) {
                                      bool isDesktop =
                                          constraints.maxWidth > 600;
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
                                ).then((unlocked) {
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
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              }
                            },
                            child: const Text('Get Premium'),
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
                    widget.isPremium
                        ? Text('You are a pro Member', style: titleStyleBigPro)
                        : Text(
                            'With Linguaflow Pro you will:',
                            style: titleStyleBig,
                          ),
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
}
