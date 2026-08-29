// lib/models/form_model.dart
// Model untuk data Form, Submission, dan Answer dari API backend.

class FormModel {
  final String id;
  final String title;
  final String description;
  final String slug;
  final String status;
  final DateTime createdAt;
  int totalSubmissions;

  FormModel({
    required this.id,
    required this.title,
    required this.description,
    required this.slug,
    required this.status,
    required this.createdAt,
    this.totalSubmissions = 0,
  });

  /// Plain text for compact list display — strips HTML tags so rich-text
  /// form titles (stored as HTML) never leak raw `<p>`/`<strong>` markup.
  String get plainTitle => _stripHtml(title);

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

  factory FormModel.fromJson(Map<dynamic, dynamic> json) {
    final map = json is Map<String, dynamic> ? json : Map<String, dynamic>.from(json);
    return FormModel(
      id: map['id'] ?? '',
      title: map['title'] ?? 'Tanpa Judul',
      description: map['description'] ?? '',
      slug: map['slug'] ?? '',
      status: map['status'] ?? 'draft',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at']) ?? DateTime.now()
          : DateTime.now(),
      totalSubmissions: map['total_submissions'] ?? 0,
    );
  }
}

class SubmissionModel {
  final String id;
  final String respondentName;
  final String respondentEmail;
  final DateTime submittedAt;
  final bool isAutoSubmitted;
  final List<AnswerModel> answers;

  SubmissionModel({
    required this.id,
    required this.respondentName,
    required this.respondentEmail,
    required this.submittedAt,
    this.isAutoSubmitted = false,
    this.answers = const [],
  });

  factory SubmissionModel.fromJson(Map<dynamic, dynamic> json) {
    final map = json is Map<String, dynamic> ? json : Map<String, dynamic>.from(json);
    final userRaw = map['user'];
    final user = userRaw is Map ? Map<String, dynamic>.from(userRaw as Map) : null;
    final answersList = map['answers'] as List<dynamic>? ?? [];

    return SubmissionModel(
      id: map['id'] ?? '',
      respondentName: user?['full_name'] ?? 'Anonim',
      respondentEmail: user?['email'] ?? '-',
      submittedAt: map['submitted_at'] != null
          ? DateTime.tryParse(map['submitted_at']) ?? DateTime.now()
          : DateTime.now(),
      isAutoSubmitted: map['is_auto_submitted'] ?? false,
      answers: answersList
          .map((a) => AnswerModel.fromJson(a as Map))
          .toList(),
    );
  }
}

class AnswerModel {
  final String questionLabel;
  final String answer;

  AnswerModel({required this.questionLabel, required this.answer});

  factory AnswerModel.fromJson(Map<dynamic, dynamic> json) {
    final map = json is Map<String, dynamic> ? json : Map<String, dynamic>.from(json);
    final qRaw = map['question'];
    final question = qRaw is Map ? Map<String, dynamic>.from(qRaw as Map) : null;
    return AnswerModel(
      questionLabel: question?['label'] ?? 'Pertanyaan',
      answer: map['value'] ?? '-',
    );
  }
}
