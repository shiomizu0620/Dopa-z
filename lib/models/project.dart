/// topaz.dev のプロジェクトを表すモデル。
class Project {
  const Project({
    required this.id,
    required this.title,
    required this.thumbnail,
    required this.author,
    required this.techs,
    required this.topazUrl,
  });

  final String id;
  final String title;
  final String thumbnail;
  final String author;
  final List<String> techs;
  final String topazUrl;

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String,
      title: json['title'] as String,
      thumbnail: json['thumbnail'] as String,
      author: json['author'] as String,
      techs: (json['techs'] as List<dynamic>).cast<String>(),
      topazUrl: json['topazUrl'] as String,
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
    };
  }
}
