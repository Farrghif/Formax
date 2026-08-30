import os
from datetime import datetime, timezone, timedelta
from sqlalchemy import create_engine, Column, Integer, DateTime, String
from sqlalchemy.orm import declarative_base, sessionmaker

Base = declarative_base()

class TestModel(Base):
    __tablename__ = 'test_dates'
    id = Column(Integer, primary_key=True)
    dt = Column(DateTime)

engine = create_engine('sqlite:///test_dates.db')
Base.metadata.create_all(engine)
Session = sessionmaker(bind=engine)
session = Session()

# Create a timezone aware UTC datetime
wib = timezone(timedelta(hours=7))
dt_wib_now = datetime.now(wib)
dt_utc = dt_wib_now.astimezone(timezone.utc)

print(f"Original WIB: {dt_wib_now}")
print(f"UTC object to save: {dt_utc}")

t = TestModel(dt=dt_utc)
session.add(t)
session.commit()

# Read it back raw from sqlite3 to see how it was stored
import sqlite3
conn = sqlite3.connect('test_dates.db')
c = conn.cursor()
c.execute("SELECT dt FROM test_dates ORDER BY id DESC LIMIT 1")
print(f"Raw string in SQLite DB: {c.fetchone()[0]}")
conn.close()

# Read it back via SQLAlchemy
t_read = session.query(TestModel).order_by(TestModel.id.desc()).first()
print(f"Read from SQLAlchemy: {t_read.dt} (tzinfo={t_read.dt.tzinfo})")
