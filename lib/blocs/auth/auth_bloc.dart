import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:linguaflow/models/user_model.dart';
import 'package:linguaflow/services/auth_service.dart';
import 'package:linguaflow/utils/firebase_utils.dart'; // Assuming this is correct
import 'package:linguaflow/services/user_service.dart';
// ADD THIS IMPORT

import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService authService;
  final UserService _userService;
  DateTime? _lastEmailSentTime;
  final _storage = const FlutterSecureStorage(); // 1. Init Storage
  static const String _gumroadProductId = "uIq5F1GwaxHuVmADcfcbIw==";

  AuthBloc(this.authService, this._userService) : super(AuthInitial()) {
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
    //Social helpers
    on<AuthAddFriend>(_onAuthAddFriend);
    on<AuthRemoveFriend>(_onAuthRemoveFriend);
    on<AuthFollowUser>(_onAuthFollowUser);
    on<AuthUnfollowUser>(_onAuthUnfollowUser);
    on<AuthBlockUser>(_onAuthBlockUser);
    on<AuthUnblockUser>(_onAuthUnblockUser);
  }

  // --- HELPER: Fetch Premium Data Once ---
  // --- HELPER: Fetch Premium Data & Check Expiration ---
  Future<UserModel> _attachPremiumData(UserModel user) async {
    // A. Check Local Cache first (Fix #5 - Offline Support)
    final cachedExpiry = await _storage.read(key: 'premium_expiry_${user.id}');

    // Only fetch from network if user is marked Premium in Firebase
    if (user.isPremium) {
      try {
        final premiumData = await FirebaseUtils().getPurchaseData(user.id);

        if (premiumData != null) {
          // --- FIX #2: GUMROAD REFUND CHECK ---
          if (premiumData['source'] == 'gumroad') {
            // We can do a lightweight check here.
            // To save API calls, maybe only check if 7 days passed?
            // For now, let's check every session for maximum security.
            final isStillValid = await _reverifyGumroadStatus(
              premiumData['code_id'] ?? '',
            );

            if (!isStillValid) {
              print(
                "License Key is no longer valid (Refund/Chargeback). Downgrading.",
              );
              await _downgradeUser(user.id);
              return user.copyWith(isPremium: false, premiumDetails: null);
            }

            // Since doc ID = License Key in our setup:
            // We need the document ID (the code). FirebaseUtils needs to return the doc ID too.
            // Assuming premiumData contains the ID or we can pass it if we change FirebaseUtils.
          }

          // 1. CALCULATE EXPIRATION DATE
          DateTime? expireDate;

          // Priority 1: Manual Date set by Admin
          if (premiumData['manual_expires_at'] != null) {
            expireDate = DateTime.tryParse(premiumData['manual_expires_at']);
          }
          // Priority 2: Calculated from Amount
          else {
            DateTime? purchaseDate;
            if (premiumData['claimedAt'] != null) {
              purchaseDate = (premiumData['claimedAt'] as Timestamp).toDate();
            } else if (premiumData['purchased_at'] != null) {
              purchaseDate = DateTime.tryParse(premiumData['purchased_at']);
            }

            if (purchaseDate != null) {
              final int amountPaid = premiumData['amount_paid'] ?? 0;
              // Lifetime
              if (amountPaid >= 9500) {
                expireDate = null;
              }
              // 6 Months
              else if (amountPaid >= 2000) {
                expireDate = purchaseDate.add(const Duration(days: 30 * 6));
              }
              // 1 Month
              else {
                expireDate = purchaseDate.add(const Duration(days: 30));
              }
            }
          }

          // 2. CHECK IF EXPIRED
          if (expireDate != null && DateTime.now().isAfter(expireDate)) {
            print("EXPIRED. Downgrading.");
            await _downgradeUser(user.id);
            return user.copyWith(isPremium: false, premiumDetails: null);
          }

          // 3. CACHE THE EXPIRY FOR OFFLINE USE (Fix #5)
          await _storage.write(
            key: 'premium_expiry_${user.id}',
            value: expireDate?.toIso8601String() ?? 'LIFETIME',
          );

          return user.copyWith(premiumDetails: premiumData);
        }
      } catch (e) {
        print("Network error fetching premium: $e");
        // FALLBACK TO SECURE STORAGE (Fix #5)
        if (cachedExpiry != null) {
          if (cachedExpiry == 'LIFETIME') return user; // Still premium

          final localDate = DateTime.tryParse(cachedExpiry);
          if (localDate != null && DateTime.now().isAfter(localDate)) {
            // Expired locally
            return user.copyWith(isPremium: false, premiumDetails: null);
          }
          // Valid locally
          return user;
        }
      }
    }
    return user;
  }

  // --- HELPER: Downgrade User ---
  Future<void> _downgradeUser(String userId) async {
    await _storage.delete(key: 'premium_expiry_$userId');
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'isPremium': false,
    });
  }

  // --- HELPER: Re-verify Gumroad (Fix #2) ---
  // Call this inside _attachPremiumData if you have the key
  Future<bool> _reverifyGumroadStatus(String key) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.gumroad.com/v2/licenses/verify'),
        body: {'product_id': _gumroadProductId, 'license_key': key},
      );

      // If Gumroad is down or error, fail safe (allow access) to not block innocent users
      if (response.statusCode != 200) return true;

      final data = jsonDecode(response.body);

      // 1. Check if the key itself exists
      if (data['success'] != true) return false;

      final purchase = data['purchase'];

      // 2. PARSE THE "OTHER DATA" (Security Checks)

      // A. Refunded: Merchant voluntarily gave money back
      if (purchase['refunded'] == true) {
        print("Gumroad Check: User was refunded.");
        return false;
      }

      // B. Chargebacked: User forced money back via bank (Fraud)
      if (purchase['chargebacked'] == true) {
        print("Gumroad Check: Payment was chargebacked.");
        return false;
      }

      // C. Disputed: User opened a dispute with PayPal/Bank
      // (Usually treated as suspended access until resolved)
      if (purchase['disputed'] == true) {
        print("Gumroad Check: Payment is disputed.");
        return false;
      }

      // D. Subscription Failed: (Only for recurring subscriptions)
      // If the latest payment failed, this might be non-null.
      if (purchase['subscription_failed_at'] != null) {
        // Optional: Check if grace period is over
        print("Gumroad Check: Subscription payment failed.");
        // return false; // Uncomment if you want strict enforcement
      }

      // E. Subscription Cancelled:
      // purchase['subscription_cancelled_at'] will be set if they cancelled.
      // Usually you still let them finish the paid month, so we return TRUE here
      // and let the Date Logic in _attachPremiumData handle the expiration.

      return true;
    } catch (e) {
      print("Gumroad Re-verify Network Error: $e");
      return true; // Assume valid on network error
    }
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
        print("Error updating XP in Firestore: $e");
      }
    }
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    // Wrap EVERYTHING in try-catch to prevent getting stuck in "AuthInitial"
    try {
      // 1. Web Persistence Fix
      if (kIsWeb) {
        try {
          await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
        } catch (e) {
          print("Error setting web persistence: $e");
          // Continue execution even if this fails
        }
      }

      // 2. Check Firebase User
      final firebaseUser = FirebaseAuth.instance.currentUser;

      if (firebaseUser != null) {
        // A. Reload user to get latest status (e.g. email verified)
        try {
          await firebaseUser.reload();
        } catch (e) {
          print("Error reloading user: $e");
          // If reload fails (network), we might still want to try loading the cached user
        }

        // B. Check Verification & Load Data
        if (firebaseUser.emailVerified) {
          UserModel? user = await authService.getCurrentUser();

          if (user != null) {
            // C. Sync Google Photo if missing
            if ((user.photoUrl == null || user.photoUrl!.isEmpty) &&
                firebaseUser.photoURL != null) {
              user = user.copyWith(photoUrl: firebaseUser.photoURL);
              // Fire & Forget update
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.id)
                  .update({'photoUrl': user.photoUrl});
            }

            // D. Update Streak & Premium
            user = await _checkAndUpateStreak(user);
            user = await _attachPremiumData(user);

            emit(AuthAuthenticated(user));
            return; // EXIT HERE if successful
          }
        }
      }
    } catch (e) {
      print("CRITICAL AUTH CHECK ERROR: $e");
      // Fallthrough to Unauthenticated so the app loads for guests
    }

    // 3. Fallback: If user is null, email not verified, db error, or any exception:
    // We treat them as a Guest.
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
          // NEW: Load premium data into memory
          user = await _attachPremiumData(user);

          emit(AuthAuthenticated(user));
        } else {
          emit(const AuthError("User data not found."));
        }
      }
    } on FirebaseAuthException catch (e) {
      // Handle specific Firebase errors
      // 'invalid-credential' is the new standard error for Email Enumeration Protection
      if (e.code == 'invalid-credential' ||
          e.code == 'user-not-found' ||
          e.code == 'wrong-password') {
        emit(const AuthError("Invalid email or password."));
      } else if (e.code == 'invalid-email') {
        emit(const AuthError("The email address is invalid."));
      } else if (e.code == 'user-disabled') {
        emit(const AuthError("This user account has been disabled."));
      } else if (e.code == 'too-many-requests') {
        emit(const AuthError("Too many attempts. Try again later."));
      } else {
        // Fallback for other Firebase errors
        emit(AuthError(e.message ?? "Authentication failed."));
      }
    } catch (e) {
      // Fallback for non-Firebase errors (e.g. Network issues)
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
        user = await _checkAndUpateStreak(
          user,
        ); // Good to update streak here too
        // NEW: Load premium data into memory
        user = await _attachPremiumData(user);

        emit(AuthAuthenticated(user));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
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
            .set({'totalListeningMinutes': newTotal}, SetOptions(merge: true));
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
        print("Error incrementing lessons: $e");
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
        emit(
          const AuthMessage(
            "Verification email resent! Check your spam folder.",
          ),
        );
        emit(AuthUnauthenticated());
      } else if (user != null && user.emailVerified) {
        final userModel = await authService.getCurrentUser();
        if (userModel != null) {
          // If they just verified, load their data
          var user = userModel;
          user = await _attachPremiumData(user);
          emit(AuthAuthenticated(user));
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
        print("Error updating language history: $e");
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
        print("Error updating language level: $e");
      }
    }
  }

