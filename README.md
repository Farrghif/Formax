# Formax

Formax adalah aplikasi pembuat formulir digital yang tersedia dalam versi **web** dan **mobile**. Aplikasi ini memungkinkan pengguna untuk membuat, mengelola, dan membagikan formulir secara mudah, mulai dari survei, pendaftaran, kuis, absensi, hingga pengumpulan data umum lainnya.

-----

## Fitur Utama

- **Dynamic Form Builder** — Membuat formulir dengan berbagai tipe input secara fleksibel.
- **Template Siap Pakai** — Tersedia template sistem seperti Blank, Attendance, dan Exam, serta template kustom buatan pengguna.
- **Easy Sharing** — Membagikan formulir melalui tautan (link) atau kode QR.
- **Response Management** — Mengelola dan menganalisis hasil pengisian formulir, termasuk ekspor data.
- **Timer Window** — Mengatur batas waktu pengisian formulir (start date – end date).
- **Mode Ujian** — Dukungan token bersama untuk sesi ujian.
- **Indikator Progres** — Menampilkan progres pengisian formulir secara real-time.

---

## Teknologi

| Platform | Teknologi |
|---|---|
| Backend | FastAPI, SQLAlchemy, PostgreSQL |
| Web | React, Vite, React Router |
| Mobile | Flutter, mobile_scanner, shared_preferences |

---

## Struktur Proyek

```
form-maker/
├── backend/    # REST API (FastAPI + PostgreSQL)
├── web/        # Aplikasi web (React + Vite)
└── mobile/     # Aplikasi mobile (Flutter)
```

---

## Menjalankan Proyek

### 1. Backend

```bash
cd backend
python -m venv venv
venv\Scripts\activate        # Windows
source venv/bin/activate     # Linux / macOS

pip install -r requirements.txt
cp .env.example .env         # Sesuaikan DATABASE_URL dan SECRET_KEY

uvicorn app.main:app --reload
```

Server berjalan di `http://localhost:8000`. Dokumentasi API interaktif tersedia di `http://localhost:8000/docs` (Swagger UI).

Untuk mengisi template sistem (Blank / Attendance / Exam):

```bash
python -m scripts.seed
```

### 2. Web

```bash
cd web
npm install
npm run dev
```

### 3. Mobile

```bash
cd mobile
flutter pub get
flutter run
```

---

## Konfigurasi Lingkungan

Buat file `.env` pada direktori `backend/` berdasarkan `.env.example`:

| Variabel | Deskripsi |
|---|---|
| `DATABASE_URL` | URL koneksi PostgreSQL |
| `SECRET_KEY` | Secret key untuk penandatanganan JWT |
| `BASE_URL` | URL dasar server |

---

## Lisensi
======= 