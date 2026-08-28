// lib/pages/result_page.dart
// Halaman Hasil Respons — menampilkan daftar semua responden suatu form.
// Menggunakan data nyata dari API /forms/{id}/submissions.

import 'package:flutter/material.dart';
import '../models/form_model.dart';
import '../services/api_service.dart';
import 'detail_response_page.dart';

class ResultPage extends StatefulWidget {
  final String formId;
  final String formTitle;

  const ResultPage({super.key, required this.formId, required this.formTitle});

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  late Future<List<SubmissionModel>> _submissionsFuture;

  @override
  void initState() {
    super.initState();
    _submissionsFuture = _fetchSubmissions();
  }

  Future<List<SubmissionModel>> _fetchSubmissions() async {
    final res = await ApiService.getFormSubmissions(widget.formId);
    if (res['success'] == true) {
      final rawList = res['data'] as List<dynamic>;
      return rawList
          .map((e) => SubmissionModel.fromJson(e as Map))
          .toList();
    }
    throw Exception(res['message'] ?? 'Gagal memuat respons');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF374151)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.formTitle,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const Text(
              'Hasil Respons',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
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
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Mengekspor ke spreadsheet...')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF6B7280)),
            onPressed: () =>
                setState(() => _submissionsFuture = _fetchSubmissions()),
          ),
        ],
      ),
      body: FutureBuilder<List<SubmissionModel>>(
        future: _submissionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }
          final submissions = snapshot.data ?? [];
          return _buildContent(submissions);
        },
      ),
    );
  }

  Widget _buildContent(List<SubmissionModel> submissions) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary card
          _buildSummaryCard(submissions.length),
          const SizedBox(height: 24),
          const Text(
            'Siapa yang Mengisi Ini',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          if (submissions.isEmpty)
            _buildEmptyState()
          else
            _buildRespondentList(submissions),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people, color: Color(0xFF1E40AF), size: 20),
              SizedBox(width: 8),
              Text(
                'Total Respons',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'responden',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  Widget _buildRespondentList(List<SubmissionModel> submissions) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: submissions.length,
        separatorBuilder: (context, index) => const Divider(
          height: 1,
          indent: 16,
          endIndent: 16,
          color: Color(0xFFF3F4F6),
        ),
        itemBuilder: (context, index) {
          final sub = submissions[index];
          return _buildRespondentTile(sub);
        },
      ),
    );
  }

  Widget _buildRespondentTile(SubmissionModel sub) {
    final initial = sub.respondentName.isNotEmpty
        ? sub.respondentName[0].toUpperCase()
        : '?';
    final timeStr = _formatTime(sub.submittedAt);

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
              formTitle: widget.formTitle,
              answers: sub.answers
                  .map((a) => {'question': a.questionLabel, 'answer': a.answer})
                  .toList(),
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
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeStr,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            _buildMethodChip(sub.isAutoSubmitted),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Colors.black26, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodChip(bool isAuto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE0E7FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAuto ? Icons.smart_toy_outlined : Icons.person_outline,
            size: 12,
            color: const Color(0xFF4F46E5),
          ),
          const SizedBox(width: 4),
          Text(
            isAuto ? 'Otomatis' : 'Manual',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF4F46E5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      alignment: Alignment.center,
      child: const Column(
        children: [
          Icon(Icons.inbox_outlined, size: 56, color: Colors.black12),
          SizedBox(height: 12),
          Text(
            'Belum ada respons',
            style: TextStyle(fontSize: 14, color: Colors.black38),
          ),
          Text(
            'Bagikan link form untuk mulai menerima jawaban.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.black26),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, size: 48, color: Colors.black26),
          const SizedBox(height: 12),
          const Text(
            'Tidak dapat memuat respons',
            style: TextStyle(fontSize: 14, color: Colors.black45),
          ),
          const SizedBox(height: 4),
          Text(
            error,
            style: const TextStyle(fontSize: 11, color: Colors.black26),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () =>
                setState(() => _submissionsFuture = _fetchSubmissions()),
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
