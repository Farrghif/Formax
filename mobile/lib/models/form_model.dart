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

  factory FormModel.fromJson(Map<String, dynamic> json) {
    return FormModel(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Tanpa Judul',
      description: json['description'] ?? '',
      slug: json['slug'] ?? '',
      status: json['status'] ?? 'draft',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
      totalSubmissions: json['total_submissions'] ?? 0,
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

  factory SubmissionModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    final answersList = json['answers'] as List<dynamic>? ?? [];

    return SubmissionModel(
      id: json['id'] ?? '',
      respondentName: user?['full_name'] ?? 'Anonim',
      respondentEmail: user?['email'] ?? '-',
      submittedAt: json['submitted_at'] != null
          ? DateTime.tryParse(json['submitted_at']) ?? DateTime.now()
          : DateTime.now(),
      isAutoSubmitted: json['is_auto_submitted'] ?? false,
      answers: answersList
          .map((a) => AnswerModel.fromJson(a as Map<String, dynamic>))
          .toList(),
    );
  }
}

class AnswerModel {
  final String questionLabel;
  final String answer;

  AnswerModel({required this.questionLabel, required this.answer});

  factory AnswerModel.fromJson(Map<String, dynamic> json) {
    final question = json['question'] as Map<String, dynamic>?;
    return AnswerModel(
      questionLabel: question?['label'] ?? 'Pertanyaan',
      answer: json['value'] ?? '-',
    );
  }
}
