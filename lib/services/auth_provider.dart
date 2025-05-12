import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  bool _isAuthenticated = false;
  bool _isLoading = true;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    final isPinSet = await _authService.isPinSet();
    _isAuthenticated = false;
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> isPinSet() async {
    return await _authService.isPinSet();
  }

  Future<void> setPin(String pin) async {
    await _authService.setPin(pin);
    _isAuthenticated = true;
    notifyListeners();
  }

  Future<bool> verifyPin(String pin) async {
    final isValid = await _authService.verifyPin(pin);
    if (isValid) {
      _isAuthenticated = true;
      notifyListeners();
    }
    return isValid;
  }

  Future<bool> isBiometricsAvailable() async {
    return await _authService.isBiometricsAvailable();
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    return await _authService.getAvailableBiometrics();
  }

  Future<void> enableBiometrics(bool enable) async {
    await _authService.enableBiometrics(enable);
    notifyListeners();
  }

  Future<bool> isBiometricsEnabled() async {
    return await _authService.isBiometricsEnabled();
  }

  Future<bool> authenticateWithBiometrics() async {
    final success = await _authService.authenticateWithBiometrics();
    if (success) {
      _isAuthenticated = true;
      notifyListeners();
    }
    return success;
  }

  void signOut() {
    _isAuthenticated = false;
    notifyListeners();
  }

  Future<void> resetAuth() async {
    await _authService.resetAuth();
    _isAuthenticated = false;
    notifyListeners();
  }
}