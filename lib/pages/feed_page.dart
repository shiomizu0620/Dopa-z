import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../layout.dart';
import '../models/feed_order.dart';
import '../models/project.dart';
import '../repositories/feed_repository.dart';
import '../theme.dart';
import '../widgets/feed_seek_bar.dart';
import '../widgets/feed_top_bar.dart';
import '../widgets/project_card.dart';
import '../widgets/wheel_pager.dart';

/// YouTube Shorts風の縦スワイプフィード。
class FeedPage extends StatefulWidget {
  const FeedPage({
    super.key,
    required this.repository,
    this.usingMockData = false,
    this.initialOrder = FeedOrder.random,
    this.random,
  });

  final ProjectFeed repository;

  /// 起動時の並び順。
  final FeedOrder initialOrder;

  /// サンプルデータを表示していることをヘッダーに出すか。
  final bool usingMockData;

  /// ページ選択とシャッフルに使う乱数。テストで固定するために差し替えられる。
  final Random? random;

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  /// 並び順を切り替えるとPageViewが作り直されるので、
  /// 前の位置を復元せず必ず先頭から始まるようにする。
  final PageController _pageController = PageController(keepPage: false);

  /// 現在ページの前後何件分のサムネイルを先読みするか。
  static const _precacheAhead = 3;
  static const _precacheBehind = 1;

  /// 追加読み込みしたページのうち、届いた時点で先読みしておく件数。
  static const _precacheOnArrival = 4;

  /// 残りがこの件数以下になったら次のページを取りに行く。
  /// 1ページ12件なので、半分ほど残っている時点で取り始める。
  static const _loadMoreThreshold = 6;

  /// フィルターチップに出す技術タグの最大数。
  static const _maxTechChips = 12;

  /// スワイプが止まってから先読みを始めるまでの待ち時間。
  static const _precacheDelay = Duration(milliseconds: 250);

  /// 追加読み込みが空振り (表示が1件も増えない) してよい回数。
  ///
  /// 絞り込み中は [_loadMoreThreshold] の判定が絞り込み後の件数で行われるので、
  /// 該当の少ないタグでは条件が成立したままになり、スワイプのたびに
  /// 1リクエスト飛ぶ。1セッションの上限は90ページ (約855MB) にもなるので、
  /// 空振りが続いたら自動取得はあきらめて手動の「もっと読む」に任せる。
  static const _maxEmptyLoadMore = 3;

  /// 先読み済みとして覚えておくURLの上限。
  ///
  /// ImageCache はメモリが埋まると古いものから追い出すので、ここに残って
  /// いても実体があるとは限らない。無制限に覚えていると
  /// 「先読みはもう走らないのに、表示時には読み直す」という一番損な状態が
  /// 増え続けるため、古いものから落として上限のある状態にする。
  /// 1ページ12件なので、300件あれば直近25ページ分をカバーできる。
  static const _maxPrecachedUrls = 300;

  late final Random _random = widget.random ?? Random();
  late FeedOrder _order = widget.initialOrder;

  bool _initialLoading = true;
  String? _error;

  List<Project> _allProjects = const [];
  List<String> _techs = const [];
  String? _selectedTech;

  /// 表示中のページ番号。ページ送りのたびに画面全体を作り直さずに済むよう、
  /// シークバーだけが購読する値として持つ。
  final ValueNotifier<int> _currentIndex = ValueNotifier(0);

  /// フィルター適用後の表示対象。
  /// ページ送りのたびに絞り込み直すと無駄なので、変わったときだけ作り直す。
  List<Project> _visible = const [];

  /// 技術タグの出現回数。追加読み込みのたびに全件を数え直さないよう持ち回る。
  final Map<String, int> _techCounts = {};

  /// 取得済みのページ番号。同じページを二度読まないために持つ。
  final Set<int> _loadedPages = {};
  int _lastPage = 1;
  bool _loadingMore = false;

  /// 「もっと読む」で取得中か。ボタンの見た目にしか使わない。
  bool _manualLoading = false;

