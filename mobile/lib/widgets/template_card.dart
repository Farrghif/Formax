import 'package:flutter/material.dart';
import '../models/form_template.dart';
import '../pages/formmakerpage.dart';

class TemplateCard extends StatelessWidget {
  final FormTemplate template;
  final bool isBuiltIn;

  const TemplateCard({
    super.key,
    required this.template,
    this.isBuiltIn = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FormMakerPage(initialTemplate: template),
          ),
        );
      },
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail Area
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCE4FB), // Light blue background
                  borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
                ),
                child: const Center(
                  child: Icon(
                    Icons.assignment_outlined,
                    size: 40,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ),
            // Text Area
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.plainTitle.isNotEmpty ? template.plainTitle : template.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    template.plainSubtitle.isNotEmpty ? template.plainSubtitle : (template.subtitle.isEmpty ? (template.questionsJson?.length ?? 0).toString() + ' pertanyaan' : template.subtitle),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
