import unittest

from calendar_days import days_inclusive


class InclusiveCalendarDays(unittest.TestCase):
    def test_same_date(self):
        self.assertEqual(days_inclusive("2026-11-14", "2026-11-14"), 1)

    def test_inclusive_calendar_boundaries(self):
        cases = [
            ("2026-11-14", "2026-11-15", 2),
            ("2026-11-14", "2026-11-20", 7),
            ("2026-01-31", "2026-02-01", 2),
            ("2026-12-31", "2027-01-01", 2),
            ("2024-02-28", "2024-03-01", 3),
            ("2024-02-29", "2024-02-29", 1),
            ("2026-02-28", "2026-03-01", 2),
            ("2000-02-28", "2000-03-01", 3),
            ("1900-02-28", "1900-03-01", 2),
            ("0001-01-01", "0001-01-01", 1),
            ("9999-12-31", "9999-12-31", 1),
        ]
        for start, end, expected in cases:
            with self.subTest(start=start, end=end):
                self.assertEqual(days_inclusive(start, end), expected)

    def test_invalid_dates_rejected_at_either_endpoint(self):
        for invalid in ["2026-02-30", "2026-02-29", "1900-02-29", "2026-13-01", "not-a-date", ""]:
            for start, end in [(invalid, "2026-03-01"), ("2026-01-01", invalid)]:
                with self.subTest(start=start, end=end):
                    with self.assertRaises(ValueError):
                        days_inclusive(start, end)

    def test_reversed_calendar_boundaries_rejected(self):
        for start, end in [
            ("2026-02-01", "2026-01-31"),
            ("2027-01-01", "2026-12-31"),
            ("2024-03-01", "2024-02-29"),
        ]:
            with self.subTest(start=start, end=end):
                with self.assertRaises(ValueError):
                    days_inclusive(start, end)


if __name__ == "__main__":
    unittest.main()
