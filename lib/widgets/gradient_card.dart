// lib/widgets/gradient_card.dart
import 'package:flutter/material.dart';

const _myGradient = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [
    Color(0xFFA4C8FF), // 0%
    Color(0xFFA992ED), // 52%
    Color(0xFF643ADE), // 100%
  ],
  stops: [0.0, 0.52, 1.0],
);

final _borderColor = const Color(0xFF7E83A9).withOpacity(0.3);

/// A convenient container that applies your Figma gradient + border.
Widget gradientCard({
  required Widget child,
  EdgeInsets padding = const EdgeInsets.all(16),
  BorderRadius? borderRadius,
}) {
  return Container(
    decoration: BoxDecoration(
      gradient: _myGradient,
      border: Border.all(color: _borderColor),
      borderRadius: borderRadius ?? BorderRadius.circular(12),
    ),
    padding: padding,
    child: child,
  );
}
