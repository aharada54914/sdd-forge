#!/usr/bin/env bash
# constant-parity.tests.sh — R-03: CI-enforced parity check for BASELINE_IDS / RISK_TIERS.
# Verifies that the hardcoded constants in check-contract.py (R-04 extracted) and
# check-contract.ps1 are identical. No runtime JSON loading; constants stay hardcoded
# (no tamper surface). Runs without pwsh or python3 — pure grep/sort/diff.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="${REPO_ROOT}/plugins/sdd-quality-loop/scripts"
PASS=0
FAIL=0

ok()   { echo "ok: $*";   PASS=$((PASS+1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# R-04: constants now live in check-contract.py (extracted from check-contract.sh heredoc).
PY="${SCRIPTS_DIR}/check-contract.py"
PS1="${SCRIPTS_DIR}/check-contract.ps1"

if [ ! -f "$PY" ]; then
    fail "check-contract.py not found: $PY"
    echo "constant-parity.tests.sh: $PASS passed, $FAIL failed"
    exit 1
fi
if [ ! -f "$PS1" ]; then
    fail "check-contract.ps1 not found: $PS1"
    echo "constant-parity.tests.sh: $PASS passed, $FAIL failed"
    exit 1
fi

# ---------------------------------------------------------------------------
# Extract BASELINE_IDS from check-contract.py
# Lines like:   BASELINE_IDS = {"lint", "typecheck", ...}
# Normalize: extract quoted identifiers, sort, one per line.
# ---------------------------------------------------------------------------
extract_baseline_sh() {
    # R-04: constants live in check-contract.py (extracted from check-contract.sh heredoc)
    python3 - "$PY" <<'PYEOF'
import sys, re, ast
path = sys.argv[1]
content = open(path).read()
# Match: BASELINE_IDS = {... } (single-line or multi-line)
m = re.search(r'BASELINE_IDS\s*=\s*\{([^}]+)\}', content)
if not m:
    print("ERROR: BASELINE_IDS not found", file=sys.stderr)
    sys.exit(1)
ids = sorted(s.strip().strip('"').strip("'") for s in m.group(1).split(',') if s.strip().strip('"').strip("'"))
print('\n'.join(ids))
PYEOF
}

# ---------------------------------------------------------------------------
# Extract BASELINE_IDS from check-contract.ps1
# Lines like: $BASELINE_IDS = @("lint", "typecheck", ...)
# ---------------------------------------------------------------------------
extract_baseline_ps1() {
    python3 - "$PS1" <<'PYEOF'
import sys, re
path = sys.argv[1]
content = open(path).read()
m = re.search(r'\$BASELINE_IDS\s*=\s*@\(([^)]+)\)', content, re.IGNORECASE)
if not m:
    # Try hashtable / set literal
    m = re.search(r'\$BASELINE_IDS\s*=\s*\[System\.Collections\.Generic\.HashSet[^\]]*\]\s*@?\(([^)]+)\)', content, re.IGNORECASE)
if not m:
    # Try array form used elsewhere
    m = re.search(r'\$baseline_ids\s*=\s*@\(([^)]+)\)', content, re.IGNORECASE)
if not m:
    # Fallback: look for quoted ids near BASELINE_IDS
    m = re.search(r'BASELINE_IDS[^\n]*\n([^\n]*)', content, re.IGNORECASE)
if not m:
    print("ERROR: BASELINE_IDS not found in ps1", file=sys.stderr)
    sys.exit(1)
ids = sorted(s.strip().strip('"').strip("'") for s in m.group(1).replace('"', '').replace("'", '').split(',') if s.strip().replace('"','').replace("'",'').strip())
print('\n'.join(ids))
PYEOF
}

# ---------------------------------------------------------------------------
# Extract RISK_TIERS keys from check-contract.py
# ---------------------------------------------------------------------------
extract_risk_tiers_sh() {
    python3 - "$PY" <<'PYEOF'
import sys, re
path = sys.argv[1]
content = open(path).read()
# Match RISK_TIERS = { ... } (multi-line dict literal in Python)
m = re.search(r'RISK_TIERS\s*=\s*\{(.+?)\}(?=\s*\n\s*#|\s*\n\s*COMPILE|\s*\n\s*KNOWN)', content, re.DOTALL)
if not m:
    print("ERROR: RISK_TIERS not found in sh", file=sys.stderr)
    sys.exit(1)
block = m.group(1)
# Extract the tier names (keys like "low", "medium", "high", "critical")
tiers = sorted(t.strip().strip('"').strip("'") for t in re.findall(r'"([a-z]+)"\s*:', block))
print('\n'.join(tiers))
PYEOF
}

# ---------------------------------------------------------------------------
# Extract RISK_TIERS keys from check-contract.ps1
# ---------------------------------------------------------------------------
extract_risk_tiers_ps1() {
    python3 - "$PS1" <<'PYEOF'
import sys, re
path = sys.argv[1]
content = open(path).read()
# Look for $RISK_TIERS or $risk_tiers hashtable
m = re.search(r'\$RISK_TIERS\s*=\s*@\{(.+?)\}(?=\s*\n)', content, re.IGNORECASE | re.DOTALL)
if not m:
    print("ERROR: RISK_TIERS not found in ps1", file=sys.stderr)
    sys.exit(1)
block = m.group(1)
tiers = sorted(t.strip().strip('"').strip("'") for t in re.findall(r'"([a-z]+)"\s*=', block))
print('\n'.join(tiers))
PYEOF
}

# ---------------------------------------------------------------------------
# Run checks (requires python3 for extraction)
# ---------------------------------------------------------------------------
if ! command -v python3 >/dev/null 2>&1; then
    echo "SKIP: constant-parity.tests.sh requires python3 for extraction"
    exit 0
fi

# Check 1: BASELINE_IDS parity
BASELINE_SH="${WORK}/baseline_sh.txt"
BASELINE_PS1="${WORK}/baseline_ps1.txt"

if extract_baseline_sh >"$BASELINE_SH" 2>/dev/null; then
    if extract_baseline_ps1 >"$BASELINE_PS1" 2>/dev/null; then
        if diff -u "$BASELINE_SH" "$BASELINE_PS1" >/dev/null 2>&1; then
            ok "BASELINE_IDS: sh and ps1 are identical ($(wc -l <"$BASELINE_SH") entries)"
        else
            fail "BASELINE_IDS: sh and ps1 DIVERGE"
            echo "  --- sh ---"
            cat "$BASELINE_SH"
            echo "  --- ps1 ---"
            cat "$BASELINE_PS1"
        fi
    else
        fail "BASELINE_IDS: could not extract from ps1"
    fi
else
    fail "BASELINE_IDS: could not extract from sh"
fi

# Check 2: RISK_TIERS tier-name parity
RISK_SH="${WORK}/risk_sh.txt"
RISK_PS1="${WORK}/risk_ps1.txt"

if extract_risk_tiers_sh >"$RISK_SH" 2>/dev/null; then
    if extract_risk_tiers_ps1 >"$RISK_PS1" 2>/dev/null; then
        if diff -u "$RISK_SH" "$RISK_PS1" >/dev/null 2>&1; then
            ok "RISK_TIERS keys: sh and ps1 are identical ($(wc -l <"$RISK_SH") tiers)"
        else
            fail "RISK_TIERS keys: sh and ps1 DIVERGE"
            echo "  --- sh ---"
            cat "$RISK_SH"
            echo "  --- ps1 ---"
            cat "$RISK_PS1"
        fi
    else
        fail "RISK_TIERS keys: could not extract from ps1"
    fi
else
    fail "RISK_TIERS keys: could not extract from sh"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "constant-parity.tests.sh: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
