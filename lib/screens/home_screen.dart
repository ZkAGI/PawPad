// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../services/auth_provider.dart';
// import 'pin_login_screen.dart';
//
// class HomeScreen extends StatelessWidget {
//   const HomeScreen({Key? key}) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Solana Wallet'),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.logout),
//             onPressed: () {
//               _signOut(context);
//             },
//           ),
//         ],
//       ),
//       body: const Center(
//         child: Text(
//           'Home Screen',
//           style: TextStyle(fontSize: 24),
//         ),
//       ),
//     );
//   }
//
//   void _signOut(BuildContext context) {
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);
//     authProvider.signOut();
//
//     Navigator.pushReplacement(
//       context,
//       MaterialPageRoute(builder: (context) => const PinLoginScreen()),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../services/agent_provider.dart';
import '../services/auth_provider.dart';
import 'package:image_picker/image_picker.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final agentProvider = Provider.of<AgentProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Solana Trading Agent'),
        actions: [
          // Settings icon
          IconButton(
            icon: const Icon(Icons.settings),
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
      // + button at bottom right
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateAgentModal(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  // Banner widget for new users
  Widget _buildNoAgentBanner(BuildContext context) {
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

  // Trending agents list
  Widget _buildTrendingAgentsList(BuildContext context, AgentProvider agentProvider) {
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

  // Modal for creating a new agent
  void _showCreateAgentModal(BuildContext context) {
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

                  // Save agent data
                  await Provider.of<AgentProvider>(context, listen: false)
                      .createAgent(
                    name: _nameController.text,
                    imagePath: _imagePath,
                  );

                  // Close the modal
                  if (context.mounted) {
                    Navigator.pop(context);
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