import 'package:flutter/material.dart';

import '../theme.dart';

/// topaz.dev のロゴに合わせた dopaz のロゴ。
/// 右上だけ角を落とした水色のマークと、アポストロフィが水色のロゴタイプ。
class DopazLogo extends StatelessWidget {
  const DopazLogo({super.key, this.markSize = 26, this.fontSize = 24});

  final double markSize;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'dopaz',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: markSize,
            height: markSize,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [TopazColors.cyanLight, TopazColors.cyan],
              ),
              // 右上だけ角を残した円
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(markSize / 2),
                bottomLeft: Radius.circular(markSize / 2),
                bottomRight: Radius.circular(markSize / 2),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'dopa'),
                TextSpan(
                  text: "'",
                  style: TextStyle(
                    color: TopazColors.cyan,
                    fontSize: fontSize * 1.1,
                  ),
                ),
                const TextSpan(text: 'z'),
              ],
            ),
            style: TextStyle(
              color: TopazColors.deep,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
