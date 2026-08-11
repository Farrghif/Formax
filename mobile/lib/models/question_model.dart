// lib/models/question_model.dart
// Model untuk tipe pertanyaan, data pertanyaan, dan opsi pertanyaan.

enum QuestionType {
  shortAnswer,
  paragraph,
  multipleChoice,
  checkboxes,
  dropdown,
  fileUpload,
  linearScale,
  rating,
  multipleChoiceGrid,
  tickBoxGrid,
  date,
  time,
  pageBreak,
}

extension QuestionTypeExtension on QuestionType {
  String get label {
    switch (this) {
      case QuestionType.shortAnswer: return 'Jawaban Singkat';
      case QuestionType.paragraph: return 'Paragraf';
      case QuestionType.multipleChoice: return 'Pilihan Ganda';
      case QuestionType.checkboxes: return 'Kotak Centang';
      case QuestionType.dropdown: return 'Dropdown';
      case QuestionType.fileUpload: return 'Upload File';
      case QuestionType.linearScale: return 'Skala Linier';
      case QuestionType.rating: return 'Rating Bintang';
      case QuestionType.multipleChoiceGrid: return 'Grid Pilihan Ganda';
      case QuestionType.tickBoxGrid: return 'Grid Kotak Centang';
      case QuestionType.date: return 'Tanggal';
      case QuestionType.time: return 'Waktu';
      case QuestionType.pageBreak: return 'Pemisah Halaman';
    }
  }

  /// Nilai yang dikirim ke backend API
  String get apiValue {
    switch (this) {
      case QuestionType.shortAnswer: return 'text';
      case QuestionType.paragraph: return 'text';
      case QuestionType.multipleChoice: return 'single_choice';
      case QuestionType.checkboxes: return 'checkbox';
      case QuestionType.dropdown: return 'dropdown';
      case QuestionType.fileUpload: return 'file_upload';
      case QuestionType.linearScale: return 'text';
      case QuestionType.rating: return 'text';
      case QuestionType.multipleChoiceGrid: return 'text';
      case QuestionType.tickBoxGrid: return 'text';
      case QuestionType.date: return 'date';
      case QuestionType.time: return 'text';
      case QuestionType.pageBreak: return 'text';
    }
  }

  bool get hasOptions {
    return this == QuestionType.multipleChoice ||
        this == QuestionType.checkboxes ||
        this == QuestionType.dropdown ||
        this == QuestionType.multipleChoiceGrid ||
        this == QuestionType.tickBoxGrid;
  }
}

class QuestionOptionData {
  String label;
  QuestionOptionData({required this.label});
}

class QuestionData {
  QuestionType type;
  String label;
  bool isRequired;
  List<QuestionOptionData> options;
  // For grid types: row labels
  List<String> rowLabels;
  // For linear scale
  int scaleMin;
  int scaleMax;

  QuestionData({
    required this.type,
    this.label = 'Pertanyaan',
    this.isRequired = false,
    List<QuestionOptionData>? options,
    List<String>? rowLabels,
    this.scaleMin = 1,
    this.scaleMax = 5,
  })  : options = options ?? [],
        rowLabels = rowLabels ?? [];
}
