import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../widgets/pin_input.dart';
import 'biometric_setup_screen.dart';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({Key? key}) : super(key: key);

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  String? _errorMessage;
  bool _isSettingUp = false;
  bool _isPinConfirmation = false;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  void _onPinComplete(String pin) async {
    if (!_isPinConfirmation) {
      // First PIN entry
      setState(() {
        _isPinConfirmation = true;
        _pinController.text = pin;
      });
    } else {
      // Confirm PIN entry
      if (_pinController.text == pin) {
        setState(() {
          _isSettingUp = true;
          _errorMessage = null;
        });

        try {
          await Provider.of<AuthProvider>(context, listen: false).setPin(pin);

          // Navigate to biometric setup after PIN is set
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const BiometricSetupScreen()),
          );
        } catch (e) {
          setState(() {
            _isSettingUp = false;
            _errorMessage = 'Failed to set PIN. Please try again.';
          });
        }
      } else {
        setState(() {
          _isPinConfirmation = false;
          _errorMessage = 'PINs do not match. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isPinConfirmation ? 'Confirm PIN' : 'Set PIN'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _isPinConfirmation
                    ? 'Please confirm your 4-digit PIN'
                    : 'Create a 4-digit PIN to secure your wallet',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 30),
              PinInput(
                onCompleted: _onPinComplete,
                controller: _isPinConfirmation ? _confirmPinController : _pinController,
                textColor: Colors.white,
                cursorColor: Colors.white,
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              if (_isSettingUp)
                const Padding(
                  padding: EdgeInsets.only(top: 24.0),
                  child: CircularProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}