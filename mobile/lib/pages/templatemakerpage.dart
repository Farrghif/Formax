// lib/pages/templatemakerpage.dart
// Halaman form builder lengkap — mendukung 12 tipe pertanyaan,
// drag & drop reorder, multi-page (section break), dan publish ke backend.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/question_model.dart';
import '../models/form_template.dart';
import '../services/api_service.dart';

class TemplateMakerPage extends StatefulWidget {
  final FormTemplate? initialTemplate;

  const TemplateMakerPage({super.key, this.initialTemplate});

  @override
  State<TemplateMakerPage> createState() => _TemplateMakerPageState();
}

class _TemplateMakerPageState extends State<TemplateMakerPage> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late List<QuestionData> _questions;

  @override
  void initState() {
    super.initState();
    if (widget.initialTemplate != null) {
      _titleController = TextEditingController(text: widget.initialTemplate!.title);
      _descController = TextEditingController(text: widget.initialTemplate!.subtitle);
      _questions = [];
      
      final qJson = widget.initialTemplate!.questionsJson;
      if (qJson != null && qJson.isNotEmpty) {
        for (var q in qJson) {
          final typeStr = q['type'] as String? ?? 'text';
          QuestionType type = QuestionType.shortAnswer;
          if (typeStr == 'single_choice') type = QuestionType.multipleChoice;
          if (typeStr == 'checkbox') type = QuestionType.checkboxes;
          if (typeStr == 'dropdown') type = QuestionType.dropdown;
          if (typeStr == 'file_upload') type = QuestionType.fileUpload;
          if (typeStr == 'date') type = QuestionType.date;

          final optionsList = (q['options'] as List<dynamic>?) ?? [];
          final options = optionsList.map((opt) {
            return QuestionOptionData(label: opt['label'] ?? 'Opsi');
          }).toList();

          _questions.add(QuestionData(
            type: type,
            label: q['label'] ?? 'Pertanyaan',
            hintText: q['placeholder'] ?? '',
            hintStyle: const TextStyle(color: Colors.grey),
            isRequired: q['is_required'] ?? false,
            options: options,
          ));
        }
      }
      
      if (_questions.isEmpty) {
        _questions.add(QuestionData(
          type: QuestionType.multipleChoice,
          label: 'Pertanyaan Tanpa Judul',
          options: [QuestionOptionData(label: 'Opsi 1')],
        ));
      }
    } else {
      _titleController = TextEditingController(text: 'Form Tanpa Judul');
      _descController = TextEditingController();
      _questions = [
        QuestionData(
          type: QuestionType.multipleChoice,
          label: 'Pertanyaan Tanpa Judul',
          hintText: 'halo',
          hintStyle: const TextStyle(color: Colors.grey),
          options: [QuestionOptionData(label: 'Opsi 1')],
        ),
      ];
    }
  }

  bool _isSaving = false;

  // State untuk Setelan
  bool _isQuiz = true;
  String _releaseGrade = 'langsung';
  bool _missedQuestions = true;
  bool _correctAnswers = true;
  bool _pointValues = true;

  String _sendCopy = 'Nonaktif';
  bool _limitOneResponse = true;
  bool _hideResponses = false;
  bool _allowMultipleEdits = false;

  bool _requireQuestionDefault = false;

  bool _enableTimer = true;
  String _timerMode = 'Start when respondent opens the form';
  final TextEditingController _durationCtrl = TextEditingController(text: '1 hari');

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  // ─── API Helpers ──────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _buildQuestionPayload() {
    final List<Map<String, dynamic>> result = [];
    int orderIndex = 0;
    for (final q in _questions) {
      if (q.type == QuestionType.pageBreak) continue;
      final opts = q.options.asMap().entries.map((e) {
        return {'label': e.value.label, 'order_index': e.key};
      }).toList();
      result.add({
        'type': q.type.apiValue,
        'label': q.label,
        'is_required': q.isRequired,
        'order_index': orderIndex++,
        'options': opts,
      });
    }
    return result;
  }

  void _saveTemplate() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final payload = {
      'title': _titleController.text.isNotEmpty
          ? _titleController.text
          : 'Form Tanpa Judul',
      'description': _descController.text,
      'questions': _buildQuestionPayload(),
    };

    final res = await ApiService.createTemplate(payload);
    setState(() => _isSaving = false);

    if (res['success'] == true) {
      if (mounted) {
        Navigator.pop(
          context,
          FormTemplate(
            title: payload['title'] as String,
            subtitle: 'Baru saja disimpan',
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: ${res['message']}')),
        );
      }
    }
  }

  void _publishForm() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final title = _titleController.text.isNotEmpty
        ? _titleController.text
        : 'Form Tanpa Judul';
    final slug =
        '${title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';

    final payload = {
      'title': title,
      'description': _descController.text,
      'slug': slug,
      'questions': _buildQuestionPayload(),
    };

    final res = await ApiService.createForm(payload);
    if (res['success'] == true) {
      final formId = res['data']['id'] as String;
      final qrRes = await ApiService.generateQrCode(formId);
      setState(() => _isSaving = false);

      if (qrRes['success'] == true) {
        final shareLink = qrRes['data']['share_link'] as String;
        String qrUrl = qrRes['data']['qr_code_url'] as String;
        
        // Ganti localhost dengan IP emulator (10.0.2.2) agar gambar bisa dimuat
        if (qrUrl.contains('localhost')) {
          qrUrl = qrUrl.replaceAll('localhost', '10.0.2.2');
        }

        if (mounted) _showShareDialog(shareLink, qrUrl);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal generate QR: ${qrRes['message']}')),
          );
        }
      }
    } else {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal publish: ${res['message']}')),
        );
      }
    }
  }

  void _showShareDialog(String link, String qrUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ShareFormDialog(link: link, qrUrl: qrUrl),
    ).then((_) {
      if (mounted) {
        Navigator.pop(
          context,
          FormTemplate(title: 'Form Terpublikasi', subtitle: 'Siap digunakan'),
        );
      }
    });
  }

  // ─── Bottom Sheet: Tipe Pertanyaan ────────────────────────────────────────

  void _showQuestionTypePicker(int targetIndex) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuestionTypePickerSheet(
        onSelected: (type) {
          setState(() {
            _questions[targetIndex].type = type;
            if (type.hasOptions && _questions[targetIndex].options.isEmpty) {
              _questions[targetIndex].options = [
                QuestionOptionData(label: 'Opsi 1'),
              ];
            }
            if (type == QuestionType.multipleChoiceGrid ||
                type == QuestionType.tickBoxGrid) {
              if (_questions[targetIndex].rowLabels.isEmpty) {
                _questions[targetIndex].rowLabels = ['Baris 1'];
              }
            }
          });
        },
      ),
    );
  }

  void _addQuestion() {
    setState(() {
      _questions.add(
        QuestionData(
          type: QuestionType.multipleChoice,
          label: 'Pertanyaan',
          options: [QuestionOptionData(label: 'Opsi 1')],
        ),
      );
    });
  }

  void _addPageBreak() {
    setState(() {
      _questions.add(QuestionData(type: QuestionType.pageBreak, label: ''));
    });
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFE8F0FE),
        appBar: _buildAppBar(),
        body: TabBarView(
          children: [_buildSoalTab(), _buildSetelanTab()],
        ),
        floatingActionButton: _buildFAB(),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFE8F0FE),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
        onPressed: () => Navigator.pop(context),
        style: IconButton.styleFrom(
          backgroundColor: Colors.white,
          padding: const EdgeInsets.all(12),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
          child: OutlinedButton.icon(
            onPressed: _isSaving ? null : _saveTemplate,
            icon: const Icon(Icons.save_outlined, size: 16),
            label: const Text('Simpan'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0F52BA),
              side: const BorderSide(color: Color(0xFF0F52BA)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _publishForm,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.send, size: 16),
            label: const Text('Publish'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F52BA),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            ),
          ),
        ),
      ],
      bottom: const TabBar(
        labelColor: Color(0xFF0F52BA),
        unselectedLabelColor: Colors.black54,
        indicatorColor: Color(0xFF0F52BA),
        indicatorWeight: 3,
        tabs: [Tab(text: 'Soal'), Tab(text: 'Setelan')],
      ),
    );
  }

  // ─── Soal Tab ─────────────────────────────────────────────────────────────

  Widget _buildSoalTab() {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      // ignore: deprecated_member_use
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex -= 1;
          final item = _questions.removeAt(oldIndex);
          _questions.insert(newIndex, item);
        });
      },
      itemCount: _questions.length + 1, // +1 for title card
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildTitleCard();
        }
        final qIndex = index - 1;
        final q = _questions[qIndex];
        if (q.type == QuestionType.pageBreak) {
          return _buildPageBreakCard(qIndex, key: ValueKey('pb_$qIndex'));
        }
        return _buildQuestionCard(
          qIndex,
          q,
          key: ValueKey('q_$qIndex'),
        );
      },
    );
  }

  Widget _buildTitleCard() {
    return Card(
      key: const ValueKey('title_card'),
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFF0F52BA), width: 4),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: 'Judul Form',
                hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const Divider(),
            TextField(
              controller: _descController,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
              decoration: const InputDecoration(
                hintText: 'Deskripsi formulir (opsional)',
                hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              maxLines: null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageBreakCard(int index, {Key? key}) {
    return Card(
      key: key,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: const Color(0xFFE0E7FF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.view_day_outlined,
                color: Color(0xFF4F46E5), size: 18),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Pemisah Halaman (Section Break)',
                style: TextStyle(
                    color: Color(0xFF4F46E5),
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Color(0xFF6B7280), size: 20),
              onPressed: () => setState(() => _questions.removeAt(index)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(int index, QuestionData q, {Key? key}) {
    return Card(
      key: key,
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFF0F52BA), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle + Question label + Type picker
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.drag_indicator,
                    color: Colors.black26, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: TextEditingController(text: q.label)
                      ..selection = TextSelection.collapsed(
                          offset: q.label.length),
                    onChanged: (v) => q.label = v,
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Pertanyaan',
                      filled: true,
                      fillColor: const Color(0xFFF3F4F6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide.none,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.all(10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => _showQuestionTypePicker(index),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              q.type.label,
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Question preview body
            _buildQuestionBody(index, q),
            const Divider(height: 24),
            // Footer actions
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  tooltip: 'Duplikat',
                  onPressed: () {
                    setState(() {
                      final clone = QuestionData(
                        type: q.type,
                        label: '${q.label} (salinan)',
                        isRequired: q.isRequired,
                        options: q.options
                            .map((o) => QuestionOptionData(label: o.label))
                            .toList(),
                        rowLabels: List.from(q.rowLabels),
                        scaleMin: q.scaleMin,
                        scaleMax: q.scaleMax,
                      );
                      _questions.insert(index + 1, clone);
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  tooltip: 'Hapus',
                  onPressed: () =>
                      setState(() => _questions.removeAt(index)),
                ),
                const Spacer(),
                const Text('Wajib',
                    style:
                        TextStyle(fontSize: 13, color: Colors.black54)),
                const SizedBox(width: 4),
                Switch(
                  value: q.isRequired,
                  onChanged: (v) => setState(() => q.isRequired = v),
                  activeThumbColor: const Color(0xFF0F52BA),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Question Body Preview ─────────────────────────────────────────────────

  Widget _buildQuestionBody(int index, QuestionData q) {
    switch (q.type) {
      case QuestionType.shortAnswer:
        return _previewTextField('Jawaban singkat');
      case QuestionType.paragraph:
        return _previewTextField('Jawaban panjang...', maxLines: 3);
      case QuestionType.multipleChoice:
        return _buildOptionsList(index, q, isRadio: true);
      case QuestionType.checkboxes:
        return _buildOptionsList(index, q, isRadio: false);
      case QuestionType.dropdown:
        return _buildDropdownPreview(index, q);
      case QuestionType.fileUpload:
        return _buildFileUploadPreview();
      case QuestionType.linearScale:
        return _buildLinearScalePreview(index, q);
      case QuestionType.rating:
        return _buildRatingPreview();
      case QuestionType.multipleChoiceGrid:
        return _buildGridPreview(index, q, isRadio: true);
      case QuestionType.tickBoxGrid:
        return _buildGridPreview(index, q, isRadio: false);
      case QuestionType.date:
        return _previewTextField('Tanggal', icon: Icons.calendar_today);
      case QuestionType.time:
        return _previewTextField('Waktu', icon: Icons.access_time);
      case QuestionType.pageBreak:
        return const SizedBox.shrink();
    }
  }

  Widget _previewTextField(String hint,
      {int maxLines = 1, IconData? icon}) {
    return TextField(
      enabled: false,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: Colors.black38),
        prefixIcon:
            icon != null ? Icon(icon, size: 18, color: Colors.black38) : null,
        border: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.black26),
        ),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      ),
    );
  }

  Widget _buildOptionsList(int qIndex, QuestionData q,
      {required bool isRadio}) {
    return Column(
      children: [
        ...q.options.asMap().entries.map((entry) {
          final i = entry.key;
          final opt = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                isRadio
                    ? const Icon(Icons.radio_button_unchecked, size: 20)
                    : const Icon(Icons.check_box_outline_blank, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller:
                        TextEditingController(text: opt.label)
                          ..selection = TextSelection.collapsed(
                              offset: opt.label.length),
                    onChanged: (v) => opt.label = v,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Opsi',
                      border: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.black12)),
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    if (q.options.length > 1) {
                      setState(() => q.options.removeAt(i));
                    }
                  },
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () => setState(
              () => q.options.add(QuestionOptionData(label: 'Opsi baru'))),
          icon: isRadio
              ? const Icon(Icons.radio_button_unchecked,
                  size: 16, color: Colors.black38)
              : const Icon(Icons.check_box_outline_blank,
                  size: 16, color: Colors.black38),
          label: const Text('Tambah opsi',
              style: TextStyle(fontSize: 13, color: Colors.black54)),
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
        ),
      ],
    );
  }

  Widget _buildDropdownPreview(int qIndex, QuestionData q) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  q.options.isEmpty ? 'Pilih...' : q.options.first.label,
                  style:
                      const TextStyle(fontSize: 13, color: Colors.black38),
                ),
              ),
              const Icon(Icons.arrow_drop_down, color: Colors.black38),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...q.options.asMap().entries.map((entry) {
          final i = entry.key;
          final opt = entry.value;
          return Row(
            children: [
              Text('${i + 1}.', style: const TextStyle(color: Colors.black38)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: TextEditingController(text: opt.label)
                    ..selection = TextSelection.collapsed(
                        offset: opt.label.length),
                  onChanged: (v) => opt.label = v,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Opsi',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  if (q.options.length > 1) {
                    setState(() => q.options.removeAt(i));
                  }
                },
              ),
            ],
          );
        }),
        TextButton.icon(
          onPressed: () => setState(
              () => q.options.add(QuestionOptionData(label: 'Opsi baru'))),
          icon: const Icon(Icons.add, size: 16, color: Colors.black38),
          label: const Text('Tambah opsi',
              style: TextStyle(fontSize: 13, color: Colors.black54)),
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
        ),
      ],
    );
  }

  Widget _buildFileUploadPreview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.upload_file_outlined, color: Color(0xFF0F52BA)),
          SizedBox(width: 8),
          Text('Upload File',
              style:
                  TextStyle(color: Color(0xFF0F52BA), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildLinearScalePreview(int qIndex, QuestionData q) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Min:', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            SizedBox(
              width: 50,
              child: DropdownButton<int>(
                value: q.scaleMin,
                isDense: true,
                items: [0, 1].map((v) => DropdownMenuItem(value: v, child: Text('$v'))).toList(),
                onChanged: (v) => setState(() => q.scaleMin = v ?? 1),
              ),
            ),
            const SizedBox(width: 16),
            const Text('Max:', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            SizedBox(
              width: 60,
              child: DropdownButton<int>(
                value: q.scaleMax,
                isDense: true,
                items: [2, 3, 4, 5, 6, 7, 8, 9, 10]
                    .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                    .toList(),
                onChanged: (v) => setState(() => q.scaleMax = v ?? 5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            q.scaleMax - q.scaleMin + 1,
            (i) => Flexible(
              child: Column(
                children: [
                  const Icon(Icons.radio_button_unchecked,
                      size: 20, color: Colors.black38),
                  Text('${q.scaleMin + i}',
                      style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRatingPreview() {
    return Row(
      children: List.generate(
        5,
        (i) => const Padding(
          padding: EdgeInsets.only(right: 4),
          child: Icon(Icons.star_border, color: Color(0xFFFBBF24), size: 30),
        ),
      ),
    );
  }

  Widget _buildGridPreview(int qIndex, QuestionData q,
      {required bool isRadio}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Column headers (options)
        Row(
          children: [
            const SizedBox(width: 80),
            ...q.options.map((o) => Expanded(
                  child: Text(o.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                )),
          ],
        ),
        // Rows
        ...q.rowLabels.asMap().entries.map((rowEntry) {
          final ri = rowEntry.key;
          return Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(rowEntry.value,
                    style: const TextStyle(fontSize: 12)),
              ),
              ...q.options.map((_) => Expanded(
                    child: Center(
                      child: isRadio
                          ? const Icon(Icons.radio_button_unchecked, size: 18)
                          : const Icon(Icons.check_box_outline_blank, size: 18),
                    ),
                  )),
              IconButton(
                icon: const Icon(Icons.close, size: 14),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  if (q.rowLabels.length > 1) {
                    setState(() => q.rowLabels.removeAt(ri));
                  }
                },
              ),
            ],
          );
        }),
        TextButton.icon(
          onPressed: () => setState(
              () => q.rowLabels.add('Baris ${q.rowLabels.length + 1}')),
          icon: const Icon(Icons.add, size: 14),
          label: const Text('Tambah baris', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
        ),
        const Divider(height: 12),
        Row(
          children: [
            ...q.options.asMap().entries.map((e) => Expanded(
                  child: TextField(
                    controller: TextEditingController(text: e.value.label)
                      ..selection = TextSelection.collapsed(
                          offset: e.value.label.length),
                    onChanged: (v) => e.value.label = v,
                    style: const TextStyle(fontSize: 11),
                    decoration: InputDecoration(
                      hintText: 'Kolom ${e.key + 1}',
                      isDense: true,
                      border: const UnderlineInputBorder(),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                )),
            IconButton(
              icon: const Icon(Icons.add, size: 16),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => setState(() =>
                  q.options.add(QuestionOptionData(
                      label: 'Kolom ${q.options.length + 1}'))),
            ),
          ],
        ),
      ],
    );
  }

  // ─── FAB ──────────────────────────────────────────────────────────────────

  Widget _buildFAB() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.small(
          heroTag: 'pageBreak',
          onPressed: _addPageBreak,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0F52BA),
          tooltip: 'Tambah Pemisah Halaman',
          child: const Icon(Icons.view_day_outlined),
        ),
        const SizedBox(height: 8),
        FloatingActionButton(
          heroTag: 'addQuestion',
          onPressed: _addQuestion,
          backgroundColor: const Color(0xFF1E66D0),
          foregroundColor: Colors.white,
          child: const Icon(Icons.add),
        ),
      ],
    );
  }

  // ─── Setelan Tab ──────────────────────────────────────────────────────────

  Widget _buildSetelanTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildQuizSettingsCard(),
          const SizedBox(height: 12),
          _buildResponseSettingsCard(),
          const SizedBox(height: 12),
          _buildDefaultSettingsCard(),
          const SizedBox(height: 12),
          _buildTimerSettingsCard(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildQuizSettingsCard() {
    return Card(
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Jadikan ini sebagai kuis',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87)),
                      SizedBox(height: 4),
                      Text(
                          'Menetapkan pertanyaan dan nilai poin, serta menyediakan masukan secara otomatis',
                          style: TextStyle(
                              fontSize: 13, color: Colors.black54)),
                    ],
                  ),
                ),
                Switch(
                  value: _isQuiz,
                  onChanged: (v) => setState(() => _isQuiz = v),
                  activeThumbColor: Colors.white,
                  activeTrackColor: const Color(0xFF0F52BA),
                ),
              ],
            ),
            if (_isQuiz) ...[
              const SizedBox(height: 24),
              const Text('RILIS NILAI',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54)),
              const SizedBox(height: 8),
              _buildRadioOption('Langsung setelah setiap pengiriman', 'langsung',
                  _releaseGrade, (v) => setState(() => _releaseGrade = v.toString())),
              _buildRadioOption(
                  'Nanti, setelah peninjauan manual\nAktifkan Respons -> Kumpulkan alamat email',
                  'nanti',
                  _releaseGrade,
                  (v) => setState(() => _releaseGrade = v.toString())),
              const SizedBox(height: 24),
              const Text('SETELAN RESPONDEN',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54)),
              const SizedBox(height: 8),
              _settingsSwitchRow('Pertanyaan tak terjawab', _missedQuestions,
                  (v) => setState(() => _missedQuestions = v)),
              const SizedBox(height: 12),
              _settingsSwitchRow('Jawaban yang benar', _correctAnswers,
                  (v) => setState(() => _correctAnswers = v)),
              const SizedBox(height: 12),
              _settingsSwitchRow('Nilai poin', _pointValues,
                  (v) => setState(() => _pointValues = v)),
              const SizedBox(height: 24),
              const Text('DEFAULT KUIS GLOBAL',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54)),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                      child: Text('Nilai poin pertanyaan default',
                          style:
                              TextStyle(fontSize: 14, color: Colors.black87))),
                  Container(
                    width: 60,
                    height: 36,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: TextField(
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero),
                      controller: TextEditingController(text: '0'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('poin',
                      style: TextStyle(fontSize: 14, color: Colors.black54)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRadioOption(String title, String value, String groupValue,
      ValueChanged onChanged) {
    return InkWell(
      onTap: () => onChanged(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              // ignore: deprecated_member_use
              child: Radio(
                value: value,
                // ignore: deprecated_member_use
                groupValue: groupValue,
                // ignore: deprecated_member_use
                onChanged: onChanged,
                activeColor: const Color(0xFF0F52BA),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Text(title,
                    style:
                        const TextStyle(fontSize: 13, color: Colors.black87))),
          ],
        ),
      ),
    );
  }

  Widget _buildResponseSettingsCard() {
    return Card(
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: const Text('Jawaban',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          subtitle: const Text(
              'Mengelola cara respons dikumpulkan dan dilindungi',
              style: TextStyle(fontSize: 13, color: Colors.black54)),
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            const Divider(height: 1),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Mengirim salinan jawaban responden',
                  style: TextStyle(fontSize: 14, color: Colors.black87)),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.black12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _sendCopy,
                    isExpanded: false,
                    items: ['Nonaktif', 'Aktif']
                        .map((e) => DropdownMenuItem(
                            value: e,
                            child: Text(e,
                                style: const TextStyle(fontSize: 14))))
                        .toList(),
                    onChanged: (v) => setState(() => _sendCopy = v!),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _settingsSwitchRow('Batasi ke 1 jawaban', _limitOneResponse,
                (v) => setState(() => _limitOneResponse = v),
                subtitle: 'Responden akan diwajibkan untuk login'),
            const SizedBox(height: 16),
            _settingsSwitchRow('Sembunyikan jawaban', _hideResponses,
                (v) => setState(() => _hideResponses = v)),
            const SizedBox(height: 16),
            _settingsSwitchRow('Isi Form lebih dari 1 kali', _allowMultipleEdits,
                (v) => setState(() => _allowMultipleEdits = v)),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultSettingsCard() {
    return Card(
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: const Text('Default',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            const Divider(height: 1),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Pertanyaan default',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
            ),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Setelan diterapkan untuk semua pertanyaan',
                  style: TextStyle(fontSize: 12, color: Colors.black54)),
            ),
            const SizedBox(height: 12),
            _settingsSwitchRow(
                'Buat pertanyaan wajib diisi secara default',
                _requireQuestionDefault,
                (v) => setState(() => _requireQuestionDefault = v)),
          ],
        ),
      ),
    );
  }

  Widget _settingsSwitchRow(
      String label, bool value, ValueChanged<bool> onChanged,
      {String? subtitle}) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 14, color: Colors.black87)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle,
                    style:
                        const TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Colors.white,
          activeTrackColor: const Color(0xFF0F52BA),
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: Colors.grey.shade400,
        ),
      ],
    );
  }

  Widget _buildTimerSettingsCard() {
    return Card(
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.av_timer, color: Color(0xFF0F52BA)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Form Timer',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87)),
                      SizedBox(height: 2),
                      Text('Manage constraints and timing for this form',
                          style: TextStyle(
                              fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Enable Timer',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87)),
                      Text('Set a time limit for form completion',
                          style: TextStyle(
                              fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ),
                Switch(
                  value: _enableTimer,
                  onChanged: (v) => setState(() => _enableTimer = v),
                  activeThumbColor: Colors.white,
                  activeTrackColor: const Color(0xFF2563EB),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Select Timer Mode',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(6)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _timerMode,
                  isExpanded: true,
                  items: [
                    'Start when respondent opens the form',
                    'Start at a specific date and time'
                  ]
                      .map((e) => DropdownMenuItem(
                          value: e,
                          child: Text(e,
                              style: const TextStyle(fontSize: 14))))
                      .toList(),
                  onChanged: (v) => setState(() => _timerMode = v!),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Duration',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            const SizedBox(height: 8),
            TextField(
              controller: _durationCtrl,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Colors.black12)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                isDense: true,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                  borderRadius: BorderRadius.circular(6)),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      color: Color(0xFF2563EB), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The form will auto-submit and lock once the timer runs out. Respondents will see a countdown display at the top of the page.',
                      style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1D4ED8),
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings Saved')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
                elevation: 0,
              ),
              child: const Text('Save Settings',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                 // Discard changes logic here if needed
              },
              style: TextButton.styleFrom(foregroundColor: Colors.black54),
              child: const Text('Discard Changes'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Question Type Picker Bottom Sheet ────────────────────────────────────────

class _QuestionTypePickerSheet extends StatelessWidget {
  final ValueChanged<QuestionType> onSelected;

  const _QuestionTypePickerSheet({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final types = [
      (QuestionType.shortAnswer, Icons.short_text, 'Jawaban Singkat'),
      (QuestionType.paragraph, Icons.subject, 'Paragraf'),
      (QuestionType.multipleChoice, Icons.radio_button_checked, 'Pilihan Ganda'),
      (QuestionType.checkboxes, Icons.check_box, 'Kotak Centang'),
      (QuestionType.dropdown, Icons.arrow_drop_down_circle, 'Dropdown'),
      (QuestionType.fileUpload, Icons.upload_file, 'Upload File'),
      (QuestionType.linearScale, Icons.linear_scale, 'Skala Linier'),
      (QuestionType.rating, Icons.star_half, 'Rating Bintang'),
      (QuestionType.multipleChoiceGrid, Icons.grid_on, 'Grid Pilihan Ganda'),
      (QuestionType.tickBoxGrid, Icons.grid_4x4, 'Grid Kotak Centang'),
      (QuestionType.date, Icons.calendar_today, 'Tanggal'),
      (QuestionType.time, Icons.access_time, 'Waktu'),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Pilih Tipe Pertanyaan',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.8,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: types.length,
            itemBuilder: (context, index) {
              final (type, icon, label) = types[index];
              return InkWell(
                onTap: () {
                  Navigator.pop(context);
                  onSelected(type);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFFF9FAFB),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 20, color: const Color(0xFF0F52BA)),
                      const SizedBox(height: 4),
                      Text(label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── Share Form Dialog ────────────────────────────────────────────────────────

class ShareFormDialog extends StatefulWidget {
  final String link;
  final String qrUrl;

  const ShareFormDialog({super.key, required this.link, required this.qrUrl});

  @override
  State<ShareFormDialog> createState() => _ShareFormDialogState();
}

class _ShareFormDialogState extends State<ShareFormDialog> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Kirim formulir',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w400)),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Kirim melalui',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: Colors.black87)),
            const SizedBox(height: 8),
            Row(
              children: [
                _tabIcon(Icons.link, 0),
                const SizedBox(width: 4),
                _tabIcon(Icons.qr_code, 1),
              ],
            ),
            const Divider(height: 24),
            if (_selectedTab == 0) _buildLinkTab() else _buildQrTab(),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal',
                    style: TextStyle(color: Colors.black54)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabIcon(IconData icon, int index) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          border: isSelected
              ? const Border(
                  bottom: BorderSide(color: Color(0xFF0F52BA), width: 3))
              : null,
        ),
        child: Icon(icon,
            color:
                isSelected ? const Color(0xFF0F52BA) : Colors.black38,
            size: 22),
      ),
    );
  }

  Widget _buildLinkTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: TextEditingController(text: widget.link),
          readOnly: true,
          style: const TextStyle(fontSize: 13, color: Color(0xFF2563EB)),
          decoration: const InputDecoration(
            border: UnderlineInputBorder(),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 8),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.link));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tautan disalin!')),
              );
            },
            child: const Text('Salin',
                style: TextStyle(
                    color: Color(0xFF0F52BA),
                    fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildQrTab() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Image.network(
          widget.qrUrl,
          height: 180,
          width: 180,
          errorBuilder: (context, error, stackTrace) => const SizedBox(
            height: 180,
            width: 180,
            child: Center(
              child: Icon(Icons.qr_code, size: 80, color: Colors.black26),
            ),
          ),
        ),
      ),
    );
  }
}
