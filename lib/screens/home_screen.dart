import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../services/agent_provider.dart';
import '../services/auth_provider.dart';
import 'package:image_picker/image_picker.dart';

import '../widgets/gradient_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? selectedAgentName;
  bool _isLoadingBalance = false;
  double _currentBalance = 0.0;

  @override
  void initState() {
    super.initState();
    // Initialize with first agent and fetch balance
    _initializeSelectedAgent();
  }

  Future<void> _initializeSelectedAgent() async {
    // We'll fetch the balance right away
    _refreshBalance();
  }

  Future<void> _refreshBalance() async {
    final agentProvider = Provider.of<AgentProvider>(context, listen: false);

    // Exit early if no agent exists
    if (agentProvider.agentName == null) return;

    setState(() {
      _isLoadingBalance = true;
    });

    try {
      // Always use the current agent from the provider
      final balance = await agentProvider.getAgentBalance(agentProvider.agentName!);

      setState(() {
        _currentBalance = balance;
        _isLoadingBalance = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingBalance = false;
      });
      print('Error refreshing balance: $e');
    }
  }

  void _copyWalletAddress(BuildContext context, AgentProvider agentProvider) {
    // Always use the current agent from the provider
    final address = agentProvider.getAgentWalletAddress(agentProvider.agentName);

    if (address != null && address.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: address));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Wallet address copied: $address'),
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
    List<String> availableAgents = [];
    if (agentProvider.agentName != null) {
      availableAgents.add(agentProvider.agentName!);
      // Add any other real agents here when you have multiple agent support
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('PawPad'),
        actions: [
          // Agent selector with dropdown and icon
          if (agentProvider.hasAgent || availableAgents.isNotEmpty)
            Row(
              children: [
                // Agent status icon
                Stack(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.auto_awesome, size: 16, color: Colors.orange.shade700),
                    ),
                    Positioned(
                      right: 4,
                      bottom: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.grey, // Grey for inactive state
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                      ),
                    ),
                  ],
                ),

                // Agent dropdown
                DropdownButton<String>(
                  // Always use the agent name if available, even if selectedAgentName is null
                  value: agentProvider.agentName ?? selectedAgentName,

                  // Remove the hint since we'll always have a value
                  // hint: const Text('Select Agent'),  // Remove this line
                  underline: Container(),
                  dropdownColor: const Color(0xFF000A19),                // dropdown’s background
                  iconEnabledColor: Colors.white,                         // the arrow
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        selectedAgentName = newValue;
                      });
                      _refreshBalance();
                    }
                  },
                  items: availableAgents
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value, style: const TextStyle(fontSize: 14)),
                    );
                  }).toList(),
                ),
              ],
            ),

          // Copy wallet address button
          if (agentProvider.hasAgent || availableAgents.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.copy),
              color: Colors.white,
              onPressed: () => _copyWalletAddress(context, agentProvider),
              tooltip: 'Copy wallet address',
            ),

          // Settings icon
          IconButton(
            icon: const Icon(Icons.settings),
            color: Colors.white,
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: agentProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Agent Balance Display
            if (agentProvider.hasAgent)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Card(
                  elevation: 2,
                  child:gradientCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Balance',
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh, size: 20),
                              onPressed: _refreshBalance,
                              tooltip: 'Refresh balance',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _isLoadingBalance
                            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                            : Row(
                          children: [
                            Text(
                              '\$ ${_currentBalance.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'USD',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ),
                ),
              ),
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
                        fontWeight: FontWeight.bold,
                        color: Colors.white
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
      child:gradientCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Create Your Trading Agent Today',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Get started with automated trading on Solana',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _showCreateAgentModal(context),
            child: const Text('Create Agent'),
          ),
        ],
      ),
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
            child:gradientCard(
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
      backgroundColor: const Color(0xFF1F2641),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const CreateAgentForm(),
    );
  }
}

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
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white,  ),
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
              style: const TextStyle(color: Colors.white),
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
              title: const Text('Bitcoin Buy & Hold', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Enable long-term Bitcoin investment strategy',style: TextStyle(color: Colors.white54)),
              value: _bitcoinBuyAndHold,
              onChanged: (value) {
                setState(() {
                  _bitcoinBuyAndHold = value;
                });
              },
            ),

            // Autonomous Trading toggle
            SwitchListTile(
              title: const Text('Autonomous Trading', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Allow agent to trade automatically based on market conditions',style: TextStyle(color: Colors.white54)),
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

                    if (context.mounted) {
                      // This will trigger a rebuild of the HomeScreen
                      Provider.of<AgentProvider>(context, listen: false).notifyListeners();
                    }

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