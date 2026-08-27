import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../widgets/rich_text_view.dart';

/// ============================================================
/// MODEL CLASSES
/// ============================================================

class QuestionOption {
  final String id;
  final String label;
  final String? value;
  final int orderIndex;
  final bool isCorrect;

  QuestionOption({
    required this.id,
    required this.label,
    this.value,
    this.orderIndex = 0,
    this.isCorrect = false,
  });

  factory QuestionOption.fromJson(Map<String, dynamic> json) {
    return QuestionOption(
      id: json['id'] ?? '',
      label: json['label'] ?? '',
      value: json['value'],
      orderIndex: json['order_index'] ?? 0,
      isCorrect: json['is_correct'] ?? false,
    );
  }
}

class Question {
  final String id;
  final String
  type; // text, single_choice, checkbox, dropdown, date, file_upload
  final String label;
  final String? placeholder;
  final bool isRequired;
  final int orderIndex;
  final Map<String, dynamic> settings;
  final List<QuestionOption> options;

  Question({
    required this.id,
    required this.type,
    required this.label,
    this.placeholder,
    this.isRequired = false,
    this.orderIndex = 0,
    this.settings = const {},
    this.options = const [],
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] ?? '',
      type: json['type'] ?? 'text',
      label: json['label'] ?? '',
      placeholder: json['placeholder'],
      isRequired: json['is_required'] ?? false,
      orderIndex: json['order_index'] ?? 0,
      settings: json['settings'] ?? {},
      options:
          (json['options'] as List<dynamic>?)
              ?.map((o) => QuestionOption.fromJson(o))
              .toList() ??
          [],
    );
  }
}

class FormData {
  final String id;
  final String title;
  final String? description;
  final String? bannerUrl;
  final String slug;
  final String? joinToken;
  final bool acceptResponses;
  final String? startDate;
  final String? endDate;
  final List<Question> questions;

  FormData({
    required this.id,
    required this.title,
    this.description,
    this.bannerUrl,
    required this.slug,
    this.joinToken,
    this.acceptResponses = true,
    this.startDate,
    this.endDate,
    this.questions = const [],
  });

  factory FormData.fromJson(Map<String, dynamic> json) {
    return FormData(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      bannerUrl: json['banner_url'],
      slug: json['slug'] ?? '',
      joinToken: json['join_token'],
      acceptResponses: json['accept_responses'] ?? true,
      startDate: json['start_date'],
      endDate: json['end_date'],
      questions:
          (json['questions'] as List<dynamic>?)
              ?.map((q) => Question.fromJson(q))
              .toList() ??
          [],
    );
  }
}

/// ============================================================
/// FillFormPage — Halaman pengisian form via link / QR code
/// ============================================================

class FillFormPage extends StatefulWidget {
  final String slug;

  const FillFormPage({super.key, required this.slug});

  @override
  State<FillFormPage> createState() => _FillFormPageState();
}

class _FillFormPageState extends State<FillFormPage> {
  // States
  bool _isLoading = true;
  String? _errorMsg;
  FormData? _formData;
  String? _submissionId;
  bool _isSubmitted = false;
  bool _isSubmitting = false;

  // Answers: { questionId: { "answer_text": ..., "answer_options": [...] } }
  final Map<String, Map<String, dynamic>> _answers = {};
  // FIX Bug 32: cache TextEditingController per question agar cursor tidak lompat tiap rebuild
  final Map<String, TextEditingController> _textCtrls = {};

  // Join Token
  bool _showJoinTokenDialog = false;
  final TextEditingController _joinTokenController = TextEditingController();
  String? _joinTokenError;

