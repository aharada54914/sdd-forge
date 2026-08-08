#!/usr/bin/env bash
# design-sync-scan.tests.sh - TDD suite for design-sync-scan.sh (issue #139,
# DS-30, epic #136). Style mirrors tests/check-placeholders.tests.sh (ok/fail
# counters, mktemp fixtures, captured exit code + output, exits 1 on any
# failure). Executes the real script against fixture files; no mocking.
#
# Scope: this file's Test IDs cover T-001's own subset per tasks.md/
# traceability.md -- REQ-001-REQ-005's script-behaviour legs, REQ-008's .sh
# half (TEST-048/TEST-069), REQ-003's AC-038 POSIX-ERE authoring (via
# TEST-021/TEST-080-082), and REQ-010's AC-034 initial contribution
# (TEST-052). T-002 ports every assertion below to .ps1 at parity (BL-008)
# and adds the cross-runtime/case-sensitivity categories that require both
# scripts to exist. T-003/T-004 APPEND new blocks to the end of this file
# for their own Test IDs (SKILL.md / claude-design-workflow.md); every block
# below must stay byte-unchanged once T-003 lands (Shared-Suite Append
# Discipline, tasks.md Global Constraints).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SC="${REPO_ROOT}/plugins/sdd-bootstrap/scripts/design-sync-scan.sh"
CHECK_PLACEHOLDERS="${REPO_ROOT}/plugins/sdd-quality-loop/scripts/check-placeholders.sh"
REQUIREMENTS_MD="${REPO_ROOT}/specs/design-sync-scan/requirements.md"
ACCEPTANCE_TESTS_MD="${REPO_ROOT}/specs/design-sync-scan/acceptance-tests.md"

PASS=0
FAIL=0

