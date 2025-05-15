import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/wallet_storage_service.dart';

class AgentTrackingProvider extends ChangeNotifier {
  // Tracking data for agents
  final Map<String, Map<String, dynamic>> _agentActivities = {};
  final Map<String, double> _agentPnL = {};
  List<Map<String, dynamic>> _trendingAgents = [];

  // Base URL and API key for the tracking service
  static const String baseUrl = 'https://zynapse.zkagi.ai';
  static const String apiKey = 'zk-123321';

  // Getters
  List<Map<String, dynamic>> get trendingAgents => _trendingAgents;

  // Get PnL for a specific agent
  double getAgentPnL(String? agentName) {
    if (agentName == null) return 0.0;
    return _agentPnL[agentName] ?? 0.0;
  }

  // Initialize provider by loading trending agents
  Future<void> initialize() async {
    await fetchTrendingAgents();
  }

  // Fetch the top trending agents sorted by PnL
  Future<void> fetchTrendingAgents() async {
    try {
      List<Map<String, dynamic>> agents = [];

      // Get agent list from storage
      final agentList = await WalletStorageService.getWalletList();

      // For each agent, fetch their activities and calculate PnL
      for (var agent in agentList) {
        final name = agent['name'] as String;
        final activities = await fetchAgentActivities(name);

        // Calculate PnL for this agent
        final pnl = await calculateAgentPnL(name, activities);

        agents.add({
          'name': name,
          'totalPnL': pnl,
          'isBuyAndHold': activities['isBuyAndHold'] ?? false,
          'isFutureAndOptions': activities['isFutureAndOptions'] ?? false,
        });
      }

      // Sort agents by PnL (descending)
      agents.sort((a, b) => (b['totalPnL'] as double).compareTo(a['totalPnL'] as double));

      // Take top 5 or less
      _trendingAgents = agents.take(5).toList();

      notifyListeners();
    } catch (e) {
      print('Error fetching trending agents: $e');
      // In case of error, provide some default trending agents
      _trendingAgents = [
        {'name': 'Test42', 'totalPnL': 152.75},
        // {'name': 'Nia', 'totalPnL': 89.32},
        // {'name': 'TradeX', 'totalPnL': 42.18},
        // {'name': 'CryptoWhiz', 'totalPnL': -12.65},
        // {'name': 'TrendFollower', 'totalPnL': -28.90},
      ];
      notifyListeners();
    }
  }

