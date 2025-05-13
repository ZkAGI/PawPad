import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:math'; // For generating random addresses
import 'package:solana/solana.dart';

class AgentProvider extends ChangeNotifier {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _agentNameKey = 'agent_name';
  static const String _agentImagePathKey = 'agent_image_path';

  String? _agentName;
  String? _agentImagePath;
  bool _isLoading = false;

  // Map to store agent wallet addresses
  final Map<String, String> _agentWalletAddresses = {};

  // Dummy trending agents data
  final List<Map<String, String>> trendingAgents = [
    {'name': 'AlphaTrader', 'image': 'assets/images/agent1.png'},
    {'name': 'SolanaWhiz', 'image': 'assets/images/agent2.png'},
    {'name': 'MoonShot', 'image': 'assets/images/agent3.png'},
    {'name': 'CryptoSage', 'image': 'assets/images/agent4.png'},
  ];

  String? get agentName => _agentName;
  String? get agentImagePath => _agentImagePath;
  bool get hasAgent => _agentName != null;
  bool get isLoading => _isLoading;

  // Get agent wallet address
  String? getAgentWalletAddress(String? agentName) {
    if (agentName == null) return null;
    return _agentWalletAddresses[agentName];
  }

  Future<double> getAgentBalance(String agentName) async {
    try {
      // Check if this is a real agent or trending agent
      if (_agentWalletAddresses.containsKey(agentName)) {
        // This is your implementation of the getBalance function they provided
        // For now, return a simulated balance since we don't have the actual wallet integration
        return await _getSimulatedBalance(agentName);
      } else {
        // For trending agents, return a random balance
        return 0.0; // These are just examples, so no balance
      }
    } catch (e) {
      debugPrint('Error getting balance: $e');
      return 0.0;
    }
  }

  // Simulated balance function - replace with real implementation when ready
  Future<double> _getSimulatedBalance(String agentName) async {
    // This would be replaced with the real getBalance() function provided
    // For now, return a random balance between 1.0 and 9.99
    await Future.delayed(const Duration(milliseconds: 500)); // Simulate network delay

    // For demo purposes, make balance consistent for the same agent name
    final hash = agentName.hashCode;
    final random = Random(hash);
    return 1.0 + random.nextDouble() * 8.99;

    /*
    // Real implementation would look something like this:
    final wallet = await getOrCreateWallet();
    final client = SolanaClient(
      rpcUrl: Uri.parse(_rpcUrl),
      websocketUrl: Uri.parse(_webSocketUrl),
    );
    try {
      final balance = await client.rpcClient.getBalance(
        wallet.address,
        commitment: Commitment.confirmed,
      );

      // Convert from lamports to SOL
      return balance.value / 1000000000;
    } catch (e) {
      throw Exception('Failed to get balance: ${e.toString()}');
    }
    */
  }

  // Generate a realistic-looking Solana wallet address
  String _generateSolanaAddress() {
    const chars = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
    final random = Random.secure();
    final result = StringBuffer();

    // Solana addresses are base58-encoded and 32-44 characters long
    // Start with the "sol" prefix for easy recognition
    result.write('sol');

    // Add 40 random characters
    for (var i = 0; i < 40; i++) {
      result.write(chars[random.nextInt(chars.length)]);
    }

    return result.toString();
  }

