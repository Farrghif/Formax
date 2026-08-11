// lib/pages/detail_response_page.dart
// Halaman Detail Jawaban Individu — menampilkan informasi responden
// dan semua pertanyaan beserta jawabannya.

import 'package:flutter/material.dart';

class DetailResponsePage extends StatelessWidget {
  final String name;
  final String email;
  final String time;
  final bool isAuto;
  final String formTitle;
  /// List jawaban dari API atau mock: [{'question': '...', 'answer': '...'}]
  final List<Map<String, String>> answers;

  const DetailResponsePage({
    super.key,
    required this.name,
    required this.email,
    required this.time,
    required this.isAuto,
    required this.formTitle,
    this.answers = const [],
  });

  String _capitalizeWords(String text) {
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _capitalizeWords(name);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF374151)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Detail Respons',
          style: TextStyle(
            color: Color(0xFF2563EB),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Respondent info card
            _buildInfoCard(displayName),
            const SizedBox(height: 24),
            const Text(
              'JAWABAN',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6B7280),
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            if (answers.isEmpty)
              _buildEmptyAnswers()
            else
              ...answers.asMap().entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildAnswerCard(
                      entry.key + 1,
                      entry.value['question'] ?? '',
                      entry.value['answer'] ?? '',
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String displayName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFF1E40AF),
            child: Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            displayName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.access_time,
                  size: 15, color: Color(0xFF6B7280)),
              const SizedBox(width: 5),
              Text(time,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF374151))),
              const SizedBox(width: 14),
              _buildMethodChip(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMethodChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE0E7FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAuto ? Icons.smart_toy_outlined : Icons.person_outline,
            size: 13,
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

  Widget _buildAnswerCard(int number, String question, String answer) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(right: 8, top: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Text('$number',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E40AF))),
                  ),
                ),
                Expanded(
                  child: Text(
                    question,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Answer
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              answer,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF1F2937),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyAnswers() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      alignment: Alignment.center,
      child: const Column(
        children: [
          Icon(Icons.question_answer_outlined,
              size: 40, color: Colors.black12),
          SizedBox(height: 8),
          Text('Tidak ada jawaban tersimpan',
              style: TextStyle(fontSize: 13, color: Colors.black38)),
        ],
      ),
    );
  }
}