  /// 追加読み込みしたのに [_visible] が1件も増えなかった回数。
  /// 絞り込みや並び順を変えたら数え直す。
  int _emptyLoadMore = 0;

  /// 自動の追加読み込みを止めているか。
  bool get _autoLoadStopped => _emptyLoadMore >= _maxEmptyLoadMore;

  /// 読み直しの世代。
  ///
  /// 並び順を素早く切り替えると [_loadInitial] が並行して走り、遅れて返って
  /// きた古い方が新しい方の結果を上書きしてしまう。開始時の世代と一致しない
  /// 結果は捨てることで、最後に始めた読み込みだけが画面に反映される。
  int _loadGeneration = 0;

  final Set<String> _precached = {};
  Timer? _precacheTimer;

  /// ホイールでのページ送り。ページをまたいで状態を持ちたいのでここに置く。
  late final WheelPaging _wheelPaging = WheelPaging(onPage: _movePage);

  /// [_allProjects] か [_selectedTech] を変えたら呼ぶ。
  void _updateVisible() {
    final tech = _selectedTech;
    _visible = tech == null
        ? _allProjects
        : _allProjects
              .where((p) => p.techs.contains(tech))
              .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _precacheTimer?.cancel();
    _currentIndex.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    final generation = ++_loadGeneration;
    setState(() {
      _initialLoading = true;
      _error = null;
    });
    try {
      // APIに並び替えの指定が無いので、まず1ページ目を取って総ページ数を知る。
      final first = await widget.repository.fetchProjects(page: 1);
      if (!_isCurrent(generation)) return;
      _loadedPages.add(first.currentPage);
      _lastPage = first.lastPage;

      final projects = [...first.projects];
      if (_order == FeedOrder.random) {
        // 1ページ目 (新着) だけに偏らないよう、全体からもう1ページ混ぜる。
        // ここで2ページ分持っておくと、最初の追加読み込みまでの余裕もできる。
        projects.addAll(await _fetchNextPage() ?? const []);
        if (!_isCurrent(generation)) return;
        projects.shuffle(_random);
      }

      setState(() {
        _allProjects = projects;
        _updateVisible();
        _countTechs(projects);
        _techs = _topTechs();
        _initialLoading = false;
      });
      // 初回はスワイプ中ではないのですぐ展開してよい
      _precacheAround(0);
    } catch (e) {
      if (!_isCurrent(generation)) return;
      setState(() {
        _error = e is FeedException ? e.message : '$e';
        _initialLoading = false;
      });
    }
  }

  /// [generation] で始めた読み込みの結果を、まだ画面に反映してよいか。
  bool _isCurrent(int generation) => mounted && generation == _loadGeneration;

  /// まだ読んでいないページを1つ取る。
  /// 全ページ読み終わっている、または失敗した場合は null。
  Future<List<Project>?> _fetchNextPage() async {
    final generation = _loadGeneration;
    final page = _pickUnloadedPage();
    if (page == null) return null;
    try {
      final result = await widget.repository.fetchProjects(page: page);
      // 待っている間に読み直しが始まっていたら、取得済みページや総ページ数を
      // 書き戻すと新しい方の状態が壊れるので、結果ごと捨てる。
      if (generation != _loadGeneration) return null;
      _loadedPages.add(result.currentPage);
      _lastPage = result.lastPage;
      final projects = result.projects.toList();
      if (_order == FeedOrder.random) projects.shuffle(_random);
      return projects;
    } catch (_) {
      return null;
    }
  }

  /// 次に読むページ番号を並び順に応じて選ぶ。
  /// 新着順なら続きのページ、ランダムなら未読からランダムに1つ。
  int? _pickUnloadedPage() {
    if (_order == FeedOrder.latest) {
      final next = _loadedPages.isEmpty ? 1 : _loadedPages.reduce(max) + 1;
      return next <= _lastPage ? next : null;
    }
    final candidates = [
      for (var page = 1; page <= _lastPage; page++)
        if (!_loadedPages.contains(page)) page,
    ];
    if (candidates.isEmpty) return null;
    return candidates[_random.nextInt(candidates.length)];
  }

