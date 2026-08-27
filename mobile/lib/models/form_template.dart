class FormTemplate {
  final String title;
  final String subtitle;
  final String? id;
  final List<dynamic>? questionsJson;
  final bool isSystem;

  FormTemplate({
    required this.title,
    required this.subtitle,
    this.id,
    this.questionsJson,
    this.isSystem = false,
  });

  /// Plain text untuk display list — strip HTML "<p>hhhh</p>" -> "hhhh"
  String get plainTitle => _stripHtml(title);
  String get plainSubtitle => _stripHtml(subtitle);

  static String _stripHtml(String? html) {
    if (html == null || html.trim().isEmpty) return '';
    return html
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  factory FormTemplate.fromJson(Map<String, dynamic> json) {
    // questions mungkin null jika backend lama tidak eager-load — normalisasi ke List
    final rawQuestions = json['questions'];
    List<dynamic>? qs;
    if (rawQuestions is List) {
      qs = rawQuestions;
    }
    return FormTemplate(
      id: json['id']?.toString(),
      title: (json['title'] as String?)?.trim().isEmpty == true ? 'Tanpa Judul' : (json['title'] ?? 'Tanpa Judul'),
      subtitle: json['description'] ?? '',
      questionsJson: qs,
      isSystem: json['is_system'] ?? false,
    );
  }
}
