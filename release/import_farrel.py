#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
IMPORTER Paket Form 'farrelghifari' -> Database Pemilik (Jalur B)
=================================================================
Dijalankan DI SISI PEMILIK (pemilik akses DB mereka sendiri).

Yang dilakukan:
  1. Backup database pemilik (kopi tersimpan di samping file).
  2. Cari user penerima = email TARGET_OWNER_EMAIL di DB pemilik.
  3. Tanam 17 form milik 'farrelghifari433@gmail.com' + soal + opsi +
     submission + jawaban, dengan:
       - owner_id -> id user penerima
       - remap id bila id bentrok dengan DB pemilik (data pemilik TIDAK ditimpa)
       - perbaiki base URL pada qr_code_url / banner_url / file_url
       - slug bentrok diberi akhiran "--farrel" agar tetap masuk
  4. Cetak laporan + verifikasi.

Cara pakai:
  python import_farrel.py "<path-db-pemilik>.db" [dir-paket]
  contoh:
  python import_farrel.py "C:/.../formmaker.db" "C:/.../release"

  (opsional) base URL backend pemilik utk perbaiki QR:
  python import_farrel.py "db.db" "." --base-url https://xxx.ngrok-free.dev

CATATAN: JANGAN dijalankan pada DB komputermu ini. Jalankan pada DB PEMILIK.
"""

import argparse
import json
import os
import shutil
import sqlite3
import sys
import uuid

DEFAULT_PKG = "paket_farrel_jalurB.json"
TARGET_OWNER_EMAIL = "fathinjamaluddin666@gmail.com"
SLUG_SUFFIX = "--farrel"


def db_columns(con, table):
    return [r[1] for r in con.execute(f"PRAGMA table_info({table})")]


def build_insert(con, table, row, col_keep):
    """Sisipkan baris hanya utk kolom yang benar-benar ada di tabel pemilik."""
    cols = db_columns(con, table)
    use_cols = [c for c in col_keep if c in cols]
    if not use_cols:
        return False
    placeholders = ",".join("?" * len(use_cols))
    sql = f"INSERT OR IGNORE INTO {table} ({','.join(use_cols)}) VALUES ({placeholders})"
    vals = [row.get(c) for c in use_cols]
    con.execute(sql, vals)
    return True


def remap_str(val, mapping):
    """Ganti id lama -> id baru di dalam string URL bila ada referensi."""
    return mapping.get(val, val)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("db_path", help="path file database pemilik (SQLite)")
    ap.add_argument("pkg_dir", nargs="?", default=".", help="folder berisi paket json")
    ap.add_argument("--base-url", default=None,
                    help="base URL backend pemilik utk perbaiki qr_code_url (mis. https://xxx.ngrok-free.dev)")
    args = ap.parse_args()

    db_path = os.path.abspath(args.db_path)
    if not os.path.exists(db_path):
        print(f"[ERROR] DB tidak ditemukan: {db_path}")
        sys.exit(1)

    pkg_path = os.path.join(args.pkg_dir, DEFAULT_PKG)
    if not os.path.exists(pkg_path):
        pkg_path = os.path.join(args.pkg_dir or ".", DEFAULT_PKG)
    if not os.path.exists(pkg_path):
        print(f"[ERROR] paket tidak ditemukan: {pkg_path}")
        sys.exit(1)

    with open(pkg_path, encoding="utf-8") as fh:
        pkg = json.load(fh)

    # ---- backup ----
    bkp = db_path + ".bak_pre_farrel_import"
    shutil.copy2(db_path, bkp)
    print(f"[OK] Backup dibuat: {bkp}")

    con = sqlite3.connect(db_path)
    con.row_factory = sqlite3.Row
    cur = con.cursor()

    # ---- cari user penerima ----
    target = con.execute("SELECT id FROM users WHERE email = ?", (TARGET_OWNER_EMAIL,)).fetchone()
    if target is None:
        print(f"[ERROR] Tidak ada user {TARGET_OWNER_EMAIL} di DB pemilik. "
              f"Buat akun penerima dulu, atau ubah TARGET_OWNER_EMAIL di skrip.")
        con.close()
        sys.exit(1)
    target_owner_id = target["id"]
    print(f"[OK] User penerima: {TARGET_OWNER_EMAIL} -> id {target_owner_id}")

    # ---- pemetaan id (old -> new) ----
    form_id_map = {}
    q_id_map = {}
    sub_id_map = {}

    existing_forms = {r[0] for r in con.execute("SELECT id FROM forms")}
    existing_slugs = {r[0] for r in con.execute("SELECT slug FROM forms")}

    # ---- tanam FORMS ----
    n_form = 0
    for f in pkg["forms"]:
        old_id = f["id"]
        new_id = old_id if old_id not in existing_forms else str(uuid.uuid4())
        form_id_map[old_id] = new_id

        row = dict(f)
        row["id"] = new_id
        row["owner_id"] = target_owner_id
        # kolom template_id jadi None (Jalur B tanpa template)
        row["template_id"] = None
        # slug unik
        slug = row.get("slug")
        if slug in existing_slugs:
            slug = slug + SLUG_SUFFIX
            existing_slugs.add(slug)
            row["slug"] = slug
        else:
            existing_slugs.add(slug)
        # perbaiki base url QR: ganti host menjadi base URL pemilik
        if row.get("qr_code_url"):
            path = row["qr_code_url"].split("/static/", 1)[-1]  # ambil "qrcodes/xxx.png"
            if args.base_url:
                row["qr_code_url"] = args.base_url.rstrip("/") + "/static/" + path
            else:
                row["qr_code_url"] = None  # tak ada base URL -> kosong, bisa di-regenerate

        build_insert(con, "forms", row, [
            "id", "owner_id", "template_id", "title", "description", "status",
            "slug", "join_token", "qr_code_url", "accept_responses", "start_date",
            "end_date", "created_at", "updated_at", "banner_url", "allow_see_result",
            "max_submissions", "require_fullscreen", "reveal_answers",
        ])
        n_form += 1
    con.commit()
    print(f"[OK] Forms ditanam: {n_form}")

    # ---- tanam QUESTIONS ----
    n_q = 0
    existing_q = {r[0] for r in con.execute("SELECT id FROM questions")}
    for q in pkg["questions"]:
        old_id = q["id"]
        new_id = old_id if old_id not in existing_q else str(uuid.uuid4())
        q_id_map[old_id] = new_id

        row = dict(q)
        row["id"] = new_id
        row["form_id"] = form_id_map.get(q["form_id"])
        row["template_id"] = None
        if build_insert(con, "questions", row, [
            "id", "form_id", "template_id", "type", "label", "placeholder",
            "is_required", "order_index", "settings", "created_at",
        ]):
            n_q += 1
    con.commit()
    print(f"[OK] Questions ditanam: {n_q}")

    # ---- tanam QUESTION_OPTIONS ----
    n_o = 0
    existing_o = {r[0] for r in con.execute("SELECT id FROM question_options")}
    for o in pkg["question_options"]:
        old_id = o["id"]
        new_id = old_id if old_id not in existing_o else str(uuid.uuid4())
        row = dict(o)
        row["id"] = new_id
        row["question_id"] = q_id_map.get(o["question_id"])
        if build_insert(con, "question_options", row, [
            "id", "question_id", "label", "value", "order_index", "is_correct", "is_other",
        ]):
            n_o += 1
    con.commit()
    print(f"[OK] Question_options ditanam: {n_o}")

    # ---- tanam SUBMISSIONS ----
    # user_id = submission milik farrel (self). User tidak ikut (Jalur B),
    # jadi user_id dikosongkan (NULL) supaya tidak referensi user yang tak ada.
    n_s = 0
    existing_s = {r[0] for r in con.execute("SELECT id FROM submissions")}
    for s in pkg["submissions"]:
        old_id = s["id"]
        new_id = old_id if old_id not in existing_s else str(uuid.uuid4())
        sub_id_map[old_id] = new_id
        row = dict(s)
        row["id"] = new_id
        row["form_id"] = form_id_map.get(s["form_id"])
        row["user_id"] = None
        if build_insert(con, "submissions", row, [
            "id", "form_id", "user_id", "respondent_key", "started_at",
            "is_auto_submitted", "submitted_at", "is_cheated",
        ]):
            n_s += 1
    con.commit()
    print(f"[OK] Submissions ditanam: {n_s}")

    # ---- tanam ANSWERS ----
    n_a = 0
    existing_a = {r[0] for r in con.execute("SELECT id FROM answers")}
    for a in pkg["answers"]:
        old_id = a["id"]
        new_id = old_id if old_id not in existing_a else str(uuid.uuid4())
        row = dict(a)
        row["id"] = new_id
        row["submission_id"] = sub_id_map.get(a["submission_id"])
        row["question_id"] = q_id_map.get(a["question_id"])
        if args.base_url and row.get("file_url") and "/static/" in row["file_url"]:
            row["file_url"] = args.base_url.rstrip("/") + "/static/" + row["file_url"].split("/static/", 1)[-1]
        if build_insert(con, "answers", row, [
            "id", "submission_id", "question_id", "answer_text",
            "answer_options", "file_url", "answered_at",
        ]):
            n_a += 1
    con.commit()
    print(f"[OK] Answers ditanam: {n_a}")

    # ---- verifikasi ----
    new_slugs = [r[0] for r in con.execute(
        "SELECT slug FROM forms WHERE owner_id = ? AND slug LIKE ?",
        (target_owner_id, "%" + SLUG_SUFFIX)
    )]
    total_forms = con.execute(
        "SELECT COUNT(*) FROM forms WHERE owner_id = ?", (target_owner_id,)
    ).fetchone()[0]
    print()
    print("=== VERIFIKASI ===")
    print("Total form milik user penerima:", total_forms)
    print("Form baru dgn akhiran --farrel (slug bentrok):", len(new_slugs), new_slugs[:20])

    con.close()
    print()
    print("SELESAI. Backup: ", bkp)
    print("Jika ada kesalahan, pulihkan dari backup dgn menimpa file db.")
    print()
    print("=== LANGKAH BERIKUTNYA ===")
    print("1. Salin folder release/qrcodes_farrel/*.png ke <backend>/static/qrcodes/ pemilik.")
    print("2. (jika QR dikosongkan) generate ulang QR via app setelah form ditanam.")


if __name__ == "__main__":
    main()