ok()   { echo "ok: $*";   PASS=$((PASS+1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Run design-sync-scan.sh capturing combined stdout+stderr and exit code,
# with stdin explicitly redirected from /dev/null (AC-015 -- the script
# presumes no interactive human; every ordinary invocation in this suite
# exercises that presumption, not only TEST-030's dedicated row).
# Usage: run_scan [args...]  ->  sets $SCAN_EXIT and $SCAN_OUTPUT
run_scan() {
    SCAN_EXIT=0
    SCAN_OUTPUT="$(bash "$SC" "$@" </dev/null 2>&1)" || SCAN_EXIT=$?
}

# Same, but with a caller-supplied environment prefix (TEST-069). Usage:
# run_scan_env 'VAR=val VAR2=val2' [args...] -> sets $SCAN_EXIT/$SCAN_OUTPUT
run_scan_env() {
    local envspec="$1"; shift
    SCAN_EXIT=0
    SCAN_OUTPUT="$(env -i PATH="$PATH" HOME="${HOME:-}" $envspec bash "$SC" "$@" </dev/null 2>&1)" || SCAN_EXIT=$?
}

echo "=== design-sync-scan.tests.sh: REPO_ROOT=${REPO_ROOT} ==="
echo "=== target script: ${SC} ==="

# ============================================================================
# REQ-001 (AC-001, AC-002, AC-003, AC-004, AC-039) -- the script contract's
# basic shape and the HTML selection boundary
# ============================================================================

echo ""
echo "=== TEST-001 (AC-001): script exists, is directly invocable, requires an argument ==="
if [ -f "$SC" ]; then
    ok "TEST-001a: ${SC} exists"
else
    fail "TEST-001a: ${SC} does not exist"
fi

t001_dir="${WORK}/t001-empty"
mkdir -p "$t001_dir"
run_scan "$t001_dir"
if [ "$SCAN_EXIT" -eq 0 ]; then
    ok "TEST-001b: bash design-sync-scan.sh <dir> is directly invocable and completes (exit 0 on an empty dir)"
else
    fail "TEST-001b: expected exit 0 for a valid empty target dir, got ${SCAN_EXIT}. Output: ${SCAN_OUTPUT}"
fi

run_scan
if [ "$SCAN_EXIT" -ne 0 ]; then
    ok "TEST-001c: zero-argument invocation does not succeed (a required first positional argument exists)"
else
    fail "TEST-001c: zero-argument invocation must not succeed"
fi

echo ""
echo "=== TEST-002 (AC-002): a finding nested >=2 directories deep is detected ==="
t002_dir="${WORK}/t002"
mkdir -p "${t002_dir}/level1/level2"
printf '<html>\n<body>\n<!-- TODO: fix this nested mockup -->\n</body>\n</html>\n' \
    > "${t002_dir}/level1/level2/nested.html"
run_scan "$t002_dir"
if [ "$SCAN_EXIT" -eq 1 ]; then
    ok "TEST-002a: a finding nested two directories deep yields exit 1"
else
    fail "TEST-002a: expected exit 1, got ${SCAN_EXIT}. Output: ${SCAN_OUTPUT}"
fi
if printf '%s' "$SCAN_OUTPUT" | grep -q "level2/nested.html:3:"; then
    ok "TEST-002b: the nested finding's file:line is reported"
else
    fail "TEST-002b: nested finding file:line not reported. Output: ${SCAN_OUTPUT}"
fi

echo ""
echo "=== TEST-003 (AC-003): one invocation, no flag, flags findings from >1 category ==="
t003_dir="${WORK}/t003"
mkdir -p "$t003_dir"
printf '<html><body>\n<!-- TODO: replace -->\n<p>AKIAABCDEFGHIJKLMNOP</p>\n</body></html>\n' \
    > "${t003_dir}/mixed.html"
run_scan "$t003_dir"
if [ "$SCAN_EXIT" -eq 1 ]; then
    ok "TEST-003a: a two-category fixture, one plain invocation, exits 1"
else
    fail "TEST-003a: expected exit 1, got ${SCAN_EXIT}. Output: ${SCAN_OUTPUT}"
fi
if printf '%s' "$SCAN_OUTPUT" | grep -q "placeholder" && printf '%s' "$SCAN_OUTPUT" | grep -q "secret"; then
    ok "TEST-003b: both categories' findings appear in the one-invocation report -- no flag selected a subset"
else
    fail "TEST-003b: expected both placeholder and secret findings in output. Output: ${SCAN_OUTPUT}"
fi

echo ""
echo "=== TEST-004 (AC-004): a target dir with zero .html files exits 0, is not an error ==="
t004_dir="${WORK}/t004"
mkdir -p "$t004_dir"
printf 'not html\n' > "${t004_dir}/notes.txt"
run_scan "$t004_dir"
if [ "$SCAN_EXIT" -eq 0 ]; then
    ok "TEST-004: a target dir with zero .html files exits 0"
else
    fail "TEST-004: expected exit 0, got ${SCAN_EXIT}. Output: ${SCAN_OUTPUT}"
fi

echo ""
echo "=== TEST-085 (AC-039a): a non-.html file with secret/PII-shaped content is never scanned ==="
t085_dir="${WORK}/t085"
mkdir -p "$t085_dir"
printf '<html><body><p>clean mockup</p></body></html>\n' > "${t085_dir}/clean.html"
printf '{"key": "AKIAABCDEFGHIJKLMNOP", "email": "user@realcompany.com"}\n' > "${t085_dir}/data.json"
run_scan "$t085_dir"
if [ "$SCAN_EXIT" -eq 0 ]; then
    ok "TEST-085a: a .json fixture with secret/PII-shaped strings beside a clean .html produces no block (exit 0)"
else
    fail "TEST-085a: expected exit 0 (non-.html excluded), got ${SCAN_EXIT}. Output: ${SCAN_OUTPUT}"
fi
if ! printf '%s' "$SCAN_OUTPUT" | grep -q "data.json"; then
    ok "TEST-085b: the .json fixture is never named in the report"
else
    fail "TEST-085b: data.json must never appear in the report. Output: ${SCAN_OUTPUT}"
fi

echo ""
echo "=== TEST-086 (.sh half of AC-039b): an upper-cased .HTML file is scanned (case-insensitive extension) ==="
t086_dir="${WORK}/t086"
mkdir -p "$t086_dir"
printf '<html><body>\n<!-- TODO: uppercase extension mockup -->\n</body></html>\n' \
    > "${t086_dir}/MOCKUP.HTML"
run_scan "$t086_dir"
if [ "$SCAN_EXIT" -eq 1 ]; then
    ok "TEST-086: an upper-cased .HTML file containing a finding is scanned and blocks (extension match is case-insensitive)"
else
    fail "TEST-086: expected exit 1 for a finding inside an upper-cased .HTML file, got ${SCAN_EXIT}. Output: ${SCAN_OUTPUT}"
fi

# ============================================================================
# REQ-002 (AC-005, AC-006, AC-007, AC-008, AC-037's script-level half) --
# the three-valued, fail-closed exit-code contract
# ============================================================================

echo ""
echo "=== TEST-005 (AC-005): a fully clean fixture set exits 0 ==="
t005_dir="${WORK}/t005"
mkdir -p "${t005_dir}/sub"
printf '<html><body><p>Welcome to our product.</p></body></html>\n' > "${t005_dir}/a.html"
printf '<html><body><p>Nothing to see here.</p></body></html>\n' > "${t005_dir}/sub/b.html"
run_scan "$t005_dir"
if [ "$SCAN_EXIT" -eq 0 ]; then
    ok "TEST-005a: a fully clean multi-file fixture set exits 0"
else
    fail "TEST-005a: expected exit 0, got ${SCAN_EXIT}. Output: ${SCAN_OUTPUT}"
fi
if printf '%s' "$SCAN_OUTPUT" | grep -q "passed"; then
    ok "TEST-005b: a clean run reports passed"
else
    fail "TEST-005b: clean run should report passed. Output: ${SCAN_OUTPUT}"
fi

echo ""
echo "=== TEST-006 (AC-006.1): a placeholder-only fixture exits 1 ==="
t006_dir="${WORK}/t006"
mkdir -p "$t006_dir"
printf '<html><body>\n<!-- TODO: placeholder only -->\n</body></html>\n' > "${t006_dir}/ph.html"
run_scan "$t006_dir"
if [ "$SCAN_EXIT" -eq 1 ]; then
    ok "TEST-006a: a placeholder-only fixture exits 1"
else
    fail "TEST-006a: expected exit 1, got ${SCAN_EXIT}. Output: ${SCAN_OUTPUT}"
fi
if printf '%s' "$SCAN_OUTPUT" | grep -q "placeholder" \
    && ! printf '%s' "$SCAN_OUTPUT" | grep -qE "secret|PII"; then
    ok "TEST-006b: only the placeholder category is reported"
else
    fail "TEST-006b: expected only placeholder category. Output: ${SCAN_OUTPUT}"
fi

echo ""
echo "=== TEST-007 (AC-006.2): a secret-only fixture exits 1 ==="
t007_dir="${WORK}/t007"
mkdir -p "$t007_dir"
printf '<html><body>\n<p>AKIAABCDEFGHIJKLMNOP</p>\n</body></html>\n' > "${t007_dir}/sec.html"
run_scan "$t007_dir"
if [ "$SCAN_EXIT" -eq 1 ]; then
    ok "TEST-007a: a secret-only fixture exits 1"
else
    fail "TEST-007a: expected exit 1, got ${SCAN_EXIT}. Output: ${SCAN_OUTPUT}"
fi
if printf '%s' "$SCAN_OUTPUT" | grep -q "secret" \
    && ! printf '%s' "$SCAN_OUTPUT" | grep -qE "placeholder|PII"; then
    ok "TEST-007b: only the secret category is reported"
else
    fail "TEST-007b: expected only secret category. Output: ${SCAN_OUTPUT}"
fi

echo ""
echo "=== TEST-008 (AC-006.3): a PII-only fixture exits 1 ==="
t008_dir="${WORK}/t008"
mkdir -p "$t008_dir"
printf '<html><body>\n<p>Contact: user@realcompany.com</p>\n</body></html>\n' > "${t008_dir}/pii.html"
run_scan "$t008_dir"
if [ "$SCAN_EXIT" -eq 1 ]; then
    ok "TEST-008a: a PII-only fixture exits 1"
else
    fail "TEST-008a: expected exit 1, got ${SCAN_EXIT}. Output: ${SCAN_OUTPUT}"
fi
if printf '%s' "$SCAN_OUTPUT" | grep -q "PII" \
    && ! printf '%s' "$SCAN_OUTPUT" | grep -qE "placeholder|secret"; then
    ok "TEST-008b: only the PII category is reported"
else
    fail "TEST-008b: expected only PII category. Output: ${SCAN_OUTPUT}"
fi

echo ""
echo "=== TEST-009 (AC-006.4): a mixed-category fixture exits 1, names every category present ==="
t009_dir="${WORK}/t009"
mkdir -p "$t009_dir"
printf '<html><body>\n<!-- TODO: mixed fixture -->\n<p>API Key: AKIAABCDEFGHIJKLMNOP</p>\n<p>Contact: user@realcompany.com</p>\n</body></html>\n' \
    > "${t009_dir}/mixed.html"
run_scan "$t009_dir"
if [ "$SCAN_EXIT" -eq 1 ]; then
    ok "TEST-009a: a mixed-category fixture exits 1"
else
    fail "TEST-009a: expected exit 1, got ${SCAN_EXIT}. Output: ${SCAN_OUTPUT}"
fi
if printf '%s' "$SCAN_OUTPUT" | grep -q "placeholder" \
    && printf '%s' "$SCAN_OUTPUT" | grep -q "secret" \
    && printf '%s' "$SCAN_OUTPUT" | grep -q "PII"; then
    ok "TEST-009b: the report names every category present, not only the first matched"
else
    fail "TEST-009b: expected all three categories named. Output: ${SCAN_OUTPUT}"
fi

echo ""
echo "=== TEST-010 (AC-007.1, AC-008): zero arguments exits 2 with a usage diagnostic, never 1 ==="
run_scan
if [ "$SCAN_EXIT" -eq 2 ]; then
    ok "TEST-010a: zero arguments exits 2"
else
    fail "TEST-010a: expected exit 2, got ${SCAN_EXIT}. Output: ${SCAN_OUTPUT}"
fi
if printf '%s' "$SCAN_OUTPUT" | grep -qi "usage"; then
    ok "TEST-010b: zero-argument invocation prints a usage diagnostic"
else
    fail "TEST-010b: expected a usage diagnostic. Output: ${SCAN_OUTPUT}"
fi
if ! printf '%s' "$SCAN_OUTPUT" | grep -qi "override"; then
    ok "TEST-010c: no override affordance is offered in the exit-2 output (AC-007's fourth clause)"
else
    fail "TEST-010c: exit-2 output must not mention an override affordance. Output: ${SCAN_OUTPUT}"
fi

echo ""
echo "=== TEST-056 (AC-007.2): more arguments than the contract defines exits 2 with a usage diagnostic ==="
t056_dir="${WORK}/t056"
mkdir -p "$t056_dir"
run_scan "$t056_dir" "extra-argument"
if [ "$SCAN_EXIT" -eq 2 ]; then
    ok "TEST-056a: two positional arguments (one too many) exits 2"
else
    fail "TEST-056a: expected exit 2, got ${SCAN_EXIT}. Output: ${SCAN_OUTPUT}"
fi
if printf '%s' "$SCAN_OUTPUT" | grep -qi "usage"; then
    ok "TEST-056b: too-many-arguments invocation prints a usage diagnostic"
else
    fail "TEST-056b: expected a usage diagnostic. Output: ${SCAN_OUTPUT}"
fi
if ! printf '%s' "$SCAN_OUTPUT" | grep -qi "override"; then
    ok "TEST-056c: no override affordance is offered in the too-many-arguments exit-2 output"
else
    fail "TEST-056c: exit-2 output must not mention an override affordance. Output: ${SCAN_OUTPUT}"
fi

echo ""
echo "=== TEST-011 (AC-007.3): a nonexistent target directory exits 2, names the missing path ==="
t011_missing="${WORK}/t011-does-not-exist"
run_scan "$t011_missing"
if [ "$SCAN_EXIT" -eq 2 ]; then
    ok "TEST-011a: a nonexistent target directory exits 2"
else
    fail "TEST-011a: expected exit 2, got ${SCAN_EXIT}. Output: ${SCAN_OUTPUT}"
fi
if printf '%s' "$SCAN_OUTPUT" | grep -qF "$t011_missing"; then
    ok "TEST-011b: the diagnostic names the missing path"
else
    fail "TEST-011b: expected the missing path named. Output: ${SCAN_OUTPUT}"
fi
if ! printf '%s' "$SCAN_OUTPUT" | grep -qi "override"; then
    ok "TEST-011c: no override affordance is offered for a nonexistent target directory"
else
    fail "TEST-011c: exit-2 output must not mention an override affordance. Output: ${SCAN_OUTPUT}"
fi

echo ""
echo "=== TEST-012 (AC-007.4): an unreadable .html file exits 2, names the file, rest not silently clean ==="
t012_dir="${WORK}/t012"
mkdir -p "$t012_dir"
printf '<html><body><p>clean sibling</p></body></html>\n' > "${t012_dir}/clean.html"
printf '<html><body><p>secret content, unreadable</p></body></html>\n' > "${t012_dir}/blocked.html"
chmod 000 "${t012_dir}/blocked.html"
run_scan "$t012_dir"
if [ "$SCAN_EXIT" -eq 2 ]; then
    ok "TEST-012a: an unreadable .html file exits 2"
else
    fail "TEST-012a: expected exit 2, got ${SCAN_EXIT}. Output: ${SCAN_OUTPUT}"
fi
if printf '%s' "$SCAN_OUTPUT" | grep -q "blocked.html"; then
    ok "TEST-012b: the diagnostic names the unreadable file"
else
    fail "TEST-012b: expected the unreadable file named. Output: ${SCAN_OUTPUT}"
fi
if ! printf '%s' "$SCAN_OUTPUT" | grep -qi "passed"; then
    ok "TEST-012c: the rest of the set is not silently reported clean/passed"
else
    fail "TEST-012c: must not report a false 'passed' when a file is unreadable. Output: ${SCAN_OUTPUT}"
fi
chmod 644 "${t012_dir}/blocked.html"

echo ""
echo "=== TEST-013 (AC-008): usage-error exit code is 2, never 1 -- contrast with check-placeholders.sh ==="
cp_out=""
cp_exit=0
cp_out="$(bash "$CHECK_PLACEHOLDERS" 2>&1)" || cp_exit=$?
if [ "$cp_exit" -eq 1 ]; then
    ok "TEST-013a: check-placeholders.sh's own zero-argument usage error exits 1 (the convention this script deliberately diverges from)"
else
    fail "TEST-013a: expected check-placeholders.sh zero-arg exit 1, got ${cp_exit}. Output: ${cp_out}"
fi
run_scan
if [ "$SCAN_EXIT" -eq 2 ] && [ "$SCAN_EXIT" -ne 1 ]; then
    ok "TEST-013b: design-sync-scan.sh's own zero-argument usage error exits 2, never 1"
else
    fail "TEST-013b: expected exit 2 (never 1), got ${SCAN_EXIT}. Output: ${SCAN_OUTPUT}"
fi

# ============================================================================
# REQ-003 (AC-009, AC-010, AC-011, AC-012, AC-038's POSIX-ERE half) --
# the three detection categories' pattern catalogue
# ============================================================================

echo ""
echo "=== TEST-014 (AC-009): placeholder detection reproduces check-placeholders.sh:18-19's own verdicts ==="
cp_pattern_cs="$(grep -m1 '^pattern_cs=' "$CHECK_PLACEHOLDERS" | sed -E "s/^pattern_cs='(.*)'\$/\\1/")"
cp_pattern_ci="$(grep -m1 '^pattern_ci=' "$CHECK_PLACEHOLDERS" | sed -E "s/^pattern_ci='(.*)'\$/\\1/")"
if [ -n "$cp_pattern_cs" ] && [ -n "$cp_pattern_ci" ]; then
    ok "TEST-014-setup: re-read check-placeholders.sh's live pattern_cs/pattern_ci at test-run time (not transcribed)"
else
    fail "TEST-014-setup: could not extract pattern_cs/pattern_ci from ${CHECK_PLACEHOLDERS}"
fi
t014_pos_txt="${WORK}/t014-pos.txt"
printf 'TODO one\nFIXME two\nHACK three\nraise NotImplemented\nPLACEHOLDER five\nTODO_REPLACE_WITH_PROJECT_COMMANDS\nnot implemented seven\nlorem ipsum eight\ncoming soon nine\ndo not ship ten\ntemporary stub eleven\ndummy data twelve\n' \
    > "$t014_pos_txt"
cp_pos_exit=0
bash "$CHECK_PLACEHOLDERS" "$t014_pos_txt" >/dev/null 2>&1 || cp_pos_exit=$?
if [ "$cp_pos_exit" -eq 1 ]; then
    ok "TEST-014a: check-placeholders.sh flags the positive marker corpus (exit 1)"
else
    fail "TEST-014a: expected check-placeholders.sh exit 1 on the positive corpus, got ${cp_pos_exit}"
fi
t014_pos_dir="${WORK}/t014-pos-dir"
mkdir -p "$t014_pos_dir"
cp "$t014_pos_txt" "${t014_pos_dir}/markers.html"
run_scan "$t014_pos_dir"
if [ "$SCAN_EXIT" -eq 1 ] && printf '%s' "$SCAN_OUTPUT" | grep -q "placeholder"; then
    ok "TEST-014b: design-sync-scan.sh flags the identical corpus as a placeholder finding -- same verdict as check-placeholders.sh"
else
    fail "TEST-014b: expected exit 1 with a placeholder finding, got ${SCAN_EXIT}. Output: ${SCAN_OUTPUT}"
fi
t014_neg_txt="${WORK}/t014-neg.txt"
printf 'nothing to see here, ordinary prose about a todo list app\n' > "$t014_neg_txt"
cp_neg_exit=0
bash "$CHECK_PLACEHOLDERS" "$t014_neg_txt" >/dev/null 2>&1 || cp_neg_exit=$?
t014_neg_dir="${WORK}/t014-neg-dir"
mkdir -p "$t014_neg_dir"
cp "$t014_neg_txt" "${t014_neg_dir}/clean.html"
run_scan "$t014_neg_dir"
if [ "$cp_neg_exit" -eq 0 ] && [ "$SCAN_EXIT" -eq 0 ]; then
    ok "TEST-014c: both scripts agree the negative corpus (lowercase 'todo' as ordinary prose) is clean"
else
    fail "TEST-014c: expected both exit 0, got check-placeholders=${cp_neg_exit} design-sync-scan=${SCAN_EXIT}. Output: ${SCAN_OUTPUT}"
fi

echo ""
echo "=== TEST-015 - TEST-020, TEST-083 (AC-010): one row per secret pattern S1-S6, plus S5's sk-proj- sub-format ==="
assert_secret_hit() {
    local label="$1" content="$2"
    local d="${WORK}/secret-$(printf '%s' "$label" | tr -c 'A-Za-z0-9' '_')"
    mkdir -p "$d"
    printf '<html><body>\n%s\n</body></html>\n' "$content" > "${d}/s.html"
    run_scan "$d"
    if [ "$SCAN_EXIT" -eq 1 ] && printf '%s' "$SCAN_OUTPUT" | grep -q "secret"; then
        ok "${label}: triggers a secret finding"
    else
        fail "${label}: expected a secret finding (exit 1), got ${SCAN_EXIT}. Output: ${SCAN_OUTPUT}"
    fi
}
assert_secret_hit "TEST-015 (S1 PEM private-key header)" '-----BEGIN RSA PRIVATE KEY-----'
assert_secret_hit "TEST-016 (S2 AKIA...)" 'AKIAABCDEFGHIJKLMNOP'
assert_secret_hit "TEST-017 (S3 ghp_...)" "ghp_$(printf 'a%.0s' $(seq 1 36))"
assert_secret_hit "TEST-018 (S4 github_pat_...)" "github_pat_$(printf 'a%.0s' $(seq 1 22))"
assert_secret_hit "TEST-019 (S5 bare sk-...)" "sk-$(printf 'a%.0s' $(seq 1 20))"
assert_secret_hit "TEST-020 (S6 xoxb-...)" 'xoxb-1234567890-abcdefghij'
assert_secret_hit "TEST-083 (S5 sk-proj- sub-format)" "sk-proj-$(printf 'a%.0s' $(seq 1 20))"

echo ""
echo "=== TEST-021 (AC-010): S7 triggers on a substantive quoted value, not on a bare or empty value ==="
t021_dir="${WORK}/t021"
mkdir -p "$t021_dir"
printf '<html><body>\n<p>password: "hunter2hunter2"</p>\n</body></html>\n' > "${t021_dir}/pos.html"
run_scan "$t021_dir"
if [ "$SCAN_EXIT" -eq 1 ] && printf '%s' "$SCAN_OUTPUT" | grep -q "secret"; then
    ok "TEST-021a: S7 triggers on a keyword followed by a substantive quoted value"
else
    fail "TEST-021a: expected a secret finding, got ${SCAN_EXIT}. Output: ${SCAN_OUTPUT}"
fi
t021_neg_dir="${WORK}/t021-neg"
mkdir -p "$t021_neg_dir"
printf '<html><body>\n<p>password:</p>\n<label>Password</label>\n<input type="password">\n<p>password: ""</p>\n</body></html>\n' \
    > "${t021_neg_dir}/neg.html"
run_scan "$t021_neg_dir"
if [ "$SCAN_EXIT" -eq 0 ]; then
    ok "TEST-021b: S7 does NOT trigger on a bare keyword, a form-field label, an input type attribute, or an empty quoted value"
else
    fail "TEST-021b: expected exit 0 (no S7 false positive), got ${SCAN_EXIT}. Output: ${SCAN_OUTPUT}"
fi

echo ""
echo "=== TEST-022 (AC-011): P1 (email, non-reserved domain) triggers a PII finding ==="
t022_dir="${WORK}/t022"
mkdir -p "$t022_dir"
printf '<html><body>\n<p>Contact: user@realcompany.com</p>\n</body></html>\n' > "${t022_dir}/e.html"
run_scan "$t022_dir"
if [ "$SCAN_EXIT" -eq 1 ] && printf '%s' "$SCAN_OUTPUT" | grep -q "PII"; then
    ok "TEST-022: a non-reserved-domain email triggers a PII finding"
else
    fail "TEST-022: expected a PII finding, got ${SCAN_EXIT}. Output: ${SCAN_OUTPUT}"
fi

echo ""
echo "=== TEST-023 (AC-011): P2 (E.164-shaped phone) triggers a PII finding ==="
t023_dir="${WORK}/t023"
mkdir -p "$t023_dir"
printf '<html><body>\n<p>Call us: +12345678901</p>\n</body></html>\n' > "${t023_dir}/p.html"
run_scan "$t023_dir"
if [ "$SCAN_EXIT" -eq 1 ] && printf '%s' "$SCAN_OUTPUT" | grep -q "PII"; then
    ok "TEST-023: an E.164-shaped phone number triggers a PII finding"
else
    fail "TEST-023: expected a PII finding, got ${SCAN_EXIT}. Output: ${SCAN_OUTPUT}"
fi

echo ""
echo "=== TEST-024, TEST-057 - TEST-062 (AC-011): the seven RFC 2606/6761 reserved domains/TLDs do not trigger ==="
assert_reserved_domain_clean() {
    local label="$1" email="$2"
    local d="${WORK}/reserved-$(printf '%s' "$label" | tr -c 'A-Za-z0-9' '_')"
    mkdir -p "$d"
    printf '<html><body>\n<p>Contact: %s</p>\n</body></html>\n' "$email" > "${d}/e.html"
    run_scan "$d"
    if [ "$SCAN_EXIT" -eq 0 ]; then
        ok "${label}: ${email} does not trigger a finding"
    else
        fail "${label}: ${email} must not trigger, got exit ${SCAN_EXIT}. Output: ${SCAN_OUTPUT}"
    fi
}
assert_reserved_domain_clean "TEST-024 (example.com)"  "user@example.com"
assert_reserved_domain_clean "TEST-057 (example.net)"  "user@example.net"
assert_reserved_domain_clean "TEST-058 (example.org)"  "user@example.org"
assert_reserved_domain_clean "TEST-059 (.test)"        "user@mockups.test"
assert_reserved_domain_clean "TEST-060 (.example)"     "user@mockups.example"
assert_reserved_domain_clean "TEST-061 (.invalid)"     "user@mockups.invalid"
assert_reserved_domain_clean "TEST-062 (.localhost)"   "user@mockups.localhost"

echo ""
echo "=== TEST-080 - TEST-082 (AC-011): P2's three negative boundary shapes ==="
t080_dir="${WORK}/t080"
mkdir -p "$t080_dir"
printf '<html><body>\n<p>Ref: +1234567</p>\n</body></html>\n' > "${t080_dir}/short.html"
run_scan "$t080_dir"
if [ "$SCAN_EXIT" -eq 0 ]; then
    ok "TEST-080: a 7-digit run (one short of the minimum) does not trigger"
else
    fail "TEST-080: expected exit 0, got ${SCAN_EXIT}. Output: ${SCAN_OUTPUT}"
fi

t081_dir="${WORK}/t081"
mkdir -p "$t081_dir"
printf '<html><body>\n<p>Ref: +1234567890123456</p>\n</body></html>\n' > "${t081_dir}/long.html"
run_scan "$t081_dir"
if [ "$SCAN_EXIT" -eq 0 ]; then
    ok "TEST-081: a 16-digit run (one over the maximum) does not trigger -- the boundary rejects an embedded valid-length substring, not only the total count"
else
    fail "TEST-081: expected exit 0, got ${SCAN_EXIT}. Output: ${SCAN_OUTPUT}"
fi

# TEST-082 exercises the LEADING side of the (^|[^0-9])...([^0-9]|$) boundary,
# complementing TEST-081's trailing/quantifier-adjacent case: a digit sitting
# immediately before the required "+" defeats the match even though the
# digits after "+" are, on their own, a valid 8-15 digit run (design.md's
# dual-form block; Edge Case 8's "one more digit... on either side").
t082_dir="${WORK}/t082"
mkdir -p "$t082_dir"
printf '<html><body>\n<p>ID9+123456789 tracking number</p>\n</body></html>\n' > "${t082_dir}/adjacent.html"
run_scan "$t082_dir"
if [ "$SCAN_EXIT" -eq 0 ]; then
    ok "TEST-082: a valid-length run with a digit immediately adjacent on the leading side (before '+') does not trigger"
else
    fail "TEST-082: expected exit 0, got ${SCAN_EXIT}. Output: ${SCAN_OUTPUT}"
fi
# Sanity control: the same digits WOULD trigger without the leading-adjacent digit.
t082_ctrl_dir="${WORK}/t082-ctrl"
mkdir -p "$t082_ctrl_dir"
printf '<html><body>\n<p>ID +123456789 tracking number</p>\n</body></html>\n' > "${t082_ctrl_dir}/control.html"
run_scan "$t082_ctrl_dir"
if [ "$SCAN_EXIT" -eq 1 ]; then
    ok "TEST-082-control: without the leading-adjacent digit, the same-length run DOES trigger (proves TEST-082 exercises the boundary, not the quantifier)"
else
    fail "TEST-082-control: expected exit 1 (positive control), got ${SCAN_EXIT}. Output: ${SCAN_OUTPUT}"
fi

echo ""
echo "=== TEST-025 (AC-012): a mixed-category fixture's report labels every finding with its correct category ==="
t025_dir="${WORK}/t025"
mkdir -p "$t025_dir"
printf '<html>\n<body>\n<!-- TODO: mixed -->\n<p>AKIAABCDEFGHIJKLMNOP</p>\n<p>user@realcompany.com</p>\n</body>\n</html>\n' \
    > "${t025_dir}/mixed.html"
run_scan "$t025_dir"
if printf '%s' "$SCAN_OUTPUT" | grep -qE "placeholder[[:space:]]+.*mixed\.html:3:" \
    && printf '%s' "$SCAN_OUTPUT" | grep -qE "secret[[:space:]]+.*mixed\.html:4:" \
    && printf '%s' "$SCAN_OUTPUT" | grep -qE "PII[[:space:]]+.*mixed\.html:5:"; then
    ok "TEST-025: every finding in the mixed fixture is labelled with its correct category at its correct line"
else
    fail "TEST-025: expected placeholder@3, secret@4, PII@5, correctly labelled. Output: ${SCAN_OUTPUT}"
fi

# ============================================================================
# REQ-004 (AC-013, AC-014, AC-015) -- actionable reports that are not
# themselves a new disclosure surface
# ============================================================================

echo ""
echo "=== TEST-026 (AC-013): a multi-file fixture's report gives correct, distinct file:line per finding ==="
t026_dir="${WORK}/t026"
mkdir -p "${t026_dir}/a" "${t026_dir}/b" "${t026_dir}/c"
printf '<html>\n<body>\n<!-- TODO: file one -->\n</body>\n</html>\n' > "${t026_dir}/a/one.html"
printf '<html>\n<body>\n<p>x</p>\n<p>AKIAABCDEFGHIJKLMNOP</p>\n</body>\n</html>\n' > "${t026_dir}/b/two.html"
printf '<html>\n<body>\n<p>a</p>\n<p>b</p>\n<p>user@realcompany.com</p>\n</body>\n</html>\n' > "${t026_dir}/c/three.html"
run_scan "$t026_dir"
if [ "$SCAN_EXIT" -eq 1 ] \
    && printf '%s' "$SCAN_OUTPUT" | grep -q "a/one.html:3:" \
    && printf '%s' "$SCAN_OUTPUT" | grep -q "b/two.html:4:" \
    && printf '%s' "$SCAN_OUTPUT" | grep -q "c/three.html:5:"; then
    ok "TEST-026: each of three files' findings is reported at its own correct, distinct file:line"
else
    fail "TEST-026: expected a/one.html:3, b/two.html:4, c/three.html:5, got exit ${SCAN_EXIT}. Output: ${SCAN_OUTPUT}"
fi

echo ""
echo "=== TEST-027, TEST-028, TEST-029, TEST-063 (AC-014): masking is category-differentiated ==="
t027_dir="${WORK}/t027"
mkdir -p "$t027_dir"
printf '<html><body>\n<p>AKIAABCDEFGHIJKLMNOP</p>\n</body></html>\n' > "${t027_dir}/s.html"
run_scan "$t027_dir"
if ! printf '%s' "$SCAN_OUTPUT" | grep -q "AKIAABCDEFGHIJKLMNOP"; then
    ok "TEST-027: a secret finding's report line does not contain the matched secret value"
else
    fail "TEST-027: the matched secret value must not appear in the report. Output: ${SCAN_OUTPUT}"
fi
if printf '%s' "$SCAN_OUTPUT" | grep -q "REDACTED"; then
    ok "TEST-027b: the secret finding is masked with the fixed token"
else
    fail "TEST-027b: expected [REDACTED] in the report. Output: ${SCAN_OUTPUT}"
fi

t028_dir="${WORK}/t028"
mkdir -p "$t028_dir"
printf '<html><body>\n<p>Contact: user@realcompany.com</p>\n</body></html>\n' > "${t028_dir}/e.html"
run_scan "$t028_dir"
if ! printf '%s' "$SCAN_OUTPUT" | grep -q "user@realcompany.com"; then
    ok "TEST-028: a PII/email finding's report line does not contain the matched address"
else
    fail "TEST-028: the matched email address must not appear in the report. Output: ${SCAN_OUTPUT}"
fi

t063_dir="${WORK}/t063"
mkdir -p "$t063_dir"
printf '<html><body>\n<p>Call: +19876543210</p>\n</body></html>\n' > "${t063_dir}/p.html"
run_scan "$t063_dir"
if ! printf '%s' "$SCAN_OUTPUT" | grep -q "+19876543210"; then
    ok "TEST-063: a PII/phone finding's report line does not contain the matched number"
else
    fail "TEST-063: the matched phone number must not appear in the report. Output: ${SCAN_OUTPUT}"
fi

t029_dir="${WORK}/t029"
mkdir -p "$t029_dir"
printf '<html><body>\n<!-- TODO: keep this marker visible -->\n</body></html>\n' > "${t029_dir}/ph.html"
run_scan "$t029_dir"
if printf '%s' "$SCAN_OUTPUT" | grep -q "TODO"; then
    ok "TEST-029: a placeholder finding's report line contains the matched marker text in full"
else
    fail "TEST-029: expected the literal marker TODO in the report. Output: ${SCAN_OUTPUT}"
fi

echo ""
echo "=== TEST-030 (AC-015): the script completes with stdin closed, no interactive read, no hang ==="
t030_dir="${WORK}/t030"
mkdir -p "$t030_dir"
printf '<html><body><p>clean</p></body></html>\n' > "${t030_dir}/c.html"
( bash "$SC" "$t030_dir" </dev/null >"${WORK}/t030-out.txt" 2>&1; echo $? > "${WORK}/t030-rc.txt" ) &
t030_pid=$!
t030_waited=0
t030_done=0
while [ "$t030_waited" -lt 30 ]; do
    if ! kill -0 "$t030_pid" 2>/dev/null; then
        t030_done=1
        break
    fi
    sleep 0.1
    t030_waited=$((t030_waited + 1))
done
if [ "$t030_done" -eq 1 ]; then
    wait "$t030_pid" 2>/dev/null || true
    t030_rc="$(cat "${WORK}/t030-rc.txt" 2>/dev/null || echo 'unknown')"
    ok "TEST-030: the scan completed within 3s with stdin closed (exit ${t030_rc}) -- no interactive read, no prompt, no hang"
else
    kill -9 "$t030_pid" 2>/dev/null || true
    fail "TEST-030: the scan did not complete within 3s with stdin closed -- possible hang/interactive read"
fi

# ============================================================================
# REQ-005 (AC-018's .sh-script half) -- the script's own header states the
# egress-hygiene-only boundary
# ============================================================================

echo ""
echo "=== TEST-034 (.sh half of AC-018): the script's header comment states the egress-hygiene-only scope ==="
if [ -f "$SC" ]; then
    t034_flat="$(sed -n '1,40p' "$SC" | grep '^#' | sed 's/^#[[:space:]]*//' | tr '\n' ' ' | tr -s ' ')"
else
    t034_flat=""
fi
if printf '%s' "$t034_flat" | grep -qi "egress hygiene"; then
    ok "TEST-034a: the header states the check is limited to egress hygiene"
else
    fail "TEST-034a: header must state 'egress hygiene'. Header: ${t034_flat}"
fi
if printf '%s' "$t034_flat" | grep -qi "no assessment of mockup quality" \
    && printf '%s' "$t034_flat" | grep -qi "design fidelity" \
    && printf '%s' "$t034_flat" | grep -qi "accessibility" \
    && printf '%s' "$t034_flat" | grep -qi "design-system"; then
    ok "TEST-034b: the header states no assessment of mockup quality, design fidelity, accessibility, or design-system/ adherence"
else
    fail "TEST-034b: header must disclaim quality/fidelity/accessibility/design-system judgment. Header: ${t034_flat}"
fi

# ============================================================================
# REQ-008 (.sh half of AC-030, via TEST-048/TEST-069) -- runtime neutrality
# ============================================================================

echo ""
echo "=== TEST-048 (.sh half of AC-030): no finite-set host/tool identifier appears as a branch condition ==="
t048_bad=0
t048_bad_lines=""
while IFS= read -r line; do
    content="${line#*:}"
    trimmed="$(printf '%s' "$content" | sed -e 's/^[[:space:]]*//')"
    case "$trimmed" in
        '#'*) continue ;;
    esac
    t048_bad=1
    t048_bad_lines="${t048_bad_lines}
${line}"
done < <(grep -inE 'CLAUDE_CODE|CODEX|DesignSync|ANTHROPIC|OPENAI' "$SC" || true)
if [ "$t048_bad" -eq 0 ]; then
    ok "TEST-048: none of the finite identifier set (CLAUDE_CODE, CODEX, DesignSync, ANTHROPIC, OPENAI) appears as a branch condition outside a comment"
else
    fail "TEST-048: forbidden identifier found outside a comment:${t048_bad_lines}"
fi

echo ""
echo "=== TEST-069 (.sh half of AC-030): representative-caller parity -- Claude-Code-style vs bare-terminal/Codex-style env ==="
t069_dir="${WORK}/t069"
mkdir -p "$t069_dir"
printf '<html><body>\n<!-- TODO: caller parity fixture -->\n<p>AKIAABCDEFGHIJKLMNOP</p>\n</body></html>\n' \
    > "${t069_dir}/mixed.html"
run_scan_env "CLAUDE_CODE=1 ANTHROPIC=1" "$t069_dir"
t069_exit_a="$SCAN_EXIT"
t069_out_a="$SCAN_OUTPUT"
run_scan_env "CODEX=1" "$t069_dir"
t069_exit_b="$SCAN_EXIT"
t069_out_b="$SCAN_OUTPUT"
if [ "$t069_exit_a" -eq "$t069_exit_b" ] && [ "$t069_out_a" = "$t069_out_b" ]; then
    ok "TEST-069: the same fixture, invoked once under a Claude-Code-style env and once under a bare-terminal/Codex-style env, is exit-code- and report-identical"
else
    fail "TEST-069: caller environments diverged. A(exit=${t069_exit_a}): ${t069_out_a} | B(exit=${t069_exit_b}): ${t069_out_b}"
fi

# ============================================================================
# REQ-010 (AC-034, this task's initial contribution) -- traceability manifest
# ============================================================================

echo ""
echo "=== TEST-052 (AC-034): traceability manifest -- every REQ-001..REQ-009 AC-NNN heading appears in acceptance-tests.md's AC column ==="
t052_ac_list="$(awk '
    /^### REQ-[0-9]+/ {
        match($0, /REQ-[0-9]+/); req = substr($0, RSTART, RLENGTH); next
    }
    /^#### AC-[0-9]+/ {
        match($0, /AC-[0-9]+/); ac = substr($0, RSTART, RLENGTH);
        if (req != "" && req != "REQ-010") print ac;
    }
