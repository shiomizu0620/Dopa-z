import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// マウスホイールやトラックパッドの縦スクロールを、1ページ送りに読み替える。
///
/// [PageView] は既定ではホイールの移動量をそのまま位置に足すだけなので、
/// 1ノッチ (100px前後) では次のページに届かず、指を離した位置から元のページへ
/// 戻ってしまう。デスクトップのブラウザでは「ホイールを回しても何も起きない」
/// ように見えるため、ここで受け取ってページ送りに変換する。
///
/// 受け取り口の [WheelPager] はページごとに作られて送るたびに入れ替わるので、
/// 貯めた量と冷却の状態はページをまたいで残るこちら側で持つ。
class WheelPaging {
  WheelPaging({required this.onPage});

  /// 送る向き。次のページなら 1、前のページなら -1。
  final ValueChanged<int> onPage;

  /// これだけ動かされたら1ページ送る。
  /// トラックパッドの小さな動きで送られてしまわない程度に取る。
  static const _threshold = 24.0;

  /// 1ページ送ってから次を受け付けるまでの間。
  ///
  /// トラックパッドは指を離したあとも慣性でイベントを送り続けるので、
  /// 冷却を置かないと一度の操作で何ページも飛んでしまう。
  /// ページ送りのアニメーションが終わるくらいの長さにする。
  static const _cooldown = Duration(milliseconds: 380);

  double _accumulated = 0;
  Duration? _lastPagedAt;

  void handle(PointerScrollEvent event) {
    final now = event.timeStamp;
    final last = _lastPagedAt;
    if (last != null && now - last < _cooldown) {
      // 慣性で流れてくる分は、次の操作と地続きに数えたくないので捨てる
      _accumulated = 0;
      return;
    }
    _accumulated += event.scrollDelta.dy;
    if (_accumulated.abs() < _threshold) return;
    final direction = _accumulated > 0 ? 1 : -1;
    _accumulated = 0;
    _lastPagedAt = now;
    onPage(direction);
  }
}

/// ホイールの入力を [WheelPaging] に渡す受け取り口。
///
/// [PointerSignalResolver] は最初に名乗り出た1つだけを呼ぶ。イベントは
/// 深い側から順に配られるので、これを [PageView] の各ページの中に置いておけば
/// [Scrollable] より先に登録でき、二重に動くことがない。
class WheelPager extends StatelessWidget {
  const WheelPager({super.key, required this.paging, required this.child});

  final WheelPaging paging;
  final Widget child;

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(
      event,
      (resolved) => paging.handle(resolved as PointerScrollEvent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _onPointerSignal,
      // サムネイルの余白の上で回されても受け取れるようにする
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }
}
