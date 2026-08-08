#!/bin/sh
set -u
# Pre-flight harness reproducing TEST-001..TEST-006 verbatim from
# tests/design-sync-standing-consent.tests.sh, run against a standalone
# fixture file before editing the live AGENTS.md.

FIXTURE="$1"
BANNED_KEY="$(printf '%s' 'ds_upload')$(printf '%s' '_consent')"

section_between() {
  awk -v start="$2" -v end="$3" '
    $0 ~ start { flag = 1 }
    flag && $0 ~ end && $0 !~ start { exit }
    flag { print }
  ' "$1" 2>/dev/null
}
flatten_text() {
  printf '%s' "$1" | tr '\n' ' ' | tr -s '[:space:]' ' '
}

AG_PS_SECTION=$(section_between "$FIXTURE" '^## Project Settings$' '^## ')
AG_PS_FLAT=$(flatten_text "$AG_PS_SECTION")
AG_KEY_LINE=$(grep -n "${BANNED_KEY}" "$FIXTURE" 2>/dev/null | head -1 | cut -d: -f2-)

if [ -n "$AG_KEY_LINE" ] \
  && printf '%s' "$AG_KEY_LINE" | grep -Fq 'standing' \
  && printf '%s' "$AG_KEY_LINE" | grep -Fq 'per-feature' \
  && printf '%s' "$AG_KEY_LINE" | grep -Fq 'off' \
  && ! printf '%s' "$AG_KEY_LINE" | grep -Eiq 'e\.g\.|similar|etc\.|and so on|for example'; then
  echo "PASS: TEST-001"
else
  echo "FAIL: TEST-001"
fi

if grep -Eq '^## Project Settings$' "$FIXTURE" && printf '%s' "$AG_PS_FLAT" | grep -Fq "${BANNED_KEY}"; then
  echo "PASS: TEST-002"
else
  echo "FAIL: TEST-002"
fi

if printf '%s' "$AG_PS_FLAT" | grep -Eiq 'absent.{0,10}section entirely' \
  && printf '%s' "$AG_PS_FLAT" | grep -Fq 'per-feature'; then
  echo "PASS: TEST-003"
else
  echo "FAIL: TEST-003"
fi

if printf '%s' "$AG_PS_FLAT" | grep -Eiq 'absent key' \
  && printf '%s' "$AG_PS_FLAT" | grep -Fq 'per-feature'; then
  echo "PASS: TEST-004"
else
  echo "FAIL: TEST-004"
fi

if [ -n "$AG_PS_FLAT" ] && printf '%s' "$AG_PS_FLAT" | grep -Fq "${BANNED_KEY}" \
  && ! printf '%s' "$AG_PS_FLAT" | grep -Eq 'Codex|Claude Code'; then
  echo "PASS: TEST-005"
else
  echo "FAIL: TEST-005"
fi

if printf '%s' "$AG_PS_FLAT" | grep -Eiq 'off.{0,10}:.{0,40}forbid.{0,30}every host|forbid.{0,30}upload.{0,20}every host'; then
  echo "PASS: TEST-006"
else
  echo "FAIL: TEST-006"
fi
