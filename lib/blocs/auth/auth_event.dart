import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

class AuthGoogleLoginRequested extends AuthEvent {}

class AuthLogoutRequested extends AuthEvent {}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;

  const AuthLoginRequested(this.email, this.password);

  @override
  List<Object> get props => [email, password];
}

class AuthRegisterRequested extends AuthEvent {
  final String email;
  final String password;
  final String displayName;

  const AuthRegisterRequested(this.email, this.password, this.displayName);

  @override
  List<Object> get props => [email, password, displayName];
}

class AuthResetPasswordRequested extends AuthEvent {
  final String email;

  const AuthResetPasswordRequested(this.email);

  @override
  List<Object> get props => [email];
}

class AuthResendVerificationEmail extends AuthEvent {
  final String email;
  final String password;

  const AuthResendVerificationEmail(this.email, this.password);

  @override
  List<Object> get props => [email, password];
}

class AuthUpdateXP extends AuthEvent {
  final int xpToAdd;

  const AuthUpdateXP(this.xpToAdd);

  @override
  List<Object> get props => [xpToAdd];
}

class AuthUpdateListeningTime extends AuthEvent {
  final int minutesToAdd;

  const AuthUpdateListeningTime(this.minutesToAdd);

  @override
  List<Object> get props => [minutesToAdd];
}

class AuthIncrementLessonsCompleted extends AuthEvent {}

class AuthDeleteAccount extends AuthEvent {}

class AuthTargetLanguageChanged extends AuthEvent {
  final String languageCode;

  const AuthTargetLanguageChanged(this.languageCode);

  @override
  List<Object> get props => [languageCode];
}

class AuthLanguageLevelChanged extends AuthEvent {
  final String level;

  const AuthLanguageLevelChanged(this.level);

  @override
  List<Object> get props => [level];
}

class AuthUpdateUser extends AuthEvent {
  final String? displayName;
  final String? photoUrl;
  final String? nativeLanguage;
  final List<String>? targetLanguages;

  const AuthUpdateUser({
    this.displayName,
    this.photoUrl,
    this.nativeLanguage,
    this.targetLanguages,
  });

  @override
  List<Object?> get props => [displayName, photoUrl, nativeLanguage, targetLanguages];
}