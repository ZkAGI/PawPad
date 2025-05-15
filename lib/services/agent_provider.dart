import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:solana/solana.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../services/solana_swap_service.dart';

import 'package:solana_hackathon_2025/services/wallet_storage_service.dart'; // For generating random data if needed


class AgentProvider extends ChangeNotifier {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  //final SolanaSwapService _solanaSwapService = SolanaSwapService();

  // Solana connection parameters
  final String _rpcUrl = 'https://api.mainnet-beta.solana.com';
  final String _webSocketUrl = 'wss://api.mainnet-beta.solana.com';

  static const String _agentNameKey = 'agent_name';
  static const String _agentImagePathKey = 'agent_image_path';

  String? _agentName;
  String? _agentImagePath;
  bool _isLoading = false;

  // Map to store agent wallet addresses
  final Map<String, String> _agentWalletAddresses = {};

  AgentProvider() {
    // Initialize the JS service
    //_solanaSwapService.initialize();
  }


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

  // Get or create wallet using real Solana implementation
  Future<Ed25519HDKeyPair> getOrCreateWallet() async {
    final stored = await _secureStorage.read(key: 'mnemonic');
    if (stored != null) {
      return await Ed25519HDKeyPair.fromMnemonic(stored);
    }

    final mnemonic = bip39.generateMnemonic();
    final wallet = await Ed25519HDKeyPair.fromMnemonic(mnemonic);

    await _secureStorage.write(key: 'mnemonic', value: mnemonic);
    return wallet;
  }

  // Get private key implementation
  Future<String> getPrivateKey() async {
    final mnemonic = await _secureStorage.read(key: 'mnemonic');
    if (mnemonic == null) {
      throw Exception('No wallet found');
    }

    final wallet = await Ed25519HDKeyPair.fromMnemonic(mnemonic);
    final extracted = await wallet.extract();
    final privateKeyBytes = extracted.bytes.sublist(0, 32);
    return privateKeyBytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
  }

  // Get real wallet balance
  Future<double> getAgentBalance(String agentName) async {
    try {
      // Check if this is a real agent or trending agent
      if (_agentWalletAddresses.containsKey(agentName)) {
        // Get the wallet address for THIS SPECIFIC AGENT
        final walletAddress = _agentWalletAddresses[agentName];
        if (walletAddress == null) {
          debugPrint('No wallet address found for agent: $agentName');
          return 0.0;
        }

        // Create a client - use mainnet instead of devnet!
        final client = SolanaClient(
          rpcUrl: Uri.parse('https://api.mainnet-beta.solana.com'),
          websocketUrl: Uri.parse('wss://api.mainnet-beta.solana.com'),
        );

        // Get balance for THIS SPECIFIC AGENT's wallet
        final balance = await client.rpcClient.getBalance(
          walletAddress,  // Use the string address directly
          commitment: Commitment.confirmed,
        );

        // Convert to SOL and log it
        final solBalance = balance.value / 1000000000;
        debugPrint('Balance for $agentName: $solBalance SOL');

        // Return SOL balance or convert to USD if needed
        return solBalance;
      } else {
        // For trending agents, return a fixed balance of 0
        return 0.0;
      }
    } catch (e) {
      debugPrint('Error getting balance for agent $agentName: $e');
      return 0.0;
    }
  }

