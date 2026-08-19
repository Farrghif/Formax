import 'package:flutter/material.dart';
import '../../../models/question_model.dart';
import 'question_editor.dart';
import 'question_viewer.dart';

class QuestionCard extends StatelessWidget {
  final int index;
  final QuestionData question;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final ValueChanged<bool> onRequiredChanged;
  final VoidCallback onChanged;
  final VoidCallback onTypeChangeTap;

  const QuestionCard({
    super.key,
    required this.index,
    required this.question,
    required this.isActive,
    required this.onTap,
    required this.onDuplicate,
    required this.onDelete,
    required this.onRequiredChanged,
    required this.onChanged,
    required this.onTypeChangeTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isActive ? const Border(left: BorderSide(color: Color(0xFF4F46E5), width: 4)) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isActive ? 0.08 : 0.03),
              blurRadius: isActive ? 12 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            if (isActive)
              Center(
                child: ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.only(bottom: 12.0),
                    child: Icon(Icons.drag_indicator, size: 20, color: Colors.black26),
                  ),
                ),
              ),
            isActive
                ? QuestionEditor(
                    question: question,
                    onChanged: onChanged,
                    onTypeChangeTap: onTypeChangeTap,
                  )
                : QuestionViewer(question: question),
            
            // Footer Toolbar when active
            if (isActive) ...[
              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy_outlined, color: Colors.black54, size: 22),
                    tooltip: 'Duplikat',
                    onPressed: onDuplicate,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.black54, size: 22),
                    tooltip: 'Hapus',
                    onPressed: onDelete,
                  ),
                  if (question.type != QuestionType.image && question.type != QuestionType.text) ...[
                    Container(
                      height: 24, 
                      width: 1, 
                      color: Colors.black12, 
                      margin: const EdgeInsets.symmetric(horizontal: 8)
                    ),
                    const Text('Wajib', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87)),
                    Switch(
                      value: question.isRequired,
                      onChanged: onRequiredChanged,
                      activeThumbColor: const Color(0xFF4F46E5),
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert, color: Colors.black54),
                      onPressed: () {},
                    ),
                  ]
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }
}
