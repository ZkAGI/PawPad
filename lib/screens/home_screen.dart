import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../services/agent_provider.dart';
import '../services/auth_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/wallet_storage_service.dart';
import '../widgets/gradient_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? selectedAgentName;
  bool _isLoadingBalance = false;
  double _currentBalance = 0.000;
  List<String> _availableAgents = [];

  @override
  void initState() {
    super.initState();
    _loadAgents();
    // Initialize with first agent and fetch balance
    _initializeSelectedAgent();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkDailyTradingSignal();
    });
  }

  // Add this method to your _HomeScreenState class
  String? _getValidDropdownValue(AgentProvider agentProvider) {
    // First try to use the selected name or the provider's agent name
    String? value = selectedAgentName ?? agentProvider.agentName;

    // Check if the value exists in the available agents list
    if (value != null && _availableAgents.contains(value)) {
      return value;
    }

    // If not, use the first available agent if any exist
    if (_availableAgents.isNotEmpty) {
      return _availableAgents.first;
    }

    // If there are no available agents, return null
    return null;
  }

  // Add this method to your _HomeScreenState class
  void _showInsufficientBalanceDialog(BuildContext context, String signal) {
    showDialog(
      context: context,
      barrierDismissible: false, // User must tap button to close dialog
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              const SizedBox(width: 10),
              const Text('Action Required', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Your trading agent received a $signal signal but couldn\'t perform the transaction.',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your wallet currently has insufficient balance to execute the transaction. To enable autonomous trading:',
                ),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.only(left: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• Load SOL into your wallet'),
                      Text('• Automated trading will resume within 24 hours'),
                      Text('• Keep sufficient balance for continuous operation'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Your agent will continue monitoring the market and will execute transactions automatically once funds are available.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Dismiss'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // You could navigate to a "Add Funds" screen here
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fund addition feature coming soon!')),
                );
              },
              child: const Text('Add Funds'),
            ),
          ],
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        );
      },
    );
  }

  Future<void> _checkDailyTradingSignal() async {
    final agentProvider = Provider.of<AgentProvider>(context, listen: false);

    // Only check if we have an agent
    if (!agentProvider.hasAgent) return;

    final result = await agentProvider.checkDailyTradingSignal();

    // If a result was checked and there's a message, show it to the user
    if (result['checked'] == true && result['message'] != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            duration: const Duration(seconds: 5),
            action: result['signal'] == 'buy' && result['action'] == 'none'
                ? SnackBarAction(
              label: 'Add Funds',
              onPressed: () {
                // Navigate to a screen where the user can add funds
                // For now just show another message
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Fund addition feature coming soon!'))
                );
              },
            )
                : null,
          ),
        );
      }
    }

    // If a buy action was performed, refresh the balance
    if (result['action'] == 'buy') {
      _refreshBalance();
    }
  }

  Future<void> _loadAgents() async {
    print('Loading agents from storage...');
    final agentProvider = Provider.of<AgentProvider>(context, listen: false);

    try {
      // Clear and reload all wallets
      await agentProvider.loadStoredWallets();

      // Get a fresh list of wallet agents
      final walletList = await WalletStorageService.getWalletList();
      print('Wallet list from storage: $walletList');

      // Update the UI with fresh data
      setState(() {
        _availableAgents =
            walletList.map((wallet) => wallet['name'] as String).toList();
        print('Available agents updated to: $_availableAgents');
      });
    } catch (e) {
      print('Error loading agents: $e');
    }
  }

  Future<void> _initializeSelectedAgent() async {
    // We'll fetch the balance right away
    _refreshBalance();
  }

  Future<void> _refreshBalance() async {
    final agentProvider = Provider.of<AgentProvider>(context, listen: false);

    // Exit early if no agent exists
    if (agentProvider.agentName == null) {
      print('Cannot refresh balance: No agent selected');
      return;
    }

    setState(() {
      _isLoadingBalance = true;
    });

    try {
      print('Refreshing balance for agent: ${agentProvider.agentName}');

      // Always use the current agent from the provider
      final balance = await agentProvider.getAgentBalance(
          agentProvider.agentName!);

      print('Retrieved balance: $balance SOL');

      setState(() {
        _currentBalance = balance;
        _isLoadingBalance = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingBalance = false;
      });
      print('Error refreshing balance: $e');
    }
  }

  void _copyWalletAddress(BuildContext context, AgentProvider agentProvider) {
    // Always use the current agent from the provider
    final address = agentProvider.getAgentWalletAddress(
        agentProvider.agentName);

    if (address != null && address.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: address));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Wallet address copied: $address'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No wallet address available to copy'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final agentProvider = Provider.of<AgentProvider>(context);

    print('Agent provider current agent: ${agentProvider.agentName}');
    print('Available agents from _availableAgents: $_availableAgents');

    return Scaffold(
      appBar: AppBar(
        title: const Text('PawPad'),
        actions: [
          // Agent selector with dropdown and icon
          if (_availableAgents.isNotEmpty)
            Row(
              children: [
                // Agent status icon
                Stack(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.auto_awesome, size: 16,
                          color: Colors.orange.shade700),
                    ),
                    Positioned(
                      right: 4,
                      bottom: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.grey, // Grey for inactive state
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                      ),
                    ),
                  ],
                ),

                // Agent dropdown
                // In HomeScreen build method, replace the dropdown section:

// Agent dropdown
                // Inside your build method, modify the DropdownButton:
                DropdownButton<String>(
                  // Make sure the value exists in the items list
                  value: _getValidDropdownValue(agentProvider),
                  underline: Container(),
                  dropdownColor: const Color(0xFF000A19),
                  iconEnabledColor: Colors.white,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      print('Selected new agent: $newValue');
                      setState(() {
                        selectedAgentName = newValue;
                      });
                      agentProvider.switchToAgent(newValue);
                      _refreshBalance();
                    }
                  },
                  items: _availableAgents.map<DropdownMenuItem<String>>((String value) {
                    print('Adding dropdown item: $value');
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value, style: const TextStyle(fontSize: 14)),
                    );
                  }).toList(),
                )
              ],
            ),

          // Copy wallet address button
          if (agentProvider.hasAgent)
            IconButton(
              icon: const Icon(Icons.copy),
              color: Colors.white,
              onPressed: () => _copyWalletAddress(context, agentProvider),
              tooltip: 'Copy wallet address',
            ),

          // Settings icon
          IconButton(
            icon: const Icon(Icons.settings),
            color: Colors.white,
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: agentProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Agent Balance Display
            if (agentProvider.hasAgent)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Card(
                  elevation: 2,
                  child: gradientCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Balance',
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.refresh, size: 20),
                                onPressed: _refreshBalance,
                                tooltip: 'Refresh balance',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _isLoadingBalance
                              ? const Center(child: CircularProgressIndicator(
                              strokeWidth: 2))
                              : Row(
                            children: [
                              Text(
                                '\$ ${_currentBalance.toStringAsFixed(3)}',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'USD',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            // Banner for new users
            if (!agentProvider.hasAgent) _buildNoAgentBanner(context),

            if (agentProvider.hasAgent)
              const SizedBox(height: 16),

            // Trending Agents Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Trending Agents',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTrendingAgentsList(context, agentProvider),
                ],
              ),
            ),
          ],
        ),
      ),
      // + button at bottom right
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateAgentModal(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  // Banner widget for new users - no changes needed
  Widget _buildNoAgentBanner(BuildContext context) {
    // Existing code...
    return Container(
      margin: const EdgeInsets.all(16.0),
      child: gradientCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create Your Trading Agent Today',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Get started with automated trading on Solana',
              style: TextStyle(
                  fontSize: 14,
                  color: Colors.white
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _showCreateAgentModal(context),
              child: const Text('Create Agent'),
            ),
          ],
        ),
      ),
    );
  }

  // Trending agents list - no changes needed
  Widget _buildTrendingAgentsList(BuildContext context,
      AgentProvider agentProvider) {
    // Existing code...
    return SizedBox(
      height: 150,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: agentProvider.trendingAgents.length,
        itemBuilder: (context, index) {
          final agent = agentProvider.trendingAgents[index];
          return Card(
            margin: const EdgeInsets.only(right: 12),
            child: gradientCard(
              child: Container(
                width: 120,
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.grey.shade200,
                      child: const Icon(
                          Icons.person, size: 30, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      agent['name'] ?? 'Agent',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Modal for creating a new agent - no changes needed
// Inside _HomeScreenState class
  void _showCreateAgentModal(BuildContext context) {
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1F2641),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const CreateAgentForm(),
    ).then((newAgentName) {
      // If we received a new agent name back
      if (newAgentName != null && newAgentName.isNotEmpty) {
        print('New agent created: $newAgentName - refreshing home screen');

        // Reload agents list from storage
        _loadAgents().then((_) {
          // Force UI update and select the new agent
          setState(() {
            selectedAgentName = newAgentName;
            print('Set selectedAgentName to: $newAgentName');
          });

          // Switch to the new agent in the provider
          final agentProvider = Provider.of<AgentProvider>(
              context, listen: false);
          agentProvider.switchToAgent(newAgentName).then((_) {
            // Refresh the balance for the new agent
            _refreshBalance();
          });
        });
      }
    });
  }
}

class _checkDailyTradingSignal {
}
// Create Agent Form Modal
class CreateAgentForm extends StatefulWidget {
  const CreateAgentForm({Key? key}) : super(key: key);

  @override
  State<CreateAgentForm> createState() => _CreateAgentFormState();
}

class _CreateAgentFormState extends State<CreateAgentForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _imagePath;
  bool _isLoading = false;
  // Add toggle state variables
  bool _bitcoinBuyAndHold = false;
  bool _autonomousTrading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _imagePath = pickedFile.path;
      });
    }
  }
  // Future<void> _createAgentAndRecord() async {
  //   if (_formKey.currentState!.validate()) {
  //     setState(() {
  //       _isLoading = true;
  //     });
  //
  //     bool needsBalanceWarning = false;
  //
  //     try {
  //       print('-------- AGENT CREATION PROCESS STARTED --------');
  //
  //       // Step 1: Create the agent in the provider first
  //       final agentProvider = Provider.of<AgentProvider>(context, listen: false);
  //       await agentProvider.getOrCreateAgent(
  //         name: _nameController.text,
  //         imagePath: _imagePath,
  //         bitcoinBuyAndHold: _bitcoinBuyAndHold,
  //         autonomousTrading: _autonomousTrading,
  //       );
  //
  //       // Step 2: Get the wallet address from the agent provider
  //       final walletAddress = agentProvider.getAgentWalletAddress(_nameController.text);
  //       print('Wallet address retrieved: $walletAddress');
  //
  //       if (walletAddress == null) {
  //         throw Exception('Failed to get wallet address for agent');
  //       }
  //
  //       // Initialize activity array
  //       List<Map<String, dynamic>> activity = [];
  //
  //       // Step 3: If Bitcoin Buy & Hold is enabled, check the trading signal
  //       if (_bitcoinBuyAndHold) {
  //         print('Bitcoin Buy & Hold is enabled - checking trading signal...');
  //
  //         try {
  //           // Call the prediction API to get trading signal
  //           final predictionResponse = await http.get(
  //             Uri.parse('http://103.231.86.182:3020/predict'),
  //           );
  //
  //           print('Prediction API status code: ${predictionResponse.statusCode}');
  //           print('Prediction API response: ${predictionResponse.body}');
  //
  //           if (predictionResponse.statusCode == 200) {
  //             // Parse the response to get the signal
  //             final predictionData = jsonDecode(predictionResponse.body);
  //
  //             // Extract the signal (adjust according to actual API response format)
  //             // Assuming the API returns something like {"signal": "buy"} or {"signal": "hold"}
  //             final signal = predictionData['signal'] ?? 'hold';
  //
  //             // Create timestamp
  //             final timestamp = DateTime.now().toIso8601String();
  //
  //             print('Trading signal received: $signal');
  //
  //             final currentBalance = await agentProvider.getBalance();
  //
  //             // Add action to activity based on signal
  //             if (signal.toLowerCase() == 'buy') {
  //               if (currentBalance <= 0) {
  //                 // Cannot perform buy action due to insufficient balance
  //                 print('Cannot perform buy action: Insufficient balance');
  //                 activity.add({
  //                   'action': 'buy_failed',
  //                   'ts': timestamp,
  //                   'note': 'Insufficient balance to perform swap action'
  //                 });
  //
  //                 needsBalanceWarning = true;
  //                 // Show a notification that will be displayed after agent creation
  //                 print('Agent created with signal: BUY, but swap action could not be performed due to insufficient balance. Please load some SOL to enable transactions.');
  //               }else {
  //                 activity.add({
  //                   'action': 'buy',
  //                   'ts': timestamp,
  //                   // Add solscan link if available in future
  //                 });
  //               }
  //             } else {
  //               activity.add({
  //                 'action': 'hold',
  //                 'ts': timestamp,
  //               });
  //             }
  //
  //           } else {
  //             print('Failed to get prediction - using default "hold" action');
  //             activity.add({
  //               'action': 'hold',
  //               'ts': DateTime.now().toIso8601String(),
  //               'note': 'Default due to prediction API error'
  //             });
  //           }
  //         } catch (e) {
  //           print('Error calling prediction API: $e');
  //           activity.add({
  //             'action': 'hold',
  //             'ts': DateTime.now().toIso8601String(),
  //             'note': 'Default due to error'
  //           });
  //         }
  //       }
  //
  //       // Step 4: Prepare API request data with activity array
  //       final requestData = {
  //         'ticker': _nameController.text,
  //         'wallet_address': walletAddress,
  //         'isFutureAndOptions': _autonomousTrading,
  //         'isBuyAndHold': _bitcoinBuyAndHold,
  //         'activity': activity,
  //       };
  //
  //       print('Request data: ${jsonEncode(requestData)}');
  //
  //       // Step 5: Send API request
  //       try {
  //         final response = await http.post(
  //           Uri.parse('https://zynapse.zkagi.ai/record_agent'),
  //           headers: {
  //             'Content-Type': 'application/json',
  //             'api-key': 'zk-123321',
  //           },
  //           body: jsonEncode(requestData),
  //         );
  //
  //         print('Record API status code: ${response.statusCode}');
  //
  //         // Handle API response
  //         if (response.statusCode != 200) {
  //           throw Exception('Failed to record agent: ${response.body}');
  //         }
  //       } catch (e) {
  //         print('Error sending to record API: $e');
  //         // Continue and show success message anyway since the agent was created locally
  //         print('Agent created locally but API recording failed: $e');
  //       }
  //
  //       if (context.mounted) {
  //         // Create a detailed success message that includes trading action if available
  //         String successMessage = 'Agent created successfully!';
  //         if (activity.isNotEmpty) {
  //           final action = activity.first['action'].toString().toUpperCase();
  //           successMessage = 'Agent created with signal: $action';
  //         }
  //
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(
  //             content: Text(successMessage),
  //             backgroundColor: Colors.green,
  //             behavior: SnackBarBehavior.floating,
  //           ),
  //         );
  //
  //         // Close the modal
  //         Navigator.pop(context, _nameController.text);
  //
  //         if (needsBalanceWarning && context.mounted) {
  //           // Delay slightly to allow the UI to update
  //           Future.delayed(const Duration(milliseconds: 500), () {
  //             if (context.mounted) {
  //               // This requires adding the dialog function to a location visible to the form
  //               // Pass the parent context to access the _showInsufficientBalanceDialog method
  //               _showInsufficientBalanceDialogAfterCreation(context, 'BUY');
  //             }
  //           });
  //         }
  //
  //       }
  //     } catch (e) {
  //       print('Error creating agent: $e');
  //
  //       // Show error toast
  //       if (context.mounted) {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(
  //             content: Text('Error creating agent: $e'),
  //             backgroundColor: Colors.red,
  //             behavior: SnackBarBehavior.floating,
  //           ),
  //         );
  //       }
  //     } finally {
  //       if (mounted) {
  //         setState(() {
  //           _isLoading = false;
  //         });
  //       }
  //     }
  //   }
  // }

  // Updated version of the function to fix the insufficient balance handling

  Future<void> _createAgentAndRecord() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      bool needsBalanceWarning = false;

      try {
        print('-------- AGENT CREATION PROCESS STARTED --------');

        // Step 1: Create the agent in the provider first
        final agentProvider = Provider.of<AgentProvider>(context, listen: false);
        await agentProvider.getOrCreateAgent(
          name: _nameController.text,
          imagePath: _imagePath,
          bitcoinBuyAndHold: _bitcoinBuyAndHold,
          autonomousTrading: _autonomousTrading,
        );

        // Step 2: Get the wallet address from the agent provider
        final walletAddress = agentProvider.getAgentWalletAddress(_nameController.text);
        print('Wallet address retrieved: $walletAddress');

        if (walletAddress == null) {
          throw Exception('Failed to get wallet address for agent');
        }

        // We need to switch to the newly created agent first - IMPORTANT!
        await agentProvider.switchToAgent(_nameController.text);

        // Initialize activity array
        List<Map<String, dynamic>> activity = [];

        // Step 3: If Bitcoin Buy & Hold is enabled, check the trading signal
        if (_bitcoinBuyAndHold) {
          final now = DateTime.now();
          print('Bitcoin Buy & Hold is enabled - checking trading signal...');


          try {
            // Call the prediction API to get trading signal
            // final predictionResponse = await http.get(
            //   Uri.parse('http://103.231.86.182:3020/predict'),
            // );
            //
            // print('Prediction API status code: ${predictionResponse.statusCode}');
            // print('Prediction API response: ${predictionResponse.body}');

            // if (predictionResponse.statusCode == 200  ) {
              // Parse the response to get the signal
             // final predictionData = jsonDecode(predictionResponse.body);

              final predictionData = {
                'signal': 'buy',
                'confidence': 0.95,
                'timestamp': DateTime.now().toIso8601String()
              };

              // Extract the signal
              // final signal = predictionData['signal'] ?? 'hold';
              final String signal = (predictionData['signal'] ?? 'hold').toString();

              // Create timestamp
              final timestamp = DateTime.now().toIso8601String();

              print('Trading signal received: $signal');

              // Add action to activity based on signal
              if (signal.toLowerCase() == 'buy') {
                // Get the current balance AFTER switching to the new agent
                final currentBalance = await agentProvider.getBalance();
                print('Current balance: $currentBalance SOL');

                // Check if balance is sufficient (use 0.01 as minimum threshold)
                if (currentBalance < 0.01) {
                  // Cannot perform buy action due to insufficient balance
                  print('Cannot perform buy action: Insufficient balance (${currentBalance} SOL)');
                  activity.add({
                    'action': 'buy_failed',
                    'ts': timestamp,
                    'note': 'Insufficient balance to perform swap action'
                  });

                  needsBalanceWarning = true;
                  print('Agent created with signal: BUY, but swap action could not be performed due to insufficient balance. Please load some SOL to enable transactions.');
                } else {
                  try {
                    // Execute the swap - BTC token address on Solana
                    final btcMint = 'qfnqNqs3nCAHjnyCgLRDbBtq4p2MtHZxw8YjSyYhPoL';

                    // Execute the swap using the handleBuySignal method
                    final swapResult = await agentProvider.handleBuySignal(btcMint);

                    if (swapResult['success'] == true) {
                      // Swap was successful
                      activity.add({
                        'action': 'buy',
                        'ts': timestamp,
                        'txSignature': swapResult['signature'],
                        'amount': swapResult['amount'],
                      });

                      print('Swap successful! Transaction signature: ${swapResult['signature']}');
                    } else {
                      // Swap failed
                      activity.add({
                        'action': 'buy_failed',
                        'ts': timestamp,
                        'note': 'Swap failed: ${swapResult['error']}'
                      });

                      needsBalanceWarning = true;
                      print('Swap failed: ${swapResult['error']}');
                    }
                  } catch (e) {
                    // Handle any errors during the swap process
                    print('Error executing swap: $e');
                    activity.add({
                      'action': 'buy_failed',
                      'ts': timestamp,
                      'note': 'Swap error: $e'
                    });

                    needsBalanceWarning = true;
                  }
                }
              } else {
                // Signal is hold
                activity.add({
                  'action': 'hold', //hold
                  'ts': timestamp,
                });
              }

            // } else {
            //   print('Failed to get prediction - using default "hold" action');
            //   activity.add({
            //     'action': 'hold',
            //     'ts': DateTime.now().toIso8601String(),
            //     'note': 'Default due to prediction API error'
            //   });
            // }
          } catch (e) {
            print('Error calling prediction API: $e');
            activity.add({
              'action': 'hold',
              'ts': DateTime.now().toIso8601String(),
              'note': 'Default due to error'
            });
          }
        }

        // Step 4: Prepare API request data with activity array
        final requestData = {
          'ticker': _nameController.text,
          'wallet_address': walletAddress,
          'isFutureAndOptions': _autonomousTrading,
          'isBuyAndHold': _bitcoinBuyAndHold,
          'activity': activity,
        };

        print('Request data: ${jsonEncode(requestData)}');

        // Step 5: Send API request
        try {
          final response = await http.post(
            Uri.parse('https://zynapse.zkagi.ai/record_agent'),
            headers: {
              'Content-Type': 'application/json',
              'api-key': 'zk-123321',
            },
            body: jsonEncode(requestData),
          );

          print('Record API status code: ${response.statusCode}');

          // Handle API response
          if (response.statusCode != 200) {
            throw Exception('Failed to record agent: ${response.body}');
          }
        } catch (e) {
          print('Error sending to record API: $e');
          // Continue and show success message anyway since the agent was created locally
          print('Agent created locally but API recording failed: $e');
        }

        if (context.mounted) {
          // Create a detailed success message that includes trading action if available
          String successMessage = 'Agent created successfully!';
          if (activity.isNotEmpty) {
            final action = activity.first['action'].toString().toUpperCase();
            if (action == 'BUY' && activity.first.containsKey('txSignature')) {
              successMessage = 'Agent created with signal: BUY. Swap executed!';
            } else if (action == 'BUY_FAILED') {
              successMessage = 'Agent created with signal: BUY, but swap failed.';
            } else {
              successMessage = 'Agent created with signal: $action';
            }
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(successMessage),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );

          // Close the modal
          Navigator.pop(context, _nameController.text);

          if (needsBalanceWarning && context.mounted) {
            // Delay slightly to allow the UI to update
            Future.delayed(const Duration(milliseconds: 500), () {
              if (context.mounted) {
                // Show insufficient balance dialog
                _showInsufficientBalanceDialogAfterCreation(context, 'BUY');
              }
            });
          }
        }
      } catch (e) {
        print('Error creating agent: $e');

        // Show error toast
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error creating agent: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Create Trading Agent',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white,  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Agent image picker
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: _imagePath != null
                        ? FileImage(File(_imagePath!))
                        : null,
                    child: _imagePath == null
                        ? const Icon(Icons.person, size: 50, color: Colors.grey)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: InkWell(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Agent name field
            TextFormField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Agent Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a name for your agent';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Bitcoin Buy & Hold toggle
            SwitchListTile(
              title: const Text('Bitcoin Buy & Hold', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Enable long-term Bitcoin investment strategy',style: TextStyle(color: Colors.white54)),
              value: _bitcoinBuyAndHold,
              onChanged: (value) {
                setState(() {
                  _bitcoinBuyAndHold = value;
                });
              },
            ),

            // Autonomous Trading toggle
            SwitchListTile(
              title: const Text('Autonomous Trading', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Allow agent to trade automatically based on market conditions',style: TextStyle(color: Colors.white54)),
              value: _autonomousTrading,
              onChanged: (value) {
                setState(() {
                  _autonomousTrading = value;
                });
              },
            ),

            const SizedBox(height: 24),

            // Create button
            ElevatedButton(
              onPressed: _isLoading ? null : _createAgentAndRecord,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Create Agent'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// Add this method to _CreateAgentFormState
void _showInsufficientBalanceDialogAfterCreation(BuildContext context, String signal) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 10),
            const Text('Action Required', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Your trading agent received a $signal signal but couldn\'t perform the transaction.',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your wallet currently has insufficient balance to execute the transaction. To enable autonomous trading:',
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• Load SOL into your wallet'),
                    Text('• Automated trading will resume within 24 hours'),
                    Text('• Keep sufficient balance for continuous operation'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Your agent will continue monitoring the market and will execute transactions automatically once funds are available.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Dismiss'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // You could navigate to a "Add Funds" screen here
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fund addition feature coming soon!')),
              );
            },
            child: const Text('Add Funds'),
          ),
        ],
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      );
    },
  );
}