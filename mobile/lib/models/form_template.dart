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

  factory FormTemplate.fromJson(Map<String, dynamic> json) {
    return FormTemplate(
      id: json['id']?.toString(),
      title: json['title'] ?? 'Tanpa Judul',
      subtitle: json['description'] ?? '',
      questionsJson: json['questions'] as List<dynamic>?,
      isSystem: json['is_system'] ?? false,
    );
  }
}
