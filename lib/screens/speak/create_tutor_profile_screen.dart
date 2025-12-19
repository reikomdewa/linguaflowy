import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/speak/speak_bloc.dart';
import 'package:linguaflow/blocs/speak/speak_event.dart';
import 'package:linguaflow/utils/language_helper.dart';

class CreateTutorProfileScreen extends StatefulWidget {
  const CreateTutorProfileScreen({super.key});

  @override
  State<CreateTutorProfileScreen> createState() => _CreateTutorProfileScreenState();
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
  final List<String> _otherLanguages = [];
  
  // Availability State (Simple Day-based selection)
  final Map<String, bool> _daysAvailable = {
    'Mon': false, 'Tue': false, 'Wed': false, 'Thu': false, 'Fri': false, 'Sat': false, 'Sun': false
  };

  final List<String> _levels = ['Beginner', 'Intermediate', 'Advanced', 'Native'];
  final List<String> _specialties = ['IELTS', 'Business', 'Conversation', 'Grammar'];

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
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _imageUrlController.dispose();
    _descriptionController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  void _submitProfile() {
    if (_formKey.currentState!.validate()) {
      // Map availability
      final Map<String, String> availabilityMap = {};
      _daysAvailable.forEach((day, isSelected) {
        if (isSelected) availabilityMap[day] = "Available";
      });

      if (availabilityMap.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select at least one day of availability")));
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
          otherLanguages: _otherLanguages,
          countryOfBirth: _countryController.text.trim(),
          isNative: _isNative,
          availability: availabilityMap,
          lessons: []
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tutor profile created successfully!")));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text("Become a Tutor"), elevation: 0, centerTitle: true),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            children: [
              _buildSectionTitle("Basic Information", theme),
              _buildLabel("Display Name", theme),
              TextFormField(
                controller: _nameController,
                decoration: _inputDecoration("Name", Icons.person_outline),
                validator: (v) => v!.isEmpty ? "Enter your name" : null,
              ),
              const SizedBox(height: 20),

              _buildLabel("Country of Birth", theme),
              TextFormField(
                controller: _countryController,
                decoration: _inputDecoration("e.g. United Kingdom", Icons.public),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 20),

              _buildLabel("Experience & Bio", theme),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: _inputDecoration("Tell students about your teaching style and experience...", Icons.history_edu),
                validator: (v) => v!.length < 20 ? "Please write at least 20 characters" : null,
              ),
              const SizedBox(height: 32),

              _buildSectionTitle("Teaching Details", theme),
              _buildLabel("Language to Teach", theme),
              DropdownButtonFormField<String>(
                value: _selectedLanguageCode,
                decoration: _inputDecoration("", Icons.language_rounded),
                items: LanguageHelper.availableLanguages.entries.map((entry) {
                  return DropdownMenuItem(value: entry.key, child: Text("${LanguageHelper.getFlagEmoji(entry.key)} ${entry.value}"));
                }).toList(),
                onChanged: (val) => setState(() => _selectedLanguageCode = val),
              ),
              CheckboxListTile(
                title: const Text("I am a native speaker of this language"),
                value: _isNative,
                onChanged: (val) => setState(() => _isNative = val ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                activeColor: theme.primaryColor,
              ),
              const SizedBox(height: 10),

              _buildLabel("Your Proficiency Level", theme),
              DropdownButtonFormField<String>(
                value: _selectedLevel,
                decoration: _inputDecoration("", Icons.bar_chart_rounded),
                items: _levels.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
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
                    onSelected: (selected) => setState(() {
                      selected ? _selectedSpecialties.add(spec) : _selectedSpecialties.remove(spec);
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),

              _buildSectionTitle("Availability & Rates", theme),
              _buildLabel("Select Available Days", theme),
              Wrap(
                spacing: 8,
                children: _daysAvailable.keys.map((day) {
                  return FilterChip(
                    label: Text(day),
                    selected: _daysAvailable[day]!,
                    onSelected: (val) => setState(() => _daysAvailable[day] = val),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              _buildLabel("Hourly Rate (USD)", theme),
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _inputDecoration("20.00", FontAwesomeIcons.dollarSign),
              ),

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _submitProfile,
                  child: const Text("Create Professional Profile", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) => Padding(
    padding: const EdgeInsets.only(bottom: 16, top: 8),
    child: Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: theme.primaryColor)),
  );

  Widget _buildLabel(String text, ThemeData theme) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(text, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
  );

  InputDecoration _inputDecoration(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon, size: 20, color: Theme.of(context).primaryColor),
    filled: true,
    fillColor: Theme.of(context).cardColor,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  );
}