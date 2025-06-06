import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter_js/extensions/fetch.dart';
import 'package:http/http.dart' as http;

class AgentPnLCalculationService {
  // Base URL and API key
  static const String baseUrl = 'https://zynapse.zkagi.ai';
  static const String apiKey = 'zk-123321';

  // Main method to calculate PnL for an agent
  static Future<Map<String, dynamic>> calculateAgentPnL(String ticker) async {
    try {
      // Fetch agent activities from the API
      final activities = await fetchAgentActivities(ticker);

      // Return early if there was an error or no activities
      if (activities.containsKey('error') ||
          !activities.containsKey('activities') ||
          (activities['activities'] as List).isEmpty) {
        return {
          'ticker': ticker,
          'totalPnL': 0.0,
          'error': activities.containsKey('error') ? activities['error'] : 'No activities found',
        };
      }

      // Extract trading type flags
      final bool isBuyAndHold = activities['isBuyAndHold'] ?? false;
      final bool isFutureAndOptions = activities['isFutureAndOptions'] ?? false;

      // Initialize PnL variables
      double bitcoinPnL = 0.0;
      double autonomousPnL = 0.0;
      Map<String, Map<String, dynamic>> positions = {};

      // Calculate Bitcoin PnL if enabled
      if (isBuyAndHold) {
        bitcoinPnL = await calculateBitcoinPnL(activities['activities'], positions);
      }

      // Calculate Autonomous Trading PnL if enabled
      if (isFutureAndOptions) {
        autonomousPnL = await calculateAutonomousPnL(activities['activities'], positions);
      }

      // Calculate total PnL
      double totalPnL = bitcoinPnL + autonomousPnL;

      // Return the results
      return {
        'ticker': ticker,
        'totalPnL': totalPnL,
        'bitcoinPnL': bitcoinPnL,
        'autonomousPnL': autonomousPnL,
        'positions': positions,
        'isBuyAndHold': isBuyAndHold,
        'isFutureAndOptions': isFutureAndOptions,
      };
    } catch (e) {
      print('Error calculating PnL for agent $ticker: $e');
      return {
        'ticker': ticker,
        'totalPnL': 0.0,
        'error': e.toString(),
      };
    }
  }

