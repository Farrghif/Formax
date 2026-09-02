import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/form_template.dart';
import '../services/api_service.dart';
import '../utils/quill_html.dart';
import '../widgets/share_form_dialog.dart';
import '../widgets/ngrok_image.dart';
import 'form_maker/models/form_builder_state.dart';
import 'form_maker/editor_canvas.dart';
import 'form_maker/preview_canvas.dart';
import '../models/question_model.dart'; // Ensure QuestionType is imported for toolbar
import 'package:image_picker/image_picker.dart';

class FormMakerResult {
  final String? draftFormId;
  final String? draftFormTitle;
  final FormTemplate? template;

  const FormMakerResult({this.draftFormId, this.draftFormTitle, this.template});

  bool get savedDraft => draftFormId != null && draftFormId!.isNotEmpty;
  bool get savedTemplate => template != null;
}

class FormMakerPage extends StatefulWidget {
  final FormTemplate? initialTemplate;

  /// JSON lengkap form draft (dari GET /forms/{id}) untuk dilanjutkan editing.
  final Map<String, dynamic>? initialDraft;

  const FormMakerPage({super.key, this.initialTemplate, this.initialDraft});

  @override
  State<FormMakerPage> createState() => _FormMakerPageState();
}

class _FormMakerPageState extends State<FormMakerPage>
    with SingleTickerProviderStateMixin {
  late FormBuilderState _builderState;
  late TabController _tabController;
  bool _isPreviewMode = false;
  String? _draftTemplateId; // untuk PATCH template (bukan POST berulang)
  String? _draftFormId;     // untuk PATCH form draft (bukan POST berulang / duplikat)

  final Color _primaryColor = const Color(0xFF4F46E5);
  final Color _bgColor = const Color(0xFFE8EEF7);
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _currentBgColor => _isDark ? const Color(0xFF0F172A) : _bgColor;
  Color get _cardColor => _isDark ? const Color(0xFF1E293B) : Colors.white;
  Color get _textColor => _isDark ? const Color(0xFFF8FAFC) : Colors.black87;
  Color get _subTextColor => _isDark ? const Color(0xFF94A3B8) : Colors.black54;
  Color get _appBarIconColor => _isDark ? const Color(0xFFCBD5E1) : Colors.black54;

  // State untuk Setelan
  bool _isQuiz = true;
  String _releaseGrade = 'langsung';
  bool _missedQuestions = true;
  bool _correctAnswers = true;
  bool _pointValues = true;

  String _sendCopy = 'Nonaktif';
  // Setelan Form (parity dengan web): status, penerimaan respons, batas respons, fullscreen, join token.
  String _formStatus = 'draft'; // draft / published / closed
  bool _acceptResponses = true;
  String _submissionLimit = 'once'; // once / unlimited / custom
  final TextEditingController _customSubLimitCtrl =
      TextEditingController(text: '2');
  bool _requireFullscreen = false;
  bool _useJoinToken = false;
  bool _hideResponses = false;
  bool _allowMultipleEdits = false;

  bool _requireQuestionDefault = false;

  bool _enableTimer = true;
  String _timerMode = 'Start when respondent opens the form';
  final TextEditingController _durationCtrl = TextEditingController(
    text: '1 hari',
  );
  final TextEditingController _pointValueCtrl = TextEditingController(
    text: '0',
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    if (widget.initialDraft != null) {
      final map = Map<String, dynamic>.from(widget.initialDraft!);
      _draftFormId = map['id']?.toString();
      _applyFormSettings(map);
      _builderState = FormBuilderState.fromForm(map);
    } else if (widget.initialTemplate != null) {
      _builderState = FormBuilderState.fromTemplate(widget.initialTemplate!);
      _draftTemplateId = widget.initialTemplate!.id;
    } else {
      _builderState = FormBuilderState();
    }
  }

  // Muat setelan form dari draft (GET /forms/{id}) supaya panel Setelan
  // menampilkan status & limit yang benar saat lanjutkan draft.
  void _applyFormSettings(Map<String, dynamic> map) {
    _formStatus = map['status']?.toString() ?? 'draft';
    _acceptResponses = map['accept_responses'] as bool? ?? true;
    _requireFullscreen = map['require_fullscreen'] as bool? ?? false;
    _correctAnswers = map['allow_see_result'] as bool? ?? true;
    final maxSub = map['max_submissions'];
    if (maxSub is int) {
      if (maxSub == 1) {
        _submissionLimit = 'once';
      } else if (maxSub == 0) {
        _submissionLimit = 'unlimited';
      } else {
        _submissionLimit = 'custom';
        _customSubLimitCtrl.text = '$maxSub';
      }
    }
  }

  @override
  void dispose() {
    _builderState.dispose();
    _tabController.dispose();
    _durationCtrl.dispose();
    _pointValueCtrl.dispose();
    _customSubLimitCtrl.dispose();
    super.dispose();
  }

  String _networkHint(String msg) {
    return msg.contains('SocketException') ||
            msg.contains('Failed host') ||
            msg.contains('Connection refused') ||
            msg.contains('No token')
        ? '\n\nCek: backend jalan di ${ApiService.baseUrl}?\nEmulator: 10.0.2.2:8000 | HP fisik: adb reverse tcp:8000 tcp:8000 + --dart-define=API_URL=http://127.0.0.1:8000'
        : '';
  }

  void _syncTitleFromPage() {
    if (_builderState.pages.isNotEmpty) {
      if (_builderState.pages[0].title.trim().isNotEmpty) {
        _builderState.formTitle = _builderState.pages[0].title;
      }
      if (_builderState.pages[0].description.trim().isNotEmpty) {
        _builderState.formDescription = _builderState.pages[0].description;
      }
    }
  }

  Map<String, dynamic> _buildPublishSettings() {
    // Fix: sesuaikan dengan web — hanya kirim start/end_date jika Form Timer benar-benar butuh window
    // Jika Enable Timer OFF atau mode 'Start when respondent opens' (per-responden, bukan window global) → jangan kirim window
    // Ini yang sebelumnya bikin publish langsung 403 'Form belum dibuka' karena start_date = now future + naive WIB mismatch
    DateTime? startDate;
    DateTime? endDate;
    final isPerRespondent = _timerMode == 'Start when respondent opens the form';
    if (_enableTimer && !isPerRespondent) {
      // Start at specific date and time → window global. 
      // Backend mengharapkan format waktu LOKAL (WIB) tanpa zona (seperti datetime-local di web).
      // Kurangi 5 menit (bukan 60s) untuk mencegah error "Form belum dibuka" jika jam HP lebih cepat dari server.
      startDate = DateTime.now().subtract(const Duration(minutes: 5));
      final durText = _durationCtrl.text.trim();
      final num =
          int.tryParse(RegExp(r'\d+').firstMatch(durText)?.group(0) ?? '1') ??
          1;
      if (durText.contains('jam')) {
        endDate = startDate.add(Duration(hours: num));
      } else if (durText.contains('menit')) {
        endDate = startDate.add(Duration(minutes: num));
      } else {
        endDate = startDate.add(Duration(days: num));
      }
    }

    // Batas respons: 1 kali / tanpa batas / kustom (>= 2) — seperti web.
    int maxSub;
    switch (_submissionLimit) {
      case 'unlimited':
        maxSub = 0;
        break;
      case 'custom':
        final n = int.tryParse(_customSubLimitCtrl.text.trim()) ?? 1;
        maxSub = n >= 2 ? n : 1;
        break;
      case 'once':
      default:
        maxSub = 1;
    }

    return {
      'allow_see_result': _correctAnswers,
      'max_submissions': maxSub,
      'require_fullscreen': _requireFullscreen,
      'reveal_answers': _correctAnswers,
      'accept_responses': _acceptResponses,
      'status': _formStatus,
      // Kirim waktu lokal tanpa Z, sesuai ekspektasi backend (seperti datetime-local)
      if (startDate != null) 'start_date': startDate.toIso8601String(),
      if (endDate != null) 'end_date': endDate.toIso8601String(),
    };
  }

  // Simpan draft/publish form ke /forms. Kalau sudah punya _draftFormId,
  // pakai PATCH (update field + replace questions) supaya tidak duplikat.
  Future<Map<String, dynamic>?> _saveForm({required bool publish}) async {
    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return null;
    setState(() => _builderState.isSaving = true);
    try {
      _syncTitleFromPage();

      final titleHtml = _builderState.formTitle.trim().isNotEmpty
          ? _builderState.formTitle
          : 'Form Tanpa Judul';
      final descriptionHtml = _builderState.formDescription.trim();
      final questionsPayload = _builderState.buildApiPayload();
      final settings = _buildPublishSettings();
      // Tombol Publish selalu menghasilkan status published (seperti web).
      if (publish) settings['status'] = 'published';

      Map<String, dynamic> res;
      if (_draftFormId != null) {
        res = await ApiService.updateForm(_draftFormId!, {
          'title': titleHtml,
          'description': descriptionHtml,
          'banner_url': _builderState.bannerUrl,
          ...settings,
          'questions': questionsPayload,
        });
      } else {
        res = await ApiService.createForm({
          'title': titleHtml,
          'description': descriptionHtml,
          'banner_url': _builderState.bannerUrl,
          'slug': ApiService.generateSlug(QuillHtml.htmlToPlainText(titleHtml)),
          'questions': questionsPayload,
          ...settings,
          if (_useJoinToken) 'use_join_token': true,
        });
        if (res['success'] == true) {
          final data = res['data'];
          if (data is Map && data['id'] != null) {
            // FormCreate tidak punya status/accept_responses → persist via PATCH
            // supaya status closed/published & 'Terima respons' benar-benar tersimpan.
            if ((!publish && _formStatus != 'draft') || !_acceptResponses) {
              await ApiService.updateForm(data['id'].toString(), {
                'status': _formStatus,
                'accept_responses': _acceptResponses,
              });
            }
          }
        }
      }

      if (res['success'] == true) {
        final data = res['data'];
        if (data is Map && data['id'] != null) {
          _draftFormId = data['id'].toString();
        }
      }
      return res;
    } finally {
      if (mounted) setState(() => _builderState.isSaving = false);
    }
  }

  Future<void> _saveDraft() async {
    if (_builderState.isSaving) return;
    final res = await _saveForm(publish: false);
    if (!mounted || res == null) return;

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draft berhasil disimpan — bisa dilanjutkan dari Dashboard / web'),
          backgroundColor: Color(0xFF059669),
        ),
      );
    } else {
      final msg = res['message']?.toString() ?? 'Unknown error';
      final hint = _networkHint(msg);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan draft: $msg$hint'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 5),
        ),
      );
      debugPrint('[FormMaker] Gagal simpan draft: $msg');
    }
  }

  Future<void> _saveAsTemplate() async {
    if (_builderState.isSaving) return;
    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 150));
    _syncTitleFromPage();

    final titleHtml = _builderState.formTitle.trim().isNotEmpty
        ? _builderState.formTitle
        : 'Form Tanpa Judul';
    final descriptionHtml = _builderState.formDescription.trim();
    final questionsPayload = _builderState.buildApiPayload();

    setState(() => _builderState.isSaving = true);

    final payload = {
      'title': titleHtml,
      'description': descriptionHtml,
      'banner_url': _builderState.bannerUrl,
      'questions': questionsPayload,
    };

    final String? targetId = _draftTemplateId ?? widget.initialTemplate?.id;
    final res = targetId != null
        ? await ApiService.updateTemplate(targetId, payload)
        : await ApiService.createTemplate(payload);
    if (!mounted) return;
    setState(() => _builderState.isSaving = false);

    if (res['success'] == true) {
      if (_draftTemplateId == null && widget.initialTemplate?.id == null) {
        final data = res['data'];
        if (data is Map && data['id'] != null) {
          _draftTemplateId = data['id'].toString();
        }
      }
      Navigator.pop(
        context,
        FormMakerResult(
          template: FormTemplate(
            title: QuillHtml.htmlToPlainText(titleHtml),
            subtitle: 'Baru saja disimpan',
            id: _draftTemplateId ?? widget.initialTemplate?.id,
            questionsJson: questionsPayload,
          ),
        ),
      );
    } else {
      final msg = res['message']?.toString() ?? 'Unknown error';
      final hint = _networkHint(msg);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan template: $msg$hint'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 5),
        ),
      );
      debugPrint('[FormMaker] Gagal simpan template: $msg');
    }
  }

  void _publishForm() async {
    if (_builderState.isSaving) return;
    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;

    if (_builderState.formTitle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judul formulir tidak boleh kosong')),
      );
      return;
    }

    final res = await _saveForm(publish: true);
    if (!mounted) return;
    if (res == null) return;
    if (res['success'] != true) {
      final msg = res['message']?.toString() ?? 'terjadi kesalahan';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal publish form: $msg${_networkHint(msg)}'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    // FIX: jangan asal force-unwrap — kalau _draftFormId belum ke-set (mis. data
    // response tak punya id), ambil dari res supaya tidak null-crash.
    var formId = _draftFormId;
    if (formId == null) {
      final data = res['data'];
      if (data is Map && data['id'] != null) {
        _draftFormId = data['id'].toString();
        formId = _draftFormId;
      }
    }
    if (formId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal publish form: tidak ada id form'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    setState(() => _builderState.isSaving = true);

    final titlePlain = QuillHtml.htmlToPlainText(
      _builderState.formTitle.trim().isNotEmpty
          ? _builderState.formTitle
          : 'Form Tanpa Judul',
    );

    // FIX Bug 17-18: createForm selalu draft, maka publish via endpoint khusus.
    // Pastikan benar-benar published (jangan lanjut generate QR kalau gagal).
    final pubRes = await ApiService.publishForm(formId);
    if (pubRes['success'] != true) {
      setState(() => _builderState.isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal publish form: ${pubRes['message'] ?? 'terjadi kesalahan'}',
            ),
          ),
        );
      }
      return;
    }

    final qrRes = await ApiService.generateQrCode(formId);

    if (qrRes['success'] == true) {
      var shareLink = qrRes['data']['share_link'] as String;
      // Paksa link publik selalu menunjuk ke frontend yang dideploy (Vercel),
      // bukan localhost yang mungkin di-set di env backend.
      shareLink = ApiService.publicFormLink(shareLink);
      String qrUrl = qrRes['data']['qr_code_url'] as String;
      if (qrUrl.contains('localhost')) {
        final apiHost = Uri.parse(ApiService.baseUrl).host;
        qrUrl = qrUrl.replaceAll('localhost', apiHost);
      }
      if (mounted) _showShareDialog(shareLink, qrUrl, formId, titlePlain);
    } else {
      if (mounted) {
        setState(() => _builderState.isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal generate QR: ${qrRes['message']}')),
        );
      }
    }
  }

  void _showShareDialog(String link, String qrUrl, String formId, String title) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ShareFormDialog(link: link, qrUrl: qrUrl),
    ).then((_) {
      if (mounted) {
        Navigator.pop(
          context,
          FormMakerResult(draftFormId: formId, draftFormTitle: title),
        );
      }
    });
  }

  void _pickImage() async {
    final picker = ImagePicker();
    // Kompres gambar saat diambil agar ukuran file kecil. Foto kamera full-res
    // (bisa 4-12 MB) gagal diupload lewat tunnel ngrok HTTPS dengan error
    // "HTTPS request failed, statusCode: 0" (koneksi putus saat tubuh request besar).
    // Pola ini sama dengan profil (avatar) & isi form (file upload) yang sudah bekerja.
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (pickedFile != null) {
      final activePageId =
          _builderState.activePageId ?? _builderState.pages.first.id;

      // Upload the image to the backend first
      final uploadResult = await ApiService.uploadFile(pickedFile);
      if (uploadResult['success'] == true) {
        final fileUrl = uploadResult['file_url'] as String;

        // Perilaku seperti Google Form: jika ada pertanyaan yang sedang dipilih,
        // gambar ditempel ke pertanyaan itu (bukan membuat pertanyaan baru).
        final attached =
            _builderState.attachImageToActiveQuestion(fileUrl);
        if (!attached) {
          _builderState.addQuestion(
            activePageId,
            QuestionType.image,
            imageUrl: fileUrl,
          );
        }
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

  /// Pilih & tempelkan gambar ke pertanyaan tertentu (perilaku Google Form,
  /// tombol gambar di toolbar pertanyaan aktif). Tidak membuat pertanyaan baru.
  /// Gambar kedua dst. menumpuk di bawah gambar pertama — teks pertanyaan
  /// (label) tidak pernah diubah.
  Future<void> _pickImageForQuestion(QuestionData q) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (pickedFile == null) return;
    final uploadResult = await ApiService.uploadFile(pickedFile);
    if (!mounted) return;
    if (uploadResult['success'] == true) {
      final fileUrl = uploadResult['file_url'] as String;
      q.addAttachedImage(fileUrl);
      _builderState.triggerUpdate();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal unggah gambar: ${uploadResult['message']}'),
        ),
      );
    }
  }

  Future<void> _pickBanner() async {
    final picker = ImagePicker();
    // Kompres banner sama seperti _pickImage agar upload via ngrok tidak putus
    // dengan error "HTTPS request failed, statusCode: 0".
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (pickedFile == null) return;
    final uploadResult = await ApiService.uploadFile(pickedFile);
    if (!mounted) return;
    if (uploadResult['success'] == true) {
      final fileUrl = uploadResult['file_url'] as String;
      setState(() => _builderState.bannerUrl = fileUrl);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal unggah banner: ${uploadResult['message']}'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  void _applyRequiredToAll() {
    _builderState.setAllQuestionsRequired(true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Semua pertanyaan dijadikan wajib diisi'),
          backgroundColor: Color(0xFF059669),
        ),
      );
    }
  }

  void _applyOptionalToAll() {
    _builderState.setAllQuestionsRequired(false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Semua pertanyaan dijadikan opsional'),
        ),
      );
    }
  }

  void _showAddQuestionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: QuestionType.values
              .where((t) =>
                  t != QuestionType.pageBreak && t != QuestionType.text)
              .map((type) {
                return ListTile(
                  leading: Icon(_getIconForType(type), color: _primaryColor),
                  title: Text(type.label, style: TextStyle(color: _textColor, fontWeight: FontWeight.w500)),
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
      default:
        return Icons.widgets;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _builderState,
      builder: (context, _) {
        // Editor Form Maker dirancang light-only (latar `_bgColor` terang +
        // teks hitam yang dikunci). Bungkus dengan tema terang agar semua teks
        // yang tidak diberi warna eksplisit tetap gelap & terbaca walau berada
        // di mode gelap aplikasi (mencegah teks terang di atas latar terang).
        return Theme(
          data: Theme.of(context).copyWith(scaffoldBackgroundColor: _currentBgColor),
          child: Scaffold(
          backgroundColor: _currentBgColor,
          appBar: _buildAppBar(),
          body: _isPreviewMode
              ? PreviewCanvas(state: _builderState)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    EditorCanvas(
                      state: _builderState,
                      onAddImage: _pickImageForQuestion,
                    ),
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
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(_isDark ? 0.3 : 0.1),
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
                            icon: Icon(
                              Icons.image_outlined,
                              color: _textColor,
                            ),
                            onPressed: _pickImage,
                            tooltip: 'Tambah Gambar',
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.view_agenda_outlined,
                              color: _textColor,
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
        ));
      },
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: _currentBgColor,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0),
        child: Container(
          decoration: BoxDecoration(
            color: _cardColor,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: _textColor,
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
                  unselectedLabelColor: _subTextColor,
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
            color: _appBarIconColor,
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
            icon: Icon(Icons.save_outlined, color: _appBarIconColor),
            onPressed: _builderState.isSaving ? null : _saveDraft,
            tooltip: 'Simpan Draft',
          ),
        if (!_isPreviewMode)
          IconButton(
            icon: Icon(Icons.account_balance, color: _appBarIconColor),
            tooltip: 'Simpan sebagai Template',
            onPressed: _builderState.isSaving ? null : _saveAsTemplate,
          ),
        Padding(
          padding: const EdgeInsets.only(right: 16.0, top: 10, bottom: 10),
          child: FilledButton.icon(
            onPressed: _builderState.isSaving ? null : _publishForm,
            icon: _builderState.isSaving
                ? SizedBox(
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
          _buildBannerCard(),
          const SizedBox(height: 12),
          _buildFormAccessCard(),
          const SizedBox(height: 12),
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

  // ── Banner Form: unggah / ganti / hapus ──
  Widget _buildBannerCard() {
    final banner = _builderState.bannerUrl;
    return Card(
      elevation: 1,
      color: _cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.image_outlined, color: Color(0xFF1E66D0)),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Banner Form',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _textColor,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Gambar header di atas judul form',
                        style: TextStyle(fontSize: 13, color: _subTextColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (banner != null && banner.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: NgrokImage(banner, fit: BoxFit.cover, errorBuilder: (_, _, _) {
                    return Container(
                      color: const Color(0xFFE5E7EB),
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickBanner,
                    icon: const Icon(Icons.upload_file, size: 18),
                    label: Text(banner != null && banner.isNotEmpty ? 'Ganti Banner' : 'Unggah Banner'),
                  ),
                ),
                if (banner != null && banner.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => setState(() => _builderState.bannerUrl = null),
                    tooltip: 'Hapus Banner',
                    icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Form & Akses: status, terima respons, batas respons, layar penuh, join token ──
  Widget _buildFormAccessCard() {
    return Card(
      elevation: 1,
      color: _cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock_outline, color: Color(0xFFDC2626)),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Form & Akses',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _textColor,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Status, penerimaan respons, dan pembatasan',
                        style: TextStyle(fontSize: 13, color: _subTextColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'STATUS FORM',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: _subTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _isDark ? const Color(0xFF0F172A) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _isDark ? const Color(0xFF334155) : Colors.black12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _formStatus,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(
                      value: 'draft',
                      child: Text('Draft', style: TextStyle(fontSize: 14, color: _textColor)),
                    ),
                    DropdownMenuItem(
                      value: 'published',
                      child: Text('Dipublikasikan', style: TextStyle(fontSize: 14, color: _textColor)),
                    ),
                    DropdownMenuItem(
                      value: 'closed',
                      child: Text('Ditutup', style: TextStyle(fontSize: 14, color: _textColor)),
                    ),
                  ],
                  dropdownColor: _isDark ? const Color(0xFF1E293B) : null,
                  icon: Icon(Icons.arrow_drop_down, color: _textColor),
                  onChanged: (v) => setState(() => _formStatus = v!),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _settingsSwitchRow(
              'Terima respons',
              _acceptResponses,
              (v) => setState(() => _acceptResponses = v),
              subtitle: 'Matikan untuk berhenti menerima jawaban tanpa menutup form',
            ),
            const SizedBox(height: 20),
            Text(
              'BATAS RESPONS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: _subTextColor,
              ),
            ),
            const SizedBox(height: 8),
            _buildRadioOption(
              '1 kali per orang',
              'once',
              _submissionLimit,
              (v) => setState(() => _submissionLimit = v.toString()),
            ),
            _buildRadioOption(
              'Tanpa batas',
              'unlimited',
              _submissionLimit,
              (v) => setState(() => _submissionLimit = v.toString()),
            ),
            _buildRadioOption(
              'Kustom (jumlah tertentu)',
              'custom',
              _submissionLimit,
              (v) => setState(() => _submissionLimit = v.toString()),
            ),
            if (_submissionLimit == 'custom') ...[
              const SizedBox(height: 8),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _customSubLimitCtrl,
                  style: TextStyle(color: _textColor),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Batas (>= 2)',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: _isDark ? const Color(0xFF475569) : Colors.black12),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Divider(color: _isDark ? const Color(0xFF334155) : null),
            const SizedBox(height: 12),
            _settingsSwitchRow(
              'Paksa layar penuh (anti-cheat)',
              _requireFullscreen,
              (v) => setState(() => _requireFullscreen = v),
              subtitle: 'Form ditandai "curang" jika responden keluar dari form',
            ),
            const SizedBox(height: 12),
            _settingsSwitchRow(
              'Perlukan token (ujian bareng)',
              _useJoinToken,
              (v) => setState(() => _useJoinToken = v),
              subtitle: 'Token dibuat otomatis saat form pertama kali disimpan',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isDark ? const Color(0xFF451A03) : const Color(0xFFFFF7ED),
                border: Border.all(color: _isDark ? const Color(0xFF9A3412) : const Color(0xFFFDBA74)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: _isDark ? const Color(0xFFFBBF24) : const Color(0xFFEA580C), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Setelan tersimpan saat form disimpan (Simpan Draft / Publish). '
                      'Jadwal timer memakai durasi di kartu Form Timer.',
                      style: TextStyle(
                        fontSize: 12,
                        color: _isDark ? const Color(0xFFFED7AA) : const Color(0xFF9A3412),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizSettingsCard() {
    return Card(
      elevation: 1,
      color: _cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Jadikan ini sebagai kuis',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _textColor,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Menetapkan pertanyaan dan nilai poin, serta menyediakan masukan secara otomatis',
                        style: TextStyle(fontSize: 13, color: _subTextColor),
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
              Text(
                'RILIS NILAI',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _subTextColor,
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
              Text(
                'SETELAN RESPONDEN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _subTextColor,
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
              Text(
                'DEFAULT KUIS GLOBAL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _subTextColor,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Nilai poin pertanyaan default',
                      style: TextStyle(fontSize: 14, color: _textColor),
                    ),
                  ),
                  Container(
                    width: 60,
                    height: 36,
                    decoration: BoxDecoration(
                      border: Border.all(color: _isDark ? const Color(0xFF334155) : Colors.black12),
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
                      controller: _pointValueCtrl,
                      style: TextStyle(color: _textColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'poin',
                    style: TextStyle(fontSize: 14, color: _subTextColor),
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
                style: TextStyle(fontSize: 13, color: _textColor),
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
      color: _cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent, colorScheme: Theme.of(context).colorScheme.copyWith(onSurface: _textColor)),
        child: ExpansionTile(
          title: Text(
            'Jawaban',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
          subtitle: Text(
            'Mengelola cara respons dikumpulkan dan dilindungi',
            style: TextStyle(fontSize: 13, color: _subTextColor),
          ),
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Divider(height: 1, color: _isDark ? const Color(0xFF334155) : null),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Mengirim salinan jawaban responden',
                style: TextStyle(fontSize: 14, color: _textColor),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: _isDark ? const Color(0xFF0F172A) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _isDark ? const Color(0xFF334155) : Colors.black12),
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
                              style: TextStyle(fontSize: 14, color: _textColor),
                            ),
                          ),
                        )
                        .toList(),
                    dropdownColor: _isDark ? const Color(0xFF1E293B) : null,
                    icon: Icon(Icons.arrow_drop_down, color: _textColor),
                    onChanged: (v) => setState(() => _sendCopy = v!),
                  ),
                ),
              ),
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
      color: _cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent, colorScheme: Theme.of(context).colorScheme.copyWith(onSurface: _textColor)),
        child: ExpansionTile(
          title: Text(
            'Default',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Divider(height: 1, color: _isDark ? const Color(0xFF334155) : null),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Pertanyaan default',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _textColor,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Setelan diterapkan untuk semua pertanyaan',
                style: TextStyle(fontSize: 12, color: _subTextColor),
              ),
            ),
            const SizedBox(height: 12),
            _settingsSwitchRow(
              'Buat pertanyaan wajib diisi secara default',
              _requireQuestionDefault,
              (v) => setState(() => _requireQuestionDefault = v),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Terapkan ke semua pertanyaan',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _subTextColor,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _applyRequiredToAll,
                    icon: const Icon(Icons.checklist, size: 18),
                    label: const Text('Set Semua Wajib'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1E66D0),
                      side: const BorderSide(color: Color(0xFF1E66D0)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _applyOptionalToAll(),
                    icon: const Icon(Icons.event_available_outlined, size: 18),
                    label: const Text('Set Semua Opsional'),
                  ),
                ),
              ],
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
                style: TextStyle(fontSize: 14, color: _textColor),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: _subTextColor),
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
          inactiveTrackColor: _isDark ? const Color(0xFF475569) : Colors.grey.shade400,
        ),
      ],
    );
  }

  Widget _buildTimerSettingsCard() {
    return Card(
      elevation: 1,
      color: _cardColor,
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
                    color: _isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.av_timer, color: _primaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Form Timer',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _textColor,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Manage constraints and timing for this form',
                        style: TextStyle(fontSize: 12, color: _subTextColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: _isDark ? const Color(0xFF334155) : null),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enable Timer',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _textColor,
                        ),
                      ),
                      Text(
                        'Set a time limit for form completion',
                        style: TextStyle(fontSize: 12, color: _subTextColor),
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
            Text(
              'Select Timer Mode',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: _isDark ? const Color(0xFF334155) : Colors.black12),
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
                                style: TextStyle(fontSize: 14, color: _textColor),
                              ),
                            ),
                          )
                          .toList(),
                  dropdownColor: _isDark ? const Color(0xFF1E293B) : null,
                  icon: Icon(Icons.arrow_drop_down, color: _textColor),
                  onChanged: (v) => setState(() => _timerMode = v!),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Duration',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _durationCtrl,
              style: TextStyle(color: _textColor),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: _isDark ? const Color(0xFF475569) : Colors.black12),
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
                color: _isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF),
                border: Border.all(color: _isDark ? const Color(0xFF1D4ED8) : const Color(0xFFBFDBFE)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: _primaryColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The form will auto-submit and lock once the timer runs out. Respondents will see a countdown display at the top of the page.',
                      style: TextStyle(
                        fontSize: 12,
                        color: _isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
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
                // Settings sudah sinkron ke payload (status, ke). SnackBar konfirmasi.
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Pengaturan disimpan — akan diterapkan saat Publish (status: $_formStatus, batas respons: $_submissionLimit, timer: ${_enableTimer ? _durationCtrl.text : 'nonaktif'})',
                    ),
                  ),
                );
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
