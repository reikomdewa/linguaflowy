import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_event.dart';
import 'package:linguaflow/blocs/auth/auth_state.dart';
import 'package:linguaflow/models/user_model.dart';
import 'package:linguaflow/utils/language_helper.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // Controllers
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  final _goalController = TextEditingController();
  final _topicInputController = TextEditingController();

  // Local State
  late String _nativeLanguage;
  late List<String> _targetLanguages;
  late Map<String, String> _languageLevels;
  late List<String> _topics;
  late String _correctionStyle;
  
  bool _isInit = false;
  bool _isLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final state = context.read<AuthBloc>().state;
      if (state is AuthAuthenticated) {
        _populateFields(state.user);
      } else {
        // Fallback or handle unauthenticated state if needed
        _nativeLanguage = 'en';
        _targetLanguages = [];
        _languageLevels = {};
        _topics = [];
        _correctionStyle = 'gentle';
      }
      _isInit = true;
    }
  }

  void _populateFields(UserModel user) {
    _nameController.text = user.displayName;
    _bioController.text = user.bio ?? '';
    _cityController.text = user.city ?? '';
    _countryController.text = user.country ?? '';
    _goalController.text = user.learningGoal ?? '';
    
    _nativeLanguage = user.nativeLanguage;
    _targetLanguages = List.from(user.targetLanguages);
    _languageLevels = Map.from(user.languageLevels);
    _topics = List.from(user.topics);
    _correctionStyle = user.correctionStyle;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _goalController.dispose();
    _topicInputController.dispose();
    super.dispose();
  }

  // --- SAVE LOGIC ---
  void _saveProfile() {
    setState(() => _isLoading = true);

    context.read<AuthBloc>().add(AuthUpdateUser(
      displayName: _nameController.text.trim(),
      bio: _bioController.text.trim(),
      city: _cityController.text.trim(),
      country: _countryController.text.trim(),
      nativeLanguage: _nativeLanguage,
      targetLanguages: _targetLanguages,
      topics: _topics,
      learningGoal: _goalController.text.trim(),
      correctionStyle: _correctionStyle,
    ));

    // Fire specific events for levels map
    for (var lang in _targetLanguages) {
        if (_languageLevels.containsKey(lang)) {
             context.read<AuthBloc>().add(AuthLanguageLevelChanged(_languageLevels[lang]!));
        }
    }

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully!")),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // --- THEME DATA ---
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Dynamic Colors based on AppTheme
    final textColor = theme.colorScheme.onSurface; // Black (Light) / White (Dark)
    final secondaryColor = theme.colorScheme.secondary; // HyperBlue
    final cardColor = theme.cardColor;
    final borderColor = theme.dividerColor;

    String? photoUrl;
    final state = context.read<AuthBloc>().state;
    if (state is AuthAuthenticated) photoUrl = state.user.photoUrl;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: const Text("Edit Profile"),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.close, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          _isLoading 
            ? Center(child: Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: secondaryColor, strokeWidth: 2)),
              ))
            : TextButton(
                onPressed: _saveProfile,
                child: Text("Save", style: TextStyle(color: secondaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
              )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. PHOTO ---
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: cardColor,
                    backgroundImage: photoUrl != null ? CachedNetworkImageProvider(photoUrl) : null,
                    child: photoUrl == null ? Icon(Icons.person, size: 50, color: theme.hintColor) : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: secondaryColor, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 30),

            // --- 2. BASIC INFO ---
            _buildSectionHeader(context, "About Me"),
            _buildTextField(context, "Display Name", _nameController),
            const SizedBox(height: 16),
            _buildTextField(context, "Bio", _bioController, maxLines: 4, hint: "Tell others about your interests..."),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildTextField(context, "City", _cityController)),
                const SizedBox(width: 16),
                Expanded(child: _buildTextField(context, "Country", _countryController)),
              ],
            ),
            const SizedBox(height: 30),

            // --- 3. LANGUAGES ---
            _buildSectionHeader(context, "Languages"),
            
            Text("Native Language", style: TextStyle(color: theme.hintColor, fontSize: 14)),
            const SizedBox(height: 8),
            _buildLanguageSelector(
              context: context,
              currentCode: _nativeLanguage,
              onSelect: (code) => setState(() => _nativeLanguage = code),
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Learning", style: TextStyle(color: theme.hintColor, fontSize: 14)),
                GestureDetector(
                  onTap: _showAddTargetLanguageSheet,
                  child: Text("+ Add", style: TextStyle(color: secondaryColor, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            
            if (_targetLanguages.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text("No languages added yet.", style: TextStyle(color: theme.hintColor, fontStyle: FontStyle.italic)),
              ),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _targetLanguages.map((code) {
                final level = _languageLevels[code] ?? "A1";
                return GestureDetector(
                  onTap: () => _showLevelPicker(code),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(LanguageHelper.getFlagEmoji(code), style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(LanguageHelper.getLanguageName(code), style: TextStyle(color: textColor)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: secondaryColor.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                          child: Text(level.split(' ').first, style: TextStyle(color: secondaryColor, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => setState(() => _targetLanguages.remove(code)),
                          child: Icon(Icons.close, size: 16, color: theme.hintColor),
                        )
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 30),

            // --- 4. PREFERENCES ---
            _buildSectionHeader(context, "Learning Preferences"),
            _buildTextField(context, "Learning Goal", _goalController, hint: "e.g. Pass IELTS, Travel..."),
            const SizedBox(height: 20),
            
            Text("Correction Style", style: TextStyle(color: theme.hintColor, fontSize: 14)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: cardColor, 
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _correctionStyle.isNotEmpty ? _correctionStyle : 'gentle',
                  dropdownColor: cardColor,
                  isExpanded: true,
                  icon: Icon(Icons.arrow_drop_down, color: textColor),
                  style: TextStyle(color: textColor, fontSize: 16),
                  items: ['gentle', 'strict', 'informal'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value[0].toUpperCase() + value.substring(1)),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _correctionStyle = val!),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text("Interests & Topics", style: TextStyle(color: theme.hintColor, fontSize: 14)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _topicInputController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: "Add interest (e.g. Football)",
                      hintStyle: TextStyle(color: theme.hintColor),
                      filled: true,
                      fillColor: cardColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: secondaryColor)),
                    ),
                    onSubmitted: (val) => _addTopic(),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: _addTopic,
                  style: IconButton.styleFrom(
                    backgroundColor: secondaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.add, color: Colors.white),
                )
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _topics.map((topic) => Chip(
                label: Text(topic),
                backgroundColor: cardColor,
                labelStyle: TextStyle(color: textColor),
                side: BorderSide(color: borderColor),
                deleteIcon: Icon(Icons.close, size: 16, color: theme.hintColor),
                onDeleted: () => setState(() => _topics.remove(topic)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              )).toList(),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  // --- LOGIC HELPER ---
  void _addTopic() {
    final text = _topicInputController.text.trim();
    if (text.isNotEmpty && !_topics.contains(text)) {
      setState(() {
        _topics.add(text);
        _topicInputController.clear();
      });
    }
  }

  // --- WIDGET BUILDERS ---

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title, 
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface, 
          fontSize: 18, 
          fontWeight: FontWeight.bold
        )
      ),
    );
  }

  Widget _buildTextField(BuildContext context, String label, TextEditingController controller, {int maxLines = 1, String? hint}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: theme.hintColor, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(color: theme.colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: theme.hintColor),
            filled: true,
            fillColor: theme.cardColor,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), 
              borderSide: BorderSide(color: theme.dividerColor)
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), 
              borderSide: BorderSide(color: theme.colorScheme.secondary)
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageSelector({required BuildContext context, required String currentCode, required Function(String) onSelect}) {
    final theme = Theme.of(context);
    final name = LanguageHelper.getLanguageName(currentCode);
    final flag = LanguageHelper.getFlagEmoji(currentCode);

    return GestureDetector(
      onTap: () => _showLanguagePickerSheet(onSelect),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Text(name, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16)),
            const Spacer(),
            Icon(Icons.keyboard_arrow_down, color: theme.hintColor),
          ],
        ),
      ),
    );
  }

  // --- BOTTOM SHEETS ---

  void _showLanguagePickerSheet(Function(String) onSelect) {
    final theme = Theme.of(context);
    final entries = LanguageHelper.availableLanguages.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2))),
              ),
              Expanded(
                child: ListView.separated(
                  controller: controller,
                  itemCount: entries.length,
                  separatorBuilder: (_,__) => Divider(color: theme.dividerColor, height: 1),
                  itemBuilder: (context, index) {
                    final code = entries[index].key;
                    return ListTile(
                      leading: Text(LanguageHelper.getFlagEmoji(code), style: const TextStyle(fontSize: 24)),
                      title: Text(entries[index].value, style: TextStyle(color: theme.colorScheme.onSurface)),
                      onTap: () {
                        onSelect(code);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddTargetLanguageSheet() {
    _showLanguagePickerSheet((code) {
      if (!_targetLanguages.contains(code) && code != _nativeLanguage) {
        setState(() {
          _targetLanguages.add(code);
          _languageLevels[code] = "A1 - Newcomer"; // Default level
        });
      }
    });
  }

  void _showLevelPicker(String langCode) {
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "Select Level for ${LanguageHelper.getLanguageName(langCode)}", 
                style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)
              ),
            ),
            Divider(color: theme.dividerColor, height: 1),
            ...["A1 - Newcomer", "A2 - Elementary", "B1 - Intermediate", "B2 - Upper Intermediate", "C1 - Advanced", "C2 - Proficient"].map((level) {
               final isSelected = _languageLevels[langCode] == level;
               return ListTile(
                 title: Text(level, style: TextStyle(color: theme.colorScheme.onSurface)),
                 trailing: isSelected ? Icon(Icons.check, color: theme.colorScheme.secondary) : null,
                 onTap: () {
                   setState(() => _languageLevels[langCode] = level);
                   Navigator.pop(context);
                 },
               );
            }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}