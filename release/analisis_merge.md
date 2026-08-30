# Analisis Database & Strategi Merge — Formax

Tanggal: 2026-08-30
Sumber data yang dianalisis: `backend/formmaker.db` (database komputermu)
File siap serah: `release/formmaker.usercopy.db`, `release/formmaker_export.json`

---

## 1. Latar Belakang Masalah

- Web **Vercel** (`formax-seven.vercel.app`) menunjuk ke backend **`wriggly-diffusion-flatfoot.ngrok-free.dev`** (milik pemilik akun).
- Backend pemilik hidup, **tetapi memakai database yang TIDAK berisi form milikmu**.
- Form yang kamu buat (mis. `empty-formakaka-4e86e8`) hanya ada di **database komputermu** yang dilayani `hardware-bountiful-porthole.ngrok-free.dev`.
- Akibatnya, saat membuka link web Vercel di HP: server pemilik tidak menemukan slug → **404 "Form tidak ditemukan"**.

Keputusan pengguna: **gabungkan data dari database komputermu ke database pemilik (merge, bukan replace).**
Database pemilik: SQLite (`formmaker.db`), sudah punya data sendiri yang harus dipertahankan.

> Catatan penting: proses merge harus dijalankan **di sisi pemilik** (karena kita tidak punya akses ke DB/server pemilik). Kita hanya bisa menyiapkan script + data.

---

## 2. Struktur Skema (8 tabel)

Semua tabel PK = `id VARCHAR(36)` (UUID).

| Tabel | Kolom penting (relasi) |
|---|---|
| `users` | id, full_name, **email (UNIQUE)**, password_hash, avatar_url, created_at |
| `forms` | id, **owner_id→users**, template_id→templates, title, **slug (UNIQUE)**, status, qr_code_url, accept_responses, start/end_date, … |
| `templates` | id, owner_id→users, title, is_system, … |
| `questions` | id, **form_id→forms**, **template_id→templates**, type, label, order_index, settings |
| `question_options` | id, **question_id→questions**, label, value, order_index, is_correct, is_other |
| `submissions` | id, **form_id→forms**, **user_id→users (boleh NULL)**, respondent_key, started_at, submitted_at |
| `answers` | id, **submission_id→submissions**, **question_id→questions**, answer_text, answer_options, file_url |
| `email_verifications` | id, email, otp_code, created_at, expires_at |

Unique constraint SQL level:
- `users.email` → **UNIQUE**
- `forms.slug` → **UNIQUE**

---

## 3. Isi Database Komputermu

| Entitas | Jumlah | Keterangan |
|---|---|---|
| users | **9** | email unik |
| forms | **41** | 24 milik `halo@gmail.com` (8bb15b52), 17 milik `farrelghifari433@gmail.com` (cbfae6d3); 26 published, 15 draft; slug unik |
| templates | **52** | semua milik user (halo:46, farrel:2, dll); `is_system=0` semua |
| questions | **135** | 63 soal form + 71 soal template + **1 menggantung** |
| question_options | **232** | bersih (tidak ada ke soal hilang) |
| submissions | **18** | 13 ber-user, 5 anonim (respondent_key) |
| answers | **6** | bersih |
| email_verifications | **4** | |

### Temuan data basi
- **1 soal menggantung**: `questions.id=cc0c7c7e…` → `template_id=ecd64d61…` yang **tidak ada** di `templates` (template pernah dihapus). Bukan ancaman, tapi harus dicatat.

---

## 4. Strategi Merge (draf)

Karena dua database adalah proyek yang sama, **ID UUID bisa tumpang tindih** dan **kunci alami** (email/slug) bisa bentrok. Strategi aman = **preserve data pemilik** bila terjadi konflik, tambahkan data milikmu yang belum ada.

Perluasan per-tabel:

1. **users** — identitas = `email` (UNIQUE).
   - Email sama → pertahankan row pemilik, jangan dup; catat petakan `id_komputermu → id_pemilik`.
   - Email beda → tambah sebagai user baru (dengan id baru bila perlu).
   - Contoh: `farrelghifari433@gmail.com` pasti ada di DB pemilik juga → harus disatukan.

2. **forms** — identitas = `slug` (UNIQUE).
   - Slug sama → **keputusan**: pertahankan pemilik ATAU beri slug baru untuk form-mu. Default aman: pertahankan pemilik (jangan timpa), log konflik untuk ditinjau.
   - Slug beda → tambah (owner diarahkan ke user pemilik yang sudah dipetakan).

3. **templates** — tidak ada kunci natural tegas.
   - id sama → pertahankan pemilik; petakan.
   - id beda → tambah. Risiko duplikasi bila pemilik punya template serupa (log untuk tinjauan).

4. **questions / question_options / submissions / answers** — ikuti relasi:
   - tambah yang form/template/user-nya sudah dipetakan & siid baru;
   - pertahankan milik pemilik bila id sama.

### Aturan aman yang dipakai script
- Default: **jangan menimpa data pemilik**. Bila id/email/slug sudah ada di pemilik, data pemilik menang; data komputermu dicatat sebagai "sama/duplikat" di log.
- Jika ingin form-mu TETAP MUNCUL (untuk diisi), slug yang bentrok harus **dibuat unik** (mis. tambah akhiran) — ini keputusan yang perlu disepakati.

---

## 5. Yang Perlu Diputuskan Sebelum Eksekusi

1. Bila ada slug form yang **sama** di database pemilik & milikmu → mau diapakan?
   - (a) Biarkan pemilik menang, form-mu yang bentrok TIDAK ikut masuk.
   - (b) Beri slug baru (mis. `-from` akhiran) supaya form-mu tetap tampil.
2. Kata sandi (password_hash) user: saat menggabung user dgn email sama, **pertahankan hash pemilik** (jangan timpa) suapaya login pemilik tetap berlaku.
3. File statis (upload & QR) harus ikut disalin ke folder `static/` pemilik agar media tidak rusak.
