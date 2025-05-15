import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

class AgentPnLService {
  // Base URL and API key
  static const String baseUrl = 'https://zynapse.zkagi.ai';
  static const String apiKey = 'zk-123321';

  // Fetch agent activities from the API
  static Future<Map<String, dynamic>> fetchAgentActivities(String ticker) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/activities/$ticker'),
        headers: {'api-key': apiKey},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load agent activities: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching agent activities: $e');
    }
  }

  // Calculate profit and loss for an agent based on its activities
  static Future<Map<String, dynamic>> calculateAgentPnL(String ticker) async {
    try {
      // Fetch the agent's activities
      final activitiesData = await fetchAgentActivities(ticker);

      // Initialize PnL data
      double totalPnL = 0.0;
      double bitcoinPnL = 0.0;
      double autonomousPnL = 0.0;

      // Maps to track entry prices for different tokens
      Map<String, Map<String, dynamic>> positions = {};

      if (activitiesData.containsKey('activities') && activitiesData['activities'] is List) {
        final activities = activitiesData['activities'] as List;

        for (var activity in activities) {
          // Check if the activity is a buy action
          if (activity['action'] == 'buy') {
            double? amount = _extractAmountFromActivity(activity);

            // Handle Bitcoin Buy & Hold
            if (activitiesData['isBuyAndHold'] == true && !activity.containsKey('symbol')) {
              // This is a Bitcoin buy
              if (amount != null) {
                double buyPrice = _getBitcoinPrice(activity);

                // Store position data
                positions['BTC'] = {
                  'amount': amount,
                  'buyPrice': buyPrice,
                  'timestamp': activity['timestamp'],
                };

                // Calculate current Bitcoin PnL
                double currentPrice = await _getCurrentBitcoinPrice();
                bitcoinPnL = amount * (currentPrice - buyPrice);
              }
            }
            // Handle Autonomous Trading
            else if (activitiesData['isFutureAndOptions'] == true && activity.containsKey('symbol')) {
              String symbol = activity['symbol'] ?? 'UNKNOWN';
              double entryPrice = activity['entry_price'] != null ?
              double.tryParse(activity['entry_price'].toString()) ?? 0.0 : 0.0;

              if (amount != null && entryPrice > 0) {
                // Store position data
                positions[symbol] = {
                  'amount': amount,
                  'buyPrice': entryPrice,
                  'timestamp': activity['timestamp'],
                };

                // Get current price and calculate PnL
                double currentPrice = await _getTokenCurrentPrice(symbol);
                double tokenPnL = amount * (currentPrice - entryPrice);
                autonomousPnL += tokenPnL;
              }
            }
          }

          // Handle signal received events to extract entry price if needed
          else if (activity['action'] == 'signal_received' &&
              activity.containsKey('response') &&
              activitiesData['isFutureAndOptions'] == true) {
            try {
              Map<String, dynamic> signalData =
              json.decode(activity['response'] as String);

              if (signalData.containsKey('Symbol') &&
                  signalData.containsKey('Entry Price') &&
                  signalData.containsKey('Signal') &&
                  signalData['Signal'].toString().contains('Long')) {
                String symbol = signalData['Symbol'];

                // Store entry price from signal if we don't have it from a buy action
                if (!positions.containsKey(symbol)) {
                  double entryPrice = double.tryParse(signalData['Entry Price'].toString()) ?? 0.0;

                  // We don't have the amount here, will need to be updated when the buy action comes
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
      }

      // Calculate total PnL
      totalPnL = bitcoinPnL + autonomousPnL;

      // Return the PnL data along with positions
      return {
        'ticker': ticker,
        'totalPnL': totalPnL,
        'bitcoinPnL': bitcoinPnL,
        'autonomousPnL': autonomousPnL,
        'positions': positions,
        'isBuyAndHold': activitiesData['isBuyAndHold'] ?? false,
        'isFutureAndOptions': activitiesData['isFutureAndOptions'] ?? false,
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

  // Helper method to extract amount from an activity
  static double? _extractAmountFromActivity(Map<String, dynamic> activity) {
    // First check if amount is directly available
    if (activity.containsKey('amount')) {
      return double.tryParse(activity['amount'].toString()) ?? null;
    }

    // If not, try to extract from other fields
    return null;
  }

  // Helper method to get Bitcoin buy price
  static double _getBitcoinPrice(Map<String, dynamic> activity) {
    // If we have buy_price directly, use it
    if (activity.containsKey('buy_price')) {
      return double.tryParse(activity['buy_price'].toString()) ?? 20000.0;
    }

    // If we don't have the price, estimate based on timestamp
    // This is a placeholder - in production you should use a history API
    DateTime timestamp = DateTime.parse(activity['timestamp'].toString());

    // Simple mock implementation - replace with actual price fetching logic
    // As a fallback, use a reasonable estimate based on recent BTC prices
    if (timestamp.isAfter(DateTime(2025, 1, 1))) {
      return 25000.0; // 2025 price estimate
    } else if (timestamp.isAfter(DateTime(2024, 1, 1))) {
      return 22000.0; // 2024 price estimate
    }

    return 20000.0; // Default fallback
  }

  // Helper method to get current Bitcoin price
  static Future<double> _getCurrentBitcoinPrice() async {
    // In a real app, this would call a price API
    // As a placeholder, return a mock price
    return 26500.0;
  }

  // Helper method to get current token price
  static Future<double> _getTokenCurrentPrice(String symbol) async {
    // In a real app, this would call a price API
    // As a placeholder, generate a price based on symbol

    // This is just for demonstration - replace with actual API call
    Map<String, double> mockPrices = {
      'ETH': 1800.0,
      'SOL': 140.0,
      'AVAX': 28.0,
      'MATIC': 0.75,
      'LINK': 12.5,
    };

    return mockPrices[symbol] ?? 10.0;
  }

  // Fetch trending agents sorted by PnL
  static Future<List<Map<String, dynamic>>> getTrendingAgents() async {
    try {
      // In a real app, you might have an API endpoint that returns trending agents
      // For now, we'll use a hard-coded list and calculate their PnL
      List<String> agentTickers = ['Test42', 'Nia', 'TradeX', 'CryptoWhiz', 'TrendFollower'];

      List<Map<String, dynamic>> agentsWithPnL = [];

      for (String ticker in agentTickers) {
        try {
          Map<String, dynamic> pnlData = await calculateAgentPnL(ticker);
          agentsWithPnL.add(pnlData);
        } catch (e) {
          print('Error getting PnL for $ticker: $e');
          // Add agent with error state
          agentsWithPnL.add({
            'ticker': ticker,
            'totalPnL': 0.0,
            'error': 'Failed to calculate PnL',
          });
        }
      }

      // Sort agents by total PnL (descending)
      agentsWithPnL.sort((a, b) => (b['totalPnL'] as double).compareTo(a['totalPnL'] as double));

      // Return top 5 trending agents
      return agentsWithPnL.take(5).toList();
    } catch (e) {
      print('Error getting trending agents: $e');
      return [];
    }
  }
}

// Widget to display agent with PnL
class AgentPnLCard extends StatelessWidget {
  final Map<String, dynamic> agentData;

  const AgentPnLCard({
    Key? key,
    required this.agentData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String ticker = agentData['ticker'] ?? 'Unknown';
    final double pnl = agentData['totalPnL'] ?? 0.0;
    final bool isProfitable = pnl >= 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Left: Agent image
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.grey.shade200,
              child: Icon(
                Icons.person,
                size: 24,
                color: Colors.grey.shade700,
              ),
            ),

            // Middle: Agent name and type
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticker,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        if (agentData['isBuyAndHold'] == true)
                          _buildTradeTypeChip('Bitcoin', Colors.orange),
                        if (agentData['isBuyAndHold'] == true && agentData['isFutureAndOptions'] == true)
                          SizedBox(width: 6),
                        if (agentData['isFutureAndOptions'] == true)
                          _buildTradeTypeChip('Auto', Colors.blue),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Right: PnL status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isProfitable ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${isProfitable ? "+" : ""}${pnl.toStringAsFixed(2)}',
                style: TextStyle(
                  color: isProfitable ? Colors.green.shade700 : Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTradeTypeChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
         // color: color.shade700,
        ),
      ),
    );
  }
}

// Widget to display trending agents list
class TrendingAgentsList extends StatefulWidget {
  const TrendingAgentsList({Key? key}) : super(key: key);

  @override
  State<TrendingAgentsList> createState() => _TrendingAgentsListState();
}

class _TrendingAgentsListState extends State<TrendingAgentsList> {
  List<Map<String, dynamic>> _trendingAgents = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTrendingAgents();
  }

  Future<void> _loadTrendingAgents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final agents = await AgentPnLService.getTrendingAgents();
      setState(() {
        _trendingAgents = agents;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Error: $_error', style: TextStyle(color: Colors.red)),
            ElevatedButton(
              onPressed: _loadTrendingAgents,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_trendingAgents.isEmpty) {
      return const Center(
        child: Text('No trending agents available'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Trending Agents',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _trendingAgents.length,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemBuilder: (context, index) {
            return AgentPnLCard(agentData: _trendingAgents[index]);
          },
        ),
      ],
    );
  }
}