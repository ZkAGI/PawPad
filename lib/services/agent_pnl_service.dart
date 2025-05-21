import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service for calculating profit and loss (PnL) for trading agents
class AgentPnLService {
  // API constants
  static const String apiUrl = 'https://zynapse.zkagi.ai';
  static const String apiKey = 'zk-123321';

  // Last refresh time to avoid frequent API calls
  static DateTime? _lastRefreshTime;
  static List<Map<String, dynamic>>? _cachedTrendingAgents;

  /// Fetch all agent tickers from the API
  static Future<List<String>> getAllAgentTickers() async {
    try {
      final response = await http.get(
        Uri.parse('$apiUrl/agent_ticker'),
        headers: {'api-key': apiKey},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          return data.map((item) => item.toString()).toList();
        } else if (data['tickers'] is List) {
          return (data['tickers'] as List).map((item) => item.toString()).toList();
        } else {
          print('Unexpected response format: $data');
          return [];
        }
      } else {
        print('Error fetching agent tickers: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Exception fetching agent tickers: $e');
      return [];
    }
  }

  /// Fetch agent activities from the API
  static Future<Map<String, dynamic>> getAgentActivities(String ticker) async {
    try {
      final response = await http.get(
        Uri.parse('$apiUrl/activities/$ticker'),
        headers: {'api-key': apiKey},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('Error fetching activities for $ticker: ${response.statusCode}');
        return {
          'error': 'Failed to fetch activities',
          'activities': [],
        };
      }
    } catch (e) {
      print('Exception fetching activities for $ticker: $e');
      return {
        'error': 'Exception: $e',
        'activities': [],
      };
    }
  }

  /// Calculate PnL for a specific agent
  static Future<Map<String, dynamic>> calculateAgentPnL(String ticker) async {
    print('---- PnL calculation START for $ticker ----');
    try {
      final activities = await getAgentActivities(ticker);
      print('Raw activities JSON for $ticker: $activities');

      double totalPnL = 0.0;

      // Extract flags from either direct or nested structure
      bool isBuyAndHold = false;
      bool isAutonomous = false;
      bool isCustomStrategy = false;

      // Handle nested structure (if response has a data array)
      List activityList = [];
      if (activities.containsKey('data') && activities['data'] is List && activities['data'].isNotEmpty) {
        final dataObj = activities['data'][0];
        activityList = dataObj['activities'] ?? [];
        isBuyAndHold = dataObj['isBuyAndHold'] ?? false;
        isAutonomous = dataObj['isFutureAndOptions'] ?? false;
        isCustomStrategy = dataObj['isCustomStrategy'] != null;
      } else {
        // Direct structure
        activityList = activities['activities'] is List ? activities['activities'] : [];
        isBuyAndHold = activities['isBuyAndHold'] ?? false;
        isAutonomous = activities['isFutureAndOptions'] ?? false;
        isCustomStrategy = activities['isCustomStrategy'] != null;
      }

      print('Found ${activityList.length} activities; isBuyAndHold=$isBuyAndHold, isAutonomous=$isAutonomous, isCustom=$isCustomStrategy');

      // For debugging, print all activities to see what we're working with
      print('Activity types in the data:');
      for (var i = 0; i < activityList.length; i++) {
        print('Activity $i - type: ${activityList[i]['type']}, action: ${activityList[i]['action']}');
      }

      for (var i = 0; i < activityList.length; i++) {
        final activity = activityList[i];

        // Use OR condition (not AND) to catch all relevant activities
        bool isBuyActivity = activity['action'] == 'buy';
        bool isAutonomousBuy = activity['type'] == 'autonomous_buy';

        if (!isBuyActivity && !isAutonomousBuy) {
          continue; // Skip non-buy activities
        }

        print('\n→ Processing activity #$i:');
        print('- type: ${activity['type']}, action: ${activity['action']}');

        // Parse amount - handle both direct values and nested MongoDB-style objects
        double? amount;
        if (activity['amount'] is Map && activity['amount'].containsKey('\$numberDouble')) {
          amount = double.tryParse(activity['amount']['\$numberDouble'].toString());
        } else if (activity['amount'] != null) {
          amount = double.tryParse(activity['amount'].toString());
        }

        print('- amount: $amount');

        if (amount == null || amount == 0) {
          print('- skipping: invalid or zero amount');
          continue;
        }

        // Parse entry price
        String? entryPriceStr = activity['entryPrice']?.toString() ?? activity['entry_price']?.toString();
        if (entryPriceStr == null) {
          print('- skipping: missing entry price');
          continue;
        }

        double entryPrice = double.tryParse(entryPriceStr) ?? 0.0;
        print('- entry price: $entryPrice');

        // Get symbol
        String? symbol = activity['symbol']?.toString();
        if (symbol == null) {
          print('- skipping: missing symbol');
          continue;
        }
        print('- symbol: $symbol');

        // Extract base symbol (remove /USDT if present)
        final baseSymbol = symbol.contains('/')
            ? symbol.split('/')[0]
            : symbol;

        // Get current price (replace with API call in production)
        double currentPrice;
        if (baseSymbol == 'BTC') currentPrice = 32500.0;
        else if (baseSymbol == 'ETH') currentPrice = 2350.0;
        else if (baseSymbol == 'SOL') currentPrice = 165.0;
        else if (baseSymbol == 'AVAX') currentPrice = 32.8;
        else if (baseSymbol == 'TRX') currentPrice = 0.29;
        else currentPrice = 10.0;

        print('- current price: $currentPrice');

        // Calculate PnL for this activity
        double pnlForThis = amount * (currentPrice - entryPrice);
        print('- PnL calculation: $amount * ($currentPrice - $entryPrice) = $pnlForThis');

        // Use 8 decimal places for small values
        print('- PnL (8 decimals): ${pnlForThis.toStringAsFixed(8)}');

        totalPnL += pnlForThis;
      }

      // Log total PnL with more decimal places for small values
      print('\n---- TOTAL PnL for $ticker ----');
      print('Raw value: $totalPnL');
      print('2 decimals: ${totalPnL.toStringAsFixed(2)}');
      print('8 decimals: ${totalPnL.toStringAsFixed(8)}');

      // For very small values, use scientific notation or more decimal places
      String formattedPnL;
      if (totalPnL.abs() < 0.01) {
        formattedPnL = totalPnL.toStringAsFixed(8);
      } else {
        formattedPnL = totalPnL.toStringAsFixed(2);
      }

      print('Formatted for display: $formattedPnL');
      print('---- PnL calculation END for $ticker ----');

      return {
        'ticker': ticker,
        'totalPnL': totalPnL,
        'formattedPnL': formattedPnL,
        'isBuyAndHold': isBuyAndHold,
        'isFutureAndOptions': isAutonomous,
        'isCustomStrategy': isCustomStrategy,
      };
    } catch (e) {
      print('Error in PnL calc for $ticker: $e');
      return {
        'ticker': ticker,
        'totalPnL': 0.0,
        'formattedPnL': '0.00',
        'error': e.toString(),
      };
    }
  }

