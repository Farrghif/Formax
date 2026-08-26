"""
Parser import soal pilihan ganda dari file Word (.docx).

Aturan format yang didukung:
- Soal   : "1. Teks soal" / "1) Teks soal" / "Soal 1: Teks soal"
- Opsi   : "A. teks" / "a) teks" / "(B) teks" / "*C. teks" (tanda * = kunci)
- Kunci  : tanda * di depan opsi ATAU baris "Jawaban: B" / "Kunci: B"
"""
import io
import re
from typing import BinaryIO

from docx import Document

QUESTION_RE = re.compile(r"^\s*(?:soal\s*)?(\d{1,3})\s*[.)\]:\-]\s+(.+)$", re.IGNORECASE)
OPTION_RE = re.compile(r"^\s*\*?\s*\(?\s*([A-Ha-h])\s*[).\]:\-]\s+(.+)$")
ANSWER_RE = re.compile(
    r"^\s*(?:(?:kunci\s+)?jawaban|kunci|answer)\s*[:=\-]\s*\(?([A-Ha-h])\)?\s*$",
    re.IGNORECASE,
)


def parse_docx_questions(file: BinaryIO) -> dict:
    """Parse file .docx menjadi daftar soal pilihan ganda.

    Return:
        {
          "questions": [
            {
              "number": 1,
              "label": "...",
              "options": [{"label": ..., "value": ..., "order_index": 0, "is_correct": bool}],
              "errors": ["..."],   # kosong berarti soal valid
            }, ...
          ],
          "total": int,
          "valid_count": int,
        }
    """
    document = Document(file)

    questions = []
    current = None
    seen_numbers = set()

    for para in document.paragraphs:
        line = (para.text or "").strip()
        if not line:
            continue

        answer_match = ANSWER_RE.match(line)
        if answer_match and current is not None:
            letter = answer_match.group(1).upper()
            matched = [o for o in current["options"] if o["letter"] == letter]
            if matched:
                for o in current["options"]:
                    o["is_correct"] = o["letter"] == letter
            else:
                current["errors"].append(
                    f"Kunci jawaban '{letter}' tidak ada di daftar opsi"
                )
            continue

        question_match = QUESTION_RE.match(line)
        option_match = OPTION_RE.match(line) if not question_match else None

        if question_match:
            number = int(question_match.group(1))
            current = {
                "number": number,
                "label": question_match.group(2).strip(),
                "options": [],
                "errors": [],
            }
            questions.append(current)
            if number in seen_numbers:
                current["errors"].append(f"Nomor soal {number} duplikat")
            seen_numbers.add(number)
            continue

        if option_match and current is not None:
            letter = option_match.group(1).upper()
            text = option_match.group(2).strip()
            is_correct = line.lstrip().startswith("*")
            existing = next((o for o in current["options"] if o["letter"] == letter), None)
            if existing is None:
                current["options"].append({
                    "letter": letter,
                    "label": text,
                    "value": text,
                    "order_index": len(current["options"]),
                    "is_correct": is_correct,
                })
            else:
                existing.update({"label": text, "value": text})
                if is_correct:
                    existing["is_correct"] = True
            continue

        # Baris lain: anggap lanjutan teks soal
        if current is not None and not current["options"]:
            current["label"] = f"{current['label']} {line}".strip()

    result = []
    for q in questions:
        options = [{k: v for k, v in o.items() if k != "letter"} for o in q["options"]]
        errors = list(q["errors"])

        if len(options) < 2:
            errors.append("Opsi jawaban kurang dari 2")
        if not any(o["is_correct"] for o in options):
            errors.append("Kunci jawaban tidak ditemukan")

        result.append({
            "number": q["number"],
            "label": q["label"],
            "options": options,
            "errors": errors,
        })

    return {
        "questions": result,
        "total": len(result),
        "valid_count": sum(1 for q in result if not q["errors"]),
    }


def generate_template_docx() -> bytes:
    """Buat file .docx contoh template untuk di-download guru."""
    document = Document()

    document.add_heading("Template Import Soal Pilihan Ganda", level=1)

    document.add_heading("Aturan penulisan:", level=2)
    rules = [
        'Setiap soal dimulai dengan nomor, contoh: "1. Ibu kota Indonesia adalah ..."',
        "Pilihan jawaban memakai huruf A., B., C., D., ... di awal baris.",
        'Tandai kunci jawaban dengan tanda bintang (*) di depan opsi, contoh: "*B. Jakarta"',
        'Atau tulis baris "Jawaban: B" tepat setelah daftar pilihan.',
        "Soal hanya boleh berupa pilihan ganda dengan 2 sampai 8 pilihan.",
    ]
    for rule in rules:
        document.add_paragraph(rule, style="List Bullet")

    document.add_heading("Contoh soal:", level=2)
    samples = [
        ("Ibu kota Indonesia adalah ...",
         [("A. Bandung", False), ("*B. Jakarta", False), ("C. Surabaya", False), ("D. Medan", False)],
         None),
        ("Hasil dari 12 x 12 adalah ...",
         [("A. 124", False), ("B. 132", False), ("C. 144", False), ("D. 154", False)],
         "Jawaban: C"),
        ("Planet yang dikenal sebagai planet merah adalah ...",
         [("A. Venus", False), ("B. Bumi", False), ("C. Yupiter", False), ("*D. Mars", False)],
         None),
    ]
    for idx, (qtext, opts, answer_line) in enumerate(samples, start=1):
        document.add_paragraph(f"{idx}. {qtext}")
        for opt_text, _ in opts:
            document.add_paragraph(opt_text)
        if answer_line:
            document.add_paragraph(answer_line)
        document.add_paragraph("")

    buffer = io.BytesIO()
    document.save(buffer)
    return buffer.getvalue()
