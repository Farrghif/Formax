// lib/pages/result_page.dart
// Halaman Hasil Respons — menampilkan daftar semua responden suatu form.
// Menggunakan data nyata dari API /forms/{id}/submissions + /forms/{id}
// untuk menghitung skor client-side (parity dengan web).

import 'dart:math';

import 'package:flutter/material.dart';
import '../models/form_model.dart';
import '../services/api_service.dart';
import '../utils/export_helper.dart';
import 'detail_response_page.dart';

class ResultPage extends StatefulWidget {
  final String formId;
  final String formTitle;

  const ResultPage({super.key, required this.formId, required this.formTitle});

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  late Future<
      ({
        List<SubmissionModel> subs,
        Map<String, Set<String>> gradeMap,
        Map<String, String> labels,
      })> _dataFuture;

  String _statusFilter = 'semua'; // semua / selesai / proses / curang

  @override
  void initState() {
    super.initState();
    _dataFuture = _fetchData();
  }

  void _reload() {
    setState(() => _dataFuture = _fetchData());
  }

  Future<
      ({
        List<SubmissionModel> subs,
        Map<String, Set<String>> gradeMap,
        Map<String, String> labels,
      })> _fetchData() async {
    final subRes = await ApiService.getFormSubmissions(widget.formId);
    if (subRes['success'] != true) {
      throw Exception(subRes['message'] ?? 'Gagal memuat respons');
    }
    final subs = (subRes['data'] as List<dynamic>)
        .map((e) => SubmissionModel.fromJson(e as Map))
        .toList();

    // Ambil detail form untuk penilaian (opsi dengan is_correct) + label soal.
    final gradeMap = <String, Set<String>>{};
    final labels = <String, String>{};
    final formRes = await ApiService.getForm(widget.formId);
    if (formRes['success'] == true && formRes['data'] is Map) {
      final questions = (formRes['data'] as Map)['questions'] as List? ?? [];
      for (final raw in questions) {
        if (raw is! Map) continue;
        final qid = raw['id']?.toString() ?? '';
        if (qid.isEmpty) continue;
        final opts = raw['options'] as List? ?? [];
        final keys = opts
            .whereType<Map>()
            .where((o) => o['is_correct'] == true)
            .map((o) => o['label'].toString())
            .toSet();
        gradeMap[qid] = keys;
        labels[qid] = _cleanText(raw['label']?.toString() ?? '');
      }
    }
    return (subs: subs, gradeMap: gradeMap, labels: labels);
  }

  String _cleanText(String s) => s
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  // ── Penilaian (logika = backend/export.py) ──────────────────────────────
  bool _answerMatches(AnswerModel a, Set<String> keys) {
    final selected = (a.answerOptions != null && a.answerOptions!.isNotEmpty)
        ? a.answerOptions!.toSet()
        : (a.answerText != null && a.answerText!.isNotEmpty)
            ? {a.answerText!}
            : <String>{};
    return selected.length == keys.length && selected.containsAll(keys);
  }

