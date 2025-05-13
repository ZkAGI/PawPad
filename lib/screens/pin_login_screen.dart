import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../widgets/pin_input.dart';
import 'home_screen.dart';

class PinLoginScreen extends StatefulWidget {
  const PinLoginScreen({Key? key}) : super(key: key);

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> {
  final TextEditingController _pinController = TextEditingController();
  String? _errorMessage;
  bool _isLoggingIn = false;
  bool _showBiometricOption = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isBiometricsAvailable = await authProvider.isBiometricsAvailable();
    final isBiometricsEnabled = await authProvider.isBiometricsEnabled();

    if (isBiometricsAvailable && isBiometricsEnabled) {
      setState(() {
        _showBiometricOption = true;
      });

      // Automatically prompt for biometric authentication
      _authenticateWithBiometrics();
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.authenticateWithBiometrics();

    if (success) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  void _onPinComplete(String pin) async {
    setState(() {
      _isLoggingIn = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final isValid = await authProvider.verifyPin(pin);

      if (isValid) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        setState(() {
          _isLoggingIn = false;
          _errorMessage = 'Incorrect PIN. Please try again.';
          _pinController.clear();
        });
      }
    } catch (e) {
      setState(() {
        _isLoggingIn = false;
        _errorMessage = 'Authentication failed. Please try again.';
        _pinController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enter PIN'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Enter your 4-digit PIN to access your wallet',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18,  color:Colors.white),
              ),
              const SizedBox(height: 30),
              PinInput(
                onCompleted: _onPinComplete,
                controller: _pinController,
                textColor: Colors.white,
                cursorColor: Colors.white, // optional
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              if (_isLoggingIn)
                const Padding(
                  padding: EdgeInsets.only(top: 24.0),
                  child: CircularProgressIndicator(),
                ),
              if (_showBiometricOption)
                Padding(
                  padding: const EdgeInsets.only(top: 24.0),
                  child: TextButton.icon(
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Use Biometrics'),
                    onPressed: _authenticateWithBiometrics,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}