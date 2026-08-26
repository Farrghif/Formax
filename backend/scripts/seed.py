"""
Jalankan sekali setelah tabel dibuat, buat ngisi 3 template sistem:
Blank Form, Attendance Form, Exam Form.

Cara run:
    python -m scripts.seed
"""
from app.database import SessionLocal, Base, engine
from app import models

Base.metadata.create_all(bind=engine)


def seed():
    db = SessionLocal()
    try:
        existing = db.query(models.Template).filter(models.Template.is_system == True).count()
        if existing > 0:
            print("Template sistem sudah ada, skip seeding.")
            return

        # 1. Blank Form — gak ada pertanyaan default
        blank = models.Template(title="Blank Form", description="Mulai dari form kosong", is_system=True)
        db.add(blank)

        # 2. Attendance Form
        attendance = models.Template(title="Attendance Form", description="Form absensi kehadiran", is_system=True)
        db.add(attendance)
        db.flush()
        q1 = models.Question(template_id=attendance.id, type=models.QuestionType.text, label="Nama Lengkap", is_required=True, order_index=0)
        q2 = models.Question(template_id=attendance.id, type=models.QuestionType.text, label="NIM / NIS", is_required=True, order_index=1)
        q3 = models.Question(template_id=attendance.id, type=models.QuestionType.single_choice, label="Status Kehadiran", is_required=True, order_index=2)
        db.add_all([q1, q2, q3])
        db.flush()
        for i, label in enumerate(["Hadir", "Izin", "Sakit", "Alpha"]):
            db.add(models.QuestionOption(question_id=q3.id, label=label, value=label.lower(), order_index=i))

        # 3. Exam Form
        exam = models.Template(title="Exam Form", description="Form ujian dengan berbagai tipe soal", is_system=True)
        db.add(exam)
        db.flush()
        eq1 = models.Question(template_id=exam.id, type=models.QuestionType.text, label="Nama Peserta", is_required=True, order_index=0)
        eq2 = models.Question(template_id=exam.id, type=models.QuestionType.single_choice, label="Soal 1 (contoh pilihan ganda)", is_required=True, order_index=1)
        eq3 = models.Question(template_id=exam.id, type=models.QuestionType.file_upload, label="Upload Lembar Jawaban (jika ada)", is_required=False, order_index=2)
        db.add_all([eq1, eq2, eq3])
        db.flush()
        for i, label in enumerate(["A", "B", "C", "D"]):
            db.add(models.QuestionOption(question_id=eq2.id, label=label, value=label, order_index=i))

        db.commit()
        print("Berhasil seed 3 template sistem: Blank Form, Attendance Form, Exam Form")
    finally:
        db.close()


if __name__ == "__main__":
    seed()
