import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AgentProvider extends ChangeNotifier {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _agentNameKey = 'agent_name';
  static const String _agentImagePathKey = 'agent_image_path';

  String? _agentName;
  String? _agentImagePath;
  bool _isLoading = false;

  // Dummy trending agents data
  final List<Map<String, String>> trendingAgents = [
    {'name': 'AlphaTrader', 'image': 'assets/images/agent1.png'},
    {'name': 'SolanaWhiz', 'image': 'assets/images/agent2.png'},
    {'name': 'MoonShot', 'image': 'assets/images/agent3.png'},
    {'name': 'CryptoSage', 'image': 'assets/images/agent4.png'},
  ];

  String? get agentName => _agentName;
  String? get agentImagePath => _agentImagePath;
  bool get hasAgent => _agentName != null;
  bool get isLoading => _isLoading;

  // Initialize provider
  Future<void> initialize() async {
    try {
      _isLoading = true;
      notifyListeners();

      _agentName = await _secureStorage.read(key: _agentNameKey);
      _agentImagePath = await _secureStorage.read(key: _agentImagePathKey);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing agent provider: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  // Create a new agent
  Future<void> createAgent({required String name, String? imagePath}) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _secureStorage.write(key: _agentNameKey, value: name);
      _agentName = name;

      if (imagePath != null) {
        await _secureStorage.write(key: _agentImagePathKey, value: imagePath);
        _agentImagePath = imagePath;
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error creating agent: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update agent name
  Future<void> updateAgentName(String name) async {
    try {
      await _secureStorage.write(key: _agentNameKey, value: name);
      _agentName = name;
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating agent name: $e');
    }
  }

  // Update agent image
  Future<void> updateAgentImage(String imagePath) async {
    try {
      await _secureStorage.write(key: _agentImagePathKey, value: imagePath);
      _agentImagePath = imagePath;
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating agent image: $e');
    }
  }
}