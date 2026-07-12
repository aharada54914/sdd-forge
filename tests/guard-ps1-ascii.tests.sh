#!/usr/bin/env bash
# TEST-015 (AC-015): sdd-hook-guard.ps1 must contain only ASCII bytes (0x00-0x7F)
# and carry no UTF-8 BOM, so it parses correctly under Windows PowerShell 5.1
# (which reads a BOM-less non-ASCII .ps1 as ANSI and corrupts the deny reasons).
#
# The target defaults to the staged human-copy .ps1 (this task's deliverable);
# override with GUARD_PS1 to check the live path once a human has copied it in.
# The non-ASCII scan mirrors `LC_ALL=C grep -P '[^\x00-\x7F]'`; on hosts whose
# grep lacks -P (e.g. BSD/macOS) it falls back to an equivalent python3 byte scan.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${GUARD_PS1:-${REPO_ROOT}/specs/epic-136-phase1-guards/human-copy/sdd-hook-guard.ps1}"

PASS=0
FAIL=0
ok()   { echo "ok: $*";   PASS=$((PASS+1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

echo "guard-ps1-ascii.tests.sh"
echo "  target: $TARGET"

if [ ! -f "$TARGET" ]; then
    fail "target .ps1 not found: $TARGET"
    echo ""
    echo "guard-ps1-ascii.tests.sh: $PASS passed, $FAIL failed"
    exit 1
fi

# Probe whether this platform's grep supports PCRE (-P). GNU grep returns 0 on a
# match; BSD grep exits with an error (non-zero, != 1) because -P is unsupported.
GREP_P_OK=0
if printf 'a\n' | LC_ALL=C grep -qP 'a' 2>/dev/null; then GREP_P_OK=1; fi

# Count non-ASCII bytes (0 = pure ASCII). Prefer grep -P; else authoritative python3.
count_non_ascii() {
    local f="$1"
    if [ "$GREP_P_OK" = "1" ]; then
        if LC_ALL=C grep -qP '[^\x00-\x7F]' "$f"; then echo 1; else echo 0; fi
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c 'import sys; d=open(sys.argv[1],"rb").read(); print(sum(1 for b in d if b>0x7F))' "$f"
    else
        # Last-resort portable scan via od.
        if LC_ALL=C od -An -tu1 "$f" | tr ' ' '\n' | grep -vE '^$' | awk '$1>127{c++} END{print c+0}' | grep -qv '^0$'; then echo 1; else echo 0; fi
    fi
}

NON_ASCII="$(count_non_ascii "$TARGET")"
if [ "$NON_ASCII" = "0" ]; then
    ok "sdd-hook-guard.ps1 is ASCII-only (no byte > 0x7F)"
else
    fail "sdd-hook-guard.ps1 contains $NON_ASCII non-ASCII byte(s)"
fi

# UTF-8 BOM check: the first three bytes must NOT be EF BB BF.
FIRST3="$(LC_ALL=C head -c 3 "$TARGET" | od -An -tx1 | tr -d ' \n')"
if [ "$FIRST3" != "efbbbf" ]; then
    ok "sdd-hook-guard.ps1 has no UTF-8 BOM (first bytes: ${FIRST3:-empty})"
else
    fail "sdd-hook-guard.ps1 starts with a UTF-8 BOM (EF BB BF)"
fi

echo ""
echo "guard-ps1-ascii.tests.sh: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
