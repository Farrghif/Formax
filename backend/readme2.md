# Form Maker API — Panduan Setup buat Tim

Backend FastAPI + PostgreSQL buat project Form Maker. Dokumen ini khusus buat kamu
yang **clone dari repo tim** dan mau jalanin backend-nya di laptop sendiri.

> Asumsi: kamu udah install Python 3.10+, PostgreSQL, dan Git di laptop kamu.
> Kalau belum, install dulu ketiganya sebelum lanjut.

---

## 1. Clone repo

```bash
git clone <url-repo-tim-kamu>
cd <nama-folder-repo>
```

Kalau backend-nya ada di subfolder (misal `backend/`), masuk dulu ke situ:
```bash
cd backend
```

## 2. Buat virtual environment & install dependencies

```bash
python -m venv venv

# aktifin venv-nya:
source venv/bin/activate        # Mac/Linux
venv\Scripts\activate           # Windows

pip install -r requirements.txt
```

## 3. Setup file `.env`

Setiap orang di tim **punya `.env` sendiri-sendiri** (file ini sengaja gak ikut di-push ke Git,
karena isinya password database & secret key masing-masing device).

```bash
cp .env.example .env
```

Buka file `.env`, isi sesuai PostgreSQL **lokal kamu sendiri**:

```env
DATABASE_URL=postgresql://postgres:password_postgres_kamu@localhost:5432/formmaker
SECRET_KEY=bebas-string-acak-apa-aja-yang-penting-panjang
BASE_URL=http://localhost:8000
```

## 4. Buat database PostgreSQL lokal

Tiap anggota tim bikin database-nya sendiri di PostgreSQL lokal masing-masing
(nama databasenya harus sama persis dengan yang ada di `DATABASE_URL` kamu):

```bash
createdb formmaker
```

Kalau `createdb` gak dikenali, buka `psql` terus jalanin:
```sql
CREATE DATABASE formmaker;
```

## 5. Jalankan server

```bash
uvicorn app.main:app --reload
```

Kalau berhasil, tabel-tabel (`users`, `forms`, `questions`, dst) **otomatis dibuat**
di database lokal kamu saat pertama kali run — gak perlu import file SQL manual.

Buka browser ke:
```
http://localhost:8000/docs
```
Ini Swagger UI — dari sini kamu bisa coba semua endpoint langsung tanpa Postman.

## 6. Isi template sistem (Blank / Attendance / Exam)

Wajib dijalanin sekali di awal, biar 3 template default kepakai pas testing:

```bash
python -m scripts.seed
```

## 7. Cara test endpoint yang butuh login

1. Coba `POST /auth/signup` dulu (isi `full_name`, `email`, `password`) → copy `access_token` dari response
2. Klik tombol **"Authorize"** (ikon gembok) di pojok kanan atas Swagger
3. Paste token-nya ke kolom yang muncul (gak perlu ketik kata "Bearer")
4. Klik Authorize → Close
5. Sekarang semua endpoint yang butuh login otomatis kebawa token itu

## 8. Kalau ada masalah pas run

| Gejala | Kemungkinan penyebab | Solusi |
|---|---|---|
| `500 Internal Server Error` pas signup | `.env` gak kebaca / DB connection salah | Cek `DATABASE_URL` di `.env` bener, pastiin `createdb formmaker` udah dijalanin |
| Error `bcrypt has no attribute '__about__'` | Versi `bcrypt` ketinggian | `pip install "bcrypt==4.0.1"` |
| `connection refused` ke database | PostgreSQL service belum jalan | Nyalain PostgreSQL (`brew services start postgresql` / buka pgAdmin / service Windows) |
| Tombol "Authorize" minta username & password, bukan kolom token | Kode `deps.py` masih pakai versi lama | Pastiin `deps.py` udah pakai `HTTPBearer`, bukan `OAuth2PasswordBearer` |
| Endpoint isi form selalu 401 walau udah login | Lupa klik "Authorize" atau token expired | Login ulang, authorize ulang di Swagger |

