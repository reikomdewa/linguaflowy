import 'package:equatable/equatable.dart';
import 'package:linguaflow/models/user_model.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  /// Returns the User object if logged in, otherwise returns NULL.
  /// This allows you to access `state.user` safely anywhere without casting.
  UserModel? get user => (this is AuthAuthenticated) 
      ? (this as AuthAuthenticated).user 
      : null;
  
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthUnauthenticated extends AuthState {}

class AuthAuthenticated extends AuthState {
  // We override the getter field to hold the actual data
  @override
  final UserModel user;

  const AuthAuthenticated(this.user);

  @override
  List<Object> get props => [user];
}

class AuthError extends AuthState {
  final String message;
  final bool isVerificationError;

  const AuthError(this.message, {this.isVerificationError = false});

  @override
  List<Object> get props => [message, isVerificationError];
}

class AuthMessage extends AuthState {
  final String message;

  const AuthMessage(this.message);

  @override
  List<Object> get props => [message];
}

// --- EXTENSION HELPERS ---
// This allows you to write clean code like: if (state.isGuest) ...
extension AuthStateHelper on AuthState {
  
  /// Returns TRUE if the user is explicitly logged in.
  bool get isAuthenticated => this is AuthAuthenticated;

  /// Returns TRUE if the user is explicitly a Guest (not logged in).
  /// This includes Unauthenticated state, Errors, or Messages.
  /// It excludes Loading/Initial states (so you can show spinners).
  bool get isGuest => this is AuthUnauthenticated || this is AuthError || this is AuthMessage;

  /// Helper to get the current language safely.
  /// authenticated -> user's language
  /// guest -> 'English' (default)
  String get currentLanguage {
    return user?.currentLanguage ?? 'English';
  }
  
  /// Helper to get premium status safely.
  /// authenticated -> user's status
  /// guest -> false
  bool get isPremium {
    return user?.isPremium ?? false;
  }
}