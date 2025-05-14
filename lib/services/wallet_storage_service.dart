import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:io';
import 'dart:convert';

class WalletStorageService {
  // Instances
  static final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  // Define all the missing constants
  static const String _deviceIdKey = 'device_id';
  static const String _walletListKey = 'wallet_list';
  static const String _isPinSetKey = 'is_pin_set';
  static const String _mnemonicPrefix = 'mnemonic_';

  // Get or generate a unique device ID
  static Future<String> getDeviceId() async {
    // Try to get stored device ID first
    String? deviceId = await _secureStorage.read(key: _deviceIdKey);

    if (deviceId != null) {
      return deviceId;
    }

    // Generate a new device ID based on device info
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        deviceId = '${androidInfo.id}_${androidInfo.device}';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'ios_${DateTime.now().millisecondsSinceEpoch}';
      } else {
        deviceId = 'unknown_${DateTime.now().millisecondsSinceEpoch}';
      }

      // Store the device ID
      await _secureStorage.write(key: _deviceIdKey, value: deviceId);
      return deviceId;
    } catch (e) {
      // Fallback to timestamp if device info fails
      deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
      await _secureStorage.write(key: _deviceIdKey, value: deviceId);
      return deviceId;
    }
  }

  // Set PIN for additional security
  static Future<void> setPin(String pin) async {
    final pinHash = _hashPin(pin);
    await _secureStorage.write(key: 'pin_hash', value: pinHash);
    await _secureStorage.write(key: _isPinSetKey, value: 'true');
  }

  // Verify PIN
  static Future<bool> verifyPin(String pin) async {
    final storedPinHash = await _secureStorage.read(key: 'pin_hash');
    if (storedPinHash == null) return false;

    final inputPinHash = _hashPin(pin);
    return storedPinHash == inputPinHash;
  }

  // Simple PIN hashing
  static String _hashPin(String pin) {
    var bytes = utf8.encode(pin);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Store a wallet mnemonic securely
  static Future<void> storeWallet({
    required String agentName,
    required String mnemonic,
    required String walletAddress,
    String? pin,
  }) async {
    final deviceId = await getDeviceId();

    // Store the mnemonic with a key that includes agent name and device ID
    final mnemonicKey = '${_mnemonicPrefix}${deviceId}_$agentName';
    await _secureStorage.write(key: mnemonicKey, value: mnemonic);

    // Add this wallet to the list of wallets on this device
    await _addWalletToList(agentName, walletAddress);
  }

  // Retrieve a wallet mnemonic
  static Future<String?> getWalletMnemonic(String agentName, {String? pin}) async {
    final isPinSet = await _secureStorage.read(key: _isPinSetKey);

    // If PIN is set, verify it before retrieving
    if (isPinSet == 'true' && pin != null) {
      final isPinValid = await verifyPin(pin);
      if (!isPinValid) {
        throw Exception('Invalid PIN');
      }
    }

    final deviceId = await getDeviceId();
    final mnemonicKey = '${_mnemonicPrefix}${deviceId}_$agentName';
    return await _secureStorage.read(key: mnemonicKey);
  }

  // Add a wallet to the list of wallets for this device
  static Future<void> _addWalletToList(String agentName, String walletAddress) async {
    // Get the current list
    final prefs = await SharedPreferences.getInstance();
    final walletListJson = prefs.getString(_walletListKey) ?? '[]';
    final walletList = List<Map<String, dynamic>>.from(jsonDecode(walletListJson));

    // Check if wallet already exists in the list
    final existingIndex = walletList.indexWhere((wallet) => wallet['name'] == agentName);

    if (existingIndex >= 0) {
      // Update existing entry
      walletList[existingIndex] = {
        'name': agentName,
        'address': walletAddress,
        'createdAt': walletList[existingIndex]['createdAt'],
        'lastUsed': DateTime.now().toIso8601String(),
      };
    } else {
      // Add new entry
      walletList.add({
        'name': agentName,
        'address': walletAddress,
        'createdAt': DateTime.now().toIso8601String(),
        'lastUsed': DateTime.now().toIso8601String(),
      });
    }

    // Save the updated list
    await prefs.setString(_walletListKey, jsonEncode(walletList));
  }

  // Get all wallets associated with this device
  static Future<List<Map<String, dynamic>>> getWalletList() async {
    final prefs = await SharedPreferences.getInstance();
    final walletListJson = prefs.getString(_walletListKey) ?? '[]';
    return List<Map<String, dynamic>>.from(jsonDecode(walletListJson));
  }

  // Clear all wallet data (for logout or reset)
  static Future<void> clearWalletData() async {
    final deviceId = await getDeviceId();
    final walletList = await getWalletList();

    // Delete all mnemonics for this device
    for (var wallet in walletList) {
      final mnemonicKey = '${_mnemonicPrefix}${deviceId}_${wallet['name']}';
      await _secureStorage.delete(key: mnemonicKey);
    }

    // Clear the wallet list
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_walletListKey);
  }
}