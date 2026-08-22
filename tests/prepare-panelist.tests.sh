#!/usr/bin/env bash
# prepare-panelist.tests.sh — TDD tests for prepare-panelist-input.sh (AC-005)
# Style: mirrors cross-model.tests.sh (ok/fail counters, mktemp fixtures, exits 1 on failure)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="${REPO_ROOT}/plugins/sdd-quality-loop/scripts"
PASS=0
FAIL=0

ok()   { echo "ok: $*";   PASS=$((PASS+1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# ============================================================================
# Helpers
# ============================================================================

# Run prepare-panelist-input.sh capturing both stdout+stderr and exit code.
# Usage: run_prepare [args...]  →  sets $PP_OUTPUT and $PP_EXIT
run_prepare() {
    PP_EXIT=0
    PP_OUTPUT=$(bash "${SCRIPTS_DIR}/prepare-panelist-input.sh" "$@" 2>&1) || PP_EXIT=$?
}

# Hermetic key for fixtures that assume NO consent. Such fixtures pass no
# --project-root, so the script walks up from CWD and can find an operator's
# live SDD_SUDO token at the real repo root — which ~/.sdd/sudo-key would
# legitimately verify, granting consent and breaking the fixture assumption.
# Prefixing run_prepare with SDD_SUDO_KEY="$DUMMY_SUDO_KEY" wins the script's
# key-resolution order, so no real token can ever verify during the fixture;
# SDD_SUDO_SKIP_SIG=0 shields against the skip flag leaking in from the env.
DUMMY_SUDO_KEY="0000000000000000000000000000000000000000000000000000000000000000"

# Write a minimal tasks.md with Cross-Model: enabled for a task
write_tasks_with_consent() {
    local path="$1"
    local task_id="${2:-T-004}"
    mkdir -p "$(dirname "$path")"
    cat > "$path" <<EOF
# Tasks

## ${task_id} Some Task

Status: Planned
Risk: high
Cross-Model: enabled
EOF
}

# Write a minimal tasks.md WITHOUT consent
write_tasks_no_consent() {
    local path="$1"
    local task_id="${2:-T-004}"
    mkdir -p "$(dirname "$path")"
    cat > "$path" <<EOF
# Tasks

## ${task_id} Some Task

Status: Planned
Risk: high
EOF
}

# Write an input file containing planted secrets + absolute path + private URL
write_input_with_secrets() {
    local path="$1"
    mkdir -p "$(dirname "$path")"
    cat > "$path" <<'EOF'
# Design Review Input

## Feature: cross-model-verification

This feature implements a consent gate for panelist input preparation.

## Code Snippet

def get_client():
    # Normal code
    api_url = "https://api.example.com/v1/completions"
    return api_url

## Environment Configuration

AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
OPENAI_API_KEY=sk-proj-abc123def456ghi789jkl012mno345pqr678stu901vwx234
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
PRIVATE_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
DB_PASSWORD=supersecretpassword123!

## File Paths

Config loaded from /Users/alice/projects/myapp/config.json
Log output to /home/bob/.local/share/myapp/debug.log
Keys stored in C:\Users\charlie\AppData\Roaming\myapp\keys

## Private URLs

See internal doc at http://internal.corp.example.com/docs/secret
Also http://192.168.1.100/admin for local admin

## Normal Content

The implementation uses sha256 for digest computation.
All panelists receive the same sanitized input bundle.
EOF
}

# Write a clean input file (no secrets)
write_clean_input() {
    local path="$1"
    mkdir -p "$(dirname "$path")"
    cat > "$path" <<'EOF'
# Design Review Input

## Feature: cross-model-verification

This feature implements a consent gate for panelist input preparation.

The implementation uses sha256 for digest computation.
All panelists receive the same sanitized input bundle.
EOF
}

# ── TEST-013..017/032 helpers (REQ-003, declared-outputs completeness) ──────

# Portable SHA-256 of a file, for building "## Outputs" table fixture rows.
sha256_of() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

# A 64-hex string guaranteed not to equal any real SHA-256 digest used below
# (all lowercase 'f', never produced by sha256_of).
wrong_hash() { printf 'f%.0s' $(seq 1 64); }

# ── TEST-051..055 helpers (per-file elision) ─────────────────────────────────

# Write a deterministic filler file with exactly $2 lines, each of the form
# "<prefix> line NNNN filler filler filler filler". Used to build oversized
# evidence-log/spec-doc/source-file fixtures with byte counts computable
# independently of the elision code under test (via plain head/tail/wc, the
# same primitives the production elision logic itself is built from — not a
# re-implementation of its byte-accounting).
# Usage: write_filler_lines <path> <line_count> <prefix>
write_filler_lines() {
    local path="$1" count="$2" prefix="$3"
    mkdir -p "$(dirname "$path")"
    : > "$path"
    local i=1
    while [ "$i" -le "$count" ]; do
        printf '%s line %04d filler filler filler filler\n' "$prefix" "$i" >> "$path"
        i=$((i + 1))
    done
}

# ── TEST-057..062 helpers (contract-declared evidence) ──────────────────────

# Write a minimal <task_id>.contract.json fixture at
# <specs_dir>/verification/<task_id>.contract.json. Args come FOUR at a time
# per check: <id> <evidence> <red_evidence> <green_evidence> (any of the
# latter three may be "" — a real contract carries mostly-empty evidence
# fields on unrequired/waived checks, which is the norm this fixture
# reproduces). Positional groups, not a tab-joined single string per row,
# deliberately — bash's IFS-whitespace word-splitting collapses consecutive
# tabs (and strips a trailing one), which would silently swallow the empty
# fields this fixture exists to represent.
# Usage: write_contract <specs_dir> <task_id> \
#            <id> <evidence> <red_evidence> <green_evidence> [...]
write_contract() {
    local specdir="$1" task_id="$2"
    shift 2
    mkdir -p "${specdir}/verification"
    {
        printf '{\n  "task_id": "%s",\n  "checks": [\n' "$task_id"
        local first=1 cid evid red green
        while [ "$#" -ge 4 ]; do
            cid="$1" evid="$2" red="$3" green="$4"
            shift 4
            if [ "$first" -eq 1 ]; then first=0; else printf ',\n'; fi
            printf '    {"id": "%s", "evidence": "%s", "red_evidence": "%s", "green_evidence": "%s"}' \
                "$cid" "$evid" "$red" "$green"
        done
        printf '\n  ]\n}\n'
    } > "${specdir}/verification/${task_id}.contract.json"
}

# Write an implementation report fixture at
# <project_root>/reports/implementation/<feature>/<task_id>.md with an
# "## Outputs" table. Each remaining arg is one row as "path<TAB>hash".
# Usage: write_impl_report <project_root> <feature> <task_id> <row> [<row> ...]
write_impl_report() {
    local root="$1" feature="$2" task_id="$3"
    shift 3
    local dir="${root}/reports/implementation/${feature}"
    mkdir -p "$dir"
    {
        printf '# Implementation Report: %s\n\n' "$task_id"
        printf '## Outputs\n\n'
        printf '| Path | SHA-256 |\n'
        printf '|---|---|\n'
        local row rpath rhash
        for row in "$@"; do
            rpath="${row%%$'\t'*}"
            rhash="${row#*$'\t'}"
            printf '| `%s` | `%s` |\n' "$rpath" "$rhash"
        done
        printf '\n## Test Evidence\n\nN/A (fixture).\n'
    } > "${dir}/${task_id}.md"
}

# ── TEST-039..044 helpers (declaration-commit fallback for shared/living
# files, drifted after the implementation report was written) ──────────────

# Initialize a real git repo at $1, hermetic from ambient operator identity/
# signing config so the fixture's commits never depend on it.
git_init_scratch_repo() {
    local root="$1"
    mkdir -p "$root"
    git -C "$root" init -q
    git -C "$root" config user.email "test@example.invalid"
    git -C "$root" config user.name "Prepare Panelist Test"
    git -C "$root" config commit.gpgsign false
}

# ============================================================================
# PP-001: No consent → fail closed (no tasks.md flag, no SDD_SUDO)
# ============================================================================

echo "=== PP-001: Fail closed — no consent ==="

mkdir -p "${WORK}/pp001"
write_tasks_no_consent "${WORK}/pp001/tasks.md"
write_clean_input "${WORK}/pp001/input.txt"
OUT_FILE="${WORK}/pp001/out.txt"

PP_EXIT=0
SDD_SUDO_KEY="$DUMMY_SUDO_KEY" SDD_SUDO_SKIP_SIG=0 run_prepare \
    --task T-004 \
    --feature cross-model-verification \
    --input "${WORK}/pp001/input.txt" \
    --tasks-file "${WORK}/pp001/tasks.md" \
    --out "$OUT_FILE"

if [ "${PP_EXIT}" -ne 0 ]; then
    ok "PP-001a: no consent → non-zero exit (${PP_EXIT})"
else
    fail "PP-001a: no consent should exit non-zero, got 0"
fi

if [ ! -f "$OUT_FILE" ]; then
    ok "PP-001b: no consent → output file NOT created"
else
    fail "PP-001b: output file must NOT be created without consent"
fi

if echo "${PP_OUTPUT}" | grep -qi "consent"; then
    ok "PP-001c: error message mentions consent"
else
    fail "PP-001c: error message should mention 'consent', got: ${PP_OUTPUT}"
fi

# ============================================================================
# PP-002: Consent via tasks.md flag → success + secrets stripped
# ============================================================================

echo "=== PP-002: Consent via tasks.md flag + secret sanitization ==="

mkdir -p "${WORK}/pp002"
write_tasks_with_consent "${WORK}/pp002/tasks.md"
write_input_with_secrets "${WORK}/pp002/input.txt"
OUT_FILE="${WORK}/pp002/out.txt"

PP_EXIT=0
run_prepare \
    --task T-004 \
    --feature cross-model-verification \
    --input "${WORK}/pp002/input.txt" \
    --tasks-file "${WORK}/pp002/tasks.md" \
    --out "$OUT_FILE"

if [ "${PP_EXIT}" -eq 0 ]; then
    ok "PP-002a: consent present → exit 0"
else
    fail "PP-002a: consent present should exit 0, got ${PP_EXIT}. Output: ${PP_OUTPUT}"
fi

if [ -f "$OUT_FILE" ]; then
    ok "PP-002b: output file created"
else
    fail "PP-002b: output file not created. Output: ${PP_OUTPUT}"
    # Skip remaining checks
fi

if [ -f "$OUT_FILE" ]; then
    # Check that secrets are NOT in the output
    if ! grep -q "wJalrXUtnFEMI" "$OUT_FILE"; then
        ok "PP-002c: AWS_SECRET_ACCESS_KEY value stripped"
    else
        fail "PP-002c: AWS_SECRET_ACCESS_KEY value found in output — SECRET LEAK"
    fi

    if ! grep -q "sk-proj-abc123" "$OUT_FILE"; then
        ok "PP-002d: OPENAI_API_KEY value stripped"
    else
        fail "PP-002d: OPENAI_API_KEY value found in output — SECRET LEAK"
    fi

    if ! grep -q "AKIAIOSFODNN7EXAMPLE" "$OUT_FILE"; then
        ok "PP-002e: AWS_ACCESS_KEY_ID value stripped"
    else
        fail "PP-002e: AWS_ACCESS_KEY_ID value found in output — SECRET LEAK"
    fi

    if ! grep -q "ghp_xxxxxxxxxxxx" "$OUT_FILE"; then
        ok "PP-002f: PRIVATE_TOKEN (GitHub PAT) value stripped"
    else
        fail "PP-002f: GitHub PAT found in output — SECRET LEAK"
    fi

    if ! grep -q "supersecretpassword123" "$OUT_FILE"; then
        ok "PP-002g: DB_PASSWORD value stripped"
    else
        fail "PP-002g: DB_PASSWORD value found in output — SECRET LEAK"
    fi

    # Check absolute paths are removed/masked
    if ! grep -q "/Users/alice" "$OUT_FILE"; then
        ok "PP-002h: absolute Unix path /Users/... stripped"
    else
        fail "PP-002h: absolute Unix path /Users/... found in output — PATH LEAK"
    fi

    if ! grep -q "/home/bob" "$OUT_FILE"; then
        ok "PP-002i: absolute Unix path /home/... stripped"
    else
        fail "PP-002i: absolute Unix path /home/... found in output — PATH LEAK"
    fi

    # Check private URL removed/masked
    if ! grep -q "internal.corp.example.com" "$OUT_FILE"; then
        ok "PP-002j: private URL stripped"
    else
        fail "PP-002j: private URL found in output — URL LEAK"
    fi

    if ! grep -q "192.168.1.100" "$OUT_FILE"; then
        ok "PP-002k: private IP URL stripped"
    else
        fail "PP-002k: private IP URL found in output — URL LEAK"
    fi

    # Normal content should still be present
    if grep -q "sha256" "$OUT_FILE"; then
        ok "PP-002l: normal content preserved"
    else
        fail "PP-002l: normal content should remain in sanitized output"
    fi
fi

# ============================================================================
# PP-003: input_digest is 64-hex and printed to stdout
# ============================================================================

echo "=== PP-003: input_digest deterministic and 64-hex ==="

mkdir -p "${WORK}/pp003"
write_tasks_with_consent "${WORK}/pp003/tasks.md"
write_clean_input "${WORK}/pp003/input.txt"
OUT_FILE="${WORK}/pp003/out.txt"

PP_EXIT=0
run_prepare \
    --task T-004 \
    --feature cross-model-verification \
    --input "${WORK}/pp003/input.txt" \
    --tasks-file "${WORK}/pp003/tasks.md" \
    --out "$OUT_FILE"

if [ "${PP_EXIT}" -eq 0 ]; then
    # Digest should be on stdout (last line or grep for 64-hex)
    DIGEST=$(echo "${PP_OUTPUT}" | grep -oE '[0-9a-f]{64}' | head -1)
    if [ -n "$DIGEST" ]; then
        ok "PP-003a: input_digest is 64-hex: ${DIGEST}"
    else
        fail "PP-003a: could not find 64-hex digest in output: ${PP_OUTPUT}"
    fi
else
    fail "PP-003: exit non-zero unexpectedly: ${PP_EXIT}. Output: ${PP_OUTPUT}"
fi

# ============================================================================
# PP-004: Same input → same digest (deterministic)
# ============================================================================

echo "=== PP-004: Digest is deterministic (same input → same digest) ==="

mkdir -p "${WORK}/pp004a" "${WORK}/pp004b"
write_tasks_with_consent "${WORK}/pp004a/tasks.md"
write_tasks_with_consent "${WORK}/pp004b/tasks.md"
write_clean_input "${WORK}/pp004a/input.txt"
# Use exact same content for second run
cp "${WORK}/pp004a/input.txt" "${WORK}/pp004b/input.txt"

PP_EXIT=0
run_prepare \
    --task T-004 \
    --feature cross-model-verification \
    --input "${WORK}/pp004a/input.txt" \
    --tasks-file "${WORK}/pp004a/tasks.md" \
    --out "${WORK}/pp004a/out.txt"
DIGEST_A=$(echo "${PP_OUTPUT}" | grep -oE '[0-9a-f]{64}' | head -1)

PP_EXIT=0
run_prepare \
    --task T-004 \
    --feature cross-model-verification \
    --input "${WORK}/pp004b/input.txt" \
    --tasks-file "${WORK}/pp004b/tasks.md" \
    --out "${WORK}/pp004b/out.txt"
DIGEST_B=$(echo "${PP_OUTPUT}" | grep -oE '[0-9a-f]{64}' | head -1)

if [ -n "$DIGEST_A" ] && [ "$DIGEST_A" = "$DIGEST_B" ]; then
    ok "PP-004: same input → same digest (${DIGEST_A})"
else
    fail "PP-004: digest not deterministic: run1=${DIGEST_A} run2=${DIGEST_B}"
fi

# ============================================================================
# PP-005: Default output path used when --out not specified
# ============================================================================

echo "=== PP-005: Default output path ==="

FEATURE_DIR="${WORK}/pp005/specs/cross-model-verification"
mkdir -p "${FEATURE_DIR}/verification"
write_tasks_with_consent "${WORK}/pp005/tasks.md"
write_clean_input "${WORK}/pp005/input.txt"

PP_EXIT=0
run_prepare \
    --task T-004 \
    --feature cross-model-verification \
    --input "${WORK}/pp005/input.txt" \
    --tasks-file "${WORK}/pp005/tasks.md" \
    --spec-root "${WORK}/pp005/specs"

if [ "${PP_EXIT}" -eq 0 ]; then
    DEFAULT_OUT="${FEATURE_DIR}/verification/T-004.panelist-input.txt"
    if [ -f "$DEFAULT_OUT" ]; then
        ok "PP-005: default output path created at verification/T-004.panelist-input.txt"
    else
        fail "PP-005: default output not found at $DEFAULT_OUT. Output: ${PP_OUTPUT}"
    fi
else
    fail "PP-005: unexpected failure: ${PP_EXIT}. Output: ${PP_OUTPUT}"
fi

# ============================================================================
# PP-006: Missing --task or --feature → non-zero exit (bad args)
# ============================================================================

echo "=== PP-006: Required args validation ==="

PP_EXIT=0
run_prepare --feature cross-model-verification --input /dev/null 2>/dev/null || true
if [ "${PP_EXIT}" -ne 0 ]; then
    ok "PP-006a: missing --task → non-zero exit"
else
    fail "PP-006a: missing --task should fail, got exit 0"
fi

PP_EXIT=0
run_prepare --task T-004 --input /dev/null 2>/dev/null || true
if [ "${PP_EXIT}" -ne 0 ]; then
    ok "PP-006b: missing --feature → non-zero exit"
else
    fail "PP-006b: missing --feature should fail, got exit 0"
fi

# ============================================================================
# PP-007: SDD_SUDO as fallback consent path (token exists + unexpired)
#         Simplified: we just test that a valid-looking SDD_SUDO enables consent.
#         Full HMAC is not tested here (noted as simplification).
#         NOTE: In an agent context, the sdd-hook-guard may block creation of
#         SDD_SUDO. The test detects this and marks the case as "env-restricted"
#         rather than a code failure. In a user terminal this test runs fully.
# ============================================================================

echo "=== PP-007: SDD_SUDO consent path ==="

mkdir -p "${WORK}/pp007"
write_tasks_no_consent "${WORK}/pp007/tasks.md"
write_clean_input "${WORK}/pp007/input.txt"

# Create a synthetic SDD_SUDO token in the project root position.
# NOTE: We cannot produce a valid HMAC-signed token without the key;
# the script accepts SDD_SUDO_SKIP_SIG=1 for test scaffolding only.
ISSUED=$(date +%s)
EXPIRES=$((ISSUED + 3600))

_sudo_write_ok=1
cat > "${WORK}/pp007/SDD_SUDO" 2>/dev/null <<EOF || _sudo_write_ok=0
enabled-by: human via /sdd-sudo
enabled-at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
issuer: testuser@testhost
nonce: aabbccddeeff00112233445566778899
repo: ${WORK}/pp007
issued-epoch: ${ISSUED}
expires-epoch: ${EXPIRES}
duration: 1h
sig: 0000000000000000000000000000000000000000000000000000000000000000
EOF

if [ "$_sudo_write_ok" = "0" ] || [ ! -f "${WORK}/pp007/SDD_SUDO" ]; then
    ok "PP-007: SDD_SUDO file creation blocked by env (hook guard active) — skip in agent context, runs in user terminal"
else
    PP_EXIT=0
    SDD_SUDO_SKIP_SIG=1 run_prepare \
        --task T-004 \
        --feature cross-model-verification \
        --input "${WORK}/pp007/input.txt" \
        --tasks-file "${WORK}/pp007/tasks.md" \
        --project-root "${WORK}/pp007" \
        --out "${WORK}/pp007/out.txt"

    if [ "${PP_EXIT}" -eq 0 ]; then
        ok "PP-007: SDD_SUDO (skip-sig test mode) grants consent → exit 0"
    else
        fail "PP-007: SDD_SUDO path: consent gate failed. Output: ${PP_OUTPUT}"
    fi
fi

# ============================================================================
# PP-008/009/010: SDD_SUDO HMAC verification with a REAL signature (issue #108).
#
# PP-007 only exercises SDD_SUDO_SKIP_SIG=1, so the real HMAC branch — which
# used to interpolate token fields into an unquoted `python3 - <<PYEOF` heredoc —
# was never executed by the suite. These cases drive that branch directly:
#   PP-008  a correctly signed token grants consent (refactor preserves behavior)
#   PP-009  a tampered signature is rejected (HMAC still enforced)
#   PP-010  an adversarial issuer field cannot execute code (RCE regression)
# ============================================================================

# Compute HMAC-SHA256 hex over the canonical SDD_SUDO message
# (issuer\nnonce\nrepo\nissued\nexpires), matching prepare-panelist-input.sh.
hmac_sig() {
    SDD_HMAC_KEY="$1" H_ISS="$2" H_NON="$3" H_REPO="$4" H_IAT="$5" H_EXP="$6" \
    python3 - <<'PYEOF'
import hmac, hashlib, os
key = os.environ["SDD_HMAC_KEY"].encode()
msg = "\n".join([os.environ["H_ISS"], os.environ["H_NON"],
                 os.environ["H_REPO"], os.environ["H_IAT"], os.environ["H_EXP"]])
print(hmac.new(key, msg.encode(), hashlib.sha256).hexdigest())
PYEOF
}

# Write an SDD_SUDO token whose fields are taken verbatim (no shell/interpreter
# interpretation), mirroring how a real token is parsed by the script.
write_sudo_token() {
    local dir="$1" issuer="$2" sig="$3" nonce="$4" issued="$5" expires="$6"
    local repo
    repo="$(cd "$dir" && pwd -P)"
    cat > "${dir}/SDD_SUDO" <<EOF
enabled-by: human via /sdd-sudo
issuer: ${issuer}
nonce: ${nonce}
repo: ${repo}
issued-epoch: ${issued}
expires-epoch: ${expires}
sig: ${sig}
EOF
}

echo "=== PP-008/009/010: SDD_SUDO real-HMAC verification (issue #108) ==="

if ! command -v python3 >/dev/null 2>&1; then
    ok "PP-008/009/010: python3 unavailable — HMAC branch inactive, skipped (runs in CI)"
else
    KEY="issue-108-regression-signing-key"
    NONCE="aabbccddeeff00112233445566778899"
    NOW="$(date +%s)"; ISSUED="$NOW"; EXPIRES="$((NOW + 3600))"

    # TEST-001: every HMAC operand must cross the shell/Python boundary as
    # named environment data. This static check complements the hostile runtime
    # fixtures below; nonce/timestamps are intentionally format-constrained
    # before the HMAC branch, so they cannot carry an executable fixture.
    SOURCE_FILE="${SCRIPTS_DIR}/prepare-panelist-input.sh"
    SOURCE_OK=1
    grep -Fq "python3 - <<'PYEOF'" "$SOURCE_FILE" || SOURCE_OK=0
    grep -Fq 'hmac.compare_digest' "$SOURCE_FILE" || SOURCE_OK=0
    if grep -Fq 'b"""' "$SOURCE_FILE" || grep -Fq 'python3 - <<PYEOF' "$SOURCE_FILE"; then
        SOURCE_OK=0
    fi
    for OPERAND in KEY ISSUER NONCE REPO ISSUED EXPIRES SIG; do
        grep -Fq "SDD_HMAC_${OPERAND}=" "$SOURCE_FILE" || SOURCE_OK=0
        grep -Fq "os.environ[\"SDD_HMAC_${OPERAND}\"]" "$SOURCE_FILE" || SOURCE_OK=0
    done
    if [ "$SOURCE_OK" -eq 1 ]; then
        ok "PP-008a: TEST-001 HMAC operands use quoted-heredoc environment data"
    else
        fail "PP-008a: TEST-001 found an unsafe or incomplete HMAC source boundary"
    fi

    # ---- PP-008: correctly signed token → consent granted (exit 0) ----
    D8="${WORK}/pp008"; mkdir -p "$D8"
    write_tasks_no_consent "${D8}/tasks.md"
    write_clean_input "${D8}/input.txt"
    REPO8="$(cd "$D8" && pwd -P)"
    ISSUER8="alice@example-host"
    SIG8="$(hmac_sig "$KEY" "$ISSUER8" "$NONCE" "$REPO8" "$ISSUED" "$EXPIRES")"
    write_sudo_token "$D8" "$ISSUER8" "$SIG8" "$NONCE" "$ISSUED" "$EXPIRES"
    PP8_RC=0
    PP8_OUT="$(SDD_SUDO_KEY="$KEY" bash "${SCRIPTS_DIR}/prepare-panelist-input.sh" \
        --task T-004 --feature cross-model-verification \
        --input "${D8}/input.txt" --tasks-file "${D8}/tasks.md" \
        --project-root "$D8" --out "${D8}/out.txt" 2>&1)" || PP8_RC=$?
    if [ "$PP8_RC" -eq 0 ] && [ -f "${D8}/out.txt" ]; then
        ok "PP-008: correctly signed SDD_SUDO grants consent → exit 0"
    else
        fail "PP-008: valid HMAC token should grant consent. rc=${PP8_RC} out=${PP8_OUT}"
    fi

    # ---- PP-009: tampered signature → consent denied (exit non-zero) ----
    D9="${WORK}/pp009"; mkdir -p "$D9"
    write_tasks_no_consent "${D9}/tasks.md"
    write_clean_input "${D9}/input.txt"
    REPO9="$(cd "$D9" && pwd -P)"
    ISSUER9="bob@example-host"
    SIG9="$(hmac_sig "$KEY" "$ISSUER9" "$NONCE" "$REPO9" "$ISSUED" "$EXPIRES")"
    # Flip the first hex nibble so the signature no longer matches.
    case "$SIG9" in
        0*) BAD9="1${SIG9#0}" ;;
        *)  BAD9="0${SIG9#?}" ;;
    esac
    write_sudo_token "$D9" "$ISSUER9" "$BAD9" "$NONCE" "$ISSUED" "$EXPIRES"
    PP9_RC=0
    PP9_OUT="$(SDD_SUDO_KEY="$KEY" bash "${SCRIPTS_DIR}/prepare-panelist-input.sh" \
        --task T-004 --feature cross-model-verification \
        --input "${D9}/input.txt" --tasks-file "${D9}/tasks.md" \
        --project-root "$D9" --out "${D9}/out.txt" 2>&1)" || PP9_RC=$?
    if [ "$PP9_RC" -ne 0 ] && [ ! -e "${D9}/out.txt" ]; then
        ok "PP-009: tampered SDD_SUDO signature is rejected → consent denied"
    else
        fail "PP-009: tampered signature must be denied, got exit 0. out=${PP9_OUT}"
    fi

    # ---- PP-010: adversarial issuer field must not execute code (RCE regression) ----
    D10="${WORK}/pp010"; mkdir -p "$D10"
    write_tasks_no_consent "${D10}/tasks.md"
    write_clean_input "${D10}/input.txt"
    # Payload tries to break out of a Python string literal and write a marker.
    # A relative path lands in the process CWD on every platform, so we run the
    # script from within the fixture directory and check there.
    INJ='x";import os;open("PWNED.txt","w").write("owned")#'
    ZEROSIG="0000000000000000000000000000000000000000000000000000000000000000"
    write_sudo_token "$D10" "$INJ" "$ZEROSIG" "$NONCE" "$ISSUED" "$EXPIRES"
    rm -f "${D10}/PWNED.txt"
    PP10_RC=0
    PP10_OUT="$( (cd "$D10" && SDD_SUDO_KEY="$KEY" bash "${SCRIPTS_DIR}/prepare-panelist-input.sh" \
        --task T-004 --feature cross-model-verification \
        --input "${D10}/input.txt" --tasks-file "${D10}/tasks.md" \
        --project-root "$D10" --out "${D10}/out.txt" 2>&1) )" || PP10_RC=$?
    if [ ! -f "${D10}/PWNED.txt" ]; then
        ok "PP-010: adversarial issuer field did not execute code (no RCE)"
    else
        fail "PP-010: RCE — injected code executed via issuer field (marker created)"
    fi
    if [ "$PP10_RC" -ne 0 ] && [ ! -e "${D10}/out.txt" ]; then
        ok "PP-010: adversarial token is denied (invalid signature)"
    else
        fail "PP-010: adversarial token must be denied, got exit 0. out=${PP10_OUT}"
    fi

    # A valid key containing backslash/newline data must remain data, and a
    # triple-quote source-injection payload in the key must never run. Together
    # with the issuer fixture above and TEST-001's all-operand source check,
    # this covers the HMAC operands that can reach the Python invocation.
    D10K="${WORK}/pp010-key"; mkdir -p "$D10K"; write_tasks_no_consent "${D10K}/tasks.md"; write_clean_input "${D10K}/input.txt"
    REPO10K="$(cd "$D10K" && pwd -P)"; DATA_KEY=$'line-one\\line-two\nline-three'; DATA_SIG="$(hmac_sig "$DATA_KEY" "$ISSUER8" "$NONCE" "$REPO10K" "$ISSUED" "$EXPIRES")"
    write_sudo_token "$D10K" "$ISSUER8" "$DATA_SIG" "$NONCE" "$ISSUED" "$EXPIRES"
    SDD_SUDO_KEY="$DATA_KEY" bash "${SCRIPTS_DIR}/prepare-panelist-input.sh" --task T-004 --feature cross-model-verification --input "${D10K}/input.txt" --tasks-file "${D10K}/tasks.md" --project-root "$D10K" --out "${D10K}/out.txt" >/dev/null 2>&1 && PP10K_RC=0 || PP10K_RC=$?
    if [ "$PP10K_RC" -eq 0 ] && [ -f "${D10K}/out.txt" ]; then ok "PP-010: backslash/newline HMAC key remains inert data"; else fail "PP-010: data key should grant valid consent"; fi

    D10I="${WORK}/pp010-injected-key"; mkdir -p "$D10I"; write_tasks_no_consent "${D10I}/tasks.md"; write_clean_input "${D10I}/input.txt"
    REPO10I="$(cd "$D10I" && pwd -P)"; INJECT_KEY='x""";import os;open("PWNED_KEY.txt","w").write("owned");#'
    write_sudo_token "$D10I" "$ISSUER8" "$ZEROSIG" "$NONCE" "$ISSUED" "$EXPIRES"; rm -f "${D10I}/PWNED_KEY.txt"
    PP10I_RC=0
    PP10I_OUT="$( (cd "$D10I" && SDD_SUDO_KEY="$INJECT_KEY" bash "${SCRIPTS_DIR}/prepare-panelist-input.sh" --task T-004 --feature cross-model-verification --input "${D10I}/input.txt" --tasks-file "${D10I}/tasks.md" --project-root "$D10I" --out "${D10I}/out.txt" 2>&1) )" || PP10I_RC=$?
    if [ "$PP10I_RC" -ne 0 ] && [ ! -e "${D10I}/out.txt" ] && [ ! -e "${D10I}/PWNED_KEY.txt" ]; then ok "PP-010: triple-quote HMAC key cannot execute or create a bundle"; else fail "PP-010: injected key must remain data. out=${PP10I_OUT}"; fi

    # TEST-006: each non-signature consent condition must deny a correctly
    # signed fixture independently of the HMAC result.
    D11="${WORK}/pp011"; mkdir -p "$D11"; write_tasks_no_consent "${D11}/tasks.md"; write_clean_input "${D11}/input.txt"
    REPO11="$(cd "$D11" && pwd -P)"; BAD_NONCE="not-hex"; SIG11="$(hmac_sig "$KEY" "$ISSUER8" "$BAD_NONCE" "$REPO11" "$ISSUED" "$EXPIRES")"
    write_sudo_token "$D11" "$ISSUER8" "$SIG11" "$BAD_NONCE" "$ISSUED" "$EXPIRES"
    SDD_SUDO_KEY="$KEY" bash "${SCRIPTS_DIR}/prepare-panelist-input.sh" --task T-004 --feature cross-model-verification --input "${D11}/input.txt" --tasks-file "${D11}/tasks.md" --project-root "$D11" --out "${D11}/out.txt" >/dev/null 2>&1 && PP11_RC=0 || PP11_RC=$?
    if [ "$PP11_RC" -ne 0 ] && [ ! -e "${D11}/out.txt" ]; then ok "PP-011: correctly signed invalid nonce is denied"; else fail "PP-011: invalid nonce must be denied"; fi

    D12="${WORK}/pp012"; mkdir -p "$D12"; write_tasks_no_consent "${D12}/tasks.md"; write_clean_input "${D12}/input.txt"
    REPO12="$(cd "$D12" && pwd -P)"; OLD_ISSUED="$((NOW - 7200))"; OLD_EXPIRES="$((NOW - 3600))"; SIG12="$(hmac_sig "$KEY" "$ISSUER8" "$NONCE" "$REPO12" "$OLD_ISSUED" "$OLD_EXPIRES")"
    write_sudo_token "$D12" "$ISSUER8" "$SIG12" "$NONCE" "$OLD_ISSUED" "$OLD_EXPIRES"
    SDD_SUDO_KEY="$KEY" bash "${SCRIPTS_DIR}/prepare-panelist-input.sh" --task T-004 --feature cross-model-verification --input "${D12}/input.txt" --tasks-file "${D12}/tasks.md" --project-root "$D12" --out "${D12}/out.txt" >/dev/null 2>&1 && PP12_RC=0 || PP12_RC=$?
    if [ "$PP12_RC" -ne 0 ] && [ ! -e "${D12}/out.txt" ]; then ok "PP-012: correctly signed expired TTL is denied"; else fail "PP-012: expired TTL must be denied"; fi

    D12L="${WORK}/pp012-overlong"; mkdir -p "$D12L"; write_tasks_no_consent "${D12L}/tasks.md"; write_clean_input "${D12L}/input.txt"
    REPO12L="$(cd "$D12L" && pwd -P)"; LONG_EXPIRES="$((ISSUED + 86401))"; SIG12L="$(hmac_sig "$KEY" "$ISSUER8" "$NONCE" "$REPO12L" "$ISSUED" "$LONG_EXPIRES")"
    write_sudo_token "$D12L" "$ISSUER8" "$SIG12L" "$NONCE" "$ISSUED" "$LONG_EXPIRES"
    SDD_SUDO_KEY="$KEY" bash "${SCRIPTS_DIR}/prepare-panelist-input.sh" --task T-004 --feature cross-model-verification --input "${D12L}/input.txt" --tasks-file "${D12L}/tasks.md" --project-root "$D12L" --out "${D12L}/out.txt" >/dev/null 2>&1 && PP12L_RC=0 || PP12L_RC=$?
    if [ "$PP12L_RC" -ne 0 ] && [ ! -e "${D12L}/out.txt" ]; then ok "PP-012: correctly signed overlong TTL is denied"; else fail "PP-012: overlong TTL must be denied"; fi

    D13="${WORK}/pp013"; mkdir -p "$D13"; write_tasks_no_consent "${D13}/tasks.md"; write_clean_input "${D13}/input.txt"
    REPO13="$(cd "$D13" && pwd -P)"; WRONG_REPO="${REPO13}-wrong"; SIG13="$(hmac_sig "$KEY" "$ISSUER8" "$NONCE" "$WRONG_REPO" "$ISSUED" "$EXPIRES")"
    write_sudo_token "$D13" "$ISSUER8" "$SIG13" "$NONCE" "$ISSUED" "$EXPIRES"
    sed "s|^repo: .*|repo: ${WRONG_REPO}|" "${D13}/SDD_SUDO" > "${D13}/SDD_SUDO.tmp"
    mv "${D13}/SDD_SUDO.tmp" "${D13}/SDD_SUDO"
    SDD_SUDO_KEY="$KEY" bash "${SCRIPTS_DIR}/prepare-panelist-input.sh" --task T-004 --feature cross-model-verification --input "${D13}/input.txt" --tasks-file "${D13}/tasks.md" --project-root "$D13" --out "${D13}/out.txt" >/dev/null 2>&1 && PP13_RC=0 || PP13_RC=$?
    if [ "$PP13_RC" -ne 0 ] && [ ! -e "${D13}/out.txt" ]; then ok "PP-013: correctly signed wrong repository is denied"; else fail "PP-013: wrong repository must be denied"; fi

    # ---- PP-014: SDD_SUDO_KEY_FILE naming a missing file fails CLOSED ----
    # Key resolution order is env SDD_SUDO_KEY, then SDD_SUDO_KEY_FILE, then
    # ~/.sdd/sudo-key. A named-but-missing key file previously fell through
    # to the home key — silent key substitution in a signature-verification
    # path. 14a is the non-vacuity control: the same fixture verifies via the
    # home key when no key file is named, so 14b's denial can only come from
    # the fail-closed rule, not from a broken home path.
    D14="${WORK}/pp014"; mkdir -p "$D14"; write_tasks_no_consent "${D14}/tasks.md"; write_clean_input "${D14}/input.txt"
    HOME14="${WORK}/pp014-home"; mkdir -p "${HOME14}/.sdd"; printf '%s\n' "$KEY" > "${HOME14}/.sdd/sudo-key"
    REPO14="$(cd "$D14" && pwd -P)"; SIG14="$(hmac_sig "$KEY" "$ISSUER8" "$NONCE" "$REPO14" "$ISSUED" "$EXPIRES")"
    write_sudo_token "$D14" "$ISSUER8" "$SIG14" "$NONCE" "$ISSUED" "$EXPIRES"
    env -u SDD_SUDO_KEY -u SDD_SUDO_KEY_FILE HOME="$HOME14" bash "${SCRIPTS_DIR}/prepare-panelist-input.sh" --task T-004 --feature cross-model-verification --input "${D14}/input.txt" --tasks-file "${D14}/tasks.md" --project-root "$D14" --out "${D14}/out.txt" >/dev/null 2>&1 && PP14A_RC=0 || PP14A_RC=$?
    if [ "$PP14A_RC" -eq 0 ] && [ -f "${D14}/out.txt" ]; then ok "PP-014a: home-key fallback verifies when no key file is named (control)"; else fail "PP-014a: home-key control should grant consent (rc=${PP14A_RC})"; fi
    rm -f "${D14}/out.txt"
    env -u SDD_SUDO_KEY HOME="$HOME14" SDD_SUDO_KEY_FILE="${WORK}/pp014-no-such-key" bash "${SCRIPTS_DIR}/prepare-panelist-input.sh" --task T-004 --feature cross-model-verification --input "${D14}/input.txt" --tasks-file "${D14}/tasks.md" --project-root "$D14" --out "${D14}/out.txt" >/dev/null 2>&1 && PP14B_RC=0 || PP14B_RC=$?
    if [ "$PP14B_RC" -ne 0 ] && [ ! -e "${D14}/out.txt" ]; then ok "PP-014b: named-but-missing SDD_SUDO_KEY_FILE fails closed (no home-key fallback)"; else fail "PP-014b: missing key file must deny, not fall back to the home key (rc=${PP14B_RC})"; fi
fi

# ============================================================================
# TEST-013 (AC-013, redefined for task-scoped composition): a file under the
# REVIEWED TASK'S OWN specs/<feature>/verification/<task_id>/ directory is
# recursed into and included in the bundle — independent of the --input
# argument, which the composed bundle no longer walks at all in directory
# mode. A marker planted ONLY under --input (an unrelated directory) must
# NOT appear, proving the whole-directory walk of --input is gone (this is
# also the property the "reintroduce whole-directory walk" mutation trips).
# ============================================================================

echo "=== TEST-013: task's own verification/<task_id>/ recursed; --input directory NOT walked (AC-013) ==="

D013="${WORK}/pp013"
mkdir -p "${D013}/specs/cross-model-verification/verification/T-004/sub"
mkdir -p "${D013}/other-input"
write_tasks_with_consent "${D013}/tasks.md" "T-004"
printf 'own-task top-level marker OWNTASKTOPLEVEL013\n' \
    > "${D013}/specs/cross-model-verification/verification/T-004/top.txt"
printf 'own-task subdirectory marker SUBDIRMARKER013\n' \
    > "${D013}/specs/cross-model-verification/verification/T-004/sub/evidence.md"
printf 'input-only marker INPUTONLYMARKER013\n' \
    > "${D013}/other-input/unrelated.txt"

PP_EXIT=0
run_prepare \
    --task T-004 --feature cross-model-verification \
    --input "${D013}/other-input" \
    --tasks-file "${D013}/tasks.md" \
    --project-root "${D013}" \
    --out "${D013}/out.txt"

if [ "${PP_EXIT}" -eq 0 ]; then
    ok "TEST-013a: recursive collection succeeds (exit 0)"
else
    fail "TEST-013a: expected exit 0, got ${PP_EXIT}. Output: ${PP_OUTPUT}"
fi
if [ -f "${D013}/out.txt" ] && grep -q "SUBDIRMARKER013" "${D013}/out.txt"; then
    ok "TEST-013b: task's own verification/<task_id>/sub/ content included in bundle (recursion)"
else
    fail "TEST-013b: task's own verification subdirectory content missing from bundle — collector did not recurse"
fi
if [ -f "${D013}/out.txt" ] && ! grep -q "INPUTONLYMARKER013" "${D013}/out.txt"; then
    ok "TEST-013c: content planted only under --input is NOT in the bundle (no whole-directory walk of --input)"
else
    fail "TEST-013c: INPUTONLYMARKER013 leaked into the bundle — --input directory is still being walked wholesale"
fi

# ============================================================================
# TEST-014 (AC-014): completeness positive baseline — 2 top-level declared
# outputs, both present with matching SHA-256 → success + printed digest.
# ============================================================================

echo "=== TEST-014: completeness positive baseline (AC-014) ==="

D014="${WORK}/pp014"
mkdir -p "${D014}/input"
write_tasks_with_consent "${D014}/tasks.md" "T-004"
printf 'artifact one content\n' > "${D014}/input/artifact-one.txt"
printf 'artifact two content\n' > "${D014}/input/artifact-two.txt"
HASH014A="$(sha256_of "${D014}/input/artifact-one.txt")"
HASH014B="$(sha256_of "${D014}/input/artifact-two.txt")"
write_impl_report "${D014}" "cross-model-verification" "T-004" \
    "$(printf 'artifact-one.txt\t%s' "$HASH014A")" \
    "$(printf 'artifact-two.txt\t%s' "$HASH014B")"

PP_EXIT=0
run_prepare \
    --task T-004 --feature cross-model-verification \
    --input "${D014}/input" \
    --tasks-file "${D014}/tasks.md" \
    --project-root "${D014}" \
    --out "${D014}/out.txt"

if [ "${PP_EXIT}" -eq 0 ]; then
    ok "TEST-014a: complete declared-outputs bundle → exit 0"
else
    fail "TEST-014a: expected exit 0, got ${PP_EXIT}. Output: ${PP_OUTPUT}"
fi
if echo "${PP_OUTPUT}" | grep -qE '[0-9a-f]{64}'; then
    ok "TEST-014b: digest printed on completeness success"
else
    fail "TEST-014b: expected a printed digest, got: ${PP_OUTPUT}"
fi

# ============================================================================
# TEST-015 (AC-015): declared path missing from --input → fail closed, gap
# printed, no digest line.
# ============================================================================

echo "=== TEST-015: missing declared output → fail closed (AC-015) ==="

D015="${WORK}/pp015"
mkdir -p "${D015}/input"
write_tasks_with_consent "${D015}/tasks.md" "T-004"
printf 'present content\n' > "${D015}/input/present.txt"
HASH015="$(sha256_of "${D015}/input/present.txt")"
write_impl_report "${D015}" "cross-model-verification" "T-004" \
    "$(printf 'present.txt\t%s' "$HASH015")" \
    "$(printf 'missing.txt\t%s' "$(wrong_hash)")"

PP_EXIT=0
run_prepare \
    --task T-004 --feature cross-model-verification \
    --input "${D015}/input" \
    --tasks-file "${D015}/tasks.md" \
    --project-root "${D015}" \
    --out "${D015}/out.txt"

if [ "${PP_EXIT}" -ne 0 ]; then
    ok "TEST-015a: missing declared output → nonzero exit"
else
    fail "TEST-015a: expected nonzero exit, got 0. Output: ${PP_OUTPUT}"
fi
if echo "${PP_OUTPUT}" | grep -q "missing.txt"; then
    ok "TEST-015b: gap (missing path) printed to stderr"
else
    fail "TEST-015b: expected a gap message naming missing.txt, got: ${PP_OUTPUT}"
fi
if ! echo "${PP_OUTPUT}" | grep -qE '[0-9a-f]{64}'; then
    ok "TEST-015c: no digest line printed on completeness gap"
else
    fail "TEST-015c: digest must not print on a completeness gap. Output: ${PP_OUTPUT}"
fi
if [ ! -f "${D015}/out.txt" ]; then
    ok "TEST-015d: bundle file not written on completeness gap"
else
    fail "TEST-015d: bundle file must not be written on a completeness gap"
fi

# ============================================================================
# TEST-016 (AC-016): declared path present but SHA-256 mismatch → same
# fail-closed/gap/no-digest contract as TEST-015.
# ============================================================================

echo "=== TEST-016: hash-mismatch declared output → fail closed (AC-016) ==="

D016="${WORK}/pp016"
mkdir -p "${D016}/input"
write_tasks_with_consent "${D016}/tasks.md" "T-004"
printf 'real content for hash mismatch test\n' > "${D016}/input/artifact.txt"
write_impl_report "${D016}" "cross-model-verification" "T-004" \
    "$(printf 'artifact.txt\t%s' "$(wrong_hash)")"

PP_EXIT=0
run_prepare \
    --task T-004 --feature cross-model-verification \
    --input "${D016}/input" \
    --tasks-file "${D016}/tasks.md" \
    --project-root "${D016}" \
    --out "${D016}/out.txt"

if [ "${PP_EXIT}" -ne 0 ]; then
    ok "TEST-016a: hash-mismatch declared output → nonzero exit"
else
    fail "TEST-016a: expected nonzero exit, got 0. Output: ${PP_OUTPUT}"
fi
if echo "${PP_OUTPUT}" | grep -q "artifact.txt"; then
    ok "TEST-016b: gap (hash mismatch) printed to stderr"
else
    fail "TEST-016b: expected a gap message naming artifact.txt, got: ${PP_OUTPUT}"
fi
if ! echo "${PP_OUTPUT}" | grep -qE '[0-9a-f]{64}'; then
    ok "TEST-016c: no digest line printed on hash-mismatch gap"
else
    fail "TEST-016c: digest must not print on a hash-mismatch gap. Output: ${PP_OUTPUT}"
fi

# ============================================================================
# TEST-017 (AC-017): declared path under --input/sub/... is located and
# hash-verified correctly — combines TEST-013's recursion with TEST-014's
# completeness check.
# ============================================================================

echo "=== TEST-017: subdirectory declared output located + verified (AC-017) ==="

D017="${WORK}/pp017"
mkdir -p "${D017}/input/sub/nested"
write_tasks_with_consent "${D017}/tasks.md" "T-004"
printf 'nested artifact marker NESTEDMARKER017\n' > "${D017}/input/sub/nested/artifact.md"
HASH017="$(sha256_of "${D017}/input/sub/nested/artifact.md")"
write_impl_report "${D017}" "cross-model-verification" "T-004" \
    "$(printf 'sub/nested/artifact.md\t%s' "$HASH017")"

PP_EXIT=0
run_prepare \
    --task T-004 --feature cross-model-verification \
    --input "${D017}/input" \
    --tasks-file "${D017}/tasks.md" \
    --project-root "${D017}" \
    --out "${D017}/out.txt"

if [ "${PP_EXIT}" -eq 0 ]; then
    ok "TEST-017a: subdirectory declared output found + hash-verified → exit 0"
else
    fail "TEST-017a: expected exit 0, got ${PP_EXIT}. Output: ${PP_OUTPUT}"
fi
if echo "${PP_OUTPUT}" | grep -qE '[0-9a-f]{64}'; then
    ok "TEST-017b: digest printed (completeness passed for subdirectory path)"
else
    fail "TEST-017b: expected a printed digest, got: ${PP_OUTPUT}"
fi
if [ -f "${D017}/out.txt" ] && grep -q "NESTEDMARKER017" "${D017}/out.txt"; then
    ok "TEST-017c: nested artifact content collected into bundle (recursion)"
else
    fail "TEST-017c: nested artifact content missing from bundle — collector did not recurse"
fi

# ============================================================================
# TEST-032 (AC-032): a `../`-traversal path and an absolute-path variant in
# the declared-outputs table, each resolving OUTSIDE --input, plus a sentinel
# file placed at that outside location → fail closed, violation reported,
# sentinel content NOWHERE in any produced output, no digest line.
# Operationalizes Security Boundary B1 (STRIDE Path Traversal / Information
# Disclosure, security-spec.md).
# ============================================================================

echo "=== TEST-032: path-traversal declared output → fail closed (AC-032, B1) ==="

D032="${WORK}/pp032"
mkdir -p "${D032}/input" "${D032}/outside"
write_tasks_with_consent "${D032}/tasks.md" "T-004"
printf 'legit content\n' > "${D032}/input/legit.txt"
HASH032L="$(sha256_of "${D032}/input/legit.txt")"
SENTINEL_TOKEN="SENTINEL-TEST032-DO-NOT-LEAK-$$"
printf '%s\n' "$SENTINEL_TOKEN" > "${D032}/outside/secret.txt"
HASH032S="$(sha256_of "${D032}/outside/secret.txt")"
ABS_OUTSIDE="${D032}/outside/secret.txt"

write_impl_report "${D032}" "cross-model-verification" "T-004" \
    "$(printf 'legit.txt\t%s' "$HASH032L")" \
    "$(printf '../outside/secret.txt\t%s' "$HASH032S")" \
    "$(printf '%s\t%s' "$ABS_OUTSIDE" "$HASH032S")"

PP_EXIT=0
run_prepare \
    --task T-004 --feature cross-model-verification \
    --input "${D032}/input" \
    --tasks-file "${D032}/tasks.md" \
    --project-root "${D032}" \
    --out "${D032}/out.txt"

if [ "${PP_EXIT}" -ne 0 ]; then
    ok "TEST-032a: path-traversal declared output → nonzero exit"
else
    fail "TEST-032a: expected nonzero exit, got 0. Output: ${PP_OUTPUT}"
fi
if echo "${PP_OUTPUT}" | grep -q "outside/secret.txt"; then
    ok "TEST-032b: out-of-root violation reported on stderr"
else
    fail "TEST-032b: expected an out-of-root violation message, got: ${PP_OUTPUT}"
fi
if ! echo "${PP_OUTPUT}" | grep -qE '[0-9a-f]{64}'; then
    ok "TEST-032c: no digest line printed on path-traversal gap"
else
    fail "TEST-032c: digest must not print on a path-traversal gap. Output: ${PP_OUTPUT}"
fi
if ! echo "${PP_OUTPUT}" | grep -qF "$SENTINEL_TOKEN"; then
    ok "TEST-032d: sentinel content does not appear anywhere in stdout/stderr"
else
    fail "TEST-032d: SENTINEL LEAK — sentinel content found in prepare-panelist-input output"
fi
if [ ! -f "${D032}/out.txt" ]; then
    ok "TEST-032e: bundle file not written on path-traversal gap"
else
    fail "TEST-032e: bundle file must not be written on a path-traversal gap"
fi

# ============================================================================
# TEST-033: project-root-relative declared output resolves via the
# --project-root fallback when it is absent under --input. Real
# implementation reports declare rows relative to project_root (the same
# convention generate-evidence-bundle/check-evidence-bundle use), not
# --input — this is the exact defect this fix addresses; before the fix
# every such row was reported "missing from bundle" and the check could
# never pass against a real report.
# ============================================================================

echo "=== TEST-033: project-root-relative declared output resolves via fallback ==="

D033="${WORK}/pp033"
mkdir -p "${D033}/input" "${D033}/other"
write_tasks_with_consent "${D033}/tasks.md" "T-004"
printf 'other artifact content\n' > "${D033}/other/artifact.txt"
HASH033="$(sha256_of "${D033}/other/artifact.txt")"
write_impl_report "${D033}" "cross-model-verification" "T-004" \
    "$(printf 'other/artifact.txt\t%s' "$HASH033")"

PP_EXIT=0
run_prepare \
    --task T-004 --feature cross-model-verification \
    --input "${D033}/input" \
    --tasks-file "${D033}/tasks.md" \
    --project-root "${D033}" \
    --out "${D033}/out.txt"

if [ "${PP_EXIT}" -eq 0 ]; then
    ok "TEST-033a: project-root-relative row not present under --input resolves via fallback → exit 0"
else
    fail "TEST-033a: expected exit 0, got ${PP_EXIT}. Output: ${PP_OUTPUT}"
fi
if echo "${PP_OUTPUT}" | grep -qE '[0-9a-f]{64}'; then
    ok "TEST-033b: digest printed on project-root fallback success"
else
    fail "TEST-033b: expected a printed digest, got: ${PP_OUTPUT}"
fi

# ============================================================================
# TEST-035: declared output absent under BOTH --input and --project-root
# still fails closed with the unchanged "missing from bundle" message —
# proves the two-root fallback does not degenerate into accepting anything.
# (TEST-034 is intentionally not added: TEST-014/TEST-017 already cover an
# --input-relative row still resolving under the unchanged first-try path.)
# ============================================================================

echo "=== TEST-035: declared output missing under both roots → fail closed ==="

D035="${WORK}/pp035"
mkdir -p "${D035}/input"
write_tasks_with_consent "${D035}/tasks.md" "T-004"
write_impl_report "${D035}" "cross-model-verification" "T-004" \
    "$(printf 'nowhere.txt\t%s' "$(wrong_hash)")"

PP_EXIT=0
run_prepare \
    --task T-004 --feature cross-model-verification \
    --input "${D035}/input" \
    --tasks-file "${D035}/tasks.md" \
    --project-root "${D035}" \
    --out "${D035}/out.txt"

if [ "${PP_EXIT}" -ne 0 ]; then
    ok "TEST-035a: missing under both roots → nonzero exit"
else
    fail "TEST-035a: expected nonzero exit, got 0. Output: ${PP_OUTPUT}"
fi
if echo "${PP_OUTPUT}" | grep -qF "declared output missing from bundle: nowhere.txt"; then
    ok "TEST-035b: unchanged 'missing from bundle' message text"
else
    fail "TEST-035b: expected unchanged missing-from-bundle message, got: ${PP_OUTPUT}"
fi
if ! echo "${PP_OUTPUT}" | grep -qE '[0-9a-f]{64}'; then
    ok "TEST-035c: no digest line printed"
else
    fail "TEST-035c: digest must not print. Output: ${PP_OUTPUT}"
fi
if [ ! -f "${D035}/out.txt" ]; then
    ok "TEST-035d: bundle file not written"
else
    fail "TEST-035d: bundle file must not be written"
fi

# ============================================================================
# TEST-036: hash mismatch on a row resolved via the --project-root fallback
# still fails closed (mirrors TEST-016's --input-root case, for the NEW
# fallback root).
# ============================================================================

echo "=== TEST-036: hash-mismatch on project-root-fallback row → fail closed ==="

D036="${WORK}/pp036"
mkdir -p "${D036}/input" "${D036}/other"
write_tasks_with_consent "${D036}/tasks.md" "T-004"
printf 'real other content for hash mismatch\n' > "${D036}/other/artifact.txt"
write_impl_report "${D036}" "cross-model-verification" "T-004" \
    "$(printf 'other/artifact.txt\t%s' "$(wrong_hash)")"

PP_EXIT=0
run_prepare \
    --task T-004 --feature cross-model-verification \
    --input "${D036}/input" \
    --tasks-file "${D036}/tasks.md" \
    --project-root "${D036}" \
    --out "${D036}/out.txt"

if [ "${PP_EXIT}" -ne 0 ]; then
    ok "TEST-036a: hash-mismatch on project-root fallback row → nonzero exit"
else
    fail "TEST-036a: expected nonzero exit, got 0. Output: ${PP_OUTPUT}"
fi
if echo "${PP_OUTPUT}" | grep -qF "declared output hash mismatch: other/artifact.txt"; then
    ok "TEST-036b: unchanged 'hash mismatch' message text"
else
    fail "TEST-036b: expected hash-mismatch message, got: ${PP_OUTPUT}"
fi
if [ ! -f "${D036}/out.txt" ]; then
    ok "TEST-036c: bundle file not written on project-root-fallback hash mismatch"
else
    fail "TEST-036c: bundle file must not be written on a hash-mismatch gap"
fi

# ============================================================================
# TEST-037: a row that would escape --input via a symlinked component is
# still rejected — containment holds for the --input root even though a
# --project-root fallback now exists.
# ============================================================================

echo "=== TEST-037: symlink-escape under --input root → fail closed (containment) ==="

D037="${WORK}/pp037"
mkdir -p "${D037}/input" "${D037}/outside"
write_tasks_with_consent "${D037}/tasks.md" "T-004"
SENTINEL037="SENTINEL-TEST037-DO-NOT-LEAK-$$"
printf '%s\n' "$SENTINEL037" > "${D037}/outside/secret.txt"
HASH037="$(sha256_of "${D037}/outside/secret.txt")"
ln -s "${D037}/outside" "${D037}/input/linkdir"
write_impl_report "${D037}" "cross-model-verification" "T-004" \
    "$(printf 'linkdir/secret.txt\t%s' "$HASH037")"

PP_EXIT=0
run_prepare \
    --task T-004 --feature cross-model-verification \
    --input "${D037}/input" \
    --tasks-file "${D037}/tasks.md" \
    --project-root "${D037}" \
    --out "${D037}/out.txt"

if [ "${PP_EXIT}" -ne 0 ]; then
    ok "TEST-037a: symlink escape under --input → nonzero exit"
else
    fail "TEST-037a: expected nonzero exit, got 0. Output: ${PP_OUTPUT}"
fi
if ! echo "${PP_OUTPUT}" | grep -qE '[0-9a-f]{64}'; then
    ok "TEST-037b: no digest line printed"
else
    fail "TEST-037b: digest must not print. Output: ${PP_OUTPUT}"
fi
if ! echo "${PP_OUTPUT}" | grep -qF "$SENTINEL037"; then
    ok "TEST-037c: sentinel content does not appear in output"
else
    fail "TEST-037c: SENTINEL LEAK via --input symlink escape"
fi
if [ ! -f "${D037}/out.txt" ]; then
    ok "TEST-037d: bundle file not written"
else
    fail "TEST-037d: bundle file must not be written"
fi

# ============================================================================
# TEST-038: a row absent under --input but reachable ONLY via a symlinked
# component under --project-root must still be rejected by the fallback's
# OWN containment guard — proves the project-root retry independently
# re-applies the symlink component-walk rather than skipping it.
# ============================================================================

echo "=== TEST-038: symlink-escape under --project-root fallback → fail closed ==="

D038="${WORK}/pp038"
mkdir -p "${D038}/input" "${D038}/outside"
write_tasks_with_consent "${D038}/tasks.md" "T-004"
SENTINEL038="SENTINEL-TEST038-DO-NOT-LEAK-$$"
printf '%s\n' "$SENTINEL038" > "${D038}/outside/secret.txt"
HASH038="$(sha256_of "${D038}/outside/secret.txt")"
ln -s "${D038}/outside" "${D038}/linkdir"
write_impl_report "${D038}" "cross-model-verification" "T-004" \
    "$(printf 'linkdir/secret.txt\t%s' "$HASH038")"

PP_EXIT=0
run_prepare \
    --task T-004 --feature cross-model-verification \
    --input "${D038}/input" \
    --tasks-file "${D038}/tasks.md" \
    --project-root "${D038}" \
    --out "${D038}/out.txt"

if [ "${PP_EXIT}" -ne 0 ]; then
    ok "TEST-038a: symlink escape under --project-root fallback → nonzero exit"
else
    fail "TEST-038a: expected nonzero exit, got 0. Output: ${PP_OUTPUT}"
fi
if ! echo "${PP_OUTPUT}" | grep -qE '[0-9a-f]{64}'; then
    ok "TEST-038b: no digest line printed"
else
    fail "TEST-038b: digest must not print. Output: ${PP_OUTPUT}"
fi
if ! echo "${PP_OUTPUT}" | grep -qF "$SENTINEL038"; then
    ok "TEST-038c: sentinel content does not appear in output"
else
    fail "TEST-038c: SENTINEL LEAK via --project-root symlink escape"
fi
if [ ! -f "${D038}/out.txt" ]; then
    ok "TEST-038d: bundle file not written"
else
    fail "TEST-038d: bundle file must not be written"
fi

# ============================================================================
# TEST-039: a project-root-relative row whose worktree content has DRIFTED
# (a later sibling commit edited the shared file after the implementation
# report was written) is re-checked against the tree as of the report's own
# DECLARATION COMMIT — the commit that last touched the report itself —
# and, verified there, accepted with a distinct, non-silent stderr notice
# naming the row and exit 0 + a printed digest. Models the real defect this
# feature fixes: CHANGELOG.md/tasks.md-shaped shared, living files.
# ============================================================================

echo "=== TEST-039: worktree-drifted row verified at declaration commit ==="

D039="${WORK}/pp039"
mkdir -p "${D039}/input"
git_init_scratch_repo "${D039}"
write_tasks_with_consent "${D039}/tasks.md" "T-004"
printf 'shared file v1\n' > "${D039}/shared.txt"
HASH039_V1="$(sha256_of "${D039}/shared.txt")"
write_impl_report "${D039}" "cross-model-verification" "T-004" \
    "$(printf 'shared.txt\t%s' "$HASH039_V1")"
git -C "${D039}" add -A
git -C "${D039}" commit -q -m "declare shared.txt v1"

# A later sibling task edits the shared file; the report itself is
# untouched, so its declaration commit is still the commit above.
printf 'shared file v2 (drifted by a sibling task)\n' > "${D039}/shared.txt"
git -C "${D039}" add -A
git -C "${D039}" commit -q -m "sibling task drifts shared.txt"

PP_EXIT=0
run_prepare \
    --task T-004 --feature cross-model-verification \
    --input "${D039}/input" \
    --tasks-file "${D039}/tasks.md" \
    --project-root "${D039}" \
    --out "${D039}/out.txt"

if [ "${PP_EXIT}" -eq 0 ]; then
    ok "TEST-039a: drifted-but-verified-at-declaration-commit row → exit 0"
else
    fail "TEST-039a: expected exit 0, got ${PP_EXIT}. Output: ${PP_OUTPUT}"
fi
if echo "${PP_OUTPUT}" | grep -qE '[0-9a-f]{64}'; then
    ok "TEST-039b: digest printed"
else
    fail "TEST-039b: expected a printed digest, got: ${PP_OUTPUT}"
fi
if echo "${PP_OUTPUT}" | grep -q "declared output verified at declaration commit" && \
   echo "${PP_OUTPUT}" | grep -qF "shared.txt"; then
    ok "TEST-039c: distinct drift notice printed, naming shared.txt"
else
    fail "TEST-039c: expected a declaration-commit drift notice naming shared.txt, got: ${PP_OUTPUT}"
fi

# ============================================================================
# TEST-040: a project-root-relative row whose worktree content still
# matches the declared hash (never drifted) exits 0 and prints NO drift
# notice — proves the notice does not become background noise on every
# git-backed report, only on rows the fast path actually had to fall back
# past.
# ============================================================================

echo "=== TEST-040: undrifted project-root row → exit 0, NO drift notice ==="

D040="${WORK}/pp040"
mkdir -p "${D040}/input"
git_init_scratch_repo "${D040}"
write_tasks_with_consent "${D040}/tasks.md" "T-004"
printf 'stable content\n' > "${D040}/stable.txt"
HASH040="$(sha256_of "${D040}/stable.txt")"
write_impl_report "${D040}" "cross-model-verification" "T-004" \
    "$(printf 'stable.txt\t%s' "$HASH040")"
git -C "${D040}" add -A
git -C "${D040}" commit -q -m "declare stable.txt"

PP_EXIT=0
run_prepare \
    --task T-004 --feature cross-model-verification \
    --input "${D040}/input" \
    --tasks-file "${D040}/tasks.md" \
    --project-root "${D040}" \
    --out "${D040}/out.txt"

if [ "${PP_EXIT}" -eq 0 ]; then
    ok "TEST-040a: undrifted row → exit 0"
else
    fail "TEST-040a: expected exit 0, got ${PP_EXIT}. Output: ${PP_OUTPUT}"
fi
if ! echo "${PP_OUTPUT}" | grep -q "declared output verified at declaration commit"; then
    ok "TEST-040b: no drift notice printed for a row that matched the worktree"
else
    fail "TEST-040b: drift notice must not print when the worktree already matches. Output: ${PP_OUTPUT}"
fi

# ============================================================================
# TEST-041: a row mismatched at BOTH the worktree AND the declaration
# commit still fails closed with the unchanged "hash mismatch" message —
# proves the declaration-commit fallback does not degenerate into accepting
# anything just because a commit exists.
# ============================================================================

echo "=== TEST-041: row mismatched at both worktree and declaration commit → fail closed ==="

D041="${WORK}/pp041"
mkdir -p "${D041}/input"
git_init_scratch_repo "${D041}"
write_tasks_with_consent "${D041}/tasks.md" "T-004"
printf 'actual content at report time\n' > "${D041}/mismatch.txt"
write_impl_report "${D041}" "cross-model-verification" "T-004" \
    "$(printf 'mismatch.txt\t%s' "$(wrong_hash)")"
git -C "${D041}" add -A
git -C "${D041}" commit -q -m "declare mismatch.txt with a wrong hash"

PP_EXIT=0
run_prepare \
    --task T-004 --feature cross-model-verification \
    --input "${D041}/input" \
    --tasks-file "${D041}/tasks.md" \
    --project-root "${D041}" \
    --out "${D041}/out.txt"

if [ "${PP_EXIT}" -ne 0 ]; then
    ok "TEST-041a: mismatched at both worktree and declaration commit → nonzero exit"
else
    fail "TEST-041a: expected nonzero exit, got 0. Output: ${PP_OUTPUT}"
fi
if echo "${PP_OUTPUT}" | grep -qF "declared output hash mismatch: mismatch.txt"; then
    ok "TEST-041b: unchanged 'hash mismatch' message text"
else
    fail "TEST-041b: expected unchanged hash-mismatch message, got: ${PP_OUTPUT}"
fi
if ! echo "${PP_OUTPUT}" | grep -q "declared output verified at declaration commit"; then
    ok "TEST-041c: no drift notice printed (declaration commit did not verify either)"
else
    fail "TEST-041c: drift notice must not print when the declaration commit also mismatches. Output: ${PP_OUTPUT}"
fi
if [ ! -f "${D041}/out.txt" ]; then
    ok "TEST-041d: bundle file not written"
else
    fail "TEST-041d: bundle file must not be written"
fi

# ============================================================================
# TEST-042: a row absent under both roots, AND absent at the declaration
# commit (a path that was declared but never actually created, or removed
# before the report was ever committed) still fails closed with the
# unchanged "missing from bundle" message.
# ============================================================================

echo "=== TEST-042: row absent under both roots and at declaration commit → fail closed ==="

D042="${WORK}/pp042"
mkdir -p "${D042}/input"
git_init_scratch_repo "${D042}"
write_tasks_with_consent "${D042}/tasks.md" "T-004"
write_impl_report "${D042}" "cross-model-verification" "T-004" \
    "$(printf 'never-existed.txt\t%s' "$(wrong_hash)")"
git -C "${D042}" add -A
git -C "${D042}" commit -q -m "declare a row for a file that was never created"

PP_EXIT=0
run_prepare \
    --task T-004 --feature cross-model-verification \
    --input "${D042}/input" \
    --tasks-file "${D042}/tasks.md" \
    --project-root "${D042}" \
    --out "${D042}/out.txt"

if [ "${PP_EXIT}" -ne 0 ]; then
    ok "TEST-042a: absent under both roots and at declaration commit → nonzero exit"
else
    fail "TEST-042a: expected nonzero exit, got 0. Output: ${PP_OUTPUT}"
fi
if echo "${PP_OUTPUT}" | grep -qF "declared output missing from bundle: never-existed.txt"; then
    ok "TEST-042b: unchanged 'missing from bundle' message text"
else
    fail "TEST-042b: expected unchanged missing-from-bundle message, got: ${PP_OUTPUT}"
fi
if [ ! -f "${D042}/out.txt" ]; then
    ok "TEST-042c: bundle file not written"
else
    fail "TEST-042c: bundle file must not be written"
fi

# ============================================================================
# TEST-043: the implementation report itself is UNCOMMITTED (added to a git
# repo with other history, but the report file is untracked) — `git log -1
# -- <report>` finds no commit, so the declaration-commit fallback is
# inert and behaviour is identical to today: unchanged "hash mismatch" gap,
# no invented pass.
# ============================================================================

echo "=== TEST-043: uncommitted implementation report → declaration-commit fallback inert ==="

D043="${WORK}/pp043"
mkdir -p "${D043}/input"
git_init_scratch_repo "${D043}"
write_tasks_with_consent "${D043}/tasks.md" "T-004"
printf 'unrelated\n' > "${D043}/unrelated.txt"
git -C "${D043}" add unrelated.txt tasks.md
git -C "${D043}" commit -q -m "unrelated commit; implementation report not yet committed"

printf 'drifted content\n' > "${D043}/shared.txt"
write_impl_report "${D043}" "cross-model-verification" "T-004" \
    "$(printf 'shared.txt\t%s' "$(wrong_hash)")"
# Deliberately NOT committed — the report is untracked.

PP_EXIT=0
run_prepare \
    --task T-004 --feature cross-model-verification \
    --input "${D043}/input" \
    --tasks-file "${D043}/tasks.md" \
    --project-root "${D043}" \
    --out "${D043}/out.txt"

if [ "${PP_EXIT}" -ne 0 ]; then
    ok "TEST-043a: uncommitted report → nonzero exit (no invented pass)"
else
    fail "TEST-043a: expected nonzero exit, got 0. Output: ${PP_OUTPUT}"
fi
if echo "${PP_OUTPUT}" | grep -qF "declared output hash mismatch: shared.txt"; then
    ok "TEST-043b: unchanged 'hash mismatch' message text"
else
    fail "TEST-043b: expected unchanged hash-mismatch message, got: ${PP_OUTPUT}"
fi
if ! echo "${PP_OUTPUT}" | grep -q "declared output verified at declaration commit"; then
    ok "TEST-043c: no drift notice printed (report has no declaration commit)"
else
    fail "TEST-043c: drift notice must not print without a declaration commit. Output: ${PP_OUTPUT}"
fi

# ============================================================================
# TEST-044: a row that escapes --project-root via a symlinked component is
# STILL rejected even when the git history at the declaration commit would,
# byte-for-byte, verify the same relative path — proves containment (the
# b3f6d1a9 symlink component-walk guard) gates BEFORE the declaration-
# commit fallback is even attempted, so a symlink escape can never be
# laundered through git history.
# ============================================================================

echo "=== TEST-044: symlink-escape under --project-root not bypassed by declaration-commit fallback ==="

D044="${WORK}/pp044"
mkdir -p "${D044}/input" "${D044}/linkdir"
git_init_scratch_repo "${D044}"
write_tasks_with_consent "${D044}/tasks.md" "T-004"
SENTINEL044="SENTINEL-TEST044-DO-NOT-LEAK-$$"
printf '%s\n' "$SENTINEL044" > "${D044}/linkdir/secret.txt"
HASH044="$(sha256_of "${D044}/linkdir/secret.txt")"
write_impl_report "${D044}" "cross-model-verification" "T-004" \
    "$(printf 'linkdir/secret.txt\t%s' "$HASH044")"
git -C "${D044}" add -A
git -C "${D044}" commit -q -m "declare linkdir/secret.txt as a plain file"

# A later change replaces linkdir with a symlink pointing outside the
# project root. The content at the same relative path, at the declaration
# commit above, still hash-matches the original declaration — the
# adversarial shape this test targets: containment must gate before any
# declaration-commit fallback is attempted, or a symlink escape could be
# laundered through history.
rm -rf "${D044}/linkdir"
mkdir -p "${D044}/outside"
printf '%s\n' "$SENTINEL044" > "${D044}/outside/secret.txt"
ln -s "${D044}/outside" "${D044}/linkdir"

PP_EXIT=0
run_prepare \
    --task T-004 --feature cross-model-verification \
    --input "${D044}/input" \
    --tasks-file "${D044}/tasks.md" \
    --project-root "${D044}" \
    --out "${D044}/out.txt"

if [ "${PP_EXIT}" -ne 0 ]; then
    ok "TEST-044a: symlink escape → nonzero exit even though declaration-commit content would match"
else
    fail "TEST-044a: expected nonzero exit, got 0. Output: ${PP_OUTPUT}"
fi
if ! echo "${PP_OUTPUT}" | grep -q "declared output verified at declaration commit"; then
    ok "TEST-044b: declaration-commit fallback never attempted (no notice) — containment gates first"
else
    fail "TEST-044b: declaration-commit fallback must not run past a symlink escape. Output: ${PP_OUTPUT}"
fi
if ! echo "${PP_OUTPUT}" | grep -qF "$SENTINEL044"; then
    ok "TEST-044c: sentinel content does not appear in output"
else
    fail "TEST-044c: SENTINEL LEAK via declaration-commit fallback bypassing symlink containment"
fi
if [ ! -f "${D044}/out.txt" ]; then
    ok "TEST-044d: bundle file not written"
else
    fail "TEST-044d: bundle file must not be written"
fi

# ============================================================================
# TEST-045: cross-task isolation — a feature with two tasks, each with its
# own verification/<task_id>/ evidence directory. T-001's bundle carries
# T-001's own evidence and NOT T-002's — the core epic-195 defect (a
# panelist reviewing one task received every OTHER task's evidence too).
# ============================================================================

echo "=== TEST-045: cross-task isolation — T-001 bundle excludes T-002's evidence ==="

D045="${WORK}/pp045"
mkdir -p "${D045}/specs/cross-model-verification/verification/T-001"
mkdir -p "${D045}/specs/cross-model-verification/verification/T-002"
mkdir -p "${D045}/empty-input"
write_tasks_with_consent "${D045}/tasks.md" "T-001"
printf 'T-001 own evidence marker T001MARKER045\n' \
    > "${D045}/specs/cross-model-verification/verification/T-001/evidence.log"
printf 'T-002 own evidence marker T002MARKER045\n' \
    > "${D045}/specs/cross-model-verification/verification/T-002/evidence.log"

PP_EXIT=0
run_prepare \
    --task T-001 --feature cross-model-verification \
    --input "${D045}/empty-input" \
    --tasks-file "${D045}/tasks.md" \
    --project-root "${D045}" \
    --out "${D045}/out.txt"

if [ "${PP_EXIT}" -eq 0 ]; then
    ok "TEST-045a: exit 0"
else
    fail "TEST-045a: expected exit 0, got ${PP_EXIT}. Output: ${PP_OUTPUT}"
fi
if [ -f "${D045}/out.txt" ] && grep -q "T001MARKER045" "${D045}/out.txt"; then
    ok "TEST-045b: T-001's own evidence present in T-001's bundle"
else
    fail "TEST-045b: T-001's own evidence missing from its bundle"
fi
if [ -f "${D045}/out.txt" ] && ! grep -q "T002MARKER045" "${D045}/out.txt"; then
    ok "TEST-045c: T-002's evidence is NOT in T-001's bundle (cross-task isolation)"
else
    fail "TEST-045c: T-002's evidence leaked into T-001's bundle — cross-task isolation broken"
fi

# ============================================================================
# TEST-046: a file named in the reviewed task's Outputs table, living OUTSIDE
# specs/ entirely (a plugin source file — exactly the shape both epic-195
# panelists said was missing), has its CURRENT content appear in the bundle
# — not just verified by the completeness check, actually included.
# ============================================================================

echo "=== TEST-046: Outputs-declared source file content appears in bundle ==="

D046="${WORK}/pp046"
mkdir -p "${D046}/specs/cross-model-verification" "${D046}/plugins/some-plugin/scripts"
mkdir -p "${D046}/empty-input"
write_tasks_with_consent "${D046}/tasks.md" "T-004"
printf 'source file marker SOURCEFILEMARKER046\n' \
    > "${D046}/plugins/some-plugin/scripts/do-thing.sh"
HASH046="$(sha256_of "${D046}/plugins/some-plugin/scripts/do-thing.sh")"
write_impl_report "${D046}" "cross-model-verification" "T-004" \
    "$(printf 'plugins/some-plugin/scripts/do-thing.sh\t%s' "$HASH046")"

PP_EXIT=0
run_prepare \
    --task T-004 --feature cross-model-verification \
    --input "${D046}/empty-input" \
    --tasks-file "${D046}/tasks.md" \
    --project-root "${D046}" \
    --out "${D046}/out.txt"

if [ "${PP_EXIT}" -eq 0 ]; then
    ok "TEST-046a: exit 0"
else
    fail "TEST-046a: expected exit 0, got ${PP_EXIT}. Output: ${PP_OUTPUT}"
fi
if [ -f "${D046}/out.txt" ] && grep -q "SOURCEFILEMARKER046" "${D046}/out.txt"; then
    ok "TEST-046b: declared output's current content is in the bundle"
else
    fail "TEST-046b: declared output was verified but its content never made it into the bundle"
fi

# ============================================================================
# TEST-047: the panel's own artifacts remain excluded under the new
# task-scoped composition — both as siblings of verification/<task_id>/
# (never read by any composition step) and as a stray file INSIDE
# verification/<task_id>/ (excluded by the same find ! -name filters the
# old whole-directory walk applied, now scoped to the task's own directory).
# ============================================================================

echo "=== TEST-047: panel's own artifacts excluded from the task-scoped bundle ==="

D047="${WORK}/pp047"
mkdir -p "${D047}/specs/cross-model-verification/verification/T-004"
mkdir -p "${D047}/empty-input"
write_tasks_with_consent "${D047}/tasks.md" "T-004"
printf 'legit evidence marker LEGITMARKER047\n' \
    > "${D047}/specs/cross-model-verification/verification/T-004/evidence.log"
printf 'SENTINEL VERDICTMARKER047\n' \
    > "${D047}/specs/cross-model-verification/verification/T-004.panelist-anthropic.verdict.json"
printf 'SENTINEL BUNDLEMARKER047\n' \
    > "${D047}/specs/cross-model-verification/verification/T-004.panelist-input.txt"
printf 'SENTINEL NESTEDVERDICTMARKER047\n' \
    > "${D047}/specs/cross-model-verification/verification/T-004/stray.verdict.json"

PP_EXIT=0
run_prepare \
    --task T-004 --feature cross-model-verification \
    --input "${D047}/empty-input" \
    --tasks-file "${D047}/tasks.md" \
    --project-root "${D047}" \
    --out "${D047}/out.txt"

if [ "${PP_EXIT}" -eq 0 ]; then
    ok "TEST-047a: exit 0"
else
    fail "TEST-047a: expected exit 0, got ${PP_EXIT}. Output: ${PP_OUTPUT}"
fi
if [ -f "${D047}/out.txt" ] && grep -q "LEGITMARKER047" "${D047}/out.txt"; then
    ok "TEST-047b: legitimate evidence still included"
else
    fail "TEST-047b: legitimate evidence missing from bundle"
fi
if [ -f "${D047}/out.txt" ] && ! grep -qE "VERDICTMARKER047|BUNDLEMARKER047" "${D047}/out.txt"; then
    ok "TEST-047c: sibling panel artifacts (verification/T-004.*) excluded"
else
    fail "TEST-047c: a sibling panel artifact leaked into the bundle"
fi
if [ -f "${D047}/out.txt" ] && ! grep -q "NESTEDVERDICTMARKER047" "${D047}/out.txt"; then
    ok "TEST-047d: stray panel artifact inside verification/T-004/ excluded"
else
    fail "TEST-047d: a panel artifact nested inside the task's own evidence dir leaked into the bundle"
fi

# ============================================================================
# TEST-048: the feature's spec documents (requirements/design/acceptance-
# tests/tasks/traceability/investigation + layer specs when present) are all
# present in the bundle.
# ============================================================================

echo "=== TEST-048: spec documents all present in the bundle ==="

D048="${WORK}/pp048"
SPECDIR048="${D048}/specs/cross-model-verification"
mkdir -p "${SPECDIR048}/verification/T-004"
mkdir -p "${D048}/empty-input"
write_tasks_with_consent "${SPECDIR048}/tasks.md" "T-004"
printf 'REQMARKER048\n'    > "${SPECDIR048}/requirements.md"
printf 'DESIGNMARKER048\n' > "${SPECDIR048}/design.md"
printf 'ACMARKER048\n'     > "${SPECDIR048}/acceptance-tests.md"
printf 'TRACEMARKER048\n'  > "${SPECDIR048}/traceability.md"
printf 'INVESTMARKER048\n' > "${SPECDIR048}/investigation.md"
printf 'UXMARKER048\n'     > "${SPECDIR048}/ux-spec.md"

PP_EXIT=0
run_prepare \
    --task T-004 --feature cross-model-verification \
    --input "${D048}/empty-input" \
    --tasks-file "${SPECDIR048}/tasks.md" \
    --project-root "${D048}" \
    --out "${D048}/out.txt"

if [ "${PP_EXIT}" -eq 0 ]; then
    ok "TEST-048a: exit 0"
else
    fail "TEST-048a: expected exit 0, got ${PP_EXIT}. Output: ${PP_OUTPUT}"
fi
if [ -f "${D048}/out.txt" ]; then
    _missing048=""
    for _marker048 in REQMARKER048 DESIGNMARKER048 ACMARKER048 TRACEMARKER048 \
        INVESTMARKER048 UXMARKER048; do
        grep -q "$_marker048" "${D048}/out.txt" || _missing048="${_missing048} ${_marker048}"
    done
    if [ -z "$_missing048" ]; then
        ok "TEST-048b: every spec document is present in the bundle"
    else
        fail "TEST-048b: missing spec document markers:${_missing048}"
    fi
    if grep -q "Cross-Model: enabled" "${D048}/out.txt"; then
        ok "TEST-048c: tasks.md itself is present in the bundle"
    else
        fail "TEST-048c: tasks.md content missing from the bundle"
    fi
else
    fail "TEST-048b/c: bundle file not written"
fi

# ============================================================================
# TEST-049 (size guard, fail-closed branch): --max-bytes set below the
# sanitized bundle's actual size → refuses to write a silently-truncated
# bundle, exits nonzero, announces the overage on stderr, prints no digest.
# ============================================================================

echo "=== TEST-049: --max-bytes exceeded → fail closed, no truncated bundle written ==="

D049="${WORK}/pp049"
SPECDIR049="${D049}/specs/cross-model-verification"
mkdir -p "${SPECDIR049}"
mkdir -p "${D049}/empty-input"
write_tasks_with_consent "${SPECDIR049}/tasks.md" "T-004"
{
    i=1
    while [ "$i" -le 50 ]; do
        printf 'requirements line %d filler content filler content filler\n' "$i"
        i=$((i + 1))
    done
} > "${SPECDIR049}/requirements.md"

PP_EXIT=0
run_prepare \
    --task T-004 --feature cross-model-verification \
    --input "${D049}/empty-input" \
    --tasks-file "${SPECDIR049}/tasks.md" \
    --project-root "${D049}" \
    --out "${D049}/out.txt" \
    --max-bytes 200

if [ "${PP_EXIT}" -ne 0 ]; then
    ok "TEST-049a: over --max-bytes → nonzero exit"
else
    fail "TEST-049a: expected nonzero exit, got 0. Output: ${PP_OUTPUT}"
fi
if echo "${PP_OUTPUT}" | grep -qi "max-bytes"; then
    ok "TEST-049b: overage announced on stderr (mentions --max-bytes)"
else
    fail "TEST-049b: expected an announcement mentioning --max-bytes, got: ${PP_OUTPUT}"
fi
if [ ! -f "${D049}/out.txt" ]; then
    ok "TEST-049c: bundle file NOT written (fail closed, never truncated)"
else
    fail "TEST-049c: bundle file must not be written when --max-bytes is exceeded"
fi
if ! echo "${PP_OUTPUT}" | grep -qE '^[0-9a-f]{64}$'; then
    ok "TEST-049d: no digest line printed on a size-guard failure"
else
    fail "TEST-049d: digest must not print when the size guard fails. Output: ${PP_OUTPUT}"
fi

# ============================================================================
# TEST-050 (size guard, pass-through branch): --max-bytes set generously
# above the bundle's actual size → the guard does not interfere with an
# otherwise-successful run.
# ============================================================================

echo "=== TEST-050: --max-bytes generous → guard does not block a normal bundle ==="

D050="${WORK}/pp050"
SPECDIR050="${D050}/specs/cross-model-verification"
mkdir -p "${SPECDIR050}"
mkdir -p "${D050}/empty-input"
write_tasks_with_consent "${SPECDIR050}/tasks.md" "T-004"
printf 'REQMARKER050\n' > "${SPECDIR050}/requirements.md"

PP_EXIT=0
run_prepare \
    --task T-004 --feature cross-model-verification \
    --input "${D050}/empty-input" \
    --tasks-file "${SPECDIR050}/tasks.md" \
    --project-root "${D050}" \
    --out "${D050}/out.txt" \
    --max-bytes 1048576

if [ "${PP_EXIT}" -eq 0 ]; then
    ok "TEST-050a: exit 0 under a generous --max-bytes"
else
    fail "TEST-050a: expected exit 0, got ${PP_EXIT}. Output: ${PP_OUTPUT}"
fi
if [ -f "${D050}/out.txt" ] && grep -q "REQMARKER050" "${D050}/out.txt"; then
    ok "TEST-050b: bundle written normally with content intact"
else
    fail "TEST-050b: bundle missing or content lost under a generous --max-bytes"
fi
if echo "${PP_OUTPUT}" | grep -qE '^[0-9a-f]{64}$'; then
    ok "TEST-050c: digest printed normally"
else
    fail "TEST-050c: expected a printed digest, got: ${PP_OUTPUT}"
fi

# ============================================================================
# TEST-051: a bundle that fits --max-bytes whole is written whole — no
# elision marker anywhere, even though a single verification-dir file is
# large in absolute terms. Budget-driven elision only activates when the
# composed-and-measured bundle is actually over cap; file size alone is
# never sufficient to trigger it.
# ============================================================================

echo "=== TEST-051: bundle under --max-bytes stays whole, regardless of one file's absolute size ==="

D051="${WORK}/pp051"
SPECDIR051="${D051}/specs/cross-model-verification"
mkdir -p "${SPECDIR051}/verification/T-004" "${D051}/empty-input"
write_tasks_with_consent "${SPECDIR051}/tasks.md" "T-004"
write_filler_lines "${SPECDIR051}/verification/T-004/big.log" 500 "LOG051"

PP_EXIT=0
run_prepare \
    --task T-004 --feature cross-model-verification \
    --input "${D051}/empty-input" \
    --tasks-file "${SPECDIR051}/tasks.md" \
    --project-root "${D051}" \
    --out "${D051}/out.txt" \
    --max-bytes 1000000

if [ "${PP_EXIT}" -eq 0 ]; then
    ok "TEST-051a: exit 0"
else
    fail "TEST-051a: expected exit 0, got ${PP_EXIT}. Output: ${PP_OUTPUT}"
fi
if [ -f "${D051}/out.txt" ] && grep -q "LOG051 line 0001 filler filler filler filler" "${D051}/out.txt" \
    && grep -q "LOG051 line 0500 filler filler filler filler" "${D051}/out.txt" \
    && grep -q "LOG051 line 0250 filler filler filler filler" "${D051}/out.txt"; then
    ok "TEST-051b: the file is present whole (first, middle, and last lines all intact)"
else
    fail "TEST-051b: a file was elided even though the whole bundle already fit --max-bytes"
fi
if [ -f "${D051}/out.txt" ] && ! grep -qi "elided from the middle" "${D051}/out.txt"; then
    ok "TEST-051c: no elision marker anywhere in a bundle that never needed one"
else
    fail "TEST-051c: an elision marker appeared even though the bundle already fit --max-bytes"
fi

# ============================================================================
# TEST-052/053: a bundle over --max-bytes elides the LARGEST elidable file
# first and stops as soon as it fits — the marker is present on that file
# with the exact byte count independently computed from its own bytes, the
# elided bundle still carries that file's own first and last lines while
# genuinely dropping a middle-only line, and a SMALLER elidable file in the
# same bundle that was never the reason for the overage is left completely
# untouched (no marker, every one of its own lines present).
# ============================================================================

echo "=== TEST-052/053: over-cap bundle elides the largest file only, leaves a smaller one whole ==="

D052="${WORK}/pp052"
SPECDIR052="${D052}/specs/cross-model-verification"
mkdir -p "${SPECDIR052}/verification/T-004" "${D052}/empty-input"
write_tasks_with_consent "${SPECDIR052}/tasks.md" "T-004"
BIG052="${SPECDIR052}/verification/T-004/big.log"
SMALL052="${SPECDIR052}/verification/T-004/small.log"
write_filler_lines "${BIG052}" 500 "BIG052"
write_filler_lines "${SMALL052}" 20 "SMALL052"

TOTAL052="$(wc -c < "${BIG052}" | tr -d ' ')"
HEAD052="$(head -n 40 "${BIG052}")"
TAIL052="$(tail -n 40 "${BIG052}")"
HEADBYTES052="$(printf '%s\n' "${HEAD052}" | wc -c | tr -d ' ')"
TAILBYTES052="$(printf '%s\n' "${TAIL052}" | wc -c | tr -d ' ')"
EXPECTED_ELIDED052=$((TOTAL052 - HEADBYTES052 - TAILBYTES052))
# --max-bytes 15000 sits strictly between (a) the whole bundle's real size
# (big.log 22,500B + small.log 940B + overhead, ~23,900B — confirmed over
# cap) and (b) that same bundle with ONLY big.log elided (~5,150B — under
# cap) — so eliding big.log alone must be enough; small.log should never
# be touched.
PP_EXIT=0
run_prepare \
    --task T-004 --feature cross-model-verification \
    --input "${D052}/empty-input" \
    --tasks-file "${SPECDIR052}/tasks.md" \
    --project-root "${D052}" \
    --out "${D052}/out.txt" \
    --max-bytes 15000

if [ "${PP_EXIT}" -eq 0 ]; then
    ok "TEST-052a: exit 0 (eliding the largest file alone let the bundle fit)"
else
    fail "TEST-052a: expected exit 0, got ${PP_EXIT}. Output: ${PP_OUTPUT}"
fi
EXPECTED_MARKER052="${EXPECTED_ELIDED052} bytes elided from the middle of specs/cross-model-verification/verification/T-004/big.log (original size ${TOTAL052} bytes"
if [ -f "${D052}/out.txt" ] && grep -qF "${EXPECTED_MARKER052}" "${D052}/out.txt"; then
    ok "TEST-052b: elision marker present on the largest file with the exact independently-computed byte count"
else
    fail "TEST-052b: expected marker containing '${EXPECTED_MARKER052}' not found in bundle"
fi
if [ -f "${D052}/out.txt" ] && [ "$(grep -c 'elided from the middle' "${D052}/out.txt")" -eq 1 ]; then
    ok "TEST-052c: exactly one elision marker — the smaller file was never a candidate that needed cutting"
else
    fail "TEST-052c: expected exactly one elision marker (largest file only)"
fi
if [ -f "${D052}/out.txt" ] && grep -q "BIG052 line 0001 filler filler filler filler" "${D052}/out.txt"; then
    ok "TEST-053a: elided bundle still contains the largest file's first line"
else
    fail "TEST-053a: largest file's first line missing from the elided bundle"
fi
if [ -f "${D052}/out.txt" ] && grep -q "BIG052 line 0500 filler filler filler filler" "${D052}/out.txt"; then
    ok "TEST-053b: elided bundle still contains the largest file's last line"
else
    fail "TEST-053b: largest file's last line missing from the elided bundle"
fi
if [ -f "${D052}/out.txt" ] && ! grep -q "BIG052 line 0250 filler filler filler filler" "${D052}/out.txt"; then
    ok "TEST-053c: a middle-only line of the largest file is genuinely dropped"
else
    fail "TEST-053c: a middle line of the largest file survived — elision did not actually remove the middle"
fi
if [ -f "${D052}/out.txt" ]; then
    _missing_small052=""
    for _line052 in 0001 0010 0020; do
        grep -q "SMALL052 line ${_line052} filler filler filler filler" "${D052}/out.txt" || _missing_small052="${_missing_small052} ${_line052}"
    done
    if [ -z "$_missing_small052" ]; then
        ok "TEST-053d: the smaller file is left completely whole (it was never the file that needed cutting)"
    else
        fail "TEST-053d: the smaller file lost line(s):${_missing_small052} — it should never have been elided"
    fi
else
    fail "TEST-053d: bundle file not written"
fi


# ============================================================================
# TEST-054: elision is scoped to the task's own verification/<task_id>/
# evidence directory only — a spec document (step 1) and an Outputs-declared
# source file living outside specs/ (step 5) are never elided, however large,
# because truncating either would gut the bundle's own claims or their
# supporting source rather than trim incidental log noise.
# ============================================================================

echo "=== TEST-054: spec documents and Outputs-declared source files are never elided ==="

D054="${WORK}/pp054"
SPECDIR054="${D054}/specs/cross-model-verification"
mkdir -p "${SPECDIR054}/verification/T-004" "${D054}/plugins/some-plugin/scripts" "${D054}/empty-input"
write_tasks_with_consent "${SPECDIR054}/tasks.md" "T-004"
write_filler_lines "${SPECDIR054}/requirements.md" 1400 "REQ054"
write_filler_lines "${D054}/plugins/some-plugin/scripts/big-thing.sh" 1400 "SRC054"
HASH054="$(sha256_of "${D054}/plugins/some-plugin/scripts/big-thing.sh")"
write_impl_report "${D054}" "cross-model-verification" "T-004" \
    "$(printf 'plugins/some-plugin/scripts/big-thing.sh\t%s' "$HASH054")"

REQBYTES054="$(wc -c < "${SPECDIR054}/requirements.md" | tr -d ' ')"
SRCBYTES054="$(wc -c < "${D054}/plugins/some-plugin/scripts/big-thing.sh" | tr -d ' ')"
# Both fixture files (~63,000 bytes each) are deliberately sized ABOVE the
# 50,000-byte per-file elision threshold (--max-bytes 200000 / 4) — proving
# these call sites stay whole because they are scoped out, not merely
# because they never crossed the threshold in the first place.

PP_EXIT=0
run_prepare \
    --task T-004 --feature cross-model-verification \
    --input "${D054}/empty-input" \
    --tasks-file "${SPECDIR054}/tasks.md" \
    --project-root "${D054}" \
    --out "${D054}/out.txt" \
    --max-bytes 200000

if [ "${PP_EXIT}" -eq 0 ]; then
    ok "TEST-054a: exit 0"
else
    fail "TEST-054a: expected exit 0, got ${PP_EXIT}. Output: ${PP_OUTPUT}. requirements.md=${REQBYTES054}B (threshold is 50000B), source=${SRCBYTES054}B"
fi
if [ -f "${D054}/out.txt" ] && grep -q "REQ054 line 0001 filler filler filler filler" "${D054}/out.txt" \
    && grep -q "REQ054 line 1400 filler filler filler filler" "${D054}/out.txt" \
    && grep -q "REQ054 line 0700 filler filler filler filler" "${D054}/out.txt"; then
    ok "TEST-054b: spec document (requirements.md, ${REQBYTES054}B > 50000B threshold) present whole, including a middle line"
else
    fail "TEST-054b: requirements.md was elided even though it exceeds the per-file threshold"
fi
if [ -f "${D054}/out.txt" ] && grep -q "SRC054 line 0001 filler filler filler filler" "${D054}/out.txt" \
    && grep -q "SRC054 line 1400 filler filler filler filler" "${D054}/out.txt" \
    && grep -q "SRC054 line 0700 filler filler filler filler" "${D054}/out.txt"; then
    ok "TEST-054c: Outputs-declared source file (${SRCBYTES054}B > 50000B threshold) present whole, including a middle line"
else
    fail "TEST-054c: the declared-output source file was elided even though it exceeds the per-file threshold"
fi
if [ -f "${D054}/out.txt" ] && ! grep -qi "elided from the middle" "${D054}/out.txt"; then
    ok "TEST-054d: no elision marker anywhere in a bundle whose only oversized files are scoped out"
else
    fail "TEST-054d: an elision marker leaked into a bundle whose oversized files should never be elided"
fi
# ============================================================================
# TEST-055: eliding every elidable candidate to its own head/tail/marker
# floor does not guarantee the whole bundle now fits (the degenerate case
# named in the task brief) — when it still does not, the --max-bytes guard
# still fails closed exactly as TEST-049, never silently shipping a bundle
# that even full elision could not bring under the cap.
# ============================================================================

echo "=== TEST-055: still over --max-bytes after exhausting every elidable candidate → fail closed ==="

D055="${WORK}/pp055"
SPECDIR055="${D055}/specs/cross-model-verification"
mkdir -p "${SPECDIR055}/verification/T-004" "${D055}/empty-input"
write_tasks_with_consent "${SPECDIR055}/tasks.md" "T-004"
write_filler_lines "${SPECDIR055}/verification/T-004/run-all-sh.log" 500 "LOG055"

PP_EXIT=0
run_prepare \
    --task T-004 --feature cross-model-verification \
    --input "${D055}/empty-input" \
    --tasks-file "${SPECDIR055}/tasks.md" \
    --project-root "${D055}" \
    --out "${D055}/out.txt" \
    --max-bytes 2000

if [ "${PP_EXIT}" -ne 0 ]; then
    ok "TEST-055a: over --max-bytes even after exhausting the elidable set → nonzero exit"
else
    fail "TEST-055a: expected nonzero exit, got 0. Output: ${PP_OUTPUT}"
fi
if echo "${PP_OUTPUT}" | grep -qi "max-bytes"; then
    ok "TEST-055b: overage announced on stderr (mentions --max-bytes)"
else
    fail "TEST-055b: expected an announcement mentioning --max-bytes, got: ${PP_OUTPUT}"
fi
if [ ! -f "${D055}/out.txt" ]; then
    ok "TEST-055c: bundle file NOT written (fail closed, elision is not a truncation loophole)"
else
    fail "TEST-055c: bundle file must not be written when still over --max-bytes after elision"
fi
if ! echo "${PP_OUTPUT}" | grep -qE '^[0-9a-f]{64}$'; then
    ok "TEST-055d: no digest line printed on a size-guard failure"
else
    fail "TEST-055d: digest must not print when the size guard fails. Output: ${PP_OUTPUT}"
fi

# ============================================================================
# TEST-056: the SAME over-cap bundle (TEST-052/053's own fixture) comes
# back byte-for-byte whole under a larger --max-bytes — elision is a
# property of whether the bundle needs it under the cap actually supplied,
# never a property baked into a file for being "big enough" in isolation.
# ============================================================================

echo "=== TEST-056: same bundle, larger --max-bytes → comes back whole ==="

D056="${WORK}/pp056"
SPECDIR056="${D056}/specs/cross-model-verification"
mkdir -p "${SPECDIR056}/verification/T-004" "${D056}/empty-input"
write_tasks_with_consent "${SPECDIR056}/tasks.md" "T-004"
write_filler_lines "${SPECDIR056}/verification/T-004/big.log" 500 "BIG056"
write_filler_lines "${SPECDIR056}/verification/T-004/small.log" 20 "SMALL056"

PP_EXIT=0
run_prepare \
    --task T-004 --feature cross-model-verification \
    --input "${D056}/empty-input" \
    --tasks-file "${SPECDIR056}/tasks.md" \
    --project-root "${D056}" \
    --out "${D056}/out.txt" \
    --max-bytes 1000000

if [ "${PP_EXIT}" -eq 0 ]; then
    ok "TEST-056a: exit 0 under a generous --max-bytes"
else
    fail "TEST-056a: expected exit 0, got ${PP_EXIT}. Output: ${PP_OUTPUT}"
fi
if [ -f "${D056}/out.txt" ] && ! grep -qi "elided from the middle" "${D056}/out.txt"; then
    ok "TEST-056b: no elision marker anywhere once the bundle fits without cutting anything"
else
    fail "TEST-056b: an elision marker survived into a bundle that fits --max-bytes whole"
fi
if [ -f "${D056}/out.txt" ] && grep -q "BIG056 line 0250 filler filler filler filler" "${D056}/out.txt"; then
    ok "TEST-056c: the larger file's middle line is present — the same file TEST-052/053 elides at a tighter cap comes back whole here"
else
    fail "TEST-056c: the larger file's middle line is missing even though this bundle fits whole"
fi

# ============================================================================
# TEST-057: a check's "evidence" field naming a path OUTSIDE the reviewed
# task's own verification/<task_id>/ directory (e.g. a shared
# verification/qg/shared/ log, the epic-194 T-001 real-world shape) has its
# CURRENT content included in the bundle — not just verified to exist, its
# bytes actually appear, closing the gap where a panelist was handed a
# check's passes:false claim with no way to read what it pointed at.
# ============================================================================

echo "=== TEST-057: contract-declared evidence outside verification/<task_id>/ appears in bundle ==="

D057="${WORK}/pp057"
SPECDIR057="${D057}/specs/cross-model-verification"
mkdir -p "${SPECDIR057}/verification/T-004" "${SPECDIR057}/verification/qg/shared" "${D057}/empty-input"
write_tasks_with_consent "${SPECDIR057}/tasks.md" "T-004"
printf 'REGRESSIONMARKER057\n' > "${SPECDIR057}/verification/qg/shared/regression-057.log"
write_contract "${SPECDIR057}" "T-004" \
    "regression" "specs/cross-model-verification/verification/qg/shared/regression-057.log" "" ""

PP_EXIT=0
run_prepare \
    --task T-004 --feature cross-model-verification \
    --input "${D057}/empty-input" \
    --tasks-file "${SPECDIR057}/tasks.md" \
    --project-root "${D057}" \
    --out "${D057}/out.txt"

if [ "${PP_EXIT}" -eq 0 ]; then
    ok "TEST-057a: exit 0"
else
    fail "TEST-057a: expected exit 0, got ${PP_EXIT}. Output: ${PP_OUTPUT}"
fi
if [ -f "${D057}/out.txt" ] && grep -q "REGRESSIONMARKER057" "${D057}/out.txt"; then
    ok "TEST-057b: contract-declared evidence content is in the bundle"
else
    fail "TEST-057b: shared verification/qg/ evidence named by the contract never made it into the bundle"
fi
if [ -f "${D057}/out.txt" ] && grep -qF "# ---- specs/cross-model-verification/verification/qg/shared/regression-057.log ----" "${D057}/out.txt"; then
    ok "TEST-057c: the path header names the file, so a reviewer can tell which evidence it is"
else
    fail "TEST-057c: expected path header missing"
fi

# ============================================================================
# TEST-058: red_evidence and green_evidence are picked up, not just evidence
# — a TDD check's contract routinely leaves "evidence" pointing at the same
# thing as "green_evidence" but a check could, in principle, carry only a
# red/green pair; both fields must independently contribute their own path.
# ============================================================================

echo "=== TEST-058: red_evidence and green_evidence are also picked up ==="

D058="${WORK}/pp058"
SPECDIR058="${D058}/specs/cross-model-verification"
mkdir -p "${SPECDIR058}/verification/T-004" "${SPECDIR058}/verification/qg/shared" "${D058}/empty-input"
write_tasks_with_consent "${SPECDIR058}/tasks.md" "T-004"
printf 'REDMARKER058\n'   > "${SPECDIR058}/verification/qg/shared/red-058.log"
printf 'GREENMARKER058\n' > "${SPECDIR058}/verification/qg/shared/green-058.log"
write_contract "${SPECDIR058}" "T-004" \
    "unit-tests" "" \
    "specs/cross-model-verification/verification/qg/shared/red-058.log" \
    "specs/cross-model-verification/verification/qg/shared/green-058.log"

PP_EXIT=0
run_prepare \
    --task T-004 --feature cross-model-verification \
    --input "${D058}/empty-input" \
    --tasks-file "${SPECDIR058}/tasks.md" \
    --project-root "${D058}" \
    --out "${D058}/out.txt"

if [ "${PP_EXIT}" -eq 0 ]; then
    ok "TEST-058a: exit 0"
else
    fail "TEST-058a: expected exit 0, got ${PP_EXIT}. Output: ${PP_OUTPUT}"
fi
if [ -f "${D058}/out.txt" ] && grep -q "REDMARKER058" "${D058}/out.txt"; then
    ok "TEST-058b: red_evidence content is in the bundle"
else
    fail "TEST-058b: red_evidence-declared file never made it into the bundle"
fi
if [ -f "${D058}/out.txt" ] && grep -q "GREENMARKER058" "${D058}/out.txt"; then
    ok "TEST-058c: green_evidence content is in the bundle"
else
    fail "TEST-058c: green_evidence-declared file never made it into the bundle"
fi

# ============================================================================
# TEST-059: dedup — a contract-declared path already pulled in by the
# reviewed task's own verification/<task_id>/ directory walk (059a), or
# already pulled in by an Outputs-table row (059b), is included exactly
# ONCE, never a second time for being separately named by the contract.
# ============================================================================

echo "=== TEST-059: contract-declared evidence already included elsewhere is not duplicated ==="

D059="${WORK}/pp059"
SPECDIR059="${D059}/specs/cross-model-verification"
mkdir -p "${SPECDIR059}/verification/T-004" "${D059}/plugins/some-plugin/scripts" "${D059}/empty-input"
write_tasks_with_consent "${SPECDIR059}/tasks.md" "T-004"
printf 'INBANDMARKER059\n' > "${SPECDIR059}/verification/T-004/inband-059.log"
printf 'SRCMARKER059\n' > "${D059}/plugins/some-plugin/scripts/thing-059.sh"
HASH059="$(sha256_of "${D059}/plugins/some-plugin/scripts/thing-059.sh")"
write_impl_report "${D059}" "cross-model-verification" "T-004" \
    "$(printf 'plugins/some-plugin/scripts/thing-059.sh\t%s' "$HASH059")"
write_contract "${SPECDIR059}" "T-004" \
    "already-in-dir" "specs/cross-model-verification/verification/T-004/inband-059.log" "" "" \
    "already-in-outputs" "plugins/some-plugin/scripts/thing-059.sh" "" ""

PP_EXIT=0
run_prepare \
    --task T-004 --feature cross-model-verification \
    --input "${D059}/empty-input" \
    --tasks-file "${SPECDIR059}/tasks.md" \
    --project-root "${D059}" \
    --out "${D059}/out.txt"

if [ "${PP_EXIT}" -eq 0 ]; then
    ok "TEST-059a: exit 0"
else
    fail "TEST-059a: expected exit 0, got ${PP_EXIT}. Output: ${PP_OUTPUT}"
fi
if [ -f "${D059}/out.txt" ] && [ "$(grep -c 'INBANDMARKER059' "${D059}/out.txt")" -eq 1 ]; then
    ok "TEST-059b: directory-walk file re-declared by the contract appears exactly once"
else
    fail "TEST-059b: expected exactly one occurrence of INBANDMARKER059"
fi
if [ -f "${D059}/out.txt" ] && [ "$(grep -c 'SRCMARKER059' "${D059}/out.txt")" -eq 1 ]; then
    ok "TEST-059c: Outputs-declared file re-declared by the contract appears exactly once"
else
    fail "TEST-059c: expected exactly one occurrence of SRCMARKER059"
fi

# ============================================================================
# TEST-060: empty evidence/red_evidence/green_evidence fields (the norm —
# most checks in a real contract, e.g. a waived lint/typecheck/build check,
# carry "") produce no bundle output and no error. This is the common case
# every other TEST-057..062 fixture deliberately does NOT exercise on its
# own unrequired checks, so it earns a dedicated assertion.
# ============================================================================

echo "=== TEST-060: empty contract evidence fields produce no output and no error ==="

D060="${WORK}/pp060"
SPECDIR060="${D060}/specs/cross-model-verification"
mkdir -p "${SPECDIR060}/verification/T-004" "${D060}/empty-input"
write_tasks_with_consent "${SPECDIR060}/tasks.md" "T-004"
write_contract "${SPECDIR060}" "T-004" \
    "lint" "" "" "" \
    "typecheck" "" "" "" \
    "build" "" "" ""

PP_EXIT=0
run_prepare \
    --task T-004 --feature cross-model-verification \
    --input "${D060}/empty-input" \
    --tasks-file "${SPECDIR060}/tasks.md" \
    --project-root "${D060}" \
    --out "${D060}/out.txt"

if [ "${PP_EXIT}" -eq 0 ]; then
    ok "TEST-060a: exit 0"
else
    fail "TEST-060a: expected exit 0, got ${PP_EXIT}. Output: ${PP_OUTPUT}"
fi
if [ -f "${D060}/out.txt" ] && ! grep -qi "contract-declared evidence" "${D060}/out.txt"; then
    ok "TEST-060b: no contract-declared-evidence section appears when every field is empty"
else
    fail "TEST-060b: a contract-declared-evidence section leaked in for an all-empty-fields contract"
fi
if echo "${PP_OUTPUT}" | grep -qE '^[0-9a-f]{64}$'; then
    ok "TEST-060c: normal digest line still printed — empty fields are not an error"
else
    fail "TEST-060c: expected a digest line, got: ${PP_OUTPUT}"
fi

# ============================================================================
# TEST-061: a declared-but-missing contract evidence path is a finding, not
# a crash or a silent omission — the bundle carries a one-line note naming
# the path and stating no file exists there, and the run still exits 0
# (telling the reviewer a contract points at nothing is true and useful;
# refusing to write the whole bundle over it would throw away every OTHER
# check's real evidence over one dangling reference).
# ============================================================================

echo "=== TEST-061: declared-but-missing contract evidence path → noted, not silently dropped ==="

D061="${WORK}/pp061"
SPECDIR061="${D061}/specs/cross-model-verification"
mkdir -p "${SPECDIR061}/verification/T-004" "${D061}/empty-input"
write_tasks_with_consent "${SPECDIR061}/tasks.md" "T-004"
write_contract "${SPECDIR061}" "T-004" \
    "regression" "specs/cross-model-verification/verification/qg/shared/nope-061.log" "" ""

PP_EXIT=0
run_prepare \
    --task T-004 --feature cross-model-verification \
    --input "${D061}/empty-input" \
    --tasks-file "${SPECDIR061}/tasks.md" \
    --project-root "${D061}" \
    --out "${D061}/out.txt"

if [ "${PP_EXIT}" -eq 0 ]; then
    ok "TEST-061a: exit 0 (a dangling contract reference does not fail the whole run)"
else
    fail "TEST-061a: expected exit 0, got ${PP_EXIT}. Output: ${PP_OUTPUT}"
fi
if [ -f "${D061}/out.txt" ] && grep -qF "specs/cross-model-verification/verification/qg/shared/nope-061.log (contract-declared evidence, not found)" "${D061}/out.txt"; then
    ok "TEST-061b: the bundle names the missing path"
else
    fail "TEST-061b: expected a not-found note naming the missing path"
fi
if [ -f "${D061}/out.txt" ] && grep -qF "[contract names this evidence path but no file exists there]" "${D061}/out.txt"; then
    ok "TEST-061c: the note states plainly that no file exists there"
else
    fail "TEST-061c: expected a plain-language explanation of the gap"
fi

# ============================================================================
# TEST-062: a large contract-declared evidence file (living OUTSIDE
# verification/<task_id>/, so only reachable via step 3b, not the directory
# walk) is elided under a tight --max-bytes exactly like a directory-walk
# file would be — proving it joined the SAME elidable candidate set, not a
# separate always-whole one.
# ============================================================================

echo "=== TEST-062: large contract-declared evidence file is elided under a tight --max-bytes ==="

D062="${WORK}/pp062"
SPECDIR062="${D062}/specs/cross-model-verification"
mkdir -p "${SPECDIR062}/verification/T-004" "${SPECDIR062}/verification/qg/shared" "${D062}/empty-input"
write_tasks_with_consent "${SPECDIR062}/tasks.md" "T-004"
BIG062="${SPECDIR062}/verification/qg/shared/big-062.log"
write_filler_lines "${BIG062}" 500 "BIG062"
write_contract "${SPECDIR062}" "T-004" \
    "regression" "specs/cross-model-verification/verification/qg/shared/big-062.log" "" ""

TOTAL062="$(wc -c < "${BIG062}" | tr -d ' ')"
HEAD062="$(head -n 40 "${BIG062}")"
TAIL062="$(tail -n 40 "${BIG062}")"
HEADBYTES062="$(printf '%s\n' "${HEAD062}" | wc -c | tr -d ' ')"
TAILBYTES062="$(printf '%s\n' "${TAIL062}" | wc -c | tr -d ' ')"
EXPECTED_ELIDED062=$((TOTAL062 - HEADBYTES062 - TAILBYTES062))

PP_EXIT=0
run_prepare \
    --task T-004 --feature cross-model-verification \
    --input "${D062}/empty-input" \
    --tasks-file "${SPECDIR062}/tasks.md" \
    --project-root "${D062}" \
    --out "${D062}/out.txt" \
    --max-bytes 15000

if [ "${PP_EXIT}" -eq 0 ]; then
    ok "TEST-062a: exit 0 (eliding the contract-declared file alone let the bundle fit)"
else
    fail "TEST-062a: expected exit 0, got ${PP_EXIT}. Output: ${PP_OUTPUT}"
fi
EXPECTED_MARKER062="${EXPECTED_ELIDED062} bytes elided from the middle of specs/cross-model-verification/verification/qg/shared/big-062.log (original size ${TOTAL062} bytes"
if [ -f "${D062}/out.txt" ] && grep -qF "${EXPECTED_MARKER062}" "${D062}/out.txt"; then
    ok "TEST-062b: elision marker present on the contract-declared file with the exact independently-computed byte count"
else
    fail "TEST-062b: expected marker containing '${EXPECTED_MARKER062}' not found in bundle"
fi
if [ -f "${D062}/out.txt" ] && grep -q "BIG062 line 0001 filler filler filler filler" "${D062}/out.txt" \
    && grep -q "BIG062 line 0500 filler filler filler filler" "${D062}/out.txt" \
    && ! grep -q "BIG062 line 0250 filler filler filler filler" "${D062}/out.txt"; then
    ok "TEST-062c: elided bundle keeps first/last lines and genuinely drops a middle line"
else
    fail "TEST-062c: elided bundle's head/tail/middle content does not match expectations"
fi

# ============================================================================
# TEST-063/064: a project-root-relative row whose worktree content has
# DRIFTED (same shape as TEST-039) must put the CURRENT worktree bytes into
# the bundle, not the declaration-commit bytes — and must say so, IN the
# bundle, where a reviewer will actually see it. TEST-039 only proved the
# gate stays open (exit 0 + a stderr-only notice); it never inspected what
# landed in the bundle file itself. This is the defect this change fixes:
# a panelist judging "the code as it stands" was quietly handed weeks-old
# bytes instead.
# ============================================================================

echo "=== TEST-063/064: drifted row serves CURRENT bytes + in-bundle stale notice ==="

D063="${WORK}/pp063"
mkdir -p "${D063}/input"
git_init_scratch_repo "${D063}"
write_tasks_with_consent "${D063}/tasks.md" "T-004"
printf 'MARKER_V1_ONLY shared content\n' > "${D063}/shared.txt"
HASH063_V1="$(sha256_of "${D063}/shared.txt")"
write_impl_report "${D063}" "cross-model-verification" "T-004" \
    "$(printf 'shared.txt\t%s' "$HASH063_V1")"
git -C "${D063}" add -A
git -C "${D063}" commit -q -m "declare shared.txt v1"

# A later sibling task drifts the shared file; the report's declared hash
# (v1) is now stale relative to the worktree (v2).
printf 'MARKER_V2_ONLY shared content (drifted)\n' > "${D063}/shared.txt"
git -C "${D063}" add -A
git -C "${D063}" commit -q -m "sibling task drifts shared.txt"

PP_EXIT=0
run_prepare \
    --task T-004 --feature cross-model-verification \
    --input "${D063}/input" \
    --tasks-file "${D063}/tasks.md" \
    --project-root "${D063}" \
    --out "${D063}/out.txt"

if [ "${PP_EXIT}" -eq 0 ]; then
    ok "TEST-063a: drifted row still exits 0"
else
    fail "TEST-063a: expected exit 0, got ${PP_EXIT}. Output: ${PP_OUTPUT}"
fi
if [ -f "${D063}/out.txt" ] && grep -qF "MARKER_V2_ONLY" "${D063}/out.txt"; then
    ok "TEST-063b: bundle carries the CURRENT worktree bytes (v2 marker present)"
else
    fail "TEST-063b: expected v2 (current worktree) content in the bundle, not found"
fi
if [ -f "${D063}/out.txt" ] && ! grep -qF "MARKER_V1_ONLY" "${D063}/out.txt"; then
    ok "TEST-063c: bundle does NOT carry the declaration-commit (historical) bytes"
else
    fail "TEST-063c: found declaration-commit (v1) content in the bundle — historical bytes leaked into review material"
fi
if [ -f "${D063}/out.txt" ] && \
   grep -qF "shared.txt (declared output" "${D063}/out.txt" && \
   grep -qF "implementation report's declared hash for this path is STALE" "${D063}/out.txt"; then
    ok "TEST-064a: in-bundle notice names shared.txt and states the report's declared hash is stale (found in the bundle FILE, not only stderr)"
else
    fail "TEST-064a: expected an in-bundle stale-declaration notice naming shared.txt"
fi

# ============================================================================
# TEST-065: a project-root-relative row whose worktree content still
# matches the declared hash produces NO stale-declaration notice anywhere
# in the bundle — proves the notice is conditioned on an actual mismatch,
# not printed unconditionally on every declared-outputs row.
# ============================================================================

echo "=== TEST-065: undrifted row → bundle carries content, NO stale notice ==="

D065="${WORK}/pp065"
mkdir -p "${D065}/input"
git_init_scratch_repo "${D065}"
write_tasks_with_consent "${D065}/tasks.md" "T-004"
printf 'MARKER_STABLE_065 stable content\n' > "${D065}/stable.txt"
HASH065="$(sha256_of "${D065}/stable.txt")"
write_impl_report "${D065}" "cross-model-verification" "T-004" \
    "$(printf 'stable.txt\t%s' "$HASH065")"
git -C "${D065}" add -A
git -C "${D065}" commit -q -m "declare stable.txt"

PP_EXIT=0
run_prepare \
    --task T-004 --feature cross-model-verification \
    --input "${D065}/input" \
    --tasks-file "${D065}/tasks.md" \
    --project-root "${D065}" \
    --out "${D065}/out.txt"

if [ -f "${D065}/out.txt" ] && grep -qF "MARKER_STABLE_065" "${D065}/out.txt"; then
    ok "TEST-065a: matching-hash row still carries its content"
else
    fail "TEST-065a: expected stable.txt content in the bundle"
fi
if [ -f "${D065}/out.txt" ] && ! grep -q "is STALE" "${D065}/out.txt"; then
    ok "TEST-065b: no stale-declaration notice for a row whose hash already matched"
else
    fail "TEST-065b: a stale notice must not appear when the worktree hash matched directly. Output: $(cat "${D065}/out.txt" 2>/dev/null)"
fi

# ============================================================================
# TEST-066: a declared row that no longer exists anywhere in the worktree
# (deleted by a later commit) but DID exist with a matching hash at the
# report's own declaration commit. There is no current content to serve —
# silently falling back to the declaration-commit blob here would be the
# exact defect this change fixes, one case further: a reviewer handed a
# file that has been REMOVED, presented as if it still existed. The chosen
# behavior is to serve no content and say so plainly in the bundle, while
# leaving the completeness gate itself unchanged (still exit 0 — the
# declaration was true when written).
# ============================================================================

echo "=== TEST-066: declared row deleted from worktree → notice only, no historical content ==="

D066="${WORK}/pp066"
mkdir -p "${D066}/input"
git_init_scratch_repo "${D066}"
write_tasks_with_consent "${D066}/tasks.md" "T-004"
printf 'MARKER_DELETED_066 content that will vanish\n' > "${D066}/deleted.txt"
HASH066="$(sha256_of "${D066}/deleted.txt")"
write_impl_report "${D066}" "cross-model-verification" "T-004" \
    "$(printf 'deleted.txt\t%s' "$HASH066")"
git -C "${D066}" add -A
git -C "${D066}" commit -q -m "declare deleted.txt"

git -C "${D066}" rm -q deleted.txt
git -C "${D066}" commit -q -m "sibling task deletes deleted.txt"

PP_EXIT=0
run_prepare \
    --task T-004 --feature cross-model-verification \
    --input "${D066}/input" \
    --tasks-file "${D066}/tasks.md" \
    --project-root "${D066}" \
    --out "${D066}/out.txt"

if [ "${PP_EXIT}" -eq 0 ]; then
    ok "TEST-066a: row deleted from the worktree but true at declaration commit → gate unchanged, exit 0"
else
    fail "TEST-066a: expected exit 0, got ${PP_EXIT}. Output: ${PP_OUTPUT}"
fi
if [ -f "${D066}/out.txt" ] && ! grep -qF "MARKER_DELETED_066" "${D066}/out.txt"; then
    ok "TEST-066b: bundle does NOT carry the deleted file's historical bytes"
else
    fail "TEST-066b: deleted file's historical content leaked into the bundle"
fi
if [ -f "${D066}/out.txt" ] && \
   grep -qF "deleted.txt (declared output" "${D066}/out.txt" && \
   grep -qF "MISSING from the worktree" "${D066}/out.txt" && \
   grep -qF "STALE" "${D066}/out.txt"; then
    ok "TEST-066c: bundle names deleted.txt and states its declaration is stale/missing"
else
    fail "TEST-066c: expected an in-bundle missing/stale notice naming deleted.txt"
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
