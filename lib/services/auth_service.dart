// ==========================================
// SERVICES
// ==========================================
// File: lib/services/auth_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:linguaflow/models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<UserModel?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return null;

    return UserModel.fromMap(doc.data()!, doc.id);
  }

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

  // --- NEW: Google Sign In Method (Fixed for v7+) ---
  Future<UserModel?> signInWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn.instance;
      
      // 1. Initialize (Required in v7)
      await googleSignIn.initialize();

      // 2. Authenticate the user
      final GoogleSignInAccount googleUser = await googleSignIn.authenticate();
      
      if (googleUser == null) return null; // User cancelled

      // 3. Get ID Token (Authentication)
      // Note: In v7, this is synchronous
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      // 4. Get Access Token (Authorization) - CHANGED IN v7
      // We must explicitly request the token for the 'email' scope.
      // Firebase requires this token to create a credential on some platforms.
      final googleAuthClient = await googleUser.authorizationClient.authorizationForScopes(['email']);

      if (googleAuthClient == null) {
        throw Exception("Could not authorize Google Sign In.");
      }

      // 5. Create Credential using both tokens
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuthClient.accessToken, // Token is here now
        idToken: googleAuth.idToken,
      );

      // 6. Sign in to Firebase
      final UserCredential userCredential = 
          await _auth.signInWithCredential(credential);
      
      final User? firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        // 7. Check/Create User Document
        final doc = await _firestore.collection('users').doc(firebaseUser.uid).get();

        if (doc.exists) {
          return UserModel.fromMap(doc.data()!, doc.id);
        } else {
          final newUser = UserModel(
            id: firebaseUser.uid,
            email: firebaseUser.email ?? '',
            displayName: firebaseUser.displayName ?? 'New User',
            createdAt: DateTime.now(),
          );

          await _firestore.collection('users').doc(newUser.id).set(newUser.toMap());

          return newUser;
        }
      }
    } catch (e) {
      print("Google Sign In Error: $e");
      throw Exception("Google Sign In failed: $e");
    }
    return null;
  }

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
    );

    await _firestore.collection('users').doc(user.id).set(user.toMap());

    return user;
  }

  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }
}
