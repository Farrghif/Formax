"""
Migration script for DB compatibility.

Covers:
- add missing is_other column on question_options
- add missing values to the PostgreSQL questiontype enum, including page_break
- keep SQLite compatibility

Run manually:
    python migrate_is_other.py
"""
import sqlite3
from sqlalchemy import text

from app.database import engine, Base

REQUIRED_QUESTIONTYPE_VALUES = [
    'text',
    'paragraph',
    'single_choice',
    'checkbox',
    'dropdown',
    'date',
    'time',
    'file_upload',
    'linear_scale',
    'rating',
    'multiple_choice_grid',
    'tick_box_grid',
    'page_break',
    'image',
    'text_block',
]

Base.metadata.create_all(bind=engine)

# SQLite path
if 'sqlite' in engine.url.drivername:
    conn = sqlite3.connect(engine.url.database or 'formmaker.db')
    cursor = conn.cursor()

    cursor.execute('PRAGMA table_info(question_options)')
    columns = [col[1] for col in cursor.fetchall()]
    if 'is_other' not in columns:
        cursor.execute('ALTER TABLE question_options ADD COLUMN is_other BOOLEAN DEFAULT 0')
        conn.commit()
        print('Migration: Added is_other column to question_options')

    conn.close()

# PostgreSQL path
if engine.dialect.name == 'postgresql':
    with engine.begin() as conn:
        raw = engine.raw_connection()
        try:
            cur = raw.cursor()
            for val in REQUIRED_QUESTIONTYPE_VALUES:
                cur.execute(
                    "SELECT 1 FROM pg_type t JOIN pg_enum e ON e.enumtypid = t.oid WHERE t.typname = 'questiontype' AND e.enumlabel = %s",
                    (val,),
                )
                if cur.fetchone() is None:
                    cur.execute(f"ALTER TYPE questiontype ADD VALUE IF NOT EXISTS '{val}'")
            raw.commit()
        finally:
            raw.close()
        print('Migration: questiontype enum synchronized for PostgreSQL')

print('Migration complete!')
