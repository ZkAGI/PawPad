import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/agent_provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/agent_pnl_tracking_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BalanceEntryScreen extends StatefulWidget {
  final String agentName;
  final String? imagePath;
  final bool bitcoinBuyAndHold;
  final bool autonomousTrading;
  final bool showCustomTrading;
  final Set<String> selectedCoins;
  final String? selectedTimeframe;

  const BalanceEntryScreen({
    Key? key,
    required this.agentName,
    this.imagePath,
    required this.bitcoinBuyAndHold,
    required this.autonomousTrading,
    required this.showCustomTrading,
    required this.selectedCoins,
    this.selectedTimeframe,
  }) : super(key: key);

  @override
  State<BalanceEntryScreen> createState() => _BalanceEntryScreenState();
}

class _BalanceEntryScreenState extends State<BalanceEntryScreen> {
  final TextEditingController _balanceController = TextEditingController();
  bool _isLoading = false;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  @override
  void dispose() {
    _balanceController.dispose();
    super.dispose();
  }

  void _setQuickAmount(double amount) {
    setState(() {
      _balanceController.text = amount.toString();
    });
  }

  Future<double> _fetchCurrentBitcoinPrice() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.containsKey('bitcoin') && data['bitcoin'].containsKey('usd')) {
          return data['bitcoin']['usd'].toDouble();
        }
      }

      final backupResponse = await http.get(
        Uri.parse('https://api.binance.com/api/v3/ticker/price?symbol=BTCUSDT'),
      );

      if (backupResponse.statusCode == 200) {
        final data = json.decode(backupResponse.body);
        if (data.containsKey('price')) {
          return double.parse(data['price']);
        }
      }

      return 32000.0;
    } catch (e) {
      print('Error fetching Bitcoin price: $e');
      return 32000.0;
    }
  }

  Future<void> _createAgentWithBalance() async {
    final enteredBalance = double.tryParse(_balanceController.text);

    if (enteredBalance == null || enteredBalance <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid balance amount'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    bool needsBalanceWarning = false;

    try {
      print('-------- AGENT CREATION PROCESS STARTED --------');

      // Step 1: Create the agent in the provider first
      final agentProvider = Provider.of<AgentProvider>(context, listen: false);
      await agentProvider.getOrCreateAgent(
        name: widget.agentName,
        imagePath: widget.imagePath,
        bitcoinBuyAndHold: widget.bitcoinBuyAndHold,
        autonomousTrading: widget.autonomousTrading,
      );

      // Step 2: Get the wallet address from the agent provider
      final walletAddress = agentProvider.getAgentWalletAddress(widget.agentName);
      print('Wallet address retrieved: $walletAddress');

      if (walletAddress == null) {
        throw Exception('Failed to get wallet address for agent');
      }

      // Switch to the newly created agent
      await agentProvider.switchToAgent(widget.agentName);

      // Initialize activity array
      List<Map<String, dynamic>> activity = [];

      // Check if balance is sufficient for trading actions
      if (enteredBalance < 0.01) {
        needsBalanceWarning = true;
      }

      // Process Autonomous Trading if enabled and sufficient balance
      if (widget.autonomousTrading) {
        print('Autonomous Trading is enabled - calling get-signal API...');

        try {
          final signalResponse = await http.post(
            Uri.parse('http://164.52.202.62:9000/get-signal'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: '{}',
          );

          print('Signal API status code: ${signalResponse.statusCode}');
          print('Signal API response: ${signalResponse.body}');

          if (signalResponse.statusCode == 200) {
            final signalData = jsonDecode(signalResponse.body);

            activity.add({
              'action': 'signal_received',
              'ts': DateTime.now().toIso8601String(),
              'response': signalResponse.body,
            });

            print('Signal received from autonomous trading API');

            final outputMint = signalData['Output Mint'] as String?;
            final tradingSignal = signalData['Signal'] as String?;

            if (outputMint != null && tradingSignal != null && tradingSignal.contains('Long')) {
              print('Processing Long signal for token mint: $outputMint');

              if (enteredBalance < 0.01) {
                print('Cannot perform buy action: Insufficient balance ($enteredBalance SOL)');
                activity.add({
                  'action': 'buy_failed',
                  'ts': DateTime.now().toIso8601String(),
                  'note': 'Insufficient balance to perform swap action'
                });
                needsBalanceWarning = true;
              } else {
                // Execute the buy transaction with the output mint
                final swapResult = await agentProvider.handleBuySignal(outputMint);

                if (swapResult['success'] == true) {
                  activity.add({
                    'action': 'buy',
                    'ts': DateTime.now().toIso8601String(),
                    'txSignature': swapResult['signature'],
                    'amount': swapResult['amount'],
                    'symbol': signalData['Symbol'],
                    'entry_price': signalData['Entry Price'],
                  });

                  print('Autonomous trading swap successful! Transaction signature: ${swapResult['signature']}');
                } else {
                  activity.add({
                    'action': 'buy_failed',
                    'ts': DateTime.now().toIso8601String(),
                    'note': 'Swap failed: ${swapResult['error']}'
                  });
                  needsBalanceWarning = true;
                  print('Autonomous trading swap failed: ${swapResult['error']}');
                }
              }
            } else {
              print('Signal not processed: ${tradingSignal ?? "Unknown"} - Output Mint: ${outputMint ?? "Not provided"}');
              activity.add({
                'action': 'signal_no_action',
                'ts': DateTime.now().toIso8601String(),
                'note': 'Signal did not require a buy action'
              });
            }
          } else {
            print('Failed to get signal from API');
            activity.add({
              'action': 'signal_failed',
              'ts': DateTime.now().toIso8601String(),
              'note': 'Failed to get signal: Status ${signalResponse.statusCode}'
            });
          }
        } catch (e) {
          print('Error calling get-signal API: $e');
          activity.add({
            'action': 'signal_error',
            'ts': DateTime.now().toIso8601String(),
            'note': 'Error: $e'
          });
        }
      }

      // Process Bitcoin Buy & Hold if enabled
      if (widget.bitcoinBuyAndHold) {
        final now = DateTime.now();
        print('Bitcoin Buy & Hold is enabled - checking trading signal...');

        try {
          final predictionResponse = await http.get(
            Uri.parse('https://zynapse.zkagi.ai/v1/predictbtc'),
          );

          print('Prediction API status code: ${predictionResponse.statusCode}');
          print('Prediction API response: ${predictionResponse.body}');

          if (predictionResponse.statusCode == 200) {
            final predictionData = jsonDecode(predictionResponse.body);
            final signal = predictionData['signal'] ?? 'hold';
            final timestamp = DateTime.now().toIso8601String();

            print('Trading signal received: $signal');

            if (signal.toLowerCase() == 'buy') {
              if (enteredBalance < 0.01) {
                print('Cannot perform buy action: Insufficient balance ($enteredBalance SOL)');
                activity.add({
                  'action': 'buy_failed',
                  'ts': timestamp,
                  'note': 'Insufficient balance to perform swap action'
                });
                needsBalanceWarning = true;
              } else {
                try {
                  final btcMint = 'cbbtcf3aa214zXHbiAZQwf4122FBYbraNdFqgw4iMij';
                  final swapResult = await agentProvider.handleBuySignal(btcMint);

                  if (swapResult['success'] == true) {
                    double bitcoinCurrentPrice = await _fetchCurrentBitcoinPrice();
                    activity.add({
                      'action': 'buy',
                      'ts': timestamp,
                      'txSignature': swapResult['signature'],
                      'amount': swapResult['amount'],
                      'buy_price': bitcoinCurrentPrice,
                    });

                    print('Swap successful! Transaction signature: ${swapResult['signature']}');
                  } else {
                    activity.add({
                      'action': 'buy_failed',
                      'ts': timestamp,
                      'note': 'Swap failed: ${swapResult['error']}'
                    });
                    needsBalanceWarning = true;
                    print('Swap failed: ${swapResult['error']}');
                  }
                } catch (e) {
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
              activity.add({
                'action': 'hold',
                'ts': timestamp,
              });
            }
          } else {
            print('Failed to get prediction - using default "hold" action');
            activity.add({
              'action': 'hold',
              'ts': DateTime.now().toIso8601String(),
              'note': 'Default due to prediction API error'
            });
          }
        } catch (e) {
          print('Error calling prediction API: $e');
          activity.add({
            'action': 'hold',
            'ts': DateTime.now().toIso8601String(),
            'note': 'Default due to error'
          });
        }
      }

      // Process custom trading if enabled
      Map<String, dynamic>? customStrategyData;

      if (widget.showCustomTrading && widget.selectedCoins.isNotEmpty && widget.selectedTimeframe != null) {
        customStrategyData = {
          "coins": widget.selectedCoins.toList(),
          "timeframe": widget.selectedTimeframe
        };

        final now = DateTime.now();
        await _secureStorage.write(
            key: 'last_custom_strategy_signal_date', value: now.toIso8601String());

        try {
          final requestBody = {
            "symbols": widget.selectedCoins.toList(),
            "timeframe": widget.selectedTimeframe
          };

          print('Sending custom trading setup: ${jsonEncode(requestBody)}');

          final response = await http.post(
            Uri.parse('http://164.52.202.62:6000/get-signal'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(requestBody),
          );

          if (response.statusCode == 200) {
            final signalData = jsonDecode(response.body);
            print('Custom trading signal received: $signalData');

            final outputMint = signalData['Output Mint'] as String?;
            final tradingSignal = signalData['Signal'] as String?;

            activity.add({
              'action': 'custom_trading_signal',
              'ts': DateTime.now().toIso8601String(),
              'symbols': widget.selectedCoins.toList(),
              'timeframe': widget.selectedTimeframe,
              'symbol': signalData['Symbol'],
              'signal': tradingSignal,
              'entry_price': signalData['Entry Price'],
              'stop_loss': signalData['Stop Loss'],
              'take_profit': signalData['Take Profit'],
            });

            if (outputMint != null && tradingSignal != null && tradingSignal.contains('Long')) {
              print('Processing Long signal for token mint: $outputMint');

              if (enteredBalance < 0.01) {
                print('Cannot perform buy action: Insufficient balance ($enteredBalance SOL)');
                activity.add({
                  'action': 'custom_trading_buy_failed',
                  'ts': DateTime.now().toIso8601String(),
                  'note': 'Insufficient balance to perform swap action'
                });
                needsBalanceWarning = true;
              } else {
                try {
                  final swapResult = await agentProvider.handleBuySignal(outputMint);

                  if (swapResult['success'] == true) {
                    activity.add({
                      'action': 'custom_trading_buy',
                      'ts': DateTime.now().toIso8601String(),
                      'txSignature': swapResult['signature'],
                      'amount': swapResult['amount'],
                      'symbol': signalData['Symbol'],
                      'entry_price': signalData['Entry Price'],
                      'output_mint': outputMint,
                    });

                    print('Custom trading swap successful! Transaction signature: ${swapResult['signature']}');
                  } else {
                    activity.add({
                      'action': 'custom_trading_buy_failed',
                      'ts': DateTime.now().toIso8601String(),
                      'note': 'Swap failed: ${swapResult['error']}'
                    });
                    needsBalanceWarning = true;
                    print('Custom trading swap failed: ${swapResult['error']}');
                  }
                } catch (e) {
                  print('Error executing custom trading swap: $e');
                  activity.add({
                    'action': 'custom_trading_buy_failed',
                    'ts': DateTime.now().toIso8601String(),
                    'note': 'Swap error: $e'
                  });
                  needsBalanceWarning = true;
                }
              }
            } else {
              print('Signal not processed for custom trading: ${tradingSignal ?? "Unknown"} - Output Mint: ${outputMint ?? "Not provided"}');
              activity.add({
                'action': 'custom_trading_no_action',
                'ts': DateTime.now().toIso8601String(),
                'note': 'Signal did not require a buy action or missing output mint'
              });
            }
          }
        } catch (e) {
          print('Error setting up custom trading: $e');
          activity.add({
            'action': 'custom_trading_error',
            'ts': DateTime.now().toIso8601String(),
            'note': 'Error: $e'
          });
        }
      }

      // Prepare API request data for record entry (this remains the same)
      final requestData = {
        'ticker': widget.agentName,
        'wallet_address': walletAddress,
        'isFutureAndOptions': widget.autonomousTrading,
        'isBuyAndHold': widget.bitcoinBuyAndHold,
        'activity': activity,
        'initial_balance': enteredBalance, // Add the entered balance
        if (customStrategyData != null) 'isCustomStrategy': customStrategyData,
      };

      if (widget.imagePath != null) {
        final bytes = await File(widget.imagePath!).readAsBytes();
        final base64Image = base64Encode(bytes);
        requestData['ticker_img'] = base64Image;
      }

      print('Request data: ${jsonEncode(requestData)}');

      // Send API request to record the agent
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

        if (response.statusCode != 200) {
          throw Exception('Failed to record agent: ${response.body}');
        }
      } catch (e) {
        print('Error sending to record API: $e');
        print('Agent created locally but API recording failed: $e');
      }

      if (context.mounted) {
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

        try {
          final trackingProvider = Provider.of<AgentTrackingProvider>(context, listen: false);
          await trackingProvider.fetchTrendingAgents();
        } catch (e) {
          print('Error refreshing trending agents: $e');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Navigate back to home screen with agent name
        Navigator.of(context).pop();
        Navigator.of(context).pop(widget.agentName);

        if (needsBalanceWarning && context.mounted) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (context.mounted) {
              _showInsufficientBalanceDialog(context, 'BUY');
            }
          });
        }
      }
    } catch (e) {
      print('Error creating agent: $e');

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

  void _showInsufficientBalanceDialog(BuildContext context, String signal) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000A19),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000A19),
        title: const Text(
          'Buy oiiio',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              // Settings action
            },
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'You can choose to buy your own coin now, before it goes live.',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 24),

            // Balance display
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'You pay (optional)',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                const Text(
                  'Balance: 0 SOL',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Input field
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[600]!),
              ),
              child: TextField(
                controller: _balanceController,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: '0.0 (optional)',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  suffixIcon: Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'SOL',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.keyboard_arrow_down, color: Colors.grey[400], size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Quick amount buttons
            Row(
              children: [
                _buildQuickAmountButton('0.25 SOL', 0.25),
                const SizedBox(width: 8),
                _buildQuickAmountButton('0.5 SOL', 0.5),
                const SizedBox(width: 8),
                _buildQuickAmountButton('1 SOL', 1.0),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    // Switch to oiiio action
                  },
                  icon: const Icon(Icons.swap_horiz, color: Colors.white54, size: 16),
                  label: const Text(
                    'Switch to oiiio',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // You receive section
            const Text(
              'You receive: ~ oiiio',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),

            const Spacer(),

            // Create coin button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createAgentWithBalance,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4ADE80),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  'Create coin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Number pad (for visual completeness, you can make it functional if needed)
            _buildNumberPad(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAmountButton(String text, double amount) {
    return InkWell(
      onTap: () => _setQuickAmount(amount),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey[700],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildNumberPad() {
    return Container(
      height: 200,
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 1.5,
          crossAxisSpacing: 1,
          mainAxisSpacing: 1,
        ),
        itemCount: 12,
        itemBuilder: (context, index) {
          String text;
          if (index < 9) {
            text = (index + 1).toString();
          } else if (index == 9) {
            text = '.';
          } else if (index == 10) {
            text = '0';
          } else {
            return Container(
              color: Colors.grey[700],
              child: const Icon(Icons.backspace, color: Colors.white),
            );
          }

          return InkWell(
            onTap: () {
              if (index == 11) {
                // Backspace
                if (_balanceController.text.isNotEmpty) {
                  _balanceController.text = _balanceController.text.substring(0, _balanceController.text.length - 1);
                }
              } else {
                // Add number or dot
                _balanceController.text += text;
              }
            },
            child: Container(
              color: Colors.grey[700],
              child: Center(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}