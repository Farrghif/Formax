import 'package:flutter/material.dart';
import '../models/form_builder_state.dart';

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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? const Color(0xFF4F46E5) : Colors.transparent, 
            width: 2
          ),
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
                  isActive
                      ? TextField(
                          controller: TextEditingController(text: page.title)..selection = TextSelection.collapsed(offset: page.title.length),
                          onChanged: (v) { page.title = v; onChanged(); },
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
                          decoration: InputDecoration(
                            hintText: isFirstPage ? 'Judul Formulir' : 'Judul Bagian',
                            border: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.transparent)),
                            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF4F46E5))),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          maxLines: null,
                        )
                      : Text(
                          page.title.isEmpty ? (isFirstPage ? 'Judul Formulir' : 'Judul Bagian') : page.title,
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                  const SizedBox(height: 16),
                  isActive
                      ? TextField(
                          controller: TextEditingController(text: page.description)..selection = TextSelection.collapsed(offset: page.description.length),
                          onChanged: (v) { page.description = v; onChanged(); },
                          style: const TextStyle(fontSize: 15, color: Colors.black54),
                          decoration: const InputDecoration(
                            hintText: 'Deskripsi',
                            border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.transparent)),
                            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF4F46E5))),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                          maxLines: null,
                        )
                      : (page.description.isNotEmpty 
                          ? Text(page.description, style: const TextStyle(fontSize: 15, color: Colors.black54))
                          : (isActive ? const SizedBox() : Container())),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
