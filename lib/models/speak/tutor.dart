import 'package:equatable/equatable.dart';

// ==========================================
// 1. AVAILABILITY HELPERS (New & Robust)
// ==========================================

/// Represents a specific time range (e.g., 09:00 - 10:30)
class TimeSlot extends Equatable {
  final int startHour;   // 0-23
  final int startMinute; // 0-59
  final int endHour;     // 0-23
  final int endMinute;   // 0-59

  const TimeSlot({
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });

  /// Helper to format for UI (e.g., "09:30")
  String get formattedStart => 
      '${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}';

  String get formattedEnd => 
      '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}';

  Map<String, dynamic> toMap() => {
    'startHour': startHour,
    'startMinute': startMinute,
    'endHour': endHour,
    'endMinute': endMinute,
  };

  factory TimeSlot.fromMap(Map<String, dynamic> map) {
    return TimeSlot(
      startHour: map['startHour'] ?? 9,
      startMinute: map['startMinute'] ?? 0,
      endHour: map['endHour'] ?? 17,
      endMinute: map['endMinute'] ?? 0,
    );
  }

  @override
  List<Object?> get props => [startHour, startMinute, endHour, endMinute];
}

/// Represents a full day's schedule (e.g., Monday)
class DaySchedule extends Equatable {
  final String dayId; // "mon", "tue", "wed", etc.
  final String dayName; // "Monday", "Tuesday"
  final bool isDayOff;
  final List<TimeSlot> slots;

  const DaySchedule({
    required this.dayId,
    required this.dayName,
    this.isDayOff = false,
    this.slots = const [],
  });

  Map<String, dynamic> toMap() => {
    'dayId': dayId,
    'dayName': dayName,
    'isDayOff': isDayOff,
    'slots': slots.map((s) => s.toMap()).toList(),
  };

  factory DaySchedule.fromMap(Map<String, dynamic> map) {
    return DaySchedule(
      dayId: map['dayId'] ?? 'mon',
      dayName: map['dayName'] ?? 'Monday',
      isDayOff: map['isDayOff'] ?? false,
      slots: map['slots'] != null
          ? List<TimeSlot>.from((map['slots'] as List).map((x) => TimeSlot.fromMap(x)))
          : [],
    );
  }

  @override
  List<Object?> get props => [dayId, dayName, isDayOff, slots];
}

// ==========================================
// 2. TUTOR LESSON HELPER MODEL
// ==========================================

class TutorLesson extends Equatable {
  final String id; // Unique ID for booking references
  final String title;
  final String description;
  final int durationMinutes;
  final double price;
  final bool isActive; // Allows archiving lessons without deleting

  const TutorLesson({
    required this.id,
    required this.title,
    required this.description,
    required this.durationMinutes,
    required this.price,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'durationMinutes': durationMinutes,
    'price': price,
    'isActive': isActive,
  };

  factory TutorLesson.fromMap(Map<String, dynamic> map) => TutorLesson(
    id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(), // Fallback ID
    title: map['title'] ?? '',
    description: map['description'] ?? '',
    durationMinutes: map['durationMinutes'] ?? 60,
    price: (map['price'] as num?)?.toDouble() ?? 0.0,
    isActive: map['isActive'] ?? true,
  );

  @override
  List<Object?> get props => [id, title, durationMinutes, price, isActive];
}

// ==========================================
// 3. TUTOR MODEL (Master Class)
// ==========================================

class Tutor extends Equatable {
  // Basic Info
  final String id;
  final String userId;
  final String name;
  final String imageUrl;
  final String description;
  final String countryOfBirth;
  final String? timezone; // e.g., "America/New_York"
  final bool isNative;

  // Teaching Stats
  final String language; // Main language
  final String level; // Proficiency (Native, C2, etc.)
  final List<String> specialties; // IELTS, Business, Kids
  final List<String> otherLanguages; // Other languages they speak

  // Performance
  final double rating;
  final int reviews;
  final int totalHoursTaught;
  final int totalStudents;
  final double pricePerHour;
  final String currency; // "USD", "EUR" - Future proofing for localization

  // Verification & Status
  final bool isVerified;
  final bool isSuperTutor;
  final bool isOnline;
  final double profileCompletion; // 0.0 to 1.0

  // Media & Socials
  final String? introVideoUrl;
  final String? videoThumbnailUrl;
  final Map<String, String> socialLinks; // {"linkedin": "...", "website": "..."}

  // Schedules (The Updated Part)
  final List<DaySchedule> availability; 
  final List<TutorLesson> lessons;

  // Metadata
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime? lastUpdatedAt;

  const Tutor({
    required this.id,
    required this.userId,
    required this.name,
    required this.language,
    required this.rating,
    required this.reviews,
    required this.pricePerHour,
    this.currency = 'USD',
    required this.imageUrl,
    required this.level,
    required this.specialties,
    required this.description,
    required this.otherLanguages,
    required this.countryOfBirth,
    required this.isNative,
    required this.availability,
    this.timezone,
    this.totalHoursTaught = 0,
    this.totalStudents = 0,
    this.isVerified = false,
    this.isSuperTutor = false,
    this.isOnline = false,
    this.profileCompletion = 0.5,
    this.introVideoUrl,
    this.videoThumbnailUrl,
    this.socialLinks = const {},
    this.lessons = const [],
    this.metadata = const {},
    required this.createdAt,
    this.lastUpdatedAt,
  });