  // static Future<Map<String, dynamic>> calculateAgentPnL(String ticker) async {
  //   try {
  //     // Get agent activities
  //     final activities = await getAgentActivities(ticker);
  //
  //     // Initialize values
  //     double totalPnL = 0.0;
  //     bool isBitcoin = activities['isBuyAndHold'] ?? false;
  //     bool isAutonomous = activities['isFutureAndOptions'] ?? false;
  //     bool isCustomStrategy = activities['isCustomStrategy'] ?? false;
  //
  //     // Process activities to calculate PnL
  //     if (activities.containsKey('activities') && activities['activities'] is List) {
  //       List activityList = activities['activities'] as List;
  //
  //       // Find buy activities
  //       for (var activity in activityList) {
  //         if (activity['action'] == 'buy') {
  //           double? amount;
  //
  //           // Try to extract amount
  //           if (activity.containsKey('amount')) {
  //             amount = double.tryParse(activity['amount'].toString());
  //           }
  //
  //           if (amount != null) {
  //             double buyPrice = 0.0;
  //             double currentPrice = 0.0;
  //
  //             // Handle Bitcoin buy
  //             if (isBitcoin && (!activity.containsKey('symbol') || activity['symbol'] == 'BTC')) {
  //               // Get buy price from activity or use default
  //               if (activity.containsKey('buy_price')) {
  //                 buyPrice = double.tryParse(activity['buy_price'].toString()) ?? 20000.0;
  //               } else {
  //                 buyPrice = 20000.0; // Default fallback
  //               }
  //
  //               // Mock current Bitcoin price (replace with API call in production)
  //               currentPrice = 32500.0;
  //
  //               // Calculate PnL
  //               double btcPnL = amount * (currentPrice - buyPrice);
  //               totalPnL += btcPnL;
  //             }
  //
  //             // Handle autonomous trading buy
  //             if ((isAutonomous || isCustomStrategy) && activity.containsKey('symbol') && activity['symbol'] != 'BTC') {
  //               String symbol = activity['symbol'];
  //
  //               // Get entry price
  //               if (activity.containsKey('entry_price')) {
  //                 buyPrice = double.tryParse(activity['entry_price'].toString()) ?? 0.0;
  //               }
  //
  //               // Get current price based on symbol (mock values)
  //               if (symbol == 'ETH') currentPrice = 2350.0;
  //               else if (symbol == 'SOL') currentPrice = 165.0;
  //               else if (symbol == 'AVAX') currentPrice = 32.8;
  //               else currentPrice = 10.0; // Default fallback
  //
  //               // Calculate PnL
  //               double tokenPnL = amount * (currentPrice - buyPrice);
  //               totalPnL += tokenPnL;
  //             }
  //           }
  //         }
  //       }
  //     }
  //
  //     // Return result
  //     return {
  //       'ticker': ticker,
  //       'totalPnL': totalPnL,
  //       'isBuyAndHold': isBitcoin,
  //       'isFutureAndOptions': isAutonomous,
  //       'isCustomStrategy': isCustomStrategy,
  //     };
  //   } catch (e) {
  //     print('Error calculating PnL for agent $ticker: $e');
  //     return {
  //       'ticker': ticker,
  //       'totalPnL': 0.0,
  //       'error': e.toString(),
  //     };
  //   }
  // }

