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
  image,
  text,
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
      case QuestionType.image: return 'Gambar';
      case QuestionType.text: return 'Teks';
    }
  }

  String get apiValue {
    switch (this) {
      case QuestionType.shortAnswer: return 'text';
      case QuestionType.paragraph: return 'paragraph';
      case QuestionType.multipleChoice: return 'single_choice';
      case QuestionType.checkboxes: return 'checkbox';
      case QuestionType.dropdown: return 'dropdown';
      case QuestionType.fileUpload: return 'file_upload';
      case QuestionType.linearScale: return 'linear_scale';
      case QuestionType.rating: return 'rating';
      case QuestionType.multipleChoiceGrid: return 'multiple_choice_grid';
      case QuestionType.tickBoxGrid: return 'tick_box_grid';
      case QuestionType.date: return 'date';
      case QuestionType.time: return 'time';
      case QuestionType.pageBreak: return 'page_break';
      case QuestionType.image: return 'image';
      case QuestionType.text: return 'text_block';
    }
  }

  static QuestionType fromApiValue(String apiValue) {
    switch (apiValue) {
      case 'text': return QuestionType.shortAnswer;
      case 'paragraph': return QuestionType.paragraph;
      case 'single_choice': return QuestionType.multipleChoice;
      case 'checkbox': return QuestionType.checkboxes;
      case 'dropdown': return QuestionType.dropdown;
      case 'file_upload': return QuestionType.fileUpload;
      case 'linear_scale': return QuestionType.linearScale;
      case 'rating': return QuestionType.rating;
      case 'multiple_choice_grid': return QuestionType.multipleChoiceGrid;
      case 'tick_box_grid': return QuestionType.tickBoxGrid;
      case 'date': return QuestionType.date;
      case 'time': return QuestionType.time;
      case 'page_break': return QuestionType.pageBreak;
      case 'image': return QuestionType.image;
      case 'text_block': return QuestionType.text;
      default: return QuestionType.shortAnswer;
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
  bool isOther;
  bool isCorrect;
  QuestionOptionData({String? id, required this.label, this.isOther = false, this.isCorrect = false})
      : id = id ?? UniqueKey().toString();

  QuestionOptionData clone() {
    return QuestionOptionData(id: UniqueKey().toString(), label: label, isOther: isOther, isCorrect: isCorrect);
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
  String? imageUrl; // For storing local path or base64
  
  // Linear scale & Rating
  int scaleMin;
  int scaleMax;
  String minLabel;
  String maxLabel;

  // Rating
  int ratingCount;
  String ratingIcon; // 'star', 'heart', dll

  // Poin per soal (bobot nilai — disimpan di settings.points)
  int points;

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
    this.imageUrl,
    List<QuestionOptionData>? options,
    List<String>? rowLabels,
    this.scaleMin = 1,
    this.scaleMax = 5,
    this.minLabel = '',
    this.maxLabel = '',
    this.ratingCount = 5,
    this.ratingIcon = 'star',
    this.points = 1,
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
      imageUrl: imageUrl,
      isRequired: isRequired,
      options: options.map((e) => e.clone()).toList(),
      rowLabels: List.from(rowLabels),
      scaleMin: scaleMin,
      scaleMax: scaleMax,
      minLabel: minLabel,
      maxLabel: maxLabel,
      ratingCount: ratingCount,
      ratingIcon: ratingIcon,
      points: points,
      allowedFileTypes: List.from(allowedFileTypes),
      maxFileSizeMB: maxFileSizeMB,
      maxFileCount: maxFileCount,
    );
  }
}