Future<void> _onAuthUpdateUser(
    AuthUpdateUser event,
    Emitter<AuthState> emit,
  ) async {
    if (state is AuthAuthenticated) {
      final currentUser = (state as AuthAuthenticated).user;

      // 1. Update Local State (Optimistic UI Update)
      // We use the event data if present, otherwise keep existing data.
      final updatedUser = currentUser.copyWith(
        displayName: event.displayName,
        photoUrl: event.photoUrl,
        username: event.username,
        bio: event.bio,
        birthDate: event.birthDate,
        gender: event.gender,
        city: event.city,
        country: event.country,
        countryCode: event.countryCode,
        location: event.location,
        nativeLanguage: event.nativeLanguage,
        additionalNativeLanguages: event.additionalNativeLanguages,
        targetLanguages: event.targetLanguages,
        topics: event.topics,
        learningGoal: event.learningGoal,
        correctionStyle: event.correctionStyle,
        communicationStyles: event.communicationStyles,
        // If name changes, we update keywords locally too
        searchKeywords: event.displayName != null 
            ? _generateSearchKeywords(event.displayName!) 
            : currentUser.searchKeywords,
      );

      // Emit the new state immediately so the UI updates
      emit(AuthAuthenticated(updatedUser));

      // 2. Prepare Firestore Updates
      // We only add fields to the map if they were actually passed in the event.
      final Map<String, dynamic> updates = {};

      if (event.displayName != null) {
        updates['displayName'] = event.displayName;
        // Auto-update search keywords when name changes
        updates['searchKeywords'] = _generateSearchKeywords(event.displayName!);
      }
      
      if (event.photoUrl != null) updates['photoUrl'] = event.photoUrl;
      if (event.username != null) updates['username'] = event.username;
      if (event.bio != null) updates['bio'] = event.bio;
      
      // Demographics & Location
      if (event.birthDate != null) updates['birthDate'] = Timestamp.fromDate(event.birthDate!);
      if (event.gender != null) updates['gender'] = event.gender;
      if (event.city != null) updates['city'] = event.city;
      if (event.country != null) updates['country'] = event.country;
      if (event.countryCode != null) updates['countryCode'] = event.countryCode;
      if (event.location != null) updates['location'] = event.location; // GeoPoint

      // Languages
      if (event.nativeLanguage != null) updates['nativeLanguage'] = event.nativeLanguage;
      if (event.additionalNativeLanguages != null) updates['additionalNativeLanguages'] = event.additionalNativeLanguages;
      if (event.targetLanguages != null) updates['targetLanguages'] = event.targetLanguages;

      // Learning Preferences
      if (event.topics != null) updates['topics'] = event.topics;
      if (event.learningGoal != null) updates['learningGoal'] = event.learningGoal;
      if (event.correctionStyle != null) updates['correctionStyle'] = event.correctionStyle;
      if (event.communicationStyles != null) updates['communicationStyles'] = event.communicationStyles;

      // 3. Persist to Firestore & Firebase Auth
      try {
        if (updates.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.id)
              .update(updates);
        }

        // Sync basic profile data to Firebase Auth (User Management)
        if (event.displayName != null || event.photoUrl != null) {
          final fbUser = FirebaseAuth.instance.currentUser;
          if (fbUser != null) {
            if (event.displayName != null) {
              await fbUser.updateDisplayName(event.displayName);
            }
            if (event.photoUrl != null) {
              await fbUser.updatePhotoURL(event.photoUrl);
            }
          }
        }
      } catch (e) {
        print("Error updating user profile: $e");
        // Optional: You could emit an AuthError here, or just log it.
        // If you emit error, remember the UI has already optimistically updated.
      }
    }
  }

  // --- INTERNAL HELPER: Generate Search Keywords ---
  // Generates substrings for partial matching in Firestore
  List<String> _generateSearchKeywords(String name) {
    List<String> keywords = [];
    String lowerName = name.toLowerCase();
    
    // 1. Add incremental substrings (e.g., "A", "As", "Asa", "Asad")
    String current = "";
    for (int i = 0; i < lowerName.length; i++) {
      current += lowerName[i];
      keywords.add(current);
    }

    // 2. Add individual words (e.g., "Drissa" for "Asad Drissa")
    final words = lowerName.split(' ');
    for (var word in words) {
      if (word.isNotEmpty && !keywords.contains(word)) {
        keywords.add(word);
        // Also add incremental substrings for the last name
        String subWord = "";
        for (int i = 0; i < word.length; i++) {
          subWord += word[i];
          if (!keywords.contains(subWord)) {
            keywords.add(subWord);
          }
        }
      }
    }
    
    return keywords.toSet().toList(); // Remove duplicates
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
      emit(
        const AuthError(
          "Failed to delete account. Please log in again and try.",
        ),
      );
    }
  }

  // --- INTERNAL UTILITIES ---

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
        print("Error updating streak: $e");
      }
    }
    return updatedUser;
  }

  ///social
  // --- SOCIAL HANDLERS ---

  Future<void> _onAuthAddFriend(
    AuthAddFriend event,
    Emitter<AuthState> emit,
  ) async {
    if (state is AuthAuthenticated) {
      final currentUser = (state as AuthAuthenticated).user;

      // 1. Update Local State (Optimistic UI)
      final updatedFriends = List<String>.from(currentUser.friends);
      if (!updatedFriends.contains(event.friendId)) {
        updatedFriends.add(event.friendId);
      }

      final updatedUser = currentUser.copyWith(friends: updatedFriends);
      emit(AuthAuthenticated(updatedUser));

      // 2. Persist to Firestore
      try {
        await _userService.addFriend(event.friendId);
      } catch (e) {
        print("Error adding friend: $e");
        // Optional: Revert state here if persistence fails
      }
    }
  }

  Future<void> _onAuthRemoveFriend(
    AuthRemoveFriend event,
    Emitter<AuthState> emit,
  ) async {
    if (state is AuthAuthenticated) {
      final currentUser = (state as AuthAuthenticated).user;

      // 1. Update Local State
      final updatedFriends = List<String>.from(currentUser.friends)
        ..remove(event.friendId);

      final updatedUser = currentUser.copyWith(friends: updatedFriends);
      emit(AuthAuthenticated(updatedUser));

      // 2. Persist to Firestore
      try {
        await _userService.removeFriend(event.friendId);
      } catch (e) {
        print("Error removing friend: $e");
      }
    }
  }

  Future<void> _onAuthFollowUser(
    AuthFollowUser event,
    Emitter<AuthState> emit,
  ) async {
    if (state is AuthAuthenticated) {
      final currentUser = (state as AuthAuthenticated).user;

      // 1. Update Local State
      final updatedFollowing = List<String>.from(currentUser.following);
      if (!updatedFollowing.contains(event.targetUserId)) {
        updatedFollowing.add(event.targetUserId);
      }

      final updatedUser = currentUser.copyWith(following: updatedFollowing);
      emit(AuthAuthenticated(updatedUser));

      // 2. Persist to Firestore
      try {
        await _userService.followUser(event.targetUserId);
      } catch (e) {
        print("Error following user: $e");
      }
    }
  }

  Future<void> _onAuthUnfollowUser(
    AuthUnfollowUser event,
    Emitter<AuthState> emit,
  ) async {
    if (state is AuthAuthenticated) {
      final currentUser = (state as AuthAuthenticated).user;

      // 1. Update Local State
      final updatedFollowing = List<String>.from(currentUser.following)
        ..remove(event.targetUserId);

      final updatedUser = currentUser.copyWith(following: updatedFollowing);
      emit(AuthAuthenticated(updatedUser));

      // 2. Persist to Firestore
      try {
        await _userService.unfollowUser(event.targetUserId);
      } catch (e) {
        print("Error unfollowing user: $e");
      }
    }
  }

  Future<void> _onAuthBlockUser(
    AuthBlockUser event,
    Emitter<AuthState> emit,
  ) async {
    if (state is AuthAuthenticated) {
      final currentUser = (state as AuthAuthenticated).user;

      // 1. Update Local State
      // Add to blocked list
      final updatedBlocked = List<String>.from(currentUser.blockedUsers);
      if (!updatedBlocked.contains(event.targetUserId)) {
        updatedBlocked.add(event.targetUserId);
      }

      // Also remove from friends and following locally to keep UI consistent
      final updatedFriends = List<String>.from(currentUser.friends)
        ..remove(event.targetUserId);
      final updatedFollowing = List<String>.from(currentUser.following)
        ..remove(event.targetUserId);

      final updatedUser = currentUser.copyWith(
        blockedUsers: updatedBlocked,
        friends: updatedFriends,
        following: updatedFollowing,
      );
      emit(AuthAuthenticated(updatedUser));

      // 2. Persist to Firestore
      try {
        await _userService.blockUser(event.targetUserId);
      } catch (e) {
        print("Error blocking user: $e");
      }
    }
  }

  Future<void> _onAuthUnblockUser(
    AuthUnblockUser event,
    Emitter<AuthState> emit,
  ) async {
    if (state is AuthAuthenticated) {
      final currentUser = (state as AuthAuthenticated).user;

      // 1. Update Local State
      final updatedBlocked = List<String>.from(currentUser.blockedUsers)
        ..remove(event.targetUserId);

      final updatedUser = currentUser.copyWith(blockedUsers: updatedBlocked);
      emit(AuthAuthenticated(updatedUser));

      // 2. Persist to Firestore
      try {
        await _userService.unblockUser(event.targetUserId);
      } catch (e) {
        print("Error unblocking user: $e");
      }
    }
  }
}
