import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:linguaflow/constants/constants.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

export '../screens/home/utils/lesson_card_utils.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class _ToastWidget extends StatefulWidget {
  final String message;
  final bool isError;
  final Duration duration;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    required this.isError,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _opacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _offset = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();

    _timer = Timer(widget.duration, () {
      _close();
    });
  }

  void _close() {
    if (!mounted) return;
    _controller.reverse().then((_) {
      widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Determine Colors
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color backgroundColor = widget.isError
        ? Colors.redAccent
        : (isDark ? const Color(0xFF333333) : const Color(0xFF1E1E1E));

    return Positioned(
      // Position it ABOVE the bottom sheet area usually
      bottom: MediaQuery.of(context).viewInsets.bottom + 50,
      left: 20,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: FadeTransition(
          opacity: _opacity,
          child: SlideTransition(
            position: _offset,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.isError
                        ? Icons.error_outline_rounded
                        : Icons.info_outline_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Utils {
  void showCustomSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        isError: isError,
        duration: duration,
        onDismiss: () {
          overlayEntry.remove();
        },
      ),
    );

    Overlay.of(context).insert(overlayEntry);
  }

  String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');
  }

  Color getLevelShade(int level, MaterialColor color) {
    if (level == 0) {
      return color.shade300; // Lightest shade
    } else if (level == 1) {
      return color.shade500; // Moderate shade
    } else if (level == 2) {
      return color.shade700; // Darker shade
    } else {
      return color.shade800; // Darkest shade
    }
  }

  Future<void> launchEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: ADMIN_EMAIL,
      query: _encodeQueryParameters({
        'subject': 'Linguaflow Premium Request',
        'body':
            'Hello, I would like to purchase a premium code via bank transfer/other method.',
      }),
    );
    try {
      if (!await launchUrl(emailLaunchUri)) throw 'Could not launch email';
    } catch (_) {}
  }

  Future<void> launchWhatsApp() async {
    final String message =
        "Hello, I would like to purchase a premium code via bank transfer/other method.";
    final Uri whatsappUri = Uri.parse(
      "https://wa.me/$ADMIN_PHONE_NUMBER?text=${Uri.encodeComponent(message)}",
    );
    try {
      if (!await launchUrl(whatsappUri, mode: LaunchMode.externalApplication))
        throw 'Could not launch WhatsApp';
    } catch (_) {}
  }

  Widget buildTextBadge(String text, Color bgColor, {double fontSize = 10}) {
    return Container(
      margin: const EdgeInsets.only(right: 3.0), // Spacing between badges
      padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          height: 1.1, // Adjust line height for small font
        ),
      ),
    );
  }

  Widget buildMediaPlaceholder(
    BuildContext context, {
    bool isLoading = false,
    dynamic error,
    String? message,
  }) {
    return Container(
      height: 450, // Consistent height
      width: MediaQuery.of(context).size.height * 0.35,
      margin: const EdgeInsets.only(right: 8.0), // Match image padding
      decoration: BoxDecoration(
        color: Colors.grey[850], // Dark placeholder background
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: isLoading
            ? const CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white54,
              )
            : Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  error != null
                      ? 'Error loading video:\n${error.toString()}'
                      : message ?? 'Cannot load media',
                  style: TextStyle(
                    color: error != null ? Colors.redAccent : Colors.white60,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
      ),
    );
  }

  static void showXpPop(int amount, BuildContext context) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();

    EdgeInsets? webMargin;
    if (kIsWeb) {
      final double screenHeight = MediaQuery.of(context).size.height;
      webMargin = EdgeInsets.only(bottom: screenHeight - 80);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "+$amount XP! ",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Icon(Icons.bolt, color: Colors.amber, size: 18),
          ],
        ),
        duration: const Duration(milliseconds: 800),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.blueAccent.withOpacity(0.9),
        width: 120,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: webMargin,
      ),
    );
  }

  static Future<void> openLink({required String url}) async {
    final Uri uri = Uri.parse(url);
    await _launchURL(uri);
  }

  static Future<void> _launchURL(Uri url) async {
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw Exception('Could not launch $url');
    }
  }

  static List<Widget> heightBetween(
    List<Widget> children, {
    required double height,
  }) {
    if (children.isEmpty) return <Widget>[];
    if (children.length == 1) return children;

    final list = [children.first, SizedBox(height: height)];
    for (int i = 1; i < children.length - 1; i++) {
      final child = children[i];
      list.add(child);
      list.add(SizedBox(height: height));
    }
    list.add(children.last);

    return list;
  }

  String timeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} ${(difference.inDays / 365).floor() == 1 ? 'year' : 'years'} ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} ${(difference.inDays / 30).floor() == 1 ? 'month' : 'months'} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }

  String capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  static Future openEmail({
    required String toEmail,
    required String subject,
    required String body,
  }) async {
    String? encodeQueryParameters(Map<String, String> params) {
      return params.entries
          .map(
            (e) =>
                '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
          )
          .join('&');
    }

    final url = Uri(
      scheme: 'mailto',
      path: toEmail,
      query: encodeQueryParameters(<String, String>{'subject': subject}),
    );
    // final url =
    //     'mailto:$toEmail?subject=${Uri.encodeFull(subject)}&body=${Uri.encodeFull(body)}';
    await _launchURL(url);
  }
}

