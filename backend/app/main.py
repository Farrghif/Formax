from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from .database import Base, engine
from .routers import auth, templates, forms, submissions, uploads, export, questions

from sqlalchemy import text

# Buat semua tabel otomatis kalau belum ada (development).
Base.metadata.create_all(bind=engine)

# Auto-migrate: pastikan kolom banner_url ada di tabel forms & templates
with engine.connect() as conn:
    conn.execute(text("ALTER TABLE forms ADD COLUMN IF NOT EXISTS banner_url VARCHAR;"))
    conn.execute(text("ALTER TABLE templates ADD COLUMN IF NOT EXISTS banner_url VARCHAR;"))
    # Auto-migrate: kunci jawaban di question_options
    conn.execute(text("ALTER TABLE question_options ADD COLUMN IF NOT EXISTS is_correct BOOLEAN;"))
    # Backfill: opsi lama yang belum punya nilai dianggap bukan jawaban benar
    conn.execute(text("UPDATE question_options SET is_correct = FALSE WHERE is_correct IS NULL;"))
    conn.commit()


app = FastAPI(title="Form Maker API", version="2.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # ganti ke domain React/Flutter kamu pas production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Serve file QR code & hasil upload
app.mount("/static", StaticFiles(directory="static"), name="static")

app.include_router(auth.router)
app.include_router(templates.router)
app.include_router(forms.router)
app.include_router(questions.router)
app.include_router(submissions.router)
app.include_router(uploads.router)
app.include_router(export.router)


@app.get("/")
def root():
    return {"message": "Form Maker API v2 is running"}
