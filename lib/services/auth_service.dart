import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:linguaflow/models/user_model.dart';
import 'package:linguaflow/utils/logger.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // FIX 1: Use the singleton instance (v7+ requirement)
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  // ---------------------------------------------------------------------------
  // GET CURRENT USER
  // ---------------------------------------------------------------------------
  Future<UserModel?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return null;
      return UserModel.fromMap(doc.data()!, doc.id);
    } catch (e) {
      printLog("Error getting user: $e");
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // EMAIL SIGN IN
  // ---------------------------------------------------------------------------
  Future<UserModel> signIn(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final doc = await _firestore
        .collection('users')
        .doc(credential.user!.uid)
        .get();

    if (!doc.exists) {
      throw Exception("User record not found in database.");
    }

    return UserModel.fromMap(doc.data()!, doc.id);
  }

  // ---------------------------------------------------------------------------
  // GOOGLE SIGN IN (HYBRID FIX FOR v7+)
  // ---------------------------------------------------------------------------
  Future<UserModel?> signInWithGoogle() async {
    try {
      UserCredential? userCredential;

      if (kIsWeb) {
        // ===============================================
        // WEB: Use Firebase Auth Popup
        // ===============================================

        // Use Firebase SDK directly to avoid "UnimplementedError"
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');

        userCredential = await _auth.signInWithPopup(googleProvider);
      } else {
        // ===============================================
        // MOBILE: Use google_sign_in v7+ Plugin
        // ===============================================

        // FIX 2: Initialize before use (v7+ requirement)
        // It is safe to call this even if already initialized.
        await _googleSignIn.initialize();

        // FIX 3: Use authenticate() instead of signIn()
        final GoogleSignInAccount? googleUser = await _googleSignIn
            .authenticate();

        if (googleUser == null) {
          return null;
        }

        // Get Tokens
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        // FIX 4: Pass null for accessToken
        // v7 removed .accessToken from the auth object.
        // Firebase only needs idToken for identity verification.
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: null,
          idToken: googleAuth.idToken,
        );

        // Sign In
        userCredential = await _auth.signInWithCredential(credential);
      }

      // ===============================================
      // COMMON: Handle User in Firestore
      // ===============================================
      final User? firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        final docRef = _firestore.collection('users').doc(firebaseUser.uid);
        final doc = await docRef.get();

        if (doc.exists) {
          return UserModel.fromMap(doc.data()!, doc.id);
        } else {
          final newUser = UserModel(
            id: firebaseUser.uid,
            email: firebaseUser.email ?? '',
            displayName: firebaseUser.displayName ?? 'New User',
            photoUrl: firebaseUser.photoURL,
            nativeLanguage: 'en',
            currentLanguage: 'es',
            targetLanguages: ['es'],
            createdAt: DateTime.now(),
            xp: 0,
            streakDays: 1,
            lastLoginDate: DateTime.now(),
          );

          await docRef.set(newUser.toMap());
          return newUser;
        }
      }
    } catch (e, stack) {
      String msg = e.toString();
      if (msg.contains("popup_closed_by_user")) {
        msg = "Login cancelled.";
      }
      throw Exception(msg);
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // EMAIL SIGN UP
  // ---------------------------------------------------------------------------
  Future<UserModel> signUp(
    String email,
    String password,
    String displayName,
  ) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = UserModel(
      id: credential.user!.uid,
      email: email,
      displayName: displayName,
      createdAt: DateTime.now(),
      xp: 0,
      streakDays: 1,
      nativeLanguage: 'en',
      currentLanguage: 'es',
      targetLanguages: ['es'],
      lastLoginDate: DateTime.now(),
    );

    await _firestore.collection('users').doc(user.id).set(user.toMap());
    return user;
  }

  // ---------------------------------------------------------------------------
  // SIGN OUT
  // ---------------------------------------------------------------------------
  Future<void> signOut() async {
    if (!kIsWeb) {
      try {
        await _googleSignIn.signOut();
      } catch (e) {}
    }
    await _auth.signOut();
  }
}
