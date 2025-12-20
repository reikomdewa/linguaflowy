import 'dart:async';
import 'package:flutter/foundation.dart'; // 1. REQUIRED FOR kIsWeb
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:linguaflow/models/user_model.dart';
import 'package:linguaflow/services/auth_service.dart';
import 'package:linguaflow/utils/logger.dart';

// Import the separate files
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService authService;
  DateTime? _lastEmailSentTime;

  AuthBloc(this.authService) : super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthLoginRequested>(_onAuthLoginRequested);
    on<AuthGoogleLoginRequested>(_onAuthGoogleLoginRequested);
    on<AuthRegisterRequested>(_onAuthRegisterRequested);
    on<AuthResetPasswordRequested>(_onAuthResetPasswordRequested);
    on<AuthResendVerificationEmail>(_onAuthResendVerificationEmail);
    on<AuthLogoutRequested>(_onAuthLogoutRequested);
    on<AuthTargetLanguageChanged>(_onAuthTargetLanguageChanged);
    on<AuthLanguageLevelChanged>(_onAuthLanguageLevelChanged);
    on<AuthUpdateUser>(_onAuthUpdateUser);
    on<AuthDeleteAccount>(_onAuthDeleteAccount);
    on<AuthUpdateListeningTime>(_onAuthUpdateListeningTime);
    on<AuthIncrementLessonsCompleted>(_onAuthIncrementLessonsCompleted);
    on<AuthUpdateXP>(_onAuthUpdateXP);
  }

  // --- HANDLERS ---

  Future<void> _onAuthUpdateXP(
    AuthUpdateXP event,
    Emitter<AuthState> emit,
  ) async {
    if (state is AuthAuthenticated) {
      final currentUser = (state as AuthAuthenticated).user;
      final int newXp = (currentUser.xp + event.xpToAdd).toInt();
      final updatedUser = currentUser.copyWith(xp: newXp);
      
      emit(AuthAuthenticated(updatedUser));

      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.id)
            .update({'xp': FieldValue.increment(event.xpToAdd)});
      } catch (e) {
        printLog("Error updating XP in Firestore: $e");
      }
    }
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    // 2. WEB PERSISTENCE FIX
    // On Web, ensure we look for Local Persistence so refresh doesn't logout
    if (kIsWeb) {
      try {
        await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
      } catch (e) {
        printLog("Error setting web persistence: $e");
      }
    }

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      try {
        await firebaseUser.reload();
      } catch (e) {
        // If reload fails (e.g. token expired), we might need to logout
        printLog("Error reloading user: $e");
      }

      if (firebaseUser.emailVerified) {
        UserModel? user = await authService.getCurrentUser();
        if (user != null) {
          // Sync Photo Logic
          if ((user.photoUrl == null || user.photoUrl!.isEmpty) &&
              firebaseUser.photoURL != null) {
            user = user.copyWith(photoUrl: firebaseUser.photoURL);
            FirebaseFirestore.instance
                .collection('users')
                .doc(user.id)
                .update({'photoUrl': user.photoUrl});
          }

          user = await _checkAndUpateStreak(user);
          emit(AuthAuthenticated(user));
          return;
        }
      }
    }
    emit(AuthUnauthenticated());
  }

  Future<void> _onAuthLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await authService.signIn(event.email, event.password);
      final firebaseUser = FirebaseAuth.instance.currentUser;

      if (firebaseUser != null && !firebaseUser.emailVerified) {
        await authService.signOut();
        emit(
          const AuthError(
            "Email not verified. Please check your inbox.",
            isVerificationError: true,
          ),
        );
      } else {
        UserModel? user = await authService.getCurrentUser();
        if (user != null) {
          user = await _checkAndUpateStreak(user);
          emit(AuthAuthenticated(user));
        } else {
          emit(const AuthError("User data not found."));
        }
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

 Future<void> _onAuthGoogleLoginRequested(
    AuthGoogleLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    print("🔹 BLOC: Received Google Login Request!"); // <--- ADD THIS
    emit(AuthLoading());
    
    try {
      print("🔹 BLOC: Calling AuthService..."); // <--- ADD THIS
      UserModel? user = await authService.signInWithGoogle();
      
      if (user != null) {
        print("🔹 BLOC: User found: ${user.email}"); // <--- ADD THIS
        // ... rest of logic
        emit(AuthAuthenticated(user));
      } else {
        print("🔹 BLOC: User cancelled or null"); // <--- ADD THIS
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      print("🔴 BLOC ERROR: $e"); // <--- ADD THIS
      emit(AuthError("Google Sign In Failed: $e"));
    }
  }

  Future<void> _onAuthUpdateListeningTime(
    AuthUpdateListeningTime event,
    Emitter<AuthState> emit,
  ) async {
    if (state is AuthAuthenticated) {
      final currentUser = (state as AuthAuthenticated).user;
      final newTotal = currentUser.totalListeningMinutes + event.minutesToAdd;
      final updatedUser = currentUser.copyWith(totalListeningMinutes: newTotal);

      emit(AuthAuthenticated(updatedUser));

      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.id)
            .set(
              {'totalListeningMinutes': newTotal},
              SetOptions(merge: true),
            );
      } catch (e) {
        rethrow;
      }
    }
  }

  Future<void> _onAuthIncrementLessonsCompleted(
    AuthIncrementLessonsCompleted event,
    Emitter<AuthState> emit,
  ) async {
    if (state is AuthAuthenticated) {
      final currentUser = (state as AuthAuthenticated).user;
      final newTotal = currentUser.lessonsCompleted + 1;
      final updatedUser = currentUser.copyWith(lessonsCompleted: newTotal);

      emit(AuthAuthenticated(updatedUser));

      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.id)
            .update({'lessonsCompleted': newTotal});
      } catch (e) {
        printLog("Error incrementing lessons: $e");
      }
    }
  }

  Future<void> _onAuthRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await authService.signUp(event.email, event.password, event.displayName);
      try {
        await FirebaseAuth.instance.currentUser?.sendEmailVerification();
        _lastEmailSentTime = DateTime.now();
      } catch (_) {}
      await authService.signOut();
      emit(
        AuthMessage(
          "Account created! Verification email sent to ${event.email}.",
        ),
      );
      emit(AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onAuthResendVerificationEmail(
    AuthResendVerificationEmail event,
    Emitter<AuthState> emit,
  ) async {
    if (_lastEmailSentTime != null) {
      final difference = DateTime.now().difference(_lastEmailSentTime!);
      if (difference.inSeconds < 60) {
        emit(
          AuthError(
            "Please wait ${60 - difference.inSeconds}s before resending.",
          ),
        );
        return;
      }
    }
    emit(AuthLoading());
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: event.email,
        password: event.password,
      );
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        _lastEmailSentTime = DateTime.now();
        await authService.signOut();
        emit(const AuthMessage("Verification email resent! Check your spam folder."));
        emit(AuthUnauthenticated());
      } else if (user != null && user.emailVerified) {
        final userModel = await authService.getCurrentUser();
        if (userModel != null) {
          emit(AuthAuthenticated(userModel));
        }
      }
    } catch (e) {
      emit(AuthError("Could not resend email: ${e.toString()}"));
    }
  }

  Future<void> _onAuthResetPasswordRequested(
    AuthResetPasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: event.email);
      emit(AuthMessage("Password reset link sent to ${event.email}."));
      emit(AuthUnauthenticated());
    } catch (e) {
      emit(AuthError("Failed to send reset email: ${e.toString()}"));
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
      final List<String> updatedTargetLanguages = List.from(
        currentUser.targetLanguages,
      );
      if (!updatedTargetLanguages.contains(event.languageCode)) {
        updatedTargetLanguages.add(event.languageCode);
      }
      final updatedUser = currentUser.copyWith(
        currentLanguage: event.languageCode,
        targetLanguages: updatedTargetLanguages,
      );
      emit(AuthAuthenticated(updatedUser));
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(updatedUser.id)
            .update({
              'currentLanguage': event.languageCode,
              'targetLanguages': updatedTargetLanguages,
            });
      } catch (e) {
        printLog("Error updating language history: $e");
      }
    }
  }

  Future<void> _onAuthLanguageLevelChanged(
    AuthLanguageLevelChanged event,
    Emitter<AuthState> emit,
  ) async {
    if (state is AuthAuthenticated) {
      final currentUser = (state as AuthAuthenticated).user;
      final updatedLevels = Map<String, String>.from(
        currentUser.languageLevels,
      );
      updatedLevels[currentUser.currentLanguage] = event.level;
      final updatedUser = currentUser.copyWith(languageLevels: updatedLevels);
      emit(AuthAuthenticated(updatedUser));
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.id)
            .update({'languageLevels': updatedLevels});
      } catch (e) {
        printLog("Error updating language level: $e");
      }
    }
  }

  Future<void> _onAuthUpdateUser(
    AuthUpdateUser event,
    Emitter<AuthState> emit,
  ) async {
    if (state is AuthAuthenticated) {
      final currentUser = (state as AuthAuthenticated).user;

      final updatedUser = currentUser.copyWith(
        nativeLanguage: event.nativeLanguage ?? currentUser.nativeLanguage,
        targetLanguages: event.targetLanguages ?? currentUser.targetLanguages,
        displayName: event.displayName ?? currentUser.displayName,
        photoUrl: event.photoUrl ?? currentUser.photoUrl,
      );
      emit(AuthAuthenticated(updatedUser));

      try {
        final updates = <String, dynamic>{};
        if (event.nativeLanguage != null) updates['nativeLanguage'] = event.nativeLanguage;
        if (event.targetLanguages != null) updates['targetLanguages'] = event.targetLanguages;
        if (event.displayName != null) updates['displayName'] = event.displayName;
        if (event.photoUrl != null) updates['photoUrl'] = event.photoUrl;

        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.id)
            .update(updates);

        if (event.displayName != null || event.photoUrl != null) {
          await FirebaseAuth.instance.currentUser?.updateDisplayName(event.displayName);
          if (event.photoUrl != null) {
            await FirebaseAuth.instance.currentUser?.updatePhotoURL(event.photoUrl);
          }
        }
      } catch (e) {
        printLog("Error updating profile: $e");
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
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .delete();
        await user.delete();
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      emit(const AuthError("Failed to delete account. Please log in again and try."));
    }
  }

  // --- INTERNAL UTILITIES ---
  
  // Ideally, move this to AuthService
  Future<UserModel> _checkAndUpateStreak(UserModel user) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTime? lastLoginDate = user.lastLoginDate;
    DateTime? lastLoginDay;

    if (lastLoginDate != null) {
      lastLoginDay = DateTime(
        lastLoginDate.year,
        lastLoginDate.month,
        lastLoginDate.day,
      );
    }

    int newStreak = user.streakDays;
    bool needsUpdate = false;

    if (lastLoginDay == null) {
      newStreak = 1;
      needsUpdate = true;
    } else if (today.difference(lastLoginDay).inDays == 0) {
      // Same day
    } else if (today.difference(lastLoginDay).inDays == 1) {
      newStreak += 1;
      needsUpdate = true;
    } else {
      newStreak = 1;
      needsUpdate = true;
    }

    final updatedUser = user.copyWith(
      streakDays: newStreak,
      lastLoginDate: now,
    );

    if (needsUpdate || lastLoginDay != today) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.id)
            .update({
              'streakDays': newStreak,
              'lastLoginDate': Timestamp.fromDate(now),
            });
      } catch (e) {
        printLog("Error updating streak: $e");
      }
    }
    return updatedUser;
  }
}