' "$REQUIREMENTS_MD" | sort -u)"
if [ -n "$t052_ac_list" ]; then
    ok "TEST-052-setup: extracted $(printf '%s\n' "$t052_ac_list" | wc -l | tr -d ' ') AC headings from requirements.md's REQ-001..REQ-009 sections"
else
    fail "TEST-052-setup: extracted zero AC headings from ${REQUIREMENTS_MD} -- the manifest check itself is broken"
fi
t052_missing=""
while IFS= read -r t052_ac; do
    [ -z "$t052_ac" ] && continue
    if ! grep -q "$t052_ac" "$ACCEPTANCE_TESTS_MD"; then
        t052_missing="${t052_missing} ${t052_ac}"
    fi
done <<EOF
$t052_ac_list
EOF
if [ -z "$t052_missing" ]; then
    ok "TEST-052: every REQ-001..REQ-009 AC-NNN heading in requirements.md appears at least once in acceptance-tests.md"
else
    fail "TEST-052: AC(s) missing from acceptance-tests.md's AC column:${t052_missing}"
fi

# ============================================================================
# T-003 -- REQ-002 (AC-037), REQ-004 (AC-016), REQ-005 (AC-017, AC-018's
# SKILL.md half, AC-019), REQ-006 (AC-020-AC-025), REQ-007 (AC-026-AC-028) --
# design-sync-loop/SKILL.md step 5's activation and the Design-Source
# record's two new fields (Egress-Scan, Egress-Scan-At). Document-
# conformance rows (parse/read SKILL.md text, no script execution), plus one
# baseline-relative regression (TEST-046) run directly against the
# pre-existing tests/design-system-contract.tests.sh suite this task does
# not edit. Positional/structural technique (TEST-035, TEST-045) mirrors
# design-sync-consent's TEST-010/TEST-014 (tests/design-system-contract.
# tests.sh), per acceptance-tests.md's own Test Details for these rows.
#
# Baseline preservation (tasks.md Global Constraints): SKILL.md steps 1-4,
# 6-7, "## Capability Detection", "## Ensure design-system/", "##
# Boundaries", and the five existing Design-Source field rows (Egress-
# Consent, Egress-Consent-Scope, Egress-Consent-Subject, Egress-Destination,
# Egress-Consent-Expiry) are untouched by this task's SKILL.md edit -- the
# rows below verify only step 5's new content and the two new field rows,
# never re-assert content this task did not change.
# ============================================================================

