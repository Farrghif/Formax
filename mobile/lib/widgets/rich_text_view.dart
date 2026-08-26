import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

/// Renders an HTML string produced by [RichTextField] / the web builder.
///
/// Used in previews and the fill page so respondents see formatted text
/// instead of raw `<p>` / `<strong>` markup.
class RichTextView extends StatelessWidget {
  final String? html;
  final TextStyle? textStyle;
  final EdgeInsetsGeometry? padding;

  const RichTextView({
    super.key,
    required this.html,
    this.textStyle,
    this.padding,
  });

  static String stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&#39;', "'")
        .replaceAll('&quot;', '"')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final content = html?.trim() ?? '';
    if (content.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Html(
        data: content,
        style: {
          'body': Style(
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
            fontSize: FontSize.medium,
            color: textStyle?.color ?? Colors.black87,
          ),
          'p': Style(margin: Margins.only(bottom: 4)),
          'a': Style(color: const Color(0xFF4F46E5)),
        },
      ),
    );
  }
}
