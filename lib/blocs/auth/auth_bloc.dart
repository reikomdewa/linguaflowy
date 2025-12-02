import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import this
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

// NEW EVENT: Add this
class AuthTargetLanguageChanged extends AuthEvent {
  final String languageCode;
  AuthTargetLanguageChanged(this.languageCode);
}

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
    on<AuthTargetLanguageChanged>(_onAuthTargetLanguageChanged); // Register handler
  }

  // ... (Login/Register/Check/Logout handlers remain the same) ...
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

  // HANDLER FOR LANGUAGE CHANGE
  Future<void> _onAuthTargetLanguageChanged(
    AuthTargetLanguageChanged event,
    Emitter<AuthState> emit,
  ) async {
    if (state is AuthAuthenticated) {
      final currentUser = (state as AuthAuthenticated).user;
      
      // 1. Create updated user object
      final updatedUser = currentUser.copyWith(
        currentLanguage: event.languageCode
      );

      // 2. Optimistically update UI
      emit(AuthAuthenticated(updatedUser));

      // 3. Persist to Firebase
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(updatedUser.id)
            .update({'currentLanguage': event.languageCode});
      } catch (e) {
        // If save fails, you might want to revert or show error, 
        // but for now we keep the UI responsive
        print("Error updating language: $e");
      }
    }
  }
}