import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_event.dart';
import 'package:linguaflow/blocs/auth/auth_state.dart';
import 'package:linguaflow/blocs/settings/eleven_labs_voice_bloc.dart';
import 'package:linguaflow/blocs/settings/settings_bloc.dart';
import 'package:linguaflow/blocs/settings/tts_voice_bloc.dart';
import 'package:linguaflow/constants/terms_and_policies.dart';
import 'package:linguaflow/screens/profile/widgets/profile_data_exporter.dart';
import 'package:linguaflow/services/home_feed_cache_service.dart';
import 'package:linguaflow/services/lesson_cache_service.dart';
import 'package:linguaflow/utils/language_helper.dart';
import 'package:package_info_plus/package_info_plus.dart';

// Local Imports
import 'widgets/profile_section_card.dart';
import 'widgets/profile_dialogs.dart';

final Future<PackageInfo> _packageInfoFuture = PackageInfo.fromPlatform();

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;

    // Theme Variables
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.bodyMedium?.color;

    if (authState.isGuest) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                "You are browsing as a Guest. We haven't saved your profile",
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.push('/login'),
                child: const Text("Create Account to Save Progress"),
              ),
            ],
          ),
        ),
      );
    } else {
      if (authState is! AuthAuthenticated) return const SizedBox();
      final user = authState.user;
      final settings = context.watch<SettingsBloc>().state;

      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        // UPDATED: Use LayoutBuilder to center content on wide screens
        body: LayoutBuilder(
          builder: (context, constraints) {
            // Determine if Desktop/Wide Screen
            final bool isWide = constraints.maxWidth > 700;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isWide ? 700 : double.infinity,
                ),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // --- 1. USER INFO ---
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: Theme.of(context).primaryColor,
                              child: Text(
                                user.displayName.isNotEmpty
                                    ? user.displayName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 30,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 24),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      user.displayName,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: Icon(
                                        Icons.edit,
                                        size: 20,
                                        color: subTextColor,
                                      ),
                                      onPressed: () {
                                        context.push('/edit_profile');
                                      },
                                      tooltip: "Edit Name",
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user.email,
                                  style: TextStyle(
                                    color: subTextColor,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // --- 2. LEARNING SETTINGS ---
                    ProfileSectionCard(
                      title: 'Learning Settings',
                      children: [
                        ListTile(
                          leading: const Icon(Icons.language),
                          title: const Text('Native Language'),
                          subtitle: Text(
                            LanguageHelper.getLanguageName(user.nativeLanguage),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                          onTap: () => ProfileDialogs.showNativeLanguageDialog(
                            context,
                            user.nativeLanguage,
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.translate),
                          title: const Text('Current Target Language'),
                          subtitle: Text(
                            LanguageHelper.getLanguageName(
                              user.currentLanguage,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                          onTap: () => ProfileDialogs.showTargetLanguageDialog(
                            context,
                            user.currentLanguage,
                            user.id,
                          ),
                        ),
                        // --- NEW: TTS VOICE SELECTION ---
                        _TtsVoiceTile(languageCode: user.currentLanguage),
                        _PremiumVoiceTile(languageCode: user.currentLanguage),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // --- 3. APP APPEARANCE (Global) ---
                    ProfileSectionCard(
                      title: 'App Appearance',
                      children: [
                        ListTile(
                          leading: const Icon(Icons.brightness_6),
                          title: const Text('App Theme'),
                          subtitle: Text(_getAppThemeName(settings.themeMode)),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                          onTap: () => ProfileDialogs.showThemeDialog(
                            context,
                            settings.themeMode,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // --- 4. READER APPEARANCE (Specific) ---
                    ProfileSectionCard(
                      title: 'Reader Appearance',
                      children: [
                        ListTile(
                          leading: const Icon(Icons.palette_outlined),
                          title: const Text('Background Theme'),
                          subtitle: Text(
                            _getReaderThemeName(settings.readerTheme),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                          onTap: () => ProfileDialogs.showReaderThemeDialog(
                            context,
                            settings.readerTheme,
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.text_fields),
                          title: const Text('Text Size'),
                          subtitle: Text(
                            _getFontSizeName(settings.fontSizeScale),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                          onTap: () => ProfileDialogs.showFontSizeDialog(
                            context,
                            settings.fontSizeScale,
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.font_download_outlined),
                          title: const Text('Font Family'),
                          subtitle: Text(settings.fontFamily),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                          onTap: () => ProfileDialogs.showFontFamilyDialog(
                            context,
                            settings.fontFamily,
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.format_line_spacing),
                          title: const Text('Line Spacing'),
                          subtitle: Text(settings.lineHeight.toString()),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                          onTap: () => ProfileDialogs.showLineHeightDialog(
                            context,
                            settings.lineHeight,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // --- 5. SUPPORT ---
                    ProfileSectionCard(
                      title: 'Support',
                      children: [
                        ListTile(
                          leading: const Icon(
                            Icons.bug_report,
                            color: Colors.orange,
                          ),
                          title: const Text('Report a Bug'),
                          subtitle: const Text('Found an issue? Let us know.'),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                          onTap: () => ProfileDialogs.showReportBugDialog(
                            context,
                            user.id,
                            user.email,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // --- 6. DATA ---
                    ProfileSectionCard(
                      title: 'Data',
                      children: [
                        ListTile(
                          leading: const Icon(Icons.download),
                          title: const Text('Export Data'),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                          onTap: () => ProfileDataExporter.exportUserData(
                            context,
                            user.id,
                          ),
                        ),
                        ListTile(
                          leading: const Icon(
                            Icons.delete_forever,
                            color: Colors.red,
                          ),
                          title: const Text(
                            'Delete Account',
                            style: TextStyle(color: Colors.red),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.red,
                          ),
                          onTap: () =>
                              ProfileDialogs.showDeleteConfirmation(context),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // --- 7. LOGOUT ---
                    ElevatedButton.icon(
                      onPressed: () async {
                        context.read<AuthBloc>().add(AuthLogoutRequested());
                        await HomeFeedCacheService().clearAllCache();
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
                    const SizedBox(height: 32),

                    // --- FOOTER ---
                    FutureBuilder<PackageInfo>(
                      future: _packageInfoFuture,
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 30.0,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Version ${snapshot.data!.version}',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Copyright 2025 - A Reikom App',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  RichText(
                                    textAlign: TextAlign.center,
                                    text: TextSpan(
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium?.color,
                                        fontSize: 13,
                                      ),
                                      children: [
                                        const TextSpan(
                                          text:
                                              "By using Linguaflow you agree to the ",
                                        ),
                                        TextSpan(
                                          text: "Terms & Conditions",
                                          style: const TextStyle(
                                            color: Colors.blue,
                                            fontWeight: FontWeight.bold,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                          recognizer: TapGestureRecognizer()
                                            ..onTap = () {
                                              _showLegalDialog(
                                                context,
                                                "Terms & Conditions",
                                                TermsAndPolicies.termsOfService,
                                              );
                                            },
                                        ),
                                        const TextSpan(text: " and "),
                                        TextSpan(
                                          text: "Privacy Policy",
                                          style: const TextStyle(
                                            color: Colors.blue,
                                            fontWeight: FontWeight.bold,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                          recognizer: TapGestureRecognizer()
                                            ..onTap = () {
                                              _showLegalDialog(
                                                context,
                                                "Privacy Policy",
                                                TermsAndPolicies.privacyPolicy,
                                              );
                                            },
                                        ),
                                        const TextSpan(text: "."),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }
  }

  void _showLegalDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 600, // Constrain width for desktop dialogs
          height: MediaQuery.of(context).size.height * 0.6,
          child: Markdown(
            data: content,
            styleSheet: MarkdownStyleSheet(
              h1: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              p: const TextStyle(fontSize: 14),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  // --- HELPERS FOR UI DISPLAY ---

  String _getAppThemeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      default:
        return 'System Default';
    }
  }

  String _getReaderThemeName(ReaderTheme theme) {
    switch (theme) {
      case ReaderTheme.light:
        return 'Light';
      case ReaderTheme.dark:
        return 'Dark';
      case ReaderTheme.sepia:
        return 'Sepia';
    }
  }

  String _getFontSizeName(double scale) {
    if (scale <= 0.8) return 'Small';
    if (scale == 1.0) return 'Medium';
    if (scale == 1.2) return 'Large';
    return 'Extra Large';
  }
}

// -----------------------------------------------------------------------------
// UPDATED TTS VOICE TILE
// -----------------------------------------------------------------------------
class _TtsVoiceTile extends StatefulWidget {
  final String languageCode;

  const _TtsVoiceTile({required this.languageCode});

  @override
  State<_TtsVoiceTile> createState() => _TtsVoiceTileState();
}

class _TtsVoiceTileState extends State<_TtsVoiceTile> {
  @override
  void initState() {
    super.initState();
    // Load voices for the current target language when this tile appears
    context.read<TtsVoiceBloc>().add(LoadVoices(widget.languageCode));
  }

  @override
  void didUpdateWidget(covariant _TtsVoiceTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload if the user switches target languages while on this screen
    if (oldWidget.languageCode != widget.languageCode) {
      context.read<TtsVoiceBloc>().add(LoadVoices(widget.languageCode));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TtsVoiceBloc, TtsVoiceState>(
      builder: (context, state) {
        String subtitle = "Loading...";

        if (!state.isLoading && state.selectedVoice != null) {
          String rawName = state.selectedVoice!['name'] ?? "Unknown";

          // 1. Clean up technical terms
          if (rawName.toLowerCase().contains("network")) {
            rawName = "High Quality (Online)";
          } else if (rawName.toLowerCase().contains("local")) {
            rawName = "Standard (Offline)";
          } else if (rawName.toLowerCase().contains("samsung")) {
            rawName = "Samsung Voice";
          } else if (rawName.toLowerCase().contains("google")) {
            rawName = "Google Voice";
          }

          // 2. Check if it's the Default voice
          // Logic: If this voice is the first one in the list, treat it as default
          bool isDefault = false;
          if (state.availableVoices.isNotEmpty) {
            // Compare names to check equality
            if (state.availableVoices.first['name'] ==
                state.selectedVoice!['name']) {
              isDefault = true;
            }
          }

          if (isDefault) {
            subtitle = "$rawName (Default)";
          } else {
            subtitle = rawName;
          }
        } else if (!state.isLoading && state.selectedVoice == null) {
          subtitle = "Default";
        }

        return ListTile(
          leading: const Icon(Icons.record_voice_over),
          title: const Text('Text-to-Speech Voice'),
          subtitle: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () => ProfileDialogs.showVoiceSelectionDialog(
            context,
            widget.languageCode,
          ),
        );
      },
    );
  }
}

class _PremiumVoiceTile extends StatefulWidget {
  final String languageCode;
  const _PremiumVoiceTile({required this.languageCode});

  @override
  State<_PremiumVoiceTile> createState() => _PremiumVoiceTileState();
}

class _PremiumVoiceTileState extends State<_PremiumVoiceTile> {
  @override
  void initState() {
    super.initState();
    context.read<ElevenLabsVoiceBloc>().add(
      LoadPremiumVoices(widget.languageCode),
    );
  }

  @override
  void didUpdateWidget(covariant _PremiumVoiceTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.languageCode != widget.languageCode) {
      context.read<ElevenLabsVoiceBloc>().add(
        LoadPremiumVoices(widget.languageCode),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ElevenLabsVoiceBloc, ElevenLabsVoiceState>(
      builder: (context, state) {
        String subtitle = "Default AI Voice";
        if (state.selectedVoice != null) {
          subtitle =
              "${state.selectedVoice!.name} (${state.selectedVoice!.description})";
        }

        return ListTile(
          leading: const Icon(
            Icons.record_voice_over,
            color: Colors.purple,
          ), // Distinct color
          title: const Text('Premium AI Voice'),
          subtitle: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () => ProfileDialogs.showPremiumVoiceDialog(
            context,
            widget.languageCode,
          ),
        );
      },
    );
  }
}