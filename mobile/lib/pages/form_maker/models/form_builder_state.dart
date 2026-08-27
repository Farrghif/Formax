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
    this.title = '',
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
    this.formTitle = '',
    this.formDescription = '',
    List<FormPageModel>? pages,
  }) : pages = pages ?? [FormPageModel()] {
    if (this.pages.isEmpty) {
      this.pages.add(FormPageModel());
    }
    // Always sync formTitle/formDescription with the first page
    if (formTitle.isNotEmpty) {
      this.pages[0].title = formTitle;
    }
    if (formDescription.isNotEmpty) {
      this.pages[0].description = formDescription;
    }
  }

  factory FormBuilderState.fromTemplate(FormTemplate template) {
    final state = FormBuilderState(
      formTitle: template.title,
      formDescription: template.subtitle,
      pages: [],
    );
    state.pages.clear(); // Clear the default page added by the constructor

    final questionsJson = template.questionsJson;
    if (questionsJson == null || questionsJson.isEmpty) {
      state.pages.add(FormPageModel(
        title: state.formTitle,
        description: state.formDescription,
        questions: [
          QuestionData(
            type: QuestionType.multipleChoice,
            options: [QuestionOptionData(label: 'Opsi 1')],
          )
        ],
      ));
      return state;
    }

    FormPageModel currentPage = FormPageModel(title: state.formTitle, description: state.formDescription);
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
      if (typeStr == 'image') type = QuestionType.image;
      if (typeStr == 'text_block') type = QuestionType.text;

      final optionsList = (q['options'] as List<dynamic>?) ?? [];
      final options = optionsList.map((opt) {
        return QuestionOptionData(
          label: opt['label'] ?? 'Opsi',
          isOther: opt['is_other'] ?? false,
        );
      }).toList();

      // Extract settings if present
      final settings = (q['settings'] as Map<String, dynamic>?) ?? {};
      final imageUrl = settings['image_url'] as String?;
      final rowLabels = (settings['row_labels'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? <String>[];
      final scaleMin = (settings['scale_min'] as int?) ?? 1;
      final scaleMax = (settings['scale_max'] as int?) ?? 5;
      final minLabel = settings['min_label'] as String? ?? '';
      final maxLabel = settings['max_label'] as String? ?? '';
      final ratingCount = (settings['rating_count'] as int?) ?? 5;
      final ratingIcon = settings['rating_icon'] as String? ?? 'star';
      final allowedFileTypes = (settings['allowed_file_types'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? <String>[];
      final maxFileSizeMB = (settings['max_file_size_mb'] as int?) ?? 10;
      final maxFileCount = (settings['max_file_count'] as int?) ?? 1;

      currentPage.questions.add(
        QuestionData(
          type: type,
          label: q['label'] ?? 'Pertanyaan',
          description: q['placeholder'] ?? q['description'] ?? '',
          isRequired: q['is_required'] ?? false,
          options: options,
          imageUrl: imageUrl,
          rowLabels: rowLabels,
          scaleMin: scaleMin,
          scaleMax: scaleMax,
          minLabel: minLabel,
          maxLabel: maxLabel,
          ratingCount: ratingCount,
          ratingIcon: ratingIcon,
          allowedFileTypes: allowedFileTypes,
          maxFileSizeMB: maxFileSizeMB,
          maxFileCount: maxFileCount,
        ),
      );
    }

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
    FormPageModel newPage = FormPageModel(title: 'Bagian Baru', questions: []);
    
    if (activePageId != null) {
      final activeIndex = pages.indexWhere((p) => p.id == activePageId);
      if (activeIndex != -1) {
        final currentPage = pages[activeIndex];
        
        // Split questions if there is an active question
        if (activeQuestionId != null) {
          final qIndex = currentPage.questions.indexWhere((q) => q.id == activeQuestionId);
          if (qIndex != -1) {
            // Move questions after qIndex to new page
            final questionsToMove = currentPage.questions.sublist(qIndex + 1);
            newPage.questions.addAll(questionsToMove);
            currentPage.questions.removeRange(qIndex + 1, currentPage.questions.length);
          }
        }
        
        // Ensure new page has at least one question if it's empty after split
        if (newPage.questions.isEmpty) {
          newPage.questions.add(QuestionData(
            type: QuestionType.multipleChoice,
            options: [QuestionOptionData(label: 'Opsi 1')],
          ));
        }

        pages.insert(activeIndex + 1, newPage);
      } else {
        pages.add(newPage);
      }
    } else {
      newPage.questions.add(QuestionData(
        type: QuestionType.multipleChoice,
        options: [QuestionOptionData(label: 'Opsi 1')],
      ));
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
  // Dipakai untuk createTemplate & createForm — harus 100% kompatibel dengan backend QuestionType enum
  List<Map<String, dynamic>> buildApiPayload() {
    final List<Map<String, dynamic>> result = [];
    int orderIndex = 0;
    for (int i = 0; i < pages.length; i++) {
      final page = pages[i];

      // Add page break if it's not the first page — backend type = page_break
      if (i > 0) {
        result.add({
          'type': QuestionType.pageBreak.apiValue,
          'label': page.title.isNotEmpty ? page.title : 'Bagian ${i + 1}',
          'placeholder': page.description,
          'is_required': false,
          'order_index': orderIndex++,
          'settings': {},
          'options': [],
        });
      }

      for (final q in page.questions) {
        final opts = q.options.asMap().entries.map((e) {
          return {
            'label': e.value.label,
            'value': e.value.label,
            'order_index': e.key,
            'is_correct': false,
            'is_other': e.value.isOther,
          };
        }).toList();

        // Build settings for question-specific config
        final settings = <String, dynamic>{};
        if (q.imageUrl != null && q.imageUrl!.isNotEmpty) {
          settings['image_url'] = q.imageUrl;
        }
        if (q.scaleMin != 1) {
          settings['scale_min'] = q.scaleMin;
        }
        if (q.scaleMax != 5) {
          settings['scale_max'] = q.scaleMax;
        }
        if (q.minLabel.isNotEmpty) {
          settings['min_label'] = q.minLabel;
        }
        if (q.maxLabel.isNotEmpty) {
          settings['max_label'] = q.maxLabel;
        }
        if (q.ratingCount != 5) {
          settings['rating_count'] = q.ratingCount;
        }
        if (q.ratingIcon != 'star') {
          settings['rating_icon'] = q.ratingIcon;
        }
        if (q.allowedFileTypes.isNotEmpty) {
          settings['allowed_file_types'] = q.allowedFileTypes;
        }
        if (q.maxFileSizeMB != 10) {
          settings['max_file_size_mb'] = q.maxFileSizeMB;
        }
        if (q.maxFileCount != 1) {
          settings['max_file_count'] = q.maxFileCount;
        }

        result.add({
          'type': q.type.apiValue,
          'label': q.label,
          'placeholder': q.description,
          'is_required': q.isRequired,
          'order_index': orderIndex++,
          'settings': settings.isNotEmpty ? settings : {},
          'options': opts,
        });
      }
    }
    return result;
  }
}
