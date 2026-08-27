import 'package:dopaz/models/project.dart';
import 'package:dopaz/pages/feed_page.dart';
import 'package:dopaz/repositories/feed_repository.dart';
import 'package:dopaz/widgets/dopaz_logo.dart';
import 'package:dopaz/widgets/feed_seek_bar.dart';
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

ProjectPage _page2() {
  return ProjectPage.fromJson({
    'current_page': 2,
    'last_page': 2,
    'data': [
      _projectJson(
        id: 'p4',
        title: '2ページ目のプロジェクト',
        displayName: 'つぎ',
        userName: 'next_user',
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
  Future<void> pumpFeed(WidgetTester tester, ProjectFeed feed) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: FeedPage(repository: feed)));
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

  testWidgets('末尾に近づくと次のページを読み込む', (WidgetTester tester) async {
    final feed = _FakeFeed([_page1(lastPage: 2), _page2()]);
    await pumpFeed(tester, feed);
    await tester.pumpAndSettle();

    expect(feed.requestedPages, [1]);

    // 3件しかないので1回スワイプすれば残り2件になり追加読み込みが走る
    await tester.fling(find.byType(PageView), const Offset(0, -400), 1000);
    await tester.pumpAndSettle();

    expect(feed.requestedPages, [1, 2]);

    // 追加分まで進める
    await tester.fling(find.byType(PageView), const Offset(0, -400), 1000);
    await tester.pumpAndSettle();
    await tester.fling(find.byType(PageView), const Offset(0, -400), 1000);
    await tester.pumpAndSettle();

    expect(find.text('@next_user'), findsOneWidget);
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