  /// 並び順を切り替えて読み直す。
  void _onOrderSelected(FeedOrder order) {
    if (order == _order) return;
    _precacheTimer?.cancel();
    setState(() {
      _order = order;
      _allProjects = const [];
      _techs = const [];
      _techCounts.clear();
      _selectedTech = null;
      _updateVisible();
      _emptyLoadMore = 0;
      _loadedPages.clear();
      _lastPage = 1;
    });
    _currentIndex.value = 0;
    _loadInitial();
  }

  /// 次のページを先に読み込んでおく。失敗しても画面は止めない。
  Future<void> _loadMore() async {
    if (_loadingMore) return;
    _loadingMore = true;
    try {
      final projects = await _fetchNextPage();
      if (projects == null || projects.isEmpty || !mounted) return;
      final visibleBefore = _visible.length;
      setState(() {
        _allProjects = [..._allProjects, ...projects];
        _updateVisible();
        // 増えた分だけ数え直す
        _countTechs(projects);
        _techs = _topTechs();
        // 絞り込みに1件も引っかからなければ空振り。
        // 続くようなら _autoLoadStopped で自動取得を止める。
        _emptyLoadMore = _visible.length == visibleBefore
            ? _emptyLoadMore + 1
            : 0;
      });
      // 届いた時点で先頭の何件かを先読みしておき、
      // スワイプが追いついたときに読み込み待ちにならないようにする。
      // 絞り込みで落ちたカードはユーザーの目に触れないので、
      // 数える位置は _allProjects ではなく _visible の末尾。
      _precacheRange(
        visibleBefore,
        visibleBefore + _precacheOnArrival,
        _visible,
      );
    } finally {
      _loadingMore = false;
    }
  }

  /// 「もっと読む」を押されたとき。
  ///
  /// 空振りが続いて自動取得を止めていても、押された分は取りに行く。
  /// 空振りの回数はここでは戻さないので、押しても見つからなければ案内は
  /// 出たままになり、見つかれば [_loadMore] 側で 0 に戻って自動取得が再開する。
  Future<void> _loadMoreManually() async {
    if (_loadingMore) return;
    setState(() => _manualLoading = true);
    await _loadMore();
    if (!mounted) return;
    setState(() => _manualLoading = false);
  }

  /// 追加された分の技術タグを数に足す。
  void _countTechs(Iterable<Project> projects) {
    for (final project in projects) {
      for (final tech in project.techs) {
        _techCounts[tech] = (_techCounts[tech] ?? 0) + 1;
      }
    }
  }

  /// 出現回数の多い順に上位の技術タグを返す。
  List<String> _topTechs() {
    final techs = _techCounts.keys.toList()
      ..sort((a, b) => _techCounts[b]!.compareTo(_techCounts[a]!));
    return techs.take(_maxTechChips).toList();
  }

  /// [index] の前後のサムネイルをImageCacheに先読みし、
  /// スワイプした瞬間に表示できるようにする。
  void _precacheAround(int index) {
    _precacheRange(index - _precacheBehind, index + _precacheAhead, _visible);
  }

  /// [from] から [to] までのサムネイルをImageCacheに読み込んでおく。
  void _precacheRange(int from, int to, [List<Project>? source]) {
    final projects = source ?? _allProjects;
    // 範囲がまるごと末尾より後ろなら、末尾を温め直すだけになるので何もしない
    if (projects.isEmpty || from >= projects.length) return;
    final start = from.clamp(0, projects.length - 1);
    final end = to.clamp(0, projects.length - 1);
    for (var i = start; i <= end; i++) {
      final url = projects[i].thumbnailUrl;
      if (url.isEmpty) continue;
      if (_rememberPrecached(url)) {
        debugOnPrecache?.call(url);
        // 先読み失敗は無視(表示時にerrorBuilderで処理される)
        precacheImage(
          thumbnailProvider(context, url),
          context,
          onError: (_, __) {},
        );
      }
    }
  }

