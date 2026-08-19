"""
Migration script to add is_other column to question_options table
and add image and text_block to QuestionType enum (PostgreSQL/SQLite).

For SQLite, this uses ALTER TABLE to add the column.
For PostgreSQL, you would use: ALTER TYPE questiontype ADD VALUE IF NOT EXISTS 'image';
"""
import sqlite3
from app.database import engine, Base
from app import models

# Create any new tables or columns that don't exist yet
Base.metadata.create_all(bind=engine)

# For SQLite, we need to manually add the is_other column if it doesn't exist
if 'sqlite' in engine.url.drivername:
    conn = sqlite3.connect(engine.url.database or 'formmaker.db')
    cursor = conn.cursor()

    # Check if is_other column exists
    cursor.execute('PRAGMA table_info(question_options)')
    columns = [col[1] for col in cursor.fetchall()]

    if 'is_other' not in columns:
        cursor.execute('ALTER TABLE question_options ADD COLUMN is_other BOOLEAN DEFAULT 0')
        conn.commit()
        print('Migration: Added is_other column to question_options')

    conn.close()

print('Migration complete!')
