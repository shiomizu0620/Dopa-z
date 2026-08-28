import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/feed_order.dart';
import '../models/project.dart';
import '../repositories/feed_repository.dart';
import '../theme.dart';
import '../widgets/feed_seek_bar.dart';
import '../widgets/feed_top_bar.dart';
import '../widgets/project_card.dart';

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

  final Set<String> _precached = {};
  Timer? _precacheTimer;

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
    setState(() {
      _initialLoading = true;
      _error = null;
    });
    try {
      // APIに並び替えの指定が無いので、まず1ページ目を取って総ページ数を知る。
      final first = await widget.repository.fetchProjects(page: 1);
      _loadedPages.add(first.currentPage);
      _lastPage = first.lastPage;

      final projects = [...first.projects];
      if (_order == FeedOrder.random) {
        // 1ページ目 (新着) だけに偏らないよう、全体からもう1ページ混ぜる。
        // ここで2ページ分持っておくと、最初の追加読み込みまでの余裕もできる。
        projects.addAll(await _fetchNextPage() ?? const []);
        projects.shuffle(_random);
      }

      if (!mounted) return;
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
      if (!mounted) return;
      setState(() {
        _error = e is FeedException ? e.message : '$e';
        _initialLoading = false;
      });
    }
  }

  /// まだ読んでいないページを1つ取る。
  /// 全ページ読み終わっている、または失敗した場合は null。
  Future<List<Project>?> _fetchNextPage() async {
    final page = _pickUnloadedPage();
    if (page == null) return null;
    try {
      final result = await widget.repository.fetchProjects(page: page);
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
      final addedFrom = _allProjects.length;
      setState(() {
        _allProjects = [..._allProjects, ...projects];
        _updateVisible();
        // 増えた分だけ数え直す
        _countTechs(projects);
        _techs = _topTechs();
      });
      // 届いた時点で先頭の何件かを先読みしておき、
      // スワイプが追いついたときに読み込み待ちにならないようにする。
      _precacheRange(addedFrom, addedFrom + _precacheOnArrival);
    } finally {
      _loadingMore = false;
    }
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
    if (projects.isEmpty) return;
    final start = from.clamp(0, projects.length - 1);
    final end = to.clamp(0, projects.length - 1);
    for (var i = start; i <= end; i++) {
      final url = projects[i].thumbnailUrl;
      if (url.isEmpty) continue;
      if (_precached.add(url)) {
        // 先読み失敗は無視(表示時にerrorBuilderで処理される)
        precacheImage(
          thumbnailProvider(context, url),
          context,
          onError: (_, __) {},
        );
      }
    }
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
    if (index >= _visible.length - _loadMoreThreshold) {
      _loadMore();
    }
  }

  /// シークバーで指した位置へ送る。
  void _seekTo(int index) {
    if (!_pageController.hasClients) return;
    _pageController.jumpToPage(index);
  }

  void _onTechSelected(String? tech) {
    setState(() {
      _selectedTech = tech;
      _updateVisible();
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // ステータスバーの文字色を背景と反対にする
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: colors.surface,
        body: Column(
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
            Expanded(child: _buildBody()),
            if (!_initialLoading && _error == null && _visible.isNotEmpty)
              SafeArea(
                top: false,
                // ページ送りで作り直すのはこの部分だけにする
                child: ValueListenableBuilder<int>(
                  valueListenable: _currentIndex,
                  builder: (context, index, _) => FeedSeekBar(
                    itemCount: _visible.length,
                    currentIndex: index.clamp(0, _visible.length - 1),
                    onSeek: _seekTo,
                  ),
                ),
              ),
          ],
        ),
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
    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      allowImplicitScrolling: true,
      itemCount: projects.length,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, index) {
        final project = projects[index];
        return ProjectCard(project: project, onOpenUrl: _openUrl);
      },
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
