import 'package:flutter/material.dart';
import '../models/question_model.dart';
import '../models/form_template.dart';
import '../services/api_service.dart';
import '../widgets/share_form_dialog.dart';

class FormMakerPage extends StatefulWidget {
  final FormTemplate? initialTemplate;

  const FormMakerPage({super.key, this.initialTemplate});

  @override
  State<FormMakerPage> createState() => _FormMakerPageState();
}

class _FormMakerPageState extends State<FormMakerPage> with SingleTickerProviderStateMixin {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late List<QuestionData> _questions;
  
  int _activeQuestionIndex = 0;
  bool _isSaving = false;
  late TabController _tabController;

  final Color _primaryColor = const Color(0xFF4F46E5);
  final Color _bgColor = const Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

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

          _questions.add(
            QuestionData(
              type: type,
              label: q['label'] ?? 'Pertanyaan',
              hintText: q['placeholder'] ?? '',
              hintStyle: const TextStyle(color: Colors.grey),
              isRequired: q['is_required'] ?? false,
              options: options,
            ),
          );
        }
      }

      if (_questions.isEmpty) {
        _questions.add(
          QuestionData(
            type: QuestionType.multipleChoice,
            label: 'Pertanyaan',
            options: [QuestionOptionData(label: 'Opsi 1')],
          ),
        );
      }
    } else {
      _titleController = TextEditingController(text: 'Form Tanpa Judul');
      _descController = TextEditingController(text: '');
      _questions = [
        QuestionData(
          type: QuestionType.multipleChoice,
          label: 'Pertanyaan Tanpa Judul',
          options: [QuestionOptionData(label: 'Opsi 1')],
        ),
      ];
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ─── API & Data Preparation ───────────────────────────────────────────────

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
      'title': _titleController.text.isNotEmpty ? _titleController.text : 'Form Tanpa Judul',
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

    final title = _titleController.text.isNotEmpty ? _titleController.text : 'Form Tanpa Judul';
    final slug = '${title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';

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

  // ─── Actions ─────────────────────────────────────────────────────────────

  void _addQuestion(QuestionType type) {
    setState(() {
      final newQuestion = QuestionData(
        type: type,
        label: 'Pertanyaan',
        options: type.hasOptions ? [QuestionOptionData(label: 'Opsi 1')] : [],
      );
      _questions.insert(_activeQuestionIndex + 1, newQuestion);
      _activeQuestionIndex++;
    });
  }

  void _duplicateQuestion(int index) {
    setState(() {
      final q = _questions[index];
      final clone = QuestionData(
        type: q.type,
        label: '${q.label} (salinan)',
        isRequired: q.isRequired,
        options: q.options.map((o) => QuestionOptionData(label: o.label)).toList(),
        rowLabels: List.from(q.rowLabels),
        scaleMin: q.scaleMin,
        scaleMax: q.scaleMax,
      );
      _questions.insert(index + 1, clone);
      _activeQuestionIndex = index + 1;
    });
  }

  void _deleteQuestion(int index) {
    setState(() {
      _questions.removeAt(index);
      if (_questions.isEmpty) {
        _questions.add(QuestionData(type: QuestionType.multipleChoice, label: 'Pertanyaan', options: [QuestionOptionData(label: 'Opsi 1')]));
        _activeQuestionIndex = 0;
      } else if (_activeQuestionIndex >= _questions.length) {
        _activeQuestionIndex = _questions.length - 1;
      }
    });
  }

  // ─── Build UI ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: _buildAppBar(),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCanvas(),
          _buildSettingsTab(),
        ],
      ),
      floatingActionButton: _buildFloatingToolbar(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: TextField(
        controller: _titleController,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          hintText: 'Judul Form',
        ),
      ),
      bottom: TabBar(
        controller: _tabController,
        labelColor: _primaryColor,
        unselectedLabelColor: Colors.black54,
        indicatorColor: _primaryColor,
        indicatorWeight: 3,
        tabs: const [
          Tab(text: 'Pertanyaan'),
          Tab(text: 'Setelan'),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.palette_outlined, color: _primaryColor),
          onPressed: () {},
          tooltip: 'Tema',
        ),
        IconButton(
          icon: Icon(Icons.save_outlined, color: _primaryColor),
          onPressed: _isSaving ? null : _saveTemplate,
          tooltip: 'Simpan Template',
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16.0, top: 10, bottom: 10),
          child: FilledButton.icon(
            onPressed: _isSaving ? null : _publishForm,
            icon: _isSaving 
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
              : const Icon(Icons.send, size: 16),
            label: const Text('Publish'),
            style: FilledButton.styleFrom(
              backgroundColor: _primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCanvas() {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        setState(() => _activeQuestionIndex = -1);
      },
      child: ReorderableListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
        // ignore: deprecated_member_use
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (newIndex > oldIndex) newIndex -= 1;
            
            // Adjust indices for title card which is index 0
            if (oldIndex == 0) return; // Cannot reorder title
            if (newIndex == 0) newIndex = 1; // Cannot place before title
            
            final qOldIndex = oldIndex - 1;
            final qNewIndex = newIndex - 1;
            
            final item = _questions.removeAt(qOldIndex);
            _questions.insert(qNewIndex, item);
            
            // Update active index if the active item was moved
            if (_activeQuestionIndex == qOldIndex) {
              _activeQuestionIndex = qNewIndex;
            } else if (_activeQuestionIndex > qOldIndex && _activeQuestionIndex <= qNewIndex) {
              _activeQuestionIndex--;
            } else if (_activeQuestionIndex < qOldIndex && _activeQuestionIndex >= qNewIndex) {
              _activeQuestionIndex++;
            }
          });
        },
        itemCount: _questions.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildTitleHeader(key: const ValueKey('header'));
          }
          final qIndex = index - 1;
          return _buildQuestionBlock(qIndex, key: ValueKey('q_$_questions[qIndex].hashCode_$qIndex'));
        },
      ),
    );
  }

  Widget _buildTitleHeader({required Key key}) {
    final isActive = _activeQuestionIndex == -1;
    return GestureDetector(
      key: key,
      onTap: () => setState(() => _activeQuestionIndex = -1),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isActive ? _primaryColor : Colors.transparent, width: 2),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha:0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 10,
              decoration: BoxDecoration(
                color: _primaryColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
                    decoration: const InputDecoration(
                      hintText: 'Judul Formulir',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    maxLines: null,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descController,
                    style: const TextStyle(fontSize: 15, color: Colors.black54),
                    decoration: const InputDecoration(
                      hintText: 'Deskripsi formulir',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    maxLines: null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionBlock(int index, {required Key key}) {
    final q = _questions[index];
    final isActive = _activeQuestionIndex == index;

    return GestureDetector(
      key: key,
      onTap: () => setState(() => _activeQuestionIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? _primaryColor : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:isActive ? 0.08 : 0.03),
              blurRadius: isActive ? 12 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: isActive ? _buildActiveQuestionEditor(index, q) : _buildReadOnlyQuestion(q),
      ),
    );
  }

  Widget _buildReadOnlyQuestion(QuestionData q) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                q.label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87),
              ),
            ),
            if (q.isRequired) const Text(' *', style: TextStyle(color: Colors.red, fontSize: 16)),
          ],
        ),
        const SizedBox(height: 16),
        _buildReadOnlyQuestionBody(q),
      ],
    );
  }

  Widget _buildReadOnlyQuestionBody(QuestionData q) {
    switch (q.type) {
      case QuestionType.shortAnswer:
        return const TextField(enabled: false, decoration: InputDecoration(hintText: 'Jawaban singkat', isDense: true, border: UnderlineInputBorder()));
      case QuestionType.paragraph:
        return const TextField(enabled: false, maxLines: 3, decoration: InputDecoration(hintText: 'Jawaban panjang', isDense: true, border: UnderlineInputBorder()));
      case QuestionType.multipleChoice:
      case QuestionType.checkboxes:
        return Column(
          children: q.options.map((opt) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Icon(q.type == QuestionType.multipleChoice ? Icons.radio_button_unchecked : Icons.check_box_outline_blank, size: 20, color: Colors.black38),
                  const SizedBox(width: 8),
                  Expanded(child: Text(opt.label, style: const TextStyle(fontSize: 14))),
                ],
              ),
            );
          }).toList(),
        );
      case QuestionType.dropdown:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(8)),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text('Pilih', style: TextStyle(color: Colors.black38)), Icon(Icons.arrow_drop_down, color: Colors.black38)],
          ),
        );
      case QuestionType.fileUpload:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(border: Border.all(color: Colors.black12, style: BorderStyle.solid), borderRadius: BorderRadius.circular(8)),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [Icon(Icons.cloud_upload_outlined, color: Colors.black54), SizedBox(width: 8), Text('Tambahkan File', style: TextStyle(color: Colors.black54))],
          ),
        );
      default:
        return Text('Preview untuk tipe ${q.type.label} belum didukung', style: const TextStyle(color: Colors.black38, fontStyle: FontStyle.italic));
    }
  }

  Widget _buildActiveQuestionEditor(int index, QuestionData q) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Drag handle indicator top center
        const Center(child: Icon(Icons.drag_handle, color: Colors.black26, size: 20)),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: TextEditingController(text: q.label)..selection = TextSelection.collapsed(offset: q.label.length),
                onChanged: (v) => q.label = v,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Pertanyaan',
                  filled: true,
                  fillColor: _bgColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                maxLines: null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: InkWell(
                onTap: () => _showQuestionTypePicker(index),
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
                      Expanded(child: Text(q.type.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                      const Icon(Icons.arrow_drop_down, size: 20, color: Colors.black54),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildEditorBody(index, q),
        const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.copy_outlined, color: Colors.black54, size: 22),
              tooltip: 'Duplikat',
              onPressed: () => _duplicateQuestion(index),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.black54, size: 22),
              tooltip: 'Hapus',
              onPressed: () => _deleteQuestion(index),
            ),
            Container(height: 24, width: 1, color: Colors.black12, margin: const EdgeInsets.symmetric(horizontal: 8)),
            const Text('Wajib', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87)),
            Switch(
              value: q.isRequired,
              onChanged: (v) => setState(() => q.isRequired = v),
              activeThumbColor: _primaryColor,
            ),
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.black54),
              onPressed: () {},
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEditorBody(int index, QuestionData q) {
    if (!q.type.hasOptions) {
      return _buildReadOnlyQuestionBody(q); // Just show the preview for text inputs
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
                  q.type == QuestionType.multipleChoice ? Icons.radio_button_unchecked : 
                  (q.type == QuestionType.checkboxes ? Icons.check_box_outline_blank : Icons.circle_outlined),
                  size: 20, color: Colors.black26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: opt.label)..selection = TextSelection.collapsed(offset: opt.label.length),
                    onChanged: (v) => opt.label = v,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Opsi ${i + 1}',
                      border: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.transparent)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _primaryColor)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                if (q.options.length > 1)
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Colors.black38),
                    onPressed: () => setState(() => q.options.removeAt(i)),
                  ),
              ],
            ),
          );
        }),
        Row(
          children: [
            Icon(
              q.type == QuestionType.multipleChoice ? Icons.radio_button_unchecked : 
              (q.type == QuestionType.checkboxes ? Icons.check_box_outline_blank : Icons.circle_outlined),
              size: 20, color: Colors.black26,
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: () => setState(() => q.options.add(QuestionOptionData(label: 'Opsi baru'))),
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
              child: const Text('Tambah opsi', style: TextStyle(color: Colors.black54, fontSize: 14)),
            ),
          ],
        )
      ],
    );
  }

  void _showQuestionTypePicker(int targetIndex) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: QuestionType.values.map((type) {
            return ListTile(
              leading: Icon(_getIconForType(type), color: Colors.black54),
              title: Text(type.label),
              onTap: () {
                setState(() {
                  _questions[targetIndex].type = type;
                  if (type.hasOptions && _questions[targetIndex].options.isEmpty) {
                    _questions[targetIndex].options = [QuestionOptionData(label: 'Opsi 1')];
                  }
                });
                Navigator.pop(context);
              },
            );
          }).toList(),
        );
      },
    );
  }

  IconData _getIconForType(QuestionType type) {
    switch (type) {
      case QuestionType.shortAnswer: return Icons.short_text;
      case QuestionType.paragraph: return Icons.notes;
      case QuestionType.multipleChoice: return Icons.radio_button_checked;
      case QuestionType.checkboxes: return Icons.check_box;
      case QuestionType.dropdown: return Icons.arrow_drop_down_circle;
      case QuestionType.fileUpload: return Icons.cloud_upload;
      case QuestionType.linearScale: return Icons.linear_scale;
      case QuestionType.rating: return Icons.star;
      case QuestionType.date: return Icons.event;
      case QuestionType.time: return Icons.access_time;
      default: return Icons.widgets;
    }
  }

  Widget _buildFloatingToolbar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha:0.1), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.black87),
            tooltip: 'Tambah Pertanyaan',
            onPressed: () => _addQuestion(QuestionType.multipleChoice),
          ),
          IconButton(
            icon: const Icon(Icons.text_fields, color: Colors.black87),
            tooltip: 'Tambah Judul/Deskripsi',
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.image_outlined, color: Colors.black87),
            tooltip: 'Tambah Gambar',
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.view_agenda_outlined, color: Colors.black87),
            tooltip: 'Tambah Bagian',
            onPressed: () => _addQuestion(QuestionType.pageBreak),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSettingCard(
          title: 'Setelan Respons',
          children: [
            SwitchListTile(
              title: const Text('Kumpulkan alamat email'),
              value: false,
              onChanged: (v) {},
              activeThumbColor: _primaryColor,
            ),
            SwitchListTile(
              title: const Text('Batasi ke 1 tanggapan'),
              value: true,
              onChanged: (v) {},
              activeThumbColor: _primaryColor,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSettingCard(
          title: 'Presentasi',
          children: [
            SwitchListTile(
              title: const Text('Tampilkan status progres'),
              value: false,
              onChanged: (v) {},
              activeThumbColor: _primaryColor,
            ),
            SwitchListTile(
              title: const Text('Acak urutan pertanyaan'),
              value: false,
              onChanged: (v) {},
              activeThumbColor: _primaryColor,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSettingCard({required String title, required List<Widget> children}) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.black12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          ),
          ...children,
        ],
      ),
    );
  }
}
