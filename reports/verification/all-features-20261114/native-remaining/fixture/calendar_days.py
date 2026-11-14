from datetime import date

def days_inclusive(start: str, end: str) -> int:
    first, last = date.fromisoformat(start), date.fromisoformat(end)
    if last < first:
        raise ValueError("end precedes start")
    return (last - first).days + 1
