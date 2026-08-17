#!/usr/bin/env bash
# Deterministic local risk-upgrade checker. Python is used only for strict
# UTF-8 decoding and ASCII lexical handling; this script never reads remotely.
#
# epic-194-a6-lite-integration T-002 (REQ-002): extended with an optional
# second argument, --capability-reasons <fragment-path>. Omitted entirely ->
# byte-identical to the pre-T-002 script (AC-007). Supplied ->
# unreadable/malformed/shape-invalid fragment is a hard error, exit 2, no
# trigger reporting (Blocker [B3]); a valid fragment's eligible:false entries
# contribute their own upgrade_reasons tokens, or a synthetic
# "ineligible:<id>" token when upgrade_reasons is empty/absent (Blocker
# [B4]), appended AFTER the existing keyword-derived tokens (AC-008).
set -euo pipefail

input_path="${1:-}"
python_bin="${PYTHON_BIN:-python3}"

capability_reasons_supplied=0
capability_reasons_path=""
case "$#" in
  1)
    ;;
  3)
    if [[ "$2" != "--capability-reasons" ]]; then
      printf '%s\n' 'risk-upgrade: input unavailable'
      exit 2
    fi
    capability_reasons_supplied=1
    capability_reasons_path="$3"
    ;;
  *)
    printf '%s\n' 'risk-upgrade: input unavailable'
    exit 2
    ;;
esac

if ! command -v "$python_bin" >/dev/null 2>&1; then
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

python_capability_reasons_path="$capability_reasons_path"
if [[ "$capability_reasons_supplied" -eq 1 ]] && command -v cygpath >/dev/null 2>&1 && [[ "$capability_reasons_path" == /* ]]; then
  if ! python_capability_reasons_path="$(cygpath -w -- "$capability_reasons_path" 2>/dev/null)"; then
    printf '%s\n' 'risk-upgrade: capability-reasons fragment invalid'
    exit 2
  fi
fi

"$python_bin" - "$python_input_path" "$capability_reasons_supplied" "$python_capability_reasons_path" <<'PY'
import json
import re
import sys
from pathlib import Path

UNAVAILABLE = "risk-upgrade: input unavailable"
FRAGMENT_INVALID = "risk-upgrade: capability-reasons fragment invalid"

try:
    raw = Path(sys.argv[1]).read_bytes()
    if b"\0" in raw:
        raise ValueError("NUL is unavailable input")
    source = raw.decode("utf-8", "strict")
except (IndexError, OSError, UnicodeDecodeError, ValueError):
    print(UNAVAILABLE)
    raise SystemExit(2)

capability_reasons_supplied = sys.argv[2] == "1"
capability_reasons_path = sys.argv[3] if len(sys.argv) > 3 else ""

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

keyword_triggers = [identifier for identifier, expression in rules if bounded(expression)]

capability_triggers = []
if capability_reasons_supplied:
    try:
        fragment_raw = Path(capability_reasons_path).read_bytes()
        fragment_text = fragment_raw.decode("utf-8", "strict")
        fragment = json.loads(fragment_text)
        if not isinstance(fragment, dict) or "capabilities" not in fragment:
            raise ValueError("fragment missing capabilities key")
        capabilities = fragment["capabilities"]
        if not isinstance(capabilities, list):
            raise ValueError("capabilities is not an array")
        for entry in capabilities:
            if not isinstance(entry, dict) or "id" not in entry or "eligible" not in entry:
                raise ValueError("entry missing id or eligible")
        for entry in capabilities:
            if entry["eligible"] is False:
                reasons = entry.get("upgrade_reasons") or []
                if not isinstance(reasons, list):
                    raise ValueError("upgrade_reasons is not an array")
                if reasons:
                    capability_triggers.extend(str(token) for token in reasons)
                else:
                    capability_triggers.append("ineligible:" + str(entry["id"]))
    except (OSError, UnicodeDecodeError, ValueError, json.JSONDecodeError, TypeError, KeyError, IndexError):
        print(FRAGMENT_INVALID)
        raise SystemExit(2)

all_triggers = keyword_triggers + capability_triggers
if not all_triggers:
    print("lite-eligible")
    raise SystemExit(0)

print(f"full-required: {all_triggers[0]}; triggers={','.join(all_triggers)}")
raise SystemExit(10)
PY
