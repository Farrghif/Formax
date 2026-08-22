from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from .database import Base, engine
from .routers import auth, templates, forms, submissions, uploads, export, questions, search

from sqlalchemy import text

# Buat semua tabel otomatis kalau belum ada (development).
Base.metadata.create_all(bind=engine)

# Auto-migrate ringan: tambah kolom baru kalau belum ada & hapus unique constraint
# (form_id, user_id) di submissions untuk mendukung multi-submit.
with engine.connect() as conn:
    dialect = engine.dialect.name

    def column_exists(table, column):
        if dialect == "postgresql":
            return conn.execute(
                text(
                    "SELECT 1 FROM information_schema.columns "
                    "WHERE table_name = :table AND column_name = :column"
                ),
                {"table": table, "column": column},
            ).first() is not None
        # SQLite / lainnya
        rows = conn.execute(text(f"PRAGMA table_info({table})")).fetchall()
        return any(r[1] == column for r in rows)

    def add_column(table, column, coldef):
        if not column_exists(table, column):
            if dialect == "postgresql":
                conn.execute(text(f"ALTER TABLE {table} ADD COLUMN IF NOT EXISTS {column} {coldef}"))
            else:
                conn.execute(text(f"ALTER TABLE {table} ADD COLUMN {column} {coldef}"))

    if not column_exists("forms", "banner_url"):
        conn.execute(text("ALTER TABLE forms ADD COLUMN banner_url VARCHAR;"))

    if not column_exists("templates", "banner_url"):
        conn.execute(text("ALTER TABLE templates ADD COLUMN banner_url VARCHAR;"))

    if not column_exists("question_options", "is_correct"):
        conn.execute(text("ALTER TABLE question_options ADD COLUMN is_correct BOOLEAN;"))

    # Backfill: opsi lama yang belum punya nilai dianggap bukan jawaban benar
    conn.execute(text("UPDATE question_options SET is_correct = FALSE WHERE is_correct IS NULL;"))

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
app.include_router(search.router)


@app.get("/")
def root():
    return {"message": "Form Maker API v2 is running"}
