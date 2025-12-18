// ==========================================
// STATES
// ==========================================
part of 'auth_bloc.dart';

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
  final bool isVerificationError;
  AuthError(this.message, {this.isVerificationError = false});
}

class AuthMessage extends AuthState {
  final String message;
  AuthMessage(this.message);
}