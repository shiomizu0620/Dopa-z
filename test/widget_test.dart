import 'dart:math';

import 'package:dopaz/models/project.dart';
import 'package:dopaz/pages/feed_page.dart';
import 'package:dopaz/repositories/feed_repository.dart';
import 'package:dopaz/theme.dart';
import 'package:dopaz/widgets/dopaz_logo.dart';
import 'package:dopaz/widgets/feed_seek_bar.dart';
import 'package:dopaz/widgets/feed_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 実APIと同じ形のプロジェクト1件分のJSON。
Map<String, dynamic> _projectJson({
  required String id,
  required String title,
  required String displayName,
  required String userName,
  required List<String> techs,
  int likeCount = 0,
  String githubId = '',
  String twitterId = '',
}) {
  return {
    'id': id,
    'title': title,
    'thumbnail_path': 'project/$id.png',
    'technology_tag_list': [
      for (final tech in techs)
        {'id': tech, 'icon_path': 'technology-tag/x.svg', 'type': 'language'},
    ],
    'user': {
      'id': 'u_$id',
      'display_name': displayName,
      'avatar_image_path':
          'https://ptera-publish.topaz.dev/defaults/no_avatar.jpg',
      'user_name': userName,
      'social': {'github_id': githubId, 'twitter_id': twitterId},
    },
    'like_count': likeCount,
    'hackathon': null,
  };
}

ProjectPage _page1({int lastPage = 1}) {
  return ProjectPage.fromJson({
    'current_page': 1,
    'last_page': lastPage,
    'data': [
      _projectJson(
        id: 'p1',
        title: 'ドーパミン駆動のプロジェクト発見アプリ',
        displayName: 'あくび',
        userName: 'akubi',
        techs: ['Flutter', 'Dart'],
        likeCount: 57000,
        githubId: 'akubi-gh',
        twitterId: 'akubi-x',
      ),
      _projectJson(
        id: 'p2',
        title: '共同編集ホワイトボード',
        displayName: 'たろう',
        userName: 'hackathon_taro',
        techs: ['React', 'TypeScript'],
        likeCount: 12,
      ),
      _projectJson(
        id: 'p3',
        title: '位置情報の音楽シェアマップ',
        displayName: 'さうんど',
        userName: 'sound_walker',
        techs: ['Swift'],
      ),
    ],
  });
}

/// 1件だけ載せたページ。
ProjectPage _singleItemPage({
  required int number,
  required int lastPage,
  required String userName,
}) {
  return ProjectPage.fromJson({
    'current_page': number,
    'last_page': lastPage,
    'data': [
      _projectJson(
        id: 'p_$userName',
        title: '$number ページ目のプロジェクト',
        displayName: userName,
        userName: userName,
        techs: ['Go'],
      ),
    ],
  });
}

/// 固定のページを返すテスト用のフィード。
class _FakeFeed implements ProjectFeed {
  _FakeFeed(this.pages);

  final List<ProjectPage> pages;
  final List<int> requestedPages = [];

  @override
  Future<ProjectPage> fetchProjects({int page = 1}) async {
    requestedPages.add(page);
    return pages[page - 1];
  }
}

/// shuffle しても並びが変わらない Random。
/// `nextInt(n)` が常に `n - 1` を返すと、Dartのshuffleは要素を動かさない。
class _NoShuffle implements Random {
  @override
  int nextInt(int max) => max - 1;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}

/// 必ず失敗するフィード。
class _FailingFeed implements ProjectFeed {
  int calls = 0;

  @override
  Future<ProjectPage> fetchProjects({int page = 1}) async {
    calls++;
    throw const FeedException('通信に失敗しました');
  }
}

