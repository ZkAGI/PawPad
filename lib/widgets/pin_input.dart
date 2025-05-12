import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PinInput extends StatefulWidget {
  final Function(String) onCompleted;
  final TextEditingController controller;

  const PinInput({
    Key? key,
    required this.onCompleted,
    required this.controller,
  }) : super(key: key);

  @override
  State<PinInput> createState() => _PinInputState();
}

class _PinInputState extends State<PinInput> {
  final List<FocusNode> _focusNodes = List.generate(4, (index) => FocusNode());
  final List<TextEditingController> _controllers = List.generate(4, (index) => TextEditingController());

  @override
  void initState() {
    super.initState();

    // Focus the first node when the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });

    // Set up listeners to move focus when a digit is entered
    for (int i = 0; i < 3; i++) {
      _controllers[i].addListener(() {
        if (_controllers[i].text.length == 1) {
          _focusNodes[i + 1].requestFocus();
        }
      });
    }

    // When the last digit is entered, call onCompleted
    _controllers[3].addListener(() {
      if (_controllers[3].text.length == 1) {
        final pin = _controllers.map((controller) => controller.text).join();
        if (pin.length == 4) {
          widget.controller.text = pin;
          widget.onCompleted(pin);
        }
      }
    });
  }

  @override
  void dispose() {
    for (var node in _focusNodes) {
      node.dispose();
    }
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _clearFields() {
    for (var controller in _controllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            4,
            (index) => Container(
              width: 60,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              child: TextField(
                controller: _controllers[index],
                focusNode: _focusNodes[index],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                obscureText: true,
                decoration: const InputDecoration(
                  counterText: '',
                  border: OutlineInputBorder(),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                onChanged: (value) {
                  // Handle backspace
                  if (value.isEmpty && index > 0) {
                    _focusNodes[index - 1].requestFocus();
                  }
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _clearFields,
          child: const Text('Clear'),
        ),
      ],
    );
  }
}