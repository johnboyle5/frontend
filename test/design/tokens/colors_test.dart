import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/src/design/tokens/colors.dart';

void main() {
  group('SoliplexColors', () {
    test('lightSoliplexColors has expected primary', () {
      expect(lightSoliplexColors.primary, const Color(0xFF030213));
    });

    test('darkSoliplexColors has expected primary', () {
      expect(darkSoliplexColors.primary, const Color(0xFFFAFAFA));
    });

    test('all light color roles are non-null via constructor', () {
      const colors = SoliplexColors(
        background: Colors.white,
        foreground: Colors.black,
        primary: Colors.blue,
        onPrimary: Colors.white,
        secondary: Colors.grey,
        onSecondary: Colors.black,
        accent: Colors.orange,
        onAccent: Colors.white,
        muted: Colors.grey,
        mutedForeground: Colors.grey,
        destructive: Colors.red,
        onDestructive: Colors.white,
        border: Colors.grey,
        inputBackground: Colors.grey,
        hintText: Colors.grey,
      );
      expect(colors.background, Colors.white);
      expect(colors.foreground, Colors.black);
      expect(colors.primary, Colors.blue);
    });
  });
}
