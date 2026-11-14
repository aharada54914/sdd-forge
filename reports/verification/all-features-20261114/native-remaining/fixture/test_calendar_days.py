import unittest
from calendar_days import days_inclusive

class ExistingChecks(unittest.TestCase):
    def test_reversed_range(self):
        with self.assertRaises(ValueError):
            days_inclusive("2026-11-14", "2026-11-13")

    def test_invalid_date(self):
        with self.assertRaises(ValueError):
            days_inclusive("2026-02-30", "2026-03-01")

if __name__ == "__main__":
    unittest.main()
