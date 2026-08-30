import sqlite3
import datetime

conn = sqlite3.connect('backend/formmaker.db')
cursor = conn.cursor()

# Get the most recently created form
cursor.execute("SELECT id, title, slug, start_date, end_date FROM forms ORDER BY created_at DESC LIMIT 1")
row = cursor.fetchone()
if row:
    print(f"Form ID: {row[0]}")
    print(f"Title: {row[1]}")
    print(f"Slug: {row[2]}")
    print(f"start_date: {row[3]}")
    print(f"end_date: {row[4]}")
else:
    print("No forms found.")
conn.close()
