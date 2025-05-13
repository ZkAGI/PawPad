import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../services/agent_provider.dart';
import '../services/auth_provider.dart';
import 'package:image_picker/image_picker.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../services/agent_provider.dart';
import '../services/auth_provider.dart';
import 'package:image_picker/image_picker.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? selectedAgentName;

  @override
  void initState() {
    super.initState();
    // Initialize selected agent from provider when screen loads
    Future.delayed(Duration.zero, () {
      final agentProvider = Provider.of<AgentProvider>(context, listen: false);
      if (agentProvider.agentName != null) {
        setState(() {
          selectedAgentName = agentProvider.agentName;
        });
      }
    });
  }

  void _copyWalletAddress(BuildContext context, String? address) {
    if (address != null) {
      Clipboard.setData(ClipboardData(text: address));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wallet address copied to clipboard'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No wallet address available to copy'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final agentProvider = Provider.of<AgentProvider>(context);

    // Get all available agents (for now just dummy data + current agent)
    List<String> availableAgents = [
      if (agentProvider.agentName != null) agentProvider.agentName!,
      // Add any other agents from your storage
    ];

    // If no agent exists yet and not already in list, add the trending agents
    if (!agentProvider.hasAgent || availableAgents.isEmpty) {
      availableAgents = agentProvider.trendingAgents.map((agent) => agent['name']!).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('PawPad'),  // Changed to PawPad as requested
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Agent selector with dropdown and copy button
          if (agentProvider.hasAgent)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      // Agent icon
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.auto_awesome, color: Colors.orange.shade700),
                      ),
                      const SizedBox(width: 8),

                      // Agent dropdown
                      DropdownButton<String>(
                        value: selectedAgentName,
                        hint: const Text('Select Agent'),
                        underline: Container(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              selectedAgentName = newValue;
                            });
                            // Update selected agent in provider
                            // You'd implement logic to load the selected agent's data
                          }
                        },
                        items: availableAgents
                            .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                      ),

                      const Spacer(),

                      // Copy button for wallet address
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.copy, size: 20),
                          onPressed: () {
                            // Get the wallet address from the provider
                            final address = agentProvider.getAgentWalletAddress(selectedAgentName);
                            _copyWalletAddress(context, address);
                          },
                          tooltip: 'Copy wallet address',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Rest of the body content
          Expanded(
            child: agentProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner for new users
                  if (!agentProvider.hasAgent) _buildNoAgentBanner(context),

                  // Trending Agents Section
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Trending Agents',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildTrendingAgentsList(context, agentProvider),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      // + button at bottom right
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateAgentModal(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  // Banner widget for new users - no changes needed
  Widget _buildNoAgentBanner(BuildContext context) {
    // Existing code...
    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Create Your Trading Agent Today',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Get started with automated trading on Solana',
            style: TextStyle(
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _showCreateAgentModal(context),
            child: const Text('Create Agent'),
          ),
        ],
      ),
    );
  }

  // Trending agents list - no changes needed
  Widget _buildTrendingAgentsList(BuildContext context, AgentProvider agentProvider) {
    // Existing code...
    return SizedBox(
      height: 150,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: agentProvider.trendingAgents.length,
        itemBuilder: (context, index) {
          final agent = agentProvider.trendingAgents[index];
          return Card(
            margin: const EdgeInsets.only(right: 12),
            child: Container(
              width: 120,
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.grey.shade200,
                    child: const Icon(Icons.person, size: 30, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    agent['name'] ?? 'Agent',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Modal for creating a new agent - no changes needed
  void _showCreateAgentModal(BuildContext context) {
    // Existing code...
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const CreateAgentForm(),
    );
  }
 }

//
// class HomeScreen extends StatelessWidget {
//   const HomeScreen({Key? key}) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     final agentProvider = Provider.of<AgentProvider>(context);
//
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Solana Trading Agent'),
//         actions: [
//           // Settings icon
//           IconButton(
//             icon: const Icon(Icons.settings),
//             onPressed: () => Navigator.pushNamed(context, '/settings'),
//           ),
//         ],
//       ),
//       body: agentProvider.isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : SingleChildScrollView(
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Banner for new users
//             if (!agentProvider.hasAgent) _buildNoAgentBanner(context),
//
//             // Trending Agents Section
//             Padding(
//               padding: const EdgeInsets.all(16.0),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const Text(
//                     'Trending Agents',
//                     style: TextStyle(
//                         fontSize: 20,
//                         fontWeight: FontWeight.bold
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//                   _buildTrendingAgentsList(context, agentProvider),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//       // + button at bottom right
//       floatingActionButton: FloatingActionButton(
//         onPressed: () => _showCreateAgentModal(context),
//         child: const Icon(Icons.add),
//       ),
//     );
//   }
//
//   // Banner widget for new users
//   Widget _buildNoAgentBanner(BuildContext context) {
//     return Container(
//       margin: const EdgeInsets.all(16.0),
//       padding: const EdgeInsets.all(16.0),
//       decoration: BoxDecoration(
//         color: Colors.blue.shade50,
//         borderRadius: BorderRadius.circular(8.0),
//         border: Border.all(color: Colors.blue.shade200),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             'Create Your Trading Agent Today',
//             style: TextStyle(
//               fontSize: 18,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           const SizedBox(height: 8),
//           const Text(
//             'Get started with automated trading on Solana',
//             style: TextStyle(
//               fontSize: 14,
//             ),
//           ),
//           const SizedBox(height: 16),
//           ElevatedButton(
//             onPressed: () => _showCreateAgentModal(context),
//             child: const Text('Create Agent'),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // Trending agents list
//   Widget _buildTrendingAgentsList(BuildContext context, AgentProvider agentProvider) {
//     return SizedBox(
//       height: 150,
//       child: ListView.builder(
//         scrollDirection: Axis.horizontal,
//         itemCount: agentProvider.trendingAgents.length,
//         itemBuilder: (context, index) {
//           final agent = agentProvider.trendingAgents[index];
//           return Card(
//             margin: const EdgeInsets.only(right: 12),
//             child: Container(
//               width: 120,
//               padding: const EdgeInsets.all(8),
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   CircleAvatar(
//                     radius: 30,
//                     backgroundColor: Colors.grey.shade200,
//                     child: const Icon(Icons.person, size: 30, color: Colors.grey),
//                   ),
//                   const SizedBox(height: 8),
//                   Text(
//                     agent['name'] ?? 'Agent',
//                     style: const TextStyle(fontWeight: FontWeight.bold),
//                     textAlign: TextAlign.center,
//                     maxLines: 2,
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                 ],
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }
//
//   // Modal for creating a new agent
//   void _showCreateAgentModal(BuildContext context) {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       builder: (context) => const CreateAgentForm(),
//     );
//   }
// }

// Create Agent Form Modal
class CreateAgentForm extends StatefulWidget {
  const CreateAgentForm({Key? key}) : super(key: key);

  @override
  State<CreateAgentForm> createState() => _CreateAgentFormState();
}

class _CreateAgentFormState extends State<CreateAgentForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _imagePath;
  bool _isLoading = false;
  // Add toggle state variables
  bool _bitcoinBuyAndHold = false;
  bool _autonomousTrading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _imagePath = pickedFile.path;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Create Trading Agent',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Agent image picker
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: _imagePath != null
                        ? FileImage(File(_imagePath!))
                        : null,
                    child: _imagePath == null
                        ? const Icon(Icons.person, size: 50, color: Colors.grey)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: InkWell(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Agent name field
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Agent Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a name for your agent';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Bitcoin Buy & Hold toggle
            SwitchListTile(
              title: const Text('Bitcoin Buy & Hold'),
              subtitle: const Text('Enable long-term Bitcoin investment strategy'),
              value: _bitcoinBuyAndHold,
              onChanged: (value) {
                setState(() {
                  _bitcoinBuyAndHold = value;
                });
              },
            ),

            // Autonomous Trading toggle
            SwitchListTile(
              title: const Text('Autonomous Trading'),
              subtitle: const Text('Allow agent to trade automatically based on market conditions'),
              value: _autonomousTrading,
              onChanged: (value) {
                setState(() {
                  _autonomousTrading = value;
                });
              },
            ),

            const SizedBox(height: 24),

            // Create button
            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () async {
                if (_formKey.currentState!.validate()) {
                  setState(() {
                    _isLoading = true;
                  });

                  try {
                    // Call getOrCreateAgent function
                    await Provider.of<AgentProvider>(context, listen: false)
                        .getOrCreateAgent(
                      name: _nameController.text,
                      imagePath: _imagePath,
                      bitcoinBuyAndHold: _bitcoinBuyAndHold,
                      autonomousTrading: _autonomousTrading,
                    );

                    // Show success toast message
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Agent created successfully!'),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );

                      // Close the modal
                      Navigator.pop(context);
                    }
                  } catch (e) {
                    // Show error toast
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
              },
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Create Agent'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}