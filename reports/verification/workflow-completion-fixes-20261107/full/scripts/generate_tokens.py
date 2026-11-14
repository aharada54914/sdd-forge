"""Generate CSS variables for the project's design-system-contract/v1 tokens."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import re
import sys


NAME = re.compile(r"[a-z][a-z0-9]*(?:-[a-z0-9]+)*")
COLOR = re.compile(r"#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})")
DIMENSION = re.compile(r"(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:px|rem|em|%)")
FONT = re.compile(r"[A-Za-z][A-Za-z0-9 -]*")


def unique_object(pairs: list[tuple[str, object]]) -> dict[str, object]:
    result: dict[str, object] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def token_value(token: dict[str, object], path: str) -> str:
    if set(token) != {"$type", "$value"}:
        raise ValueError(f"{path}: expected only $type and $value")
    kind, value = token["$type"], token["$value"]
    if kind == "color" and isinstance(value, str) and COLOR.fullmatch(value):
        return value
    if kind == "dimension" and isinstance(value, str) and DIMENSION.fullmatch(value):
        return value
    if kind == "number" and type(value) in (int, float):
        if isinstance(value, int) or (isinstance(value, float) and math.isfinite(value)):
            return str(value)
    if kind == "fontFamily" and isinstance(value, list) and value:
        fonts: list[str] = []
        for font in value:
            if not isinstance(font, str) or not FONT.fullmatch(font) or font != font.strip():
                raise ValueError(f"{path}: invalid font family")
            fonts.append(f'"{font}"' if " " in font else font)
        return ", ".join(fonts)
    raise ValueError(f"{path}: unsupported token type or invalid value")


def render_tokens(document: object) -> str:
    if not isinstance(document, dict):
        raise ValueError("token document must be an object")
    metadata = document.get("meta")
    if (not isinstance(metadata, dict)
            or metadata.get("schema") != "design-system-contract/v1"
            or not isinstance(metadata.get("version"), str)
            or not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", metadata["version"])):
        raise ValueError("meta must declare design-system-contract/v1 and a numeric version")
    declarations: dict[str, str] = {}

    def visit(node: object, segments: tuple[str, ...]) -> None:
        path = "-".join(segments)
        if not isinstance(node, dict) or not node:
            raise ValueError(f"{path}: expected a nonempty token or group object")
        if "$type" in node or "$value" in node:
            if path in declarations:
                raise ValueError(f"duplicate CSS variable name: {path}")
            declarations[path] = token_value(node, path)
            return
        for key, child in node.items():
            if not isinstance(key, str) or not NAME.fullmatch(key):
                raise ValueError(f"{path}: invalid token or group name")
            visit(child, (*segments, key))

    for key, node in document.items():
        if key == "meta":
            continue
        if not isinstance(key, str) or not NAME.fullmatch(key):
            raise ValueError("invalid top-level token or group name")
        visit(node, (key,))
    if not declarations:
        raise ValueError("token document contains no tokens")
    lines = ["/* Generated from design tokens; do not edit. */", ":root {"]
    lines.extend(f"  --{name}: {value};" for name, value in sorted(declarations.items()))
    return "\n".join([*lines, "}", ""])


def generate(source: Path, output: Path) -> None:
    if source.resolve() == output.resolve() or (output.exists() and source.samefile(output)):
        raise ValueError("input and output must be different files")
    document: object = json.loads(source.read_text(encoding="utf-8"), object_pairs_hook=unique_object)
    css = render_tokens(document)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(css, encoding="utf-8", newline="\n")


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=root / "design-system/design-tokens.json")
    parser.add_argument("--output", type=Path, default=root / "design-system/build/tokens.css")
    args = parser.parse_args()
    try:
        generate(args.input, args.output)
    except (OSError, ValueError, RecursionError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    print(f"Generated {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