DSL="${REPO_ROOT}/plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md"

# Collapse text to one whitespace-normalized line so a multi-word phrase
# assertion is not defeated by Markdown's ordinary prose line-wrapping --
# the same technique tests/design-system-contract.tests.sh's flatten_file
# establishes, redefined here (not imported) since this suite is append-
# only and self-contained.
t003_flatten_file() {
    [ -f "$1" ] || return 1
    tr '\n' ' ' <"$1" | tr -s '[:space:]' ' '
}

# Lines from the first line matching $2 (inclusive) up to, but excluding,
# the first later line matching $3, from file $1.
t003_section_between() {
    awk -v start="$2" -v end="$3" '
        $0 ~ start { flag = 1 }
        flag && $0 ~ end && $0 !~ start { exit }
        flag { print }
    ' "$1" 2>/dev/null
}

DSL_FLAT="$(t003_flatten_file "$DSL")"
DSL_LOOP_SECTION="$(t003_section_between "$DSL" '^## Loop$' '^## ')"
DSL_LOOP_FLAT="$(printf '%s\n' "$DSL_LOOP_SECTION" | tr '\n' ' ' | tr -s '[:space:]' ' ')"

# First line number (1-based, within $DSL_LOOP_SECTION) matching regex $1.
t003_loop_line_of() {
    printf '%s\n' "$DSL_LOOP_SECTION" | grep -n -iE "$1" | head -1 | cut -d: -f1
}