  // Pagination
  static const int _questionsPerPage = 4;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _loadForm();
  }

  @override
  void dispose() {
    _joinTokenController.dispose();
    for (var c in _textCtrls.values) { c.dispose(); }
    super.dispose();
  }

  TextEditingController _getTextCtrl(Question q) {
    var ctrl = _textCtrls[q.id];
    final cur = _answers[q.id]?['answer_text'] ?? '';
    if (ctrl == null) {
      ctrl = TextEditingController(text: cur);
      ctrl.addListener(() => _answers[q.id] = {'answer_text': ctrl!.text});
      _textCtrls[q.id] = ctrl;
    } else if (ctrl.text != cur) {
      // sync jika jawaban diupdate dari luar (misal load draft)
      ctrl.text = cur;
      ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
    }
    return ctrl;
  }

  // ============================================================
  // API CALLS
  // ============================================================

  Future<void> _loadForm() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final token = await ApiService.getToken();
      if (token == null) {
        setState(() {
          _errorMsg = 'Silakan login terlebih dahulu';
          _isLoading = false;
        });
        return;
      }

      // 1. Fetch form data by slug
      final formResponse = await http.get(
        Uri.parse('${ApiService.baseUrl}/forms/public/${widget.slug}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (formResponse.statusCode != 200) {
        final detail =
            jsonDecode(formResponse.body)['detail'] ?? 'Form tidak ditemukan';
        setState(() {
          _errorMsg = detail;
          _isLoading = false;
        });
        return;
      }

      final formJson = jsonDecode(formResponse.body);
      final formData = FormData.fromJson(formJson);
      setState(() => _formData = formData);

      // 2. Try joining the form (auto-join if no token required)
      await _joinForm(token, null);
    } catch (e) {
      setState(() => _errorMsg = 'Terjadi kesalahan: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _joinForm(String token, String? joinToken) async {
    try {
      final body = <String, dynamic>{};
      if (joinToken != null && joinToken.isNotEmpty) {
        body['token'] = joinToken;
      }

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/forms/public/${widget.slug}/join'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final subJson = jsonDecode(response.body);
        setState(() {
          _submissionId = subJson['id'];
          _showJoinTokenDialog = false;
          _joinTokenError = null;
        });

        // Check if already submitted
        if (subJson['submitted_at'] != null) {
          setState(() => _isSubmitted = true);
        }
      } else {
        final detail =
            jsonDecode(response.body)['detail'] ?? 'Gagal memulai form';
        final lowerDetail = detail.toString().toLowerCase();

        if (lowerDetail.contains('token') || (_formData?.joinToken != null)) {
          setState(() {
            _showJoinTokenDialog = true;
            _joinTokenError = joinToken != null ? detail : null;
          });
        } else if (lowerDetail.contains('sudah submit')) {
          setState(() => _isSubmitted = true);
        } else {
          setState(() => _errorMsg = detail);
        }
      }
    } catch (e) {
      setState(() => _errorMsg = 'Gagal terhubung ke server');
    }
  }

  Future<void> _saveAnswer(String questionId) async {
    if (_submissionId == null) return;

    final token = await ApiService.getToken();
    if (token == null) return;

    final answer = _answers[questionId];
    if (answer == null) return;

    try {
      await http.put(
        Uri.parse('${ApiService.baseUrl}/submissions/$_submissionId/answers'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'question_id': questionId,
          'answer_text': answer['answer_text'],
          'answer_options': answer['answer_options'],
          'file_url': answer['file_url'],
        }),
      );
    } catch (_) {
      // Auto-save gagal silently — user tetap bisa lanjut isi
    }
  }

  Future<void> _submitForm() async {
    if (_submissionId == null) return;

    setState(() => _isSubmitting = true);

    try {
      final token = await ApiService.getToken();
      if (token == null) return;

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/submissions/$_submissionId/submit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        setState(() => _isSubmitted = true);
      } else {
        final detail = jsonDecode(response.body)['detail'] ?? 'Gagal submit';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(detail), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal terhubung ke server'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  // ============================================================
  // HELPER METHODS
  // ============================================================

  int get _totalPages {
    if (_formData == null) return 0;
    return (_formData!.questions.length / _questionsPerPage).ceil();
  }

  List<Question> get _currentQuestions {
    if (_formData == null) return [];
    final start = _currentPage * _questionsPerPage;
    final end = (start + _questionsPerPage).clamp(
      0,
      _formData!.questions.length,
    );
    return _formData!.questions.sublist(start, end);
  }

  int get _answeredCount {
    return _answers.values.where((a) {
      final text = a['answer_text'] as String?;
      final options = a['answer_options'] as List?;
      return (text != null && text.isNotEmpty) ||
          (options != null && options.isNotEmpty);
    }).length;
  }

  void _updateAnswer(String questionId, {String? text, List<String>? options}) {
    setState(() {
      _answers[questionId] = {
        'answer_text': text ?? _answers[questionId]?['answer_text'],
        'answer_options': options ?? _answers[questionId]?['answer_options'],
        'file_url': _answers[questionId]?['file_url'],
      };
    });
    _saveAnswer(questionId);
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFB4C5D4),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Color(0xFF374151)),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        _formData?.title ?? 'Memuat Form...',
        style: const TextStyle(
          color: Color(0xFF374151),
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildBody() {
    // Loading state
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF1E66D0)),
            SizedBox(height: 16),
            Text('Memuat form...', style: TextStyle(color: Color(0xFF6B7280))),
          ],
        ),
      );
    }

    // Error state
    if (_errorMsg != null) {
      return _buildErrorState();
    }

    // Join Token Dialog
    if (_showJoinTokenDialog) {
      return _buildJoinTokenForm();
    }

    // Already submitted
    if (_isSubmitted) {
      return _buildSubmittedState();
    }

    // Form content
    if (_formData != null && _submissionId != null) {
      return _buildFormContent();
    }

    return const SizedBox.shrink();
  }

  // ============================================================
  // ERROR STATE
  // ============================================================
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.error_outline,
                size: 48,
                color: Color(0xFFDC2626),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _errorMsg!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF374151),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadForm,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E66D0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // JOIN TOKEN FORM
  // ============================================================
  Widget _buildJoinTokenForm() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Icon(
                  Icons.lock_outline,
                  size: 40,
                  color: Color(0xFF1E66D0),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Token Diperlukan',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Form "${_formData?.title ?? ''}" membutuhkan token untuk diakses.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _joinTokenController,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  letterSpacing: 4,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: 'Masukkan Token',
                  hintStyle: const TextStyle(
                    letterSpacing: 1,
                    fontWeight: FontWeight.normal,
                  ),
                  errorText: _joinTokenError,
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF1E66D0),
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final token = await ApiService.getToken();
                    if (token != null) {
                      await _joinForm(token, _joinTokenController.text.trim());
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E66D0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Mulai Isi Form',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SUBMITTED STATE
  // ============================================================
  Widget _buildSubmittedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.check_circle_outline,
                size: 64,
                color: Color(0xFF059669),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Jawaban Terkirim!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Terima kasih telah mengisi form ini.\nJawaban kamu sudah berhasil disimpan.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF6B7280),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Kembali'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E66D0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FORM CONTENT
  // ============================================================
  Widget _buildFormContent() {
    final questions = _currentQuestions;

    return Column(
      children: [
        // Progress bar
        _buildProgressBar(),

        // Questions list
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Form header (only on first page)
                if (_currentPage == 0) _buildFormHeader(),

                // Questions
                ...questions.asMap().entries.map((entry) {
                  final globalIndex =
                      _currentPage * _questionsPerPage + entry.key;
                  return _buildQuestionCard(entry.value, globalIndex);
                }),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),

        // Navigation buttons
        _buildNavigationButtons(),
      ],
    );
  }

  Widget _buildProgressBar() {
    final total = _formData?.questions.length ?? 0;
    final progress = total > 0 ? _answeredCount / total : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$_answeredCount / $total terjawab',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
              ),
              Text(
                'Halaman ${_currentPage + 1} / $_totalPages',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF1E66D0),
              ),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormHeader() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner image
          if (_formData?.bannerUrl != null && _formData!.bannerUrl!.isNotEmpty)
            Container(
              width: double.infinity,
              height: 150,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                image: DecorationImage(
                  image: NetworkImage(_formData!.bannerUrl!),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          Text(
            _formData!.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          if (_formData?.description != null &&
              _formData!.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _formData!.description!,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 14,
                  color: Color(0xFFD97706),
                ),
                const SizedBox(width: 6),
                Text(
                  '${_formData!.questions.length} pertanyaan',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFD97706),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // QUESTION CARD
  // ============================================================
  Widget _buildQuestionCard(Question question, int index) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question label
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E66D0),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: question.label.contains('<')
                    ? RichTextView(
                        html: question.label,
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      )
                    : RichText(
                        text: TextSpan(
                          text: question.label,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2937),
                          ),
                          children: [
                            if (question.isRequired)
                              const TextSpan(
                                text: ' *',
                                style: TextStyle(
                                  color: Color(0xFFDC2626),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Answer input based on question type
          _buildAnswerInput(question),
        ],
      ),
    );
  }

  Widget _buildAnswerInput(Question question) {
    switch (question.type) {
      case 'text':
      case 'paragraph':
        return _buildTextInput(question);
      case 'single_choice':
        return _buildSingleChoiceInput(question);
      case 'checkbox':
        return _buildCheckboxInput(question);
      case 'dropdown':
        return _buildDropdownInput(question);
      case 'date':
        return _buildDateInput(question);
      case 'time':
        return _buildTextInput(question);
      case 'linear_scale':
        return _buildLinearScaleInput(question);
      case 'rating':
        return _buildRatingInput(question);
      case 'multiple_choice_grid':
      case 'tick_box_grid':
        return _buildGridInput(question);
      case 'file_upload':
        return _buildFileUploadInput(question);
      case 'image':
      case 'text_block':
        return const SizedBox.shrink();
      default:
        return _buildTextInput(question);
    }
  }

  // --- TEXT INPUT ---
  Widget _buildTextInput(Question question) {
    final ctrl = _getTextCtrl(question);
    return TextField(
      controller: ctrl,
      onChanged: (value) => _updateAnswer(question.id, text: value),
      maxLines: 3,
      decoration: InputDecoration(
        hintText: question.placeholder ?? 'Ketik jawaban di sini...',
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1E66D0), width: 2),
        ),
        contentPadding: const EdgeInsets.all(14),
      ),
    );
  }

  // --- SINGLE CHOICE (RADIO) ---
  Widget _buildSingleChoiceInput(Question question) {
    final selectedValue = _answers[question.id]?['answer_text'] ?? '';

    return Column(
      children: question.options.map((option) {
        final isSelected = selectedValue == option.label;
        return InkWell(
          onTap: () => _updateAnswer(question.id, text: option.label),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFEFF6FF)
                  : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF1E66D0)
                    : const Color(0xFFD1D5DB),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: isSelected
                      ? const Color(0xFF1E66D0)
                      : const Color(0xFF9CA3AF),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    option.label,
                    style: TextStyle(
                      fontSize: 15,
                      color: isSelected
                          ? const Color(0xFF1E40AF)
                          : const Color(0xFF374151),
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // --- CHECKBOX (MULTI CHOICE) ---
  Widget _buildCheckboxInput(Question question) {
    final selectedOptions = List<String>.from(
      _answers[question.id]?['answer_options'] ?? [],
    );

    return Column(
      children: question.options.map((option) {
        final isSelected = selectedOptions.contains(option.label);
        return InkWell(
          onTap: () {
            final newOptions = List<String>.from(selectedOptions);
            if (isSelected) {
              newOptions.remove(option.label);
            } else {
              newOptions.add(option.label);
            }
            _updateAnswer(question.id, options: newOptions);
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFEFF6FF)
                  : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF1E66D0)
                    : const Color(0xFFD1D5DB),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                  color: isSelected
                      ? const Color(0xFF1E66D0)
                      : const Color(0xFF9CA3AF),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    option.label,
                    style: TextStyle(
                      fontSize: 15,
                      color: isSelected
                          ? const Color(0xFF1E40AF)
                          : const Color(0xFF374151),
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // --- DROPDOWN ---
  Widget _buildDropdownInput(Question question) {
    final selectedValue = _answers[question.id]?['answer_text'] ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: selectedValue.isEmpty ? null : selectedValue,
          hint: const Text(
            'Pilih jawaban...',
            style: TextStyle(color: Color(0xFF9CA3AF)),
          ),
          items: question.options.map((option) {
            return DropdownMenuItem<String>(
              value: option.label,
              child: Text(option.label),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) _updateAnswer(question.id, text: value);
          },
        ),
      ),
    );
  }

  // --- DATE INPUT ---
  Widget _buildDateInput(Question question) {
    final currentDate = _answers[question.id]?['answer_text'] ?? '';

    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: Color(0xFF1E66D0),
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          final formatted =
              '${picked.day.toString().padLeft(2, '0')}/'
              '${picked.month.toString().padLeft(2, '0')}/'
              '${picked.year}';
          _updateAnswer(question.id, text: formatted);
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFD1D5DB)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today,
              size: 20,
              color: Color(0xFF6B7280),
            ),
            const SizedBox(width: 12),
            Text(
              currentDate.isEmpty ? 'Pilih tanggal...' : currentDate,
              style: TextStyle(
                fontSize: 15,
                color: currentDate.isEmpty
                    ? const Color(0xFF9CA3AF)
                    : const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- LINEAR SCALE ---
  Widget _buildLinearScaleInput(Question question) {
    final settings = question.settings;
    final min = settings['scale_min'] ?? 1;
    final max = settings['scale_max'] ?? 5;
    final current = int.tryParse(_answers[question.id]?['answer_text'] ?? '') ?? -1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(settings['min_label'] ?? '$min', style: const TextStyle(fontSize: 12, color: Colors.black54)),
            Text(settings['max_label'] ?? '$max', style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: List.generate(max - min + 1, (i) {
            final val = min + i;
            final selected = current == val;
            return ChoiceChip(
              label: Text('$val'),
              selected: selected,
              onSelected: (_) => _updateAnswer(question.id, text: '$val'),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildRatingInput(Question question) {
    final count = (question.settings['rating_count'] as int?) ?? 5;
    final current = int.tryParse(_answers[question.id]?['answer_text'] ?? '') ?? 0;
    return Row(
      children: List.generate(count, (i) {
        final filled = i < current;
        return IconButton(icon: Icon(filled ? Icons.star : Icons.star_border, color: const Color(0xFFF59E0B)), onPressed: () => _updateAnswer(question.id, text: '${i + 1}'));
      }),
    );
  }

  Widget _buildGridInput(Question question) {
    final rowLabels = (question.settings['row_labels'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? ['Baris 1'];
    final isRadio = question.type == 'multiple_choice_grid';
    final selected = _answers[question.id]?['answer_options'] as List<dynamic>? ?? [];
    return Column(
      children: rowLabels.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(row, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: question.options.map((opt) {
                final isSel = selected.contains(opt.label);
                return FilterChip(label: Text(opt.label), selected: isSel, onSelected: (_) {
                  final cur = List<String>.from(selected.map((e) => e.toString()));
                  if (isRadio) { cur.clear(); cur.add(opt.label); } else { if (cur.contains(opt.label)) cur.remove(opt.label); else cur.add(opt.label); }
                  _updateAnswer(question.id, text: null, options: cur);
                });
              }).toList(),
            ),
          ]),
        );
      }).toList(),
    );
  }

  // --- FILE UPLOAD (placeholder) ---
  Widget _buildFileUploadInput(Question question) {
    final fileUrl = _answers[question.id]?['file_url'];

    return InkWell(
      onTap: () {
        // TODO: Implement file picker integration
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fitur upload file akan segera tersedia'),
          ),
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFFD1D5DB),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              fileUrl != null
                  ? Icons.check_circle
                  : Icons.cloud_upload_outlined,
              size: 40,
              color: fileUrl != null
                  ? const Color(0xFF059669)
                  : const Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 8),
            Text(
              fileUrl != null
                  ? 'File berhasil diupload'
                  : 'Tap untuk upload file',
              style: TextStyle(
                fontSize: 14,
                color: fileUrl != null
                    ? const Color(0xFF059669)
                    : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // NAVIGATION BUTTONS
  // ============================================================
  Widget _buildNavigationButtons() {
    final isFirstPage = _currentPage == 0;
    final isLastPage = _currentPage == _totalPages - 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Previous button
          if (!isFirstPage)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _currentPage--),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Sebelumnya'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF374151),
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),

          if (!isFirstPage && !isLastPage) const SizedBox(width: 12),

          // Next / Submit button
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isSubmitting
                  ? null
                  : () {
                      if (isLastPage) {
                        _showSubmitConfirmation();
                      } else {
                        setState(() => _currentPage++);
                      }
                    },
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(
                      isLastPage ? Icons.send : Icons.arrow_forward,
                      size: 18,
                    ),
              label: Text(
                _isSubmitting
                    ? 'Mengirim...'
                    : isLastPage
                    ? 'Submit'
                    : 'Selanjutnya',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isLastPage
                    ? const Color(0xFF059669)
                    : const Color(0xFF1E66D0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUBMIT CONFIRMATION DIALOG
  // ============================================================
  void _showSubmitConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.send, color: Color(0xFF059669)),
            SizedBox(width: 12),
            Text('Kirim Jawaban?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kamu telah menjawab $_answeredCount dari ${_formData?.questions.length ?? 0} pertanyaan.',
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 12),
            const Text(
              'Setelah dikirim, jawaban tidak bisa diubah lagi.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFFDC2626),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Batal',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _submitForm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Ya, Kirim!'),
          ),
        ],
      ),
    );
  }
}
