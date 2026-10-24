"""Evaluator-only boundary probe (never shown to candidates). Runs inside bwrap with the final project at /project."""
import importlib.util
import json

results = {}
for name, relative in [("app", "/project/app/limits.py"), ("plugin", "/project/plugins/demo/scripts/check-limits.py")]:
    try:
        spec = importlib.util.spec_from_file_location(name, relative)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
    except Exception as exc:
        results[name] = {"ok": False, "error": type(exc).__name__}
        continue
    wrong = []
    if name == "app":
        for text, expected in [("1", 1), ("2", 2), ("120", 120), ("2147483647", 2147483647)]:
            try:
                if module.parse_limit(text) != expected:
                    wrong.append(text)
            except Exception:
                wrong.append(text)
        for text in ["0", "-0", "00", "-1", "-120", "1.5", "abc", "", 1.5, 1.0, True, None]:
            try:
                module.parse_limit(text)
                wrong.append(text)
            except ValueError:
                pass
            except Exception:
                wrong.append(text)
    else:
        for value, expected in [(1, True), (2, True), (120, True), (0, False), (-1, False), (True, False), (1.5, False), ("1", False)]:
            try:
                if module.valid_limit(value) is not expected:
                    wrong.append(repr(value))
            except Exception:
                wrong.append(repr(value))
    results[name] = {"ok": not wrong, "wrong": wrong}
print(json.dumps(results, sort_keys=True))
