import 'package:flutter/material.dart';
import '../../../models/question_model.dart';
import '../../../models/form_template.dart';

class FormPageModel {
  String id;
  String title;
  String description;
  List<QuestionData> questions;

  FormPageModel({
    String? id,
    this.title = 'Bagian Tanpa Judul',
    this.description = '',
    List<QuestionData>? questions,
  })  : id = id ?? UniqueKey().toString(),
        questions = questions ?? [];

  FormPageModel clone() {
    return FormPageModel(
      id: UniqueKey().toString(),
      title: title,
      description: description,
      questions: questions.map((q) => q.clone()).toList(),
    );
  }
}

class FormBuilderState extends ChangeNotifier {
  String formTitle;
  String formDescription;
  List<FormPageModel> pages;
  
  // State for Editor
  String? activeQuestionId;
  String? activePageId;
  bool isSaving = false;

  FormBuilderState({
    this.formTitle = 'Form Tanpa Judul',
    this.formDescription = '',
    List<FormPageModel>? pages,
  }) : pages = pages ?? [FormPageModel()] {
    if (this.pages.isEmpty) {
      this.pages.add(FormPageModel());
    }
  }

  factory FormBuilderState.fromTemplate(FormTemplate template) {
    final state = FormBuilderState(
      formTitle: template.title,
      formDescription: template.subtitle,
      pages: [],
    );

    final questionsJson = template.questionsJson;
    if (questionsJson == null || questionsJson.isEmpty) {
      state.pages.add(FormPageModel(
        questions: [
          QuestionData(
            type: QuestionType.multipleChoice,
            options: [QuestionOptionData(label: 'Opsi 1')],
          )
        ],
      ));
      return state;
    }

    FormPageModel currentPage = FormPageModel(title: 'Bagian 1');
    for (var q in questionsJson) {
      final typeStr = q['type'] as String? ?? 'text';
      if (typeStr == 'page_break') {
        state.pages.add(currentPage);
        currentPage = FormPageModel(title: q['label'] ?? 'Bagian Baru');
        continue;
      }

      QuestionType type = QuestionType.shortAnswer;
      if (typeStr == 'single_choice') type = QuestionType.multipleChoice;
      if (typeStr == 'checkbox') type = QuestionType.checkboxes;
      if (typeStr == 'dropdown') type = QuestionType.dropdown;
      if (typeStr == 'file_upload') type = QuestionType.fileUpload;
      if (typeStr == 'date') type = QuestionType.date;
      if (typeStr == 'time') type = QuestionType.time;

      final optionsList = (q['options'] as List<dynamic>?) ?? [];
      final options = optionsList.map((opt) {
        return QuestionOptionData(label: opt['label'] ?? 'Opsi');
      }).toList();

      currentPage.questions.add(
        QuestionData(
          type: type,
          label: q['label'] ?? 'Pertanyaan',
          description: q['description'] ?? '',
          isRequired: q['is_required'] ?? false,
          options: options,
        ),
      );
    }
    
    // Add the last page
    state.pages.add(currentPage);

    // Ensure at least one question
    if (state.pages.first.questions.isEmpty) {
      state.pages.first.questions.add(QuestionData(
        type: QuestionType.multipleChoice,
        options: [QuestionOptionData(label: 'Opsi 1')],
      ));
    }

    return state;
  }

  // === Actions ===

  void updateFormTitle(String newTitle) {
    formTitle = newTitle;
    notifyListeners();
  }

  void updateFormDescription(String newDesc) {
    formDescription = newDesc;
    notifyListeners();
  }

  void setActiveQuestion(String? questionId, String? pageId) {
    activeQuestionId = questionId;
    activePageId = pageId;
    notifyListeners();
  }

