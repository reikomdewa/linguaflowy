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

  // ... _onLoadSettings remains the same ...
  Future<void> _onLoadSettings(
      LoadSettings event, Emitter<SettingsState> emit) async {
    final prefs = await SharedPreferences.getInstance();

    final themeIndex = prefs.getInt('themeMode') ?? 0;
    final themeMode = (themeIndex >= 0 && themeIndex < ThemeMode.values.length)
        ? ThemeMode.values[themeIndex]
        : ThemeMode.system;

    final fontScale = prefs.getDouble('fontScale') ?? 1.0;

    final readerIndex = prefs.getInt('readerTheme') ?? 1;
    final readerTheme = (readerIndex >= 0 && readerIndex < ReaderTheme.values.length)
        ? ReaderTheme.values[readerIndex]
        : ReaderTheme.dark;

    final fontFamily = prefs.getString('fontFamily') ?? 'Roboto';
    final lineHeight = prefs.getDouble('lineHeight') ?? 1.5;

    emit(SettingsState(
      themeMode: themeMode,
      fontSizeScale: fontScale,
      readerTheme: readerTheme,
      fontFamily: fontFamily,
      lineHeight: lineHeight,
    ));
  }

  // --- UPDATED METHOD ---
  Future<void> _onToggleTheme(
      ToggleTheme event, Emitter<SettingsState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Save and Update Global Theme
    await prefs.setInt('themeMode', event.themeMode.index);

    // 2. Calculate New Reader Theme based on Global Theme
    ReaderTheme newReaderTheme = state.readerTheme;

    if (event.themeMode == ThemeMode.light) {
      newReaderTheme = ReaderTheme.light;
    } else if (event.themeMode == ThemeMode.dark) {
      newReaderTheme = ReaderTheme.dark;
    }
    // Note: If event.themeMode is ThemeMode.system, we usually 
    // keep the current readerTheme because we don't know if the OS is currently
    // light or dark inside the Bloc without context.

    // 3. Save Reader Theme (Syncing preferences)
    if (newReaderTheme != state.readerTheme) {
      await prefs.setInt('readerTheme', newReaderTheme.index);
    }

    // 4. Emit State with BOTH updated
    emit(state.copyWith(
      themeMode: event.themeMode,
      readerTheme: newReaderTheme, 
    ));
  }

  // --- REMAINS THE SAME (The "Unless" condition) ---
  Future<void> _onChangeReaderTheme(
      ChangeReaderTheme event, Emitter<SettingsState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    // This allows the user to manually override the reader theme 
    // to Sepia (or others) regardless of what the App Theme is.
    await prefs.setInt('readerTheme', event.readerTheme.index);
    emit(state.copyWith(readerTheme: event.readerTheme));
  }

  // ... _onChangeFontSize, _onChangeFontFamily, _onChangeLineHeight remain the same ...
  Future<void> _onChangeFontSize(
      ChangeFontSize event, Emitter<SettingsState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('fontScale', event.scaleFactor);
    emit(state.copyWith(fontSizeScale: event.scaleFactor));
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