  /// [url] を先読み済みとして覚える。既に覚えていれば false。
  ///
  /// Set は挿入順を保つので、あふれた分は古い方から落とせる。
  bool _rememberPrecached(String url) {
    if (!_precached.add(url)) return false;
    while (_precached.length > _maxPrecachedUrls) {
      _precached.remove(_precached.first);
    }
    return true;
  }

  /// スワイプが落ち着いてから先読みする。
  ///
  /// precacheImage は名前に反してその場で画像を展開するので、
  /// ページ送りの最中に呼ぶとそのフレームが落ちて引っかかりの原因になる。
  /// 連続でスワイプされている間はタイマーが張り直されるため、
  /// 通り過ぎるだけのページを展開してしまうことも防げる。
  void _schedulePrecache(int index) {
    _precacheTimer?.cancel();
    _precacheTimer = Timer(_precacheDelay, () {
      if (mounted) _precacheAround(index);
    });
  }

  void _onPageChanged(int index) {
    // シークバーだけ更新したいので、画面全体は作り直さない
    _currentIndex.value = index;
    _schedulePrecache(index);
    // 空振りが続いているときは、スワイプのたびに無駄なリクエストを
    // 出し続けることになるので、あとは手動の「もっと読む」に任せる。
    if (!_autoLoadStopped && index >= _visible.length - _loadMoreThreshold) {
      _loadMore();
    }
  }

  /// シークバーで指した位置へ送る。
  void _seekTo(int index) {
    if (!_pageController.hasClients) return;
    _pageController.jumpToPage(index);
  }

  /// [PageView] に並べる枚数。自動取得を止めたときの案内1枚を含む。
  int get _itemCount => _visible.length + (_autoLoadStopped ? 1 : 0);

