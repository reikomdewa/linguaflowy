import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_state.dart';
import 'package:linguaflow/blocs/speak/speak_bloc.dart';
import 'package:linguaflow/blocs/speak/speak_event.dart';
import 'package:linguaflow/models/speak/speak_models.dart';
import 'package:linguaflow/screens/speak/widgets/cards/tutor_card.dart';
import 'package:linguaflow/utils/language_helper.dart';

class CreateTutorProfileScreen extends StatefulWidget {
  const CreateTutorProfileScreen({super.key});

  @override
  State<CreateTutorProfileScreen> createState() =>
      _CreateTutorProfileScreenState();
}

class _CreateTutorProfileScreenState extends State<CreateTutorProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _imageUrlController;
  late TextEditingController _descriptionController;
  late TextEditingController _countryController;

  // Form State
  String? _selectedLanguageCode;
  String _selectedLevel = 'Native';
  bool _isNative = false;
  final List<String> _selectedSpecialties = [];

  final Map<String, bool> _daysAvailable = {
    'Mon': false,
    'Tue': false,
    'Wed': false,
    'Thu': false,
    'Fri': false,
    'Sat': false,
    'Sun': false,
  };

  final List<String> _levels = [
    'Beginner',
    'Intermediate',
    'Advanced',
    'Native',
  ];
  final List<String> _specialties = [
    'IELTS',
    'Business',
    'Conversation',
    'Grammar',
  ];

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    String initialName = "";
    String initialPhoto = "https://i.pravatar.cc/150";
    String? initialLang;

    if (authState is AuthAuthenticated) {
      initialName = authState.user.displayName;
      initialPhoto = authState.user.photoUrl ?? initialPhoto;
      initialLang = authState.user.currentLanguage;
    }

    _nameController = TextEditingController(text: initialName);
    _priceController = TextEditingController(text: "15.00");
    _imageUrlController = TextEditingController(text: initialPhoto);
    _descriptionController = TextEditingController();
    _countryController = TextEditingController();
    _selectedLanguageCode = initialLang ?? 'en';

    // ADD LISTENERS FOR LIVE PREVIEW
    _nameController.addListener(_updatePreview);
    _priceController.addListener(_updatePreview);
    _imageUrlController.addListener(_updatePreview);
  }

  void _updatePreview() => setState(() {});

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _imageUrlController.dispose();
    _descriptionController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  // Generate a temporary Tutor object to feed the Preview Card
  Tutor _generatePreviewTutor() {
    final authState = context.read<AuthBloc>().state;
    final uid = authState is AuthAuthenticated ? authState.user.id : "preview";

    return Tutor(
      id: uid,
      userId: uid,
      name: _nameController.text.isEmpty ? "Your Name" : _nameController.text,
      language: LanguageHelper.getLanguageName(_selectedLanguageCode ?? 'en'),
      rating: 5.0,
      reviews: 0,
      pricePerHour: double.tryParse(_priceController.text) ?? 0.0,
      imageUrl: _imageUrlController.text.isEmpty
          ? "https://i.pravatar.cc/150"
          : _imageUrlController.text,
      level: _selectedLevel,
      specialties: _selectedSpecialties,
      description: _descriptionController.text,
      otherLanguages: const [],
      countryOfBirth: _countryController.text,
      isNative: _isNative,
      availability: {},
      createdAt: DateTime.now(),
      isOnline: true,
      isSuperTutor: true,
    );
  }

  void _submitProfile() {
    if (_formKey.currentState!.validate()) {
      final Map<String, String> availabilityMap = {};
      _daysAvailable.forEach((day, isSelected) {
        if (isSelected) availabilityMap[day] = "Available";
      });

      if (availabilityMap.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select availability")),
        );
        return;
      }

      context.read<SpeakBloc>().add(
        CreateTutorProfileEvent(
          name: _nameController.text.trim(),
          language: LanguageHelper.getLanguageName(_selectedLanguageCode!),
          pricePerHour: double.parse(_priceController.text.trim()),
          imageUrl: _imageUrlController.text.trim(),
          level: _selectedLevel,
          specialties: _selectedSpecialties,
          description: _descriptionController.text.trim(),
          otherLanguages: const [],
          countryOfBirth: _countryController.text.trim(),
          isNative: _isNative,
          availability: availabilityMap,
          lessons: const [],
        ),
      );

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Tutor profile created!")));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Become a Tutor"),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            children: [
              // --- LIVE PREVIEW SECTION ---
              _buildSectionTitle("Card Preview", theme),
              Text(
                "This is how students will see you in the feed.",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
              const SizedBox(height: 12),
              TutorCard(tutor: _generatePreviewTutor()),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Divider(),
              ),

              _buildSectionTitle("Basic Information", theme),
              _buildLabel("Display Name", theme),
              TextFormField(
                controller: _nameController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: _inputDecoration("Full Name", Icons.person_outline),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 20),

              _buildLabel("Profile Image URL", theme),
              TextFormField(
                controller: _imageUrlController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: _inputDecoration(
                  "Image link (https://...)",
                  Icons.image_outlined,
                ),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 20),

              _buildLabel("Country of Birth", theme),
              TextFormField(
                controller: _countryController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: _inputDecoration(
                  "e.g. United Kingdom",
                  Icons.public,
                ),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 20),

              _buildLabel("Experience & Bio", theme),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: _inputDecoration(
                  "Teaching style...",
                  Icons.history_edu,
                ),
                validator: (v) => v!.length < 20 ? "Too short" : null,
              ),
              const SizedBox(height: 32),

              _buildSectionTitle("Teaching Details", theme),
              _buildLabel("Language to Teach", theme),
              DropdownButtonFormField<String>(
                value: _selectedLanguageCode,
                dropdownColor: theme.cardColor,
                decoration: _inputDecoration("", Icons.language_rounded),
                items: LanguageHelper.availableLanguages.entries.map((entry) {
                  return DropdownMenuItem(
                    value: entry.key,
                    child: Text(
                      "${LanguageHelper.getFlagEmoji(entry.key)} ${entry.value}",
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedLanguageCode = val),
              ),
              CheckboxListTile(
                title: Text(
                  "I am a native speaker",
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                ),
                value: _isNative,
                onChanged: (val) => setState(() => _isNative = val ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                activeColor: theme.primaryColor,
              ),

              const SizedBox(height: 20),
              _buildLabel("Your Proficiency Level", theme),
              DropdownButtonFormField<String>(
                value: _selectedLevel,
                dropdownColor: theme.cardColor,
                decoration: _inputDecoration("", Icons.bar_chart_rounded),
                items: _levels
                    .map(
                      (l) => DropdownMenuItem(
                        value: l,
                        child: Text(
                          l,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _selectedLevel = val!),
              ),

              const SizedBox(height: 20),
              _buildLabel("Specialties", theme),
              Wrap(
                spacing: 8,
                children: _specialties.map((spec) {
                  final isSelected = _selectedSpecialties.contains(spec);
                  return FilterChip(
                    label: Text(spec),
                    selected: isSelected,
                    selectedColor: theme.primaryColor.withOpacity(0.3),
                    labelStyle: TextStyle(
                      color: isSelected ? theme.primaryColor : theme.hintColor,
                    ),
                    onSelected: (selected) => setState(() {
                      selected
                          ? _selectedSpecialties.add(spec)
                          : _selectedSpecialties.remove(spec);
                    }),
                  );
                }).toList(),
              ),

              const SizedBox(height: 32),
              _buildSectionTitle("Availability & Rates", theme),
              _buildLabel("Available Days", theme),
              Wrap(
                spacing: 8,
                children: _daysAvailable.keys.map((day) {
                  final isSelected = _daysAvailable[day]!;
                  return FilterChip(
                    label: Text(day),
                    selected: isSelected,
                    selectedColor: theme.primaryColor.withOpacity(0.3),
                    onSelected: (val) =>
                        setState(() => _daysAvailable[day] = val),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              _buildLabel("Hourly Rate (USD)", theme),
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: _inputDecoration(
                  "20.00",
                  FontAwesomeIcons.dollarSign,
                ),
              ),

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _submitProfile,
                  child: const Text(
                    "Create Professional Profile",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      title,
      style: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
        color: theme.primaryColor,
      ),
    ),
  );

  Widget _buildLabel(String text, ThemeData theme) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      text,
      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
    ),
  );

  InputDecoration _inputDecoration(String hint, IconData icon) {
    final theme = Theme.of(context);
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(
        icon,
        size: 20,
        color: theme.colorScheme.secondary,
      ), // Uses Hyper Blue
      filled: true,
      fillColor:
          theme.cardColor, // Automatically switches between F9F9F9 and 181818
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: theme.dividerColor,
          width: 1,
        ), // Subtle "Threads" border
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.dividerColor, width: 1),
      ),
    );
  }
}
