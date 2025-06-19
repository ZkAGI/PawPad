import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:solana/solana.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../services/solana_swap_service.dart';
import 'package:web3dart/web3dart.dart';
import 'package:bip32/bip32.dart' as bip32;

import 'package:solana_hackathon_2025/services/wallet_storage_service.dart'; // For generating random data if needed


class AgentProvider extends ChangeNotifier {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  //final SolanaSwapService _solanaSwapService = SolanaSwapService();

  // Solana connection parameters
  final String _rpcUrl = 'https://api.mainnet-beta.solana.com';
  final String _webSocketUrl = 'wss://api.mainnet-beta.solana.com';
  final String _ethRpcUrl = 'https://1rpc.io/base';

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


  static const _mnemonicKey = 'mnemonic';

  /// 1. Solana: derive or read mnemonic and return Ed25519HDKeyPair
  Future<Ed25519HDKeyPair> getOrCreateSolanaWallet() async {
    // Try to read an existing mnemonic
    String? mnemonic = await _secureStorage.read(key: _mnemonicKey);

    // If none, generate and persist one
    if (mnemonic == null) {
      mnemonic = bip39.generateMnemonic();
      await _secureStorage.write(key: _mnemonicKey, value: mnemonic);
    }

    // Derive the Solana keypair
    return await Ed25519HDKeyPair.fromMnemonic(mnemonic);
  }

  /// 2. EVM: derive EthPrivateKey from the same mnemonic using BIP-44 path m/44'/60'/0'/0/0
  Future<EthPrivateKey> getOrCreateEvmWallet() async {
    // Ensure we have a mnemonic
    String? mnemonic = await _secureStorage.read(key: _mnemonicKey);
    if (mnemonic == null) {
      // If someone called this before solana, make sure to generate & store
      mnemonic = bip39.generateMnemonic();
      await _secureStorage.write(key: _mnemonicKey, value: mnemonic);
    }

    // Convert mnemonic to seed
    final seed = bip39.mnemonicToSeed(mnemonic);

    // Create a BIP32 root from the seed
    final root = bip32.BIP32.fromSeed(seed);

    // Derive the Ethereum account at m/44'/60'/0'/0/0
    final ethNode = root
        .derivePath("m/44'/60'/0'/0/0");

    // Private key bytes
    final Uint8List privKey = ethNode.privateKey!;

    // Wrap it in web3dart's EthPrivateKey
    return EthPrivateKey(privKey);
  }