  /// 現在地から [delta] 枚ぶん送る。端まで来ていたら何もしない。
  ///
  /// スワイプできない環境 (マウスやキーボード) からの操作をここに集める。
  void _movePage(int delta) {
    if (!_pageController.hasClients) return;
    final current = _pageController.page?.round() ?? _currentIndex.value;
    final target = current + delta;
    if (target < 0 || target >= _itemCount) return;
    _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  /// 次のページに送るキー。矢印のほかに、スクロール系のUIでよく使われる
  /// PageDown と Vim風の J も受ける。
  static final _nextKeys = {
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.pageDown,
    LogicalKeyboardKey.keyJ,
  };

  /// 前のページに戻すキー。
  static final _previousKeys = {
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.pageUp,
    LogicalKeyboardKey.keyK,
  };

  /// キーボードでのページ送り。
  ///
  /// ボタンにフォーカスが移っていても、キーイベントは先祖の [Focus] まで
  /// 上がってくるのでここで受け取れる。矢印キーを [KeyEventResult.handled]
  /// にすることで、既定のフォーカス移動に持っていかれるのも防ぐ。
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (_nextKeys.contains(key)) {
      _movePage(1);
      return KeyEventResult.handled;
    }
    if (_previousKeys.contains(key)) {
      _movePage(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      _seekTo(0);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      if (_itemCount > 0) _seekTo(_itemCount - 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _onTechSelected(String? tech) {
    setState(() {
      _selectedTech = tech;
      _updateVisible();
      // 絞り込みが変われば空振りの意味も変わるので数え直す
      _emptyLoadMore = 0;
    });
    _currentIndex.value = 0;
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
    _precacheAround(0);
  }

  /// topaz.dev や作者のSNSページを外部ブラウザで開く。
  Future<void> _openUrl(String url) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('開けませんでした: $url')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = TopazColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final wide = isWideLayout(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // ステータスバーの文字色を背景と反対にする
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        // 広い画面ではステージの外側を一段沈ませて、中央の1枚を浮かせる
        backgroundColor: wide ? colors.canvas : colors.surface,
        // キーボードでもページを送れるようにする (Web/デスクトップ向け)
        body: Focus(
          autofocus: true,
          onKeyEvent: _onKey,
          child: Column(
            children: [
              // 上部のセーフエリアは FeedTopBar が確保する
              FeedTopBar(
                techs: _techs,
                selectedTech: _selectedTech,
                onTechSelected: _onTechSelected,
                order: _order,
                onOrderSelected: _onOrderSelected,
                showMockBadge: widget.usingMockData,
              ),
              Expanded(
                child: wide ? _buildWide(colors, isDark) : _buildNarrow(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// スマホ幅。フィードを画面いっぱいに広げ、シークバーを画面の下端に置く。
  Widget _buildNarrow() {
    return Column(
      children: [
        Expanded(child: _buildBody()),
        if (_hasItems) SafeArea(top: false, child: _buildSeekBar()),
      ],
    );
  }

  /// デスクトップ幅。Shorts と同じ三分割で、
  /// 左に作者情報、中央にサムネイル、右にアクション列とページ送りを置く。
  ///
  /// 画面いっぱいに広げると、横長のサムネイルが中央に取り残されたまま
  /// アクション列だけが画面の右端まで離れてしまう。見るものを1本にまとめて、
  /// 目線と操作を同じ場所に集める。
  Widget _buildWide(TopazColors colors, bool isDark) {
    final width = feedWidth(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(kStagePadding, 16, kStagePadding, 20),
      child: Column(
        children: [
          Expanded(
            child: Row(
              // 左右のガターを同じ幅にすることで、ステージが画面の中央に来る。
              // 伸び縮みするのは外側だけで、中央の幅は画面サイズだけで決まる。
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildMeta()),
                SizedBox(width: width, child: _buildStage(colors, isDark)),
                Expanded(child: _buildRightGutter()),
              ],
            ),
          ),
          // シークバーはステージと同じ幅にする。ステージが画面の中央にあるので、
          // ここで中央に置けば真下に並ぶ。
          if (_hasItems)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: SizedBox(width: width, child: _buildSeekBar()),
            ),
        ],
      ),
    );
  }

  /// 中央に置く1枚ぶんのフィード。角を丸めて1枚のカードに見せる。
  Widget _buildStage(TopazColors colors, bool isDark) {
    const radius = BorderRadius.all(Radius.circular(20));
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      // 罫線は中身より前に描かないと、角の内側でサムネイルに隠れる
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: colors.border),
      ),
      child: ClipRRect(borderRadius: radius, child: _buildBody()),
    );
  }

  /// ステージの左に置く、作者・タイトル・技術タグ。
  ///
  /// サムネイルの上に重ねると肝心の画像が隠れるので、Shorts と同じく外に出し、
  /// 下端をサムネイルに揃える。ガターは画面幅に応じて広がるが、離れすぎると
  /// 読みづらいので [kMetaMaxWidth] で止めてステージ側に寄せる。
  Widget _buildMeta() {
    if (!_hasItems) return const SizedBox.shrink();
    return ValueListenableBuilder<int>(
      valueListenable: _currentIndex,
      builder: (context, index, _) {
        // 末尾の案内ページには出すものがない
        if (index >= _visible.length) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.bottomRight,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kMetaMaxWidth),
            child: ProjectInfo(
              project: _visible[index],
              onOpenUrl: _openUrl,
              // 右の余白でステージとの間を空ける
              padding: const EdgeInsets.only(right: kStageGap, bottom: 14),
            ),
          ),
        );
      },
    );
  }

  /// ステージの右。すぐ隣にアクション列、画面の右端にページ送りのボタン。
  ///
  /// ページ送りをアクション列の上に積むと、いいねを押すつもりで次のカードへ
  /// 送ってしまう。送る操作はカードへの操作から離して端に置く。
  Widget _buildRightGutter() {
    if (!_hasItems) return const SizedBox.shrink();
    return ValueListenableBuilder<int>(
      valueListenable: _currentIndex,
      builder: (context, index, _) {
        // 末尾の案内ページにはアクションの対象がない
        final project = index < _visible.length ? _visible[index] : null;
        return Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: kStageGap),
              child: SizedBox(
                width: kRailWidth,
                child: project == null
                    ? null
                    : Align(
                        // サムネイルの下端に揃える
                        alignment: Alignment.bottomCenter,
                        child: ProjectActionRail(
                          project: project,
                          onOpenUrl: _openUrl,
                          // サムネイルの外に出るので、読みやすくする縁取りは要らない
                          overlay: false,
                        ),
                      ),
              ),
            ),
            const Spacer(),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _NavButton(
                  icon: Icons.keyboard_arrow_up,
                  tooltip: '前へ (↑)',
                  onTap: index > 0 ? () => _movePage(-1) : null,
                ),
                const SizedBox(height: 12),
                _NavButton(
                  icon: Icons.keyboard_arrow_down,
                  tooltip: '次へ (↓)',
                  onTap: index < _itemCount - 1 ? () => _movePage(1) : null,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// フィードに出せるカードがあるか。
  /// 読み込み中やエラー中は、シークバーもページ送りのボタンも出さない。
  bool get _hasItems =>
      !_initialLoading && _error == null && _visible.isNotEmpty;

  Widget _buildSeekBar() {
    // ページ送りで作り直すのはこの部分だけにする
    return ValueListenableBuilder<int>(
      valueListenable: _currentIndex,
      builder: (context, index, _) => FeedSeekBar(
        itemCount: _visible.length,
        currentIndex: index.clamp(0, _visible.length - 1),
        onSeek: _seekTo,
      ),
    );
  }

  Widget _buildBody() {
    final colors = TopazColors.of(context);
    if (_initialLoading) {
      return Center(child: CircularProgressIndicator(color: colors.cyan));
    }
    if (_error != null) {
      return _ErrorView(message: _error!, onRetry: _loadInitial);
    }
    final projects = _visible;
    if (projects.isEmpty) {
      return Center(
        child: Text('プロジェクトがありません', style: TextStyle(color: colors.muted)),
      );
    }
    final wide = isWideLayout(context);
    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      allowImplicitScrolling: true,
      // 自動取得を止めたことが伝わるよう、末尾に案内を1枚だけ差し込む
      itemCount: _itemCount,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, index) {
        // ホイールは PageView より内側で受け取らないと Scrollable に取られる
        return WheelPager(
          paging: _wheelPaging,
          child: index >= projects.length
              ? _NoMoreView(
                  loading: _manualLoading,
                  onLoadMore: _loadMoreManually,
                )
              : ProjectCard(
                  project: projects[index],
                  onOpenUrl: _openUrl,
                  // 広い画面では作者情報もアクション列もステージの外に出す
                  showChrome: !wide,
                ),
        );
      },
    );
  }
}

/// 画面の右端に置く、前後のページへ送る丸ボタン。
class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;

