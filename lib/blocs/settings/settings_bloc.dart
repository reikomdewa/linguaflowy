import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Events
abstract class SettingsEvent {}

class LoadSettings extends SettingsEvent {}

class ToggleTheme extends SettingsEvent {
  final ThemeMode themeMode;
  ToggleTheme(this.themeMode);
}

class ChangeFontSize extends SettingsEvent {
  final double scaleFactor; // 1.0 = Medium, 0.8 = Small, 1.2 = Large
  ChangeFontSize(this.scaleFactor);
}

// State
class SettingsState {
  final ThemeMode themeMode;
  final double fontSizeScale;

  SettingsState({required this.themeMode, required this.fontSizeScale});
}

// Bloc
class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc()
      : super(SettingsState(themeMode: ThemeMode.system, fontSizeScale: 1.0)) {
    on<LoadSettings>(_onLoadSettings);
    on<ToggleTheme>(_onToggleTheme);
    on<ChangeFontSize>(_onChangeFontSize);
  }

  Future<void> _onLoadSettings(
      LoadSettings event, Emitter<SettingsState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load Theme
    final themeIndex = prefs.getInt('themeMode') ?? 0;
    final themeMode = ThemeMode.values[themeIndex]; // 0:system, 1:light, 2:dark

    // Load Font
    final fontScale = prefs.getDouble('fontScale') ?? 1.0;

    emit(SettingsState(themeMode: themeMode, fontSizeScale: fontScale));
  }

  Future<void> _onToggleTheme(
      ToggleTheme event, Emitter<SettingsState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', event.themeMode.index);
    emit(SettingsState(themeMode: event.themeMode, fontSizeScale: state.fontSizeScale));
  }

  Future<void> _onChangeFontSize(
      ChangeFontSize event, Emitter<SettingsState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('fontScale', event.scaleFactor);
    emit(SettingsState(themeMode: state.themeMode, fontSizeScale: event.scaleFactor));
  }
}