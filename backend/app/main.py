import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from .database import Base, engine
from .routers import auth, templates, forms, submissions, uploads, export, questions, search, import_docx

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


# Auto-migrate ringan & schema update
with engine.begin() as conn:
    dialect = engine.dialect.name

    def add_column(table: str, column: str, coldef: str):
        if not column_exists(table, column):
            if dialect == "postgresql":
                conn.execute(text(f"ALTER TABLE {table} ADD COLUMN IF NOT EXISTS {column} {coldef}"))
            else:
                conn.execute(text(f"ALTER TABLE {table} ADD COLUMN {column} {coldef}"))

    # Migrasi banner & opsi soal
    if not column_exists("forms", "banner_url"):
        conn.execute(text("ALTER TABLE forms ADD COLUMN banner_url VARCHAR;"))

    if not column_exists("templates", "banner_url"):
        conn.execute(text("ALTER TABLE templates ADD COLUMN banner_url VARCHAR;"))

    if not column_exists("question_options", "is_correct"):
        conn.execute(text("ALTER TABLE question_options ADD COLUMN is_correct BOOLEAN;"))

    if not column_exists("question_options", "is_other"):
        if dialect == "postgresql":
            conn.execute(text("ALTER TABLE question_options ADD COLUMN IF NOT EXISTS is_other BOOLEAN;"))
        else:
            conn.execute(text("ALTER TABLE question_options ADD COLUMN is_other BOOLEAN;"))

    # Backfill: opsi lama yang belum punya nilai dianggap bukan jawaban benar
    conn.execute(text("UPDATE question_options SET is_correct = FALSE WHERE is_correct IS NULL;"))
    conn.execute(text("UPDATE question_options SET is_other = FALSE WHERE is_other IS NULL;"))

    # Tambah nilai enum baru untuk PostgreSQL (semua tipe baru)
    if dialect == "postgresql":
        raw = engine.raw_connection()
        try:
            raw_cursor = raw.cursor()
            for val in ['image', 'text_block', 'paragraph', 'time', 'linear_scale', 'rating', 'multiple_choice_grid', 'tick_box_grid']:
                raw_cursor.execute(f"ALTER TYPE questiontype ADD VALUE IF NOT EXISTS '{val}'")
            raw.commit()
            raw_cursor.close()
        finally:
            raw.close()

    # Setting baru Form Builder
    add_column("forms", "allow_see_result", "BOOLEAN NOT NULL DEFAULT FALSE")
    add_column("forms", "max_submissions", "INTEGER NOT NULL DEFAULT 1")
    add_column("forms", "require_fullscreen", "BOOLEAN NOT NULL DEFAULT FALSE")
    add_column("forms", "reveal_answers", "BOOLEAN NOT NULL DEFAULT FALSE")
    add_column("submissions", "is_cheated", "BOOLEAN NOT NULL DEFAULT FALSE")

    # Hapus unique constraint (form_id, user_id) supaya multi-submit bisa jalan.
    if dialect == "postgresql":
        conn.execute(
            text("ALTER TABLE submissions DROP CONSTRAINT IF EXISTS uq_one_submission_per_user_per_form")
        )
    else:
        indexes = conn.execute(
            text("SELECT name, sql FROM sqlite_master WHERE type='index' AND tbl_name='submissions'")
        ).fetchall()
        drop = False
        for name, sql in indexes:
            if sql and "uq_one_submission_per_user_per_form" in sql:
                drop = True
                break
            if not sql and name and name.startswith("sqlite_autoindex_submissions"):
                cols = [r[2] for r in conn.execute(text(f"PRAGMA index_info({name})")).fetchall()]
                if cols == ["form_id", "user_id"] or cols == ["user_id", "form_id"]:
                    drop = True
                    break
        if drop:
            cols = ["id", "form_id", "user_id", "started_at", "is_auto_submitted", "submitted_at", "is_cheated"]
            cols_sql = ", ".join(cols)
            conn.execute(text("DROP TABLE IF EXISTS submissions_new"))
            conn.execute(text("""CREATE TABLE submissions_new (
                id VARCHAR(36) NOT NULL,
                form_id VARCHAR(36) NOT NULL,
                user_id VARCHAR(36) NOT NULL,
                started_at DATETIME,
                is_auto_submitted BOOLEAN,
                submitted_at DATETIME,
                is_cheated BOOLEAN NOT NULL DEFAULT 0,
                PRIMARY KEY (id)
            )"""))
            conn.execute(text(f"INSERT INTO submissions_new ({cols_sql}) SELECT {cols_sql} FROM submissions"))
            conn.execute(text("DROP TABLE submissions"))
            conn.execute(text("ALTER TABLE submissions_new RENAME TO submissions"))


app = FastAPI(title="Form Maker API", version="2.0.0")

# CORS: baca dari env ALLOWED_ORIGINS (comma-separated), fallback buka untuk ngrok/Vercel
_allowed_origins_raw = os.getenv("ALLOWED_ORIGINS", "")
_allowed_origins = [o.strip() for o in _allowed_origins_raw.split(",") if o.strip()] if _allowed_origins_raw.strip() else []

if _allowed_origins:
    # Production: hanya origin yang di-whitelist
    app.add_middleware(
        CORSMiddleware,
        allow_origins=_allowed_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
else:
    # Dev / ngrok tunnel: allow semua origin (Bearer token tidak butuh cookies)
    # Ini yang fix Cross-Origin di https://formax-seven.vercel.app -> ngrok-free.dev
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=False,
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
app.include_router(import_docx.router)


@app.get("/")
def root():
    return {"message": "Form Maker API v2 is running"}
