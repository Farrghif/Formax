import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'home_page.dart'; 

class QuestionOptionData {
  String label;
  QuestionOptionData({required this.label});
}

class QuestionData {
  String type; // 'text', 'single_choice', 'checkbox', 'dropdown', 'date', 'file_upload'
  String label;
  bool isRequired;
  List<QuestionOptionData> options;

  QuestionData({
    required this.type,
    required this.label,
    this.isRequired = false,
    List<QuestionOptionData>? options,
  }) : options = options ?? [];
}

class TemplateMakerPage extends StatefulWidget {
  const TemplateMakerPage({super.key});

  @override
  State<TemplateMakerPage> createState() => _TemplateMakerPageState();
}

class _TemplateMakerPageState extends State<TemplateMakerPage> {
  final TextEditingController _titleController = TextEditingController(text: "Form Tanpa Judul");
  final TextEditingController _descController = TextEditingController();

  final List<QuestionData> _questions = [
    QuestionData(
      type: 'single_choice',
      label: 'Pertanyaan Tanpa Judul',
      options: [QuestionOptionData(label: 'Opsi 1')],
    )
  ];

  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _saveAndReturn() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    
    // Construct payload
    List<Map<String, dynamic>> questionPayload = [];
    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      List<Map<String, dynamic>> opts = [];
      for (int j = 0; j < q.options.length; j++) {
        opts.add({
          "label": q.options[j].label,
          "order_index": j,
        });
      }
      questionPayload.add({
        "type": q.type,
        "label": q.label,
        "is_required": q.isRequired,
        "order_index": i,
        "options": opts,
      });
    }

    final payload = {
      "title": _titleController.text.isNotEmpty ? _titleController.text : "Form Tanpa Judul",
      "description": _descController.text,
      "questions": questionPayload,
    };

    final res = await ApiService.createTemplate(payload);
    setState(() => _isSaving = false);

    if (res['success'] == true) {
      if (mounted) {
        Navigator.pop(
          context,
          FormTemplate(
            title: payload["title"] as String,
            subtitle: "Baru saja diperbarui",
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal menyimpan: ${res['message']}")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFE8F0FE), 
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
                onPressed: _isSaving ? null : _saveAndReturn,
                icon: _isSaving 
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save, size: 18),
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
          ..._questions.asMap().entries.map((entry) {
            int index = entry.key;
            QuestionData q = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: _buildDynamicQuestionCard(index, q),
            );
          }),
          const SizedBox(height: 80),
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
          top: BorderSide(color: Color(0xFF0F52BA), width: 8), 
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
              hintText: "Judul Formulir",
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descController,
            style: const TextStyle(fontSize: 14, color: Colors.black54),
            decoration: const InputDecoration(
              hintText: "Deskripsi formulir",
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            maxLines: null,
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicQuestionCard(int index, QuestionData q) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: Color(0xFF0F52BA), width: 4),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(child: Icon(Icons.drag_indicator, color: Colors.black26)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: TextEditingController(text: q.label)
                    ..selection = TextSelection.collapsed(offset: q.label.length),
                  onChanged: (val) => q.label = val,
                  decoration: InputDecoration(
                    hintText: "Pertanyaan",
                    filled: true,
                    fillColor: const Color(0xFFF3F4F6),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: q.type,
                      items: const [
                        DropdownMenuItem(value: 'text', child: Text("Teks")),
                        DropdownMenuItem(value: 'single_choice', child: Text("Pilihan Ganda")),
                        DropdownMenuItem(value: 'checkbox', child: Text("Kotak Centang")),
                        DropdownMenuItem(value: 'dropdown', child: Text("Dropdown")),
                        DropdownMenuItem(value: 'date', child: Text("Tanggal")),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            q.type = val;
                            if ((val == 'single_choice' || val == 'checkbox' || val == 'dropdown') && q.options.isEmpty) {
                              q.options.add(QuestionOptionData(label: 'Opsi 1'));
                            }
                          });
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (q.type == 'single_choice' || q.type == 'checkbox' || q.type == 'dropdown')
            ...q.options.asMap().entries.map((optEntry) {
              int optIndex = optEntry.key;
              QuestionOptionData opt = optEntry.value;
              IconData icon = Icons.radio_button_unchecked;
              if (q.type == 'checkbox') icon = Icons.check_box_outline_blank;
              if (q.type == 'dropdown') icon = Icons.format_list_numbered;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Icon(icon, color: Colors.black54),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: TextEditingController(text: opt.label)
                          ..selection = TextSelection.collapsed(offset: opt.label.length),
                        onChanged: (val) => opt.label = val,
                        decoration: const InputDecoration(
                          hintText: "Opsi",
                          border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black12)),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black54),
                      onPressed: () {
                        setState(() {
                          q.options.removeAt(optIndex);
                        });
                      },
                    )
                  ],
                ),
              );
            }),
          if (q.type == 'single_choice' || q.type == 'checkbox' || q.type == 'dropdown')
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Icon(
                    q.type == 'checkbox' ? Icons.check_box_outline_blank : Icons.radio_button_unchecked, 
                    color: Colors.black54
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () {
                      setState(() {
                        q.options.add(QuestionOptionData(label: 'Opsi ${q.options.length + 1}'));
                      });
                    },
                    child: const Text("Tambah opsi", style: TextStyle(color: Colors.black54)),
                  ),
                ],
              ),
            ),
          
          if (q.type == 'text')
            const TextField(
              enabled: false,
              decoration: InputDecoration(
                hintText: "Teks jawaban (Jawaban Singkat / Paragraf)",
                hintStyle: TextStyle(color: Colors.black26),
                border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black12)),
              ),
            ),
          if (q.type == 'date')
            const TextField(
              enabled: false,
              decoration: InputDecoration(
                hintText: "Bulan, hari, tahun",
                hintStyle: TextStyle(color: Colors.black26),
                border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black12)),
                suffixIcon: Icon(Icons.calendar_today, color: Colors.black26),
              ),
            ),
          
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.copy, color: Colors.black54),
                onPressed: () {
                  setState(() {
                    _questions.insert(index + 1, QuestionData(
                      type: q.type,
                      label: q.label,
                      isRequired: q.isRequired,
                      options: q.options.map((o) => QuestionOptionData(label: o.label)).toList(),
                    ));
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.black54),
                onPressed: () {
                  setState(() {
                    _questions.removeAt(index);
                  });
                },
              ),
              Container(width: 1, height: 20, color: Colors.black12),
              const SizedBox(width: 16),
              const Text("Wajib diisi", style: TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(width: 8),
              Switch(
                value: q.isRequired, 
                onChanged: (v) {
                  setState(() {
                    q.isRequired = v;
                  });
                }, 
                activeThumbColor: const Color(0xFF0F52BA)
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton(
      onPressed: () {
        setState(() {
          _questions.add(QuestionData(
            type: 'single_choice',
            label: 'Pertanyaan',
            options: [QuestionOptionData(label: 'Opsi 1')],
          ));
        });
      },
      backgroundColor: const Color(0xFF1E66D0),
      shape: const CircleBorder(),
      child: const Icon(Icons.add, color: Colors.white, size: 30),
    );
  }

  // --- SETELAN TAB ---
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
              Switch(value: true, onChanged: (v){}, activeThumbColor: const Color(0xFF0F52BA)),
            ],
          ),
          const SizedBox(height: 24),
          const Text("RILIS NILAI", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(height: 12),
          _buildRadioOption(true, "Langsung setelah setiap pengiriman"),
          const SizedBox(height: 8),
          _buildRadioOptionWithSubtitle(false, "Nanti, setelah peninjauan manual", "Aktifkan Respons -> Kumpulkan alamat email"),
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
        Switch(value: value, onChanged: (v){}, activeThumbColor: const Color(0xFF0F52BA)),
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
          const Text("Mengelola cara respons dikumpulkan", style: TextStyle(fontSize: 14, color: Colors.black54)),
          const SizedBox(height: 16),
          _buildSwitchOption("Batasi ke 1 jawaban", true),
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
          _buildSwitchOption("Buat pertanyaan wajib diisi secara default", false),
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
                    Text("Manage constraints and timing", style: TextStyle(fontSize: 14, color: Colors.black54)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
