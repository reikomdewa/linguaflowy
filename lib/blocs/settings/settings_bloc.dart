import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- ENUMS ---

/// Specific themes for the Reader View
/// ORDER MATTERS: 0=light, 1=dark, 2=sepia.
/// Do not change order to preserve saved user preferences.
enum ReaderTheme {
  light, // Index 0
  dark,  // Index 1
  sepia, // Index 2
}

// --- EVENTS ---

abstract class SettingsEvent {}

class LoadSettings extends SettingsEvent {}

/// Global App Theme (System, Light, Dark)
class ToggleTheme extends SettingsEvent {
  final ThemeMode themeMode;
  ToggleTheme(this.themeMode);
}

/// Reader Text Size
class ChangeFontSize extends SettingsEvent {
  final double scaleFactor; // 0.8 to 1.4
  ChangeFontSize(this.scaleFactor);
}

/// Reader Background Color (Light, Dark, Sepia)
class ChangeReaderTheme extends SettingsEvent {
  final ReaderTheme readerTheme;
  ChangeReaderTheme(this.readerTheme);
}

/// Reader Font (e.g., 'Roboto', 'Merriweather')
class ChangeFontFamily extends SettingsEvent {
  final String fontFamily;
  ChangeFontFamily(this.fontFamily);
}

/// Reader Line Spacing (e.g., 1.5, 1.8)
class ChangeLineHeight extends SettingsEvent {
  final double lineHeight;
  ChangeLineHeight(this.lineHeight);
}

// --- STATE ---

class SettingsState {
  final ThemeMode themeMode;      // Global App UI
  final double fontSizeScale;     // Reader Text Size
  final ReaderTheme readerTheme;  // Reader Background (Sepia support)
  final String fontFamily;        // Reader Font
  final double lineHeight;        // Reader Spacing

  SettingsState({
    required this.themeMode,
    required this.fontSizeScale,
    required this.readerTheme,
    required this.fontFamily,
    required this.lineHeight,
  });

  // Helper to make updating state easier
  SettingsState copyWith({
    ThemeMode? themeMode,
    double? fontSizeScale,
    ReaderTheme? readerTheme,
    String? fontFamily,
    double? lineHeight,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      fontSizeScale: fontSizeScale ?? this.fontSizeScale,
      readerTheme: readerTheme ?? this.readerTheme,
      fontFamily: fontFamily ?? this.fontFamily,
      lineHeight: lineHeight ?? this.lineHeight,
    );
  }
}

// --- BLOC ---

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc()
      : super(SettingsState(
          themeMode: ThemeMode.system,
          fontSizeScale: 1.0,
          // 1. DEFAULT STATE: Set to Dark (index 1) for immediate load
          readerTheme: ReaderTheme.dark, 
          fontFamily: 'Roboto',
          lineHeight: 1.5,
        )) {
    on<LoadSettings>(_onLoadSettings);
    on<ToggleTheme>(_onToggleTheme);
    on<ChangeFontSize>(_onChangeFontSize);
    on<ChangeReaderTheme>(_onChangeReaderTheme);
    on<ChangeFontFamily>(_onChangeFontFamily);
    on<ChangeLineHeight>(_onChangeLineHeight);
  }

  Future<void> _onLoadSettings(
      LoadSettings event, Emitter<SettingsState> emit) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Global Theme
    final themeIndex = prefs.getInt('themeMode') ?? 0;
    // Safety check for enum range
    final themeMode = (themeIndex >= 0 && themeIndex < ThemeMode.values.length)
        ? ThemeMode.values[themeIndex]
        : ThemeMode.system;

    // 2. Font Size
    final fontScale = prefs.getDouble('fontScale') ?? 1.0;

    // 3. Reader Theme (Sepia, etc)
    // 0=Light, 1=Dark, 2=Sepia. 
    // We default to 1 (Dark) if no setting exists.
    final readerIndex = prefs.getInt('readerTheme') ?? 1; 
    
    final readerTheme = (readerIndex >= 0 && readerIndex < ReaderTheme.values.length)
        ? ReaderTheme.values[readerIndex]
        : ReaderTheme.dark; // Fallback to Dark

    // 4. Font Family - Default to Roboto (Sans-Serif)
    final fontFamily = prefs.getString('fontFamily') ?? 'Roboto';

    // 5. Line Height - Default to 1.5
    final lineHeight = prefs.getDouble('lineHeight') ?? 1.5;

    emit(SettingsState(
      themeMode: themeMode,
      fontSizeScale: fontScale,
      readerTheme: readerTheme,
      fontFamily: fontFamily,
      lineHeight: lineHeight,
    ));
  }

  Future<void> _onToggleTheme(
      ToggleTheme event, Emitter<SettingsState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', event.themeMode.index);
    emit(state.copyWith(themeMode: event.themeMode));
  }

  Future<void> _onChangeFontSize(
      ChangeFontSize event, Emitter<SettingsState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('fontScale', event.scaleFactor);
    emit(state.copyWith(fontSizeScale: event.scaleFactor));
  }

  Future<void> _onChangeReaderTheme(
      ChangeReaderTheme event, Emitter<SettingsState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('readerTheme', event.readerTheme.index);
    emit(state.copyWith(readerTheme: event.readerTheme));
  }

  Future<void> _onChangeFontFamily(
      ChangeFontFamily event, Emitter<SettingsState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fontFamily', event.fontFamily);
    emit(state.copyWith(fontFamily: event.fontFamily));
  }

  Future<void> _onChangeLineHeight(
      ChangeLineHeight event, Emitter<SettingsState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('lineHeight', event.lineHeight);
    emit(state.copyWith(lineHeight: event.lineHeight));
  }
}