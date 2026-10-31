"""Prepare a fresh identity without changing historical attempt evidence."""
from pathlib import Path

source = Path(__file__).with_name('prepare-t003-attempt7.py').read_text()
source = source.replace('attempt7', 'attempt8')
source = source.replace('01a140c5-7fd8-7260-a864-59c14fc4de6e', '01a140d2-ac5a-7d90-9d42-8da5b93afdc8')
exec(compile(source, __file__, 'exec'))
