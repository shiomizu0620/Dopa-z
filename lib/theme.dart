import 'package:flutter/material.dart';

/// topaz.dev のテーマ色(水色 + 白)。
abstract final class TopazColors {
  /// アクセントの水色。
  static const cyan = Color(0xFF00B8D4);

  /// ロゴマークのグラデーション始点になる明るい水色。
  static const cyanLight = Color(0xFF8FEAF2);

  /// ロゴの濃い青緑。ロゴタイプの文字色に使う。
  static const deep = Color(0xFF17434F);

  /// 水色の薄い面(選択中でないチップの背景など)。
  static const cyanSurface = Color(0xFFE3F7FB);

  /// 背景。
  static const surface = Colors.white;

  /// 本文の文字色。
  static const onSurface = Color(0xFF11181C);

  /// 補助的な文字色。
  static const muted = Color(0xFF5C6B73);

  /// 罫線やシークバーの溝。
  static const border = Color(0xFFE3E8EA);
}

/// 画像の上に乗る文字・アイコンを、写真でも白背景でも読めるようにする影。
const topazGlowShadows = [
  Shadow(color: Colors.white, blurRadius: 6),
  Shadow(color: Colors.white, blurRadius: 12),
];
