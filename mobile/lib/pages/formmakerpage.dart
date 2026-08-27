import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/form_template.dart';
import '../services/api_service.dart';
import '../utils/quill_html.dart';
import '../widgets/share_form_dialog.dart';
import 'form_maker/models/form_builder_state.dart';
import 'form_maker/editor_canvas.dart';
import 'form_maker/preview_canvas.dart';
import '../models/question_model.dart'; // Ensure QuestionType is imported for toolbar
import 'package:image_picker/image_picker.dart';

class FormMakerPage extends StatefulWidget {
  final FormTemplate? initialTemplate;

  const FormMakerPage({super.key, this.initialTemplate});

  @override
  State<FormMakerPage> createState() => _FormMakerPageState();
}

class _FormMakerPageState extends State<FormMakerPage>
    with SingleTickerProviderStateMixin {
  late FormBuilderState _builderState;
  late TabController _tabController;
  bool _isPreviewMode = false;

  final Color _primaryColor = const Color(0xFF4F46E5);
  final Color _bgColor = const Color(0xFFE8EEF7);

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
  final TextEditingController _durationCtrl = TextEditingController(
    text: '1 hari',
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    if (widget.initialTemplate != null) {
      _builderState = FormBuilderState.fromTemplate(widget.initialTemplate!);
    } else {
      _builderState = FormBuilderState();
    }
  }

  @override
  void dispose() {
    _builderState.dispose();
    _tabController.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  void _saveDraft() async {
    if (_builderState.isSaving) return;
    setState(() => _builderState.isSaving = true);

    // Always sync the form title from the first page header (RichText HTML -> plain)
    if (_builderState.pages.isNotEmpty) {
      final firstTitleHtml = _builderState.pages[0].title;
      final firstTitlePlain = QuillHtml.htmlToPlainText(firstTitleHtml);
      if (firstTitlePlain.isNotEmpty) {
        _builderState.formTitle = firstTitlePlain;
      }
      // description simpan sebagai plain juga untuk konsistensi list
      _builderState.formDescription = QuillHtml.htmlToPlainText(_builderState.pages[0].description);
    }

    final title = QuillHtml.titleToPlain(_builderState.formTitle, fallback: 'Form Tanpa Judul');
    final descriptionPlain = QuillHtml.htmlToPlainText(_builderState.formDescription);

    final questionsPayload = _builderState.buildApiPayload();
    // Log detail payload untuk diagnosa mapping hilang (cek label/options/settings)
    debugPrint('[FormMaker] Draft title="$title" questions=${questionsPayload.length}');
    for (var i = 0; i < questionsPayload.length && i < 3; i++) {
      debugPrint('[FormMaker] Q$i type=${questionsPayload[i]['type']} label=${(questionsPayload[i]['label'] as String).substring(0, (questionsPayload[i]['label'] as String).length > 60 ? 60 : (questionsPayload[i]['label'] as String).length)} opts=${(questionsPayload[i]['options'] as List).length} settings=${questionsPayload[i]['settings']}');
    }

    final payload = {
      'title': title,
      'description': descriptionPlain,
      'questions': questionsPayload,
    };

    debugPrint('[FormMaker] Simpan draft payload -> ${ApiService.baseUrl}/templates title="$title"');

    final res = await ApiService.createTemplate(payload);
    if (!mounted) return;
    setState(() => _builderState.isSaving = false);

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draft berhasil disimpan ke Template Saya!'),
          backgroundColor: Color(0xFF059669),
        ),
      );
      Navigator.pop(
        context,
        FormTemplate(
          title: title,
          subtitle: 'Baru saja disimpan',
          questionsJson: questionsPayload,
        ),
      );
    } else {
      final msg = res['message']?.toString() ?? 'Unknown error';
      final hint = msg.contains('SocketException') || msg.contains('Failed host') || msg.contains('Connection refused') || msg.contains('No token')
          ? '\n\nCek: backend jalan di ${ApiService.baseUrl}?\nEmulator: 10.0.2.2:8000 | HP fisik: adb reverse tcp:8000 tcp:8000 + --dart-define=API_URL=http://127.0.0.1:8000'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan: $msg$hint'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 5),
        ),
      );
      debugPrint('[FormMaker] Gagal simpan draft: $msg');
    }
  }

  void _publishForm() async {
    if (_builderState.isSaving) return;

    // Simple Validation
    if (_builderState.formTitle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judul formulir tidak boleh kosong')),
      );
      return;
    }

    setState(() => _builderState.isSaving = true);

    final title = _builderState.formTitle;
    final slug =
        '${title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';

    final payload = {
      'title': title,
      'description': _builderState.formDescription,
      'slug': slug,
      'questions': _builderState.buildApiPayload(),
    };

    final res = await ApiService.createForm(payload);
    if (res['success'] == true) {
      final formId = res['data']['id'] as String;
      final qrRes = await ApiService.generateQrCode(formId);
      setState(() => _builderState.isSaving = false);

      if (qrRes['success'] == true) {
        final shareLink = qrRes['data']['share_link'] as String;
        String qrUrl = qrRes['data']['qr_code_url'] as String;
        if (qrUrl.contains('localhost')) {
          final apiHost = Uri.parse(ApiService.baseUrl).host;
          qrUrl = qrUrl.replaceAll('localhost', apiHost);
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
      setState(() => _builderState.isSaving = false);
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

  void _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final activePageId =
          _builderState.activePageId ?? _builderState.pages.first.id;

      // Upload the image to the backend first
      final uploadResult = await ApiService.uploadFile(pickedFile);
      if (uploadResult['success'] == true) {
        final fileUrl = uploadResult['file_url'] as String;
        _builderState.addQuestion(
          activePageId,
          QuestionType.image,
          imageUrl: fileUrl,
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal unggah gambar: ${uploadResult['message']}'),
            ),
          );
        }
      }
    }
  }

  void _showAddQuestionSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: QuestionType.values
              .where((t) => t != QuestionType.pageBreak)
              .map((type) {
                return ListTile(
                  leading: Icon(_getIconForType(type), color: Colors.black54),
                  title: Text(type.label),
                  onTap: () {
                    final activePageId =
                        _builderState.activePageId ??
                        _builderState.pages.first.id;
                    _builderState.addQuestion(activePageId, type);
                    Navigator.pop(context);
                  },
                );
              })
              .toList(),
        );
      },
    );
  }

  IconData _getIconForType(QuestionType type) {
    switch (type) {
      case QuestionType.shortAnswer:
        return Icons.short_text;
      case QuestionType.paragraph:
        return Icons.notes;
      case QuestionType.multipleChoice:
        return Icons.radio_button_checked;
      case QuestionType.checkboxes:
        return Icons.check_box;
      case QuestionType.dropdown:
        return Icons.arrow_drop_down_circle;
      case QuestionType.fileUpload:
        return Icons.cloud_upload;
      case QuestionType.linearScale:
        return Icons.linear_scale;
      case QuestionType.rating:
        return Icons.star;
      case QuestionType.date:
        return Icons.event;
      case QuestionType.time:
        return Icons.access_time;
      case QuestionType.image:
        return Icons.image_outlined;
      case QuestionType.text:
        return Icons.title;
      default:
        return Icons.widgets;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _builderState,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: _bgColor,
          appBar: _buildAppBar(),
          body: _isPreviewMode
              ? PreviewCanvas(state: _builderState)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    EditorCanvas(state: _builderState),
                    _buildSettingsTab(),
                  ],
                ),
          floatingActionButton: (!_isPreviewMode && _tabController.index == 0)
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.title,
                              color: Colors.black87,
                            ),
                            onPressed: () {
                              final activePageId =
                                  _builderState.activePageId ??
                                  _builderState.pages.first.id;
                              _builderState.addQuestion(
                                activePageId,
                                QuestionType.text,
                              );
                            },
                            tooltip: 'Tambah Judul/Deskripsi',
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.image_outlined,
                              color: Colors.black87,
                            ),
                            onPressed: _pickImage,
                            tooltip: 'Tambah Gambar',
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.view_agenda_outlined,
                              color: Colors.black87,
                            ),
                            onPressed: () {
                              _builderState.addPage();
                            },
                            tooltip: 'Tambah Bagian',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    FloatingActionButton(
                      heroTag: 'add_question_btn',
                      onPressed: _showAddQuestionSheet,
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      child: const Icon(Icons.add, size: 28),
                    ),
                  ],
                )
              : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        );
      },
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: _bgColor,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.black87,
              size: 18,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      title: null,
      bottom: _isPreviewMode
          ? null
          : PreferredSize(
              preferredSize: const Size.fromHeight(kTextTabBarHeight),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: TabBar(
                  controller: _tabController,
                  labelColor: _primaryColor,
                  unselectedLabelColor: Colors.black54,
                  indicatorColor: _primaryColor,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                  onTap: (index) {
                    setState(() {}); // refresh floating button
                  },
                  tabs: const [
                    Tab(text: 'Soal'),
                    Tab(text: 'Setelan'),
                  ],
                ),
              ),
            ),
      actions: [
        IconButton(
          icon: Icon(
            _isPreviewMode ? Icons.edit_outlined : Icons.visibility_outlined,
            color: Colors.black54,
          ),
          onPressed: () {
            setState(() {
              _isPreviewMode = !_isPreviewMode;
              // Clear active selection when switching modes
              _builderState.setActiveQuestion(null, null);
            });
          },
          tooltip: _isPreviewMode ? 'Editor Mode' : 'Preview Mode',
        ),
        if (!_isPreviewMode)
          IconButton(
            icon: const Icon(Icons.save_outlined, color: Colors.black54),
            onPressed: _builderState.isSaving ? null : _saveDraft,
            tooltip: 'Simpan Draft',
          ),
        Padding(
          padding: const EdgeInsets.only(right: 16.0, top: 10, bottom: 10),
          child: FilledButton.icon(
            onPressed: _builderState.isSaving ? null : _publishForm,
            icon: _builderState.isSaving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.send, size: 16),
            label: const Text(
              'Publish',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTab() {
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
                      Text(
                        'Jadikan ini sebagai kuis',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Menetapkan pertanyaan dan nilai poin, serta menyediakan masukan secara otomatis',
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isQuiz,
                  onChanged: (v) => setState(() => _isQuiz = v),
                  activeThumbColor: Colors.white,
                  activeTrackColor: _primaryColor,
                ),
              ],
            ),
            if (_isQuiz) ...[
              const SizedBox(height: 24),
              const Text(
                'RILIS NILAI',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              _buildRadioOption(
                'Langsung setelah setiap pengiriman',
                'langsung',
                _releaseGrade,
                (v) => setState(() => _releaseGrade = v.toString()),
              ),
              _buildRadioOption(
                'Nanti, setelah peninjauan manual\nAktifkan Respons -> Kumpulkan alamat email',
                'nanti',
                _releaseGrade,
                (v) => setState(() => _releaseGrade = v.toString()),
              ),
              const SizedBox(height: 24),
              const Text(
                'SETELAN RESPONDEN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              _settingsSwitchRow(
                'Pertanyaan tak terjawab',
                _missedQuestions,
                (v) => setState(() => _missedQuestions = v),
              ),
              const SizedBox(height: 12),
              _settingsSwitchRow(
                'Jawaban yang benar',
                _correctAnswers,
                (v) => setState(() => _correctAnswers = v),
              ),
              const SizedBox(height: 12),
              _settingsSwitchRow(
                'Nilai poin',
                _pointValues,
                (v) => setState(() => _pointValues = v),
              ),
              const SizedBox(height: 24),
              const Text(
                'DEFAULT KUIS GLOBAL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Nilai poin pertanyaan default',
                      style: TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                  ),
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
                        contentPadding: EdgeInsets.zero,
                      ),
                      controller: TextEditingController(text: '0'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'poin',
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRadioOption(
    String title,
    String value,
    String groupValue,
    ValueChanged onChanged,
  ) {
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
              child: Radio(
                value: value,
                groupValue: groupValue,
                onChanged: onChanged,
                activeColor: _primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ),
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
          title: const Text(
            'Jawaban',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          subtitle: const Text(
            'Mengelola cara respons dikumpulkan dan dilindungi',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            const Divider(height: 1),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Mengirim salinan jawaban responden',
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
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
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(
                              e,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _sendCopy = v!),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _settingsSwitchRow(
              'Batasi ke 1 jawaban',
              _limitOneResponse,
              (v) => setState(() => _limitOneResponse = v),
              subtitle: 'Responden akan diwajibkan untuk login',
            ),
            const SizedBox(height: 16),
            _settingsSwitchRow(
              'Sembunyikan jawaban',
              _hideResponses,
              (v) => setState(() => _hideResponses = v),
            ),
            const SizedBox(height: 16),
            _settingsSwitchRow(
              'Isi Form lebih dari 1 kali',
              _allowMultipleEdits,
              (v) => setState(() => _allowMultipleEdits = v),
            ),
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
          title: const Text(
            'Default',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            const Divider(height: 1),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Pertanyaan default',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Setelan diterapkan untuk semua pertanyaan',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
            const SizedBox(height: 12),
            _settingsSwitchRow(
              'Buat pertanyaan wajib diisi secara default',
              _requireQuestionDefault,
              (v) => setState(() => _requireQuestionDefault = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingsSwitchRow(
    String label,
    bool value,
    ValueChanged<bool> onChanged, {
    String? subtitle,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Colors.white,
          activeTrackColor: _primaryColor,
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
                  child: Icon(Icons.av_timer, color: _primaryColor),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Form Timer',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Manage constraints and timing for this form',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
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
                      Text(
                        'Enable Timer',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'Set a time limit for form completion',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _enableTimer,
                  onChanged: (v) => setState(() => _enableTimer = v),
                  activeThumbColor: Colors.white,
                  activeTrackColor: _primaryColor,
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Select Timer Mode',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _timerMode,
                  isExpanded: true,
                  items:
                      [
                            'Start when respondent opens the form',
                            'Start at a specific date and time',
                          ]
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(
                                e,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (v) => setState(() => _timerMode = v!),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Duration',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _durationCtrl,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Colors.black12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                isDense: true,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                border: Border.all(color: const Color(0xFFBFDBFE)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: _primaryColor, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'The form will auto-submit and lock once the timer runs out. Respondents will see a countdown display at the top of the page.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1D4ED8),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Settings Saved')));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Save Settings',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
