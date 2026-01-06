import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_event.dart';
import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';
import 'package:linguaflow/blocs/settings/eleven_labs_voice_bloc.dart';
import 'package:linguaflow/blocs/settings/settings_bloc.dart';
import 'package:linguaflow/blocs/settings/tts_voice_bloc.dart';
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

  static void showTargetLanguageDialog(
    BuildContext context,
    String current,
    String userId,
  ) {
    _showLanguageListDialog(context, "Switch Target Language", current, (val) {
      context.read<AuthBloc>().add(AuthTargetLanguageChanged(val));
      context.read<LessonBloc>().add(LessonLoadRequested(userId, val));
    });
  }

  static void _showLanguageListDialog(
    BuildContext context,
    String title,
    String current,
    Function(String) onSelected,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: RadioGroup<String>(
            groupValue: current,
            onChanged: (val) {
              if (val != null) {
                onSelected(val);
                Navigator.pop(ctx);
              }
            },
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
                  // groupValue and onChanged handled by RadioGroup
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  // --- HELPER: BEAUTIFY VOICE NAMES ---
  static String _getFriendlyVoiceName(Map<String, String> voice) {
    String rawName = voice['name'] ?? '';
    String locale = voice['locale'] ?? '';

    // 1. Determine Quality (Network vs Local)
    String quality = "Standard";
    if (rawName.toLowerCase().contains("network") ||
        rawName.toLowerCase().contains("online")) {
      quality = "High Quality (Online)";
    } else if (rawName.toLowerCase().contains("local") ||
        rawName.toLowerCase().contains("offline")) {
      quality = "Offline";
    }

    // 2. Determine Region (e.g., US, ES, MX)
    String region = "";
    List<String> localeParts = locale.split('-');
    if (localeParts.length > 1) {
      region = localeParts[1].toUpperCase(); // US, GB, ES
    }

    // 3. Try to generate a clean ID
    // e.g., "es-us-x-sfb-network" -> "Voice SFB"
    String shortId = rawName;
    if (rawName.contains("-x-")) {
      // Android convention often looks like: lang-region-x-id-quality
      final parts = rawName.split('-x-');
      if (parts.length > 1) {
        // Take the part after -x- and before the next hyphen
        String suffix = parts[1];
        if (suffix.contains('-')) {
          suffix = suffix.split('-')[0];
        }
        shortId = suffix.toUpperCase();
      }
    } else {
      // Fallback for simple names
      shortId = rawName.split('-').last;
    }

    // 4. Construct Final Name
    // Example: "US - Voice SFB (High Quality)"
    if (region.isNotEmpty) {
      return "$region - Voice $shortId ($quality)";
    }
    return "Voice $shortId ($quality)";
  }

  static void showVoiceSelectionDialog(BuildContext context, String langCode) {
    context.read<TtsVoiceBloc>().add(LoadVoices(langCode));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Select Text-to-Speech Voice"),
        content: SizedBox(
          width: double.maxFinite,
          child: BlocBuilder<TtsVoiceBloc, TtsVoiceState>(
            builder: (context, state) {
              if (state.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state.availableVoices.isEmpty) {
                return const Text("No voices found for this language.");
              }

              return ListView.builder(
                shrinkWrap: true,
                itemCount: state.availableVoices.length,
                itemBuilder: (context, index) {
                  final voice = state.availableVoices[index];
                  final isSelected =
                      state.selectedVoice?['name'] == voice['name'];

                  // USE THE HELPER HERE
                  final String displayName = _getFriendlyVoiceName(voice);
                  final bool isNetwork = displayName.contains("Online");

                  return ListTile(
                    leading: Icon(
                      isNetwork ? Icons.cloud_queue : Icons.smartphone,
                      color: isNetwork ? Colors.blue : Colors.grey,
                    ),
                    title: Text(
                      displayName,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    // Show actual locale as subtitle (e.g. es-ES vs es-US)
                    subtitle: Text(
                      voice['locale'] ?? "",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle,
                            color: Theme.of(context).primaryColor,
                          )
                        : null,
                    onTap: () {
                      context.read<TtsVoiceBloc>().add(ChangeVoice(voice));
                      Navigator.pop(ctx);
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  static void showPremiumVoiceDialog(BuildContext context, String langCode) {
    context.read<ElevenLabsVoiceBloc>().add(LoadPremiumVoices(langCode));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.diamond, color: Colors.purple, size: 20),
            ),
            const SizedBox(width: 12),
            const Text("Premium Voice", style: TextStyle(fontSize: 20)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          // Limit height so it doesn't take up full screen on tall devices
          height: 500,
          child: BlocBuilder<ElevenLabsVoiceBloc, ElevenLabsVoiceState>(
            builder: (context, state) {
              if (state.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              // 1. Split voices by gender
              final femaleVoices = state.voices
                  .where((v) => v.gender == 'Female')
                  .toList();
              final maleVoices = state.voices
                  .where((v) => v.gender == 'Male')
                  .toList();

              return ListView(
                shrinkWrap: true,
                children: [
                  // --- FEMALE SECTION ---
                  if (femaleVoices.isNotEmpty) ...[
                    _buildSectionHeader(context, "Female Voices", Icons.female),
                    ...femaleVoices.map(
                      (voice) => _buildVoiceItem(
                        ctx,
                        context,
                        voice,
                        state.selectedVoice?.id,
                        langCode,
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // --- MALE SECTION ---
                  if (maleVoices.isNotEmpty) ...[
                    _buildSectionHeader(context, "Male Voices", Icons.male),
                    ...maleVoices.map(
                      (voice) => _buildVoiceItem(
                        ctx,
                        context,
                        voice,
                        state.selectedVoice?.id,
                        langCode,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Done"),
          ),
        ],
      ),
    );
  }

  // Helper for Section Headers
  static Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
        ],
      ),
    );
  }

  // Helper for Individual Voice Tiles
  static Widget _buildVoiceItem(
    BuildContext dialogContext,
    BuildContext blocContext,
    dynamic voice, // ElevenLabsVoiceData
    String? selectedId,
    String langCode,
  ) {
    final isSelected = selectedId == voice.id;
    final primaryColor = Theme.of(blocContext).primaryColor;

    return Container(
      color: isSelected
          ? Colors.purple.withOpacity(0.05)
          : null, // Subtle highlight
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        dense: true,
        // Removed Leading CircleAvatar to give more room for text
        title: Text(
          voice.name,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            fontSize: 16,
            color: isSelected ? Colors.purple : null,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            voice.description,
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: isSelected
            ? const Icon(Icons.check_circle, color: Colors.purple, size: 20)
            : null,
        onTap: () {
          blocContext.read<ElevenLabsVoiceBloc>().add(
            ChangePremiumVoice(voice, langCode),
          );
          Navigator.pop(dialogContext);
        },
      ),
    );
  }
  // --- 3. SETTINGS: READER APPEARANCE ---

  static void showReaderThemeDialog(BuildContext context, ReaderTheme current) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reader Theme"),
        content: RadioGroup<ReaderTheme>(
          groupValue: current,
          onChanged: (v) {
            if (v != null) {
              context.read<SettingsBloc>().add(ChangeReaderTheme(v));
              Navigator.pop(ctx);
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildReaderThemeItem(
                ReaderTheme.light,
                "Light",
                Colors.white,
                Colors.black,
              ),
              _buildReaderThemeItem(
                ReaderTheme.sepia,
                "Sepia",
                const Color(0xFFF4ECD8),
                const Color(0xFF5D4037),
              ),
              _buildReaderThemeItem(
                ReaderTheme.dark,
                "Dark",
                const Color(0xFF1E1E1E),
                Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildReaderThemeItem(
    ReaderTheme theme,
    String label,
    Color bg,
    Color text,
  ) {
    return RadioListTile<ReaderTheme>(
      title: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey),
            ),
            child: Center(
              child: Text(
                "Aa",
                style: TextStyle(
                  color: text,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
      value: theme,
    );
  }

  static void showFontFamilyDialog(BuildContext context, String current) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Font Family"),
        content: RadioGroup<String>(
          groupValue: current,
          onChanged: (v) {
            if (v != null) {
              context.read<SettingsBloc>().add(ChangeFontFamily(v));
              Navigator.pop(ctx);
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFontFamilyRadio('Roboto', "Sans-Serif (Default)"),
              _buildFontFamilyRadio('Serif', "Serif (Book style)"),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildFontFamilyRadio(String val, String label) {
    return RadioListTile<String>(
      title: Text(
        label,
        style: TextStyle(fontFamily: val == 'Serif' ? null : val),
      ),
      value: val,
    );
  }

  static void showLineHeightDialog(BuildContext context, double current) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Line Spacing"),
        content: RadioGroup<double>(
          groupValue: current,
          onChanged: (v) {
            if (v != null) {
              context.read<SettingsBloc>().add(ChangeLineHeight(v));
              Navigator.pop(ctx);
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLineHeightRadio(1.2, "Compact"),
              _buildLineHeightRadio(1.5, "Normal"),
              _buildLineHeightRadio(1.8, "Loose"),
              _buildLineHeightRadio(2.0, "Very Loose"),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildLineHeightRadio(double val, String label) {
    return RadioListTile<double>(title: Text(label), value: val);
  }

  static void showFontSizeDialog(BuildContext context, double current) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Text Size"),
        content: RadioGroup<double>(
          groupValue: current,
          onChanged: (v) {
            if (v != null) {
              context.read<SettingsBloc>().add(ChangeFontSize(v));
              Navigator.pop(ctx);
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFontSizeRadio(0.8, "Small"),
              _buildFontSizeRadio(1.0, "Medium"),
              _buildFontSizeRadio(1.2, "Large"),
              _buildFontSizeRadio(1.4, "Extra Large"),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildFontSizeRadio(double val, String label) {
    return RadioListTile<double>(
      // Fixed: textScaleFactor replaced with textScaler
      title: Text(label, textScaler: TextScaler.linear(val)),
      value: val,
    );
  }

  // --- 4. SETTINGS: APP THEME ---

  static void showThemeDialog(BuildContext context, ThemeMode current) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("App UI Theme"),
        content: RadioGroup<ThemeMode>(
          groupValue: current,
          onChanged: (v) {
            if (v != null) {
              context.read<SettingsBloc>().add(ToggleTheme(v));
              Navigator.pop(ctx);
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildThemeRadio(ThemeMode.system, "System Default"),
              _buildThemeRadio(ThemeMode.light, "Light Mode"),
              _buildThemeRadio(ThemeMode.dark, "Dark Mode"),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildThemeRadio(ThemeMode val, String label) {
    return RadioListTile<ThemeMode>(title: Text(label), value: val);
  }

  // --- 5. SUPPORT & DATA ---

  static void showReportBugDialog(
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
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: descCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: "Description",
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
                if (titleCtrl.text.isNotEmpty) {
                  await FirebaseFirestore.instance
                      .collection('bug_reports')
                      .add({
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Report sent!")),
                    );
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
}
