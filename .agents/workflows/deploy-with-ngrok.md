---
description: Cara menjalankan backend dengan ngrok agar bisa diakses dari Vercel
---

# Deploy Frontend ke Vercel + Backend via Ngrok

## Prasyarat
- Python & pip sudah terinstall
- [ngrok](https://ngrok.com/download) sudah terinstall dan sudah login (`ngrok config add-authtoken <token>`)
- Akun Vercel

---

## Langkah 1: Jalankan Backend FastAPI

Buka terminal di folder `backend/`:

```powershell
cd backend
..\venv\Scripts\activate     # aktifkan virtual environment
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Pastikan backend jalan di `http://localhost:8000`.

---

## Langkah 2: Jalankan Ngrok

Buka terminal **baru** (jangan tutup terminal backend), lalu jalankan:

```powershell
ngrok http 8000
```

Ngrok akan menampilkan output seperti ini:

```
Forwarding    https://abcd-1234.ngrok-free.app -> http://localhost:8000
```

**Salin URL `https://xxxx.ngrok-free.app`** — ini adalah URL publik backend kamu.

> ⚠️ **PENTING**: Setiap kali ngrok di-restart, URL akan berubah! Kamu harus update Environment Variable di Vercel juga.

---

## Langkah 3: Update BASE_URL di Backend `.env`

Edit file `backend/.env`:

```
BASE_URL=https://abcd-1234.ngrok-free.app
```

Ini penting supaya URL file upload & QR code yang dikembalikan backend 
menggunakan URL ngrok (bukan localhost).

Setelah mengubah `.env`, **restart backend** (Ctrl+C lalu jalankan ulang uvicorn).

---

## Langkah 4: Deploy Frontend ke Vercel

### Opsi A: Via Vercel CLI

```powershell
cd web
npx -y vercel --prod
```

Saat ditanya environment variables, atau lewat dashboard Vercel:

- **Key**: `VITE_API_BASE_URL`
- **Value**: `https://abcd-1234.ngrok-free.app` (URL ngrok kamu)

### Opsi B: Via Vercel Dashboard

1. Push project ke GitHub
2. Buka [vercel.com](https://vercel.com), import repository
3. Set **Root Directory** ke `web`
4. Set **Framework Preset** ke `Vite`
5. Tambahkan Environment Variable:
   - `VITE_API_BASE_URL` = `https://abcd-1234.ngrok-free.app`
6. Klik **Deploy**

---

## Langkah 5: Verifikasi

1. Buka URL Vercel yang di-generate
2. Coba login / akses fitur yang butuh backend
3. Pastikan semua API call mengarah ke URL ngrok

---

## Catatan Penting

| Hal | Keterangan |
|-----|------------|
| **Ngrok URL berubah** | Setiap restart ngrok, URL berubah. Update di Vercel + backend `.env`, lalu re-deploy |
| **Ngrok gratis** | Ada rate limit & URL berubah. Untuk URL tetap, pakai ngrok berbayar (`ngrok http 8000 --domain=xxx.ngrok-free.app`) |
| **CORS** | `backend/app/main.py:131` pakai `allow_origins` dari `ALLOWED_ORIGINS` + `allow_origin_regex=r"https://formax.*\.vercel\.app"` untuk allow semua preview Vercel (`formax-*.vercel.app`). Tanpa ini `OPTIONS /auth/login` di branch preview akan `400` |
| **Backend harus nyala** | Selama web dipakai, backend + ngrok harus tetap jalan di komputer kamu |
| **Upload/QR Code** | URL hasil upload & QR code sudah pakai `BASE_URL` dari `.env`, jadi otomatis ikut ngrok |
