# Form4X — Product Specification

## 1. Konsep Utama
Buat aplikasi bernama **Form4X**.
Form4X adalah aplikasi **form builder seperti Google Forms**.
Tujuan utama aplikasi ini adalah memungkinkan pengguna membuat formulir digital dengan pengalaman yang **semirip mungkin dengan Google Forms**.
Jangan menganggap Form4X sebagai LMS, platform sekolah, sistem ujian kompleks, atau aplikasi survey khusus.
**Referensi utama desain dan UX adalah Google Forms.**

Fitur tambahan utama Form4X dibandingkan konsep Google Forms dasar adalah:
1. **Template system**
2. **QR Code generator**
3. **QR Code scanner**

## 2. Target Pengguna
Aplikasi memiliki satu jenis akun utama: **User** (bisa sebagai pembuat atau pengisi).

## 3. Struktur Aplikasi
- Authentication (Login, Register, Logout, Profile)
- Home / Dashboard
- Form Builder & Template
- Form Filling & Response Management
- QR Code & QR Scanner

## 4. Prioritas Implementasi
**Phase 1 — Core**
Authentication, Home, Create Form, Edit Form, Questions, Question Options, Preview, Publish, Fill Form, Submit Response

**Phase 2 — Google Forms-like UX**
Duplicate/Delete question, Drag/reorder, Required question, Sections, Images, Form settings, Response management

**Phase 3 — Template**
System Templates, My Templates, Create/Use/Edit/Delete Template

**Phase 4 — QR**
Generate, Display, Download, Scan QR, Open scanned form

**Phase 5 — Export**
Export responses to Excel

## 5. Most Important Requirement
Ketika mengambil keputusan desain atau implementasi, selalu gunakan prinsip berikut:
**"Bagaimana Google Forms melakukan hal ini?"**
Jangan menciptakan UX baru tanpa alasan.
Form4X harus terasa familiar bagi orang yang sudah pernah menggunakan Google Forms, dengan tambahan Template, QR Code Generator, dan QR Code Scanner.
