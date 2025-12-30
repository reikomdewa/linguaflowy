import 'package:equatable/equatable.dart';
import 'package:linguaflow/models/user_model.dart'; // Import UserModel

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
  final String? bio; // Added to general update
  final int? dailyGoalMinutes; // Added to general update

  // You can keep this general update, or use specific events below
  // For lists, specific events are usually better for clarity and array manipulation
  final List<String>? friends;
  final List<String>? following;
  final List<String>? followers;
  final List<String>? blockedUsers;


  const AuthUpdateUser({
    this.displayName,
    this.photoUrl,
    this.nativeLanguage,
    this.targetLanguages,
    this.bio,
    this.dailyGoalMinutes,
    this.friends,
    this.following,
    this.followers,
    this.blockedUsers,
  });

  @override
  List<Object?> get props => [
    displayName, photoUrl, nativeLanguage, targetLanguages,
    bio, dailyGoalMinutes, friends, following, followers, blockedUsers
  ];
}

// --- NEW SOCIAL EVENTS ---
class AuthAddFriend extends AuthEvent {
  final String friendId;
  const AuthAddFriend(this.friendId);
  @override
  List<Object> get props => [friendId];
}

class AuthRemoveFriend extends AuthEvent {
  final String friendId;
  const AuthRemoveFriend(this.friendId);
  @override
  List<Object> get props => [friendId];
}

class AuthFollowUser extends AuthEvent {
  final String targetUserId;
  const AuthFollowUser(this.targetUserId);
  @override
  List<Object> get props => [targetUserId];
}

class AuthUnfollowUser extends AuthEvent {
  final String targetUserId;
  const AuthUnfollowUser(this.targetUserId);
  @override
  List<Object> get props => [targetUserId];
}

class AuthBlockUser extends AuthEvent {
  final String targetUserId;
  const AuthBlockUser(this.targetUserId);
  @override
  List<Object> get props => [targetUserId];
}

class AuthUnblockUser extends AuthEvent {
  final String targetUserId;
  const AuthUnblockUser(this.targetUserId);
  @override
  List<Object> get props => [targetUserId];
}