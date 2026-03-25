import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import '../models/user.dart' as UserModel;

class AuthService {
  FirebaseAuth? get _authOrNull {
    if (Firebase.apps.isEmpty) {
      return null;
    }
    return FirebaseAuth.instance;
  }

  LocalAuthentication? get _localAuthOrNull {
    if (kIsWeb) {
      return null;
    }
    return LocalAuthentication();
  }

  // Stream of auth state changes
  Stream<UserModel.User?> get authStateChanges {
    final auth = _authOrNull;
    if (auth == null) {
      return Stream.value(null);
    }

    return auth.authStateChanges().map(
      (firebaseUser) =>
          firebaseUser != null ? UserModel.User.fromFirebase(firebaseUser) : null,
    );
  }

  // Current user
  UserModel.User? get currentUser {
    final firebaseUser = _authOrNull?.currentUser;
    return firebaseUser != null ? UserModel.User.fromFirebase(firebaseUser) : null;
  }

  // Sign up with email and password
  Future<UserModel.User?> signUp(String email, String password, String displayName) async {
    final auth = _authOrNull;
    if (auth == null) {
      throw StateError('Firebase Auth is not configured for this platform.');
    }

    try {
      final result = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name
      await result.user?.updateDisplayName(displayName);

      return UserModel.User.fromFirebase(result.user!);
    } catch (e) {
      print('Error signing up: $e');
      rethrow;
    }
  }

  // Sign in with email and password
  Future<UserModel.User?> signIn(String email, String password) async {
    final auth = _authOrNull;
    if (auth == null) {
      throw StateError('Firebase Auth is not configured for this platform.');
    }

    try {
      final result = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      return UserModel.User.fromFirebase(result.user!);
    } catch (e) {
      print('Error signing in: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    final auth = _authOrNull;
    if (auth == null) {
      return;
    }

    try {
      await auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
      rethrow;
    }
  }

  // Check if biometric authentication is available
  Future<bool> isBiometricAvailable() async {
    final localAuth = _localAuthOrNull;
    if (localAuth == null) {
      return false;
    }

    try {
      return await localAuth.canCheckBiometrics;
    } catch (e) {
      print('Error checking biometrics: $e');
      return false;
    }
  }

  // Authenticate with biometrics
  Future<bool> authenticateWithBiometrics() async {
    final localAuth = _localAuthOrNull;
    if (localAuth == null) {
      return false;
    }

    try {
      return await localAuth.authenticate(
        localizedReason: 'Authenticate to access ReVolve',
        options: const AuthenticationOptions(
          biometricOnly: true,
          useErrorDialogs: true,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      print('Error authenticating with biometrics: $e');
      return false;
    }
  }

  // Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    final localAuth = _localAuthOrNull;
    if (localAuth == null) {
      return [];
    }

    try {
      return await localAuth.getAvailableBiometrics();
    } catch (e) {
      print('Error getting available biometrics: $e');
      return [];
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    final auth = _authOrNull;
    if (auth == null) {
      throw StateError('Firebase Auth is not configured for this platform.');
    }

    try {
      await auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      print('Error resetting password: $e');
      rethrow;
    }
  }

  // Update user profile
  Future<void> updateProfile({String? displayName, String? photoUrl}) async {
    final auth = _authOrNull;
    if (auth == null) {
      throw StateError('Firebase Auth is not configured for this platform.');
    }

    try {
      if (displayName != null) {
        await auth.currentUser?.updateDisplayName(displayName);
      }
      if (photoUrl != null) {
        await auth.currentUser?.updatePhotoURL(photoUrl);
      }
    } catch (e) {
      print('Error updating profile: $e');
      rethrow;
    }
  }

  // Delete account
  Future<void> deleteAccount() async {
    final auth = _authOrNull;
    if (auth == null) {
      return;
    }

    try {
      await auth.currentUser?.delete();
    } catch (e) {
      print('Error deleting account: $e');
      rethrow;
    }
  }

  // Check if user is authenticated
  bool get isAuthenticated => _authOrNull?.currentUser != null;
}
