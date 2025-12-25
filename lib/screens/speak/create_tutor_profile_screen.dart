import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_state.dart';
import 'package:linguaflow/blocs/speak/tutor/tutor_bloc.dart';
import 'package:linguaflow/blocs/speak/tutor/tutor_event.dart';
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

  // NEW: Robust Schedule State
  late List<DaySchedule> _weeklySchedule;

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
    'Kids',
    'Exam Prep',
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

    // Initialize Schedule (Default to all days off)
    _weeklySchedule = [
      _createDefaultDay('mon', 'Monday'),
      _createDefaultDay('tue', 'Tuesday'),
      _createDefaultDay('wed', 'Wednesday'),
      _createDefaultDay('thu', 'Thursday'),
      _createDefaultDay('fri', 'Friday'),
      _createDefaultDay('sat', 'Saturday'),
      _createDefaultDay('sun', 'Sunday'),
    ];

    // ADD LISTENERS FOR LIVE PREVIEW
    _nameController.addListener(_updatePreview);
    _priceController.addListener(_updatePreview);
    _imageUrlController.addListener(_updatePreview);
  }

  DaySchedule _createDefaultDay(String id, String name) {
    return DaySchedule(
      dayId: id,
      dayName: name,
      isDayOff: true, // Default to off
      slots: [],
    );
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
      description: _descriptionController.text.isEmpty
          ? "Your biography will appear here..."
          : _descriptionController.text,
      otherLanguages: const [],
      countryOfBirth: _countryController.text,
      isNative: _isNative,
      // NEW: Pass the structured schedule
      availability: _weeklySchedule,
      createdAt: DateTime.now(),
      isOnline: true,
      isSuperTutor: false,
    );
  }

  // ==========================================
  // SCHEDULE LOGIC
  // ==========================================

  Future<void> _editDaySchedule(int index) async {
    final day = _weeklySchedule[index];

    // Create local copies for the dialog to modify
    bool isDayOff = day.isDayOff;
    List<TimeSlot> currentSlots = List.from(day.slots);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final theme = Theme.of(context);

            return Padding(
              padding: EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Edit ${day.dayName}",
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Switch(
                        value: !isDayOff, // True means Available
                        activeColor: Colors.green,
                        onChanged: (val) {
                          setModalState(() {
                            isDayOff = !val;
                            // Add default slot if turning on and empty
                            if (!isDayOff && currentSlots.isEmpty) {
                              currentSlots.add(
                                const TimeSlot(
                                  startHour: 9,
                                  startMinute: 0,
                                  endHour: 17,
                                  endMinute: 0,
                                ),
                              );
                            }
                          });
                        },
                      ),
                    ],
                  ),
                  const Divider(),

                  if (isDayOff)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      child: Center(
                        child: Text(
                          "Day Off",
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.hintColor,
                          ),
                        ),
                      ),
                    )
                  else ...[
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: currentSlots.length,
                      itemBuilder: (ctx, i) {
                        final slot = currentSlots[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(Icons.access_time),
                            title: Text(
                              "${slot.formattedStart} - ${slot.formattedEnd}",
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setModalState(() {
                                  currentSlots.removeAt(i);
                                });
                              },
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        // final newSlot = await _pickTimeSlot(context);
                        // if (newSlot != null) {
                        //   setModalState(() {
                        //     currentSlots.add(newSlot);
                        //     // Sort slots by start time
                        //     currentSlots.sort((a, b) => a.startHour.compareTo(b.startHour));
                        //   });
                        // }

                        if (currentSlots.length >= 3) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Maximum 3 slots allowed per day."),
                            ),
                          );
                          return; // Stop here
                        }

                        // 2. Proceed to pick time if under limit
                        final newSlot = await _pickTimeSlot(context);
                        if (newSlot != null) {
                          setModalState(() {
                            currentSlots.add(newSlot);
                            currentSlots.sort(
                              (a, b) => a.startHour.compareTo(b.startHour),
                            );
                          });
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text("Add Time Slot"),
                    ),
                  ],

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // Save changes to main state
                        setState(() {
                          _weeklySchedule[index] = DaySchedule(
                            dayId: day.dayId,
                            dayName: day.dayName,
                            isDayOff: isDayOff,
                            slots: currentSlots,
                          );
                        });
                        Navigator.pop(ctx);
                      },
                      child: const Text("Save Schedule"),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<TimeSlot?> _pickTimeSlot(BuildContext context) async {
    // 1. Pick Start
    final start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      helpText: "Select Start Time",
    );
    if (start == null) return null;

    if (!context.mounted) return null;

    // 2. Pick End
    final end = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: start.hour + 1, minute: start.minute),
      helpText: "Select End Time",
    );
    if (end == null) return null;

    // Validation
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;

    if (endMinutes <= startMinutes) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("End time must be after start time")),
        );
      }
      return null;
    }

    return TimeSlot(
      startHour: start.hour,
      startMinute: start.minute,
      endHour: end.hour,
      endMinute: end.minute,
    );
  }

  // ==========================================
  // SUBMIT
  // ==========================================
  void _submitProfile() {
    if (_formKey.currentState!.validate()) {
      // Ensure at least one day is active
      bool hasAvailability = _weeklySchedule.any(
        (d) => !d.isDayOff && d.slots.isNotEmpty,
      );

      if (!hasAvailability) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please add at least one available time slot."),
          ),
        );
        return;
      }

      // NOTE: Ensure your TutorBloc -> CreateTutorProfileEvent
      // accepts List<DaySchedule> for 'availability'.
      context.read<TutorBloc>().add(
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

          // PASSING THE NEW STRUCTURE
          availability: _weeklySchedule,

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
              // Ensure TutorCard supports the updated Tutor model
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

              // ===================================
              // NEW: AVAILABILITY SECTION
              // ===================================
              _buildSectionTitle("Availability & Rates", theme),
              Text(
                "Tap a day to set your hours.",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
              const SizedBox(height: 12),

              Container(
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Column(
                  children: List.generate(_weeklySchedule.length, (index) {
                    final day = _weeklySchedule[index];
                    final bool isLast = index == _weeklySchedule.length - 1;

                    return Column(
                      children: [
                        ListTile(
                          onTap: () => _editDaySchedule(index),
                          title: Text(
                            day.dayName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            day.isDayOff
                                ? "Day Off"
                                : day.slots.isEmpty
                                ? "No times set (Click to add)"
                                : day.slots
                                      .map(
                                        (s) =>
                                            "${s.formattedStart}-${s.formattedEnd}",
                                      )
                                      .join(", "),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: day.isDayOff
                                  ? theme.hintColor
                                  : theme.primaryColor,
                            ),
                          ),
                          trailing: Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: theme.hintColor.withOpacity(0.5),
                          ),
                        ),
                        if (!isLast)
                          Divider(height: 1, indent: 16, endIndent: 16),
                      ],
                    );
                  }),
                ),
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
