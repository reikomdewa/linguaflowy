


import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Needed for account deletion & profile update
import 'package:linguaflow/models/user_model.dart';
import 'package:linguaflow/services/auth_service.dart';

// EVENTS
abstract class AuthEvent {}

class AuthCheckRequested extends AuthEvent {}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;
  AuthLoginRequested(this.email, this.password);
}

class AuthRegisterRequested extends AuthEvent {
  final String email;
  final String password;
  final String displayName;
  AuthRegisterRequested(this.email, this.password, this.displayName);
}

class AuthLogoutRequested extends AuthEvent {}

class AuthTargetLanguageChanged extends AuthEvent {
  final String languageCode;
  AuthTargetLanguageChanged(this.languageCode);
}

// UPDATED EVENT: Added displayName
class AuthUpdateUser extends AuthEvent {
  final String? nativeLanguage;
  final List<String>? targetLanguages;
  final String? displayName; // <-- Added this

  AuthUpdateUser({
    this.nativeLanguage, 
    this.targetLanguages, 
    this.displayName, // <-- Added this
  });
}

class AuthDeleteAccount extends AuthEvent {}

// STATES
abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final UserModel user;
  AuthAuthenticated(this.user);
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}

// BLOC
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService authService;

  AuthBloc(this.authService) : super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthLoginRequested>(_onAuthLoginRequested);
    on<AuthRegisterRequested>(_onAuthRegisterRequested);
    on<AuthLogoutRequested>(_onAuthLogoutRequested);
    on<AuthTargetLanguageChanged>(_onAuthTargetLanguageChanged);
    
    // Register Profile Handlers
    on<AuthUpdateUser>(_onAuthUpdateUser);
    on<AuthDeleteAccount>(_onAuthDeleteAccount);
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    final user = await authService.getCurrentUser();
    if (user != null) {
      emit(AuthAuthenticated(user));
    } else {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onAuthLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = await authService.signIn(event.email, event.password);
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onAuthRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = await authService.signUp(event.email, event.password, event.displayName);
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onAuthLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await authService.signOut();
    emit(AuthUnauthenticated());
  }

  Future<void> _onAuthTargetLanguageChanged(
    AuthTargetLanguageChanged event,
    Emitter<AuthState> emit,
  ) async {
    if (state is AuthAuthenticated) {
      final currentUser = (state as AuthAuthenticated).user;
      final updatedUser = currentUser.copyWith(currentLanguage: event.languageCode);
      emit(AuthAuthenticated(updatedUser));
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(updatedUser.id)
            .update({'currentLanguage': event.languageCode});
      } catch (e) {
        print("Error updating language: $e");
      }
    }
  }

  // --- UPDATED HANDLER FOR PROFILE ---

  Future<void> _onAuthUpdateUser(
    AuthUpdateUser event,
    Emitter<AuthState> emit,
  ) async {
    if (state is AuthAuthenticated) {
      final currentUser = (state as AuthAuthenticated).user;
      
      // Update local state first (Optimistic)
      final updatedUser = currentUser.copyWith(
        nativeLanguage: event.nativeLanguage ?? currentUser.nativeLanguage,
        targetLanguages: event.targetLanguages ?? currentUser.targetLanguages,
        displayName: event.displayName ?? currentUser.displayName, // Update display name model
      );
      
      emit(AuthAuthenticated(updatedUser));

      // Persist to Firebase
      try {
        final updates = <String, dynamic>{};
        if (event.nativeLanguage != null) updates['nativeLanguage'] = event.nativeLanguage;
        if (event.targetLanguages != null) updates['targetLanguages'] = event.targetLanguages;
        if (event.displayName != null) updates['displayName'] = event.displayName;

        // 1. Update Firestore Database
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.id)
            .update(updates);

        // 2. Update Firebase Auth Profile (so it syncs with Google/Apple sign in visuals if needed)
        if (event.displayName != null) {
          await FirebaseAuth.instance.currentUser?.updateDisplayName(event.displayName);
        }
      } catch (e) {
        // Revert on error or show snackbar (simplified here)
        print("Error updating profile: $e");
      }
    }
  }

  Future<void> _onAuthDeleteAccount(
    AuthDeleteAccount event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // 1. Delete Firestore Data
        await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
        // 2. Delete Auth Account
        await user.delete();
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthError("Failed to delete account. Please log in again and try."));
    }
  }
}