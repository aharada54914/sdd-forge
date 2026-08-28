#!/usr/bin/env bash
# Deterministic local risk-upgrade checker. Python is used only for strict
# UTF-8 decoding and ASCII lexical handling; this script never reads remotely.
set -euo pipefail

input_path="${1:-}"
python_bin="${PYTHON_BIN:-python3}"

if [[ "$#" -ne 1 ]] || ! command -v "$python_bin" >/dev/null 2>&1; then
  printf '%s\n' 'risk-upgrade: input unavailable'
  exit 2
fi

python_input_path="$input_path"
if command -v cygpath >/dev/null 2>&1 && [[ "$input_path" == /* ]]; then
  if ! python_input_path="$(cygpath -w -- "$input_path" 2>/dev/null)"; then
    printf '%s\n' 'risk-upgrade: input unavailable'
    exit 2
  fi
fi

"$python_bin" - "$python_input_path" <<'PY'
import re
import sys
from pathlib import Path

UNAVAILABLE = "risk-upgrade: input unavailable"

try:
    raw = Path(sys.argv[1]).read_bytes()
    if b"\0" in raw:
        raise ValueError("NUL is unavailable input")
    source = raw.decode("utf-8", "strict")
except (IndexError, OSError, UnicodeDecodeError, ValueError):
    print(UNAVAILABLE)
    raise SystemExit(2)

def lower_ascii(value: str) -> str:
    return "".join(
        chr(ord(character) + 32) if "A" <= character <= "Z" else character
        for character in value
    )

normalized = lower_ascii(source).replace("\r\n", "\n").replace("\r", "\n")
normalized = re.sub(r"[ \t\n]+", " ", normalized)

# Do not erase an adjacent token whose documented boundary is a hyphen or a
# non-ASCII code point. The exclusion applies to the standalone design phrase.
normalized = re.sub(
    r"(^|[^a-z0-9_])design tokens?(?=$|[^a-z0-9_])",
    r"\1 ",
    normalized,
)

def bounded(expression: str) -> bool:
    return re.search(r"(^|[^a-z0-9_])(?:" + expression + r")(?=$|[^a-z0-9_])", normalized) is not None

rules = (
    ("AUTH_BOUNDARY", r"auth|authentication|authorization|oauth|oidc"),
    ("TOKEN_CREDENTIAL", r"token|tokens|credential|credentials|password|passwords|private key(?:s)?"),
    ("MCP", r"mcp"),
    ("EXTERNAL_API", r"external[ -]+api(?:s)?|third[ -]+party[ -]+api(?:s)?"),
    ("SECRET", r"secret|secrets"),
    ("GITHUB_ACTIONS", r"github actions"),
)

triggers = [identifier for identifier, expression in rules if bounded(expression)]
if not triggers:
    print("lite-eligible")
    raise SystemExit(0)

print(f"full-required: {triggers[0]}; triggers={','.join(triggers)}")
raise SystemExit(10)
PY
