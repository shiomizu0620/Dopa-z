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

  late final Random _random = widget.random ?? Random();
  late FeedOrder _order = widget.initialOrder;

  bool _initialLoading = true;
  String? _error;

  List<Project> _allProjects = const [];
  List<String> _techs = const [];
  String? _selectedTech;
  int _currentIndex = 0;

  /// 取得済みのページ番号。同じページを二度読まないために持つ。
  final Set<int> _loadedPages = {};
  int _lastPage = 1;
  bool _loadingMore = false;

  final Set<String> _precached = {};

  /// フィルター適用後の表示対象。
  List<Project> get _projects {
    final tech = _selectedTech;
    if (tech == null) return _allProjects;
    return _allProjects.where((p) => p.techs.contains(tech)).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
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
        _techs = _collectTechs(projects);
        _initialLoading = false;
      });
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
    setState(() {
      _order = order;
      _allProjects = const [];
      _techs = const [];
      _selectedTech = null;
      _currentIndex = 0;
      _loadedPages.clear();
      _lastPage = 1;
    });
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
        _techs = _collectTechs(_allProjects);
      });
      // 届いた時点で先頭の何件かを先読みしておき、
      // スワイプが追いついたときに読み込み待ちにならないようにする。
      _precacheRange(addedFrom, addedFrom + _precacheOnArrival);
    } finally {
      _loadingMore = false;
    }
  }

  /// 出現回数の多い順に技術タグを集める。
  List<String> _collectTechs(List<Project> projects) {
    final counts = <String, int>{};
    for (final project in projects) {
      for (final tech in project.techs) {
        counts[tech] = (counts[tech] ?? 0) + 1;
      }
    }
    final techs = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return techs.take(_maxTechChips).toList();
  }

  /// [index] の前後のサムネイルをImageCacheに先読みし、
  /// スワイプした瞬間に表示できるようにする。
  void _precacheAround(int index) {
    _precacheRange(index - _precacheBehind, index + _precacheAhead, _projects);
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
        precacheImage(NetworkImage(url), context, onError: (_, __) {});
      }
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    _precacheAround(index);
    if (index >= _projects.length - _loadMoreThreshold) {
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
      _currentIndex = 0;
    });
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // 背景が白なのでステータスバーの文字は暗い色にする
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: TopazColors.surface,
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
            if (!_initialLoading && _error == null && _projects.isNotEmpty)
              SafeArea(
                top: false,
                child: FeedSeekBar(
                  itemCount: _projects.length,
                  currentIndex: _currentIndex.clamp(0, _projects.length - 1),
                  onSeek: _seekTo,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_initialLoading) {
      return const Center(
        child: CircularProgressIndicator(color: TopazColors.cyan),
      );
    }
    if (_error != null) {
      return _ErrorView(message: _error!, onRetry: _loadInitial);
    }
    final projects = _projects;
    if (projects.isEmpty) {
      return const Center(
        child: Text('プロジェクトがありません', style: TextStyle(color: TopazColors.muted)),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, color: TopazColors.border, size: 56),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: TopazColors.muted, fontSize: 14),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: TopazColors.cyan),
              child: const Text('再読み込み'),
            ),
          ],
        ),
      ),
    );
  }
}
