import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';
import 'package:linguaflow/blocs/settings/settings_bloc.dart';
import 'package:linguaflow/utils/language_helper.dart';

class ProfileDialogs {
  
  // --- 1. USER PROFILE DIALOGS ---

  static void showEditNameDialog(BuildContext context, String currentName) {
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

  // --- 2. LANGUAGE DIALOGS ---

  static void showNativeLanguageDialog(BuildContext context, String current) {
    _showLanguageListDialog(context, "Select Native Language", current, (val) {
      context.read<AuthBloc>().add(AuthUpdateUser(nativeLanguage: val));
    });
  }

  static void showTargetLanguageDialog(BuildContext context, String current, String userId) {
    _showLanguageListDialog(context, "Switch Target Language", current, (val) {
      context.read<AuthBloc>().add(AuthTargetLanguageChanged(val));
      context.read<LessonBloc>().add(LessonLoadRequested(userId, val));
    });
  }

  static void _showLanguageListDialog(BuildContext context, String title, String current, Function(String) onSelected) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: LanguageHelper.availableLanguages.entries.map((entry) {
              final code = entry.key;
              final name = entry.value;
              final flag = LanguageHelper.getFlagEmoji(code);

              return RadioListTile<String>(
                title: Row(
                  children: [
                    Text(flag, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Text(name),
                  ],
                ),
                value: code,
                groupValue: current,
                onChanged: (val) {
                  if (val != null) {
                    onSelected(val);
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

  // --- 3. SETTINGS: READER APPEARANCE ---

  static void showReaderThemeDialog(BuildContext context, ReaderTheme current) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reader Theme"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildReaderThemeItem(ctx, context, ReaderTheme.light, "Light", Colors.white, Colors.black, current),
            _buildReaderThemeItem(ctx, context, ReaderTheme.sepia, "Sepia", const Color(0xFFF4ECD8), const Color(0xFF5D4037), current),
            _buildReaderThemeItem(ctx, context, ReaderTheme.dark, "Dark", const Color(0xFF1E1E1E), Colors.white, current),
          ],
        ),
      ),
    );
  }

  static Widget _buildReaderThemeItem(BuildContext ctx, BuildContext mainContext, ReaderTheme theme, String label, Color bg, Color text, ReaderTheme group) {
    return RadioListTile<ReaderTheme>(
      title: Row(
        children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey),
            ),
            child: Center(child: Text("Aa", style: TextStyle(color: text, fontSize: 10, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
      value: theme,
      groupValue: group,
      onChanged: (v) {
        mainContext.read<SettingsBloc>().add(ChangeReaderTheme(v!));
        Navigator.pop(ctx);
      },
    );
  }

  static void showFontFamilyDialog(BuildContext context, String current) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Font Family"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFontFamilyRadio(ctx, context, 'Roboto', "Sans-Serif (Default)", current),
            _buildFontFamilyRadio(ctx, context, 'Serif', "Serif (Book style)", current),
            // Add 'Merriweather', 'Lato', etc. here if added to pubspec.yaml
          ],
        ),
      ),
    );
  }

  static Widget _buildFontFamilyRadio(BuildContext ctx, BuildContext mainContext, String val, String label, String group) {
    return RadioListTile<String>(
      title: Text(label, style: TextStyle(fontFamily: val == 'Serif' ? null : val)), 
      value: val,
      groupValue: group,
      onChanged: (v) {
        mainContext.read<SettingsBloc>().add(ChangeFontFamily(v!));
        Navigator.pop(ctx);
      },
    );
  }

  static void showLineHeightDialog(BuildContext context, double current) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Line Spacing"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLineHeightRadio(ctx, context, 1.2, "Compact", current),
            _buildLineHeightRadio(ctx, context, 1.5, "Normal", current),
            _buildLineHeightRadio(ctx, context, 1.8, "Loose", current),
            _buildLineHeightRadio(ctx, context, 2.0, "Very Loose", current),
          ],
        ),
      ),
    );
  }

  static Widget _buildLineHeightRadio(BuildContext ctx, BuildContext mainContext, double val, String label, double group) {
    return RadioListTile<double>(
      title: Text(label),
      value: val,
      groupValue: group,
      onChanged: (v) {
        mainContext.read<SettingsBloc>().add(ChangeLineHeight(v!));
        Navigator.pop(ctx);
      },
    );
  }

  static void showFontSizeDialog(BuildContext context, double current) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Text Size"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFontSizeRadio(ctx, context, 0.8, "Small", current),
            _buildFontSizeRadio(ctx, context, 1.0, "Medium", current),
            _buildFontSizeRadio(ctx, context, 1.2, "Large", current),
            _buildFontSizeRadio(ctx, context, 1.4, "Extra Large", current),
          ],
        ),
      ),
    );
  }

  static Widget _buildFontSizeRadio(BuildContext ctx, BuildContext mainContext, double val, String label, double group) {
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

  // --- 4. SETTINGS: APP THEME ---

  static void showThemeDialog(BuildContext context, ThemeMode current) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("App UI Theme"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeRadio(ctx, context, ThemeMode.system, "System Default", current),
            _buildThemeRadio(ctx, context, ThemeMode.light, "Light Mode", current),
            _buildThemeRadio(ctx, context, ThemeMode.dark, "Dark Mode", current),
          ],
        ),
      ),
    );
  }

  static Widget _buildThemeRadio(BuildContext ctx, BuildContext mainContext, ThemeMode val, String label, ThemeMode group) {
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

  // --- 5. SUPPORT & DATA ---

  static void showReportBugDialog(BuildContext context, String userId, String userEmail) {
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
                  decoration: const InputDecoration(labelText: "Subject", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: descCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: "Description", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: severity,
                  decoration: const InputDecoration(labelText: "Impact"),
                  items: ['low', 'medium', 'high', 'critical']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase())))
                      .toList(),
                  onChanged: (v) => setState(() => severity = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.isNotEmpty) {
                  await FirebaseFirestore.instance.collection('bug_reports').add({
                    'title': titleCtrl.text,
                    'description': descCtrl.text,
                    'severity': severity,
                    'status': 'open',
                    'userId': userId,
                    'userEmail': userEmail,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Report sent!")));
                  }
                }
              },
              child: const Text("Submit"),
            ),
          ],
        ),
      ),
    );
  }

  static void showDeleteConfirmation(BuildContext context) {
    final emailController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Account"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("This action is irreversible. All data will be lost."),
            const SizedBox(height: 10),
            const Text("Type 'DELETE' to confirm:"),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(hintText: 'DELETE'),
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (emailController.text == 'DELETE') {
                context.read<AuthBloc>().add(AuthDeleteAccount());
                Navigator.pop(ctx);
              }
            },
            child: const Text("Delete Forever", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}