  /// 3. A combined convenience method if you really want both at once
  Future<Map<String, dynamic>> getOrCreateBothWallets() async {
    final solana = await getOrCreateSolanaWallet();
    final evm = await getOrCreateEvmWallet();
    return {
      'solana': solana,
      'evm': evm,
    };
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
          rpcUrl: Uri.parse('https://mainnet.helius-rpc.com/?api-key=daee1b98-f564-4352-b8aa-d41654bc0e02'),
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

  Future<Map<String, double>> getBothBalances() async {
    // 1️⃣ Derive both wallets
    final wallets = await getOrCreateBothWallets();
    final Ed25519HDKeyPair solWallet = wallets['solana'];
    final EthPrivateKey    evmWallet = wallets['evm'];

    // 2️⃣ Fetch Solana balance
    final solClient = SolanaClient(
      rpcUrl: Uri.parse(_rpcUrl),
      websocketUrl: Uri.parse(_webSocketUrl),
    );
    final solLamports = (await solClient.rpcClient.getBalance(
      solWallet.address,
      commitment: Commitment.confirmed,
    )).value;
    final double solBalance = solLamports / lamportsPerSol;

    // 3️⃣ Fetch Ethereum balance
    final ethClient = Web3Client(_ethRpcUrl, http.Client());
    final EthereumAddress ethAddress = await evmWallet.extractAddress();
    final etherAmount = await ethClient.getBalance(ethAddress);
    // convert Wei to ETH
    final double ethBalance = etherAmount.getValueInUnit(EtherUnit.ether);

    // 4️⃣ Clean up HTTP client (optional)
    ethClient.dispose();

    return {
      'sol': solBalance,
      'eth': ethBalance,
    };
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

  Future<void> showWalletAddressesAndBalances() async {
    // 1️⃣ Derive both wallets
    final wallets   = await getOrCreateBothWallets();
    final solWallet = wallets['solana'] as Ed25519HDKeyPair;
    final evmWallet = wallets['evm']    as EthPrivateKey;

    // 2️⃣ Fetch balances
    final balances  = await getBothBalances();
    final solBal    = balances['sol']!;
    final ethBal    = balances['eth']!;

    // 3️⃣ Extract Ethereum address
    final ethAddress = await evmWallet.extractAddress();

    // 4️⃣ Print to console
    debugPrint('Solana Wallet  : ${solWallet.address}');
    debugPrint('Solana Balance : $solBal  SOL');
    debugPrint('Ethereum Wallet: ${ethAddress.hex}');
    debugPrint('Ethereum Balance: $ethBal ETH');
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
      // for (var wallet in storedWallets) {
      //   _agentWalletAddresses[wallet['name']] = wallet['address'];
      // }

      for (var w in storedWallets) {
        _agentWalletAddresses[w['name']!] = w['address']!;
      }

      _isLoading = false;
      notifyListeners();
      showWalletAddressesAndBalances();
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
  Future<bool> shouldCheckBitcoinSignalToday() async {
    try {
      // Get the last Bitcoin signal date
      final lastSignalDateStr = await _secureStorage.read(key: 'last_bitcoin_signal_date');

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
      if (!isSameDay) {
        return true;
      }

      // Check if current time is after 3 PM IST and the last check was before 3 PM
      // IST is UTC+5:30
      final utcOffset = const Duration(hours: 5, minutes: 30);
      final nowInIST = now.toUtc().add(utcOffset);
      final lastSignalInIST = lastSignalDate.toUtc().add(utcOffset);

      // If it's after 3 PM IST now and the last signal was before 3 PM IST today
      final isAfter3PMIST = nowInIST.hour >= 15;
      final wasLastCheckBefore3PMIST = lastSignalInIST.hour < 15;

      return isAfter3PMIST && wasLastCheckBefore3PMIST;
    } catch (e) {
      debugPrint('Error checking if should request Bitcoin trading signal: $e');
      // Default to true if there's an error
      return true;
    }
  }

// Add this method for autonomous trading checks every 6 hours
  Future<bool> shouldCheckAutonomousSignal() async {
    try {
      // Get the last autonomous signal date
      final lastSignalDateStr = await _secureStorage.read(key: 'last_autonomous_signal_date');

      if (lastSignalDateStr == null) {
        // No previous signal, should check
        return true;
      }

      final lastSignalDate = DateTime.parse(lastSignalDateStr);
      final now = DateTime.now();

      // Check if 12 hours have passed since the last check
      final hoursSinceLastCheck = now.difference(lastSignalDate).inHours;

      return hoursSinceLastCheck >= 12;
    } catch (e) {
      debugPrint('Error checking if should request autonomous trading signal: $e');
      // Default to true if there's an error
      return true;
    }
  }

  // Add this method for custom strategy checks every 6 hours
  Future<bool> shouldCheckCustomStrategySignal() async {
    try {
      // Get the last custom strategy signal date
      final lastSignalDateStr = await _secureStorage.read(key: 'last_custom_strategy_signal_date');

      if (lastSignalDateStr == null) {
        // No previous signal, should check
        return true;
      }

      final lastSignalDate = DateTime.parse(lastSignalDateStr);
      final now = DateTime.now();

      // Check if 8 hours have passed since the last check
      final hoursSinceLastCheck = now.difference(lastSignalDate).inHours;

      return hoursSinceLastCheck >= 8;
    } catch (e) {
      debugPrint('Error checking if should request custom strategy signal: $e');
      // Default to true if there's an error
      return true;
    }
  }

  // Check Custom Strategy signal
  Future<Map<String, dynamic>> checkCustomStrategySignal(double balance) async {
    try {
      // First, check if agent name exists
      if (_agentName == null) {
        return {
          'type': 'custom_strategy',
          'error': 'No agent selected',
          'message': 'Error checking custom strategy signal: No agent selected'
        };
      }

      // Fetch current custom strategy settings from server
      final response = await http.get(
        Uri.parse('https://zynapse.zkagi.ai/activities/${_agentName}'),
        headers: {
          'api-key': 'zk-123321',
        },
      );

      if (response.statusCode != 200) {
        debugPrint('Error fetching agent activities: ${response.body}');
        return {
          'type': 'custom_strategy',
          'error': 'Failed to fetch agent activities',
          'message': 'Error checking custom strategy signal: Failed to fetch agent data'
        };
      }

      final activityData = jsonDecode(response.body);

      // Extract custom strategy settings
      if (activityData['isCustomStrategy'] == null) {
        debugPrint('No custom strategy settings found for agent: ${_agentName}');
        return {
          'type': 'custom_strategy',
          'error': 'No custom strategy settings',
          'message': 'No custom strategy settings found for this agent'
        };
      }

      final customStrategy = activityData['isCustomStrategy'];
      final symbols = List<String>.from(customStrategy['coins'] ?? []);
      final timeframe = customStrategy['timeframe'] as String?;

      if (symbols.isEmpty || timeframe == null) {
        debugPrint('Invalid custom strategy settings: symbols=$symbols, timeframe=$timeframe');
        return {
          'type': 'custom_strategy',
          'error': 'Invalid custom strategy settings',
          'message': 'Custom strategy settings are incomplete'
        };
      }

      debugPrint('Using custom strategy settings: symbols=$symbols, timeframe=$timeframe');

      // Call the custom strategy API to get signal
      final requestBody = {
        "symbols": symbols,
        "timeframe": timeframe
      };

      final signalResponse = await http.post(
        Uri.parse('http://164.52.202.62:6000/get-signal'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      // Update the last signal date for custom strategy
      final now = DateTime.now();
      await _secureStorage.write(
          key: 'last_custom_strategy_signal_date', value: now.toIso8601String());

      if (signalResponse.statusCode == 200) {
        final signalData = jsonDecode(signalResponse.body);

        // Extract output mint and signal from response
        final outputMint = signalData['Output Mint'] as String?;
        final tradingSymbol = signalData['Symbol'] as String?;
        final signalType = signalData['Signal'] as String?;

        // Process signal if it's a Long signal and we have an output mint
        if (outputMint != null && signalType != null && signalType.contains('Long')) {
          if (balance <= 0.01) {
            return {
              'type': 'custom_strategy',
              'signal': 'long',
              'symbol': tradingSymbol,
              'action': 'none',
              'message': 'Long signal received for $tradingSymbol but insufficient balance. Please load SOL to enable transactions.'
            };
          } else {
            // Execute the swap with the output mint from the signal
            final swapResult = await handleBuySignal(outputMint);

            if (swapResult['success'] == true) {
              // Record transaction in activity log
              await recordTradingActivity('custom_strategy_buy', {
                'ts': now.toIso8601String(),
                'txSignature': swapResult['signature'],
                'amount': swapResult['amount'],
                'symbol': tradingSymbol,
                'outputMint': outputMint,
                'signal': signalType,
                'entryPrice': signalData['Entry Price'],
                'stopLoss': signalData['Stop Loss'],
                'takeProfit': signalData['Take Profit'],
              });

              // Create activity data with strategy-specific information
              final activityData = {
                'ts': now.toIso8601String(),
                'txSignature': swapResult['signature'],
                'amount': swapResult['amount'],
                'symbol': tradingSymbol,
                'outputMint': outputMint,
                'signal': signalType,
                'entryPrice': signalData['Entry Price'],
                'stopLoss': signalData['Stop Loss'],
                'takeProfit': signalData['Take Profit'],
                'action': 'buy',
                'timeframe': timeframe,
              };

              // Record transaction in activity log and send to API
              await recordTradingActivity('custom_strategy_buy', activityData);

              return {
                'type': 'custom_strategy',
                'signal': 'long',
                'action': 'buy',
                'symbol': tradingSymbol,
                'txSignature': swapResult['signature'],
                'message': 'LONG signal executed: Swapped SOL for $tradingSymbol'
              };
            } else {
              return {
                'type': 'custom_strategy',
                'signal': 'long',
                'action': 'none',
                'symbol': tradingSymbol,
                'error': swapResult['error'],
                'message': 'LONG signal received but swap failed: ${swapResult['error']}'
              };
            }
          }
        } else {
          // Not a Long signal or missing output mint
          return {
            'type': 'custom_strategy',
            'signal': signalType?.toLowerCase() ?? 'unknown',
            'symbol': tradingSymbol,
            'action': 'none',
            'message': 'Signal received: ${signalType ?? "Unknown"} for ${tradingSymbol ?? "Unknown"} - No action required'
          };
        }
      } else {
        return {
          'type': 'custom_strategy',
          'error': 'Failed to get custom strategy signal',
          'message': 'Error checking custom strategy signal'
        };
      }
    } catch (e) {
      debugPrint('Error checking custom strategy signal: $e');
      return {
        'type': 'custom_strategy',
        'signal': 'error',
        'action': 'none',
        'error': e.toString(),
        'message': 'Error checking custom strategy signal: $e'
      };
    }
  }

// This replaces the previous checkDailyTradingSignal method
  Future<Map<String, dynamic>> checkTradingSignals() async {
    if (_agentName == null) {
      return {'checked': false, 'message': 'No agent selected'};
    }

    try {
      // Check if Bitcoin Buy & Hold is enabled for the current agent
      final bitcoinBuyAndHold = await _secureStorage.read(key: 'bitcoin_buy_and_hold') == 'true';
      final autonomousTrading = await _secureStorage.read(key: 'autonomous_trading') == 'true';
      final customStrategyEnabled = await _secureStorage.read(key: 'last_custom_strategy_signal_date') != null;

      // Get the balance using your existing method
      final balance = await getBalance();

      Map<String, dynamic> result = {'checked': true, 'signals': []};

      // Check Bitcoin Buy & Hold Signal (once a day at 3 PM IST)
      if (bitcoinBuyAndHold) {
        final shouldCheckBitcoin = await shouldCheckBitcoinSignalToday();

        if (shouldCheckBitcoin) {
          final bitcoinResult = await checkBitcoinBuyAndHoldSignal(balance);
          result['signals'].add(bitcoinResult);

          // If a buy action was performed, add a message
          if (bitcoinResult['action'] == 'buy') {
            result['message'] = 'BTC buy signal executed successfully!';
          } else if (bitcoinResult['signal'] == 'buy' && bitcoinResult['action'] == 'none') {
            result['message'] = 'BTC buy signal received but insufficient balance.';
          }
        }
      }

      // Check Autonomous Trading Signal (every 6 hours)
      if (autonomousTrading) {
        final shouldCheckAutonomous = await shouldCheckAutonomousSignal();

        if (shouldCheckAutonomous) {
          final autonomousResult = await checkAutonomousTradingSignal(balance);
          result['signals'].add(autonomousResult);

          // Add message for autonomous signal if needed
          if (autonomousResult['action'] == 'buy') {
            result['message'] = result['message'] ?? '';
            if (result['message'].isNotEmpty) {
              result['message'] += ' ';
            }
            final symbol = autonomousResult['symbol'] ?? 'token';
            result['message'] += 'Long signal for $symbol executed successfully!';
          } else if (autonomousResult['signal'] == 'long' && autonomousResult['action'] == 'none') {
            result['message'] = result['message'] ?? '';
            if (result['message'].isNotEmpty) {
              result['message'] += ' ';
            }
            result['message'] += 'Long signal received but insufficient balance.';
          }
        }
      }

      if (customStrategyEnabled) {
        final shouldCheckCustom = await shouldCheckCustomStrategySignal();

        if (shouldCheckCustom) {
          final customResult = await checkCustomStrategySignal(balance);
          result['signals'].add(customResult);

          // Add message for custom strategy signal if needed
          if (customResult['action'] == 'buy') {
            result['message'] = result['message'] ?? '';
            if (result['message'].isNotEmpty) {
              result['message'] += ' ';
            }
            final symbol = customResult['symbol'] ?? 'token';
            result['message'] += 'Custom strategy: Long signal for $symbol executed successfully!';
          } else if (customResult['signal'] == 'long' && customResult['action'] == 'none') {
            result['message'] = result['message'] ?? '';
            if (result['message'].isNotEmpty) {
              result['message'] += ' ';
            }
            result['message'] += 'Custom strategy: Long signal received but insufficient balance.';
          }
        }
      }

      // If no signals were checked, return a generic message
      if (result['signals'].isEmpty) {
        result['message'] = 'No signals checked at this time.';
      }

      return result;
    } catch (e) {
      debugPrint('Error checking trading signals: $e');
      return {
        'checked': true,
        'signal': 'error',
        'action': 'none',
        'error': e.toString(),
        'message': 'Error checking trading signals: $e'
      };
    }
  }

// Check Bitcoin Buy & Hold signal
  Future<Map<String, dynamic>> checkBitcoinBuyAndHoldSignal(double balance) async {
    try {
      // Get the trading signal
      final response = await http.get(Uri.parse('http://103.231.86.182:3020/predict'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final signal = data['signal'] ?? 'hold';

        // Update the last signal date for Bitcoin
        final now = DateTime.now();
        await _secureStorage.write(key: 'last_bitcoin_signal_date', value: now.toIso8601String());

        // Handle the buy signal
        if (signal.toLowerCase() == 'buy') {
          if (balance <= 0.01) {
            return {
              'type': 'bitcoin',
              'signal': 'buy',
              'action': 'none',
              'message': 'Buy signal received but insufficient balance. Please load SOL to enable transactions.'
            };
          } else {
            // Execute the swap - BTC token address on Solana
            final btcMint = 'cbbtcf3aa214zXHbiAZQwf4122FBYbraNdFqgw4iMij';

            // Use our method to handle the buy signal
            final swapResult = await handleBuySignal(btcMint);

            if (swapResult['success'] == true) {
              // Record transaction in activity log
              await recordTradingActivity('bitcoin_buy', {
                'ts': now.toIso8601String(),
                'txSignature': swapResult['signature'],
                'amount': swapResult['amount'],
              });

              // Create activity data
              final activityData = {
                'ts': now.toIso8601String(),
                'txSignature': swapResult['signature'],
                'amount': swapResult['amount'],
                'action': 'buy',
                'symbol': 'BTC',
              };

              // Record transaction in activity log and send to API
              await recordTradingActivity('bitcoin_buy', activityData);

              return {
                'type': 'bitcoin',
                'signal': 'buy',
                'action': 'buy',
                'txSignature': swapResult['signature'],
                'message': 'BUY signal executed: Swapped SOL for BTC'
              };
            } else {
              return {
                'type': 'bitcoin',
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
            'type': 'bitcoin',
            'signal': signal.toLowerCase(),
            'action': 'none',
            'message': 'Bitcoin trading signal received: ${signal.toUpperCase()}'
          };
        }
      } else {
        return {
          'type': 'bitcoin',
          'error': 'Failed to get prediction signal',
          'message': 'Error checking Bitcoin trading signal'
        };
      }
    } catch (e) {
      debugPrint('Error checking Bitcoin trading signal: $e');
      return {
        'type': 'bitcoin',
        'signal': 'error',
        'action': 'none',
        'error': e.toString(),
        'message': 'Error checking Bitcoin trading signal: $e'
      };
    }
  }

// Check Autonomous Trading signal
  Future<Map<String, dynamic>> checkAutonomousTradingSignal(double balance) async {
    try {
      // Call the autonomous trading API to get signal
      final signalResponse = await http.post(
        Uri.parse('http://164.52.202.62:9000/get-signal'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: '{}',
      );

      // Update the last signal date for autonomous trading
      final now = DateTime.now();
      await _secureStorage.write(key: 'last_autonomous_signal_date', value: now.toIso8601String());

      if (signalResponse.statusCode == 200) {
        final signalData = jsonDecode(signalResponse.body);

        // Extract output mint and signal from response
        final outputMint = signalData['Output Mint'] as String?;
        final tradingSymbol = signalData['Symbol'] as String?;
        final signalType = signalData['Signal'] as String?;

        // Process signal if it's a Long signal and we have an output mint
        if (outputMint != null && signalType != null && signalType.contains('Long')) {
          if (balance <= 0.01) {
            return {
              'type': 'autonomous',
              'signal': 'long',
              'symbol': tradingSymbol,
              'action': 'none',
              'message': 'Long signal received for $tradingSymbol but insufficient balance. Please load SOL to enable transactions.'
            };
          } else {
            // Execute the swap with the output mint from the signal
            final swapResult = await handleBuySignal(outputMint);

            if (swapResult['success'] == true) {
              // Record transaction in activity log
              await recordTradingActivity('autonomous_buy', {
                'ts': now.toIso8601String(),
                'txSignature': swapResult['signature'],
                'amount': swapResult['amount'],
                'symbol': tradingSymbol,
                'outputMint': outputMint,
                'signal': signalType,
                'entryPrice': signalData['Entry Price'],
              });
              // Create activity data with more detailed information
              final activityData = {
                'ts': now.toIso8601String(),
                'txSignature': swapResult['signature'],
                'amount': swapResult['amount'],
                'symbol': tradingSymbol,
                'outputMint': outputMint,
                'signal': signalType,
                'entryPrice': signalData['Entry Price'],
                'action': 'buy',
              };

              // Record transaction in activity log and send to API
              await recordTradingActivity('autonomous_buy', activityData);

              return {
                'type': 'autonomous',
                'signal': 'long',
                'action': 'buy',
                'symbol': tradingSymbol,
                'txSignature': swapResult['signature'],
                'message': 'LONG signal executed: Swapped SOL for $tradingSymbol'
              };
            } else {
              return {
                'type': 'autonomous',
                'signal': 'long',
                'action': 'none',
                'symbol': tradingSymbol,
                'error': swapResult['error'],
                'message': 'LONG signal received but swap failed: ${swapResult['error']}'
              };
            }
          }
        } else {
          // Not a Long signal or missing output mint
          return {
            'type': 'autonomous',
            'signal': signalType?.toLowerCase() ?? 'unknown',
            'symbol': tradingSymbol,
            'action': 'none',
            'message': 'Signal received: ${signalType ?? "Unknown"} for ${tradingSymbol ?? "Unknown"} - No action required'
          };
        }
      } else {
        return {
          'type': 'autonomous',
          'error': 'Failed to get autonomous trading signal',
          'message': 'Error checking autonomous trading signal'
        };
      }
    } catch (e) {
      debugPrint('Error checking autonomous trading signal: $e');
      return {
        'type': 'autonomous',
        'signal': 'error',
        'action': 'none',
        'error': e.toString(),
        'message': 'Error checking autonomous trading signal: $e'
      };
    }
  }

// Helper method to record trading activity
  Future<void> recordTradingActivity(String activityType, Map<String, dynamic> activityData) async {
    try {
      if (_agentName == null) return;

      // Get existing activity or initialize new array
      final activityStr = await _secureStorage.read(key: '${_agentName}_activity');
      List<dynamic> activity = [];

      if (activityStr != null) {
        activity = jsonDecode(activityStr);
      }

      // Add new activity with type
      final newActivity = {
        'type': activityType,
        ...activityData,
      };

      activity.add(newActivity);

      // Store updated activity
      await _secureStorage.write(
        key: '${_agentName}_activity',
        value: jsonEncode(activity),
      );

      // Limit stored activity to last 50 entries to prevent excessive storage
      if (activity.length > 50) {
        activity = activity.sublist(activity.length - 50);
        await _secureStorage.write(
          key: '${_agentName}_activity',
          value: jsonEncode(activity),
        );
      }

      // Send the activity to the API
      await sendActivityToApi(newActivity);

      debugPrint('Recorded trading activity: $activityType');
    } catch (e) {
      debugPrint('Error recording trading activity: $e');
    }
  }
//   Future<void> recordTradingActivity(String activityType, Map<String, dynamic> activityData) async {
//     try {
//       if (_agentName == null) return;
//
//       // Get existing activity or initialize new array
//       final activityStr = await _secureStorage.read(key: '${_agentName}_activity');
//       List<dynamic> activity = [];
//
//       if (activityStr != null) {
//         activity = jsonDecode(activityStr);
//       }
//
//       // Add new activity with type
//       final newActivity = {
//         'type': activityType,
//         ...activityData,
//       };
//
//       activity.add(newActivity);
//
//       // Store updated activity
//       await _secureStorage.write(
//         key: '${_agentName}_activity',
//         value: jsonEncode(activity),
//       );
//
//       // Limit stored activity to last 50 entries to prevent excessive storage
//       if (activity.length > 50) {
//         activity = activity.sublist(activity.length - 50);
//         await _secureStorage.write(
//           key: '${_agentName}_activity',
//           value: jsonEncode(activity),
//         );
//       }
//
//       debugPrint('Recorded trading activity: $activityType');
//     } catch (e) {
//       debugPrint('Error recording trading activity: $e');
//     }
//   }

// Get trading activity history
  Future<List<Map<String, dynamic>>> getTradingActivityHistory() async {
    try {
      if (_agentName == null) return [];

      final activityStr = await _secureStorage.read(key: '${_agentName}_activity');
      if (activityStr == null) return [];

      final activityList = jsonDecode(activityStr) as List;
      return activityList.map((item) => Map<String, dynamic>.from(item)).toList();
    } catch (e) {
      debugPrint('Error getting trading activity history: $e');
      return [];
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

  Future<bool> sendActivityToApi(Map<String, dynamic> activity) async {
    try {
      if (_agentName == null) {
        debugPrint('Cannot send activity to API: No agent selected');
        return false;
      }

      // Prepare the request body
      final requestBody = {
        'ticker': _agentName,
        'payload': activity
      };

      debugPrint('Sending activity to API: ${jsonEncode(requestBody)}');

      // Make the API call
      final response = await http.post(
        Uri.parse('https://zynapse.zkagi.ai/append_activity'),
        headers: {
          'Content-Type': 'application/json',
          'api-key': 'zk-123321',
        },
        body: jsonEncode(requestBody),
      );

      // Check the response
      if (response.statusCode == 200) {
        debugPrint('Activity successfully sent to API');
        return true;
      } else {
        debugPrint('Failed to send activity to API: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Error sending activity to API: $e');
      return false;
    }
  }
}
