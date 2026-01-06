import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:linguaflow/utils/language_helper.dart'; // <--- IMPORT THIS

// --- EVENTS ---
abstract class TtsVoiceEvent {}

class LoadVoices extends TtsVoiceEvent {
  final String languageCode;
  LoadVoices(this.languageCode);
}

class ChangeVoice extends TtsVoiceEvent {
  final Map<String, String> voice; 
  ChangeVoice(this.voice);
}

// --- STATE ---
class TtsVoiceState {
  final List<Map<String, String>> availableVoices;
  final Map<String, String>? selectedVoice;
  final bool isLoading;

  TtsVoiceState({
    this.availableVoices = const [],
    this.selectedVoice,
    this.isLoading = false,
  });

  TtsVoiceState copyWith({
    List<Map<String, String>>? availableVoices,
    Map<String, String>? selectedVoice,
    bool? isLoading,
  }) {
    return TtsVoiceState(
      availableVoices: availableVoices ?? this.availableVoices,
      selectedVoice: selectedVoice ?? this.selectedVoice,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// --- BLOC ---
class TtsVoiceBloc extends Bloc<TtsVoiceEvent, TtsVoiceState> {
  final FlutterTts _flutterTts = FlutterTts();

  TtsVoiceBloc() : super(TtsVoiceState()) {
    on<LoadVoices>(_onLoadVoices);
    on<ChangeVoice>(_onChangeVoice);
  }

  Future<void> _onLoadVoices(
    LoadVoices event,
    Emitter<TtsVoiceState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));

    try {
      // 1. Get clean target code (e.g. "Spanish" -> "es")
      final targetLang = LanguageHelper.getLangCode(event.languageCode);

      // 2. Get all voices
      final List<dynamic> voices = await _flutterTts.getVoices;
      
      final List<Map<String, String>> filteredVoices = [];
      
      for (var v in voices) {
        final Map<String, String> voiceMap = Map<String, String>.from(v);
        final String locale = voiceMap['locale'] ?? '';
        
        // Robust check: does 'es_US' start with 'es'?
        // We use the helper logic indirectly by checking startsWith
        if (locale.toLowerCase().startsWith(targetLang.toLowerCase())) {
          filteredVoices.add(voiceMap);
        }
      }

      // 3. Load saved preference using standard key
      final prefs = await SharedPreferences.getInstance();
      final String? savedName = prefs.getString('tts_voice_name_$targetLang');
      final String? savedLocale = prefs.getString('tts_voice_locale_$targetLang');

      Map<String, String>? currentSelection;
      
      if (savedName != null && savedLocale != null) {
        // Try to find the exact object to keep UI consistent
        final match = filteredVoices.where((v) => v['name'] == savedName).firstOrNull;
        currentSelection = match ?? {'name': savedName, 'locale': savedLocale};
      } else if (filteredVoices.isNotEmpty) {
        currentSelection = filteredVoices.first;
      }

      emit(state.copyWith(
        availableVoices: filteredVoices,
        selectedVoice: currentSelection,
        isLoading: false,
      ));
    } catch (e) {
      print("Error loading voices: $e");
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onChangeVoice(
    ChangeVoice event,
    Emitter<TtsVoiceState> emit,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    
    // --- FIX: ROBUST KEY GENERATION ---
    // 1. Get the locale from the selected voice (e.g. "es_US" or "es-ES")
    final rawLocale = event.voice['locale']!;
    
    // 2. Extract just the language part ("es") using the Helper logic 
    // This ensures it matches exactly what ReaderScreen generates.
    // If Helper expects "Spanish", we pass the first part of locale.
    // Ideally, we treat the first 2 letters as the code.
    
    // Split by either '-' or '_' to handle Android inconsistencies
    String langCode = rawLocale.split(RegExp(r'[-_]'))[0].toLowerCase();
    
    // Use Helper just to be safe (in case langCode is 'spa' or something weird)
    langCode = LanguageHelper.getLangCode(langCode);
    
    await prefs.setString('tts_voice_name_$langCode', event.voice['name']!);
    await prefs.setString('tts_voice_locale_$langCode', event.voice['locale']!);

    emit(state.copyWith(selectedVoice: event.voice));
  }
}