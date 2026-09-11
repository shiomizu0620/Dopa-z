import 'dart:math';

import 'package:dopaz/layout.dart';
import 'package:dopaz/models/project.dart';
import 'package:dopaz/pages/feed_page.dart';
import 'package:dopaz/repositories/feed_repository.dart';
import 'package:dopaz/theme.dart';
import 'package:dopaz/widgets/dopaz_logo.dart';
import 'package:dopaz/widgets/feed_seek_bar.dart';
import 'package:dopaz/widgets/feed_top_bar.dart';
import 'package:dopaz/widgets/project_card.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// 同じ技術タグだけを持つプロジェクトを並べたページ。
ProjectPage _techPage({
  required int number,
  required int lastPage,
  required String tech,
  required List<String> ids,
}) {
  return ProjectPage.fromJson({
    'current_page': number,
    'last_page': lastPage,
    'data': [
      for (final id in ids)
        _projectJson(
          id: id,
          title: '$id のプロジェクト',
          displayName: id,
          userName: id,
          techs: [tech],
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

/// Swift は1ページ目の2件だけで、残りのページはすべて Go というフィード。
/// Swift で絞り込むと、何ページ読んでも表示が増えない状況を再現できる。
_FakeFeed _sparseTagFeed({int lastPage = 10}) {
  return _FakeFeed([
    _techPage(number: 1, lastPage: lastPage, tech: 'Swift', ids: ['s1', 's2']),
    for (var page = 2; page <= lastPage; page++)
      _techPage(number: page, lastPage: lastPage, tech: 'Go', ids: ['g$page']),
  ]);
}

/// スマホ相当 (オーバーフロー検出のため実機に近い大きさにする)。
const _phone = Size(390, 844);

/// デスクトップのブラウザ相当。
const _desktop = Size(1440, 900);

/// テストの画面サイズを [size] にする。
///
/// `setSurfaceSize` はレイアウトに使う大きさしか変えず、MediaQuery には
/// 既定の 800x600 が残る。画面幅で表示を出し分けるようになったので、
/// 両方が同じ大きさを見るように view ごと差し替える。
void _useScreen(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

void main() {
  /// 並び順を検証したいので、既定では順番が変わらない乱数を使う。
  Future<void> pumpFeed(
    WidgetTester tester,
    ProjectFeed feed, {
    Random? random,
    Brightness brightness = Brightness.light,
    Size size = _phone,
  }) async {
    _useScreen(tester, size);
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

  group('デスクトップ幅', () {
    /// ホイールを1ノッチぶん回す。
    ///
    /// 慣性で流れてくる分と区別するために時刻を見ているので、
    /// 2回目以降は [at] をずらす。
    Future<void> scroll(
      WidgetTester tester,
      double dy, {
      Duration at = Duration.zero,
    }) async {
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      final center = tester.getCenter(find.byType(PageView));
      await tester.sendEventToBinding(pointer.hover(center));
      await tester.sendEventToBinding(
        pointer.scroll(Offset(0, dy), timeStamp: at),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('フィードは中央に寄り、アクション列はその外に出る', (WidgetTester tester) async {
      await pumpFeed(tester, _FakeFeed([_page1()]), size: _desktop);
      await tester.pumpAndSettle();

      final stage = tester.getRect(find.byType(PageView));
      // 画面いっぱいには広げず、中央に1本だけ置く
      expect(stage.width, lessThan(_desktop.width / 2));
      expect(stage.center.dx, closeTo(_desktop.width / 2, 1));

      // アクション列はカードに重ならず、右隣に1つだけ出る
      final rail = tester.getRect(find.byType(ProjectActionRail));
      expect(find.byType(ProjectActionRail), findsOneWidget);
      expect(rail.left, greaterThanOrEqualTo(stage.right));

      // 外側は surface と別の色にして、中央のカードを浮かせる
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, TopazColors.light.canvas);
    });

    testWidgets('作者情報は左、ページ送りは画面の右端に置く', (WidgetTester tester) async {
      await pumpFeed(tester, _FakeFeed([_page1()]), size: _desktop);
      await tester.pumpAndSettle();

      final stage = tester.getRect(find.byType(PageView));

      // 作者情報はカードの中ではなく、左隣に1組だけ出る
      expect(find.byType(ProjectInfo), findsOneWidget);
      final meta = tester.getRect(find.byType(ProjectInfo));
      expect(meta.right, lessThanOrEqualTo(stage.left));
      // 下端はサムネイルに揃える
      expect(meta.bottom, closeTo(stage.bottom, 1));

      // ページ送りはアクション列と離して画面の右端へ。
      // いいねを押すつもりで次のカードに送ってしまわないようにする。
      final rail = tester.getRect(find.byType(ProjectActionRail));
      final next = tester.getRect(find.byTooltip('次へ (↓)'));
      expect(next.left, greaterThan(rail.right));
      expect(next.right, closeTo(_desktop.width - kStagePadding, 1));

      // 上下2つはステージの高さの中央に並べる
      final previous = tester.getRect(find.byTooltip('前へ (↑)'));
      expect((previous.top + next.bottom) / 2, closeTo(stage.center.dy, 1));
    });

    testWidgets('ページを送ると左の作者情報も入れ替わる', (WidgetTester tester) async {
      await pumpFeed(tester, _FakeFeed([_page1()]), size: _desktop);
      await tester.pumpAndSettle();

      expect(find.text('ドーパミン駆動のプロジェクト発見アプリ'), findsOneWidget);

      await tester.tap(find.byTooltip('次へ (↓)'));
      await tester.pumpAndSettle();

      expect(find.text('共同編集ホワイトボード'), findsOneWidget);
      expect(find.text('ドーパミン駆動のプロジェクト発見アプリ'), findsNothing);
    });

    testWidgets('ホイールを回すと1ページだけ送る', (WidgetTester tester) async {
      await pumpFeed(tester, _FakeFeed([_page1()]), size: _desktop);
      await tester.pumpAndSettle();

      await scroll(tester, 100);

      // 1ノッチで1枚。行き過ぎて2枚送ってしまわない
      expect(find.text('@hackathon_taro'), findsOneWidget);
      expect(find.text('@akubi'), findsNothing);
    });

    testWidgets('ホイールの慣性で何ページも飛ばさない', (WidgetTester tester) async {
      await pumpFeed(tester, _FakeFeed([_page1()]), size: _desktop);
      await tester.pumpAndSettle();

      // 指を離したあとに続けて届く分は、まとめて1ページぶんとして扱う
      await scroll(tester, 100);
      await scroll(tester, 100, at: const Duration(milliseconds: 30));
      await scroll(tester, 100, at: const Duration(milliseconds: 60));

      expect(find.text('@hackathon_taro'), findsOneWidget);
    });

    testWidgets('矢印キーで前後に送れる', (WidgetTester tester) async {
      await pumpFeed(tester, _FakeFeed([_page1()]), size: _desktop);
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(find.text('@hackathon_taro'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(find.text('@akubi'), findsOneWidget);
    });

    testWidgets('先頭では前へのボタンを押せない', (WidgetTester tester) async {
      await pumpFeed(tester, _FakeFeed([_page1()]), size: _desktop);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('次へ (↓)'));
      await tester.pumpAndSettle();
      expect(find.text('@hackathon_taro'), findsOneWidget);

      await tester.tap(find.byTooltip('前へ (↑)'));
      await tester.pumpAndSettle();
      expect(find.text('@akubi'), findsOneWidget);

      // 先頭に戻ったら、前へは押せなくなる
      final up = tester.widget<InkWell>(
        find.descendant(
          of: find.byTooltip('前へ (↑)'),
          matching: find.byType(InkWell),
        ),
      );
      expect(up.onTap, isNull);
    });
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

  /// 縦スワイプ1回分。[back] なら前のカードへ戻る。
  Future<void> swipe(WidgetTester tester, {bool back = false}) async {
    await tester.fling(
      find.byType(PageView),
      Offset(0, back ? 400 : -400),
      1000,
    );
    await tester.pumpAndSettle();
  }

  /// Swift で絞り込んだ状態にする。1ページ目の2件だけが残る。
  Future<_FakeFeed> pumpFilteredToSwift(WidgetTester tester) async {
    final feed = _sparseTagFeed();
    await pumpFeed(tester, feed);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Swift'));
    await tester.pumpAndSettle();

    expect(find.text('@s1'), findsOneWidget);
    return feed;
  }

  testWidgets('絞り込み中に空振りが続いたら読み込みを止める', (WidgetTester tester) async {
    final feed = await pumpFilteredToSwift(tester);

    // 初回の2ページ (1ページ目 + ランダムに1ページ)
    expect(feed.requestedPages, hasLength(2));

    // 表示は2件しかないので、スワイプするたびに追加読み込みの条件が成立する。
    // 該当が増えないまま3回空振りしたら自動取得をあきらめる。
    await swipe(tester);
    await swipe(tester, back: true);
    await swipe(tester);
    expect(feed.requestedPages, hasLength(5));

    // 止まったことが分かる案内が末尾に出る
    await swipe(tester);
    expect(find.text('これ以上見つかりませんでした'), findsOneWidget);

    // ここから先は何度スワイプしてもリクエストは増えない
    await swipe(tester, back: true);
    await swipe(tester);
    await swipe(tester, back: true);
    expect(feed.requestedPages, hasLength(5));
  });

  testWidgets('止めたあとも「もっと読む」なら読みに行ける', (WidgetTester tester) async {
    final feed = await pumpFilteredToSwift(tester);

    await swipe(tester);
    await swipe(tester, back: true);
    await swipe(tester);
    await swipe(tester);
    expect(feed.requestedPages, hasLength(5));

    // 手動なら何度でも押せる
    await tester.tap(find.text('もっと読む'));
    await tester.pumpAndSettle();
    expect(feed.requestedPages, hasLength(6));

    await tester.tap(find.text('もっと読む'));
    await tester.pumpAndSettle();
    expect(feed.requestedPages, hasLength(7));
  });

  testWidgets('絞り込み中に見えないカードの画像を先読みしない', (WidgetTester tester) async {
    final precached = <String>[];
    debugOnPrecache = precached.add;
    addTearDown(() => debugOnPrecache = null);

    await pumpFilteredToSwift(tester);
    // 表示中の2件はこの時点で温まっている
    precached.clear();

    // スワイプで追加読み込みが走るが、届くのは Go のカードだけ。
    // 絞り込みで落ちて画面に出ないものを温めても無駄なので、何も増えない。
    await swipe(tester);

    expect(precached, isEmpty);
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
