import 'package:cloud_firestore/cloud_firestore.dart'; // Required for GeoPoint
import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

// --- CORE AUTH EVENTS ---

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

class AuthDeleteAccount extends AuthEvent {}

// --- GAMIFICATION & STATS EVENTS ---

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

// --- LANGUAGE SETTINGS EVENTS ---

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

// --- PROFILE UPDATE EVENT (FULL FIXED VERSION) ---

class AuthUpdateUser extends AuthEvent {
  // Identity & Bio
  final String? displayName;
  final String? photoUrl;
  final String? username;
  final String? bio;
  
  // Demographics & Location
  final DateTime? birthDate;
  final String? gender;
  final String? city;
  final String? country;
  final String? countryCode;
  final GeoPoint? location;

  // Languages
  final String? nativeLanguage;
  final List<String>? additionalNativeLanguages;
  final List<String>? targetLanguages;

  // Learning & Preferences
  final List<String>? topics;
  final String? learningGoal;
  final String? correctionStyle;
  final List<String>? communicationStyles;
  
  // Settings
  final int? dailyGoalMinutes;

  // Social Lists (Direct overwrite - usually better to use specific Add/Remove events below)
  final List<String>? friends;
  final List<String>? following;
  final List<String>? followers;
  final List<String>? blockedUsers;

  const AuthUpdateUser({
    this.displayName,
    this.photoUrl,
    this.username,
    this.bio,
    this.birthDate,
    this.gender,
    this.city,
    this.country,
    this.countryCode,
    this.location,
    this.nativeLanguage,
    this.additionalNativeLanguages,
    this.targetLanguages,
    this.topics,
    this.learningGoal,
    this.correctionStyle,
    this.communicationStyles,
    this.dailyGoalMinutes,
    this.friends,
    this.following,
    this.followers,
    this.blockedUsers,
  });

  @override
  List<Object?> get props => [
        displayName,
        photoUrl,
        username,
        bio,
        birthDate,
        gender,
        city,
        country,
        countryCode,
        location,
        nativeLanguage,
        additionalNativeLanguages,
        targetLanguages,
        topics,
        learningGoal,
        correctionStyle,
        communicationStyles,
        dailyGoalMinutes,
        friends,
        following,
        followers,
        blockedUsers,
      ];
}

// --- SPECIFIC SOCIAL EVENTS ---

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