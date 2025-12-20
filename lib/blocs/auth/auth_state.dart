import 'package:equatable/equatable.dart';
import 'package:linguaflow/models/user_model.dart';

abstract class AuthState extends Equatable {
  const AuthState();
  
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthUnauthenticated extends AuthState {}

class AuthAuthenticated extends AuthState {
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