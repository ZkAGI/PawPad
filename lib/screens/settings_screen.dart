import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../services/agent_provider.dart';
import '../services/auth_provider.dart';
import 'package:image_picker/image_picker.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameController = TextEditingController();
  String? _newImagePath;
  bool _isEditingName = false;
  bool _showPrivateKey = false;
  bool _whitelistAssets = false;

  @override
  void initState() {
    super.initState();
    // Initialize the name controller with the current agent name
    final agentName = Provider.of<AgentProvider>(context, listen: false).agentName;
    if (agentName != null) {
      _nameController.text = agentName;
    }

    // You would typically load whitelist preference from persistent storage
    // For now we'll just use a default value
    _whitelistAssets = false;
  }

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
        _newImagePath = pickedFile.path;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final agentProvider = Provider.of<AgentProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Agent Profile Section
            if (agentProvider.hasAgent) ...[
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage: _newImagePath != null
                              ? FileImage(File(_newImagePath!))
                              : agentProvider.agentImagePath != null
                              ? FileImage(File(agentProvider.agentImagePath!))
                              : null,
                          child: (_newImagePath == null && agentProvider.agentImagePath == null)
                              ? const Icon(Icons.person, size: 60, color: Colors.grey)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: InkWell(
                            onTap: _pickImage,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.edit,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Agent Name with Edit Option
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _isEditingName
                            ? Expanded(
                          child: TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Agent Name',
                              border: OutlineInputBorder(),
                            ),
                            autofocus: true,
                          ),
                        )
                            : Text(
                          agentProvider.agentName ?? 'My Trading Agent',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: Icon(_isEditingName ? Icons.check : Icons.edit),
                          onPressed: () {
                            if (_isEditingName) {
                              // Save the name
                              agentProvider.updateAgentName(_nameController.text);
                            }
                            setState(() {
                              _isEditingName = !_isEditingName;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],

            // Private Key Section
            const Text(
              'Private Key',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Show Private Key'),
                      Switch(
                        value: _showPrivateKey,
                        onChanged: (value) {
                          setState(() {
                            _showPrivateKey = value;
                          });
                        },
                      ),
                    ],
                  ),
                  if (_showPrivateKey) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [

                          IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: () {
                              // Implement copy to clipboard
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Private key copied to clipboard')),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Warning: Never share your private key with anyone.',
                      style: TextStyle(color: Colors.red, fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Whitelist Assets Toggle
            const Text(
              'Security Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Whitelist Assets'),
                      SizedBox(height: 4),
                      Text(
                        'Only trade with approved assets',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: _whitelistAssets,
                    onChanged: (value) {
                      setState(() {
                        _whitelistAssets = value;
                      });
                      // Save the setting to persistent storage
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Save Changes Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  // Save image if changed
                  if (_newImagePath != null) {
                    await agentProvider.updateAgentImage(_newImagePath!);
                  }

                  // Save whitelist setting to persistent storage

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Settings saved')),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Save Changes'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}