import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:form4xandroid/utils/quill_html.dart';

void main() {
  test('HtmlToDelta parses common formatting', () {
    const html = '<p>Hello <strong>bold</strong> and <em>italic</em></p>'
        '<ul><li>one</li><li>two</li></ul>'
        '<h1>Title</h1>';
    final converter = HtmlToDelta();
    final delta = converter.convert(html);
    final doc = Document.fromJson(delta.toJson());
    expect(doc.toPlainText(), contains('Hello'));
    expect(doc.toPlainText(), contains('bold'));
    expect(doc.toPlainText(), contains('Title'));
  });

  test('QuillHtml.documentFromHtml round-trips with web html', () {
    const html = '<p>Hi <strong>there</strong></p>';
    final doc = QuillHtml.documentFromHtml(html);
    expect(doc.toPlainText(), contains('there'));
  });

  test('QuillHtml.documentToHtml produces html', () {
    // Build a delta with a bold span directly (Document.insert requires a
    // positional index, so we compose the delta via JSON instead).
    final deltaJson = [
      {'insert': 'Hello '},
      {'insert': 'world', 'attributes': {'bold': true}},
      {'insert': '\n'},
    ];
    final doc = Document.fromJson(deltaJson);
    final html = QuillHtml.documentToHtml(doc);
    expect(html, contains('Hello'));
    expect(html, contains('world'));
    expect(html.toLowerCase(), contains('bold'));
  });

  Set<dynamic> attrKeys(dynamic rt) {
    return rt
        .where((op) => op['insert'] is String && op['attributes'] is Map)
        .expand((op) => (op['attributes'] as Map).keys)
        .toSet();
  }

  test('all text-editor formatting survives the full HTML round-trip', () {
    // A single paragraph formatted with every inline attribute supported by
    // the text editor, plus block-level center alignment on its newline.
    final deltaJson = [
      {
        'insert': 'Hello ',
        'attributes': {
          'bold': true,
          'italic': true,
          'underline': true,
          'strike': true,
          'color': '#ff0000',
          'background': '#ffff00',
          'size': 'large',
          'font': 'Arial',
          'line-height': 1.5,
        }
      },
      {'insert': 'world'},
      {'insert': '\n', 'attributes': {'align': 'center'}},
    ];
    final html = QuillHtml.documentToHtml(Document.fromJson(deltaJson));
    // Restore the HTML into a fresh Quill document, exactly like the editor
    // does when a saved form/template is reopened.
    final restored = QuillHtml.documentFromHtml(html).toDelta().toJson();
    final attrs = attrKeys(restored);

    for (final key in [
      'bold', 'italic', 'underline', 'strike', 'color', 'background',
      'size', 'font', 'line-height', 'align',
    ]) {
      expect(attrs.contains(key), isTrue, reason: 'missing $key in $restored');
    }
    // The report example: bold, italic, red, centered, larger font size.
    expect(restored.join(), contains('bold'));
    expect(restored.join(), contains('italic'));
    expect(restored.join(), contains('#ff0000'));
    expect(restored.join(), contains('align'));
    expect(restored.join(), contains('large'));
  });

  test('headers, alignment and bullet lists round-trip', () {
    final deltaJson = [
      {'insert': 'Heading'},
      {'insert': '\n', 'attributes': {'header': 1, 'align': 'center'}},
      {'insert': 'one'},
      {'insert': '\n', 'attributes': {'list': 'bullet'}},
      {'insert': 'two'},
      {'insert': '\n', 'attributes': {'list': 'bullet'}},
    ];
    final html = QuillHtml.documentToHtml(Document.fromJson(deltaJson));
    expect(html, contains('<h1 style="text-align: center;">'));
    expect(html, contains('<ul>'));
    expect(html, contains('<li>one</li>'));

    final restored = QuillHtml.documentFromHtml(html).toDelta().toJson();
    expect(attrKeys(restored).contains('header'), isTrue);
    expect(attrKeys(restored).contains('align'), isTrue);
    expect(attrKeys(restored).contains('list'), isTrue);
  });
}
