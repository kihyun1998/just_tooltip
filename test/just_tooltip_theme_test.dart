import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_tooltip/just_tooltip.dart';

void main() {
  group('JustTooltipTheme', () {
    test('copyWith replaces only the given field', () {
      const base = JustTooltipTheme(
        backgroundColor: Color(0xFF112233),
        elevation: 4,
      );

      final copy = base.copyWith(elevation: 9);

      expect(copy.elevation, 9);
      expect(copy.backgroundColor, const Color(0xFF112233),
          reason: 'fields not passed to copyWith are carried over');
    });

    test('themes with identical fields are equal and share a hashCode', () {
      const a = JustTooltipTheme(
        backgroundColor: Color(0xFF112233),
        showArrow: true,
        arrowLength: 10,
      );
      const b = JustTooltipTheme(
        backgroundColor: Color(0xFF112233),
        showArrow: true,
        arrowLength: 10,
      );

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('themes differing in a single field are not equal', () {
      const a = JustTooltipTheme(showArrow: true);
      const b = JustTooltipTheme(showArrow: false);

      expect(a, isNot(equals(b)));
    });
  });
}
