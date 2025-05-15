import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/agent_provider.dart';

class SignalSchedulerService {
  Timer? _bitcoinTimer;
  Timer? _autonomousTimer;
  bool _isInitialized = false;

  // Initialize the service with context
  void initialize(BuildContext context) {
    if (_isInitialized) return;

    final agentProvider = Provider.of<AgentProvider>(context, listen: false);

    // Schedule initial check and then set up regular intervals
    _scheduleInitialChecks(agentProvider, context);

    _isInitialized = true;
  }

  // Schedule initial checks with slight delay to not block UI
  void _scheduleInitialChecks(AgentProvider agentProvider, BuildContext context) async {
    // Check once after app starts with a small delay
    Future.delayed(const Duration(seconds: 5), () {
      _checkAllSignals(agentProvider, context);

      // Then set up scheduled timers
      _setupScheduledTimers(agentProvider, context);
    });
  }

  // Set up regular scheduled timers
  void _setupScheduledTimers(AgentProvider agentProvider, BuildContext context) {
    // Check Bitcoin signal every hour (to catch the 3 PM IST window)
    _bitcoinTimer = Timer.periodic(const Duration(hours: 1), (timer) {
      _checkBitcoinSignal(agentProvider, context);
    });

    // Check Autonomous trading signal every hour (to ensure we don't miss the 6-hour window)
    _autonomousTimer = Timer.periodic(const Duration(hours: 1), (timer) {
      _checkAutonomousSignal(agentProvider, context);
    });
  }

  // Check both signals
  Future<void> _checkAllSignals(AgentProvider agentProvider, BuildContext context) async {
    if (!context.mounted) return;

    try {
      final result = await agentProvider.checkTradingSignals();

      // Show notifications for important signals
      if (result['checked'] == true && result['message'] != null && context.mounted) {
        // Show notification to user about signal result
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            duration: const Duration(seconds: 5),
            action: result['message'].toString().contains('insufficient balance')
                ? SnackBarAction(
              label: 'Add Funds',
              onPressed: () {
                // Navigate to add funds screen or show dialog
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Fund addition feature coming soon!'))
                );
              },
            )
                : null,
          ),
        );
      }
    } catch (e) {
      print('Error checking signals: $e');
    }
  }

  // Check only Bitcoin signal (for scheduled runs)
  Future<void> _checkBitcoinSignal(AgentProvider agentProvider, BuildContext context) async {
    if (!context.mounted) return;

    try {
      // First check if we should check Bitcoin signal now (3 PM IST)
      final shouldCheck = await agentProvider.shouldCheckBitcoinSignalToday();

      if (shouldCheck) {
        // Get current balance
        final balance = await agentProvider.getBalance();

        // Check Bitcoin signal
        final result = await agentProvider.checkBitcoinBuyAndHoldSignal(balance);

        // Show notification for buy signals or errors
        if ((result['signal'] == 'buy' || result['error'] != null) && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              duration: const Duration(seconds: 5),
              action: result['signal'] == 'buy' && result['action'] == 'none'
                  ? SnackBarAction(
                label: 'Add Funds',
                onPressed: () {
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
    } catch (e) {
      print('Error checking Bitcoin signal: $e');
    }
  }

  // Check only Autonomous signal (for scheduled runs)
  Future<void> _checkAutonomousSignal(AgentProvider agentProvider, BuildContext context) async {
    if (!context.mounted) return;

    try {
      // Check if we should check autonomous signal now (every 6 hours)
      final shouldCheck = await agentProvider.shouldCheckAutonomousSignal();

      if (shouldCheck) {
        // Get current balance
        final balance = await agentProvider.getBalance();

        // Check Autonomous signal
        final result = await agentProvider.checkAutonomousTradingSignal(balance);

        // Show notification for long signals or errors
        if ((result['signal'] == 'long' || result['error'] != null) && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              duration: const Duration(seconds: 5),
              action: result['signal'] == 'long' && result['action'] == 'none'
                  ? SnackBarAction(
                label: 'Add Funds',
                onPressed: () {
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
    } catch (e) {
      print('Error checking Autonomous signal: $e');
    }
  }

  // Manual check method that can be called from UI
  Future<void> checkSignalsManually(BuildContext context) async {
    final agentProvider = Provider.of<AgentProvider>(context, listen: false);
    await _checkAllSignals(agentProvider, context);
  }

  // Dispose timers when no longer needed
  void dispose() {
    _bitcoinTimer?.cancel();
    _autonomousTimer?.cancel();
    _isInitialized = false;
  }
}