  Future<double> getBalance() async {
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
      double solBalance = balance.value / 1000000000;
      debugPrint('Raw balance in lamports: ${balance.value}');
      debugPrint('Converted balance in SOL: $solBalance');
      return solBalance;
    } catch (e) {
      debugPrint('Error getting balance: $e');
      throw Exception('Failed to get balance: ${e.toString()}');
    }
  }

  Future<void> initialize() async {
    try {
      _isLoading = true;
      notifyListeners();

      // Get stored agent name and image path
      _agentName = await _secureStorage.read(key: _agentNameKey);
      _agentImagePath = await _secureStorage.read(key: _agentImagePathKey);

      // Get all wallets from storage service
      final storedWallets = await WalletStorageService.getWalletList();

      // Populate the wallet addresses map
      for (var wallet in storedWallets) {
        _agentWalletAddresses[wallet['name']] = wallet['address'];
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing agent provider: $e');
      _isLoading = false;
      notifyListeners();
    }
  }
  // Get or create agent with real wallet address
  // Get or create agent with real wallet address
  Future<void> getOrCreateAgent({
    required String name,
    String? imagePath,
    required bool bitcoinBuyAndHold,
    required bool autonomousTrading,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Store agent settings
      await _secureStorage.write(key: _agentNameKey, value: name);
      _agentName = name;

      if (imagePath != null) {
        await _secureStorage.write(key: _agentImagePathKey, value: imagePath);
        _agentImagePath = imagePath;
      }

      // Store agent preferences
      await _secureStorage.write(key: 'bitcoin_buy_and_hold', value: bitcoinBuyAndHold.toString());
      await _secureStorage.write(key: 'autonomous_trading', value: autonomousTrading.toString());

      // Get or create a real wallet and store its address
      final wallet = await getOrCreateWallet();
      final walletAddress = wallet.address;

      // Store the wallet address
      await _secureStorage.write(key: '${name}_wallet_address', value: walletAddress);

      // Update in-memory wallet address map
      _agentWalletAddresses[name] = walletAddress;

      // IMPORTANT ADDITION - Store the wallet in WalletStorageService
      final mnemonic = await _secureStorage.read(key: 'mnemonic');
      if (mnemonic != null) {
        await WalletStorageService.storeWallet(
          agentName: name,
          mnemonic: mnemonic,
          walletAddress: walletAddress,
        );
        debugPrint('Stored wallet in WalletStorageService for $name: $walletAddress');
      }

      debugPrint('Created real wallet address for $name: $walletAddress');

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
        } else {
          // If no stored address but agent exists, create a wallet and store its address
          final wallet = await getOrCreateWallet();
          final walletAddress = wallet.address;

          await _secureStorage.write(key: '${_agentName}_wallet_address', value: walletAddress);
          _agentWalletAddresses[_agentName!] = walletAddress;

          debugPrint('Created new wallet address for $_agentName: $walletAddress');
        }
      }
    } catch (e) {
      debugPrint('Error loading agent wallet addresses: $e');
    }
  }

  // Transfer SOL implementation
  Future<String> transferSol({
    required String destination,
    required double amount,
  }) async {
    final wallet = await getOrCreateWallet();
    final client = SolanaClient(
      rpcUrl: Uri.parse(_rpcUrl),
      websocketUrl: Uri.parse(_webSocketUrl),
    );
    final lamports = (amount * 1000000000).toInt();
    final recipient = Ed25519HDPublicKey.fromBase58(destination);
    try {
      // Create the transfer instruction
      final instruction = SystemInstruction.transfer(
        fundingAccount: wallet.publicKey,
        recipientAccount: recipient,
        lamports: lamports,
      );
      // Use the higher-level API to send a transaction
      final signature = await client.sendAndConfirmTransaction(
        message: Message.only(instruction),
        signers: [wallet],
        commitment: Commitment.confirmed,
      );
      return signature;
    } catch (e) {
      print('Error: $e');
      throw Exception('Transfer failed: $e');
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

  Future<void> loadStoredWallets() async {
    try {
      // Get the wallet list from WalletStorageService
      final walletList = await WalletStorageService.getWalletList();

      // Process each stored wallet
      for (var wallet in walletList) {
        // Add to in-memory map
        final name = wallet['name'] as String;
        final address = wallet['address'] as String;
        _agentWalletAddresses[name] = address;

        // If we don't have an agent selected yet, use the first one
        if (_agentName == null) {
          _agentName = name;
          await _secureStorage.write(key: _agentNameKey, value: name);
        }
      }

      // Notify listeners if any wallets were loaded
      if (walletList.isNotEmpty) {
        notifyListeners();
      }

      debugPrint('Loaded ${walletList.length} wallets from storage');
    } catch (e) {
      debugPrint('Error loading wallets from storage: $e');
    }
  }

  // Add to your AgentProvider class
  Future<void> switchToAgent(String agentName) async {
    try {
      debugPrint('Switching to agent: $agentName');

      // First check if this is a valid agent
      if (!_agentWalletAddresses.containsKey(agentName)) {
        throw Exception('Agent not found: $agentName');
      }

      // Set the new agent as current
      _agentName = agentName;
      await _secureStorage.write(key: _agentNameKey, value: agentName);

      // Log the wallet address we're switching to
      final address = _agentWalletAddresses[agentName];
      debugPrint('Switched to agent: $agentName with wallet: $address');

      // Notify listeners of the change
      notifyListeners();
    } catch (e) {
      debugPrint('Error switching agent: $e');
      throw Exception('Failed to switch agent: $e');
    }
  }

  // Add this method to AgentProvider class
  Future<Map<String, dynamic>> checkDailyTradingSignal() async {
    if (_agentName == null) {
      return {'checked': false, 'message': 'No agent selected'};
    }

    try {
      // Check if we should get a signal today using your existing method
      final shouldCheck = await shouldCheckTradingSignalToday();

      if (!shouldCheck) {
        return {'checked': false, 'message': 'Already checked trading signal today'};
      }

      // Check if Bitcoin Buy & Hold is enabled for the current agent
      final bitcoinBuyAndHold = await _secureStorage.read(key: 'bitcoin_buy_and_hold') == 'true';

      if (!bitcoinBuyAndHold) {
        return {'checked': false, 'message': 'Bitcoin Buy & Hold not enabled for this agent'};
      }

      // Get the balance using your existing method
      final balance = await getBalance();

      // Get the trading signal
      final response = await http.get(Uri.parse('http://103.231.86.182:3020/predict'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final signal = data['signal'] ?? 'hold';

        // Update the last signal date
        await _secureStorage.write(key: 'last_signal_date', value: DateTime.now().toIso8601String());

        // Handle the buy signal
        if (signal.toLowerCase() == 'buy') {
          if (balance <= 0) {
            return {
              'checked': true,
              'signal': 'buy',
              'action': 'none',
              'message': 'Buy signal received but insufficient balance. Please load SOL to enable transactions.'
            };
          } else {
            // Execute the swap - BTC token address on Solana
            final btcMint = '9n4nbM75f5Ui33ZbPYXn59EwSgE8CGsHtAeTH5YFeJ9E';
                //'qfnqNqs3nCAHjnyCgLRDbBtq4p2MtHZxw8YjSyYhPoL';

            // Use our new method to handle the buy signal
            final swapResult = await handleBuySignal(btcMint);

            if (swapResult['success'] == true) {
              return {
                'checked': true,
                'signal': 'buy',
                'action': 'buy',
                'txSignature': swapResult['signature'],
                'message': 'BUY signal executed: Swapped SOL for BTC'
              };
            } else {
              return {
                'checked': true,
                'signal': 'buy',
                'action': 'none',
                'error': swapResult['error'],
                'message': 'BUY signal received but swap failed: ${swapResult['error']}'
              };
            }
          }
        } else {
          // Hold signal
          return {
            'checked': true,
            'signal': signal.toLowerCase(),
            'action': 'none',
            'message': 'Trading signal received: ${signal.toUpperCase()}'
          };
        }
      } else {
        return {
          'checked': true,
          'error': 'Failed to get prediction signal',
          'message': 'Error checking trading signal'
        };
      }
    } catch (e) {
      debugPrint('Error checking daily trading signal: $e');
      return {
        'checked': true,
        'signal': 'error',
        'action': 'none',
        'error': e.toString(),
        'message': 'Error checking trading signal: $e'
      };
    }
  }

  Future<bool> shouldCheckTradingSignalToday() async {
    try {
      // Get the last signal date
      final lastSignalDateStr = await _secureStorage.read(key: 'last_signal_date');

      if (lastSignalDateStr == null) {
        // No previous signal, should check
        return true;
      }

      final lastSignalDate = DateTime.parse(lastSignalDateStr);
      final now = DateTime.now();

      // Check if it's a new day since the last signal
      final isSameDay = lastSignalDate.year == now.year &&
          lastSignalDate.month == now.month &&
          lastSignalDate.day == now.day;

      // Only check for a new signal if it's a different day
      return !isSameDay;
    } catch (e) {
      debugPrint('Error checking if should request trading signal: $e');
      // Default to true if there's an error
      return true;
    }
  }

  Future<Map<String, dynamic>> handleBuySignal(String tokenMint) async {
    if (_agentName == null) {
      return {
        'success': false,
        'error': 'No agent selected',
      };
    }

    try {
      debugPrint("Handling buy signal for token: $tokenMint");

      // Get the wallet
      final wallet = await getOrCreateWallet();
      final publicKey = wallet.address;

      // Get the balance
      final balance = await getBalance();
      debugPrint("Current balance: $balance SOL");

      if (balance <= 0.005) {
        return {
          'success': false,
          'error': 'Insufficient balance. Minimum 0.005 SOL required.',
        };
      }

      // Calculate swap amount (5% of balance or max 0.0005 SOL)
      final swapAmount = min(balance * 0.05, 0.0005);
      final swapAmountLamports = (swapAmount * 1e9).toInt();
      debugPrint("Swap amount: $swapAmount SOL ($swapAmountLamports lamports)");

      // Step 1: Get a quote from Jupiter API
      final quoteUrl = Uri.parse('https://quote-api.jup.ag/v6/quote');
      final quoteParams = {
        'inputMint': 'So11111111111111111111111111111111111111112', // SOL
        'outputMint': tokenMint,
        'amount': swapAmountLamports.toString(),
        'slippageBps': '50', // 0.5% slippage
      };

      final quoteUri = quoteUrl.replace(queryParameters: quoteParams);
      debugPrint("Requesting quote from: $quoteUri");

      final quoteResponse = await http.get(quoteUri);

      if (quoteResponse.statusCode != 200) {
        debugPrint("Error getting quote: ${quoteResponse.body}");
        return {
          'success': false,
          'error': 'Failed to get quote from Jupiter: ${quoteResponse.body}',
        };
      }

      final quoteData = jsonDecode(quoteResponse.body);
      debugPrint("Quote received: ${quoteData['outAmount']} output tokens");

      // Step 2: Get a serialized transaction from Jupiter
      final swapUrl = Uri.parse('https://quote-api.jup.ag/v6/swap');
      final swapBody = {
        'quoteResponse': quoteData,
        'userPublicKey': publicKey,
        'wrapAndUnwrapSol': true, // Auto-wrap SOL
      };

      debugPrint("Requesting swap transaction...");
      final swapResponse = await http.post(
        swapUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(swapBody),
      );

      if (swapResponse.statusCode != 200) {
        debugPrint("Error getting swap transaction: ${swapResponse.body}");
        return {
          'success': false,
          'error': 'Failed to get swap transaction from Jupiter: ${swapResponse.body}',
        };
      }

      final swapData = jsonDecode(swapResponse.body);
      final encodedTransaction = swapData['swapTransaction'];
      debugPrint("Received base64 transaction");

      // Step 3: Sign and send the transaction using our utility function
      final txSignature = await signAndSendJupiterSwapTx(
        base64Tx: encodedTransaction,
        wallet: wallet,
      );

      if (txSignature == null) {
        return {
          'success': false,
          'error': 'Failed to sign and send transaction',
        };
      }

      debugPrint("Swap transaction sent with signature: $txSignature");

      // Return success
      return {
        'success': true,
        'signature': txSignature,
        'amount': swapAmount,
        'inputMint': 'SOL',
        'outputMint': tokenMint,
        'outAmount': quoteData['outAmount'],
      };
    } catch (e) {
      debugPrint('Error handling buy signal: $e');
      return {
        'success': false,
        'error': 'Swap failed: $e',
      };
    }
  }
}
