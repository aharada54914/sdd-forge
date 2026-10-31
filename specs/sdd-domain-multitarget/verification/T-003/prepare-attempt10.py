"""Freeze current admitted inputs using the existing preparation procedure."""
from pathlib import Path

root = Path(__file__).resolve().parents[4]
source = (root / 'reports/verification/prepare-t003-attempt7.py').read_text()
source = source.replace('root = Path(__file__).resolve().parents[2]', 'root = Path(__file__).resolve().parents[4]')
source = source.replace('attempt7', 'attempt10').replace(
    '01a140c5-7fd8-7260-a864-59c14fc4de6e',
    '01a140ef-6584-7453-a8c3-e51adad974e4',
)
exec(compile(source, __file__, 'exec'))
