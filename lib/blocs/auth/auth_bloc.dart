import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:linguaflow/models/user_model.dart';
import 'package:linguaflow/services/auth_service.dart';
import 'package:linguaflow/utils/logger.dart';

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

// ==========================================
// STATES
// ==========================================
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

// ==========================================
// BLOC
// ==========================================
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

    // New Handlers
    on<AuthUpdateListeningTime>(_onAuthUpdateListeningTime);
    on<AuthIncrementLessonsCompleted>(_onAuthIncrementLessonsCompleted);
  }

  // --- STREAK CALCULATION LOGIC ---
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
      // First time
      newStreak = 1;
      needsUpdate = true;
    } else if (today.difference(lastLoginDay).inDays == 0) {
      // Same day, no streak change, but maybe update exact timestamp
    } else if (today.difference(lastLoginDay).inDays == 1) {
      // Consecutive day
      newStreak += 1;
      needsUpdate = true;
    } else {
      // Missed a day
      newStreak = 1;
      needsUpdate = true;
    }

    // Always update the lastLoginDate to now
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

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      await firebaseUser.reload();

      if (firebaseUser.emailVerified) {
        UserModel? user = await authService.getCurrentUser();
        if (user != null) {
          // CHECK STREAK HERE
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
          AuthError(
            "Email not verified. Please check your inbox.",
            isVerificationError: true,
          ),
        );
      } else {
        UserModel? user = await authService.getCurrentUser();
        if (user != null) {
          // CHECK STREAK HERE TOO
          user = await _checkAndUpateStreak(user);
          emit(AuthAuthenticated(user));
        } else {
          emit(AuthError("User data not found."));
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
    emit(AuthLoading());
    try {
      UserModel? user = await authService.signInWithGoogle();
      if (user != null) {
        // CHECK STREAK HERE TOO
        user = await _checkAndUpateStreak(user);
        emit(AuthAuthenticated(user));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthError("Google Sign In Failed: ${e.toString()}"));
    }
  }

  // --- NEW HANDLER: LISTENING TIME ---
  Future<void> _onAuthUpdateListeningTime(
    AuthUpdateListeningTime event,
    Emitter<AuthState> emit,
  ) async {
    if (state is AuthAuthenticated) {
      final currentUser = (state as AuthAuthenticated).user;

      // Calculate new total
      // If the field was null/0 locally, this handles the increment correctly
      final newTotal = currentUser.totalListeningMinutes + event.minutesToAdd;

      final updatedUser = currentUser.copyWith(totalListeningMinutes: newTotal);

      // Emit immediately for UI
      emit(AuthAuthenticated(updatedUser));

      // SAVE TO FIRESTORE ROBUSTLY
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.id)
            .set(
              {'totalListeningMinutes': newTotal},
              SetOptions(merge: true), // <--- THIS CREATES THE FIELD IF MISSING
            );
      } catch (e) {
        rethrow;
      }
    }
  }

  // --- NEW HANDLER: LESSON COMPLETED ---
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

  // ... (Rest of existing methods: Register, ResetPass, etc. remain unchanged) ...
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
        emit(AuthMessage("Verification email resent! Check your spam folder."));
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
      );
      emit(AuthAuthenticated(updatedUser));
      try {
        final updates = <String, dynamic>{};
        if (event.nativeLanguage != null) {
          updates['nativeLanguage'] = event.nativeLanguage;
        }
        if (event.targetLanguages != null) {
          updates['targetLanguages'] = event.targetLanguages;
        }
        if (event.displayName != null) {
          updates['displayName'] = event.displayName;
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.id)
            .update(updates);

        if (event.displayName != null) {
          await FirebaseAuth.instance.currentUser?.updateDisplayName(
            event.displayName,
          );
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
      emit(AuthError("Failed to delete account. Please log in again and try."));
    }
  }
}
