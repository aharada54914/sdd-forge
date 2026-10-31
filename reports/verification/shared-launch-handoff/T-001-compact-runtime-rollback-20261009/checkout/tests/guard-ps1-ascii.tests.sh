#!/usr/bin/env bash
# TEST-015 (AC-015): sdd-hook-guard.ps1 must contain only ASCII bytes (0x00-0x7F)
# and carry no UTF-8 BOM, so it parses correctly under Windows PowerShell 5.1
# (which reads a BOM-less non-ASCII .ps1 as ANSI and corrupts the deny reasons).
# TEST-012/TEST-015 (epic-159-pillar-a2 T-003/#147, T-004/#174, AC-012/AC-015):
# the same hygiene checks are extended to the domain-review-precheck.ps1 and
# spec-review-precheck.ps1 full-parity ports, plus a CR-byte scan (LF-only
# convention; CR is inside the ASCII range so the non-ASCII scan alone would
# not catch it) via a generalized TARGETS array.
#
# The FIRST target defaults to the LIVE guard .ps1 (the human-copy staged
# deliverable was applied by a human, so CI must watch the enforcing copy);
# override it with GUARD_PS1 to check a staged human-copy before it is
# applied. This override applies ONLY to the protected hook-guard entry;
# the newer, unprotected precheck-port entries always check their live path.
# The non-ASCII scan mirrors `LC_ALL=C grep -P '[^\x00-\x7F]'`; on hosts whose
# grep lacks -P (e.g. BSD/macOS) it falls back to an equivalent python3 byte scan.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGETS=(
    "${GUARD_PS1:-${REPO_ROOT}/plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1}"
    "${REPO_ROOT}/plugins/sdd-domain/scripts/domain-review-precheck.ps1"
    "${REPO_ROOT}/plugins/sdd-review-loop/scripts/spec-review-precheck.ps1"
)

PASS=0
FAIL=0
ok()   { echo "ok: $*";   PASS=$((PASS+1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

echo "guard-ps1-ascii.tests.sh"

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

# Count CR (0x0D) bytes (0 = LF-only). CR is inside the 0x00-0x7F ASCII
# range, so this is a distinct scan from count_non_ascii above.
count_cr() {
    local f="$1"
    if [ "$GREP_P_OK" = "1" ]; then
        if LC_ALL=C grep -qP '\x0D' "$f"; then echo 1; else echo 0; fi
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c 'import sys; d=open(sys.argv[1],"rb").read(); print(1 if 0x0D in d else 0)' "$f"
    else
        if LC_ALL=C od -An -tu1 "$f" | tr ' ' '\n' | grep -vE '^$' | awk '$1==13{c++} END{print c+0}' | grep -qv '^0$'; then echo 1; else echo 0; fi
    fi
}

for TARGET in "${TARGETS[@]}"; do
    echo "  target: $TARGET"

    if [ ! -f "$TARGET" ]; then
        fail "target .ps1 not found: $TARGET"
        continue
    fi

    BASENAME="$(basename "$TARGET")"

    NON_ASCII="$(count_non_ascii "$TARGET")"
    if [ "$NON_ASCII" = "0" ]; then
        ok "$BASENAME is ASCII-only (no byte > 0x7F)"
    else
        fail "$BASENAME contains $NON_ASCII non-ASCII byte(s)"
    fi

    # UTF-8 BOM check: the first three bytes must NOT be EF BB BF.
    FIRST3="$(LC_ALL=C head -c 3 "$TARGET" | od -An -tx1 | tr -d ' \n')"
    if [ "$FIRST3" != "efbbbf" ]; then
        ok "$BASENAME has no UTF-8 BOM (first bytes: ${FIRST3:-empty})"
    else
        fail "$BASENAME starts with a UTF-8 BOM (EF BB BF)"
    fi

    CR_COUNT="$(count_cr "$TARGET")"
    if [ "$CR_COUNT" = "0" ]; then
        ok "$BASENAME has no CR bytes (LF-only)"
    else
        fail "$BASENAME contains CR byte(s) (not LF-only)"
    fi
done

echo ""
echo "guard-ps1-ascii.tests.sh: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
