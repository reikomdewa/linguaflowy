// }

// File: lib/screens/profile/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Needed for Bug Reports
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';
import 'package:linguaflow/blocs/settings/settings_bloc.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ProfileScreen extends StatelessWidget {
  // Available Languages
  final Map<String, String> languages = {
    'en': 'English',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'it': 'Italian',
    'pt': 'Portuguese',
    'ja': 'Japanese',
    'ru': 'Russian',
    'zh': 'Chinese',
  };

  ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return const SizedBox();

    final user = authState.user;
    final settings = context.watch<SettingsBloc>().state;

    // Theme Variables
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.bodyMedium?.color;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- USER INFO (UPDATED WITH EDIT BUTTON) ---
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Theme.of(context).primaryColor,
                  child: Text(
                    user.displayName.isNotEmpty
                        ? user.displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(fontSize: 40, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                // Name + Edit Button Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      user.displayName,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.edit, size: 20, color: subTextColor),
                      onPressed: () =>
                          _showEditNameDialog(context, user.displayName),
                      tooltip: "Edit Name",
                    ),
                  ],
                ),
                Text(user.email, style: TextStyle(color: subTextColor)),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // --- LEARNING SETTINGS ---
          _ProfileSection(
            title: 'Learning Settings',
            children: [
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text('Native Language'),
                subtitle: Text(
                  languages[user.nativeLanguage] ?? user.nativeLanguage,
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () =>
                    _showNativeLanguageDialog(context, user.nativeLanguage),
              ),
              ListTile(
                leading: const Icon(Icons.translate),
                title: const Text('Current Target Language'),
                subtitle: Text(
                  languages[user.currentLanguage] ?? user.currentLanguage,
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _showTargetLanguageDialog(
                  context,
                  user.currentLanguage,
                  user.id,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // --- APP SETTINGS ---
          _ProfileSection(
            title: 'App Settings',
            children: [
              ListTile(
                leading: const Icon(Icons.palette),
                title: const Text('Theme'),
                subtitle: Text(_getThemeName(settings.themeMode)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _showThemeDialog(context, settings.themeMode),
              ),
              ListTile(
                leading: const Icon(Icons.text_fields),
                title: const Text('Font Size'),
                subtitle: Text(_getFontSizeName(settings.fontSizeScale)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () =>
                    _showFontSizeDialog(context, settings.fontSizeScale),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // --- SUPPORT SECTION (NEW) ---
          _ProfileSection(
            title: 'Support',
            children: [
              ListTile(
                leading: const Icon(Icons.bug_report, color: Colors.orange),
                title: const Text('Report a Bug'),
                subtitle: const Text('Found an issue? Let us know.'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _showReportBugDialog(context, user.id, user.email),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // --- DATA & DANGER ZONE ---
          _ProfileSection(
            title: 'Data',
            children: [
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Export Data'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Preparing your data export..."),
                    ),
                  );
                  _exportUserData(context, user.id);
                  
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text(
                  'Delete Account',
                  style: TextStyle(color: Colors.red),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.red,
                ),
                onTap: () => _showDeleteConfirmation(context),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // --- LOGOUT ---
          ElevatedButton.icon(
            onPressed: () {
              context.read<AuthBloc>().add(AuthLogoutRequested());
            },
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'Version 1.0.0',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportUserData(BuildContext context, String userId) async {
    // 1. Show Loading
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Generating export file... please wait.")),
    );

    try {
      final firestore = FirebaseFirestore.instance;

      // 2. Fetch User Profile
      final userDoc = await firestore.collection('users').doc(userId).get();
      final userData = userDoc.data() ?? {};

      // 3. Fetch Vocabulary (Assuming you have a vocabulary collection or subcollection)
      // Adjust path if your vocab is in: users/{id}/vocabulary OR /vocabulary (with userId field)

      // OPTION A: If vocab is a root collection with userId field
      final vocabSnapshot = await firestore
          .collection('vocabulary') // or 'vocabulary_items'
          .where('userId', isEqualTo: userId)
          .get();

      // OPTION B: If vocab is a subcollection: users/{id}/vocabulary_items
      // final vocabSnapshot = await firestore
      //    .collection('users').doc(userId).collection('vocabulary_items').get();

      final vocabList = vocabSnapshot.docs.map((doc) {
        final data = doc.data();
        // Clean up data (remove timestamps if not needed)
        return {
          'word': data['word'],
          'translation': data['translation'],
          'language': data['language'],
          'proficiency': data['proficiency'] ?? 0,
        };
      }).toList();

      // 4. Combine Data
      final Map<String, dynamic> exportData = {
        'generated_at': DateTime.now().toIso8601String(),
        'app': 'LinguaFlow',
        'profile': {
          'display_name': userData['displayName'],
          'email': userData['email'],
          'xp': userData['xp'] ?? 0,
          'native_language': userData['nativeLanguage'],
          'target_languages': userData['targetLanguages'],
          'joined_date': userData['createdAt']?.toString(),
        },
        'vocabulary_count': vocabList.length,
        'vocabulary_list': vocabList,
      };

      // 5. Convert to Pretty JSON String
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

      // 6. Write to Temp File
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/linguaflow_export.json');
      await file.writeAsString(jsonString);

      // 7. Share File
      if (context.mounted) {
        await Share.shareXFiles([
          XFile(file.path),
        ], text: 'Here is my LinguaFlow data export!');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Export failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  // --- HELPER DIALOGS ---

  // 1. Edit Name Dialog (NEW)
  void _showEditNameDialog(BuildContext context, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Name"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "Display Name"),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                // Assuming AuthUpdateUser accepts displayName in copyWith style
                context.read<AuthBloc>().add(
                  AuthUpdateUser(displayName: controller.text.trim()),
                );
                Navigator.pop(ctx);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // 2. Report Bug Dialog (NEW - Sends to Admin Dashboard)
  void _showReportBugDialog(
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

                // Write to Firestore for the Admin Dashboard to pick up
                await FirebaseFirestore.instance.collection('bug_reports').add({
                  'title': titleCtrl.text,
                  'description': descCtrl.text,
                  'severity': severity,
                  'status': 'open',
                  'userId': userId,
                  'userEmail': userEmail,
                  'deviceInfo':
                      'User Reported', // Can use device_info_plus package here if available
                  'appVersion': '1.0.0',
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

  void _showNativeLanguageDialog(BuildContext context, String current) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Select Native Language"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: languages.entries.map((entry) {
              return RadioListTile<String>(
                title: Text(entry.value),
                value: entry.key,
                groupValue: current,
                onChanged: (val) {
                  if (val != null) {
                    context.read<AuthBloc>().add(
                      AuthUpdateUser(nativeLanguage: val),
                    );
                    Navigator.pop(ctx);
                  }
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _showTargetLanguageDialog(
    BuildContext context,
    String current,
    String userId,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Switch Target Language"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: languages.entries.map((entry) {
              return RadioListTile<String>(
                title: Text(entry.value),
                value: entry.key,
                groupValue: current,
                onChanged: (val) {
                  if (val != null) {
                    context.read<AuthBloc>().add(
                      AuthTargetLanguageChanged(val),
                    );
                    context.read<LessonBloc>().add(
                      LessonLoadRequested(userId, val),
                    );
                    Navigator.pop(ctx);
                  }
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _showThemeDialog(BuildContext context, ThemeMode current) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Choose Theme"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeRadio(
              ctx,
              context,
              ThemeMode.system,
              "System Default",
              current,
            ),
            _buildThemeRadio(ctx, context, ThemeMode.light, "Light", current),
            _buildThemeRadio(ctx, context, ThemeMode.dark, "Dark", current),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeRadio(
    BuildContext ctx,
    BuildContext mainContext,
    ThemeMode val,
    String label,
    ThemeMode group,
  ) {
    return RadioListTile<ThemeMode>(
      title: Text(label),
      value: val,
      groupValue: group,
      onChanged: (v) {
        mainContext.read<SettingsBloc>().add(ToggleTheme(v!));
        Navigator.pop(ctx);
      },
    );
  }

  void _showFontSizeDialog(BuildContext context, double current) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Font Size"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFontRadio(ctx, context, 0.8, "Small", current),
            _buildFontRadio(ctx, context, 1.0, "Medium", current),
            _buildFontRadio(ctx, context, 1.2, "Large", current),
            _buildFontRadio(ctx, context, 1.4, "Extra Large", current),
          ],
        ),
      ),
    );
  }

  Widget _buildFontRadio(
    BuildContext ctx,
    BuildContext mainContext,
    double val,
    String label,
    double group,
  ) {
    return RadioListTile<double>(
      title: Text(label, textScaleFactor: val),
      value: val,
      groupValue: group,
      onChanged: (v) {
        mainContext.read<SettingsBloc>().add(ChangeFontSize(v!));
        Navigator.pop(ctx);
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    final emailController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Account"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "This action is irreversible. All your lessons and progress will be lost.",
            ),
            const SizedBox(height: 16),
            const Text("Type 'DELETE' to confirm:"),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(hintText: 'DELETE'),
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (emailController.text == 'DELETE') {
                context.read<AuthBloc>().add(AuthDeleteAccount());
                Navigator.pop(ctx);
              }
            },
            child: const Text(
              "Delete Forever",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  String _getThemeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      default:
        return 'System Default';
    }
  }

  String _getFontSizeName(double scale) {
    if (scale <= 0.8) return 'Small';
    if (scale == 1.0) return 'Medium';
    if (scale == 1.2) return 'Large';
    return 'Extra Large';
  }
}

class _ProfileSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _ProfileSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        Card(
          elevation: 0,
          color: isDark ? Colors.white10 : Colors.grey[50],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isDark ? Colors.transparent : Colors.grey.withOpacity(0.2),
            ),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}
