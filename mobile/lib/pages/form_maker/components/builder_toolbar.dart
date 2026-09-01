import 'package:flutter/material.dart';

class BuilderToolbar extends StatelessWidget {
  final VoidCallback onAddText;
  final VoidCallback onAddImage;
  
  const BuilderToolbar({
    super.key,
    required this.onAddText,
    required this.onAddImage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1), 
            blurRadius: 10, 
            offset: const Offset(0, 5)
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.text_fields, color: Colors.black87),
            tooltip: 'Tambah Judul/Teks',
            onPressed: onAddText,
          ),
          IconButton(
            icon: Icon(Icons.image_outlined, color: Colors.black87),
            tooltip: 'Tambah Gambar',
            onPressed: onAddImage,
          ),
        ],
      ),
    );
  }
}
