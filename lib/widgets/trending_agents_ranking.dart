import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/agent_pnl_tracking_provider.dart';

/// A widget that displays the top 5 trending agents sorted by PnL
class TrendingAgentsRanking extends StatefulWidget {
  const TrendingAgentsRanking({Key? key}) : super(key: key);

  @override
  State<TrendingAgentsRanking> createState() => _TrendingAgentsRankingState();
}

class _TrendingAgentsRankingState extends State<TrendingAgentsRanking> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTrendingAgents();
  }

  Future<void> _loadTrendingAgents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get the tracking provider and fetch trending agents
      final trackingProvider = Provider.of<AgentTrackingProvider>(context, listen: false);
      await trackingProvider.fetchTrendingAgents();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading trending agents: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AgentTrackingProvider>(
      builder: (context, trackingProvider, child) {
        final trendingAgents = trackingProvider.trendingAgents;

        if (_isLoading) {
          return const SizedBox(
            height: 280,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (trendingAgents.isEmpty) {
          return SizedBox(
            height: 100,
            child: Center(
              child: Text(
                'No trending agents available',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Trending Agents',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: _loadTrendingAgents,
                    tooltip: 'Refresh trending agents',
                  ),
                ],
              ),
            ),
            // List of trending agents (top 5)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: trendingAgents.length > 5 ? 5 : trendingAgents.length,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemBuilder: (context, index) {
                final agent = trendingAgents[index];
                final double pnl = agent['totalPnL'] ?? 0.0;
                final bool isProfitable = pnl >= 0;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Container(
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
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          // Ranking number (left side)
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _getRankColor(index),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                          // Left image (agent avatar)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.grey.shade200,
                              child: Icon(
                                Icons.person,
                                size: 24,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),

                          // Middle: Agent name and type
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  agent['name'] ?? 'Unknown',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (agent['isBuyAndHold'] == true)
                                      _buildTradeTypeChip('Bitcoin', Colors.orange),
                                    if (agent['isBuyAndHold'] == true && agent['isFutureAndOptions'] == true)
                                      SizedBox(width: 6),
                                    if (agent['isFutureAndOptions'] == true)
                                      _buildTradeTypeChip('Auto', Colors.blue),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Right end: PNL status
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isProfitable
                                  ? Colors.green.withOpacity(0.2)
                                  : Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${isProfitable ? "+" : ""}${pnl.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: isProfitable ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Color _getRankColor(int index) {
    switch (index) {
      case 0:
        return Colors.amber.shade700; // Gold
      case 1:
        return Colors.blueGrey.shade400; // Silver
      case 2:
        return Colors.brown.shade400; // Bronze
      default:
        return Colors.blueGrey.shade700; // Others
    }
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
          color: color,
        ),
      ),
    );
  }
}