  void addQuestion(String pageId, QuestionType type, {String? imageUrl}) {
    final pageIndex = pages.indexWhere((p) => p.id == pageId);
    if (pageIndex == -1) return;

    final newQuestion = QuestionData(
      type: type,
      options: type.hasOptions ? [QuestionOptionData(label: 'Opsi 1')] : [],
      imageUrl: imageUrl,
    );

    // Insert after active question if possible
    int insertIndex = pages[pageIndex].questions.length;
    if (activeQuestionId != null) {
      final qIndex = pages[pageIndex].questions.indexWhere((q) => q.id == activeQuestionId);
      if (qIndex != -1) {
        insertIndex = qIndex + 1;
      }
    }

    pages[pageIndex].questions.insert(insertIndex, newQuestion);
    activeQuestionId = newQuestion.id;
    activePageId = pageId;
    notifyListeners();
  }

  void duplicateQuestion(String pageId, String questionId) {
    final pageIndex = pages.indexWhere((p) => p.id == pageId);
    if (pageIndex == -1) return;

    final qIndex = pages[pageIndex].questions.indexWhere((q) => q.id == questionId);
    if (qIndex == -1) return;

    final cloned = pages[pageIndex].questions[qIndex].clone();
    pages[pageIndex].questions.insert(qIndex + 1, cloned);
    activeQuestionId = cloned.id;
    notifyListeners();
  }

  void deleteQuestion(String pageId, String questionId) {
    final pageIndex = pages.indexWhere((p) => p.id == pageId);
    if (pageIndex == -1) return;

    pages[pageIndex].questions.removeWhere((q) => q.id == questionId);
    
    // Ensure at least one question exists in the page, else add a default one
    if (pages[pageIndex].questions.isEmpty) {
      pages[pageIndex].questions.add(QuestionData(
        type: QuestionType.multipleChoice, 
        options: [QuestionOptionData(label: 'Opsi 1')]
      ));
    }

    activeQuestionId = null;
    notifyListeners();
  }

  void addPage() {
    final newPage = FormPageModel(title: 'Bagian Baru', questions: [
      QuestionData(
        type: QuestionType.multipleChoice,
        options: [QuestionOptionData(label: 'Opsi 1')],
      )
    ]);
    
    if (activePageId != null) {
      final activeIndex = pages.indexWhere((p) => p.id == activePageId);
      if (activeIndex != -1) {
        pages.insert(activeIndex + 1, newPage);
      } else {
        pages.add(newPage);
      }
    } else {
      pages.add(newPage);
    }
    
    activePageId = newPage.id;
    activeQuestionId = null;
    notifyListeners();
  }

  void deletePage(String pageId) {
    if (pages.length <= 1) return; // Cannot delete last page
    pages.removeWhere((p) => p.id == pageId);
    activePageId = null;
    activeQuestionId = null;
    notifyListeners();
  }

  void reorderQuestions(String pageId, int oldIndex, int newIndex) {
    final pageIndex = pages.indexWhere((p) => p.id == pageId);
    if (pageIndex == -1) return;

    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = pages[pageIndex].questions.removeAt(oldIndex);
    pages[pageIndex].questions.insert(newIndex, item);
    notifyListeners();
  }

  void triggerUpdate() {
    notifyListeners();
  }

  // --- API Payload Builder ---
  List<Map<String, dynamic>> buildApiPayload() {
    final List<Map<String, dynamic>> result = [];
    int orderIndex = 0;

    for (int i = 0; i < pages.length; i++) {
      final page = pages[i];

      // Add page break if it's not the first page
      if (i > 0) {
        result.add({
          'type': QuestionType.pageBreak.apiValue,
          'label': page.title,
          'description': page.description,
          'is_required': false,
          'order_index': orderIndex++,
          'options': [],
        });
      }

      for (final q in page.questions) {
        final opts = q.options.asMap().entries.map((e) {
          return {'label': e.value.label, 'order_index': e.key};
        }).toList();

        result.add({
          'type': q.type.apiValue,
          'label': q.label,
          'description': q.description, // Added description sending
          'is_required': q.isRequired,
          'order_index': orderIndex++,
          'options': opts,
          if (q.imageUrl != null) 'image_url': q.imageUrl,
          // You can also add rating/scale limits here if API supports it in the future
        });
      }
    }
    return result;
  }
}
