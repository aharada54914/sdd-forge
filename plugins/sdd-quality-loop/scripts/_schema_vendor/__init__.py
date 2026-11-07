"""Load the pinned pure-Python wheel under our private package namespace."""
import json
from pathlib import Path

_directory = Path(__file__).resolve().parent
_manifest = json.loads((_directory / 'manifest.json').read_text(encoding='utf-8'))
__path__.append(str(_directory / _manifest['wheel']))
