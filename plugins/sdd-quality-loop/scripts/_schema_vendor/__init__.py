"""Load the pinned pure-Python wheel under a private package namespace."""
from pathlib import Path

__path__.append(str(Path(__file__).resolve().parent / 'fastjsonschema.whl'))
