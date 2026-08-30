import sqlite3
import json

conn = sqlite3.connect('backend/formmaker.db')
c = conn.cursor()
c.execute("SELECT id, title, slug, start_date, end_date, status, accept_responses, created_at FROM forms ORDER BY created_at DESC LIMIT 5")
rows = c.fetchall()
conn.close()

for r in rows:
    print(f"Form ID: {r[0]}")
    print(f"Title: {r[1]}")
    print(f"Slug: {r[2]}")
    print(f"start_date: {r[3]}")
    print(f"end_date: {r[4]}")
    print(f"status: {r[5]}")
    print(f"accept_responses: {r[6]}")
    print(f"created_at: {r[7]}")
    print("-" * 40)
