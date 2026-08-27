import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dopaz/main.dart';

void main() {
  testWidgets('アプリが起動してローディングが表示される', (WidgetTester tester) async {
    await tester.pumpWidget(const DopazApp());

    // FeedRepositoryのモックディレイ中はローディング表示
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // モックディレイ(500ms)を消化してタイマー残りをなくす
    await tester.pump(const Duration(seconds: 1));
  });
}
