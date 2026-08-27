import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../utils/quill_html.dart';

/// A polished rich text editor backed by an HTML string, using flutter_quill.
///
/// The [initialHtml] is parsed into a Quill document and [onChanged] emits the
/// current content as HTML (so it round-trips with the web builder, which
/// stores HTML).
///
/// Set [compact] to `true` for a slimmer toolbar that only exposes inline
/// formatting (bold, italic, underline, strikethrough, link). This is useful
/// for short fields such as option labels.
class RichTextField extends StatefulWidget {
  final String initialHtml;
  final ValueChanged<String> onChanged;
  final String? hintText;
  final int? minLines;
  final int? maxLines;

  /// When `true`, shows a compact toolbar with only inline-formatting buttons.
  final bool compact;

  const RichTextField({
    super.key,
    this.initialHtml = '',
    required this.onChanged,
    this.hintText,
    this.minLines = 2,
    this.maxLines,
    this.compact = false,
  });

  @override
  State<RichTextField> createState() => _RichTextFieldState();
}

class _RichTextFieldState extends State<RichTextField> {
  late final QuillController _controller;
  late final FocusNode _focusNode;
  late final ScrollController _scrollController;
  bool _showToolbar = false;

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
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _showToolbar) {
        setState(() => _showToolbar = false);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  QuillSimpleToolbarConfig _buildToolbarConfig() {
    if (widget.compact) {
      return const QuillSimpleToolbarConfig(
        showDividers: false,
        showFontFamily: false,
        showFontSize: false,
        showBoldButton: true,
        showItalicButton: true,
        showUnderLineButton: true,
        showStrikeThrough: false,
        showColorButton: false,
        showBackgroundColorButton: false,
        showClearFormat: false,
        showAlignmentButtons: false,
        showLeftAlignment: false,
        showCenterAlignment: false,
        showRightAlignment: false,
        showJustifyAlignment: false,
        showHeaderStyle: false,
        showListNumbers: false,
        showListBullets: false,
        showListCheck: false,
        showQuote: false,
        showLink: true,
        showUndo: false,
        showRedo: false,
        showSearchButton: false,
        showSubscript: false,
        showSuperscript: false,
        showCodeBlock: false,
        showInlineCode: false,
        showIndent: false,
        showDirection: false,
      );
    }

    return const QuillSimpleToolbarConfig(
      showDividers: true,
      showFontFamily: false,
      showFontSize: true,
      showBoldButton: true,
      showItalicButton: true,
      showUnderLineButton: true,
      showStrikeThrough: true,
      showColorButton: true,
      showBackgroundColorButton: false,
      showClearFormat: true,
      showAlignmentButtons: false,
      showLeftAlignment: true,
      showCenterAlignment: true,
      showRightAlignment: true,
      showJustifyAlignment: false,
      showHeaderStyle: true,
      showListNumbers: true,
      showListBullets: true,
      showListCheck: false,
      showQuote: false,
      showLink: true,
      showUndo: true,
      showRedo: true,
      showSearchButton: false,
      showSubscript: false,
      showSuperscript: false,
      showCodeBlock: false,
      showInlineCode: false,
      showIndent: false,
      showDirection: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = _controller.document.toPlainText().trim().isEmpty;
    final minH = (widget.minLines ?? 1) * 22.0 + 16;
    final maxH = (widget.maxLines ?? 6) * 22.0 + 16;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Editor area ──
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _focusNode.hasFocus
                  ? const Color(0xFF4F46E5)
                  : const Color(0xFFD1D5DB),
              width: _focusNode.hasFocus ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Toolbar (collapsible) ──
              if (_showToolbar) ...[
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF0F1F4),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: QuillSimpleToolbar(
                      controller: _controller,
                      config: _buildToolbarConfig(),
                    ),
                  ),
                ),
                const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
              ],

              // ── Quill editor area ──
              GestureDetector(
                onTap: () {
                  _focusNode.requestFocus();
                },
                child: Container(
                  constraints: BoxConstraints(minHeight: minH, maxHeight: maxH),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Stack(
                    children: [
                      if (isEmpty && widget.hintText != null)
                        Positioned(
                          top: 2,
                          left: 0,
                          right: 0,
                          child: IgnorePointer(
                            child: Text(
                              widget.hintText!,
                              style: const TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                      QuillEditor.basic(
                        controller: _controller,
                        focusNode: _focusNode,
                        scrollController: _scrollController,
                        config: QuillEditorConfig(
                          padding: EdgeInsets.zero,
                          expands: false,
                          autoFocus: false,
                          customStyles: DefaultStyles(
                            paragraph: DefaultTextBlockStyle(
                              const TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: Color(0xFF1F2937),
                              ),
                              HorizontalSpacing.zero,
                              VerticalSpacing.zero,
                              VerticalSpacing.zero,
                              null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Bottom bar with format toggle ──
              Container(
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Row(
                  children: [
                    _MiniIconButton(
                      icon: Icons.format_bold,
                      tooltip: 'Formatting',
                      isActive: _showToolbar,
                      onPressed: () {
                        setState(() => _showToolbar = !_showToolbar);
                        if (!_focusNode.hasFocus) _focusNode.requestFocus();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Small icon button used in the bottom bar of the editor.
class _MiniIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback onPressed;

  const _MiniIconButton({
    required this.icon,
    required this.tooltip,
    required this.isActive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF4F46E5).withValues(alpha: 0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              size: 18,
              color: isActive ? const Color(0xFF4F46E5) : const Color(0xFF6B7280),
            ),
          ),
        ),
      ),
    );
  }
}