## 9. Aturan kerja tim (biar gak konflik)

- **Jangan pernah commit file `.env`** — itu udah ada di `.gitignore`, tapi double-check dulu sebelum `git push`
- Kalau nambah kolom/tabel baru di `models.py`, kabarin ke tim di grup — karena tiap orang punya DB lokal sendiri, perubahan struktur tabel gak otomatis nyambung ke database temen lain (mereka perlu drop & recreate DB, atau pakai migration kalau nanti udah pakai Alembic)
- Push kerjaan di branch masing-masing, jangan langsung ke `main`

---

## Daftar Endpoint

### Auth
| Method | Endpoint | Fungsi |
|---|---|---|
| POST | `/auth/signup` | Daftar (full_name, email, password) |
| POST | `/auth/login` | Login → dapat JWT |
| POST | `/auth/logout` | Logout |
| GET | `/auth/me` | Data profil sendiri |

> ⚠️ `PUT /auth/me` (edit profil) **belum ada** di kode saat ini — kalau tim butuh ini, bilang aja, gampang ditambahin.

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
| GET | `/forms` | List form sendiri + jumlah submission (halaman History) |
| POST | `/forms` | Buat form (blank / dari template), atur `start_date`/`end_date`, `use_join_token` |
| GET | `/forms/{id}` | Detail form (buat owner edit) |
| PATCH | `/forms/{id}` | Update form |
| DELETE | `/forms/{id}` | Hapus form |
| POST | `/forms/{id}/generate-qr` | Generate QR code dari link form |
| GET | `/forms/public/{slug}` | Wajib login — buka form buat diisi |
| GET | `/forms/{id}/export` | Download hasil jawaban jadi Excel |

### Questions
| Method | Endpoint | Fungsi |
|---|---|---|
| POST | `/forms/{form_id}/questions` | Tambah 1 pertanyaan baru ke form |
| POST | `/templates/{template_id}/questions` | Tambah 1 pertanyaan baru ke template |
| PATCH | `/questions/{id}` | Edit 1 pertanyaan |
| DELETE | `/questions/{id}` | Hapus 1 pertanyaan |
| POST | `/questions/{id}/options` | Tambah 1 opsi jawaban |
| PATCH | `/options/{id}` | Edit 1 opsi jawaban |
| DELETE | `/options/{id}` | Hapus 1 opsi jawaban |

### Submissions
| Method | Endpoint | Fungsi |
|---|---|---|
| POST | `/forms/public/{slug}/join` | Mulai isi form (wajib token kalau form pakai join_token) |
| PUT | `/submissions/{id}/answers` | Autosave jawaban per soal |
| GET | `/submissions/{id}/progress` | Progress "3/40" |
| POST | `/submissions/{id}/submit` | Submit final |
| GET | `/forms/{id}/submissions` | Owner lihat semua jawaban masuk |

### Uploads
| Method | Endpoint | Fungsi |
|---|---|---|
| POST | `/uploads` | Upload file (buat pertanyaan tipe `file_upload`) |

---

## Alur lengkap isi form (buat dipahami tim frontend)

1. User login dulu (wajib)
2. `GET /forms/public/{slug}` → tampilkan pertanyaan
3. `POST /forms/public/{slug}/join` (+ token kalau perlu) → dapat `submission_id`
4. Tiap jawab 1 soal → `PUT /submissions/{id}/answers`
5. `GET /submissions/{id}/progress` → nampilin "3/40"
6. `POST /submissions/{id}/submit` → selesai

## Fitur Token Form (ujian bareng)

Saat bikin form kirim `"use_join_token": true` → server generate kode 6 karakter di
`forms.join_token`. Guru share kode itu terpisah dari link, siswa wajib masukin token
di `POST /join` sebelum bisa mulai ujian.