  /// Get trending agents sorted by PnL
  /// This method will refresh the data at most once per hour
  static Future<List<Map<String, dynamic>>> getTrendingAgents({bool forceRefresh = false}) async {
    // Check if we have cached data and it's less than 1 hour old
    final now = DateTime.now();
    if (!forceRefresh &&
        _lastRefreshTime != null &&
        _cachedTrendingAgents != null &&
        now.difference(_lastRefreshTime!).inMinutes < 60) {
      return _cachedTrendingAgents!;
    }

    try {
      // Get all agent tickers
      final tickers = await getAllAgentTickers();
      print('Found ${tickers.length} agent tickers');

      if (tickers.isEmpty) {
        return _getDefaultTrendingAgents();
      }

      List<Map<String, dynamic>> agentsWithPnL = [];

      // Calculate PnL for each agent
      for (String ticker in tickers) {
        try {
          final pnlData = await calculateAgentPnL(ticker);
          agentsWithPnL.add(pnlData);
        } catch (e) {
          print('Error calculating PnL for $ticker: $e');
          // Add with 0 PnL instead of skipping
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

      // Take top 5 or all if less than 5
      final topAgents = agentsWithPnL.length > 5
          ? agentsWithPnL.sublist(0, 5)
          : agentsWithPnL;

      // Update cache
      _cachedTrendingAgents = topAgents;
      _lastRefreshTime = now;

      return topAgents;
    } catch (e) {
      print('Error getting trending agents: $e');

      // If we have cached data, return it even if it's old
      if (_cachedTrendingAgents != null) {
        return _cachedTrendingAgents!;
      }

      // Otherwise return default mock data
      return _getDefaultTrendingAgents();
    }
  }

  /// Generate default trending agents for fallback
  static List<Map<String, dynamic>> _getDefaultTrendingAgents() {
    return [
      {'ticker': 'Test42', 'totalPnL': 152.75, 'isBuyAndHold': true, 'isFutureAndOptions': false},
      {'ticker': 'Nia', 'totalPnL': 89.32, 'isBuyAndHold': false, 'isFutureAndOptions': true},
      {'ticker': 'TradeX', 'totalPnL': 42.18, 'isBuyAndHold': true, 'isFutureAndOptions': true},
      {'ticker': 'CryptoWhiz', 'totalPnL': -12.65, 'isBuyAndHold': false, 'isFutureAndOptions': true},
      {'ticker': 'AlphaTrader', 'totalPnL': -28.90, 'isBuyAndHold': true, 'isFutureAndOptions': false},
    ];
  }

  /// Force refresh trending agents data
  static Future<List<Map<String, dynamic>>> refreshTrendingAgents() async {
    return getTrendingAgents(forceRefresh: true);
  }
}