import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/agent_provider.dart';
import '../services/auth_provider.dart';
import '../utils/image_utils.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameController = TextEditingController();
  String? _newImagePath;
  bool _isEditingName = false;
  bool _isLoading = false;
  bool _isImageValid = true; // Track image validity
  String? _imageError; // Store image error
  bool _isCompressingImage = false;
  bool _notificationsEnabled = false;

  // Available coins list
  final List<String> _availableCoins = [
    "TRUMP",
    "BONK",
    "FARTCOIN",
    "PENGU",
    "POPCAT",
    "PNUT",
    "AI16Z",
    "MEW",
    "VIRTUAL",
    "SPX",
    "PYTH",
    "GRASS",
    "ATH",
    "W",
    "MOODENG"
  ];

  @override
  void initState() {
    super.initState();
    // Initialize the name controller with the current agent name
    final agentName = Provider.of<AgentProvider>(context, listen: false).agentName;
    if (agentName != null) {
      _nameController.text = agentName;
    }
    // TODO: Load notification preference from local storage or provider
    _loadNotificationPreference();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // Add method to load notification preference
  Future<void> _loadNotificationPreference() async {
    // TODO: Load from SharedPreferences or your state management
    // For now, defaulting to false
    setState(() {
      _notificationsEnabled = false;
    });
  }

  // Add method to save notification preference
  Future<void> _saveNotificationPreference(bool enabled) async {
    // TODO: Save to SharedPreferences or your state management
    setState(() {
      _notificationsEnabled = enabled;
    });

    // Optional: Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            enabled
                ? 'Notifications enabled'
                : 'Notifications disabled'
        ),
        backgroundColor: enabled ? Colors.green : Colors.orange,
      ),
    );
  }

  Future<void> _pickImage() async {
    setState(() {
      _isCompressingImage = false;
      _imageError = null;
    });

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 70,
    );

    if (picked != null) {
      setState(() {
        _isCompressingImage = true;
      });

      try {
        // Check file size
        final file = File(picked.path);
        final sizeInKB = await file.length() / 1024;

        if (sizeInKB <= 2) {
          // File is already small enough
          setState(() {
            _newImagePath = picked.path;
            _isImageValid = true;
            _isCompressingImage = false;
          });
        } else {
          // Try to compress the image
          final compressedPath = await ImageUtils.compressAndValidateImage(picked.path);

          if (compressedPath != null) {
            setState(() {
              _newImagePath = compressedPath;
              _isImageValid = true;
              _imageError = null;
            });
          } else {
            setState(() {
              _newImagePath = null;
              _isImageValid = false;
              _imageError = 'Image is too large and could not be compressed below 2KB. Please choose a smaller image.';
            });
          }
        }
      } catch (e) {
        setState(() {
          _newImagePath = null;
          _isImageValid = false;
          _imageError = 'Error processing image: $e';
        });
      } finally {
        setState(() {
          _isCompressingImage = false;
        });
      }
    }
  }

  void _showAuthenticationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Authentication Required'),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please authenticate to view your private key'),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Biometric option
                  ElevatedButton.icon(
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Biometric'),
                    onPressed: () {
                      Navigator.pop(context);
                      _authenticateWithBiometrics();
                    },
                  ),
                  // PIN option
                  ElevatedButton.icon(
                    icon: const Icon(Icons.pin),
                    label: const Text('PIN'),
                    onPressed: () {
                      Navigator.pop(context);
                      _authenticateWithPIN();
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _authenticateWithBiometrics() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.authenticateWithBiometrics();

    if (success && mounted) {
      _showPrivateKeyDialog();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Authentication failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _authenticateWithPIN() async {
    // Show PIN input dialog
    final pin = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final pinController = TextEditingController();
        return AlertDialog(
          title: const Text('Enter PIN'),
          content: TextField(
            controller: pinController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: 'Enter your 4-digit PIN',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(pinController.text),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );

    if (pin != null && mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.verifyPin(pin);

      if (success && mounted) {
        _showPrivateKeyDialog();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incorrect PIN'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showPrivateKeyDialog() async {
    // Get the private key
    String privateKey = "";
    try {
      // This would be your implementation of getPrivateKey
      // For now, we'll use a placeholder
      privateKey = await Provider.of<AgentProvider>(context, listen: false).getPrivateKey();
    } catch (e) {
      privateKey = "Error retrieving private key: $e";
    }

    if (!mounted) return;

    // Show the private key dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Your Private Key'),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Warning: Never share your private key with anyone!',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        privateKey,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: privateKey));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Private key copied to clipboard'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // New method to show Custom Strategy dialog
  Future<void> _showCustomStrategyDialog() async {
    setState(() {
      _isLoading = true;
    });

    final agentProvider = Provider.of<AgentProvider>(context, listen: false);
    final agentName = agentProvider.agentName;

    if (agentName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No agent selected'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Fetch current custom strategy settings
    Map<String, dynamic>? customStrategy;
    List<String> selectedCoins = [];
    String timeframe = "4h"; // Default

    try {
      // Fetch activities from API
      final response = await http.get(
        Uri.parse('https://zynapse.zkagi.ai/activities/$agentName'),
        headers: {
          'api-key': 'zk-123321',
        },
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        print('API Response: $responseBody');

        // Handle the response structure with success and data array
        if (responseBody['success'] == true && responseBody['data'] is List && responseBody['data'].isNotEmpty) {
          final data = responseBody['data'][0]; // Get the first item in the data array

          if (data['isCustomStrategy'] != null) {
            customStrategy = Map<String, dynamic>.from(data['isCustomStrategy']);
            selectedCoins = List<String>.from(customStrategy!['coins'] ?? []);
            timeframe = customStrategy['timeframe'] ?? "4h";

            print('Loaded Custom Strategy: coins=$selectedCoins, timeframe=$timeframe');
          } else {
            print('No Custom Strategy found for agent: $agentName');
          }
        } else {
          print('Unexpected API response format');
        }
      } else {
        print('Error fetching agent data: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print('Exception fetching agent data: $e');
    }

    setState(() {
      _isLoading = false;
    });

    if (!mounted) return;

    // Create a copy of selectedCoins that we'll modify in the dialog
    List<String> updatedSelectedCoins = List.from(selectedCoins);
    String updatedTimeframe = timeframe;
    bool hasChanges = false;

    // Show the Custom Strategy Dialog
    await showDialog(
      context: context,
      barrierDismissible: false, // User must tap buttons
      builder: (BuildContext context) {
        return StatefulBuilder(
            builder: (context, setDialogState) {
              // Check if any changes have been made
              bool checkChanges() {
                if (updatedTimeframe != timeframe) return true;
                if (updatedSelectedCoins.length != selectedCoins.length) return true;

                for (final coin in selectedCoins) {
                  if (!updatedSelectedCoins.contains(coin)) return true;
                }

                for (final coin in updatedSelectedCoins) {
                  if (!selectedCoins.contains(coin)) return true;
                }

                return false;
              }

              // Create helper sets for the original selected coins
              final Set<String> originalCoinsSet = Set.from(selectedCoins);
              final bool canClose = !checkChanges() || (updatedSelectedCoins.isNotEmpty);

              return AlertDialog(
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Custom Strategy Settings', style: TextStyle(fontSize: 18)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: canClose
                          ? () => Navigator.of(context).pop()
                          : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select at least one coin or revert your changes to close'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Coin selection section header
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          'Select coins for trading:',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                      ),

                      // Coin selection list
                      Flexible(
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 300),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _availableCoins.length,
                            itemBuilder: (context, index) {
                              final coin = _availableCoins[index];
                              final wasOriginallySelected = originalCoinsSet.contains(coin);
                              final isSelected = updatedSelectedCoins.contains(coin);

                              // Apply background color only to individual items that are selected
                              return Container(
                                decoration: BoxDecoration(
                                  color: wasOriginallySelected && isSelected ?
                                  Colors.purple.withOpacity(0.08) : null,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                margin: const EdgeInsets.symmetric(vertical: 1),
                                child: CheckboxListTile(
                                  title: Text(coin),
                                  value: isSelected,
                                  activeColor: Colors.purple,
                                  // Disable unchecking for original coins
                                  onChanged: (wasOriginallySelected && isSelected)
                                      ? null // Disable the checkbox if it was originally selected
                                      : (bool? value) {
                                    setDialogState(() {
                                      if (value == true) {
                                        if (!updatedSelectedCoins.contains(coin)) {
                                          updatedSelectedCoins.add(coin);
                                        }
                                      } else {
                                        if (!wasOriginallySelected) {
                                          updatedSelectedCoins.remove(coin);
                                        }
                                      }
                                      hasChanges = checkChanges();
                                    });
                                  },
                                  subtitle: wasOriginallySelected && isSelected
                                      ? const Text('Cannot unselect',
                                      style: TextStyle(fontSize: 12, color: Colors.grey))
                                      : null,
                                  dense: true, // Make the list tiles more compact
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      // Timeframe section with clear separation from the coins list
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.only(top: 8.0),
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Colors.black12, width: 1),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select timeframe:',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: ['1h', '4h', '1d'].map((tf) {
                                return InkWell(
                                  onTap: () {
                                    setDialogState(() {
                                      updatedTimeframe = tf;
                                      hasChanges = checkChanges();
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: updatedTimeframe == tf ? Colors.purple : Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      tf,
                                      style: TextStyle(
                                        color: updatedTimeframe == tf ? Colors.white : Colors.black,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: hasChanges && updatedSelectedCoins.isNotEmpty
                        ? () async {
                      // Close dialog
                      Navigator.of(context).pop();
                      // Show loading indicator
                      setState(() {
                        _isLoading = true;
                      });

                      try {
                        // Get the agent/ticker name
                        final tickerName = agentName;

                        // Get current timestamp in ISO 8601 format
                        final now = DateTime.now().toUtc().toIso8601String();

                        // Determine which coins were added (not in original selection)
                        final Set<String> originalCoinsSet = Set.from(selectedCoins);
                        final List<String> addedCoins = updatedSelectedCoins
                            .where((coin) => !originalCoinsSet.contains(coin))
                            .toList();

                        // Keep removeCoins empty as requested
                        final List<String> removeCoins = [];

                        // Prepare the request data for the new API endpoint with exact format
                        final requestData = {
                          'ticker': tickerName,
                          'addCoins': addedCoins,
                          'removeCoins': removeCoins,
                          'newTimeframe': updatedTimeframe,  // Using newTimeframe for the timeframe value (like "4h")
                          'ticker_img': "",  // Empty as requested
                        };

                        print('Sending request to update_custom_strategy: ${jsonEncode(requestData)}');

                        // Make the API call to the new endpoint
                        final response = await http.post(
                          Uri.parse('https://zynapse.zkagi.ai/update_custom_strategy'),
                          headers: {
                            'Content-Type': 'application/json',
                            'api-key': 'zk-123321',
                          },
                          body: jsonEncode(requestData),
                        );

                        setState(() {
                          _isLoading = false;
                        });

                        if (response.statusCode == 200) {
                          print('Custom strategy updated successfully');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Custom strategy updated successfully'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } else {
                          print('Error response: ${response.body}');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error updating custom strategy: ${response.statusCode}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        print('Exception updating strategy: $e');
                        setState(() {
                          _isLoading = false;
                        });

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                        : null, // Disable button if no changes or empty selection
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                    ),
                    child: const Text('Save Changes'),
                  ),
                ],
              );
            }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final agentProvider = Provider.of<AgentProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Agent Profile
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage: _isCompressingImage
                            ? null
                            : _newImagePath != null
                            ? FileImage(File(_newImagePath!))
                            : agentProvider.agentImagePath != null
                            ? FileImage(File(agentProvider.agentImagePath!))
                            : null,
                        child: _isCompressingImage
                            ? const CircularProgressIndicator()
                            : (_newImagePath == null && agentProvider.agentImagePath == null)
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
                  if (_imageError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        _imageError!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 16),

                  //agent name without edit option
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      agentProvider.agentName ?? 'My Trading Agent',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                ],
              ),
            ),
            const SizedBox(height: 32),

            // Private Key Section
            const Text(
              'Private Key',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white
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
                children: [
                  // Non-editable input showing masked private key
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: const Text(
                        'XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX',
                        style: TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                  ),
                  // Eye icon to reveal
                  IconButton(
                    icon: const Icon(Icons.visibility),
                    onPressed: _showAuthenticationDialog,
                    tooltip: 'Show private key',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Custom Strategy Section (NEW)
            const Text(
              'Trading Strategy',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                title: const Text('Update Custom Strategy'),
                subtitle: const Text('Select coins and timeframe for trading'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: _showCustomStrategyDialog,
              ),
            ),

            const SizedBox(height: 24),

            // Notifications Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left side: Notifications heading and disclaimer text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Notifications',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'By enabling notifications, you authorize to receive updates on automated trading actions and profit/loss made.',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white70,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                // Right side: Toggle switch
                Switch(
                  value: _notificationsEnabled,
                  onChanged: _saveNotificationPreference,
                  activeColor: Colors.purple,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Save Changes Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (!_isImageValid && _newImagePath != null)
                    ? null
                    : () async {
                  final agentProvider = Provider.of<AgentProvider>(context, listen: false);
                  final ticker = agentProvider.agentName;

                  // Check if we have a valid agent name
                  if (ticker == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No agent selected'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  // Check if we need to update the image
                  if (_newImagePath == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No changes to save'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  setState(() => _isLoading = true);

                  try {
                    // Read the image file and convert to base64
                    final bytes = await File(_newImagePath!).readAsBytes();
                    final base64Img = base64Encode(bytes);

                    // Create the API payload
                    final payload = {
                      'ticker': ticker,
                      'ticker_img': base64Img,
                      'addCoins': <String>[],       // empty as required
                      'removeCoins': <String>[],    // empty as required
                      'newTimeframe': '',           // empty as required
                    };

                    print('▶️ [update_custom_strategy] Sending image update for ticker: $ticker');

                    // Make the API call
                    final res = await http.post(
                      Uri.parse('https://zynapse.zkagi.ai/update_custom_strategy'),
                      headers: {
                        'Content-Type': 'application/json',
                        'api-key': 'zk-123321',
                      },
                      body: jsonEncode(payload),
                    );

                    print('◀️ [update_custom_strategy] status = ${res.statusCode}');

                    if (res.statusCode == 200) {
                      // Update local image path only after successful API call
                      await agentProvider.updateAgentImage(_newImagePath!);

                      setState(() {
                        _newImagePath = null;  // Reset the new image path
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Agent image updated successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      print('◀️ [update_custom_strategy] Error response: ${res.body}');
                      throw Exception('API Error: ${res.statusCode} - ${res.body}');
                    }
                  } catch (e) {
                    print('❌ Exception updating agent image: $e');

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to update agent image: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  } finally {
                    if (mounted) setState(() => _isLoading = false);
                  }
                },
                child: _isLoading
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Save Changes',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}