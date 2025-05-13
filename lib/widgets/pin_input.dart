import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PinInput extends StatefulWidget {
  final Function(String) onCompleted;
  final TextEditingController controller;
  final Color textColor;       // new parameter
  final Color cursorColor;     // new parameter

  const PinInput({
    Key? key,
    required this.onCompleted,
    required this.controller,
    this.textColor = Colors.black,
    Color? cursorColor,
  })  : cursorColor = cursorColor ?? textColor,
        super(key: key);

  @override
  State<PinInput> createState() => _PinInputState();
}

class _PinInputState extends State<PinInput> {
  final List<FocusNode> _focusNodes = List.generate(4, (index) => FocusNode());
  final List<TextEditingController> _controllers = List.generate(4, (index) => TextEditingController());

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });

    for (int i = 0; i < 3; i++) {
      _controllers[i].addListener(() {
        if (_controllers[i].text.length == 1) {
          _focusNodes[i + 1].requestFocus();
        }
      });
    }

    _controllers[3].addListener(() {
      if (_controllers[3].text.length == 1) {
        final pin = _controllers.map((c) => c.text).join();
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
                style: TextStyle(
                  color: widget.textColor,
                  fontSize: 24,
                ),
                cursorColor: widget.cursorColor,
                decoration: const InputDecoration(
                  counterText: '',
                  border: OutlineInputBorder(),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                onChanged: (value) {
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
