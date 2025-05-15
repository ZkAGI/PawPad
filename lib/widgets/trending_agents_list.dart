
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/agent_pnl_tracking_provider.dart';

class TrendingAgentsList extends StatefulWidget {
  const TrendingAgentsList({Key? key}) : super(key: key);

  @override
  State<TrendingAgentsList> createState() => _TrendingAgentsListState();
}

class _TrendingAgentsListState extends State<TrendingAgentsList> {
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
          return SizedBox(
            height: 150,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (trendingAgents.isEmpty) {
          return SizedBox(
            height: 150,
            child: Center(
              child: Text(
                'No trending agents available',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          );
        }

        return SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: trendingAgents.length,
            itemBuilder: (context, index) {
              final agent = trendingAgents[index];
              final double pnl = agent['totalPnL'] ?? 0.0;
              final bool isProfitable = pnl >= 0;

              return Card(
                margin: const EdgeInsets.only(right: 12),
                child: Container(
                  width: 120,
                  padding: const EdgeInsets.all(8),
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
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Left: Agent Image
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.grey.shade200,
                        child: Icon(
                          Icons.person,
                          size: 30,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Middle: Agent Name
                      Text(
                        agent['name'] ?? 'Agent',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Right end: PNL status
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isProfitable
                              ? Colors.green.withOpacity(0.2)
                              : Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${isProfitable ? "+" : ""}${pnl.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: isProfitable ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// Widget for displaying a detailed agent PnL card (for viewing all agents)
class AgentPnLDetailCard extends StatelessWidget {
  final Map<String, dynamic> agent;

  const AgentPnLDetailCard({
    Key? key,
    required this.agent,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String name = agent['name'] ?? 'Unknown';
    final double pnl = agent['totalPnL'] ?? 0.0;
    final bool isProfitable = pnl >= 0;
    final bool isBitcoin = agent['isBuyAndHold'] ?? false;
    final bool isAutonomous = agent['isFutureAndOptions'] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          if (isBitcoin)
                            _buildTradeTypeChip('Bitcoin', Colors.orange),
                          if (isBitcoin && isAutonomous)
                            SizedBox(width: 6),
                          if (isAutonomous)
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