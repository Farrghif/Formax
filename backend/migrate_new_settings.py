"""
Migrasi database untuk fitur Settings baru di Form Builder.

Menambahkan 4 kolom di tabel forms (allow_see_result, max_submissions,
require_fullscreen, reveal_answers), 1 kolom di tabel submissions (is_cheated),
dan menghapus UniqueConstraint("form_id", "user_id") dari tabel submissions
(agar mendukung multi-submit).

Cara run:
    python migrate_new_settings.py

Script ini auto-detect engine dari DATABASE_URL (di .env):
- PostgreSQL : ADD COLUMN IF NOT EXISTS + DROP CONSTRAINT IF EXISTS.
- SQLite     : ADD COLUMN + rebuild tabel submissions untuk hapus constraint.
"""
import os

from dotenv import load_dotenv
from sqlalchemy import create_engine, text

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./formmaker.db")

FORM_COLUMNS = [
    ("allow_see_result", "BOOLEAN NOT NULL DEFAULT FALSE"),
    ("max_submissions", "INTEGER NOT NULL DEFAULT 1"),
    ("require_fullscreen", "BOOLEAN NOT NULL DEFAULT FALSE"),
    ("reveal_answers", "BOOLEAN NOT NULL DEFAULT FALSE"),
]

SUBMISSION_COLUMNS = [
    ("is_cheated", "BOOLEAN NOT NULL DEFAULT FALSE"),
]

# Skema baru tabel submissions TANPA unique constraint (form_id, user_id).
SUBMISSIONS_COLS = [
    "id", "form_id", "user_id", "started_at",
    "is_auto_submitted", "submitted_at", "is_cheated",
]


def _table_columns(conn, table):
    rows = conn.execute(text(f"PRAGMA table_info({table})")).fetchall()
    return {r[1] for r in rows}


def _migrate_postgres(conn):
    for name, coldef in FORM_COLUMNS:
        conn.execute(text(f"ALTER TABLE forms ADD COLUMN IF NOT EXISTS {name} {coldef}"))
    for name, coldef in SUBMISSION_COLUMNS:
        conn.execute(text(f"ALTER TABLE submissions ADD COLUMN IF NOT EXISTS {name} {coldef}"))
    conn.execute(
        text("ALTER TABLE submissions DROP CONSTRAINT IF EXISTS uq_one_submission_per_user_per_form")
    )
    print("PostgreSQL: kolom ditambahkan & unique constraint dihapus.")


def _migrate_sqlite(conn):
    forms_cols = _table_columns(conn, "forms")
    for name, coldef in FORM_COLUMNS:
        if name not in forms_cols:
            conn.execute(text(f"ALTER TABLE forms ADD COLUMN {name} {coldef}"))
            print(f"SQLite: forms.{name} ditambahkan.")

    subs_cols = _table_columns(conn, "submissions")
    for name, coldef in SUBMISSION_COLUMNS:
        if name not in subs_cols:
            conn.execute(text(f"ALTER TABLE submissions ADD COLUMN {name} {coldef}"))
            print(f"SQLite: submissions.{name} ditambahkan.")

    # SQLite tidak mendukung DROP CONSTRAINT -> rebuild tabel submissions.
    has_unique = _sqlite_has_form_user_unique(conn)
    if has_unique:
        cols_sql = ", ".join(SUBMISSIONS_COLS)
        conn.execute(text("DROP TABLE IF EXISTS submissions_new"))
        conn.execute(
            text(f"""
            CREATE TABLE submissions_new (
                id VARCHAR(36) NOT NULL,
                form_id VARCHAR(36) NOT NULL,
                user_id VARCHAR(36) NOT NULL,
                started_at DATETIME,
                is_auto_submitted BOOLEAN,
                submitted_at DATETIME,
                is_cheated BOOLEAN NOT NULL DEFAULT 0,
                PRIMARY KEY (id)
            )
            """)
        )
        conn.execute(
            text(f"INSERT INTO submissions_new ({cols_sql}) SELECT {cols_sql} FROM submissions")
        )
        conn.execute(text("DROP TABLE submissions"))
        conn.execute(text("ALTER TABLE submissions_new RENAME TO submissions"))
        print("SQLite: unique constraint (form_id, user_id) dihapus via rebuild tabel.")
    else:
        print("SQLite: tidak ada unique constraint yang perlu dihapus.")


def _sqlite_has_form_user_unique(conn):
    indexes = conn.execute(
        text("SELECT name, sql FROM sqlite_master WHERE type='index' AND tbl_name='submissions'")
    ).fetchall()
    for name, sql in indexes:
        if sql and "uq_one_submission_per_user_per_form" in sql:
            return True
    # Autoindex (sql NULL) — cek apakah mengcover (form_id, user_id).
    for name, sql in indexes:
        if not sql and name and name.startswith("sqlite_autoindex_submissions"):
            cols = [
                r[2]
                for r in conn.execute(
                    text(f"PRAGMA index_info({name})")
                ).fetchall()
            ]
            if cols == ["form_id", "user_id"] or cols == ["user_id", "form_id"]:
                return True
    return False


def main():
    engine = create_engine(DATABASE_URL)
    conn = engine.connect()
    try:
        dialect = engine.dialect.name
        print(f"Menggunakan engine: {dialect}")
        if dialect == "postgresql":
            _migrate_postgres(conn)
        else:
            _migrate_sqlite(conn)
        conn.commit()
        print("Migrasi selesai.")
    except Exception as exc:
        conn.rollback()
        raise
    finally:
        conn.close()


if __name__ == "__main__":
    main()