  // Fetch activities for a specific agent
  Future<Map<String, dynamic>> fetchAgentActivities(String ticker) async {
    // Check if we already have the activities cached
    if (_agentActivities.containsKey(ticker)) {
      return _agentActivities[ticker]!;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/activities/$ticker'),
        headers: {'api-key': apiKey},
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);

        // Cache the activities
        _agentActivities[ticker] = data;

        return data;
      } else {
        print('Failed to fetch activities for $ticker: ${response.statusCode}');
        // Return empty activities structure
        return {
          'ticker': ticker,
          'activities': [],
          'isBuyAndHold': false,
          'isFutureAndOptions': false,
        };
      }
    } catch (e) {
      print('Error fetching activities for $ticker: $e');
      // Return empty activities structure
      return {
        'ticker': ticker,
        'activities': [],
        'isBuyAndHold': false,
        'isFutureAndOptions': false,
      };
    }
  }

  // Calculate PnL for an agent based on its activities
  Future<double> calculateAgentPnL(String ticker, Map<String, dynamic> activitiesData) async {
    try {
      double totalPnL = 0.0;

      // Check if we have activities to process
      if (activitiesData.containsKey('activities') && activitiesData['activities'] is List) {
        List activities = activitiesData['activities'] as List;

        // Maps to track positions
        Map<String, Map<String, dynamic>> positions = {};

        // Process Bitcoin Buy & Hold activities
        if (activitiesData['isBuyAndHold'] == true) {
          totalPnL += await _calculateBitcoinPnL(activities, positions);
        }

        // Process Autonomous Trading activities
        if (activitiesData['isFutureAndOptions'] == true) {
          totalPnL += await _calculateAutonomousPnL(activities, positions);
        }
      }

      // Store and return the calculated PnL
      _agentPnL[ticker] = totalPnL;
      return totalPnL;
    } catch (e) {
      print('Error calculating PnL for $ticker: $e');
      _agentPnL[ticker] = 0.0;
      return 0.0;
    }
  }

  // Calculate PnL for Bitcoin Buy & Hold strategy
  Future<double> _calculateBitcoinPnL(List activities, Map<String, Map<String, dynamic>> positions) async {
    double bitcoinPnL = 0.0;

    // Find the most recent Bitcoin buy activity
    for (var activity in activities.reversed) {
      if (activity['action'] == 'buy' && !activity.containsKey('symbol')) {
        // This is likely a Bitcoin buy
        double? amount = _extractAmount(activity);

        if (amount != null) {
          // Get the buy price (either from activity or estimate it)
          double buyPrice = activity.containsKey('buy_price')
              ? double.parse(activity['buy_price'].toString())
              : await _estimateBitcoinPriceAtTime(activity['timestamp']);

          // Store position data
          positions['BTC'] = {
            'amount': amount,
            'buyPrice': buyPrice,
            'timestamp': activity['timestamp'],
          };

          // Get current price and calculate PnL
          double currentPrice = await _getCurrentBitcoinPrice();
          bitcoinPnL = amount * (currentPrice - buyPrice);

          // We found the most recent Bitcoin buy, so we can break
          break;
        }
      }
    }

    return bitcoinPnL;
  }

  // Calculate PnL for Autonomous Trading strategy
  Future<double> _calculateAutonomousPnL(List activities, Map<String, Map<String, dynamic>> positions) async {
    double autonomousPnL = 0.0;

    // Process buy activities and signal_received activities
    for (var activity in activities) {
      if (activity['action'] == 'buy' && activity.containsKey('symbol')) {
        // This is an autonomous trading buy
        String symbol = activity['symbol'];
        double? amount = _extractAmount(activity);
        double? entryPrice = activity.containsKey('entry_price')
            ? double.tryParse(activity['entry_price'].toString())
            : null;

        if (amount != null && entryPrice != null) {
          // Store position data
          positions[symbol] = {
            'amount': amount,
            'buyPrice': entryPrice,
            'timestamp': activity['timestamp'],
          };

          // Get current price and calculate PnL
          double currentPrice = await _getTokenCurrentPrice(symbol);
          double symbolPnL = amount * (currentPrice - entryPrice);
          autonomousPnL += symbolPnL;
        }
      }
      else if (activity['action'] == 'signal_received' && activity.containsKey('response')) {
        // Parse signal response to extract entry price
        try {
          Map<String, dynamic> signalData = json.decode(activity['response']);

          if (signalData.containsKey('Symbol') &&
              signalData.containsKey('Entry Price') &&
              signalData.containsKey('Signal') &&
              signalData['Signal'].toString().contains('Long')) {

            String symbol = signalData['Symbol'];
            double entryPrice = double.tryParse(signalData['Entry Price'].toString()) ?? 0.0;

            // Store or update position data if we haven't processed a buy yet
            if (!positions.containsKey(symbol)) {
              positions[symbol] = {
                'buyPrice': entryPrice,
                'timestamp': activity['timestamp'],
              };
            }
          }
        } catch (e) {
          print('Error parsing signal response: $e');
        }
      }
    }

    // Process buy activities again to match with signal data
    for (var activity in activities) {
      if (activity['action'] == 'buy' && !activity.containsKey('symbol')) {
        // Check each position to see if this buy is related
        for (String symbol in positions.keys) {
          // Skip Bitcoin position
          if (symbol == 'BTC') continue;

          // If position doesn't have an amount but has a timestamp that's before this buy
          if (!positions[symbol]!.containsKey('amount') &&
              positions[symbol]!.containsKey('timestamp') &&
              positions[symbol]!.containsKey('buyPrice')) {

            DateTime positionTime = DateTime.parse(positions[symbol]!['timestamp'].toString());
            DateTime buyTime = DateTime.parse(activity['timestamp'].toString());

            // If buy happened right after signal (within 5 minutes), associate it
            if (buyTime.difference(positionTime).inMinutes < 5) {
              double? amount = _extractAmount(activity);

              if (amount != null) {
                // Update position with amount
                positions[symbol]!['amount'] = amount;

                // Calculate PnL for this position
                double buyPrice = positions[symbol]!['buyPrice'];
                double currentPrice = await _getTokenCurrentPrice(symbol);
                double symbolPnL = amount * (currentPrice - buyPrice);
                autonomousPnL += symbolPnL;

                // We've matched this buy, so we can break
                break;
              }
            }
          }
        }
      }
    }

    return autonomousPnL;
  }

  // Helper method to extract amount from activity
  double? _extractAmount(Map<String, dynamic> activity) {
    if (activity.containsKey('amount')) {
      return double.tryParse(activity['amount'].toString());
    }
    return null;
  }

  // Estimate Bitcoin price at a given time
  Future<double> _estimateBitcoinPriceAtTime(String timestamp) async {
    // In production, this would call a historical price API
    // For now, use a simple estimation based on date
    DateTime time = DateTime.parse(timestamp);

    // Simple mock implementation
    if (time.isAfter(DateTime(2025, 1, 1))) {
      return 26000.0; // 2025 estimate
    } else if (time.isAfter(DateTime(2024, 1, 1))) {
      return 23000.0; // 2024 estimate
    }

    return 20000.0; // Default fallback
  }

  // Get current Bitcoin price
  Future<double> _getCurrentBitcoinPrice() async {
    // In production, this would call a price API
    return 28500.0; // Mock current price
  }

  // Get current token price
  Future<double> _getTokenCurrentPrice(String symbol) async {
    // In production, this would call a price API
    Map<String, double> mockPrices = {
      'ETH': 1950.0,
      'SOL': 155.0,
      'AVAX': 30.5,
      'MATIC': 0.82,
      'LINK': 13.75,
    };

    return mockPrices[symbol] ?? 10.0;
  }

  // Track a new PnL entry when a buy happens
  Future<void> recordBuyTransaction(String ticker, String action, double amount, double? buyPrice, String? symbol) async {
    // Update the agent's activities cache if we have it
    if (_agentActivities.containsKey(ticker)) {
      // Create a new transaction entry
      Map<String, dynamic> transaction = {
        'action': action,
        'timestamp': DateTime.now().toIso8601String(),
        'amount': amount,
      };

      // Add symbol and entry_price for autonomous trading
      if (symbol != null) {
        transaction['symbol'] = symbol;
      }

      if (buyPrice != null) {
        transaction['buy_price'] = buyPrice;
      }

      // Add to activities list
      if (_agentActivities[ticker]!.containsKey('activities')) {
        (_agentActivities[ticker]!['activities'] as List).add(transaction);
      } else {
        _agentActivities[ticker]!['activities'] = [transaction];
      }

      // Recalculate PnL
      await calculateAgentPnL(ticker, _agentActivities[ticker]!);

      // Refresh trending agents
      await fetchTrendingAgents();
    }
  }
}