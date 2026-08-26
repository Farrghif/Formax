// lib/pages/historypage.dart
// Halaman History — menampilkan daftar form yang sudah dipublikasikan
// beserta jumlah responden, menggunakan data nyata dari API.

import 'package:flutter/material.dart';
import '../models/form_model.dart';
import '../services/api_service.dart';
import 'result_page.dart';

class HistoryPage extends StatefulWidget {
  /// Jika diisi, akan di-highlight form dengan ID tersebut (dari Dashboard).
  final String? highlightFormId;

  const HistoryPage({super.key, this.highlightFormId});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late Future<List<FormModel>> _formsFuture;

  @override
  void initState() {
    super.initState();
    _formsFuture = _fetchForms();
  }

  Future<List<FormModel>> _fetchForms() async {
    final res = await ApiService.getMyForms();
    if (res['success'] == true) {
      final rawList = res['data'] as List<dynamic>;
      final forms = rawList
          .map((e) => FormModel.fromJson(e as Map<String, dynamic>))
          .toList();
      forms.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return forms;
    }
    throw Exception(res['message'] ?? 'Gagal memuat data');
  }

  void _refresh() {
    setState(() => _formsFuture = _fetchForms());
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: FutureBuilder<List<FormModel>>(
        future: _formsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }
          final forms = snapshot.data ?? [];
          if (forms.isEmpty) {
            return _buildEmptyState();
          }
          return _buildList(forms);
        },
      ),
    );
  }

  Widget _buildList(List<FormModel> forms) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'History',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Lihat hasil jawaban formulir yang sudah dipublikasikan.',
          style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 20),
        ...forms.map(
          (form) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _buildHistoryCard(form),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(FormModel form) {
    final isHighlighted = form.id == widget.highlightFormId;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted
              ? const Color(0xFFB4C5D4)
              : const Color(0xFFE5E7EB),
          width: isHighlighted ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Thumbnail area
          Container(
            height: 100,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11),
              ),
            ),
            child: Stack(
              children: [
                const Center(
                  child: Icon(
                    Icons.description_outlined,
                    size: 40,
                    color: Colors.white38,
                  ),
                ),
                if (isHighlighted)
                  const Positioned(
                    top: 8,
                    right: 8,
                    child: Chip(
                      label: Text(
                        'Baru!',
                        style: TextStyle(fontSize: 11, color: Colors.white),
                      ),
                      backgroundColor: Color(0xFF059669),
                      padding: EdgeInsets.zero,
                    ),
                  ),
              ],
            ),
          ),
          // Content area
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  form.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.people_outline,
                      size: 14,
                      color: Color(0xFF6B7280),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${form.totalSubmissions} responden',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: Color(0xFF6B7280),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(form.createdAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Export button
                    OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Mengekspor ke spreadsheet...'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.table_chart_outlined, size: 14),
                      label: const Text('Export'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF059669),
                        side: const BorderSide(color: Color(0xFF059669)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Lihat Hasil button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ResultPage(
                                formId: form.id,
                                formTitle: form.title,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.visibility_outlined, size: 14),
                        label: const Text('Lihat Hasil'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E40AF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          textStyle: const TextStyle(fontSize: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 40),
        const Center(
          child: Icon(
            Icons.history_toggle_off,
            size: 72,
            color: Colors.black12,
          ),
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'Belum ada formulir',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black38,
            ),
          ),
        ),
        const Center(
          child: Text(
            'Publikasikan formulir dari tab Template\nuntuk melihatnya di sini.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.black26),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, size: 48, color: Colors.black26),
          const SizedBox(height: 12),
          const Text(
            'Tidak dapat memuat data',
            style: TextStyle(fontSize: 15, color: Colors.black45),
          ),
          const SizedBox(height: 4),
          Text(
            error,
            style: const TextStyle(fontSize: 12, color: Colors.black26),
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _refresh, child: const Text('Coba Lagi')),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Hari ini';
    if (diff.inDays == 1) return 'Kemarin';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
