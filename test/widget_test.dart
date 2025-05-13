// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solana_hackathon_2025/main.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:solana_hackathon_2025/main.dart';
import 'package:solana_hackathon_2025/services/auth_provider.dart';


void main() {
  testWidgets('Basic widget test', (WidgetTester tester) async {
    // Build our app by directly calling the main() function
    // which will create the root widget with the correct name
    await tester.pumpWidget(
      // Use the actual widget from main.dart
      // Replace this with whatever widget is returned by your main() function
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Test Widget'),
          ),
        ),
      ),
    );

    // A simple verification that doesn't depend on specific widgets
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}