/// フィードの並び順。
enum FeedOrder {
  /// APIが返す順序 (新着順) のまま、1ページ目から順に読む。
  latest('新着'),

  /// まだ読んでいないページからランダムに選び、中身もシャッフルする。
  random('ランダム');

  const FeedOrder(this.label);

  /// 画面に出すラベル。
  final String label;
}