void main() {
  /// スマホ相当のサイズで描画する(オーバーフロー検出のため)。
  /// 並び順を検証したいので、既定では順番が変わらない乱数を使う。
  Future<void> pumpFeed(
    WidgetTester tester,
    ProjectFeed feed, {
    Random? random,
    Brightness brightness = Brightness.light,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: TopazColors.light.toThemeData(Brightness.light),
        darkTheme: TopazColors.dark.toThemeData(Brightness.dark),
        themeMode: brightness == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light,
        home: FeedPage(repository: feed, random: random ?? _NoShuffle()),
      ),
    );
  }

  testWidgets('起動直後はローディングが表示される', (WidgetTester tester) async {
    await pumpFeed(tester, _FakeFeed([_page1()]));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
  });

  testWidgets('読み込み後にShorts風のUIが表示される', (WidgetTester tester) async {
    await pumpFeed(tester, _FakeFeed([_page1()]));
    await tester.pumpAndSettle();

    // ヘッダーとフィルターチップ
    expect(find.byType(DopazLogo), findsOneWidget);
    expect(find.text('すべて'), findsOneWidget);
    expect(find.text('Flutter'), findsOneWidget);

    // 1件目のカード
    expect(find.text('あくび'), findsOneWidget);
    expect(find.text('@akubi'), findsOneWidget);
    expect(find.text('ドーパミン駆動のプロジェクト発見アプリ'), findsOneWidget);
    expect(find.text('#Flutter #Dart'), findsOneWidget);

    // 右下のアクションレール(5.7万 = 57000件のいいね)
    expect(find.text('5.7万'), findsOneWidget);
    expect(find.text('共有'), findsOneWidget);
    expect(find.text('topaz'), findsOneWidget);
  });

  testWidgets('縦スワイプで次のプロジェクトに進む', (WidgetTester tester) async {
    await pumpFeed(tester, _FakeFeed([_page1()]));
    await tester.pumpAndSettle();

    await tester.fling(find.byType(PageView), const Offset(0, -400), 1000);
    await tester.pumpAndSettle();

    expect(find.text('@hackathon_taro'), findsOneWidget);
    expect(find.text('@akubi'), findsNothing);
  });

  testWidgets('いいねは表示のみでアプリからは操作できない', (WidgetTester tester) async {
    await pumpFeed(tester, _FakeFeed([_page1()]));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.favorite_border).first);
    await tester.pumpAndSettle();

    // 状態は変わらず、topaz.dev へ誘導する案内だけが出る
    expect(find.byIcon(Icons.favorite), findsNothing);
    expect(find.text('5.7万'), findsOneWidget);
    expect(find.text('いいね は topaz.dev で行えます'), findsOneWidget);
    expect(find.text('開く'), findsOneWidget);
  });

  testWidgets('技術タグでフィルターできる', (WidgetTester tester) async {
    await pumpFeed(tester, _FakeFeed([_page1()]));
    await tester.pumpAndSettle();

    // チップ行は横スクロールするので、目的のタグを描画させてから
    // 完全に画面内に入れてタップする
    await tester.dragUntilVisible(
      find.text('Swift'),
      find.byType(ListView),
      const Offset(-120, 0),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Swift'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Swift'));
    await tester.pumpAndSettle();

    expect(find.text('@sound_walker'), findsOneWidget);
    expect(find.text('@akubi'), findsNothing);
  });

  testWidgets('シークバーを横にドラッグして送れる', (WidgetTester tester) async {
    await pumpFeed(tester, _FakeFeed([_page1()]));
    await tester.pumpAndSettle();

    expect(find.text('@akubi'), findsOneWidget);

    // 左端から右端までドラッグすると最後のプロジェクトへ
    final bar = tester.getRect(find.byType(FeedSeekBar));
    await tester.dragFrom(
      bar.centerLeft + const Offset(1, 0),
      Offset(bar.width, 0),
    );
    await tester.pumpAndSettle();

    expect(find.text('@sound_walker'), findsOneWidget);
    expect(find.text('@akubi'), findsNothing);
  });

  testWidgets('シークバーをタップした位置に移動する', (WidgetTester tester) async {
    await pumpFeed(tester, _FakeFeed([_page1()]));
    await tester.pumpAndSettle();

    // 3件の中央をタップすると2件目
    await tester.tapAt(tester.getRect(find.byType(FeedSeekBar)).center);
    await tester.pumpAndSettle();

    expect(find.text('@hackathon_taro'), findsOneWidget);
  });

  testWidgets('初回に1ページ目ともう1ページを読み込む', (WidgetTester tester) async {
    final feed = _FakeFeed([
      _page1(lastPage: 3),
      _singleItemPage(number: 2, lastPage: 3, userName: 'second_user'),
      _singleItemPage(number: 3, lastPage: 3, userName: 'third_user'),
    ]);
    // 総ページ数を知るために1ページ目、そのあとランダムに1ページ
    await pumpFeed(tester, feed, random: Random(0));
    await tester.pumpAndSettle();

    expect(feed.requestedPages, hasLength(2));
    expect(feed.requestedPages.first, 1);
    expect(feed.requestedPages[1], isNot(1));
  });

  testWidgets('読み終わっていないページから追加で読み込む', (WidgetTester tester) async {
    final feed = _FakeFeed([
      _page1(lastPage: 3),
      _singleItemPage(number: 2, lastPage: 3, userName: 'second_user'),
      _singleItemPage(number: 3, lastPage: 3, userName: 'third_user'),
    ]);
    await pumpFeed(tester, feed);
    await tester.pumpAndSettle();

    // _NoShuffle は候補の末尾を選ぶので、初回は 1 と 3 ページ目
    expect(feed.requestedPages, [1, 3]);

    // 1回スワイプすると残りページ (2) を取りに行く
    await tester.fling(find.byType(PageView), const Offset(0, -400), 1000);
    await tester.pumpAndSettle();

    expect(feed.requestedPages, [1, 3, 2]);

    // 1ページ目の3件を過ぎると、あとから足したページの項目が出てくる
    await tester.fling(find.byType(PageView), const Offset(0, -400), 1000);
    await tester.pumpAndSettle();
    await tester.fling(find.byType(PageView), const Offset(0, -400), 1000);
    await tester.pumpAndSettle();

    expect(find.text('@third_user'), findsOneWidget);
    // 全ページ読み終わったのでもう取りに行かない
    expect(feed.requestedPages, [1, 3, 2]);
  });

  testWidgets('新着順に切り替えると1ページ目から順に読む', (WidgetTester tester) async {
    final feed = _FakeFeed([
      _page1(lastPage: 3),
      _singleItemPage(number: 2, lastPage: 3, userName: 'second_user'),
      _singleItemPage(number: 3, lastPage: 3, userName: 'third_user'),
    ]);
    await pumpFeed(tester, feed);
    await tester.pumpAndSettle();

    // ランダムなので1ページ目 + 別の1ページ
    expect(feed.requestedPages, [1, 3]);

    await tester.tap(find.text('新着'));
    await tester.pumpAndSettle();

    // 読み直して1ページ目から。続きは2ページ目
    expect(feed.requestedPages, [1, 3, 1]);
    expect(find.text('@akubi'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(0, -400), 1000);
    await tester.pumpAndSettle();

    expect(feed.requestedPages, [1, 3, 1, 2]);
  });

  testWidgets('ダークモードでも同じ内容が表示される', (WidgetTester tester) async {
    await pumpFeed(tester, _FakeFeed([_page1()]), brightness: Brightness.dark);
    await tester.pumpAndSettle();

    expect(find.byType(DopazLogo), findsOneWidget);
    expect(find.text('@akubi'), findsOneWidget);
    expect(find.text('5.7万'), findsOneWidget);

    // 背景がダークのパレットになっている
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, TopazColors.dark.surface);
  });

  testWidgets('並び順のトグルは現在の選択を示す', (WidgetTester tester) async {
    await pumpFeed(tester, _FakeFeed([_page1()]));
    await tester.pumpAndSettle();

    expect(find.text('新着'), findsOneWidget);
    expect(find.text('ランダム'), findsOneWidget);
  });

  testWidgets('ページ送りしてもヘッダーは作り直さない', (WidgetTester tester) async {
    await pumpFeed(tester, _FakeFeed([_page1()]));
    await tester.pumpAndSettle();

    final before = tester.widget<FeedTopBar>(find.byType(FeedTopBar));

    await tester.fling(find.byType(PageView), const Offset(0, -400), 1000);
    await tester.pumpAndSettle();

    // 同じインスタンスのままなら、ページ送りで画面全体を作り直していない
    final after = tester.widget<FeedTopBar>(find.byType(FeedTopBar));
    expect(identical(before, after), isTrue);
  });

  testWidgets('取得に失敗したら再読み込みできる', (WidgetTester tester) async {
    final feed = _FailingFeed();
    await pumpFeed(tester, feed);
    await tester.pumpAndSettle();

    expect(find.text('通信に失敗しました'), findsOneWidget);
    expect(feed.calls, 1);

    await tester.tap(find.text('再読み込み'));
    await tester.pumpAndSettle();

    expect(feed.calls, 2);
  });
}
