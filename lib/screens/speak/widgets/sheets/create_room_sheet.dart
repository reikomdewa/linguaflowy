import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_state.dart';
import 'package:linguaflow/blocs/speak/speak_bloc.dart';
import 'package:linguaflow/blocs/speak/speak_event.dart';
import 'package:linguaflow/utils/language_helper.dart';

class CreateRoomSheet extends StatefulWidget {
  const CreateRoomSheet({super.key});

  @override
  State<CreateRoomSheet> createState() => _CreateRoomSheetState();
}

class _CreateRoomSheetState extends State<CreateRoomSheet> {
  // Logic Variables
  String _selectedLanguageName = "English";
  String _selectedLevel = 'Beginner';
  double _memberCount = 3.0;
  bool _isUnlimited = false;
  bool _isPaid = false;

  late TextEditingController _topicController;
  late TextEditingController _accessCodeController;

  final List<String> _levels = [
    'Beginner',
    'Intermediate',
    'Advanced',
    'Native',
  ];

  @override
  void initState() {
    super.initState();
    _topicController = TextEditingController();
    _accessCodeController = TextEditingController();

    // Initialize with the user's current learning language
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _selectedLanguageName = LanguageHelper.getLanguageName(
        authState.user.currentLanguage,
      );
    }
  }

  @override
  void dispose() {
    _topicController.dispose();
    _accessCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = context.watch<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return const SizedBox();

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Create Conversation",
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                // 1. Topic Input
                _buildLabel("Topic", theme),
                TextField(
                  controller: _topicController,
                  decoration: _inputDecoration(
                    "e.g., Daily life in $_selectedLanguageName",
                    Icons.topic_outlined,
                  ),
                ),
                const SizedBox(height: 20),

                // 2. Language Selection
                _buildLabel("Room Language", theme),
                DropdownButtonFormField<String>(
                  initialValue: LanguageHelper.getLangCode(_selectedLanguageName),
                  dropdownColor: theme.cardColor,
                  decoration: _inputDecoration("", Icons.language_rounded),
                  items: LanguageHelper.availableLanguages.entries.map((entry) {
                    return DropdownMenuItem(
                      value: entry.key,
                      child: Text(
                        "${LanguageHelper.getFlagEmoji(entry.key)} ${entry.value}",
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedLanguageName = LanguageHelper.getLanguageName(
                        val!,
                      );
                    });
                  },
                ),
                const SizedBox(height: 20),

                // 3. Level Selector
                _buildLabel("Target Proficiency", theme),
                DropdownButtonFormField<String>(
                  initialValue: _selectedLevel,
                  dropdownColor: theme.cardColor,
                  decoration: _inputDecoration("", Icons.bar_chart_rounded),
                  items: _levels
                      .map(
                        (level) =>
                            DropdownMenuItem(value: level, child: Text(level)),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => _selectedLevel = val!),
                ),
                const SizedBox(height: 20),

                // 4. Members Slider
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildLabel("Member Limit", theme),
                    Row(
                      children: [
                        Text(
                          _isUnlimited
                              ? "Unlimited"
                              : "${_memberCount.toInt()}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.primaryColor,
                          ),
                        ),
                        Switch(
                          value: _isUnlimited,
                          onChanged: (val) =>
                              setState(() => _isUnlimited = val),
                          activeThumbColor: theme.primaryColor,
                        ),
                      ],
                    ),
                  ],
                ),
                if (!_isUnlimited)
                  Slider(
                    value: _memberCount,
                    min: 2,
                    max: 20,
                    divisions: 18,
                    label: _memberCount.toInt().toString(),
                    onChanged: (val) => setState(() => _memberCount = val),
                  ),

                const SizedBox(height: 10),

                // 5. Paid vs Free
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    "Paid Session (Entrance Fee)",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text("Require an access code to join"),
                  value: _isPaid,
                  onChanged: (val) => setState(() => _isPaid = val),
                  secondary: Icon(
                    FontAwesomeIcons.coins,
                    color: _isPaid ? Colors.amber : theme.hintColor,
                  ),
                ),

                if (_isPaid) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _accessCodeController,
                    decoration: _inputDecoration(
                      "Set 4-digit Access Code",
                      Icons.lock_outline,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],

                const SizedBox(height: 32),

                // 6. Create Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      final String topic = _topicController.text.trim();
                      if (topic.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Please enter a topic")),
                        );
                        return;
                      }

                      // DISPATCH EVENT
                      context.read<SpeakBloc>().add(
                        CreateRoomEvent(
                          topic: topic,
                          language: _selectedLanguageName,
                          level:
                              _selectedLevel, // Corrected from Language to Level
                          maxMembers: _isUnlimited ? 50 : _memberCount.toInt(),
                          isPaid: _isPaid,
                        ),
                      );

                      Navigator.pop(context);

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Room created! You are now the host."),
                        ),
                      );
                    },
                    child: const Text(
                      "Go Live",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- HELPER UI METHODS ---

  Widget _buildLabel(String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    final theme = Theme.of(context);
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 20, color: theme.primaryColor),
      filled: true,
      fillColor: theme.cardColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
