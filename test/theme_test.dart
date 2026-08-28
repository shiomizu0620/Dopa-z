import 'dart:math';

import 'package:dopaz/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// 指定した明るさで [TopazColors.of] が返すパレットを取り出す。
  Future<TopazColors> paletteFor(
    WidgetTester tester,
    Brightness brightness,
  ) async {
    late TopazColors colors;
    await tester.pumpWidget(
      MaterialApp(
        theme: TopazColors.light.toThemeData(Brightness.light),
        darkTheme: TopazColors.dark.toThemeData(Brightness.dark),
        themeMode: brightness == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light,
        home: Builder(
          builder: (context) {
            colors = TopazColors.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    return colors;
  }

  testWidgets('端末がライトならライトのパレットを返す', (WidgetTester tester) async {
    final colors = await paletteFor(tester, Brightness.light);

    expect(colors, same(TopazColors.light));
    expect(colors.surface, Colors.white);
  });

  testWidgets('端末がダークならダークのパレットを返す', (WidgetTester tester) async {
    final colors = await paletteFor(tester, Brightness.dark);

    expect(colors, same(TopazColors.dark));
    expect(colors.surface, isNot(Colors.white));
  });

  test('ダークの背景と文字色はライトと明暗が逆になっている', () {
    // 背景は暗く、文字は明るい
    expect(
      TopazColors.dark.surface.computeLuminance(),
      lessThan(TopazColors.light.surface.computeLuminance()),
    );
    expect(
      TopazColors.dark.onSurface.computeLuminance(),
      greaterThan(TopazColors.light.onSurface.computeLuminance()),
    );
  });

  test('文字色と背景のコントラストが十分にある', () {
    for (final colors in [TopazColors.light, TopazColors.dark]) {
      final bg = colors.surface.computeLuminance();
      final fg = colors.onSurface.computeLuminance();
      final ratio = (max(bg, fg) + 0.05) / (min(bg, fg) + 0.05);
      // WCAG AA (通常サイズの文字) の 4.5:1 を満たす
      expect(ratio, greaterThan(4.5));
    }
  });

  test('画像に重ねる縁取りは背景と同系色になっている', () {
    // ライトは白い縁取り、ダークは暗い縁取り
    expect(
      TopazColors.light.glowShadows.first.color.computeLuminance(),
      greaterThan(0.9),
    );
    expect(
      TopazColors.dark.glowShadows.first.color.computeLuminance(),
      lessThan(0.1),
    );
  });
}
