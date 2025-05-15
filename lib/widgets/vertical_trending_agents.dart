// import 'package:flutter/material.dart';
// import '../services/agent_pnl_tracking_service.dart';
// import 'gradient_card.dart';
//
// /// Widget that displays top 5 trending agents in a vertical list
// class VerticalTrendingAgents extends StatefulWidget {
//   const VerticalTrendingAgents({Key? key}) : super(key: key);
//
//   @override
//   State<VerticalTrendingAgents> createState() => _VerticalTrendingAgentsState();
// }
//
// class _VerticalTrendingAgentsState extends State<VerticalTrendingAgents> {
//   List<Map<String, dynamic>> _trendingAgents = [];
//   bool _isLoading = true;
//   String? _error;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadTrendingAgents();
//   }
//
//   Future<void> _loadTrendingAgents() async {
//     setState(() {
//       _isLoading = true;
//       _error = null;
//     });
//
//     try {
//       final agents = await AgentPnLService.getTrendingAgents();
//
//       if (mounted) {
//         setState(() {
//           _trendingAgents = agents;
//           _isLoading = false;
//         });
//       }
//     } catch (e) {
//       if (mounted) {
//         setState(() {
//           _error = e.toString();
//           _isLoading = false;
//         });
//       }
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     if (_isLoading) {
//       return SizedBox(
//         height: 300,
//         child: Center(
//           child: CircularProgressIndicator(),
//         ),
//       );
//     }
//
//     if (_error != null) {
//       return SizedBox(
//         height: 300,
//         child: Center(
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Text('Error: $_error', style: TextStyle(color: Colors.red)),
//               const SizedBox(height: 8),
//               ElevatedButton(
//                 onPressed: _loadTrendingAgents,
//                 child: const Text('Retry'),
//               ),
//             ],
//           ),
//         ),
//       );
//     }
//
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Padding(
//           padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               const Text(
//                 'Trending Agents',
//                 style: TextStyle(
//                   fontSize: 20,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.white,
//                 ),
//               ),
//               IconButton(
//                 icon: const Icon(Icons.refresh, color: Colors.white),
//                 onPressed: _loadTrendingAgents,
//                 tooltip: 'Refresh',
//               ),
//             ],
//           ),
//         ),
//
//         // Top 5 trending agents in vertical list
//         ListView.builder(
//           shrinkWrap: true,
//           physics: const NeverScrollableScrollPhysics(),
//           itemCount: _trendingAgents.length > 5 ? 5 : _trendingAgents.length,
//           itemBuilder: (context, index) {
//             final agent = _trendingAgents[index];
//             return _buildAgentCard(agent, index);
//           },
//         ),
//       ],
//     );
//   }
//
//   Widget _buildAgentCard(Map<String, dynamic> agent, int index) {
//     final String ticker = agent['ticker'] ?? 'Unknown';
//     final double pnl = agent['totalPnL'] ?? 0.0;
//     final bool isProfitable = pnl >= 0;
//     final bool isBitcoin = agent['isBuyAndHold'] ?? false;
//     final bool isAutonomous = agent['isFutureAndOptions'] ?? false;
//
//     return Card(
//       margin: const EdgeInsets.only(bottom: 8),
//       child: gradientCard(
//         child: Padding(
//           padding: const EdgeInsets.all(12),
//           child: Row(
//             children: [
//               // Left: Agent image
//               CircleAvatar(
//                 radius: 24,
//                 backgroundColor: Colors.grey.shade200,
//                 child: Icon(
//                   Icons.person,
//                   size: 24,
//                   color: Colors.grey.shade700,
//                 ),
//               ),
//
//               // Middle: Agent name and type
//               Expanded(
//                 child: Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 12),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         ticker,
//                         style: const TextStyle(
//                           fontWeight: FontWeight.bold,
//                           fontSize: 16,
//                           color: Colors.white,
//                         ),
//                       ),
//                       const SizedBox(height: 4),
//                       Row(
//                         children: [
//                           if (isBitcoin)
//                             _buildTypeChip('Bitcoin', Colors.orange),
//                           if (isBitcoin && isAutonomous)
//                             const SizedBox(width: 6),
//                           if (isAutonomous)
//                             _buildTypeChip('Auto', Colors.blue),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//
//               // Right end: PNL status
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                 decoration: BoxDecoration(
//                   color: isProfitable
//                       ? Colors.green.withOpacity(0.2)
//                       : Colors.red.withOpacity(0.2),
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: Text(
//                   '${isProfitable ? "+" : ""}${pnl.toStringAsFixed(2)}',
//                   style: TextStyle(
//                     color: isProfitable ? Colors.green : Colors.red,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildTypeChip(String label, Color color) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
//       decoration: BoxDecoration(
//         color: color.withOpacity(0.2),
//         borderRadius: BorderRadius.circular(4),
//       ),
//       child: Text(
//         label,
//         style: TextStyle(
//           fontSize: 12,
//           color: color,
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'dart:async';
import '../services/agent_pnl_service.dart';
import 'gradient_card.dart';

/// Widget that displays top 5 trending agents in a vertical list
class VerticalTrendingAgents extends StatefulWidget {
  const VerticalTrendingAgents({Key? key}) : super(key: key);

  @override
  State<VerticalTrendingAgents> createState() => _VerticalTrendingAgentsState();
}

class _VerticalTrendingAgentsState extends State<VerticalTrendingAgents> {
  List<Map<String, dynamic>> _trendingAgents = [];
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadTrendingAgents();

    // Set up timer to refresh data every hour
    _refreshTimer = Timer.periodic(const Duration(hours: 1), (timer) {
      if (mounted) {
        _loadTrendingAgents(forceRefresh: true);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTrendingAgents({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final agents = await AgentPnLService.getTrendingAgents(forceRefresh: forceRefresh);

      if (mounted) {
        setState(() {
          _trendingAgents = agents;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _trendingAgents.isEmpty) {
      return SizedBox(
        height: 300,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null && _trendingAgents.isEmpty) {
      return SizedBox(
        height: 300,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Error: $_error', style: TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => _loadTrendingAgents(forceRefresh: true),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_trendingAgents.isEmpty) {
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
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
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
              // Show loading indicator when refreshing but still displaying old data
              _isLoading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: () => _loadTrendingAgents(forceRefresh: true),
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),

        // Top 5 trending agents in vertical list
        ..._trendingAgents.asMap().entries.map((entry) {
          int index = entry.key;
          Map<String, dynamic> agent = entry.value;
          return _buildAgentCard(agent, index);
        }).toList(),
      ],
    );
  }

  Widget _buildAgentCard(Map<String, dynamic> agent, int index) {
    final String ticker = agent['ticker'] ?? 'Unknown';
    final double pnl = agent['totalPnL'] ?? 0.0;
    final bool isProfitable = pnl >= 0;
    final bool isBitcoin = agent['isBuyAndHold'] ?? false;
    final bool isAutonomous = agent['isFutureAndOptions'] ?? false;
    final bool isCustomStrategy = agent['isCustomStrategy'] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: gradientCard(
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
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (isBitcoin)
                            _buildTypeChip('Bitcoin', Colors.orange),
                          if (isBitcoin && (isAutonomous || isCustomStrategy))
                            const SizedBox(width: 6),
                          if (isAutonomous)
                            _buildTypeChip('Auto', Colors.blue),
                          if (isCustomStrategy)
                            _buildTypeChip('Custom', Colors.purple),
                        ],
                      ),
                    ],
                  ),
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
  }

  Widget _buildTypeChip(String label, Color color) {
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