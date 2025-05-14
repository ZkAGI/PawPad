// import 'package:flutter/material.dart';
// import 'package:local_auth/local_auth.dart';
// import '../screens/home_screen.dart';
// import 'auth_service.dart';
// import 'package:flutter_secure_storage/flutter_secure_storage.dart';
//
// class AuthProvider extends ChangeNotifier {
//   final AuthService _authService = AuthService();
//   final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
//   bool _isAuthenticated = false;
//   bool _isLoading = true;
//
//   bool get isAuthenticated => _isAuthenticated;
//   bool get isLoading => _isLoading;
//
//   AuthProvider() {
//     _checkAuthStatus();
//   }
//
//   Future<void> savePinAndNavigate(String pin, BuildContext context) async {
//     try {
//       // Save PIN securely
//       await _secureStorage.write(key: 'user_pin', value: pin);
//
//       _isAuthenticated = true;
//       notifyListeners();
//
//       // Add a slight delay before navigation to ensure storage completes
//       await Future.delayed(const Duration(milliseconds: 300));
//
//       // Use a more basic navigation approach to avoid rendering issues
//       if (context.mounted) {
//         // Replace the current screen instead of pushing a new one
//         Navigator.of(context).pushReplacement(
//           MaterialPageRoute(builder: (context) => const HomeScreen()),
//         );
//       }
//     } catch (e) {
//       print('Error saving PIN: $e');
//       // Show error message to user
//     }
//   }
//
//   Future<void> _checkAuthStatus() async {
//     _isLoading = true;
//     notifyListeners();
//
//     final isPinSet = await _authService.isPinSet();
//     _isAuthenticated = false;
//     _isLoading = false;
//     notifyListeners();
//   }
//
//   Future<bool> isPinSet() async {
//     return await _authService.isPinSet();
//   }
//
//   Future<void> setPin(String pin) async {
//     await _authService.setPin(pin);
//     _isAuthenticated = true;
//     notifyListeners();
//   }
//
//   Future<bool> verifyPin(String pin) async {
//     final isValid = await _authService.verifyPin(pin);
//     if (isValid) {
//       _isAuthenticated = true;
//       notifyListeners();
//     }
//     return isValid;
//   }
//
//   Future<bool> isBiometricsAvailable() async {
//     return await _authService.isBiometricsAvailable();
//   }
//
//   Future<List<BiometricType>> getAvailableBiometrics() async {
//     return await _authService.getAvailableBiometrics();
//   }
//
//   Future<void> enableBiometrics(bool enable) async {
//     await _authService.enableBiometrics(enable);
//     notifyListeners();
//   }
//
//   Future<bool> isBiometricsEnabled() async {
//     return await _authService.isBiometricsEnabled();
//   }
//
//   Future<bool> authenticateWithBiometrics() async {
//     final success = await _authService.authenticateWithBiometrics();
//     if (success) {
//       _isAuthenticated = true;
//       notifyListeners();
//     }
//     return success;
//   }
//
//   void signOut() {
//     _isAuthenticated = false;
//     notifyListeners();
//   }
//
//   Future<void> resetAuth() async {
//     await _authService.resetAuth();
//     _isAuthenticated = false;
//     notifyListeners();
//   }
// }

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/home_screen.dart';
import 'auth_service.dart';
import 'wallet_storage_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool _isAuthenticated = false;
  bool _isLoading = true;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _checkAuthStatus();
  }

  Future<void> savePinAndNavigate(String pin, BuildContext context) async {
    try {
      // Save PIN securely using both the existing method and WalletStorageService
      await _secureStorage.write(key: 'user_pin', value: pin);
      await WalletStorageService.setPin(pin); // Add this for wallet security

      _isAuthenticated = true;
      notifyListeners();

      // Add a slight delay before navigation to ensure storage completes
      await Future.delayed(const Duration(milliseconds: 300));

      // Use a more basic navigation approach to avoid rendering issues
      if (context.mounted) {
        // Replace the current screen instead of pushing a new one
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      print('Error saving PIN: $e');
      // Show error message to user
    }
  }

  Future<void> _checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    // Check if PIN is set in either of the storage mechanisms
    final isPinSet = await this.isPinSet();
    _isAuthenticated = false;
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> isPinSet() async {
    // Check both methods to ensure backward compatibility
    final isAuthServicePinSet = await _authService.isPinSet();

    // Check if WalletStorageService has a pin set
    final isPinHashSet = await _secureStorage.read(key: 'pin_hash') != null;

    return isAuthServicePinSet || isPinHashSet;
  }

  Future<void> setPin(String pin) async {
    // Set PIN in both storage mechanisms
    await _authService.setPin(pin);
    await WalletStorageService.setPin(pin);
    _isAuthenticated = true;
    notifyListeners();
  }

  Future<bool> verifyPin(String pin) async {
    // Try verifying with the auth service first
    var isValid = await _authService.verifyPin(pin);

    // If not valid with auth service, try with WalletStorageService
    if (!isValid) {
      isValid = await WalletStorageService.verifyPin(pin);
    }

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

    // Also save the biometrics preference for wallet access
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometrics_enabled', enable);

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

    // Also clear wallet data when resetting authentication
    await WalletStorageService.clearWalletData();

    _isAuthenticated = false;
    notifyListeners();
  }

  // Add this method to get the list of stored wallets
  Future<List<Map<String, dynamic>>> getStoredWallets() async {
    return await WalletStorageService.getWalletList();
  }
}