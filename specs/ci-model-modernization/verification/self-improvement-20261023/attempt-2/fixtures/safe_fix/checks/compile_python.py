"""Compile every project Python file in memory; nothing is written to disk."""
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
errors = 0
paths = sorted(ROOT.rglob("*.py"))
for path in paths:
    try:
        compile(path.read_text(encoding="utf-8"), str(path.relative_to(ROOT)), "exec")
    except SyntaxError as exc:
        errors += 1
        print(f"syntax error: {exc}")
print(f"compiled {len(paths) - errors}/{len(paths)} Python files")
sys.exit(1 if errors else 0)