String getType(dynamic value) {
  if (value is String) return "string";
  if (value is int) return "int";
  if (value is double) return "double";
  if (value is bool) return "bool";
  if (value is Timestamp) return "timestamp";
  if (value is GeoPoint) return "geopoint";
  if (value is DocumentReference) return "reference";
  if (value is List) return "array";
  if (value is Map) return "map";
  return "unknown";
}

Future<void> printFirestoreSchema() async {
  final firestore = FirebaseFirestore.instance;

  final collections = <CollectionReference>[
    // firestore.collection('posts'),
    firestore.collection('users'),
    // firestore.collection('activities'),
    // firestore.collection('content_preferences'),
    // firestore.collection('reported_posts'),
    // firestore.collection('reports'),
    // add other collections if needed
  ];

  Map<String, dynamic> schemaJson = {};

  for (var col in collections) {
    try {
      final docs = await col.limit(1).get(); // only need ONE doc
      if (docs.docs.isEmpty) {
        schemaJson[col.id] = {"fields": {}};
        continue;
      }

      final sampleData = docs.docs.first.data() as Map<String, dynamic>?;

      // Convert sample doc fields → type string
      final fields = (sampleData ?? <String, dynamic>{}).map<String, String>(
        (key, value) => MapEntry(key, getType(value)),
      );

      schemaJson[col.id] = {"fields": fields};
    } catch (e) {
      schemaJson[col.id] = {"error": e.toString()};
    }
  }

  // print(jsonEncode(schemaJson));
  // ... inside your printFirestoreSchema function, after the loop ...

  // Use an encoder to "pretty print" the JSON output
  JsonEncoder encoder = JsonEncoder.withIndent('  ');
  String prettyJson = encoder.convert(schemaJson);

  // You can still print it to the console if you want
  print("--- Firestore Schema (from 1-document sample) ---");
  //  print(prettyJson);
  printSchemaInChunks(prettyJson);
  print('⚡⚡⚡⚡⚡⚡⚡⚡⚡');
  // await writeOutputToFile(prettyJson, 'schema_output.json');
  print("-------------------------------------------------");
}

Future<void> writeOutputToFile(String content, String filename) async {
  try {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsString(content);
    debugPrint("Output successfully written to: ${file.path}");
    // You can copy the file.path from the console and open it directly.
  } catch (e) {
    debugPrint("Failed to write to file: $e");
  }
}
// Import for debugPrint

void printSchemaInChunks(String prettyJson) {
  try {
    // 1. Decode the pretty JSON string back into a Dart Map
    final Map<String, dynamic> schema = json.decode(prettyJson);

    debugPrint("--- Firestore Schema Start ---", wrapWidth: 1024);

    // 2. Iterate through the top-level keys (e.g., "posts", "users")
    schema.forEach((collectionName, schemaDetails) {
      // 3. Print a clear header for each collection chunk
      debugPrint("\n--- Collection: $collectionName ---", wrapWidth: 1024);
      debugPrint("\n--- Collection: $collectionName ---", wrapWidth: 1024);

      // 4. Encode the specific collection details back to a pretty string
      //    to keep the nice formatting for the output.
      final collectionJson = const JsonEncoder.withIndent(
        '  ',
      ).convert(schemaDetails);

      // 5. Use debugPrint() to print this chunk.
      //    It automatically handles wrapping long lines within the chunk.
      debugPrint(collectionJson, wrapWidth: 1024);

      debugPrint(
        "-------------------------------------------------",
        wrapWidth: 1024,
      );
    });

    debugPrint("\n--- Firestore Schema End ---", wrapWidth: 1024);
  } catch (e) {
    debugPrint("Error processing schema: $e", wrapWidth: 1024);
    // Fallback if parsing fails
    debugPrint(prettyJson, wrapWidth: 1024);
  }
}
