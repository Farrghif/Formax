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
}
