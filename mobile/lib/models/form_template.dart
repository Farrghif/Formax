class FormTemplate {
  final String title;
  final String subtitle;
  final String? id;
  final List<dynamic>? questionsJson;

  FormTemplate({
    required this.title,
    required this.subtitle,
    this.id,
    this.questionsJson,
  });
}