echo ""
echo "=== TEST-031 (AC-016): step 5 names the script, the target dir, and states exit-1 presents findings before any push ==="
if printf '%s' "$DSL_FLAT" | grep -Eq 'design-sync-scan\.sh' \
    && printf '%s' "$DSL_FLAT" | grep -Fq 'specs/<feature>/mockups/' \
    && printf '%s' "$DSL_FLAT" | grep -Fq 'present the findings report to the human before any push is attempted' \
    && printf '%s' "$DSL_FLAT" | grep -Fq 'no push occurs without that presentation'; then
    ok "TEST-031: step 5 names design-sync-scan.sh and specs/<feature>/mockups/, and states exit-1 presents findings before any push"
else
    fail "TEST-031: step 5 must name the script, the target dir, and state exit-1 presents findings before push"
fi

echo ""
echo "=== TEST-032 (AC-017): the exit-0 branch states direct continuation to 6, no additional prompt, no delay beyond scan run time ==="
if printf '%s' "$DSL_FLAT" | grep -Fq 'continue directly to 6' \
    && printf '%s' "$DSL_FLAT" | grep -Fq 'No additional prompt' \
    && printf '%s' "$DSL_FLAT" | grep -Fq 'no delay beyond the scan' \
    && printf '%s' "$DSL_FLAT" | grep -Fq "own run time"; then
    ok "TEST-032: exit 0 states direct continuation to step 6, no additional prompt, no delay beyond the scan's own run time"
