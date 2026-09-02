import 'package:flutter_test/flutter_test.dart';
import 'package:form4x/models/question_model.dart';
import 'package:form4x/pages/form_maker/models/form_builder_state.dart';

void main() {
  test('buildApiPayload skips page_break entries to avoid invalid enum values', () {
    final state = FormBuilderState(
      pages: [
        FormPageModel(
          title: 'Halaman 1',
          questions: [
            QuestionData(type: QuestionType.shortAnswer, label: 'Nama'),
          ],
        ),
        FormPageModel(
          title: 'Bagian Baru',
          questions: [
            QuestionData(type: QuestionType.multipleChoice, label: 'Jenis kelamin'),
          ],
        ),
      ],
    );

    final payload = state.buildApiPayload();

    expect(payload.any((item) => item['type'] == 'page_break'), isFalse);
    expect(payload.length, 2);
    expect(payload[0]['type'], 'text');
    expect(payload[1]['type'], 'single_choice');
  });
}
