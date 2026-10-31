"""Reuse the input-freezing procedure with this implementer's actual identity."""
from pathlib import Path

source = Path(__file__).with_name('prepare-t003-attempt7.py').read_text()
source = source.replace('attempt7', 'attempt9').replace(
    '01a140c5-7fd8-7260-a864-59c14fc4de6e',
    '01a140dd-cc39-76c1-9865-af9bc2f04680',
)
exec(compile(source, __file__, 'exec'))
