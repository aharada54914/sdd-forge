# Private calendar helper

A small existing Python standard-library project. This is a disposable verification fixture, not a deployed service or public API.

`calendar_days.days_inclusive(start, end)` accepts ISO dates and should count both endpoints. Reversed ranges and invalid dates must raise ValueError. No network, authentication, database, personal data, billing, or migration is in scope.

Run `python3 -m unittest -v`.

Reported bug: the same date, for example 2026-11-14 to 2026-11-14, returns 0 when the caller expects one inclusive calendar day. Confirm the complete inclusive-date contract while preserving invalid/reversed-input rejection.
