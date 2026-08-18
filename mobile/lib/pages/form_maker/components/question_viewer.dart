import 'package:flutter/material.dart';
import '../../../models/question_model.dart';

class QuestionViewer extends StatelessWidget {
  final QuestionData question;

  const QuestionViewer({super.key, required this.question});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                question.label.isEmpty ? 'Pertanyaan' : question.label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87),
              ),
            ),
            if (question.isRequired)
              const Text(' *', style: TextStyle(color: Colors.red, fontSize: 16)),
          ],
        ),
        if (question.description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              question.description,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ),
        const SizedBox(height: 16),
        _buildBody(),
      ],
    );
  }

  Widget _buildBody() {
    switch (question.type) {
      case QuestionType.shortAnswer:
        return const TextField(
          enabled: false,
          decoration: InputDecoration(
            hintText: 'Jawaban singkat',
            isDense: true,
            border: UnderlineInputBorder(),
          ),
        );
      case QuestionType.paragraph:
        return const TextField(
          enabled: false,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Jawaban panjang',
            isDense: true,
            border: UnderlineInputBorder(),
          ),
        );
      case QuestionType.multipleChoice:
      case QuestionType.checkboxes:
        return Column(
          children: question.options.map((opt) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Icon(
                    question.type == QuestionType.multipleChoice 
                      ? Icons.radio_button_unchecked 
                      : Icons.check_box_outline_blank, 
                    size: 20, 
                    color: Colors.black38,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      opt.label.isEmpty ? 'Opsi' : opt.label, 
                      style: const TextStyle(fontSize: 14)
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      case QuestionType.dropdown:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black12), 
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Pilih opsi', style: TextStyle(color: Colors.black38)), 
              Icon(Icons.arrow_drop_down, color: Colors.black38),
            ],
          ),
        );
      case QuestionType.fileUpload:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black12, style: BorderStyle.solid), 
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_upload_outlined, color: Colors.black54), 
              SizedBox(width: 8), 
              Text('Tambahkan File', style: TextStyle(color: Colors.black54)),
            ],
          ),
        );
      case QuestionType.linearScale:
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                question.scaleMax - question.scaleMin + 1, 
                (index) => Column(
                  children: [
                    Text('${question.scaleMin + index}'),
                    const SizedBox(height: 4),
                    const Icon(Icons.radio_button_unchecked, color: Colors.black38),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(question.minLabel, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                Text(question.maxLabel, style: const TextStyle(color: Colors.black54, fontSize: 12)),
              ],
            )
          ],
        );
      case QuestionType.rating:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            question.ratingCount, 
            (index) => Icon(
              question.ratingIcon == 'heart' ? Icons.favorite_border : Icons.star_border, 
              color: Colors.black38,
              size: 32,
            ),
          ),
        );
      case QuestionType.date:
        return const TextField(
          enabled: false,
          decoration: InputDecoration(
            hintText: 'HH/BB/TTTT',
            suffixIcon: Icon(Icons.calendar_today, color: Colors.black38),
            isDense: true,
            border: UnderlineInputBorder(),
          ),
        );
      case QuestionType.time:
        return const TextField(
          enabled: false,
          decoration: InputDecoration(
            hintText: 'Waktu',
            suffixIcon: Icon(Icons.access_time, color: Colors.black38),
            isDense: true,
            border: UnderlineInputBorder(),
          ),
        );
      default:
        return Text(
          'Preview untuk tipe ${question.type.label} belum didukung', 
          style: const TextStyle(color: Colors.black38, fontStyle: FontStyle.italic),
        );
    }
  }
}
