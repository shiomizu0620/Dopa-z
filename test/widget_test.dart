import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dopaz/main.dart';
import 'package:dopaz/widgets/dopaz_logo.dart';

void main() {
  /// スマホ相当のサイズで描画する(オーバーフロー検出のため)。
  Future<void> pumpFeed(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const DopazApp());
  }

  testWidgets('起動直後はローディングが表示される', (WidgetTester tester) async {
    await pumpFeed(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // モックディレイ(500ms)を消化してタイマー残りをなくす
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('読み込み後にShorts風のUIが表示される', (WidgetTester tester) async {
    await pumpFeed(tester);
    await tester.pump(const Duration(seconds: 1));

    // ヘッダーとフィルターチップ
    expect(find.byType(DopazLogo), findsOneWidget);
    expect(find.text('すべて'), findsOneWidget);
    expect(find.text('Flutter'), findsOneWidget);

    // 1件目のカード
    expect(find.text('@akubi'), findsOneWidget);
    expect(find.text('フォロー'), findsOneWidget);
    expect(find.text('#Flutter #Dart #Riverpod'), findsOneWidget);

    // 右側のアクションレール(5.7万 = 57000件のいいね)
    expect(find.text('5.7万'), findsOneWidget);
    expect(find.text('270'), findsOneWidget);
    expect(find.text('共有'), findsOneWidget);
    expect(find.text('topaz'), findsOneWidget);
  });

  testWidgets('縦スワイプで次のプロジェクトに進む', (WidgetTester tester) async {
    await pumpFeed(tester);
    await tester.pump(const Duration(seconds: 1));

    await tester.fling(find.byType(PageView), const Offset(0, -400), 1000);
    await tester.pumpAndSettle();

    expect(find.text('@hackathon_taro'), findsOneWidget);
    expect(find.text('@akubi'), findsNothing);
  });

  testWidgets('いいねは表示のみでアプリからは操作できない', (WidgetTester tester) async {
    await pumpFeed(tester);
    await tester.pump(const Duration(seconds: 1));

    // 前後のページも構築されているので、表示中のカードのものをタップする
    await tester.tap(find.byIcon(Icons.favorite_border).first);
    await tester.pumpAndSettle();

    // 状態は変わらず、topaz.dev へ誘導する案内だけが出る
    expect(find.byIcon(Icons.favorite), findsNothing);
    expect(find.text('5.7万'), findsOneWidget);
    expect(find.text('いいね は topaz.dev で行えます'), findsOneWidget);
    expect(find.text('開く'), findsOneWidget);
  });

  testWidgets('技術タグでフィルターできる', (WidgetTester tester) async {
    await pumpFeed(tester);
    await tester.pump(const Duration(seconds: 1));

    // チップ行は横スクロールするので、目的のタグまでスクロールしてからタップ
    await tester.dragUntilVisible(
      find.text('Swift'),
      find.byType(ListView),
      const Offset(-120, 0),
    );
    await tester.tap(find.text('Swift'));
    await tester.pumpAndSettle();

    expect(find.text('@sound_walker'), findsOneWidget);
    expect(find.text('@akubi'), findsNothing);
  });
}
