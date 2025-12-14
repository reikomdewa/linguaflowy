import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';
import 'package:linguaflow/blocs/lesson/lesson_event.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/utils/constants.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
// Place this inside your User App code
// import 'package:device_info_plus/device_info_plus.dart'; // Optional
// import 'package:package_info_plus/package_info_plus.dart'; // Optional

// --- 3. LESSON OPTIONS DIALOG ---
void showLessonOptions(
  BuildContext context,
  LessonModel lesson,
  bool isDark, {
  // 'showDeleteAction' is true when we are in the Library/Profile.
  // 'showDeleteAction' is false when we are on the Home/Discovery screen.
  bool showDeleteAction = false,
}) {
  final parentContext = context;
  final authState = parentContext.read<AuthBloc>().state;
  String currentUserId = '';
  bool canDelete = false;
  bool isOwner = false;
  bool isCreatedByMe = false;

  if (authState is AuthAuthenticated) {
    final user = authState.user;
    currentUserId = user.id;

    // 1. Basic Ownership Check
    isOwner = (user.id == lesson.userId);

    // 2. Check if I am the ORIGINAL creator (Imported/Created)
    //    If originalAuthorId is null, we assume it's an old lesson created by the user (backward compatibility).
    //    If originalAuthorId matches userId, it is definitely my creation.
    isCreatedByMe =
        isOwner &&
        (lesson.originalAuthorId == null ||
            lesson.originalAuthorId == lesson.userId);

    // 3. Admin Check
    final bool isAdmin = AppConstants.isAdmin(user.email ?? '');

    // 4. FINAL DELETE LOGIC:
    //    - Admins can delete anything.
    //    - If I CREATED/IMPORTED it: I can delete it anywhere (Home or Library).
    //    - If it's a SAVED COPY: I can only delete it if 'showDeleteAction' is true (Library).
    canDelete = isAdmin || isCreatedByMe || (isOwner && showDeleteAction);
  }

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (builderContext) => Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 0,
        right: 0,
        bottom: MediaQuery.of(builderContext).viewPadding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // --- FAVORITE / SAVE BUTTON ---
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: lesson.isFavorite
                    ? Colors.amber.withOpacity(0.1)
                    : (isDark ? Colors.white10 : Colors.grey[100]),
                shape: BoxShape.circle,
              ),
              child: Icon(
                lesson.isFavorite ? Icons.star : Icons.star_border,
                color: lesson.isFavorite ? Colors.amber : Colors.grey,
              ),
            ),
            title: Text(
              lesson.isFavorite ? 'Remove from Favorites' : 'Save to Library',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            subtitle: Text(
              isOwner
                  ? (lesson.isFavorite
                        ? 'Unfavorite (removes from library)'
                        : 'Add to favorites')
                  : 'Create a copy in your cloud library.',
              style: const TextStyle(color: Colors.grey),
            ),
            onTap: () {
              if (currentUserId.isEmpty) {
                Navigator.pop(builderContext);
                return;
              }

              if (isOwner) {
                // Toggle Favorite
                final updatedLesson = lesson.copyWith(
                  isFavorite: !lesson.isFavorite,
                );
                parentContext.read<LessonBloc>().add(
                  LessonUpdateRequested(updatedLesson),
                );
              } else {
                // Create Copy
                final newLesson = lesson.copyWith(
                  id: '',
                  userId: currentUserId,
                  // IMPORTANT: Save the original author's ID so we know it's a copy later
                  originalAuthorId: lesson.userId,
                  isFavorite: true,
                  isLocal: false,
                  createdAt: DateTime.now(),
                );
                parentContext.read<LessonBloc>().add(
                  LessonCreateRequested(newLesson),
                );
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  const SnackBar(content: Text("Saved to Favorites & Library")),
                );
              }
              Navigator.pop(builderContext);
            },
          ),

          // --- DELETE BUTTON ---
          if (canDelete) ...[
            Divider(color: Colors.grey[800]),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline, color: Colors.red),
              ),
              title: const Text(
                'Delete Lesson',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("Delete Lesson?"),
                    content: Text(
                      isCreatedByMe
                          ? "This is your created lesson. Deleting it will remove it permanently for everyone."
                          : "This will remove the lesson from your library.",
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          parentContext.read<LessonBloc>().add(
                            LessonDeleteRequested(lesson.id),
                          );
                          Navigator.pop(builderContext);

                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            const SnackBar(
                              content: Text("Lesson Deleted"),
                              backgroundColor: Colors.red,
                            ),
                          );
                        },
                        child: const Text(
                          "Delete",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    ),
  );
}

void showReportBugDialog(
  BuildContext context,
  String userId,
  String userEmail,
) {
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  String severity = 'medium';

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text("Report a Problem"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: "Subject",
                  hintText: "e.g., Audio not playing",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: descCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: "Description",
                  hintText: "Explain what happened step by step...",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                initialValue: severity,
                decoration: const InputDecoration(labelText: "Impact"),
                items: ['low', 'medium', 'high', 'critical']
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(s.toUpperCase()),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => severity = v!),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.isEmpty) return;

              // 1. Gather Device Info (Optional but recommended)
              String deviceInfo = "Unknown Device";
              String appVersion = "1.0.0";

              /* UNCOMMENT THIS IF YOU INSTALLED THE PACKAGES
              try {
                final info = await DeviceInfoPlugin().deviceInfo;
                if (info is AndroidDeviceInfo) deviceInfo = "${info.brand} ${info.model} (SDK ${info.version.sdkInt})";
                if (info is IosDeviceInfo) deviceInfo = "${info.name} (${info.systemVersion})";
                final pkg = await PackageInfo.fromPlatform();
                appVersion = "${pkg.version} (${pkg.buildNumber})";
              } catch (_) {} 
              */

              // 2. Write to Firestore
              await FirebaseFirestore.instance.collection('bug_reports').add({
                'title': titleCtrl.text,
                'description': descCtrl.text,
                'severity': severity,
                'status': 'open',
                'userId': userId,
                'userEmail': userEmail,
                'deviceInfo': deviceInfo,
                'appVersion': appVersion,
                'createdAt': FieldValue.serverTimestamp(),
              });

              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Report sent! Thank you.")),
                );
              }
            },
            child: const Text("Submit Report"),
          ),
        ],
      ),
    ),
  );
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

class Utils {
  static Future openLink({required url}) async {
    _launchURL(url);
  }

  static Future _launchURL(url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      throw 'Could not launch $url';
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

  // --- 1. FIND THE LOCAL PATH ---
  // Gets the directory where the app can store files
  final directory = await getApplicationDocumentsDirectory();
  final path = directory.path;

  // --- 2. CREATE A FILE REFERENCE ---
  final file = File('$path/firestore_schema.txt');

  // --- 3. WRITE THE STRING TO THE FILE ---
  // try {
  //   await file.writeAsString(prettyJson);
  //   print("✅ Success! Schema saved to: ${file.path}");
  // } catch (e) {
  //   print("❌ Error saving schema file: $e");
  // }

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
