import 'package:flutter/material.dart';

import '../theme.dart';

/// フィード内の位置を示すシークバー。
/// 横にドラッグ、またはタップした位置へ送ることができる。
class FeedSeekBar extends StatefulWidget {
  const FeedSeekBar({
    super.key,
    required this.itemCount,
    required this.currentIndex,
    required this.onSeek,
  });

  final int itemCount;
  final int currentIndex;

  /// 移動先が変わったときに呼ばれる。
  final ValueChanged<int> onSeek;

  @override
  State<FeedSeekBar> createState() => _FeedSeekBarState();
}

class _FeedSeekBarState extends State<FeedSeekBar> {
  /// ドラッグ中の指の位置 (0.0〜1.0)。触っていなければ null。
  double? _dragFraction;

  /// 細いバーでも掴めるように、当たり判定はバー本体より広くとる。
  static const _hitHeight = 30.0;
  static const _trackHeight = 2.5;
  static const _trackHeightActive = 4.0;
  static const _knobSize = 10.0;
  static const _knobSizeActive = 16.0;

  bool get _dragging => _dragFraction != null;

  /// バーを塗る割合。ドラッグ中は指の位置をそのまま使い、
  /// 離したら現在ページの位置に戻す。
  double get _fraction {
    if (_dragFraction != null) return _dragFraction!;
    if (widget.itemCount == 0) return 0;
    return (widget.currentIndex + 1) / widget.itemCount;
  }

  /// 指の位置を項目のインデックスに変換する。
  int _indexAt(double fraction) {
    if (widget.itemCount == 0) return 0;
    return (fraction * widget.itemCount).floor().clamp(0, widget.itemCount - 1);
  }

  void _seek(double localX, double width) {
    if (width <= 0) return;
    final fraction = (localX / width).clamp(0.0, 1.0);
    setState(() => _dragFraction = fraction);
    final index = _indexAt(fraction);
    if (index != widget.currentIndex) {
      widget.onSeek(index);
    }
  }

  void _release() {
    if (_dragging) setState(() => _dragFraction = null);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => _seek(details.localPosition.dx, width),
          onTapUp: (_) => _release(),
          onTapCancel: _release,
          onHorizontalDragStart: (details) =>
              _seek(details.localPosition.dx, width),
          onHorizontalDragUpdate: (details) =>
              _seek(details.localPosition.dx, width),
          onHorizontalDragEnd: (_) => _release(),
          onHorizontalDragCancel: _release,
          child: SizedBox(
            height: _hitHeight,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: _fraction.clamp(0.0, 1.0)),
              // ドラッグ中は指に追従させたいのでアニメーションしない
              duration: _dragging
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              builder: (context, value, _) => _buildBar(width, value),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBar(double width, double value) {
    final colors = TopazColors.of(context);
    final trackHeight = _dragging ? _trackHeightActive : _trackHeight;
    final knobSize = _dragging ? _knobSizeActive : _knobSize;
    final trackTop = (_hitHeight - trackHeight) / 2;
    final knobTop = (_hitHeight - knobSize) / 2;
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: trackTop,
          child: Container(height: trackHeight, color: colors.border),
        ),
        Positioned(
          left: 0,
          top: trackTop,
          child: Container(
            width: width * value,
            height: trackHeight,
            color: colors.cyan,
          ),
        ),
        Positioned(
          left: (width * value - knobSize / 2).clamp(0.0, width - knobSize),
          top: knobTop,
          child: Container(
            width: knobSize,
            height: knobSize,
            decoration: BoxDecoration(
              color: colors.cyan,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}