  int? _scoreOf(SubmissionModel sub, Map<String, Set<String>> gradeMap) {
    final graded = gradeMap.entries.where((e) => e.value.isNotEmpty).toList();
    if (graded.isEmpty) return null;
    var correct = 0;
    for (final e in graded) {
      final a = sub.answersById[e.key];
      if (a == null) continue;
      if (_answerMatches(a, e.value)) correct++;
    }
    return (correct / graded.length * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.formTitle,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              'Hasil Respons',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.table_chart_outlined,
              color: Color(0xFF059669),
            ),
            tooltip: 'Export ke Spreadsheet',
            onPressed: () => exportFormSubmissionsWithShare(
              context,
              widget.formId,
              '${widget.formId}-hasil.xlsx',
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onPressed: _reload,
          ),
        ],
      ),
      body: FutureBuilder<
          ({
            List<SubmissionModel> subs,
            Map<String, Set<String>> gradeMap,
            Map<String, String> labels,
          })>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }
          final data = snapshot.data!;
          final submissions = data.subs
              .where((s) => _passFilter(s))
              .toList();
          return _buildContent(submissions, data.gradeMap, data.labels);
        },
      ),
    );
  }

  bool _passFilter(SubmissionModel s) {
    switch (_statusFilter) {
      case 'selesai':
        return s.submittedAt != null;
      case 'proses':
        return s.submittedAt == null;
      case 'curang':
        return s.isCheated;
      default:
        return true;
    }
  }

  Widget _buildContent(
    List<SubmissionModel> submissions,
    Map<String, Set<String>> gradeMap,
    Map<String, String> labels,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCard(submissions, gradeMap),
          const SizedBox(height: 20),
          _buildFilterRow(),
          const SizedBox(height: 20),
          Text(
            'Siapa yang Mengisi Ini',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          if (submissions.isEmpty)
            _buildEmptyState()
          else
            _buildRespondentList(submissions, gradeMap, labels),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    List<SubmissionModel> submissions,
    Map<String, Set<String>> gradeMap,
  ) {
    final scores = submissions.map((s) => _scoreOf(s, gradeMap)).whereType<int>().toList();
    final highest = scores.isEmpty ? null : scores.reduce(max);
    final lowest = scores.isEmpty ? null : scores.reduce(min);
    final hasGrades = highest != null;

    Widget stat(String label, String value) {
      return Expanded(
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          stat('Total Respons', '${submissions.length}'),
          if (hasGrades) ...[
            const _VDivider(),
            stat('Nilai Tertinggi', '$highest/100'),
          ],
          if (hasGrades) ...[
            const _VDivider(),
            stat('Nilai Terendah', '$lowest/100'),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    Widget chip(String label, String value) {
      final selected = _statusFilter == value;
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        labelStyle: TextStyle(
          fontSize: 12,
          color: selected
              ? Colors.white
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        selectedColor: const Color(0xFF059669),
        backgroundColor: Theme.of(context).colorScheme.surface,
        side: BorderSide(
          color: selected
              ? const Color(0xFF059669)
              : Theme.of(context).colorScheme.outlineVariant,
        ),
        onSelected: (_) => setState(() => _statusFilter = value),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip('Semua Status', 'semua'),
        chip('Selesai', 'selesai'),
        chip('Proses', 'proses'),
        chip('Curang', 'curang'),
      ],
    );
  }

  Widget _buildRespondentList(
    List<SubmissionModel> submissions,
    Map<String, Set<String>> gradeMap,
    Map<String, String> labels,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: submissions.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          indent: 16,
          endIndent: 16,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        itemBuilder: (context, index) {
          final sub = submissions[index];
          return _buildRespondentTile(sub, gradeMap, labels);
        },
      ),
    );
  }

  Widget _buildRespondentTile(
    SubmissionModel sub,
    Map<String, Set<String>> gradeMap,
    Map<String, String> labels,
  ) {
    final initial = sub.respondentName.isNotEmpty
        ? sub.respondentName[0].toUpperCase()
        : '?';
    final timeStr = sub.submittedAt != null
        ? _formatTime(sub.submittedAt!)
        : 'Belum dikirim';
    final score = _scoreOf(sub, gradeMap);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetailResponsePage(
              name: sub.respondentName,
              email: sub.respondentEmail,
              time: timeStr,
              isAuto: sub.isAutoSubmitted,
              isCheated: sub.isCheated,
              scoreText: score != null ? '$score/100' : null,
              formTitle: widget.formTitle,
              answers: _buildAnswerDetails(sub, gradeMap, labels),
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF1E40AF),
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sub.respondentName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub.respondentEmail == '-'
                        ? 'Anonim'
                        : sub.respondentEmail,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub.isAutoSubmitted ? '$timeStr • dikirim otomatis' : timeStr,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildStatusPill(sub),
            const SizedBox(width: 8),
            if (score != null)
              Text(
                '$score/100',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: score >= 70
                      ? const Color(0xFF059669)
                      : (score >= 40
                          ? const Color(0xFFD97706)
                          : const Color(0xFFDC2626)),
                ),
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: Colors.black26, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill(SubmissionModel sub) {
    final (String label, Color color, Color bg) = sub.isCheated
        ? ('Curang', const Color(0xFFDC2626), const Color(0xFFFEE2E2))
        : sub.submittedAt != null
            ? ('Selesai', const Color(0xFF059669), const Color(0xFFD1FAE5))
            : ('Proses', const Color(0xFFD97706), const Color(0xFFFEF3C7));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 7, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _buildAnswerDetails(
    SubmissionModel sub,
    Map<String, Set<String>> gradeMap,
    Map<String, String> labels,
  ) {
    return sub.answers.map((a) {
      final keys = gradeMap[a.questionId];
      final graded = keys != null && keys.isNotEmpty;
      bool? isCorrect;
      if (graded) isCorrect = _answerMatches(a, keys);
      return {
        'question': (labels[a.questionId]?.isNotEmpty ?? false)
            ? labels[a.questionId]
            : a.questionLabel,
        'answer': _cleanText(a.display),
        'isCorrect': isCorrect,
        'correctAnswer': (graded && keys.isNotEmpty) ? _cleanText(keys.join(', ')) : null,
        'fileUrl': a.fileUrl,
      };
    }).toList();
  }

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 56, color: colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            _statusFilter == 'semua'
                ? 'Belum ada respons'
                : 'Tidak ada respons dengan status ini',
            style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
          ),
          Text(
            'Bagikan link form untuk mulai menerima jawaban.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 48, color: colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            'Tidak dapat memuat respons',
            style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            error,
            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _reload,
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays == 1) return 'Kemarin';
    return '${dt.day}/${dt.month}/${dt.year}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _VDivider extends StatelessWidget {
  const _VDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}