else
    fail "TEST-032: exit-0 branch must state direct continuation, no prompt, no delay beyond the scan's own run time"
fi

echo ""
echo "=== TEST-033 (AC-018, SKILL.md half): the skill text states the check is egress-hygiene-only, no quality judgment ==="
if printf '%s' "$DSL_FLAT" | grep -Fiq 'egress hygiene' \
    && printf '%s' "$DSL_FLAT" | grep -Fiq 'no assessment of mockup quality' \
    && printf '%s' "$DSL_FLAT" | grep -Fiq 'design fidelity' \
    && printf '%s' "$DSL_FLAT" | grep -Fiq 'accessibility' \
    && printf '%s' "$DSL_FLAT" | grep -Fiq 'design-system'; then
    ok "TEST-033: SKILL.md states the check is limited to egress hygiene and makes no quality/fidelity/accessibility/design-system judgment"
else
    fail "TEST-033: SKILL.md must state the egress-hygiene-only boundary in its own words"
fi

echo ""
echo "=== TEST-035 (AC-019, structural): the Loop's step order is unchanged -- generate -> consent -> check point -> push -> review, cycle to 2 ==="
t035_s1=$(t003_loop_line_of '^1\. \*\*Select project')
t035_s2=$(t003_loop_line_of '^2\. \*\*Generate mockups')
t035_s3=$(t003_loop_line_of '^3\. \*\*Resolve egress consent')
t035_s4=$(t003_loop_line_of '^4\. \*\*Obtain informed consent')
t035_s5=$(t003_loop_line_of '^5\. \*\*Pre-upload check point')
t035_s6=$(t003_loop_line_of '^6\. \*\*Push')
t035_s7=$(t003_loop_line_of '^7\. \*\*Review in the claude\.ai')
if [ -n "$t035_s1" ] && [ -n "$t035_s2" ] && [ -n "$t035_s3" ] && [ -n "$t035_s4" ] \
    && [ -n "$t035_s5" ] && [ -n "$t035_s6" ] && [ -n "$t035_s7" ] \
    && [ "$t035_s1" -lt "$t035_s2" ] && [ "$t035_s2" -lt "$t035_s3" ] && [ "$t035_s3" -lt "$t035_s4" ] \
    && [ "$t035_s4" -lt "$t035_s5" ] && [ "$t035_s5" -lt "$t035_s6" ] && [ "$t035_s6" -lt "$t035_s7" ] \
    && printf '%s' "$DSL_LOOP_FLAT" | grep -Eq 'return to 2\b' \
    && ! printf '%s' "$DSL_LOOP_FLAT" | grep -Eq 'return to 3\b'; then
    ok "TEST-035: the Loop's seven numbered steps retain their relative order, and the cycle at 7 returns to 2, not 3"
