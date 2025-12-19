import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart'; // Required for context.read
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/speak/speak_bloc.dart';
import 'package:linguaflow/blocs/speak/speak_event.dart';
import 'package:linguaflow/utils/language_helper.dart';

class CreateRoomSheet extends StatefulWidget {
  const CreateRoomSheet({super.key});

  @override
  State<CreateRoomSheet> createState() => _CreateRoomSheetState();
}

class _CreateRoomSheetState extends State<CreateRoomSheet> {
  // Controllers to capture text input
  late TextEditingController _topicController;
  late TextEditingController _accessCodeController;

  // State variables
  double _memberCount = 3.0;
  bool _isUnlimited = false;
  bool _isPaid = false;
  String _selectedLevel = 'Beginner';

  // Available levels for dropdown
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

    final user = authState.user;
    // Using SingleChildScrollView to handle smaller screens/keyboard
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.only(
          right: 24,
          left: 24,
          top: 16,
          bottom: 16,
        ),
        // Ensure the sheet pushes up with keyboard
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
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 20),

                // 1. Topic Input
                TextField(
                  controller: _topicController, // Connected controller
                  decoration: InputDecoration(
                    hintText:
                        "Topic (e.g., Business in ${LanguageHelper.getLanguageName(user.currentLanguage)}, Anime)",
                    filled: true,
                    fillColor: theme.cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.topic),
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Level Selector
                DropdownButtonFormField<String>(
                  value: _selectedLevel,
                  decoration: InputDecoration(
                    labelText: "Target Level",
                    filled: true,
                    fillColor: theme.cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.bar_chart),
                  ),
                  items: _levels
                      .map(
                        (level) =>
                            DropdownMenuItem(value: level, child: Text(level)),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => _selectedLevel = val!),
                ),
                const SizedBox(height: 20),

                // 3. Members Slider
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Members limit", style: theme.textTheme.titleMedium),
                    Row(
                      children: [
                        Text(
                          _isUnlimited
                              ? "Unlimited"
                              : "${_memberCount.toInt()}",
                        ),
                        Switch(
                          value: _isUnlimited,
                          onChanged: (val) =>
                              setState(() => _isUnlimited = val),
                          activeColor: theme.primaryColor,
                        ),
                      ],
                    ),
                  ],
                ),
                if (!_isUnlimited)
                  Slider(
                    value: _memberCount,
                    min: 2, // 1on1
                    max: 20,
                    divisions: 18,
                    label: _memberCount.toInt().toString(),
                    onChanged: (val) => setState(() => _memberCount = val),
                  ),

                const SizedBox(height: 10),

                // 4. Paid vs Free
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Paid Session (Entrance Fee)"),
                  subtitle: const Text("Users need an access code or GPay"),
                  value: _isPaid,
                  onChanged: (val) => setState(() => _isPaid = val),
                  secondary: Icon(
                    FontAwesomeIcons.coins,
                    color: _isPaid ? Colors.amber : Colors.grey,
                  ),
                ),

                if (_isPaid) ...[
                  const SizedBox(height: 10),
                  // Access Code Input
                  TextField(
                    controller: _accessCodeController, // Connected controller
                    decoration: InputDecoration(
                      hintText: "Set Access Code",
                      filled: true,
                      fillColor: theme.cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.lock_outline),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // 5. Create Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      // 1. Get values
                      final String topic = _topicController.text.trim();

                      if (topic.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Please enter a topic")),
                        );
                        return;
                      }

                      // 2. Add Event to Bloc
                      context.read<SpeakBloc>().add(
                        CreateRoomEvent(
                          topic: topic,
                          language:
                              "English", // In future, add a Language Dropdown
                          level: _selectedLevel,
                          maxMembers: _isUnlimited ? 50 : _memberCount.toInt(),
                          isPaid: _isPaid,
                        ),
                      );

                      // 3. Close Sheet
                      Navigator.pop(context);

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Room created successfully!"),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
