import 'package:flutter/material.dart';

class BuilderToolbar extends StatelessWidget {
  final VoidCallback onAddQuestion;
  final VoidCallback onAddPage;
  
  const BuilderToolbar({
    super.key,
    required this.onAddQuestion,
    required this.onAddPage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1), 
            blurRadius: 20, 
            offset: const Offset(0, 10)
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.black87),
            tooltip: 'Tambah Pertanyaan',
            onPressed: onAddQuestion,
          ),
          IconButton(
            icon: const Icon(Icons.text_fields, color: Colors.black87),
            tooltip: 'Tambah Teks/Deskripsi',
            onPressed: () {
              // Placeholder for add text feature
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fitur Tambah Teks segera hadir')));
            },
          ),
          IconButton(
            icon: const Icon(Icons.image_outlined, color: Colors.black87),
            tooltip: 'Tambah Gambar',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fitur Tambah Gambar segera hadir')));
            },
          ),
          IconButton(
            icon: const Icon(Icons.view_agenda_outlined, color: Colors.black87),
            tooltip: 'Tambah Bagian',
            onPressed: onAddPage,
          ),
        ],
      ),
    );
  }
}
