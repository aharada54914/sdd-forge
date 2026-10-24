#!/usr/bin/env python3
"""Demo plugin guard: validates every limit in config/limits.json."""
import json
import sys


def valid_limit(value):
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def main(path="config/limits.json"):
    with open(path, encoding="utf-8") as handle:
        limits = json.load(handle)["limits"]
    bad = sorted(name for name, value in limits.items() if not valid_limit(value))
    for name in bad:
        print(f"invalid limit: {name}={limits[name]!r}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:]))
