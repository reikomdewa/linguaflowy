
part of 'auth_bloc.dart';

// ==========================================
// EVENTS
// ==========================================
abstract class AuthEvent {}

class AuthCheckRequested extends AuthEvent {}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;
  AuthLoginRequested(this.email, this.password);
}

class AuthGoogleLoginRequested extends AuthEvent {}

class AuthRegisterRequested extends AuthEvent {
  final String email;
  final String password;
  final String displayName;
  AuthRegisterRequested(this.email, this.password, this.displayName);
}

class AuthResetPasswordRequested extends AuthEvent {
  final String email;
  AuthResetPasswordRequested(this.email);
}

class AuthResendVerificationEmail extends AuthEvent {
  final String email;
  final String password;
  AuthResendVerificationEmail(this.email, this.password);
}

class AuthLogoutRequested extends AuthEvent {}

class AuthTargetLanguageChanged extends AuthEvent {
  final String languageCode;
  AuthTargetLanguageChanged(this.languageCode);
}

class AuthLanguageLevelChanged extends AuthEvent {
  final String level;
  AuthLanguageLevelChanged(this.level);
}

class AuthUpdateUser extends AuthEvent {
  final String? nativeLanguage;
  final List<String>? targetLanguages;
  final String? displayName;

  AuthUpdateUser({this.nativeLanguage, this.targetLanguages, this.displayName});
}

class AuthDeleteAccount extends AuthEvent {}

// --- NEW EVENTS FOR STATS ---
class AuthUpdateListeningTime extends AuthEvent {
  final int minutesToAdd;
  AuthUpdateListeningTime(this.minutesToAdd);
}

class AuthIncrementLessonsCompleted extends AuthEvent {}

class AuthUpdateXP extends AuthEvent {
  final int xpToAdd;
  AuthUpdateXP(this.xpToAdd);
}