  /// null なら端まで来ているので押せない。
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = TopazColors.of(context);
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: colors.cyanSurface.withValues(alpha: enabled ? 1 : 0.4),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              icon,
              size: 26,
              color: enabled
                  ? colors.deep
                  : colors.muted.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}

/// 絞り込み中に自動取得を止めたときに、フィードの末尾に出す案内。
class _NoMoreView extends StatelessWidget {
  const _NoMoreView({required this.loading, required this.onLoadMore});

  final bool loading;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final colors = TopazColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, color: colors.border, size: 56),
            const SizedBox(height: 16),
            Text(
              'これ以上見つかりませんでした',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.muted, fontSize: 14),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: loading ? null : onLoadMore,
              style: FilledButton.styleFrom(
                backgroundColor: colors.cyan,
                foregroundColor: colors.surface,
              ),
              child: loading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.surface,
                      ),
                    )
                  : const Text('もっと読む'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = TopazColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, color: colors.border, size: 56),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.muted, fontSize: 14),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: colors.cyan,
                foregroundColor: colors.surface,
              ),
              child: const Text('再読み込み'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 先読みを開始したサムネイルURLの通知先。
///
/// 「絞り込みで見えなくなったカードを先読みしていないか」は外からは
/// 観測しようがないので、回帰テストのためだけにここを開けている。
@visibleForTesting
void Function(String url)? debugOnPrecache;
