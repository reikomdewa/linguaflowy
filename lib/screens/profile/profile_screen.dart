// File: lib/screens/profile/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';
import 'package:linguaflow/blocs/settings/settings_bloc.dart';

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
    if (authState is! AuthAuthenticated) return SizedBox();

    final user = authState.user;
    final settings = context.watch<SettingsBloc>().state;

    // Theme Variables
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.bodyMedium?.color;

    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
        // AppBar theme is handled by main.dart now, but explicit fallback helps
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // --- USER INFO ---
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
                    style: TextStyle(fontSize: 40, color: Colors.white),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  user.displayName,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 4),
                Text(user.email, style: TextStyle(color: subTextColor)),
              ],
            ),
          ),

          SizedBox(height: 32),

          // --- LEARNING SETTINGS ---
          _ProfileSection(
            title: 'Learning Settings',
            children: [
              ListTile(
                leading: Icon(Icons.language),
                title: Text('Native Language'),
                subtitle: Text(
                  languages[user.nativeLanguage] ?? user.nativeLanguage,
                ),
                trailing: Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () =>
                    _showNativeLanguageDialog(context, user.nativeLanguage),
              ),
              ListTile(
                leading: Icon(Icons.translate),
                title: Text('Current Target Language'),
                subtitle: Text(
                  languages[user.currentLanguage] ?? user.currentLanguage,
                ),
                trailing: Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _showTargetLanguageDialog(
                  context,
                  user.currentLanguage,
                  user.id,
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          // --- APP SETTINGS ---
          _ProfileSection(
            title: 'App Settings',
            children: [
              ListTile(
                leading: Icon(Icons.palette),
                title: Text('Theme'),
                subtitle: Text(_getThemeName(settings.themeMode)),
                trailing: Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _showThemeDialog(context, settings.themeMode),
              ),
              ListTile(
                leading: Icon(Icons.text_fields),
                title: Text('Font Size'),
                subtitle: Text(_getFontSizeName(settings.fontSizeScale)),
                trailing: Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () =>
                    _showFontSizeDialog(context, settings.fontSizeScale),
              ),
            ],
          ),

          SizedBox(height: 16),

          // --- DATA & DANGER ZONE ---
          _ProfileSection(
            title: 'Data',
            children: [
              ListTile(
                leading: Icon(Icons.download),
                title: Text('Export Data'),
                trailing: Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Exporting data... (Coming soon)")),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_forever, color: Colors.red),
                title: Text(
                  'Delete Account',
                  style: TextStyle(color: Colors.red),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.red,
                ),
                onTap: () => _showDeleteConfirmation(context),
              ),
            ],
          ),

          SizedBox(height: 32),

          // --- LOGOUT ---
          ElevatedButton.icon(
            onPressed: () {
              context.read<AuthBloc>().add(AuthLogoutRequested());
            },
            icon: Icon(Icons.logout),
            label: Text('Logout'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              minimumSize: Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          SizedBox(height: 16),
          Center(
            child: Text(
              'Version 1.0.0',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPER DIALOGS ---

  void _showNativeLanguageDialog(BuildContext context, String current) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Select Native Language"),
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

  // UPDATED: Now uses single selection Radio to sync with user.currentLanguage
  void _showTargetLanguageDialog(
    BuildContext context,
    String current,
    String userId,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Switch Target Language"),
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
                    // 1. Update Auth Bloc (Persists to Firestore)
                    context.read<AuthBloc>().add(
                      AuthTargetLanguageChanged(val),
                    );

                    // 2. Reload Lessons for new language
                    context.read<LessonBloc>().add(
                      LessonLoadRequested(userId, val),
                    );

                    // 3. Reload Vocabulary for new language (optional, or filter in UI)
                    // context.read<VocabularyBloc>().add(VocabularyLoadRequested(userId));

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
        title: Text("Choose Theme"),
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
        title: Text("Font Size"),
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
        title: Text("Delete Account"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "This action is irreversible. All your lessons and progress will be lost.",
            ),
            SizedBox(height: 16),
            Text("Type 'DELETE' to confirm:"),
            TextField(
              controller: emailController,
              decoration: InputDecoration(hintText: 'DELETE'),
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (emailController.text == 'DELETE') {
                context.read<AuthBloc>().add(AuthDeleteAccount());
                Navigator.pop(ctx);
              }
            },
            child: Text(
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
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
