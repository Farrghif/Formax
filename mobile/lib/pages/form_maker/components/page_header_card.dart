import 'package:flutter/material.dart';
import '../models/form_builder_state.dart';
import '../../../widgets/rich_text_field.dart';
import '../../../widgets/rich_text_view.dart';

class PageHeaderCard extends StatelessWidget {
  final FormPageModel page;
  final bool isActive;
  final bool isFirstPage;
  final VoidCallback onTap;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  const PageHeaderCard({
    super.key,
    required this.page,
    required this.isActive,
    required this.isFirstPage,
    required this.onTap,
    required this.onChanged,
    required this.onDelete,
  });

  bool _looksLikeHtml(String s) => s.contains('<');

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isActive ? const Border(left: BorderSide(color: Color(0xFF4F46E5), width: 4)) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), 
              blurRadius: 10, 
              offset: const Offset(0, 4)
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 10,
              decoration: BoxDecoration(
                color: isFirstPage ? const Color(0xFF4F46E5) : const Color(0xFF8B5CF6),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isFirstPage) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Bagian Baru', style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                        if (isActive)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: onDelete,
                            tooltip: 'Hapus Bagian',
                          )
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  // --- Title Field ---
                  isActive
                      ? RichTextField(
                          initialHtml: page.title,
                          onChanged: (html) {
                            page.title = html;
                            onChanged();
                          },
                          hintText: isFirstPage ? 'Judul Formulir' : 'Judul Bagian',
                          minLines: 1,
                          maxLines: 3,
                        )
                      : _buildTitleView(),
                  const SizedBox(height: 16),
                  // --- Description Field ---
                  isActive
                      ? RichTextField(
                          initialHtml: page.description,
                          onChanged: (html) {
                            page.description = html;
                            onChanged();
                          },
                          hintText: 'Deskripsi',
                          minLines: 1,
                          maxLines: 3,
                        )
                      : _buildDescriptionView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleView() {
    final displayText = page.title.isEmpty
        ? (isFirstPage ? 'Judul Formulir' : 'Judul Bagian')
        : page.title;

    if (_looksLikeHtml(displayText)) {
      return RichTextView(
        html: displayText,
        textStyle: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
      );
    }
    return Text(
      displayText,
      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
    );
  }

  Widget _buildDescriptionView() {
    if (page.description.isEmpty) return const SizedBox.shrink();

    if (_looksLikeHtml(page.description)) {
      return RichTextView(
        html: page.description,
        textStyle: const TextStyle(fontSize: 15, color: Colors.black54),
      );
    }
    return Text(
      page.description,
      style: const TextStyle(fontSize: 15, color: Colors.black54),
    );
  }
}
