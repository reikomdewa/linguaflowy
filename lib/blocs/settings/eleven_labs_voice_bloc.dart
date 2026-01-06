import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:linguaflow/config/eleven_labs_voices.dart';
import 'package:linguaflow/utils/language_helper.dart';

// --- EVENTS ---
abstract class ElevenLabsVoiceEvent {}

class LoadPremiumVoices extends ElevenLabsVoiceEvent {
  final String languageCode;
  LoadPremiumVoices(this.languageCode);
}

class ChangePremiumVoice extends ElevenLabsVoiceEvent {
  final ElevenLabsVoiceData voice;
  final String languageCode;
  ChangePremiumVoice(this.voice, this.languageCode);
}

// --- STATE ---
class ElevenLabsVoiceState {
  final List<ElevenLabsVoiceData> voices;
  final ElevenLabsVoiceData? selectedVoice;
  final bool isLoading;

  ElevenLabsVoiceState({
    this.voices = const [],
    this.selectedVoice,
    this.isLoading = false,
  });

  ElevenLabsVoiceState copyWith({
    List<ElevenLabsVoiceData>? voices,
    ElevenLabsVoiceData? selectedVoice,
    bool? isLoading,
  }) {
    return ElevenLabsVoiceState(
      voices: voices ?? this.voices,
      selectedVoice: selectedVoice ?? this.selectedVoice,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// --- BLOC ---
class ElevenLabsVoiceBloc extends Bloc<ElevenLabsVoiceEvent, ElevenLabsVoiceState> {
  ElevenLabsVoiceBloc() : super(ElevenLabsVoiceState()) {
    on<LoadPremiumVoices>(_onLoadVoices);
    on<ChangePremiumVoice>(_onChangeVoice);
  }

  Future<void> _onLoadVoices(
    LoadPremiumVoices event,
    Emitter<ElevenLabsVoiceState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));

    final cleanLang = LanguageHelper.getLangCode(event.languageCode);
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Get saved ID
    final savedId = prefs.getString('elevenlabs_voice_id_$cleanLang');
    
    // 2. Determine Selected Voice
    ElevenLabsVoiceData? selection;
    if (savedId != null) {
      selection = ElevenLabsVoiceData.getById(savedId);
    }
    
    // If no selection, use the Default from your original map (Hardcoded fallback)
    if (selection == null) {
       // Optional: You could import the map from the service, or just default to first
       selection = ElevenLabsVoiceData.voices.first; 
    }

    // 3. Return all voices (Since they are multilingual, we return the whole list)
    // You could filter here if you wanted specific voices for specific langs,
    // but Multilingual V2 works with all of them.
    emit(state.copyWith(
      voices: ElevenLabsVoiceData.voices,
      selectedVoice: selection,
      isLoading: false,
    ));
  }

  Future<void> _onChangeVoice(
    ChangePremiumVoice event,
    Emitter<ElevenLabsVoiceState> emit,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanLang = LanguageHelper.getLangCode(event.languageCode);

    // Save per language
    await prefs.setString('elevenlabs_voice_id_$cleanLang', event.voice.id);

    emit(state.copyWith(selectedVoice: event.voice));
  }
}