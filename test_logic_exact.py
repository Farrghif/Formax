from datetime import datetime, timedelta, timezone

WIB = timezone(timedelta(hours=7))

def _window_dt(dt):
    if dt is None:
        return None
    if dt.tzinfo is not None:
        return dt.astimezone(WIB)
    return dt.replace(tzinfo=WIB)

# Simulate DB value
start_date = datetime.strptime("2026-08-30 17:38:35", "%Y-%m-%d %H:%M:%S")

# Simulate user opening the form at 17:39:00 WIB
now = datetime(2026, 8, 30, 17, 39, 0, tzinfo=WIB)

GRACE = timedelta(seconds=60)
w_dt = _window_dt(start_date)

print(f"now: {now}")
print(f"w_dt: {w_dt}")
print(f"now + GRACE: {now + GRACE}")
print(f"now + GRACE < w_dt: {now + GRACE < w_dt}")
