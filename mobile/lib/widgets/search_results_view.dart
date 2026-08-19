import 'package:flutter/material.dart';
import '../models/form_model.dart';
import '../models/form_template.dart';
import '../pages/historypage.dart';
import '../pages/formmakerpage.dart';

class SearchResultsView extends StatelessWidget {
  final Map<String, dynamic> searchData;
  final VoidCallback onRefresh;

  const SearchResultsView({
    super.key,
    required this.searchData,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final List<dynamic> sysTemplatesRaw = searchData['system_templates'] ?? [];
    final List<dynamic> usrTemplatesRaw = searchData['user_templates'] ?? [];
    final List<dynamic> pubFormsRaw = searchData['published_forms'] ?? [];

    final systemTemplates = sysTemplatesRaw.map((e) => FormTemplate.fromJson(e)).toList();
    final userTemplates = usrTemplatesRaw.map((e) => FormTemplate.fromJson(e)).toList();
    final publishedForms = pubFormsRaw.map((e) => FormModel.fromJson(e)).toList();

    final hasTemplates = systemTemplates.isNotEmpty || userTemplates.isNotEmpty;
    final hasHistory = publishedForms.isNotEmpty;

    if (!hasTemplates && !hasHistory) {
      return _buildEmptyState();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasTemplates) ...[
            const Text(
              'Templates',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 12),
            if (systemTemplates.isNotEmpty) ...[
              ...systemTemplates.map((t) => _buildTemplateResult(context, t, true)),
            ],
            if (userTemplates.isNotEmpty) ...[
              ...userTemplates.map((t) => _buildTemplateResult(context, t, false)),
            ],
            const SizedBox(height: 24),
          ],
          if (hasHistory) ...[
            const Text(
              'Published Forms / History',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 12),
            ...publishedForms.map((f) => _buildFormResult(context, f)),
          ]
        ],
      ),
    );
  }

  Widget _buildTemplateResult(BuildContext context, FormTemplate template, bool isBuiltIn) {
    return InkWell(
      onTap: () async {
        final result = await Navigator.push<FormTemplate>(
          context,
          MaterialPageRoute(
            builder: (_) => const FormMakerPage(),
          ),
        );
        if (result != null) {
          onRefresh();
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isBuiltIn ? const Color(0xFFF3F4F6) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                isBuiltIn ? Icons.dashboard_customize_outlined : Icons.description_outlined,
                color: isBuiltIn ? const Color(0xFF4B5563) : const Color(0xFF1E40AF),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isBuiltIn ? 'Template Bawaan' : 'Template Saya',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black26),
          ],
        ),
      ),
    );
  }

  Widget _buildFormResult(BuildContext context, FormModel form) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Scaffold(
              backgroundColor: const Color(0xFFF9FAFB),
              appBar: AppBar(
                title: const Text(
                  'Detail Form',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                elevation: 0.5,
              ),
              body: HistoryPage(highlightFormId: form.id),
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.assignment_turned_in_outlined,
                color: Color(0xFF059669),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    form.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${form.totalSubmissions} responden',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black26),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(Icons.search_off, size: 64, color: Colors.black12),
          const SizedBox(height: 16),
          const Text(
            'Tidak ada template atau form yang ditemukan.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Coba gunakan kata kunci pencarian yang lain.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.black38),
          ),
        ],
      ),
    );
  }
}
