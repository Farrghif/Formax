import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../models/question_model.dart';
import '../../../widgets/rich_text_field.dart';

class QuestionEditor extends StatefulWidget {
  final QuestionData question;
  final VoidCallback onChanged;
  final VoidCallback onTypeChangeTap;

  const QuestionEditor({
    super.key,
    required this.question,
    required this.onChanged,
    required this.onTypeChangeTap,
  });

  @override
  State<QuestionEditor> createState() => _QuestionEditorState();
}

class _QuestionEditorState extends State<QuestionEditor> {
  // Debounce controllers for linear scale configs etc.
  late TextEditingController _minLabelCtrl;
  late TextEditingController _maxLabelCtrl;

  @override
  void initState() {
    super.initState();
    _minLabelCtrl = TextEditingController(text: widget.question.minLabel);
    _maxLabelCtrl = TextEditingController(text: widget.question.maxLabel);
  }

  @override
  void didUpdateWidget(covariant QuestionEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question.id != widget.question.id) {
      _minLabelCtrl.text = widget.question.minLabel;
      _maxLabelCtrl.text = widget.question.maxLabel;
    }
  }

  @override
  void dispose() {
    _minLabelCtrl.dispose();
    _maxLabelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Drag Handle
        const Center(
          child: Icon(Icons.drag_handle, color: Colors.black26, size: 20),
        ),
        const SizedBox(height: 8),

        // Title and Type Selector
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  RichTextField(
                    initialHtml: widget.question.label,
                    onChanged: (html) {
                      widget.question.label = html;
                      widget.onChanged();
                    },
                    hintText: widget.question.type == QuestionType.text
                        ? 'Judul Teks'
                        : (widget.question.type == QuestionType.image
                            ? 'Caption (opsional)'
                            : 'Pertanyaan'),
                    minLines: 1,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 8),
                  RichTextField(
                    initialHtml: widget.question.description,
                    onChanged: (html) {
                      widget.question.description = html;
                      widget.onChanged();
                    },
                    hintText: 'Deskripsi tambahan (opsional)',
                    minLines: 1,
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            if (widget.question.type != QuestionType.image && widget.question.type != QuestionType.text) ...[
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: InkWell(
                onTap: widget.onTypeChangeTap,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.question.type.label, 
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), 
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 20, color: Colors.black54),
                    ],
                  ),
                ),
              ),
            ),
            ]
          ],
        ),
        const SizedBox(height: 20),
        
        // Editor Body based on type
        _buildEditorBody(),
      ],
    );
  }

  Widget _buildEditorBody() {
    final q = widget.question;

    if (q.type == QuestionType.image) {
      if (q.imageUrl != null && q.imageUrl!.isNotEmpty) {
        return Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: (kIsWeb || q.imageUrl!.startsWith('http'))
              ? Image.network(q.imageUrl!, fit: BoxFit.cover)
              : Image.file(File(q.imageUrl!), fit: BoxFit.cover),
        );
      }
      return const SizedBox(height: 100, child: Center(child: Icon(Icons.image, color: Colors.black26, size: 40)));
    }

    if (q.type == QuestionType.linearScale) {
      return Column(
        children: [
          Row(
            children: [
              DropdownButton<int>(
                value: q.scaleMin,
                items: const [
                  DropdownMenuItem(value: 0, child: Text('0')),
                  DropdownMenuItem(value: 1, child: Text('1')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    q.scaleMin = v;
                    widget.onChanged();
                  }
                },
              ),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('sampai')),
              DropdownButton<int>(
                value: q.scaleMax,
                items: List.generate(9, (index) => index + 2).map((val) => DropdownMenuItem(value: val, child: Text('$val'))).toList(),
                onChanged: (v) {
                  if (v != null) {
                    q.scaleMax = v;
                    widget.onChanged();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('${q.scaleMin}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _minLabelCtrl,
                  onChanged: (v) { q.minLabel = v; widget.onChanged(); },
                  decoration: const InputDecoration(hintText: 'Label opsional', isDense: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('${q.scaleMax}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _maxLabelCtrl,
                  onChanged: (v) { q.maxLabel = v; widget.onChanged(); },
                  decoration: const InputDecoration(hintText: 'Label opsional', isDense: true),
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (q.type == QuestionType.rating) {
      return Row(
        children: [
          const Text('Jumlah Tingkat: '),
          DropdownButton<int>(
            value: q.ratingCount,
            items: List.generate(8, (i) => i + 3).map((val) => DropdownMenuItem(value: val, child: Text('$val'))).toList(),
            onChanged: (v) {
              if (v != null) {
                q.ratingCount = v;
                widget.onChanged();
              }
            },
          ),
          const SizedBox(width: 24),
          const Text('Bentuk: '),
          DropdownButton<String>(
            value: q.ratingIcon,
            items: const [
              DropdownMenuItem(value: 'star', child: Text('Bintang')),
              DropdownMenuItem(value: 'heart', child: Text('Hati')),
            ],
            onChanged: (v) {
              if (v != null) {
                q.ratingIcon = v;
                widget.onChanged();
              }
            },
          ),
        ],
      );
    }

    if (!q.type.hasOptions) {
      return Container(); // No specific body editor needed for text/date/time
    }

    return Column(
      children: [
        ...q.options.asMap().entries.map((entry) {
          final i = entry.key;
          final opt = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Icon(
                  q.type == QuestionType.multipleChoice 
                    ? Icons.radio_button_unchecked 
                    : (q.type == QuestionType.checkboxes ? Icons.check_box_outline_blank : Icons.circle_outlined),
                  size: 20, 
                  color: Colors.black26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: opt.isOther
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.0),
                        child: Text('Lainnya...', style: TextStyle(fontSize: 14, color: Colors.black87)),
                      )
                    : TextFormField(
                        initialValue: opt.label,
                        onChanged: (v) {
                          opt.label = v;
                          widget.onChanged();
                        },
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Opsi ${i + 1}',
                          border: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.transparent)),
                          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF4F46E5))),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                ),
                if (q.options.length > 1)
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Colors.black38),
                    onPressed: () {
                      q.options.removeAt(i);
                      widget.onChanged();
                    },
                  ),
              ],
            ),
          );
        }),
        Row(
          children: [
            Icon(
              q.type == QuestionType.multipleChoice 
                ? Icons.radio_button_unchecked 
                : (q.type == QuestionType.checkboxes ? Icons.check_box_outline_blank : Icons.circle_outlined),
              size: 20, 
              color: Colors.black26,
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: () {
                q.options.add(QuestionOptionData(label: 'Opsi ${q.options.length + 1}'));
                widget.onChanged();
              },
              child: const Text('Tambah opsi', style: TextStyle(color: Colors.black54, fontSize: 14)),
            ),
            if (!q.options.any((o) => o.isOther) && (q.type == QuestionType.multipleChoice || q.type == QuestionType.checkboxes)) ...[
              const Text(' atau ', style: TextStyle(color: Colors.black54, fontSize: 14)),
              InkWell(
                onTap: () {
                  q.options.add(QuestionOptionData(label: 'Lainnya', isOther: true));
                  widget.onChanged();
                },
                child: const Text('tambahkan "Lainnya"', style: TextStyle(color: Color(0xFF4F46E5), fontSize: 14, fontWeight: FontWeight.w500)),
              ),
            ]
          ],
        )
      ],
    );
  }
}
