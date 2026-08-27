/// topaz.dev のプロジェクト。
///
/// GET https://topaz.dev/api/projects の `data[]` に対応する。
class Project {
  const Project({
    required this.id,
    required this.title,
    required this.thumbnailUrl,
    required this.authorName,
    required this.authorUserName,
    required this.avatarUrl,
    required this.techs,
    required this.likeCount,
    this.githubId = '',
    this.twitterId = '',
  });

  /// 画像の配信元。API が返すパスは相対なのでこれを前に付ける。
  static const assetBaseUrl = 'https://ptera-publish.topaz.dev/';

  static const siteBaseUrl = 'https://topaz.dev';

  final String id;
  final String title;

  /// サムネイル画像の絶対URL。
  final String thumbnailUrl;

  /// 投稿者の表示名 (`user.display_name`)。
  final String authorName;

  /// 投稿者の識別子 (`user.user_name`)。`@` 付きで表示する。
  final String authorUserName;

  /// 投稿者のアバター画像の絶対URL。
  final String avatarUrl;

  /// 技術タグ名の一覧 (`technology_tag_list[].id`)。
  final List<String> techs;

  final int likeCount;

  /// 投稿者のGitHubアカウント名 (`user.social.github_id`)。未設定なら空文字。
  final String githubId;

  /// 投稿者のX(Twitter)アカウント名 (`user.social.twitter_id`)。未設定なら空文字。
  final String twitterId;

  /// topaz.dev 上のプロジェクトページ。
  String get topazUrl => '$siteBaseUrl/projects/$id';

  /// 投稿者のGitHubページ。未設定なら null。
  String? get githubUrl =>
      githubId.isEmpty ? null : 'https://github.com/$githubId';

  /// 投稿者のXページ。未設定なら null。
  String? get xUrl => twitterId.isEmpty ? null : 'https://x.com/$twitterId';

  factory Project.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? const {};
    final social = user['social'] as Map<String, dynamic>? ?? const {};
    final tags = json['technology_tag_list'] as List<dynamic>? ?? const [];
    return Project(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      thumbnailUrl: absoluteUrl(json['thumbnail_path'] as String?),
      authorName: user['display_name'] as String? ?? '',
      authorUserName: user['user_name'] as String? ?? '',
      avatarUrl: absoluteUrl(user['avatar_image_path'] as String?),
      techs: [
        for (final tag in tags)
          if ((tag as Map<String, dynamic>)['id'] is String)
            tag['id'] as String,
      ],
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      githubId: accountName(social['github_id'] as String?),
      twitterId: accountName(social['twitter_id'] as String?),
    );
  }

  /// SNSのアカウント名を正規化する。未設定は空文字、先頭の `@` は落とす。
  static String accountName(String? raw) {
    final name = raw?.trim() ?? '';
    return name.startsWith('@') ? name.substring(1) : name;
  }

  /// 相対パスなら配信元のホストを補って絶対URLにする。
  static String absoluteUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '$assetBaseUrl$path';
  }
}

/// ページ送り付きのプロジェクト一覧。
class ProjectPage {
  const ProjectPage({
    required this.projects,
    required this.currentPage,
    required this.lastPage,
  });

  final List<Project> projects;
  final int currentPage;
  final int lastPage;

  bool get hasMore => currentPage < lastPage;

  factory ProjectPage.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as List<dynamic>? ?? const [];
    return ProjectPage(
      projects: [
        for (final item in data) Project.fromJson(item as Map<String, dynamic>),
      ],
      currentPage: (json['current_page'] as num?)?.toInt() ?? 1,
      lastPage: (json['last_page'] as num?)?.toInt() ?? 1,
    );
  }
}
