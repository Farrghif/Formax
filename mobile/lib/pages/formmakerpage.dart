import 'package:flutter/material.dart';
import '../models/form_template.dart';
import '../services/api_service.dart';
import '../widgets/share_form_dialog.dart';
import 'form_maker/models/form_builder_state.dart';
import 'form_maker/editor_canvas.dart';
import 'form_maker/preview_canvas.dart';
import 'form_maker/components/builder_toolbar.dart';
import '../models/question_model.dart'; // Ensure QuestionType is imported for toolbar

class FormMakerPage extends StatefulWidget {
  final FormTemplate? initialTemplate;

  const FormMakerPage({super.key, this.initialTemplate});

  @override
  State<FormMakerPage> createState() => _FormMakerPageState();
}

class _FormMakerPageState extends State<FormMakerPage> with SingleTickerProviderStateMixin {
  late FormBuilderState _builderState;
  late TabController _tabController;
  bool _isPreviewMode = false;

  final Color _primaryColor = const Color(0xFF4F46E5);
  final Color _bgColor = const Color(0xFFF3F4F6);

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

    final payload = {
      'title': _builderState.formTitle.isNotEmpty ? _builderState.formTitle : 'Form Tanpa Judul',
      'description': _builderState.formDescription,
      'questions': _builderState.buildApiPayload(),
    };

    final res = await ApiService.createTemplate(payload);
    setState(() => _builderState.isSaving = false);

    if (res['success'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Draft berhasil disimpan!'), backgroundColor: Colors.green),
        );
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
    if (_builderState.isSaving) return;
    
    // Simple Validation
    if (_builderState.formTitle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Judul formulir tidak boleh kosong')));
      return;
    }

    setState(() => _builderState.isSaving = true);

    final title = _builderState.formTitle;
    final slug = '${title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';

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
            ? BuilderToolbar(
                onAddQuestion: () {
                  final activePageId = _builderState.activePageId ?? _builderState.pages.first.id;
                  _builderState.addQuestion(activePageId, QuestionType.multipleChoice);
                },
                onAddPage: () {
                  _builderState.addPage();
                },
              )
            : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        );
      }
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
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _builderState.formTitle.isEmpty ? 'Form Tanpa Judul' : _builderState.formTitle,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Text('Status: Draft', style: TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
      bottom: _isPreviewMode ? null : TabBar(
        controller: _tabController,
        labelColor: _primaryColor,
        unselectedLabelColor: Colors.black54,
        indicatorColor: _primaryColor,
        indicatorWeight: 3,
        onTap: (index) {
          setState(() {}); // refresh floating button
        },
        tabs: const [
          Tab(text: 'Pertanyaan'),
          Tab(text: 'Setelan'),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            _isPreviewMode ? Icons.edit_outlined : Icons.visibility_outlined, 
            color: _primaryColor
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
            icon: Icon(Icons.save_outlined, color: _primaryColor),
            onPressed: _builderState.isSaving ? null : _saveDraft,
            tooltip: 'Simpan Draft',
          ),
        Padding(
          padding: const EdgeInsets.only(right: 16.0, top: 10, bottom: 10),
          child: FilledButton.icon(
            onPressed: _builderState.isSaving ? null : _publishForm,
            icon: _builderState.isSaving 
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
