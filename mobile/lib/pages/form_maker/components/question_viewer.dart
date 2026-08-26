import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../models/question_model.dart';
import '../../../widgets/rich_text_view.dart';

class QuestionViewer extends StatelessWidget {
  final QuestionData question;

  const QuestionViewer({super.key, required this.question});

  bool _looksLikeHtml(String s) => s.contains('<');

  @override
  Widget build(BuildContext context) {
    final hasLabel = question.label.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: hasLabel
                  ? (_looksLikeHtml(question.label)
                      ? RichTextView(
                          html: question.label,
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        )
                      : Text(
                          question.label,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ))
                  : const Text(
                      'Pertanyaan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
            ),
            if (question.isRequired)
              const Text(' *', style: TextStyle(color: Colors.red, fontSize: 16)),
          ],
        ),
        if (question.description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: _looksLikeHtml(question.description)
                ? RichTextView(
                    html: question.description,
                    textStyle: const TextStyle(fontSize: 13, color: Colors.black54),
                  )
                : Text(
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
          children: question.options.asMap().entries.expand((entry) {
            final opt = entry.value;
            final isOther = opt.isOther;
            final optionTile = Padding(
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
            if (isOther) {
              return [
                optionTile,
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: TextField(
                    enabled: false,
                    decoration: InputDecoration(
                      hintText: 'Jawaban lainnya',
                      isDense: true,
                      border: const UnderlineInputBorder(),
                    ),
                  ),
                ),
              ];
            }
            return [optionTile];
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
      case QuestionType.image:
        if (question.imageUrl != null && question.imageUrl!.isNotEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: (kIsWeb || question.imageUrl!.startsWith('http'))
                ? Image.network(question.imageUrl!, fit: BoxFit.cover)
                : Image.file(File(question.imageUrl!), fit: BoxFit.cover),
          );
        }
        return const SizedBox(height: 100, child: Center(child: Icon(Icons.image, color: Colors.black26, size: 40)));
      case QuestionType.text:
      case QuestionType.pageBreak:
        return const SizedBox.shrink();
      default:
        return Text(
          'Preview untuk tipe ${question.type.label} belum didukung', 
          style: const TextStyle(color: Colors.black38, fontStyle: FontStyle.italic),
        );
    }
  }
}