  /// Helper to get formatted availability for the old UI (Backward Compatibility)
  /// Returns: {"Mon": "09:00-17:00", "Tue": "Day Off"}
  Map<String, String> get legacyAvailabilityMap {
    final Map<String, String> result = {};
    for (var day in availability) {
      if (day.isDayOff || day.slots.isEmpty) {
        // Skip or mark as off
      } else {
        // Just take the first slot for simple UI display
        final firstSlot = day.slots.first;
        result[day.dayName.substring(0, 3)] = 
            "${firstSlot.formattedStart}-${firstSlot.formattedEnd}";
      }
    }
    return result;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'imageUrl': imageUrl,
      'description': description,
      'countryOfBirth': countryOfBirth,
      'timezone': timezone,
      'isNative': isNative,
      'language': language,
      'level': level,
      'specialties': specialties,
      'otherLanguages': otherLanguages,
      'rating': rating,
      'reviews': reviews,
      'totalHoursTaught': totalHoursTaught,
      'totalStudents': totalStudents,
      'pricePerHour': pricePerHour,
      'currency': currency,
      'isVerified': isVerified,
      'isSuperTutor': isSuperTutor,
      'isOnline': isOnline,
      'profileCompletion': profileCompletion,
      'introVideoUrl': introVideoUrl,
      'videoThumbnailUrl': videoThumbnailUrl,
      'socialLinks': socialLinks,
      
      // Serialize structured availability
      'availability': availability.map((d) => d.toMap()).toList(),
      
      'lessons': lessons.map((l) => l.toMap()).toList(),
      'metadata': metadata,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastUpdatedAt': lastUpdatedAt?.millisecondsSinceEpoch,
    };
  }

  factory Tutor.fromMap(Map<String, dynamic> map, String id) {
    // Handling Availability: Support both new List and old Map formats
    List<DaySchedule> parsedAvailability = [];
    
    if (map['availability'] is List) {
      // NEW FORMAT
      parsedAvailability = List<DaySchedule>.from(
        (map['availability'] as List).map((x) => DaySchedule.fromMap(x))
      );
    } else if (map['availability'] is Map) {
      // OLD FORMAT FALLBACK (Converts "Mon": "9-5" to structured object)
      // This ensures your app doesn't crash with old data
      (map['availability'] as Map).forEach((key, value) {
        parsedAvailability.add(DaySchedule(
          dayId: key.toString().toLowerCase(),
          dayName: key.toString(),
          isDayOff: false,
          slots: [
             // Rough parsing or default placeholder
             const TimeSlot(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)
          ],
        ));
      });
    }

    return Tutor(
      id: id,
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      description: map['description'] ?? '',
      countryOfBirth: map['countryOfBirth'] ?? '',
      timezone: map['timezone'],
      isNative: map['isNative'] ?? false,
      language: map['language'] ?? 'English',
      level: map['level'] ?? 'Native',
      specialties: List<String>.from(map['specialties'] ?? []),
      otherLanguages: List<String>.from(map['otherLanguages'] ?? []),
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      reviews: (map['reviews'] as num?)?.toInt() ?? 0,
      totalHoursTaught: (map['totalHoursTaught'] as num?)?.toInt() ?? 0,
      totalStudents: (map['totalStudents'] as num?)?.toInt() ?? 0,
      pricePerHour: (map['pricePerHour'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] ?? 'USD',
      isVerified: map['isVerified'] ?? false,
      isSuperTutor: map['isSuperTutor'] ?? false,
      isOnline: map['isOnline'] ?? false,
      profileCompletion: (map['profileCompletion'] as num?)?.toDouble() ?? 0.0,
      introVideoUrl: map['introVideoUrl'],
      videoThumbnailUrl: map['videoThumbnailUrl'],
      socialLinks: Map<String, String>.from(map['socialLinks'] ?? {}),
      
      availability: parsedAvailability,
      
      lessons: map['lessons'] != null
          ? List<TutorLesson>.from(
              (map['lessons'] as List).map((l) => TutorLesson.fromMap(l)),
            )
          : [],
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      lastUpdatedAt: map['lastUpdatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastUpdatedAt'])
          : null,
    );
  }

  Tutor copyWith({
    String? name,
    String? language,
    double? rating,
    int? reviews,
    double? pricePerHour,
    String? imageUrl,
    String? level,
    List<String>? specialties,
    bool? isOnline,
    List<DaySchedule>? availability,
    List<TutorLesson>? lessons,
    String? description,
    String? countryOfBirth,
    String? timezone,
  }) {
    return Tutor(
      id: id,
      userId: userId,
      name: name ?? this.name,
      language: language ?? this.language,
      rating: rating ?? this.rating,
      reviews: reviews ?? this.reviews,
      pricePerHour: pricePerHour ?? this.pricePerHour,
      imageUrl: imageUrl ?? this.imageUrl,
      level: level ?? this.level,
      specialties: specialties ?? this.specialties,
      description: description ?? this.description,
      otherLanguages: otherLanguages,
      countryOfBirth: countryOfBirth ?? this.countryOfBirth,
      isNative: isNative,
      availability: availability ?? this.availability,
      isOnline: isOnline ?? this.isOnline,
      lessons: lessons ?? this.lessons,
      createdAt: createdAt,
      lastUpdatedAt: lastUpdatedAt,
      timezone: timezone ?? this.timezone,
      currency: currency,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    rating,
    reviews,
    isOnline,
    level,
    specialties,
    lessons,
    availability,
  ];
}