  // Fetch activities for a specific agent
  static Future<Map<String, dynamic>> fetchAgentActivities(String ticker) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/activities/$ticker'),
        headers: {'api-key': apiKey},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('Error fetching activities: ${response.statusCode}');
        return {
          'error': 'Failed to fetch activities: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Exception fetching activities: $e');
      return {
        'error': 'Exception fetching activities: $e',
      };
    }
  }

  // Calculate PnL for Bitcoin Buy & Hold strategy
  static Future<double> calculateBitcoinPnL(List activities, Map<String, Map<String, dynamic>> positions) async {
    double bitcoinPnL = 0.0;

    try {
      // Find buy activities for Bitcoin
      List<Map<String, dynamic>> bitcoinBuys = [];

      for (var activity in activities) {
        // Convert activity to Map if it's not already
        Map<String, dynamic> activityMap = activity is Map<String, dynamic>
            ? activity
            : json.decode(json.encode(activity));

        if (activityMap['action'] == 'buy' &&
            (!activityMap.containsKey('symbol') || activityMap['symbol'] == 'BTC')) {
          // This is a Bitcoin buy
          double? amount = extractAmount(activityMap);

          if (amount != null) {
            // Add to bitcoin buys list
            bitcoinBuys.add({
              ...activityMap,
              'calculatedAmount': amount,
            });
          }
        }
      }

      // If no buys found, return 0
      if (bitcoinBuys.isEmpty) {
        return 0.0;
      }

      // Sort buys by timestamp (newest first)
      bitcoinBuys.sort((a, b) {
        DateTime aTime = DateTime.parse(a['timestamp'].toString());
        DateTime bTime = DateTime.parse(b['timestamp'].toString());
        return bTime.compareTo(aTime);
      });

      // Get the most recent buy
      final latestBuy = bitcoinBuys.first;
      final double buyAmount = latestBuy['calculatedAmount'];

      // Get the buy price
      double buyPrice;
      if (latestBuy.containsKey('buy_price')) {
        // Use the buy price from the activity
        buyPrice = double.parse(latestBuy['buy_price'].toString());
      } else {
        // Estimate the buy price based on the timestamp
        buyPrice = await estimateBitcoinPriceAtTime(latestBuy['timestamp'].toString());
      }

      // Get current price
      double currentPrice = await getCurrentBitcoinPrice();

      // Calculate PnL
      bitcoinPnL = buyAmount * (currentPrice - buyPrice);

      // Store position data
      positions['BTC'] = {
        'amount': buyAmount,
        'buyPrice': buyPrice,
        'currentPrice': currentPrice,
        'pnl': bitcoinPnL,
        'timestamp': latestBuy['timestamp'],
      };
    } catch (e) {
      print('Error calculating Bitcoin PnL: $e');
    }

    return bitcoinPnL;
  }

  // Calculate PnL for Autonomous Trading
  static Future<double> calculateAutonomousPnL(List activities, Map<String, Map<String, dynamic>> positions) async {
    double autonomousPnL = 0.0;

    try {
      // Extract signals and their associated buys
      Map<String, Map<String, dynamic>> signalData = {};

      // First pass: extract all signal_received activities
      for (var activity in activities) {
        // Convert activity to Map if it's not already
        Map<String, dynamic> activityMap = activity is Map<String, dynamic>
            ? activity
            : json.decode(json.encode(activity));

        if (activityMap['action'] == 'signal_received' && activityMap.containsKey('response')) {
          try {
            // Parse the response
            Map<String, dynamic> response = activityMap['response'] is String
                ? json.decode(activityMap['response'])
                : activityMap['response'];

            if (response.containsKey('Symbol') &&
                response.containsKey('Signal') &&
                response['Signal'].toString().contains('Long')) {

              String symbol = response['Symbol'];
              double entryPrice = 0.0;

              if (response.containsKey('Entry Price')) {
                entryPrice = double.tryParse(response['Entry Price'].toString()) ?? 0.0;
              }

              signalData[symbol] = {
                'entryPrice': entryPrice,
                'timestamp': activityMap['timestamp'],
                'signal': response['Signal'],
              };
            }
          } catch (e) {
            print('Error parsing signal response: $e');
          }
        }
      }

      // Second pass: match buy activities to signals
      for (var activity in activities) {
        // Convert activity to Map if it's not already
        Map<String, dynamic> activityMap = activity is Map<String, dynamic>
            ? activity
            : json.decode(json.encode(activity));

        if (activityMap['action'] == 'buy') {
          double? amount = extractAmount(activityMap);

          if (amount != null) {
            // Check if this buy has a symbol
            if (activityMap.containsKey('symbol') && activityMap['symbol'] != 'BTC') {
              // This is an autonomous trading buy with symbol
              String symbol = activityMap['symbol'];
              double entryPrice = 0.0;

              // Get entry price from activity or from signal data
              if (activityMap.containsKey('entry_price')) {
                entryPrice = double.tryParse(activityMap['entry_price'].toString()) ?? 0.0;
              } else if (signalData.containsKey(symbol)) {
                entryPrice = signalData[symbol]!['entryPrice'];
              }

              if (entryPrice > 0) {
                // Get current price for the token
                double currentPrice = await getTokenCurrentPrice(symbol);

                // Calculate PnL for this position
                double positionPnL = amount * (currentPrice - entryPrice);
                autonomousPnL += positionPnL;

                // Store position data
                positions[symbol] = {
                  'amount': amount,
                  'buyPrice': entryPrice,
                  'currentPrice': currentPrice,
                  'pnl': positionPnL,
                  'timestamp': activityMap['timestamp'],
                };
              }
            } else {
              // This could be a buy related to a signal without a symbol
              // Try to match it with a signal by timestamp
              String? matchedSymbol;

              for (String symbol in signalData.keys) {
                // If we don't have a position for this symbol yet
                if (!positions.containsKey(symbol)) {
                  DateTime signalTime = DateTime.parse(signalData[symbol]!['timestamp']);
                  DateTime buyTime = DateTime.parse(activityMap['timestamp']);

                  // If buy happened after signal and within 5 minutes
                  if (buyTime.isAfter(signalTime) &&
                      buyTime.difference(signalTime).inMinutes < 5) {
                    matchedSymbol = symbol;
                    break;
                  }
                }
              }

              if (matchedSymbol != null) {
                double entryPrice = signalData[matchedSymbol]!['entryPrice'];

                if (entryPrice > 0) {
                  // Get current price for the token
                  double currentPrice = await getTokenCurrentPrice(matchedSymbol);

                  // Calculate PnL for this position
                  double positionPnL = amount * (currentPrice - entryPrice);
                  autonomousPnL += positionPnL;

                  // Store position data
                  positions[matchedSymbol] = {
                    'amount': amount,
                    'buyPrice': entryPrice,
                    'currentPrice': currentPrice,
                    'pnl': positionPnL,
                    'timestamp': activityMap['timestamp'],
                  };
                }
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error calculating Autonomous PnL: $e');
    }

    return autonomousPnL;
  }

  // Helper method to extract amount from activity
  static double? extractAmount(Map<String, dynamic> activity) {
    // First try to get amount directly from the activity
    if (activity.containsKey('amount')) {
      return double.tryParse(activity['amount'].toString());
    }

    // If not available, try to extract from other fields
    return null;
  }

  // Helper method to estimate Bitcoin price at a given time
  static Future<double> estimateBitcoinPriceAtTime(String timestamp) async {
    // In a real app, this would call a price history API
    // For this demo, use a simple estimation based on date
    try {
      DateTime time = DateTime.parse(timestamp);

      // Simple mock implementation
      if (time.isAfter(DateTime(2025, 4, 1))) {
        return 30000.0; // April 2025 price estimate
      } else if (time.isAfter(DateTime(2025, 3, 1))) {
        return 28500.0; // March 2025 price estimate
      } else if (time.isAfter(DateTime(2025, 2, 1))) {
        return 27000.0; // February 2025 price estimate
      } else if (time.isAfter(DateTime(2025, 1, 1))) {
        return 25500.0; // January 2025 price estimate
      } else if (time.isAfter(DateTime(2024, 12, 1))) {
        return 24000.0; // December 2024 price estimate
      } else if (time.isAfter(DateTime(2024, 11, 1))) {
        return 22500.0; // November 2024 price estimate
      } else if (time.isAfter(DateTime(2024, 10, 1))) {
        return 21000.0; // October 2024 price estimate
      }

      return 20000.0; // Default fallback
    } catch (e) {
      print('Error estimating Bitcoin price: $e');
      return 20000.0; // Default fallback
    }
  }

  // Helper method to get current Bitcoin price
  static Future<double> getCurrentBitcoinPrice() async {
    // In production, this would call a price API
    // For this demo, use a mock price
    try {
      // This could be replaced with an actual API call in production
      return 32500.0; // Mock current Bitcoin price
    } catch (e) {
      print('Error getting current Bitcoin price: $e');
      return 30000.0; // Default fallback
    }
  }

  // Helper method to get current token price
  static Future<double> getTokenCurrentPrice(String symbol) async {
    // In production, this would call a price API
    // For this demo, use mock prices based on symbol
    try {
      // Mock prices for common tokens
      Map<String, double> mockPrices = {
        'ETH': 2350.0,
        'SOL': 165.0,
        'AVAX': 32.8,
        'MATIC': 0.86,
        'LINK': 14.25,
        'SHIB': 0.000018,
        'DOGE': 0.12,
        'UNI': 6.8,
        'AAVE': 95.0,
        'ADA': 0.45,
      };

      return mockPrices[symbol] ?? 10.0; // Return mock price or default
    } catch (e) {
      print('Error getting current token price: $e');
      return 10.0; // Default fallback
    }
  }

  // Helper method to fetch trending agents sorted by PnL
  static Future<List<Map<String, dynamic>>> getTrendingAgents() async {
    try {
      // In a real app, you might have an API endpoint that returns trending agents
      // For now, use a hardcoded list of agents and calculate their PnL
      List<String> agentTickers = ['Test42', 'Nia', 'TradeX', 'CryptoWhiz', 'AlphaTrader'];

      List<Map<String, dynamic>> agentsWithPnL = [];

      // Calculate PnL for each agent
      for (String ticker in agentTickers) {
        try {
          final pnlData = await calculateAgentPnL(ticker);
          agentsWithPnL.add(pnlData);
        } catch (e) {
          print('Error calculating PnL for $ticker: $e');
          agentsWithPnL.add({
            'ticker': ticker,
            'totalPnL': 0.0,
            'error': e.toString(),
          });
        }
      }

      // Sort by PnL (descending)
      agentsWithPnL.sort((a, b) =>
          (b['totalPnL'] as double).compareTo(a['totalPnL'] as double));

      return agentsWithPnL;
    } catch (e) {
      print('Error getting trending agents: $e');
      return [];
    }
  }

  // Update agent activities with a new transaction
  static Future<bool> updateAgentActivities(
      String ticker,
      Map<String, dynamic> transaction) async {
    try {
      // Fetch current activities
      final activities = await fetchAgentActivities(ticker);
      debug("activities ok ${activities}");

      if (activities.containsKey('error')) {
        return false;
      }

      // Add the new transaction
      (activities['activities'] as List).add(transaction);

      // Send updated activities back to the API
      final response = await http.post(
        Uri.parse('$baseUrl/update_activities/$ticker'),
        headers: {
          'Content-Type': 'application/json',
          'api-key': apiKey,
        },
        body: json.encode(activities),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating agent activities: $e');
      return false;
    }
  }
}