  // Initialize provider
  Future<void> initialize() async {
    try {
      _isLoading = true;
      notifyListeners();

      _agentName = await _secureStorage.read(key: _agentNameKey);
      _agentImagePath = await _secureStorage.read(key: _agentImagePathKey);

      // Load wallet addresses
      await _loadAgentWalletAddresses();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing agent provider: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  // Create a new agent
  Future<void> createAgent({required String name, String? imagePath}) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _secureStorage.write(key: _agentNameKey, value: name);
      _agentName = name;

      if (imagePath != null) {
        await _secureStorage.write(key: _agentImagePathKey, value: imagePath);
        _agentImagePath = imagePath;
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error creating agent: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get or create agent with wallet address
  Future<void> getOrCreateAgent({
    required String name,
    String? imagePath,
    required bool bitcoinBuyAndHold,
    required bool autonomousTrading,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Check if agent already exists
      final existingAgent = await _secureStorage.read(key: _agentNameKey);
      String walletAddress;

      if (existingAgent != null && existingAgent == name) {
        // Agent exists, update it
        await _secureStorage.write(key: _agentNameKey, value: name);
        _agentName = name;

        if (imagePath != null) {
          await _secureStorage.write(key: _agentImagePathKey, value: imagePath);
          _agentImagePath = imagePath;
        }

        // Store agent settings
        await _secureStorage.write(key: 'bitcoin_buy_and_hold', value: bitcoinBuyAndHold.toString());
        await _secureStorage.write(key: 'autonomous_trading', value: autonomousTrading.toString());

        // Get existing wallet address
        final existingAddress = await _secureStorage.read(key: '${name}_wallet_address');
        if (existingAddress != null && existingAddress.isNotEmpty) {
          walletAddress = existingAddress;
        } else {
          // Generate new address if none exists
          walletAddress = _generateSolanaAddress();
          await _secureStorage.write(key: '${name}_wallet_address', value: walletAddress);
        }
      } else {
        // Create new agent
        await _secureStorage.write(key: _agentNameKey, value: name);
        _agentName = name;

        if (imagePath != null) {
          await _secureStorage.write(key: _agentImagePathKey, value: imagePath);
          _agentImagePath = imagePath;
        }

        // Store agent settings
        await _secureStorage.write(key: 'bitcoin_buy_and_hold', value: bitcoinBuyAndHold.toString());
        await _secureStorage.write(key: 'autonomous_trading', value: autonomousTrading.toString());

        // Generate and store wallet address
        walletAddress = _generateSolanaAddress();
        await _secureStorage.write(key: '${name}_wallet_address', value: walletAddress);

        // Debug log the address to verify it's being generated
        debugPrint('Generated wallet address for $name: $walletAddress');
      }

      // Update in-memory wallet address map
      _agentWalletAddresses[name] = walletAddress;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error in getOrCreateAgent: $e');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Load agent wallet addresses
  Future<void> _loadAgentWalletAddresses() async {
    try {
      // Clear existing addresses
      _agentWalletAddresses.clear();

      // Load current agent address if exists
      if (_agentName != null) {
        final address = await _secureStorage.read(key: '${_agentName}_wallet_address');
        if (address != null && address.isNotEmpty) {
          _agentWalletAddresses[_agentName!] = address;
          debugPrint('Loaded wallet address for $_agentName: $address');
        }
      }
    } catch (e) {
      debugPrint('Error loading agent wallet addresses: $e');
    }
  }

  // Update agent name
  Future<void> updateAgentName(String name) async {
    try {
      await _secureStorage.write(key: _agentNameKey, value: name);
      _agentName = name;
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating agent name: $e');
    }
  }

  // Update agent image
  Future<void> updateAgentImage(String imagePath) async {
    try {
      await _secureStorage.write(key: _agentImagePathKey, value: imagePath);
      _agentImagePath = imagePath;
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating agent image: $e');
    }
  }

  // Add this method to your AgentProvider class
  Future<String> getPrivateKey() async {
    try {
      final mnemonic = await _secureStorage.read(key: 'mnemonic');
      if (mnemonic == null) {
        throw Exception('No wallet found');
      }

      // This is a placeholder - in a real app you'd implement the Ed25519HDKeyPair.fromMnemonic
      // For demo purposes, we'll return a dummy private key
      // In production, uncomment and implement the real code:

      // final wallet = await Ed25519HDKeyPair.fromMnemonic(mnemonic);
      // final extracted = await wallet.extract();
      // final privateKeyBytes = extracted.bytes.sublist(0, 32);
      // return privateKeyBytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join();

      // For demo:
      await Future.delayed(const Duration(milliseconds: 500)); // Simulate processing
      return "1a2b3c4d5e6f7g8h9i0j1k2l3m4n5o6p7q8r9s0t1u2v3w4x5y6z7";
    } catch (e) {
      throw Exception('Failed to get private key: ${e.toString()}');
    }
  }
}