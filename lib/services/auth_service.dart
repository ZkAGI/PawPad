import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;

class AuthService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();

  // Keys for secure storage
  static const String _pinKey = 'pin_code';
  static const String _biometricEnabledKey = 'biometric_enabled';

  // Check if PIN is set
  Future<bool> isPinSet() async {
    final pin = await _secureStorage.read(key: _pinKey);
    return pin != null;
  }

  // Set PIN
  Future<void> setPin(String pin) async {
    await _secureStorage.write(key: _pinKey, value: pin);
  }

  // Verify PIN
  Future<bool> verifyPin(String pin) async {
    final storedPin = await _secureStorage.read(key: _pinKey);
    return pin == storedPin;
  }

  // Check if biometrics are available on the device
  Future<bool> isBiometricsAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();
      return canAuthenticate;
    } catch (e) {
      return false;
    }
  }

  // Get available biometrics
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  // Enable biometric authentication
  Future<void> enableBiometrics(bool enable) async {
    await _secureStorage.write(key: _biometricEnabledKey, value: enable.toString());
  }

  // Check if biometrics are enabled by user
  Future<bool> isBiometricsEnabled() async {
    final value = await _secureStorage.read(key: _biometricEnabledKey);
    return value?.toLowerCase() == 'true';
  }

  // Authenticate with biometrics
  Future<bool> authenticateWithBiometrics() async {
    try {
      final isBiometricsEnabled = await this.isBiometricsEnabled();
      if (!isBiometricsEnabled) {
        return false;
      }

      return await _localAuth.authenticate(
        localizedReason: 'Authenticate to access your wallet',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      return false;
    }
  }

  // Reset authentication (for testing purposes or account reset)
  Future<void> resetAuth() async {
    await _secureStorage.delete(key: _pinKey);
    await _secureStorage.delete(key: _biometricEnabledKey);
  }
}