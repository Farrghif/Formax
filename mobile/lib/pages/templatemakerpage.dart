import 'package:flutter/material.dart';
import 'home_page.dart'; 

class TemplateMakerPage extends StatefulWidget {
  const TemplateMakerPage({super.key});

  @override
  State<TemplateMakerPage> createState() => _TemplateMakerPageState();
}

class _TemplateMakerPageState extends State<TemplateMakerPage> {
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
            _buildSetelanTab(),
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

  Widget _buildSetelanTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildQuizSettingsCard(),
          const SizedBox(height: 16),
          _buildResponseSettingsCard(),
          const SizedBox(height: 16),
          _buildDefaultSettingsCard(),
          const SizedBox(height: 16),
          _buildTimerSettingsCard(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildQuizSettingsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text("Jadikan ini sebagai kuis", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                    SizedBox(height: 4),
                    Text("Menetapkan pertanyaan dan nilai poin, serta menyediakan masukan secara otomatis", style: TextStyle(fontSize: 14, color: Colors.black54)),
                  ],
                ),
              ),
              Switch(value: true, onChanged: (v){}, activeColor: const Color(0xFF0F52BA)),
            ],
          ),
          const SizedBox(height: 24),
          const Text("RILIS NILAI", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(height: 12),
          _buildRadioOption(true, "Langsung setelah setiap pengiriman"),
          const SizedBox(height: 8),
          _buildRadioOptionWithSubtitle(false, "Nanti, setelah peninjauan manual", "Aktifkan Respons -> Kumpulkan alamat email"),
          const SizedBox(height: 24),
          const Text("SETELAN RESPONDEN", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(height: 12),
          _buildSwitchOption("Pertanyaan tak terjawab", true),
          const SizedBox(height: 12),
          _buildSwitchOption("Jawaban yang benar", true),
          const SizedBox(height: 12),
          _buildSwitchOption("Nilai poin", true),
          const SizedBox(height: 24),
          const Text("DEFAULT KUIS GLOBAL", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Nilai poin pertanyaan default", style: TextStyle(fontSize: 14)),
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 36,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black26),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    alignment: Alignment.center,
                    child: const Text("0", style: TextStyle(fontSize: 14)),
                  ),
                  const SizedBox(width: 8),
                  const Text("poin", style: TextStyle(fontSize: 14)),
                ],
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildRadioOption(bool isSelected, String text) {
    return Row(
      children: [
        Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: isSelected ? const Color(0xFF0F52BA) : Colors.black54),
        const SizedBox(width: 12),
        Text(text, style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  Widget _buildRadioOptionWithSubtitle(bool isSelected, String text, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: isSelected ? const Color(0xFF0F52BA) : Colors.black54),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildSwitchOption(String title, bool value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 14)),
        Switch(value: value, onChanged: (v){}, activeColor: const Color(0xFF0F52BA)),
      ],
    );
  }

  Widget _buildResponseSettingsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text("Jawaban", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              Icon(Icons.expand_less, color: Colors.black54),
            ],
          ),
          const SizedBox(height: 4),
          const Text("Mengelola cara respons dikumpulkan dan dilindungi", style: TextStyle(fontSize: 14, color: Colors.black54)),
          const SizedBox(height: 24),
          const Text("Mengirim salinan jawaban responden", style: TextStyle(fontSize: 14)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4FA),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text("Nonaktif", style: TextStyle(color: Color(0xFF4B5563))),
                SizedBox(width: 4),
                Icon(Icons.expand_more, color: Color(0xFF4B5563), size: 18),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text("Batasi ke 1 jawaban", style: TextStyle(fontSize: 14)),
                    SizedBox(height: 2),
                    Text("Responden akan diwajibkan untuk login", style: TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                ),
              ),
              Switch(value: true, onChanged: (v){}, activeColor: const Color(0xFF0F52BA)),
            ],
          ),
          const SizedBox(height: 16),
          _buildSwitchOption("Sembunyikan jawaban", false),
          const SizedBox(height: 16),
          _buildSwitchOption("Isi Form lebih dari 1 kali", false),
        ],
      ),
    );
  }

  Widget _buildDefaultSettingsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text("Default", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              Icon(Icons.expand_less, color: Colors.black54),
            ],
          ),
          const SizedBox(height: 16),
          const Text("Pertanyaan default", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          const Text("Setelan diterapkan untuk semua pertanyaan", style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text("Buat pertanyaan wajib diisi secara default", style: TextStyle(fontSize: 14)),
              ),
              Switch(value: false, onChanged: (v){}),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Timer", style: TextStyle(fontSize: 14)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text("Edit", style: TextStyle(color: Color(0xFF0F52BA), fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimerSettingsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.timer_outlined, color: Color(0xFF0F52BA)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text("Form Timer", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                    SizedBox(height: 2),
                    Text("Manage constraints and timing for this form", style: TextStyle(fontSize: 14, color: Colors.black54)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(height: 1, color: Colors.black12),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text("Enable Timer", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                  SizedBox(height: 2),
                  Text("Set a time limit for form completion", style: TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
              Switch(value: true, onChanged: (v){}, activeColor: const Color(0xFF2563EB)),
            ],
          ),
          const SizedBox(height: 24),
          const Text("Select Timer Mode", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Expanded(child: Text("Start when respondent opens the form", style: TextStyle(fontSize: 14, color: Colors.black87))),
                Icon(Icons.expand_more, color: Colors.black54),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text("Duration", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: const [
                Text("1 hari", style: TextStyle(fontSize: 16, color: Colors.black87)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.info_outline, color: Color(0xFF2563EB), size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text("The form will auto-submit and lock once the timer runs out. Respondents will see a countdown display at the top of the page.", style: TextStyle(fontSize: 12, color: Color(0xFF1D4ED8), height: 1.5)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("Save Settings", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () {},
              child: const Text("Discard Changes", style: TextStyle(fontSize: 16, color: Colors.black54)),
            ),
          ),
        ],
      ),
    );
  }
}
