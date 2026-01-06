class ElevenLabsVoiceData {
  final String id;
  final String name;
  final String gender;
  final String description;

  const ElevenLabsVoiceData({
    required this.id,
    required this.name,
    required this.gender,
    required this.description,
  });

  // A curated list of the best Multilingual v2 voices
  static const List<ElevenLabsVoiceData> voices = [
    // --- FEMALE VOICES ---
    ElevenLabsVoiceData(id: 'EXAVITQu4vr4xnSDxMaL', name: 'Rachel', gender: 'Female', description: 'American, Calm, Narrator'),
    ElevenLabsVoiceData(id: 'XB0fDUnXU5powFXDhCwa', name: 'Charlotte', gender: 'Female', description: 'English-French, Seductive, Soft'),
    ElevenLabsVoiceData(id: 'IKne3meq5aSn9XLyUdCD', name: 'Kazuha', gender: 'Female', description: 'Japanese-English, Energetic'),
    ElevenLabsVoiceData(id: 'XrExE9yKIg1WjnnlVkGX', name: 'Matilda', gender: 'Female', description: 'Warm, Friendly, Children\'s Books'),
    ElevenLabsVoiceData(id: '21m00Tcm4TlvDq8ikWAM', name: 'Rachel (Legacy)', gender: 'Female', description: 'Clear, Standard'),
    ElevenLabsVoiceData(id: 'MF3mGyEYCl7XYWbV9V6O', name: 'Elli', gender: 'Female', description: 'Emotional, Young'),
    
    // --- MALE VOICES ---
    ElevenLabsVoiceData(id: 'ErXwobaYiN019PkySvjV', name: 'Antoni', gender: 'Male', description: 'American, Well-rounded, News'),
    ElevenLabsVoiceData(id: 'pNInz6obpgDQGcFmaJgB', name: 'Adam', gender: 'Male', description: 'American, Deep, Narration'),
    ElevenLabsVoiceData(id: 'VR6AewLTigWG4xSOukaG', name: 'Arnold', gender: 'Male', description: 'American, Crispy, Narration'),
    ElevenLabsVoiceData(id: 'TxGEqnHWrfWFTfGW9XjX', name: 'Josh', gender: 'Male', description: 'American, Deep, Storytelling'),
    ElevenLabsVoiceData(id: 'yoZ06aMxZJJ28mfd3POQ', name: 'Sam', gender: 'Male', description: 'American, Raspy, Conversational'),
    ElevenLabsVoiceData(id: 'iP95p4xoKVk53GoZ742B', name: 'Marcus', gender: 'Male', description: 'Authoritative, Deep, Intense'),
  ];

  // Helper to get a voice object by ID
  static ElevenLabsVoiceData? getById(String id) {
    try {
      return voices.firstWhere((v) => v.id == id);
    } catch (_) {
      return null;
    }
  }
}