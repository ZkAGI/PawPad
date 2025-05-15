import 'package:flutter/material.dart';
import '../services/agent_pnl_calculation_service.dart';

/// Extension methods for the AgentProvider class to add PnL tracking capabilities
extension AgentPnLExtension on dynamic {
  /// Records a buy transaction for PnL tracking
  Future<void> recordBuyTransaction({
    required String ticker,
    required double amount,
    double? buyPrice,
    String? symbol,
    required String entryPrice,
  }) async {
    try {
      // Create a transaction record
      Map<String, dynamic> transaction = {
        'action': 'buy',
        'timestamp': DateTime.now().toIso8601String(),
        'amount': amount,
      };

      // Add optional fields if provided
      if (buyPrice != null) {
        transaction['buy_price'] = buyPrice;
      }

      if (symbol != null && symbol.isNotEmpty) {
        transaction['symbol'] = symbol;
      }

      if (entryPrice.isNotEmpty) {
        transaction['entry_price'] = entryPrice;
      }

      // Update agent activities via the calculation service
      await AgentPnLCalculationService.updateAgentActivities(ticker, transaction);

      // If this is a current agent (AgentProvider instance), you might want to refresh data
      // This needs to be handled in the AgentProvider implementation
    } catch (e) {
      print('Error recording buy transaction: $e');
    }
  }

  /// Records a signal received for autonomous trading
  Future<void> recordSignalReceived({
    required String ticker,
    required Map<String, dynamic> signalResponse,
  }) async {
    try {
      // Create a transaction record
      Map<String, dynamic> transaction = {
        'action': 'signal_received',
        'timestamp': DateTime.now().toIso8601String(),
        'response': signalResponse,
      };

      // Update agent activities via the calculation service
      await AgentPnLCalculationService.updateAgentActivities(ticker, transaction);
    } catch (e) {
      print('Error recording signal received: $e');
    }
  }

  /// Calculates and returns PnL for a specific agent
  Future<Map<String, dynamic>> getAgentPnL(String ticker) async {
    try {
      return await AgentPnLCalculationService.calculateAgentPnL(ticker);
    } catch (e) {
      print('Error getting agent PnL: $e');
      return {
        'ticker': ticker,
        'totalPnL': 0.0,
        'error': e.toString(),
      };
    }
  }

  /// Gets the list of trending agents sorted by PnL
  Future<List<Map<String, dynamic>>> getTrendingAgents() async {
    try {
      return await AgentPnLCalculationService.getTrendingAgents();
    } catch (e) {
      print('Error getting trending agents: $e');
      return [];
    }
  }
}

/// Mixin to add PnL tracking to an AgentProvider
mixin AgentPnLTracking {
  /// Formats a PnL value with + or - sign and fixed decimal places
  static String formatPnL(double pnl, {int decimalPlaces = 2}) {
    final isPositive = pnl >= 0;
    return '${isPositive ? '+' : ''}${pnl.toStringAsFixed(decimalPlaces)}';
  }

  /// Returns a color based on PnL value (green for positive, red for negative)
  static Color getPnLColor(double pnl, {double opacity = 1.0}) {
    return pnl >= 0
        ? Colors.green.withOpacity(opacity)
        : Colors.red.withOpacity(opacity);
  }

  /// Calculates percentage change from a buy price to current price
  static double calculatePercentageChange(double buyPrice, double currentPrice) {
    if (buyPrice <= 0) return 0.0;
    return ((currentPrice - buyPrice) / buyPrice) * 100;
  }

  /// Formats a percentage change with + or - sign and fixed decimal places
  static String formatPercentageChange(double percentageChange) {
    final isPositive = percentageChange >= 0;
    return '${isPositive ? '+' : ''}${percentageChange.toStringAsFixed(2)}%';
  }
}

/// Widget to display an agent's PnL summary
class AgentPnLSummary extends StatelessWidget {
  final String ticker;
  final Future<Map<String, dynamic>> Function(String) getPnLCallback;

  const AgentPnLSummary({
    Key? key,
    required this.ticker,
    required this.getPnLCallback,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: getPnLCallback(ticker),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Text(
              'Error loading PnL data',
              style: TextStyle(color: Colors.red),
            ),
          );
        }

        final pnlData = snapshot.data!;
        final double totalPnL = pnlData['totalPnL'] ?? 0.0;
        final bool isProfitable = totalPnL >= 0;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1F2641),
                  Color(0xFF1A1F38),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Performance',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildPnLInfoCard(
                        title: 'Total PnL',
                        value: AgentPnLTracking.formatPnL(totalPnL),
                        isPositive: isProfitable,
                      ),
                    ),
                    if (pnlData['bitcoinPnL'] != null) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildPnLInfoCard(
                          title: 'Bitcoin PnL',
                          value: AgentPnLTracking.formatPnL(pnlData['bitcoinPnL']),
                          isPositive: pnlData['bitcoinPnL'] >= 0,
                        ),
                      ),
                    ],
                    if (pnlData['autonomousPnL'] != null) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildPnLInfoCard(
                          title: 'Trading PnL',
                          value: AgentPnLTracking.formatPnL(pnlData['autonomousPnL']),
                          isPositive: pnlData['autonomousPnL'] >= 0,
                        ),
                      ),
                    ],
                  ],
                ),

                // Show positions if available
                if (pnlData['positions'] != null &&
                    (pnlData['positions'] as Map<String, dynamic>).isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Open Positions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Column(
                    children: [
                      for (var entry in (pnlData['positions'] as Map<String, dynamic>).entries)
                        _buildPositionItem(entry.key, entry.value),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPnLInfoCard({
    required String title,
    required String value,
    required bool isPositive,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isPositive ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPositionItem(String symbol, Map<String, dynamic> position) {
    final double buyPrice = position['buyPrice'] ?? 0.0;
    final double currentPrice = position['currentPrice'] ?? 0.0;
    final double pnl = position['pnl'] ?? 0.0;
    final bool isPositive = pnl >= 0;

    final double percentageChange =
    AgentPnLTracking.calculatePercentageChange(buyPrice, currentPrice);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isPositive ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Symbol
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              symbol,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Buy price and current price
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Buy: ${buyPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                Text(
                  'Current: ${currentPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),

          // PnL and percentage
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                AgentPnLTracking.formatPnL(pnl),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isPositive ? Colors.green : Colors.red,
                ),
              ),
              Text(
                AgentPnLTracking.formatPercentageChange(percentageChange),
                style: TextStyle(
                  fontSize: 12,
                  color: isPositive ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}