import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../utils/quill_html.dart';

/// A Summernote/Quill-style rich text editor backed by an HTML string.
///
/// The [initialHtml] is parsed into a Quill document and [onChanged] emits the
/// current content as HTML (so it round-trips with the web builder, which
/// stores HTML).
class RichTextField extends StatefulWidget {
  final String initialHtml;
  final ValueChanged<String> onChanged;
  final String? hintText;
  final int? minLines;
  final int? maxLines;

  const RichTextField({
    super.key,
    this.initialHtml = '',
    required this.onChanged,
    this.hintText,
    this.minLines = 2,
    this.maxLines,
  });

  @override
  State<RichTextField> createState() => _RichTextFieldState();
}

class _RichTextFieldState extends State<RichTextField> {
  late final QuillController _controller;
  late final FocusNode _focusNode;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _scrollController = ScrollController();
    _controller = QuillController(
      document: QuillHtml.documentFromHtml(widget.initialHtml),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _controller.document.changes.listen((_) {
      final html = QuillHtml.documentToHtml(_controller.document);
      widget.onChanged(html);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = _controller.document.toPlainText().trim().isEmpty;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          QuillSimpleToolbar(
            controller: _controller,
            config: const QuillSimpleToolbarConfig(
              showDividers: true,
              showFontFamily: true,
              showFontSize: true,
              showBoldButton: true,
              showItalicButton: true,
              showUnderLineButton: true,
              showStrikeThrough: true,
              showColorButton: true,
              showBackgroundColorButton: true,
              showClearFormat: true,
              showAlignmentButtons: true,
              showLeftAlignment: true,
              showCenterAlignment: true,
              showRightAlignment: true,
              showJustifyAlignment: true,
              showHeaderStyle: true,
              showListNumbers: true,
              showListBullets: true,
              showListCheck: true,
              showQuote: true,
              showLink: true,
              showUndo: true,
              showRedo: true,
            ),
          ),
          Divider(height: 1, color: Colors.black12),
          Container(
            constraints: BoxConstraints(
              minHeight: (widget.minLines ?? 2) * 20.0 + 24,
              maxHeight: (widget.maxLines ?? 8) * 20.0 + 24,
            ),
            padding: const EdgeInsets.all(12),
            child: Stack(
              children: [
                if (isEmpty && widget.hintText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 2),
                    child: Text(
                      widget.hintText!,
                      style: const TextStyle(color: Colors.black38, fontSize: 14),
                    ),
                  ),
                QuillEditor.basic(
                  controller: _controller,
                  focusNode: _focusNode,
                  scrollController: _scrollController,
                  config: const QuillEditorConfig(
                    padding: EdgeInsets.zero,
                    expands: false,
                    autoFocus: false,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
