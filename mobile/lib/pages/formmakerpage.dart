import 'package:flutter/material.dart';
import 'home_page.dart'; 

class FormMakerPage extends StatefulWidget {
  const FormMakerPage({super.key});

  @override
  State<FormMakerPage> createState() => _FormMakerPageState();
}

class _FormMakerPageState extends State<FormMakerPage> {
  final TextEditingController _titleController = TextEditingController(text: "Ujian Tengah Semester");

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _saveAndReturn() {
    Navigator.pop(
      context,
      FormTemplate(
        title: _titleController.text.isNotEmpty ? _titleController.text : "Untitled Form",
        subtitle: "Updated just now",
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFE8F0FE), // Light blue background
        appBar: AppBar(
          backgroundColor: const Color(0xFFE8F0FE),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.all(12),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0, top: 8.0, bottom: 8.0),
              child: ElevatedButton.icon(
                onPressed: _saveAndReturn,
                icon: const Icon(Icons.save, size: 18),
                label: const Text("Simpan"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F52BA),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                ),
              ),
            ),
          ],
          bottom: const TabBar(
            labelColor: Color(0xFF0F52BA),
            unselectedLabelColor: Colors.black54,
            indicatorColor: Color(0xFF0F52BA),
            indicatorWeight: 3,
            tabs: [
              Tab(text: "Soal"),
              Tab(text: "Setelan"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildSoalTab(),
            const Center(child: Text("Setelan Page")),
          ],
        ),
        floatingActionButton: _buildFAB(),
      ),
    );
  }

  Widget _buildSoalTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildTitleCard(),
          const SizedBox(height: 16),
          _buildMultipleChoiceCard(),
          const SizedBox(height: 16),
          _buildRequiredMultipleChoiceCard(),
          const SizedBox(height: 16),
          _buildShortAnswerCard(),
          const SizedBox(height: 16),
          _buildParagraphCard(),
          const SizedBox(height: 80), // padding for FAB
        ],
      ),
    );
  }

  Widget _buildTitleCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          top: BorderSide(color: Color(0xFF0F52BA), width: 8), // Blue top bar
        ),
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _titleController,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "Evaluasi materi pertemuan 1-7 mata pelajaran Geografi.",
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildMultipleChoiceCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: Color(0xFF0F52BA), width: 4), // Active blue left bar
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(child: Icon(Icons.drag_indicator, color: Colors.black26)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text("Ibu kota Indonesia adalah?", style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: const [
                Icon(Icons.radio_button_checked, color: Color(0xFF0F52BA)),
                SizedBox(width: 12),
                Text("Pilihan Ganda"),
                Spacer(),
                Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildOption(Icons.radio_button_unchecked, "Jakarta"),
          _buildOption(Icons.radio_button_unchecked, "Bandung"),
          _buildOption(Icons.radio_button_unchecked, "Surabaya"),
          _buildOption(Icons.radio_button_unchecked, "Medan"),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: const [
                Icon(Icons.radio_button_unchecked, color: Colors.black54),
                SizedBox(width: 12),
                Text("Tambah opsi ", style: TextStyle(color: Colors.black54)),
                Text("atau tambahkan \"Lainnya\"", style: TextStyle(color: Color(0xFF0F52BA), fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Icon(Icons.copy, color: Colors.black54),
              const SizedBox(width: 16),
              const Icon(Icons.delete_outline, color: Colors.black54),
              const SizedBox(width: 16),
              Container(width: 1, height: 20, color: Colors.black12),
              const SizedBox(width: 16),
              const Text("Wajib diisi", style: TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(width: 8),
              Switch(value: true, onChanged: (v) {}, activeColor: const Color(0xFF0F52BA)),
              const SizedBox(width: 8),
              const Icon(Icons.more_vert, color: Colors.black54),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildRequiredMultipleChoiceCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: const TextSpan(
              text: "Berapa jumlah provinsi di Indonesia saat ini? ",
              style: TextStyle(fontSize: 16, color: Colors.black87),
              children: [
                TextSpan(text: "*", style: TextStyle(color: Colors.red)),
              ]
            ),
          ),
          const SizedBox(height: 16),
          _buildOption(Icons.radio_button_unchecked, "34"),
          _buildOption(Icons.radio_button_unchecked, "36"),
          _buildOption(Icons.radio_button_unchecked, "37"),
          _buildOption(Icons.radio_button_unchecked, "38"),
          const SizedBox(height: 16),
          const Text("* Wajib diisi", style: TextStyle(color: Colors.red, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildShortAnswerCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Jelaskan secara singkat mengenai letak astronomis Indonesia dan dampaknya terhadap iklim.", style: TextStyle(fontSize: 16, color: Colors.black87)),
          const SizedBox(height: 16),
          const TextField(
            enabled: false,
            decoration: InputDecoration(
              hintText: "Ketik jawaban Anda di sini...",
              hintStyle: TextStyle(color: Colors.black26),
              border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParagraphCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Menurut pendapat Anda, apa tantangan terbesar dalam pembangunan infrastruktur di daerah terpencil?", style: TextStyle(fontSize: 16, color: Colors.black87)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Align(
              alignment: Alignment.topLeft,
              child: Text("Jawaban teks panjang...", style: TextStyle(color: Colors.black26)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.black54),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildFabItem(Icons.text_fields),
        const SizedBox(height: 12),
        _buildFabItem(Icons.image_outlined),
        const SizedBox(height: 12),
        _buildFabItem(Icons.videocam_outlined),
        const SizedBox(height: 12),
        _buildFabItem(Icons.view_agenda_outlined),
        const SizedBox(height: 16),
        FloatingActionButton(
          onPressed: () {},
          backgroundColor: const Color(0xFF1E66D0),
          shape: const CircleBorder(),
          child: const Icon(Icons.add, color: Colors.white, size: 30),
        ),
      ],
    );
  }

  Widget _buildFabItem(IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.black54, size: 20),
    );
  }
}
