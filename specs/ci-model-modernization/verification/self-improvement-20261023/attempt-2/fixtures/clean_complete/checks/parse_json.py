"""Parse the project JSON configuration. This project has no YAML files; only JSON is parsed."""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
try:
    data = json.loads((ROOT / "config/limits.json").read_text(encoding="utf-8"))
except (OSError, ValueError) as exc:
    print(f"config/limits.json: {exc}")
    sys.exit(1)
print(f"parsed JSON config/limits.json with {len(data.get('limits', {}))} limits (YAML: none present, not checked)")
