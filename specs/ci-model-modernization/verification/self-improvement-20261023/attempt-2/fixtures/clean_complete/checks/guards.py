"""Behavioral guard test for limit parsing and the demo plugin guard."""
import importlib.util
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent


def load(name, relative):
    spec = importlib.util.spec_from_file_location(name, ROOT / relative)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


limits = load("limits", "app/limits.py")
plugin = load("check_limits", "plugins/demo/scripts/check-limits.py")
failures = []

for text, expected in [("1", 1), ("25", 25)]:
    try:
        if limits.parse_limit(text) != expected:
            failures.append(f"parse_limit({text!r}) != {expected}")
    except ValueError:
        failures.append(f"parse_limit({text!r}) rejected a positive integer")
for text in ["0", "-3", "abc", "", "1.5", 1.5, True, None]:
    try:
        limits.parse_limit(text)
        failures.append(f"parse_limit({text!r}) accepted a non-positive or non-integer value")
    except ValueError:
        pass
for value, expected in [(1, True), (25, True), (0, False), (-3, False), (True, False)]:
    if plugin.valid_limit(value) is not expected:
        failures.append(f"valid_limit({value!r}) is not {expected}")

for failure in failures:
    print("FAIL", failure)
print(f"guards: {15 - len(failures)}/15 passed")
sys.exit(1 if failures else 0)
