# Form Maker API v2 (FastAPI + PostgreSQL)

Versi final backend, sudah disesuaikan sama fitur desain kelompok:
timer window (start_date–end_date), token ujian bareng, wajib login buat isi form,
progress indikator, dan QR code generator.

## Nama tabel

`users`, `templates`, `forms`, `questions`, `question_options`, `submissions`, `answers`

## 1. Setup

```bash
python -m venv venv
source venv/bin/activate        # Windows: venv\Scripts\activate
pip install -r requirements.txt

cp .env.example .env
# isi DATABASE_URL sesuai PostgreSQL kamu, dan SECRET_KEY acak

createdb formmaker
```

## 2. Jalankan server

```bash
uvicorn app.main:app --reload
```

Buka `http://localhost:8000/docs` buat Swagger UI (coba semua endpoint langsung dari browser).

## 3. Isi template sistem (Blank / Attendance / Exam)

```bash
python -m scripts.seed
```

## 4. Daftar endpoint

### Auth
| Method | Endpoint | Fungsi |
|---|---|---|
| POST | `/auth/signup` | Daftar (full_name, email, password) |
| POST | `/auth/login` | Login → dapat JWT |
| POST | `/auth/logout` | Logout |
| GET | `/auth/me` | Data profil sendiri |

### Templates
| Method | Endpoint | Fungsi |
|---|---|---|
| GET | `/templates` | List semua template (sistem + punya sendiri) |
| GET | `/templates/mine` | Khusus "My Template" |
| POST | `/templates` | Buat template baru |
| GET | `/templates/{id}` | Detail template |
| PATCH | `/templates/{id}` | Edit judul/deskripsi template |
| DELETE | `/templates/{id}` | Hapus template sendiri |

### Forms
| Method | Endpoint | Fungsi |
|---|---|---|
| GET | `/forms` | List form sendiri + jumlah submission (halaman **History**) |
| POST | `/forms` | Buat form (blank / dari template), atur `start_date`/`end_date`, `use_join_token` |
| GET | `/forms/{id}` | Detail form (buat owner edit) |
| PATCH | `/forms/{id}` | Update form |
| DELETE | `/forms/{id}` | Hapus form |
| POST | `/forms/{id}/generate-qr` | Generate QR code dari link form |
| GET | `/forms/public/{slug}` | **Wajib login** — buka form buat diisi |
| GET | `/forms/{id}/export` | Download hasil jawaban jadi Excel |

### Questions (form builder — tambah/edit/hapus per soal)
| Method | Endpoint | Fungsi |
|---|---|---|
| POST | `/forms/{form_id}/questions` | Tambah 1 pertanyaan baru ke form |
| POST | `/templates/{template_id}/questions` | Tambah 1 pertanyaan baru ke template |
| PATCH | `/questions/{id}` | Edit 1 pertanyaan (label, tipe, wajib, urutan) |
| DELETE | `/questions/{id}` | Hapus 1 pertanyaan |
| POST | `/questions/{id}/options` | Tambah 1 opsi jawaban |
| PATCH | `/options/{id}` | Edit 1 opsi jawaban |
| DELETE | `/options/{id}` | Hapus 1 opsi jawaban |

### Submissions (isi & submit form)
| Method | Endpoint | Fungsi |
|---|---|---|
| POST | `/forms/public/{slug}/join` | Mulai isi form. Wajib kirim `token` kalau form pakai join_token |
| PUT | `/submissions/{id}/answers` | Autosave — simpan/update 1 jawaban per soal |
| GET | `/submissions/{id}/progress` | Progress "3/40" — jumlah soal terjawab vs total |
| POST | `/submissions/{id}/submit` | Submit final |
| GET | `/forms/{id}/submissions` | Owner lihat semua jawaban masuk |

### Uploads
| Method | Endpoint | Fungsi |
|---|---|---|
| POST | `/uploads` | Upload file (buat pertanyaan tipe `file_upload`) |

## 5. Alur lengkap isi form (versi final)

1. User **login dulu** (wajib, gak ada anonim)
2. Buka link `/f/{slug}` di frontend → panggil `GET /forms/public/{slug}` → tampilkan pertanyaan
3. Klik "Mulai" → `POST /forms/public/{slug}/join` (isi `token` kalau ujian pakai kode bareng) → dapat `submission_id`
4. Tiap jawab 1 soal → `PUT /submissions/{id}/answers` (autosave)
5. Frontend polling/hitung `GET /submissions/{id}/progress` buat nampilin "3/40"
6. Submit akhir → `POST /submissions/{id}/submit`
   - Kalau waktu submit udah lewat `end_date` form → otomatis ditandai `is_auto_submitted = true`

## 6. Fitur Token Form (ujian bareng)

Saat bikin form, kirim `"use_join_token": true` → server generate kode acak 6 karakter
(disimpan di `forms.join_token`). Guru share kode ini terpisah dari link (misal ditulis di
papan tulis pas mau mulai ujian), siswa wajib masukin kode itu di `POST /join` sebelum bisa
mulai — jadi ujian beneran mulai serentak, bukan kapan aja orang buka link-nya.

## 7. Catatan production

<!-- - Ganti `Base.metadata.create_all` dengan **Alembic** migration
- Set `allow_origins` CORS ke domain React/Flutter kamu, jangan `"*"` -->
- File di `static/` disimpan lokal di server — untuk production sebaiknya pindah ke
  object storage (S3, Cloudinary, dll) supaya gak numpuk di disk server API
