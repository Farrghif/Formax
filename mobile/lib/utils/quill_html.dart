import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';

/// Self-contained bridge between HTML (used by the web app / backend, e.g.
/// Quill's `<p>`, `<strong>`, `<em>`...) and a Quill [Document].
///
/// HTML -> Delta is delegated to the official `flutter_quill_delta_from_html`
/// package (transitive dep of flutter_quill 11). Delta -> HTML is a small
/// local writer so the mobile editor stays compatible with the HTML stored by
/// the web builder.
class QuillHtml {
  const QuillHtml._();

  /// Build a Quill [Document] from an HTML string (may be plain text).
  /// Falls back to a single plaintext line when parsing fails.
  static Document documentFromHtml(String? html) {
    if (html == null || html.trim().isEmpty) return Document();
    try {
      final delta = HtmlToDelta().convert(html);
      return Document.fromJson(delta.toJson());
    } catch (_) {
      return Document()..insert(0, html);
    }
  }

  /// Serialize a Quill [Document] back to an HTML string (round-trips with web).
  static String documentToHtml(Document doc) => deltaToHtml(doc.toDelta());

  /// Convert a Quill [Delta] to an HTML string.
  static String deltaToHtml(dynamic delta) {
    final out = StringBuffer();
    final inline = StringBuffer(); // accumulated inline html for the current line
    String? blockTag; // 'h1' | 'h2' | 'h3' | 'blockquote' | null
    String? listTag; // 'ul' | 'ol' | null
    final listItems = <String>[];

    String inlineStyle(Map<String, dynamic> a) {
      final s = <String>[];
      if (a['bold'] == true) s.add('font-weight: bold;');
      if (a['italic'] == true) s.add('font-style: italic;');
      if (a['underline'] == true) s.add('text-decoration: underline;');
      if (a['strike'] == true) s.add('text-decoration: line-through;');
      if (a['color'] != null) s.add('color: ${a['color']};');
      return s.isEmpty ? '' : s.join(' ');
    }

    void flushInline({required bool closeBlock}) {
      if (inline.isNotEmpty) {
        if (listTag != null) {
          listItems.add(inline.toString());
        } else if (blockTag != null) {
          out.write('$inline</$blockTag>');
        } else {
          out.write('<p>$inline</p>');
        }
        inline.clear();
      }
      if (closeBlock && listTag != null && listItems.isNotEmpty) {
        out.write('<$listTag>');
        for (final it in listItems) {
          out.write('<li>$it</li>');
        }
        out.write('</$listTag>');
        listItems.clear();
        listTag = null;
      }
    }

    for (final op in delta.operations) {
      if (!op.isInsert) continue;
      final data = op.data;
      final attrs = (op.attributes ?? const <String, dynamic>{}) as Map<String, dynamic>;

      if (data == '\n') {
        final block = attrs['block'] as String?;
        if (block == 'ul' || block == 'ol') {
          listTag = block;
          flushInline(closeBlock: false);
        } else if (block == 'blockquote') {
          flushInline(closeBlock: true);
          blockTag = 'blockquote';
          inline.write('<blockquote>');
        } else if (block != null && block.startsWith('header.')) {
          flushInline(closeBlock: true);
          blockTag = 'h${block.split('.').last}';
          inline.write('<$blockTag>');
        } else if (block == 'code-block') {
          flushInline(closeBlock: true);
          out.write('<pre>$inline</pre>');
          inline.clear();
        } else {
          flushInline(closeBlock: true);
          blockTag = null;
        }
        continue;
      }

      final text = _escape(data.toString());
      final link = attrs['link'] as String?;
      final style = inlineStyle(attrs);

      // List-item markers (e.g. "1." from ordered lists) come through as
      // attributes with no useful styling for raw HTML — ignore them.
      if (attrs.containsKey('list')) continue;

      if (link != null) {
        inline.write('<a href="$link">$text</a>');
      } else if (style.isNotEmpty) {
        inline.write('<span style="$style">$text</span>');
      } else {
        inline.write(text);
      }
    }

    flushInline(closeBlock: true);
    final result = out.toString();
    return result.isEmpty ? '<p><br></p>' : result;
  }

  static String _escape(String text) =>
      text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

  /// Strip HTML tags untuk field yang harus plain text (mis. title template).
  /// "<p>hhhh\n</p>" -> "hhhh"
  static String htmlToPlainText(String? html) {
    if (html == null || html.trim().isEmpty) return '';
    // Gunakan documentToPlain via delta parsing agar lebih akurat
    try {
      final doc = documentFromHtml(html);
      final plain = doc.toPlainText().trim();
      // toPlainText biasanya ada trailing \n
      return plain.replaceAll(RegExp(r'\n+'), ' ').trim();
    } catch (_) {
      // fallback regex strip
      return html
          .replaceAll(RegExp(r'<[^>]*>'), ' ')
          .replaceAll('&nbsp;', ' ')
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }
  }

  /// Alias untuk kasus title — jaga agar tidak kosong
  static String titleToPlain(String? html, {String fallback = 'Form Tanpa Judul'}) {
    final plain = htmlToPlainText(html);
    return plain.isEmpty ? fallback : plain;
  }
}
