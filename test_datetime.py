import asyncio
from datetime import datetime, timezone, timedelta
from pydantic import BaseModel
from typing import Optional

class FormCreate(BaseModel):
    start_date: Optional[datetime] = None

wib = timezone(timedelta(hours=7))

def _dt(dt):
    if dt is None: return None
    if dt.tzinfo is not None:
        return dt.astimezone(wib)
    return dt.replace(tzinfo=wib)

def test():
    # Simulate receiving UTC string from mobile
    payload = {"start_date": "2026-08-30T13:00:42.123Z"}
    req = FormCreate(**payload)
    
    # Simulate saving to SQLAlchemy and reading back (drops tzinfo if naive DB)
    # Actually, SQLAlchemy might drop tzinfo, or keep it depending on dialect.
    # Let's see what pydantic parses it as:
    print(f"Pydantic parsed: {req.start_date} (tzinfo={req.start_date.tzinfo})")
    
    # If saved to DB, it might become naive if it was converted, or maybe Pydantic keeps it tz aware?
    # What does dt.astimezone(wib) produce?
    db_dt = req.start_date.replace(tzinfo=None) # simulate naive DB
    print(f"Naive DB dt: {db_dt}")
    
    dt_from_db = _dt(db_dt)
    print(f"_dt(db_dt): {dt_from_db}")
    
    now = datetime.now(wib)
    print(f"now(WIB): {now}")
    
    print(f"now < _dt(start_date): {now < dt_from_db}")

test()
