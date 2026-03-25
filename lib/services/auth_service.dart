import 'package:firebase_auth/firebase_auth.dart';
import 'package:local_auth/local_auth.dart';
import '../models/user.dart' as UserModel;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LocalAuthentication _localAuth = LocalAuthentication();

  // Stream of auth state changes
  Stream<UserModel.User?> get authStateChanges => _auth.authStateChanges().map((firebaseUser) => firebaseUser != null ? UserModel.User.fromFirebase(firebaseUser) : null);

  // Current user
  UserModel.User? get currentUser {
    final firebaseUser = _auth.currentUser;
    return firebaseUser != null ? UserModel.User.fromFirebase(firebaseUser) : null;
  }

  // Sign up with email and password
  Future<UserModel.User?> signUp(String email, String password, String displayName) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
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
    try {
      final result = await _auth.signInWithEmailAndPassword(
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
    try {
      await _auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
      rethrow;
    }
  }

  // Check if biometric authentication is available
  Future<bool> isBiometricAvailable() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      print('Error checking biometrics: $e');
      return false;
    }
  }

  // Authenticate with biometrics
  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _localAuth.authenticate(
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
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      print('Error getting available biometrics: $e');
      return [];
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      print('Error resetting password: $e');
      rethrow;
    }
  }

  // Update user profile
  Future<void> updateProfile({String? displayName, String? photoUrl}) async {
    try {
      if (displayName != null) {
        await _auth.currentUser?.updateDisplayName(displayName);
      }
      if (photoUrl != null) {
        await _auth.currentUser?.updatePhotoURL(photoUrl);
      }
    } catch (e) {
      print('Error updating profile: $e');
      rethrow;
    }
  }

  // Delete account
  Future<void> deleteAccount() async {
    try {
      await _auth.currentUser?.delete();
    } catch (e) {
      print('Error deleting account: $e');
      rethrow;
    }
  }

  // Check if user is authenticated
  bool get isAuthenticated => _auth.currentUser != null;
}