#!/usr/bin/env bash
# TEST-004 / AC-004: static Windows PowerShell 5.1 compatibility oracle for
# the staged T-002 candidate. It intentionally rejects shortcut comparisons.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd -P)"
target="${GUARD_PS1:-$root/specs/epic-136-phase2-gates/human-copy/plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1}"

if [[ ! -f "$target" ]]; then
  echo "FAIL: staged guard candidate is missing: $target" >&2
  exit 1
fi

python_target="$target"
if command -v cygpath >/dev/null 2>&1; then
  python_target="$(cygpath -w "$target")"
fi

python3 - "$python_target" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
raw = path.read_bytes()
failures = []

if raw.startswith(b"\xef\xbb\xbf"):
    failures.append("candidate has a UTF-8 BOM")
if any(byte > 0x7f for byte in raw):
    failures.append("candidate contains a non-ASCII byte")

try:
    text = raw.decode("ascii")
except UnicodeDecodeError:
    text = raw.decode("ascii", errors="replace")

forbidden = ("FixedTimeEquals", "FromHexString")
for name in forbidden:
    if name in text:
        failures.append(f"forbidden PS5.1-incompatible API present: {name}")

direct_comparisons = (
    r"\$expectedHex\s*-(?:c?eq|c?ne)\s*\$sigField",
    r"\$sigField\s*-(?:c?eq|c?ne)\s*\$expectedHex",
    r"\[string\]::Compare\([^\n]*\$sigField",
)
for pattern in direct_comparisons:
    if re.search(pattern, text, re.IGNORECASE):
        failures.append("direct supplied-signature string comparison is present")
        break

match = re.search(r"(?im)^function\s+Test-SudoSignatureConstantTime\s*\{", text)
body = ""
if not match:
    failures.append("missing Test-SudoSignatureConstantTime helper")
else:
    start = match.end()
    depth = 1
    index = start
    while index < len(text) and depth:
        if text[index] == "{":
            depth += 1
        elif text[index] == "}":
            depth -= 1
        index += 1
    if depth:
        failures.append("comparator helper has unbalanced braces")
    else:
        body = text[start:index - 1]

if body:
    literal_hex_check = r"\[regex\]::IsMatch\(\$%s,\s*\"\\A\[0-9a-fA-F\]\{64\}\\z\"\)"
    generated_hex_check = r"\[regex\]::IsMatch\(\$%s,\s*\"\\A\[0-9a-fA-F\]\{\$SudoSignatureHexLength\}\\z\"\)"
    uses_generated_length = False
    for variable in ("ExpectedHex", "SuppliedHex"):
        if re.search(generated_hex_check % variable, body):
            uses_generated_length = True
        elif not re.search(literal_hex_check % variable, body):
            failures.append(f"{variable} lacks exact 64-hex validation")

    if uses_generated_length:
        if not re.search(r"\$SudoSignatureHexLength\s*=\s*\$GuardInvariants\.SUDO_SIGNATURE_HEX_LENGTH", text):
            failures.append("generated signature length is not sourced from the fixed invariant export")
        if not re.search(r"\$GuardInvariants\.SUDO_SIGNATURE_HEX_LENGTH\s*-ne\s*64", text):
            failures.append("generated signature length is not fail-closed at exactly 64")

    loop_match = re.search(
        r"(?m)^\s*for\s*\(\$i\s*=\s*0;\s*\$i\s*-lt\s*32;\s*\$i\+\+\)\s*\{",
        body,
    )
    loop_count = len(re.findall(r"for\s*\(\$i\s*=\s*0;\s*\$i\s*-lt\s*32;\s*\$i\+\+\)", body))
    if loop_count != 1 or not loop_match:
        failures.append("comparator must contain exactly one fixed 32-iteration loop")
    else:
        loop_start = loop_match.end()
        depth = 1
        index = loop_start
        while index < len(body) and depth:
            if body[index] == "{":
                depth += 1
            elif body[index] == "}":
                depth -= 1
            index += 1
        loop_body = body[loop_start:index - 1]
        if re.search(r"(?im)\b(return|break|continue)\b", loop_body):
            failures.append("comparator loop contains an early exit")
        for variable in ("ExpectedHex", "SuppliedHex"):
            decode = rf"\[Convert\]::ToByte\(\${variable}\.Substring\(\$i\s*\*\s*2,\s*2\),\s*16\)"
            if not re.search(decode, loop_body):
                failures.append(f"{variable} is not decoded with two-character Substring plus Convert.ToByte(..., 16)")
        if "-bxor" not in loop_body or "-bor" not in loop_body:
            failures.append("comparator loop does not accumulate byte-wise XOR")
        if not re.search(r"\$difference\s*=\s*\$difference\s*-bor", loop_body):
            failures.append("comparator loop does not retain a non-short-circuit XOR accumulator")
        after_loop = body[index:]
        if not re.search(r"(?m)^\s*return\s+\(\$difference\s*-eq\s*0\)\s*$", after_loop):
            failures.append("comparator must decide equality only after the full loop")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(1)

print("ok: candidate is ASCII/no-BOM and uses the PS5.1 64-hex full-XOR comparator")
PY
