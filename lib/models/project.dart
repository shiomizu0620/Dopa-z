/// topaz.dev のプロジェクトを表すモデル。
class Project {
  const Project({
    required this.id,
    required this.title,
    required this.thumbnail,
    required this.author,
    required this.techs,
    required this.topazUrl,
    this.likes = 0,
    this.comments = 0,
  });

  final String id;
  final String title;
  final String thumbnail;
  final String author;
  final List<String> techs;
  final String topazUrl;
  final int likes;
  final int comments;

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String,
      title: json['title'] as String,
      thumbnail: json['thumbnail'] as String,
      author: json['author'] as String,
      techs: (json['techs'] as List<dynamic>).cast<String>(),
      topazUrl: json['topazUrl'] as String,
      likes: json['likes'] as int? ?? 0,
      comments: json['comments'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'thumbnail': thumbnail,
      'author': author,
      'techs': techs,
      'topazUrl': topazUrl,
      'likes': likes,
      'comments': comments,
    };
  }
}
