from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from .database import Base, engine
from .routers import auth, templates, forms, submissions, uploads, export, questions, search

from sqlalchemy import text, inspect

# Buat semua tabel otomatis kalau belum ada (development).
Base.metadata.create_all(bind=engine)


def column_exists(table_name: str, column_name: str) -> bool:
    """Cek apakah kolom ada di tabel - kompatibel dengan SQLite, PostgreSQL, dll."""
    insp = inspect(engine)
    if not insp.has_table(table_name):
        return False
    columns = insp.get_columns(table_name)
    return any(col["name"] == column_name for col in columns)


# Auto-migrate: pastikan kolom banner_url ada di tabel forms & templates
with engine.begin() as conn:
    if not column_exists("forms", "banner_url"):
        conn.execute(text("ALTER TABLE forms ADD COLUMN banner_url VARCHAR;"))

    if not column_exists("templates", "banner_url"):
        conn.execute(text("ALTER TABLE templates ADD COLUMN banner_url VARCHAR;"))

    if not column_exists("question_options", "is_correct"):
        conn.execute(text("ALTER TABLE question_options ADD COLUMN is_correct BOOLEAN;"))

    # Backfill: opsi lama yang belum punya nilai dianggap bukan jawaban benar
    conn.execute(text("UPDATE question_options SET is_correct = FALSE WHERE is_correct IS NULL;"))


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
app.include_router(search.router)


@app.get("/")
def root():
    return {"message": "Form Maker API v2 is running"}