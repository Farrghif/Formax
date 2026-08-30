from datetime import datetime, timedelta, timezone
from backend.app.routers.forms import _now, _dt, GRACE
import sqlite3

conn = sqlite3.connect('backend/formmaker.db')
c = conn.cursor()
c.execute("SELECT start_date FROM forms ORDER BY created_at DESC LIMIT 1")
row = c.fetchone()
conn.close()

if row and row[0]:
    # Start date as string from DB
    start_date_str = row[0]
    print(f"DB start_date string: {start_date_str}")
    # SQLite returns string, SQLAlchemy parses it as datetime. Let's parse it:
    start_date = datetime.strptime(start_date_str, "%Y-%m-%d %H:%M:%S.%f")
    print(f"Parsed DB datetime: {start_date} (tzinfo={start_date.tzinfo})")
    
    now = _now()
    dt_val = _dt(start_date)
    print(f"now = {now}")
    print(f"dt_val = {dt_val}")
    print(f"now + GRACE = {now + GRACE}")
    
    if now + GRACE < dt_val:
        print("RESULT: Form belum dibuka")
    else:
        print("RESULT: Form sudah dibuka")
else:
    print("No start date")
