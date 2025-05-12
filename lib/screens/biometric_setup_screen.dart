import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import 'home_screen.dart';

class BiometricSetupScreen extends StatefulWidget {
  const BiometricSetupScreen({Key? key}) : super(key: key);

  @override
  State<BiometricSetupScreen> createState() => _BiometricSetupScreenState();
}

class _BiometricSetupScreenState extends State<BiometricSetupScreen> {
  bool _isBiometricAvailable = false;
  List<BiometricType> _availableBiometrics = [];
  bool _hasFaceId = false;
  bool _hasFingerprint = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isBiometricAvailable = await authProvider.isBiometricsAvailable();

    if (isBiometricAvailable) {
      final availableBiometrics = await authProvider.getAvailableBiometrics();

      setState(() {
        _isBiometricAvailable = true;
        _availableBiometrics = availableBiometrics;
        _hasFaceId = availableBiometrics.contains(BiometricType.face);
        _hasFingerprint = availableBiometrics.contains(BiometricType.fingerprint);
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _enableBiometrics() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.enableBiometrics(true);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  void _skipBiometrics() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.enableBiometrics(false);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biometric Setup'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Set up biometric authentication',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const Text(
                'Use biometrics to quickly access your wallet without entering your PIN.',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              if (!_isBiometricAvailable)
                const Text(
                  'Biometric authentication is not available on this device.',
                  style: TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                )
              else
                Column(
                  children: [
                    if (_hasFingerprint)
                      ListTile(
                        leading: const Icon(Icons.fingerprint, size: 48),
                        title: const Text('Fingerprint Authentication'),
                        subtitle: const Text('Use your fingerprint to unlock the app'),
                        onTap: _enableBiometrics,
                      ),
                    if (_hasFaceId)
                      ListTile(
                        leading: const Icon(Icons.face, size: 48),
                        title: const Text('Face ID Authentication'),
                        subtitle: const Text('Use your face to unlock the app'),
                        onTap: _enableBiometrics,
                      ),
                  ],
                ),
              const SizedBox(height: 40),
              TextButton(
                onPressed: _skipBiometrics,
                child: const Text('Skip for now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}