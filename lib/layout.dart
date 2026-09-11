import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// 横に広い画面 (デスクトップのブラウザなど) とみなす境目。
///
/// これより広いと、フィードを画面いっぱいに伸ばすより中央に1本だけ置いた方が
/// 見やすい。YouTube Shorts のデスクトップ表示と同じ考え方。
const double kWideLayoutBreakpoint = 720;

/// 広い画面で中央に置くステージの最大幅。
const double kStageMaxWidth = 440;

/// ステージの縦横比 (幅 ÷ 高さ)。スマホの画面に近い形にする。
const double kStageAspectRatio = 0.58;

/// 高さが足りない画面 (横向きのスマホなど) でも、これより細くはしない。
const double kStageMinWidth = 300;

/// ステージの右に置くアクション列の幅。
const double kRailWidth = 56;

/// 画面の端に置く、前後のページへ送る丸ボタンの幅。
///
/// Shorts と同じく、アクション列とは離して画面の右端に置く。
/// ページを送る操作とカードへの操作が隣り合っていると押し間違えるため。
const double kNavWidth = 44;

/// ステージとアクション列の間隔。
const double kStageGap = 16;

/// ステージの左右、画面の端までに空ける余白。
const double kStagePadding = 16;

/// ステージの左右に空ける領域の最小幅。
///
/// 右には [アクション列 + 間隔 + ページ送りボタン] が入る。左には作者情報を
/// 置くが、こちらは入るだけ入れて溢れた分は省略するので、幅は右に合わせる
/// (左右を同じ幅にすることでステージが画面の中央に来る)。
const double kGutterMinWidth = kStageGap + kRailWidth + kStageGap + kNavWidth;

/// ステージの左に置く作者情報の最大幅。
///
/// 広い画面ではガターがいくらでも広がるので、上限を置かないと作者名と
/// タイトルがステージから遠く離れて読みづらくなる。
const double kMetaMaxWidth = 300;

/// 広い画面でヘッダーの中身を収める最大幅。
const double kHeaderMaxWidth = 1100;

/// ステージの高さを見積もるときに差し引く、ヘッダーとシークバーのおおよその高さ。
///
/// 正確な値はレイアウトしてみないと分からないが、ここで [LayoutBuilder] を
/// 使うと先読み側から同じ幅を求められなくなる ([feedWidth] の注記を参照)。
/// 見積もりがずれてもステージが少し縦長・横長になるだけで、はみ出しはしない。
const double kChromeHeight = 150;

/// 広い画面向けの見せ方に切り替えるか。
bool isWideLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kWideLayoutBreakpoint;

/// カード1枚を表示する幅。
///
/// 広い画面では中央のステージの幅、狭い画面では画面いっぱい。
/// サムネイルを展開する大きさもこの幅に合わせるので、先読みと表示で同じ値に
/// なる必要がある。そのため実際のレイアウト結果からではなく、
/// どこから呼んでも同じ答えになる画面サイズから決める。
double feedWidth(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  if (size.width < kWideLayoutBreakpoint) return size.width;
  // ステージを画面の中央に保つため、左右に同じ幅のガターを空ける
  final maxByWidth = size.width - (kGutterMinWidth + kStagePadding) * 2;
  final byHeight = (size.height - kChromeHeight) * kStageAspectRatio;
  final width = math.min(math.min(kStageMaxWidth, maxByWidth), byHeight);
  return math.max(width, math.min(maxByWidth, kStageMinWidth));
}
