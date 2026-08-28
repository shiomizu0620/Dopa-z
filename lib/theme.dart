import 'package:flutter/material.dart';

/// topaz.dev のテーマ色(水色 + 白)。
/// ライト/ダークの2組を持ち、[TopazColors.of] で現在のものを取り出す。
class TopazColors {
  const TopazColors({
    required this.cyan,
    required this.cyanLight,
    required this.cyanSurface,
    required this.deep,
    required this.surface,
    required this.onSurface,
    required this.muted,
    required this.border,
    required this.glowShadows,
  });

  /// アクセントの水色。
  final Color cyan;

  /// ロゴマークのグラデーション始点になる明るい水色。
  final Color cyanLight;

  /// 水色の薄い面(選択中でないチップの背景など)。
  final Color cyanSurface;

  /// ロゴタイプの文字色。
  final Color deep;

  /// 背景。
  final Color surface;

  /// 本文の文字色。
  final Color onSurface;

  /// 補助的な文字色。
  final Color muted;

  /// 罫線やシークバーの溝。
  final Color border;

  /// 画像の上に乗る文字・アイコンを、写真でも背景の上でも読めるようにする影。
  /// 背景と同系色で縁取ることで、どちらに重なっても輪郭が出る。
  final List<Shadow> glowShadows;

  static const light = TopazColors(
    cyan: Color(0xFF00B8D4),
    cyanLight: Color(0xFF8FEAF2),
    cyanSurface: Color(0xFFE3F7FB),
    deep: Color(0xFF17434F),
    surface: Colors.white,
    onSurface: Color(0xFF11181C),
    muted: Color(0xFF5C6B73),
    border: Color(0xFFE3E8EA),
    glowShadows: [
      Shadow(color: Colors.white, blurRadius: 6),
      Shadow(color: Colors.white, blurRadius: 12),
    ],
  );

  static const dark = TopazColors(
    // 暗い背景では水色をやや明るくしないと沈む
    cyan: Color(0xFF35D6EF),
    cyanLight: Color(0xFFA8F0F8),
    cyanSurface: Color(0xFF12333B),
    deep: Color(0xFFDFF6FA),
    surface: Color(0xFF0E1417),
    onSurface: Color(0xFFE7EEF0),
    muted: Color(0xFF93A5AC),
    border: Color(0xFF27343A),
    glowShadows: [
      Shadow(color: Color(0xFF0E1417), blurRadius: 6),
      Shadow(color: Color(0xFF0E1417), blurRadius: 12),
    ],
  );

  /// 現在のテーマに合うパレット。
  static TopazColors of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }

  /// このパレットに対応する [ThemeData]。
  ThemeData toThemeData(Brightness brightness) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: cyan,
        brightness: brightness,
        surface: surface,
      ),
      scaffoldBackgroundColor: surface,
      useMaterial3: true,
    );
  }
}
