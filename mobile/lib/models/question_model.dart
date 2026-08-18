import 'package:flutter/material.dart';

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
      case QuestionType.pageBreak: return 'page_break'; // Custom handling for backend
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
  String id;
  String label;
  QuestionOptionData({String? id, required this.label}) 
      : id = id ?? UniqueKey().toString();

  QuestionOptionData clone() {
    return QuestionOptionData(id: UniqueKey().toString(), label: label);
  }
}

class QuestionData {
  String id;
  QuestionType type;
  String label;
  String description; // Replaces hintText
  bool isRequired;
  List<QuestionOptionData> options;
  List<String> rowLabels;
  
  // Linear scale & Rating
  int scaleMin;
  int scaleMax;
  String minLabel;
  String maxLabel;

  // Rating
  int ratingCount;
  String ratingIcon; // 'star', 'heart', dll

  // File Upload
  List<String> allowedFileTypes;
  int maxFileSizeMB;
  int maxFileCount;

  QuestionData({
    String? id,
    required this.type,
    this.label = 'Pertanyaan',
    this.description = '',
    this.isRequired = false,
    List<QuestionOptionData>? options,
    List<String>? rowLabels,
    this.scaleMin = 1,
    this.scaleMax = 5,
    this.minLabel = '',
    this.maxLabel = '',
    this.ratingCount = 5,
    this.ratingIcon = 'star',
    this.allowedFileTypes = const [],
    this.maxFileSizeMB = 10,
    this.maxFileCount = 1,
  })  : id = id ?? UniqueKey().toString(),
        options = options ?? [],
        rowLabels = rowLabels ?? [];

  QuestionData clone() {
    return QuestionData(
      id: UniqueKey().toString(),
      type: type,
      label: label,
      description: description,
      isRequired: isRequired,
      options: options.map((e) => e.clone()).toList(),
      rowLabels: List.from(rowLabels),
      scaleMin: scaleMin,
      scaleMax: scaleMax,
      minLabel: minLabel,
      maxLabel: maxLabel,
      ratingCount: ratingCount,
      ratingIcon: ratingIcon,
      allowedFileTypes: List.from(allowedFileTypes),
      maxFileSizeMB: maxFileSizeMB,
      maxFileCount: maxFileCount,
    );
  }
}
