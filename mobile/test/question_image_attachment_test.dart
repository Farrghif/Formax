import 'package:flutter_test/flutter_test.dart';
import '../lib/models/question_model.dart';
import '../lib/pages/form_maker/models/form_builder_state.dart';
import '../lib/pages/fillformpage.dart';

void main() {
  group('Question Image Attachment Tests', () {
    test('attachImageToActiveQuestion preserves existing image when adding a second image', () {
      final state = FormBuilderState(
        pages: [
          FormPageModel(
            questions: [
              QuestionData(
                type: QuestionType.multipleChoice,
                label: 'Question 1',
                imageUrl: 'http://example.com/image1.jpg',
              ),
            ],
          ),
        ],
      );

      final question = state.pages.first.questions.first;
      state.setActiveQuestion(question.id, state.pages.first.id);

      // Attach second image
      final success = state.attachImageToActiveQuestion('http://example.com/image2.jpg');

      expect(success, isTrue);
      // First image remains in imageUrl
      expect(question.imageUrl, equals('http://example.com/image1.jpg'));
      // Second image is appended to label as rich text image
      expect(question.label, contains('http://example.com/image2.jpg'));
      expect(question.label, contains('<img src="http://example.com/image2.jpg"'));
    });

    test('FillFormPage Question parses image_url from settings correctly', () {
      final jsonMap = {
        'id': 'q1',
        'type': 'multiple_choice',
        'label': 'Test Question',
        'is_required': true,
        'settings': {
          'image_url': 'http://example.com/banner.jpg',
        },
        'options': [],
      };

      final q = Question.fromJson(jsonMap);

      expect(q.id, equals('q1'));
      expect(q.imageUrl, equals('http://example.com/banner.jpg'));
    });
  });
}
