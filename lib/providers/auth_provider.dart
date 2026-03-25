import 'package:flutter/material.dart';
import '../models/user.dart' as UserModel;
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  UserModel.User? _user;
  bool _isLoading = false;

  UserModel.User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _init();
  }

  void _init() {
    _authService.authStateChanges.listen((appUser) {
      _user = appUser;
      notifyListeners();
    });
  }

  Future<void> signUp(String email, String password, String displayName) async {
    _isLoading = true;
    notifyListeners();

    try {
      _user = await _authService.signUp(email, password, displayName);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signIn(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      _user = await _authService.signIn(email, password);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _user = null;
    notifyListeners();
  }

  Future<bool> authenticateWithBiometrics() async {
    if (!await _authService.isBiometricAvailable()) {
      return false;
    }

    return await _authService.authenticateWithBiometrics();
  }

  Future<void> resetPassword(String email) async {
    await _authService.resetPassword(email);
  }

  Future<void> updateProfile({String? displayName, String? photoUrl}) async {
    await _authService.updateProfile(displayName: displayName, photoUrl: photoUrl);
    // Refresh user data
    _user = _authService.currentUser;
    notifyListeners();
  }
}