else
    fail "TEST-035: step order or the regeneration cycle target changed. lines: 1=${t035_s1} 2=${t035_s2} 3=${t035_s3} 4=${t035_s4} 5=${t035_s5} 6=${t035_s6} 7=${t035_s7}"
fi

echo ""
echo "=== TEST-036 (AC-020): an explicit override affordance is stated; absent it, no push occurs -- silence/non-response/agent judgment is not an override ==="
if printf '%s' "$DSL_FLAT" | grep -Fiq 'explicit human override' \
    && printf '%s' "$DSL_FLAT" | grep -Fq 'Absent an explicit override' \
    && printf '%s' "$DSL_FLAT" | grep -Fq 'silence' \
    && printf '%s' "$DSL_FLAT" | grep -Fq 'non-response' \
    && printf '%s' "$DSL_FLAT" | grep -Fq "own judgment" \
    && printf '%s' "$DSL_FLAT" | grep -Fq 'never an override' \
    && printf '%s' "$DSL_FLAT" | grep -Fq 'no push occurs'; then
    ok "TEST-036: an explicit override affordance is stated; silence, non-response, or agent judgment is never an override, and absent it no push occurs"
else
    fail "TEST-036: the override affordance and its negative (no explicit approval -> no push) must both be stated"
fi

echo ""
echo "=== TEST-037 (AC-021.1): a fresh scan after regeneration requires its own override decision -- a prior override does not carry forward ==="
if printf '%s' "$DSL_FLAT" | grep -Fq 'fresh scan after any regeneration requires its own override decision'; then
    ok "TEST-037: a fresh scan after any regeneration is stated to require its own override decision"
else
    fail "TEST-037: step 5 must state that a fresh scan after regeneration requires its own override decision"
fi

echo ""
echo "=== TEST-038 (AC-021.2): this holds even when the new scan reproduces IDENTICAL findings -- recurrence is not evidence the human need not be asked again ==="
if printf '%s' "$DSL_FLAT" | grep -Fq 'reproduces findings identical to the ones already overridden'; then
    ok "TEST-038: the no-carry-forward rule is stated to hold even for identical findings, not only different ones"
else
    fail "TEST-038: step 5 must state the no-carry-forward rule holds even when findings are identical to a prior override"
fi

echo ""
echo "=== TEST-039 (AC-022.1): an override is stated to record Egress-Scan: overridden ==="
if printf '%s' "$DSL_FLAT" | grep -Fq 'Egress-Scan: overridden'; then
    ok "TEST-039: step 5 states an override records Egress-Scan: overridden"
else
    fail "TEST-039: step 5 must state Egress-Scan: overridden is recorded on override"
fi

echo ""
echo "=== TEST-040 (AC-022.2): a clean scan is stated to record Egress-Scan: clean ==="
if printf '%s' "$DSL_FLAT" | grep -Fq 'Egress-Scan: clean'; then
    ok "TEST-040: step 5 states a clean scan records Egress-Scan: clean"
else
    fail "TEST-040: step 5 must state Egress-Scan: clean is recorded on a clean scan"
fi

echo ""
echo "=== TEST-041 (AC-023, clean value): Egress-Scan-At (ISO-8601) is stated for the clean branch ==="
if printf '%s' "$DSL_FLAT" | grep -Eq 'Egress-Scan: clean.{0,120}ISO-8601'; then
    ok "TEST-041: the clean branch states Egress-Scan-At as an ISO-8601 timestamp"
else
    fail "TEST-041: the clean branch must state Egress-Scan-At (ISO-8601)"
fi

echo ""
echo "=== TEST-064 (AC-023, overridden value): Egress-Scan-At (ISO-8601) is stated for the overridden branch too, not only the exceptional one ==="
if printf '%s' "$DSL_FLAT" | grep -Eq 'Egress-Scan: overridden.{0,120}ISO-8601'; then
    ok "TEST-064: the overridden branch also states Egress-Scan-At as an ISO-8601 timestamp"
else
    fail "TEST-064: the overridden branch must state Egress-Scan-At (ISO-8601), not only the clean branch"
fi

echo ""
echo "=== TEST-042, TEST-065 - TEST-068 (AC-024): the five existing Design-Source field names are present, unrenamed, unredefined ==="
assert_field_row_present() {
    local label="$1" row="$2"
    if grep -Fq -- "$row" "$DSL"; then
        ok "${label}: the field row ${row} is present, unrenamed"
    else
        fail "${label}: expected the unmodified field row ${row} in ${DSL}"
    fi
}
assert_field_row_present "TEST-042 (Egress-Consent)"          '| `Egress-Consent` |'
assert_field_row_present "TEST-065 (Egress-Consent-Scope)"    '| `Egress-Consent-Scope` |'
assert_field_row_present "TEST-066 (Egress-Consent-Subject)"  '| `Egress-Consent-Subject` |'
assert_field_row_present "TEST-067 (Egress-Destination)"      '| `Egress-Destination` |'
assert_field_row_present "TEST-068 (Egress-Consent-Expiry)"   '| `Egress-Consent-Expiry` |'

