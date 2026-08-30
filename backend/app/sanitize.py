"""Sanitasi HTML untuk konten rich-text (judul, deskripsi, label soal & opsi).

Judul/label dibuat via editor rich-text (Quill/html) sehingga sah berisi markup
presentasional (<b>, <i>, <span style>, dll). Sanitizer ini:

  1. mengunci tag berbahaya (script/iframe/object/svg + atribut on* & javascript:)
     agar tidak pernah masuk database,
  2. mempertahankan markup presentasional yang dibutuhkan rendering di web & mobile.

Dipakai lewat Pydantic `field_validator` pada skema input create/update
(forms, templates, questions & options) sehingga terjamin untuk semua endpoint.
"""

import html as _html
import re as _re
from html.parser import HTMLParser

_ALLOWED_TAGS = {
    "p", "br", "strong", "b", "em", "i", "u", "s", "strike", "del",
    "span", "ul", "ol", "li", "h1", "h2", "h3", "h4", "blockquote",
    "a", "sub", "sup", "font", "div", "pre",
    # audio/video untuk RichTextEditor dcb894e — harus di-allow agar tidak di-strip
    "audio", "video", "source",
}

_DROP_TAGS = {
    "script", "style", "iframe", "object", "embed", "form", "link",
    "meta", "base", "noscript", "svg", "math",
}

_VOID_TAGS = {"br", "hr", "img", "wbr", "source"}

_ALLOWED_ATTRS = {
    "a": {"href", "title", "target", "rel"},
    "img": {"src", "alt", "title", "width", "height"},
    "span": {"style", "title"},
    "font": {"color", "face", "size"},
    "ol": {"start"},
    "audio": {"src", "controls", "style", "preload", "title"},
    "video": {"src", "controls", "style", "width", "height", "preload"},
    "source": {"src", "type"},
}

# Pola berbahaya yang tidak boleh ada di dalam nilai atribut style/href/src.
_UNSAFE_STYLE = _re.compile(
    r"(url\s*\(|expression\s*\(|javascript:|@import|behavior\s*:|-moz-binding)"
)
_SAFE_PREFIXES = ("http://", "https://", "mailto:", "tel:", "/", "#", "data:image/", "data:audio/", "data:video/")

_STRIP_TAG_RE = _re.compile(r"<[^>]+>")


class _Sanitizer(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.out = []
        self._skipping = 0

    def _attrs(self, tag, attrs):
        rendered = []
        for key, value in attrs:
            key = key.lower()
            if key.startswith("on"):
                continue
            value = "" if value is None else str(value)
            if key == "style":
                if not _UNSAFE_STYLE.search(value.lower()):
                    rendered.append((key, value[:2000]))
            elif key in ("href", "src"):
                test = value.strip().lower()
                if test.startswith(_SAFE_PREFIXES):
                    rendered.append((key, value))
            elif _ALLOWED_ATTRS.get(tag) is None or key in _ALLOWED_ATTRS[tag]:
                if key not in ("class",):
                    rendered.append((key, value))
        return "".join(f' {k}="{_html.escape(v, quote=True)}"' for k, v in rendered)

    def handle_starttag(self, tag, attrs):
        tag = tag.lower()
        if tag in _DROP_TAGS:
            self._skipping += 1
            return
        if tag in _VOID_TAGS:
            self.out.append(f"<{tag}{self._attrs(tag, attrs)} />")
            return
        if tag in _ALLOWED_TAGS:
            self.out.append(f"<{tag}{self._attrs(tag, attrs)}>")

    def handle_startendtag(self, tag, attrs):
        self.handle_starttag(tag, attrs)

    def handle_endtag(self, tag):
        tag = tag.lower()
        if tag in _DROP_TAGS:
            if self._skipping > 0:
                self._skipping -= 1
            return
        if tag in _VOID_TAGS or tag not in _ALLOWED_TAGS:
            return
        if self._skipping == 0:
            self.out.append(f"</{tag}>")

    def handle_data(self, data):
        if self._skipping == 0:
            self.out.append(data)

    def handle_entityref(self, name):
        if self._skipping == 0:
            self.out.append(_html.unescape(f"&{name};"))

    def handle_charref(self, name):
        if self._skipping == 0:
            self.out.append(_html.unescape(f"&#{name};"))


def sanitize_html(value, max_len=100000):
    """Bersihkan HTML. Tanpa tag di dalamnya → dikembalikan apa adanya."""
    if value is None:
        return None
    s = str(value)
    if "<" not in s:
        return s if len(s) <= max_len else s[:max_len]
    parser = _Sanitizer()
    try:
        parser.feed(s)
        parser.close()
    except Exception:
        return _strip_all_tags(s)[:max_len]
    result = "".join(parser.out).strip()
    return result[:max_len]


def _strip_all_tags(s):
    text = _STRIP_TAG_RE.sub(" ", s)
    text = _html.unescape(text)
    return _re.sub(r"\s+", " ", text).strip()


def plain_text(value):
    """Sanitasi sekaligus ubah menjadi teks polos (buang markup)."""
    if value is None:
        return None
    return _strip_all_tags(str(value))