echo ""
echo "=== TEST-043 (AC-025): on decline, no push, nothing written to Design-Source as an override, remediate before rescan -- distinguished from Egress-Consent's decline/withdrawal ==="
if printf '%s' "$DSL_FLAT" | grep -Fq 'nothing is written to' \
    && printf '%s' "$DSL_FLAT" | grep -Fq 'Design-Source' \
    && printf '%s' "$DSL_FLAT" | grep -Fq 'as an override' \
    && printf '%s' "$DSL_FLAT" | grep -Fiq 'remediates the flagged mockups' \
    && printf '%s' "$DSL_FLAT" | grep -Fq 'distinct from' \
    && printf '%s' "$DSL_FLAT" | grep -Fq "decline or withdrawal"; then
    ok "TEST-043: the decline outcome (no push, nothing written as override, remediate) is stated and distinguished from Egress-Consent's own decline/withdrawal vocabulary"
else
    fail "TEST-043: the decline outcome must be stated in full and distinguished from Egress-Consent's decline/withdrawal vocabulary"
fi

echo ""
echo "=== TEST-044 (AC-026): step 5 remains the single named point -- not duplicated, not relocated relative to steps 4 and 6 ==="
t044_count=$(grep -cE '^5\. \*\*Pre-upload check point' "$DSL")
t044_s4=$(t003_loop_line_of '^4\. \*\*Obtain informed consent')
t044_s5=$(t003_loop_line_of '^5\. \*\*Pre-upload check point')
t044_s6=$(t003_loop_line_of '^6\. \*\*Push')
if [ "$t044_count" -eq 1 ] && [ -n "$t044_s4" ] && [ -n "$t044_s5" ] && [ -n "$t044_s6" ] \
    && [ "$t044_s4" -lt "$t044_s5" ] && [ "$t044_s5" -lt "$t044_s6" ]; then
    ok "TEST-044: step 5 appears exactly once, still positioned between steps 4 and 6"
else
    fail "TEST-044: step 5 must appear exactly once and stay positioned between steps 4 and 6. count=${t044_count} s4=${t044_s4} s5=${t044_s5} s6=${t044_s6}"
fi

echo ""
echo "=== TEST-045 (AC-027, positional): no route from generation to push (write_files) in the Loop's text reaches push without passing step 5's position first ==="
test_045_no_bypass() {
    cp_line=$(t003_loop_line_of '^5\. \*\*Pre-upload check point')
    [ -n "$cp_line" ] || return 1
    upload_lines=$(printf '%s\n' "$DSL_LOOP_SECTION" | grep -n -E 'write_files' | cut -d: -f1)
    [ -n "$upload_lines" ] || return 1
    for l in $upload_lines; do
        [ "$l" -ge "$cp_line" ] || return 1
    done
    return 0
}
if test_045_no_bypass; then
    ok "TEST-045: every write_files mention in the Loop's text sits at or after step 5's position -- no described route bypasses it"
else
    fail "TEST-045: a write_files mention sits before step 5's position -- the text describes a bypass"
fi

echo ""
echo "=== TEST-046 (AC-028, baseline-relative regression): tests/design-system-contract.tests.sh introduces zero new failures vs its documented baseline ==="
DSC_SH="${REPO_ROOT}/tests/design-system-contract.tests.sh"
DSC_BASELINE_SH="${REPO_ROOT}/specs/design-sync-scan/verification/T-003/dsc-baseline.sh.log"
t046_no_green_to_red_flip() {
    local baseline_log="$1" current_output="$2"
    [ -f "$baseline_log" ] || return 1
    local flipped=0 line
    while IFS= read -r line; do
        case "$line" in
        "PASS: DS-"* | "PASS: TEST-"*)
            printf '%s\n' "$current_output" | grep -Fxq -- "$line" || flipped=1
            ;;
        esac
    done < "$baseline_log"
    [ "$flipped" -eq 0 ]
}
DSC_CURRENT_SH="$(bash "$DSC_SH" 2>&1)" || true
if t046_no_green_to_red_flip "$DSC_BASELINE_SH" "$DSC_CURRENT_SH" \
    && printf '%s\n' "$DSC_CURRENT_SH" | grep -Eq '^PASS: TEST-010 ' \
    && printf '%s\n' "$DSC_CURRENT_SH" | grep -Eq '^PASS: TEST-015 ' \
    && printf '%s\n' "$DSC_CURRENT_SH" | grep -Eq '^PASS: TEST-018 ' \
    && printf '%s\n' "$DSC_CURRENT_SH" | grep -Eq '^PASS: TEST-026 ' \
    && printf '%s\n' "$DSC_CURRENT_SH" | grep -Eq '^PASS: TEST-040 '; then
    ok "TEST-046: tests/design-system-contract.tests.sh has zero new failures against its documented baseline (TEST-010/015/018/026/040 re-verified passing; TEST-039 remains its pre-existing designed red)"
else
    fail "TEST-046: tests/design-system-contract.tests.sh regressed -- a baseline-green row is no longer green, or one of TEST-010/015/018/026/040 is no longer passing"
fi

echo ""
echo "=== TEST-055 (AC-037): the skill states the exit-2 branch is unconditionally blocking, with no override affordance offered at all ==="
if printf '%s' "$DSL_FLAT" | grep -Fiq 'unconditionally blocking' \
    && printf '%s' "$DSL_FLAT" | grep -Fiq 'no override affordance' \
    && printf '%s' "$DSL_FLAT" | grep -Fiq 'offered at all' \
    && printf '%s' "$DSL_FLAT" | grep -Fiq 'tool failure'; then
    ok "TEST-055: the exit-2 branch is stated as unconditionally blocking with no override affordance offered at all, worded as a tool failure"
else
    fail "TEST-055: the exit-2 branch must state it is unconditionally blocking with no override affordance at all"
fi

# ============================================================================
# T-004 -- REQ-008 (AC-029) -- claude-design-workflow.md documents the
# standalone/Codex scan usage ahead of the manual fallback it describes.
# Document conformance (real read), the medium tier's required-check set
# (risk-gate-matrix.md) -- no independent review / traceability evidence
# mandated at this tier. This is the last content-adding task in this
# suite's Shared-Suite Append Discipline (tasks.md Global Constraints); with
# this block landed, AC-034's full "both suite files together cover
# REQ-001 through REQ-009" claim is satisfiable for the first time, and
# T-001's TEST-052 traceability-manifest check above is re-run at this
# point and recorded passing (tasks.md T-004 Done-When).
#
# Reuses t003_flatten_file (defined above, in T-003's block) -- a generic
# whitespace-flatten utility, not itself part of T-003's byte-unchanged
# assertion content, so calling it here does not modify that block.
# ============================================================================

CDW="${REPO_ROOT}/plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/references/claude-design-workflow.md"

CDW_FLAT="$(t003_flatten_file "$CDW")"

echo ""
echo "=== TEST-047 (AC-029): claude-design-workflow.md documents standalone design-sync-scan usage ahead of the manual fallback it describes ==="
if printf '%s' "$CDW_FLAT" | grep -Fq 'design-sync-scan.sh' \
    && printf '%s' "$CDW_FLAT" | grep -Fq 'design-sync-scan.ps1' \
    && printf '%s' "$CDW_FLAT" | grep -Fq 'specs/<feature>/mockups/' \
    && printf '%s' "$CDW_FLAT" | grep -Fq 'no Claude Code-specific tool' \
    && printf '%s' "$CDW_FLAT" | grep -Fq 'no deferred-tool search' \
    && printf '%s' "$CDW_FLAT" | grep -Fq 'no DesignSync capability' \
    && printf '%s' "$CDW_FLAT" | grep -Fq 'as a precondition'; then
    ok "TEST-047: claude-design-workflow.md names both scripts, the required target-directory argument, and states no Claude Code-specific tool/deferred-tool search/DesignSync capability is a precondition"
else
    fail "TEST-047: claude-design-workflow.md must name design-sync-scan.sh/.ps1, specs/<feature>/mockups/, and state no Claude Code-specific tool/deferred-tool search/DesignSync capability is a precondition"
fi

# ============================================================================
# Summary
# ============================================================================

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "${FAIL}" -gt 0 ]; then
    exit 1
fi
exit 0
