#!/bin/sh
# T-011 (epic-189-a1-project-context, REQ-009): acceptance checks for the
# ADR-0023 track-selection contract as documented in PLUGIN-CONTRACTS.md and
# in the THREE UNPROTECTED migrated consumer skills.
#
# Scope note (read before adding cases): this suite deliberately covers only
# the UNPROTECTED half of REQ-009's five-consumer matrix --
# PLUGIN-CONTRACTS.md, sdd-bootstrap/bootstrap, sdd-bootstrap-interviewer,
# and sdd-lite/lite-gate. The two PROTECTED consumers (sdd-ship/ship,
# sdd-lite/lite-spec) are migrated via apply-human-copy in T-012, which also
# completes AC-039's 30-assertion matrix and AC-035's full wiring inventory.
#
# TEST-024 document conformance (AC-024): PLUGIN-CONTRACTS.md's Track
#   Detection section carries the four-case Project-Context-present rule,
#   and the legacy CLI-flag-first order is retitled as the
#   compatibility-fallback path and appears AFTER it.
# TEST-026 PROJECT_CONTEXT_INVALID explicit-stop, fixture-driven (AC-026,
#   unprotected half): SIX independently-constructed fixture projects, each
#   physically PRESENT on disk and each failing the REAL
#   validate-approval-sidecar.py for a DIFFERENT one of AC-026's six named
#   reasons, are each routed by every document's own documented table to
#   PROJECT_CONTEXT_INVALID. A SEVENTH fixture with the content file
#   physically ABSENT routes to COMPATIBILITY_FALLBACK. The two resolutions
#   are then asserted DISTINCT -- that inequality, not either lookup alone,
#   is what proves the present-but-invalid route is not the fallback route
#   wearing a different label (security-spec.md B5).
# TEST-039 per-consumer common-contract-suite matrix (AC-039, unprotected
#   half): all six cases resolved independently against EACH of the four
#   documents' own tables -- never one document inspected and the other
#   three asserted by similarity. The lite/full promotion and error-stop
#   cases (C3..C6) are driven from fixture projects whose spec_profile is
#   read back off disk and whose sidecar the REAL validator PASSED, so the
#   branch a consumer would actually take is observed, not assumed.
# TEST-035P handshake wiring (AC-035, partial -- completed in T-012): each
#   of the three consumer skills carries the REQ-010 challenge/response
#   wiring at its own entry point, naming the emit/verify subcommands, the
#   canary target, and the fail-closed CAPABILITY_RUNTIME_UNAVAILABLE stop.
# TEST-MUT detection-power proof: twelve independent mutations of a
#   THROWAWAY COPY of the four documents (never the repository) must each be
#   caught. Every mutation assertion is a DELTA -- the pristine copy must
#   CONFORM and the mutated copy must be REJECTED with the specific
#   expected finding -- so none of them can pass vacuously while the
#   documents are still unmigrated (the TDD Red state), which is exactly how
#   a mutation test silently measures nothing.
#
# Fixture-path convention: this suite's approver-registry and sidecar
# fixtures are deliberately NOT placed at sdd/approver-registry.yaml or
# sdd/project-context.approval.json. Those suffixes are PROTECTED-MANIFEST
# entries, and the hook guard's R-10 pre-filter refuses any agent command
# string containing them -- a suite that embeds them cannot be maintained
# from an agent session. Both tools take the path as an argument, so the
# fixture layout is free. The CONTENT file stays at sdd/project-context.yaml
# because physical presence AT THAT PATH is the very thing under test.
set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/plugin-contracts-track-selection-test.XXXXXX")
# Physical-path normalization (design.md Test Strategy item 12).
WORK=$(cd "$WORK" && pwd -P)
trap 'rm -rf "$WORK"' EXIT INT TERM

GEN_PY="$ROOT/plugins/sdd-quality-loop/scripts/generate-approval-sidecar.py"
VAL_PY="$ROOT/plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py"

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; }
assert_eq() {
  if [ "$1" = "$2" ]; then pass "$3"; else fail "$3 (expected [$2], got [$1])"; fi
}

if command -v python3 >/dev/null 2>&1; then
  PY=python3
elif command -v python >/dev/null 2>&1; then
  PY=python
else
  printf 'FAIL: no python3/python interpreter available\n'
  exit 1
fi

PYTHONDONTWRITEBYTECODE=1
export PYTHONDONTWRITEBYTECODE

TESTKEY=t011-track-selection-test-key

# The four documents under test, as repository-relative paths. conform.py
# resolves them against whatever root it is handed, so the identical checker
# runs against the live tree and against every throwaway mutation copy.
DOC_CONTRACTS='PLUGIN-CONTRACTS.md'
DOC_BOOTSTRAP='plugins/sdd-bootstrap/skills/bootstrap/SKILL.md'
DOC_INTERVIEWER='plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md'
DOC_LITEGATE='plugins/sdd-lite/skills/lite-gate/SKILL.md'
# T-012 extension: the two PROTECTED consumers, read from the staged
# candidates T-012 authors under the guard-exempt human-copy prefix. The
# checker below is path-agnostic, so this is a list extension (4 -> 6), never
# a parallel copy of the checker.
_T012_STAGE='specs/epic-189-a1-project-context/human-copy'
DOC_SHIP="$_T012_STAGE/plugins/sdd-ship/skills/ship/SKILL.md"
DOC_LITESPEC="$_T012_STAGE/plugins/sdd-lite/skills/lite-spec/SKILL.md"
CONSUMER_DOCS="$DOC_BOOTSTRAP $DOC_INTERVIEWER $DOC_LITEGATE $DOC_SHIP $DOC_LITESPEC"
ALL_DOCS="$DOC_CONTRACTS $CONSUMER_DOCS"

# ---------------------------------------------------------------------------
# conform.py -- the single document-conformance checker.
#
# Modes:
#   conform.py check <root>        one OK|<doc>|<check> or
#                                  BAD|<doc>|<check>|<detail> line per check;
#                                  exit 1 if any BAD.
#   conform.py table <root> <doc>  the document's own parsed contract rows as
#                                  Cn|<state>|<flag>|<resolution>; exit 1 if
#                                  the block is missing or unparseable.
#
# EXPECTED_ROWS is derived from ADR-0023 / requirements.md AC-024+AC-039 and
# lives HERE, in the test, never read back out of a document -- otherwise a
# document could define its own correctness and the comparison would be an
# echo of its own input.
# ---------------------------------------------------------------------------
CONFORM="$WORK/conform.py"
cat > "$CONFORM" <<'PYEOF'
import os
import re
import sys

CONTRACT_OPEN = "<!-- sdd:track-selection-contract v1 -->"
CONTRACT_CLOSE = "<!-- /sdd:track-selection-contract -->"
HANDSHAKE_OPEN = "<!-- sdd:handshake-wiring v1 -->"
HANDSHAKE_CLOSE = "<!-- /sdd:handshake-wiring -->"

EXPECTED_ROWS = [
    ("C1", "physically absent",
     "--full, --lite, or none", "COMPATIBILITY_FALLBACK"),
    ("C2", "physically present, REQ-005 validation fails",
     "--full, --lite, or none", "PROJECT_CONTEXT_INVALID"),
    ("C3", "physically present and valid, spec_profile: lite",
     "--full", "PROMOTE_FULL"),
    ("C4", "physically present and valid, spec_profile: lite",
     "--lite", "NO_OP_LITE"),
    ("C5", "physically present and valid, spec_profile: full",
     "--lite", "ERROR_STOP"),
    ("C6", "physically present and valid, spec_profile: full",
     "--full", "NO_OP_FULL"),
]

# REQ-010's challenge/response protocol, as every wired entry point must name
# it. Each token is independently load-bearing: drop the verify subcommand and
# a skill could "run the handshake" without ever checking the answer; drop the
# fail-closed token and a non-HOOK_ACTIVE verdict has no documented stop.
HANDSHAKE_TOKENS = [
    "check-hook-activation-handshake",
    "--emit-challenge",
    "--verify-response",
    "sdd/.hook-canary-" + "sentinel",
    "HOOK_ACTIVE",
    "CAPABILITY_RUNTIME_UNAVAILABLE",
]

CONTRACTS = "PLUGIN-CONTRACTS.md"
BOOTSTRAP = "plugins/sdd-bootstrap/skills/bootstrap/SKILL.md"
INTERVIEWER = "plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md"
LITEGATE = "plugins/sdd-lite/skills/lite-gate/SKILL.md"
# T-012: the two protected consumers, as their staged candidates.
_STAGE = "specs/epic-189-a1-project-context/human-copy"
SHIP = _STAGE + "/plugins/sdd-ship/skills/ship/SKILL.md"
LITESPEC = _STAGE + "/plugins/sdd-lite/skills/lite-spec/SKILL.md"
CONSUMERS = [BOOTSTRAP, INTERVIEWER, LITEGATE, SHIP, LITESPEC]
ALL_DOCS = [CONTRACTS] + CONSUMERS

# The compatibility fallback's own four steps (ADR-0023 decision 2: the
# pre-existing priority order, preserved unchanged).
FALLBACK_HEADING = "Compatibility fallback (no Project Context)"
FALLBACK_STEPS = ["`--full`", "`--lite`", "`spec_profile: lite`", "Default"]

# sdd-bootstrap-interviewer's three spec_profile read sites (tasks.md T-011
# Must Read). Each must gate on the RESOLVED track, not on a fresh, unvalidated
# AGENTS.md read of its own.
INTERVIEWER_GATES = [
    "## Specification Review Gate",
    "## Implementation Policy Review Gate",
    "## Task Decomposition Review Gate",
]
INTERVIEWER_GATE_MARKER = "resolved track"
# Pre-migration phrasings. Their survival anywhere in the document means a read
# site still bypasses the contract.
LEGACY_GATE_PHRASES = [
    "If `spec_profile: lite` in AGENTS.md → SKIP",
    "Check AGENTS.md spec_profile. If lite → SKIP",
]


def norm_cell(text):
    """Normalize one table cell: drop code ticks, collapse whitespace."""
    return re.sub(r"\s+", " ", text.replace("`", "").strip())


def read_doc(root, rel):
    path = os.path.join(root, rel)
    with open(path, "r", encoding="utf-8") as handle:
        return handle.read()


def slice_block(text, open_marker, close_marker):
    start = text.find(open_marker)
    if start < 0:
        return None, "opening marker %s absent" % open_marker
    end = text.find(close_marker, start)
    if end < 0:
        return None, "closing marker %s absent" % close_marker
    if text.find(open_marker, start + 1) >= 0:
        return None, "opening marker %s appears more than once" % open_marker
    return text[start + len(open_marker):end], None


def parse_rows(block):
    """Parse the contract table's data rows into 4-tuples."""
    rows = []
    for line in block.splitlines():
        line = line.strip()
        if not line.startswith("|"):
            continue
        cells = [norm_cell(c) for c in line.strip("|").split("|")]
        if len(cells) != 4:
            return None, "table row has %d cells, expected 4: %r" % (
                len(cells), line)
        if set("".join(cells)) <= set("-: "):
            continue  # alignment row
        if cells[0].lower() == "case":
            continue  # header row
        rows.append(tuple(cells))
    if not rows:
        return None, "contract block contains no data rows"
    return rows, None


def doc_rows(root, rel):
    """(rows, error) for one document's contract block."""
    try:
        text = read_doc(root, rel)
    except OSError as exc:
        return None, "unreadable: %s" % exc
    block, err = slice_block(text, CONTRACT_OPEN, CONTRACT_CLOSE)
    if err:
        return None, err
    return parse_rows(block)


class Report(object):
    def __init__(self):
        self.bad = 0

    def ok(self, doc, check):
        sys.stdout.write("OK|%s|%s\n" % (doc, check))

    def no(self, doc, check, detail):
        self.bad += 1
        sys.stdout.write("BAD|%s|%s|%s\n" % (doc, check, detail))

    def verdict(self, cond, doc, check, detail):
        if cond:
            self.ok(doc, check)
        else:
            self.no(doc, check, detail)


def check_contract_table(rep, root, rel):
    rows, err = doc_rows(root, rel)
    if err:
        rep.no(rel, "contract-block-present", err)
        rep.no(rel, "contract-table-exact", "not parseable: %s" % err)
        return
    rep.ok(rel, "contract-block-present")
    if rows == EXPECTED_ROWS:
        rep.ok(rel, "contract-table-exact")
        return
    detail = "row set differs from ADR-0023"
    if len(rows) != len(EXPECTED_ROWS):
        detail = "%d rows, expected %d" % (len(rows), len(EXPECTED_ROWS))
    else:
        for got, want in zip(rows, EXPECTED_ROWS):
            if got != want:
                detail = "row %s: got %r, expected %r" % (want[0], got, want)
                break
    rep.no(rel, "contract-table-exact", detail)


def check_handshake(rep, root, rel):
    try:
        text = read_doc(root, rel)
    except OSError as exc:
        rep.no(rel, "handshake-block-present", "unreadable: %s" % exc)
        rep.no(rel, "handshake-tokens", "unreadable: %s" % exc)
        return
    block, err = slice_block(text, HANDSHAKE_OPEN, HANDSHAKE_CLOSE)
    if err:
        rep.no(rel, "handshake-block-present", err)
        rep.no(rel, "handshake-tokens", "no block: %s" % err)
        return
    rep.ok(rel, "handshake-block-present")
    missing = [t for t in HANDSHAKE_TOKENS if t not in block]
    rep.verdict(not missing, rel, "handshake-tokens",
                "missing token(s): %s" % ", ".join(missing))


def check_contracts_doc(rep, root):
    """PLUGIN-CONTRACTS.md only: AC-024's ordering and retitling."""
    rel = CONTRACTS
    try:
        text = read_doc(root, rel)
    except OSError as exc:
        rep.no(rel, "fallback-retitled", "unreadable: %s" % exc)
        rep.no(rel, "fallback-after-contract", "unreadable: %s" % exc)
        rep.no(rel, "fallback-steps", "unreadable: %s" % exc)
        return
    heading_at = text.find(FALLBACK_HEADING)
    rep.verdict(heading_at >= 0, rel, "fallback-retitled",
                "heading %r absent" % FALLBACK_HEADING)
    close_at = text.find(CONTRACT_CLOSE)
    rep.verdict(heading_at >= 0 and close_at >= 0 and heading_at > close_at,
                rel, "fallback-after-contract",
                "compatibility fallback must follow the four-case rule "
                "(heading at %d, contract block ends at %d)"
                % (heading_at, close_at))
    if heading_at >= 0:
        tail = text[heading_at:heading_at + 1200]
        missing = [s for s in FALLBACK_STEPS if s not in tail]
        rep.verdict(not missing, rel, "fallback-steps",
                    "missing step(s): %s" % ", ".join(missing))
    else:
        rep.no(rel, "fallback-steps", "no fallback section to inspect")


def check_interviewer_gates(rep, root):
    rel = INTERVIEWER
    try:
        text = read_doc(root, rel)
    except OSError as exc:
        rep.no(rel, "gates-migrated", "unreadable: %s" % exc)
        rep.no(rel, "legacy-gating-removed", "unreadable: %s" % exc)
        return
    unmigrated = []
    for heading in INTERVIEWER_GATES:
        at = text.find(heading)
        if at < 0:
            unmigrated.append("%s (section absent)" % heading)
            continue
        nxt = text.find("\n## ", at + 1)
        section = text[at:nxt if nxt > 0 else len(text)]
        if INTERVIEWER_GATE_MARKER not in section.lower():
            unmigrated.append(heading)
    rep.verdict(not unmigrated, rel, "gates-migrated",
                "gate(s) not gating on the resolved track: %s"
                % "; ".join(unmigrated))
    survivors = [p for p in LEGACY_GATE_PHRASES if p in text]
    rep.verdict(not survivors, rel, "legacy-gating-removed",
                "pre-migration phrasing survives: %s" % "; ".join(survivors))


def run_check(root):
    rep = Report()
    for rel in ALL_DOCS:
        check_contract_table(rep, root, rel)
        # The wiring is asserted in the contract document too: AC-035 binds the
        # three consumer entry points, but a normative requirement that lives
        # only in the consumers has no single place a later epic's new entry
        # point can be checked against (REQ-010's future-entry-point contract).
        check_handshake(rep, root, rel)
    check_contracts_doc(rep, root)
    check_interviewer_gates(rep, root)
    return 1 if rep.bad else 0


def run_table(root, rel):
    rows, err = doc_rows(root, rel)
    if err:
        sys.stderr.write("table: %s: %s\n" % (rel, err))
        return 1
    for row in rows:
        sys.stdout.write("|".join(row) + "\n")
    return 0


def main(argv):
    if len(argv) >= 3 and argv[1] == "check":
        return run_check(argv[2])
    if len(argv) >= 4 and argv[1] == "table":
        return run_table(argv[2], argv[3])
    sys.stderr.write("usage: conform.py check <root> | table <root> <doc>\n")
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
PYEOF

conform_check() { "$PY" "$CONFORM" check "$1"; }

# ===========================================================================
# TEST-024 / TEST-035P / TEST-039 (document half): per-document conformance
# against the live tree. Each finding line becomes its own PASS/FAIL so the
# Red and Green tallies name the specific document and rule.
# ===========================================================================
printf -- '--- TEST-024/TEST-035P/TEST-039: live document conformance ---\n'
conform_check "$ROOT" > "$WORK/live.findings" 2>"$WORK/live.err" || :
if [ ! -s "$WORK/live.findings" ]; then
  fail "conform.py produced no findings ($(head -1 "$WORK/live.err" 2>/dev/null))"
fi
while IFS='|' read -r verdict doc check detail; do
  [ -n "${verdict:-}" ] || continue
  if [ "$verdict" = "OK" ]; then
    pass "$doc: $check"
  else
    fail "$doc: $check ($detail)"
  fi
done < "$WORK/live.findings"

# ===========================================================================
# Fixture projects: real on-disk state, signed by the REAL generator and
# judged by the REAL validator. These decide WHICH contract case applies; the
# documents decide what that case RESOLVES to. Neither side supplies the
# other's answer.
# ===========================================================================
FX="$WORK/fx"

new_project() {
  # new_project <name> <spec_profile|OMIT-PROFILE|NO-CONTEXT>
  d="$FX/$1"
  mkdir -p "$d/sdd" "$d/fixtures"
  case $2 in
    NO-CONTEXT) : ;;  # sdd/project-context.yaml deliberately never created
    OMIT-PROFILE)
      cat > "$d/sdd/project-context.yaml" <<'EOF'
schema: sdd-project-context/v1
workflow:
  artifact_layout: lite-three-file
  capability_enforcement: required
EOF
      ;;
    *)
      cat > "$d/sdd/project-context.yaml" <<EOF
schema: sdd-project-context/v1
workflow:
  spec_profile: $2
  artifact_layout: lite-three-file
  capability_enforcement: required
EOF
      ;;
  esac
  cat > "$d/fixtures/approver-registry.fixture.yaml" <<'EOF'
schema: sdd-approver-registry/v1
approvers:
  - id: alice
    name: Alice Example
  - id: bob
    name: Bob Example
EOF
  cat > "$d/fixtures/registry-without-alice.yaml" <<'EOF'
schema: sdd-approver-registry/v1
approvers:
  - id: bob
    name: Bob Example
EOF
}

sign_project() {
  # sign_project <name> [extra generator args...] -> fixtures/approval.json
  d="$FX/$1"; shift
  ( cd "$d" && SDD_CONTEXT_KEY="$TESTKEY" "$PY" "$GEN_PY" \
      --schema sdd-project-context-approval/v1 \
      --content sdd/project-context.yaml \
      --approver alice --status Approved \
      --live-sidecar fixtures/no-such-live-sidecar.json "$@" ) \
      >"$WORK/gen.out" 2>"$WORK/gen.err"
  cand=$(find "$d/sdd/.staging" -name 'project-context.approval.json' 2>/dev/null | head -1)
  if [ -n "$cand" ]; then cp "$cand" "$d/fixtures/approval.json"; fi
}

validate_project() {
  # validate_project <name> <content-rel> <sidecar-rel> <registry-rel> -> exit code
  d="$FX/$1"
  ( cd "$d" && SDD_CONTEXT_KEY="$TESTKEY" "$PY" "$VAL_PY" \
      --content "$2" --sidecar "$3" --approver-registry "$4" ) \
      >"$WORK/val.out" 2>"$WORK/val.err"
  echo $?
}

# The physical-presence probe REQ-009 step 3 mandates FIRST. Deliberately a
# plain filesystem test with no validator involvement: conflating the two is
# precisely the B5 defect this suite exists to prevent.
context_present() {
  if [ -f "$FX/$1/sdd/project-context.yaml" ]; then echo present; else echo absent; fi
}

# Read spec_profile back OFF DISK rather than from the variable the fixture
# was built with, so C3..C6 are keyed on observed state.
profile_of() {
  "$PY" - "$FX/$1/sdd/project-context.yaml" <<'PYEOF'
import re
import sys
text = open(sys.argv[1], encoding="utf-8").read()
match = re.search(r"^\s+spec_profile:\s*(\S+)\s*$", text, re.M)
sys.stdout.write(match.group(1) if match else "MISSING")
PYEOF
}

# doc_resolution <doc> <case-id> -- the resolution THAT DOCUMENT documents.
doc_resolution() {
  "$PY" "$CONFORM" table "$ROOT" "$1" 2>/dev/null \
    | awk -F'|' -v c="$2" '$1 == c { print $4 }'
}

printf -- '--- TEST-026/TEST-039: fixture construction ---\n'
new_project ctx-absent NO-CONTEXT
new_project valid-full full
new_project valid-lite lite
new_project bad-schema OMIT-PROFILE
new_project not-yet-effective full

sign_project valid-full
sign_project valid-lite
sign_project bad-schema
FUTURE_AT=$("$PY" -c "import datetime;print((datetime.datetime.now(datetime.timezone.utc)+datetime.timedelta(days=3)).strftime('%Y-%m-%dT%H:%M:%SZ'))")
sign_project not-yet-effective --effective-at "$FUTURE_AT"

# Derived invalid variants of the valid-full fixture.
cp "$FX/valid-lite/sdd/project-context.yaml" "$FX/valid-full/fixtures/other-content.yaml"
"$PY" - "$FX/valid-full/fixtures/approval.json" "$FX/valid-full/fixtures/approval-badmac.json" <<'PYEOF'
import json
import sys
src, dst = sys.argv[1], sys.argv[2]
obj = json.load(open(src, encoding="utf-8"))
mac = obj["hmac"]
obj["hmac"] = ("1" if mac[0] == "0" else "0") + mac[1:]
with open(dst, "w", encoding="utf-8") as handle:
    json.dump(obj, handle, indent=2, sort_keys=True)
PYEOF

REG=fixtures/approver-registry.fixture.yaml
CTX=sdd/project-context.yaml

# --- C-case assignment, observed rather than assumed -----------------------
assert_eq "$(context_present ctx-absent)" "absent" \
  "TEST-026 fixture: the no-Context project's $CTX is physically ABSENT"
assert_eq "$(context_present valid-full)" "present" \
  "TEST-026 fixture: the full-profile project's $CTX is physically PRESENT"
assert_eq "$(profile_of valid-full)" "full" \
  "TEST-039 fixture: the full-profile project's on-disk spec_profile reads 'full'"
assert_eq "$(profile_of valid-lite)" "lite" \
  "TEST-039 fixture: the lite-profile project's on-disk spec_profile reads 'lite'"

# A valid, correctly-signed sidecar must PASS -- otherwise C3..C6 below would
# be exercising the invalid branch under a valid-looking label.
assert_eq "$(validate_project valid-full "$CTX" fixtures/approval.json "$REG")" "0" \
  "TEST-039 fixture: the full-profile project's sidecar PASSES validate-approval-sidecar"
assert_eq "$(validate_project valid-lite "$CTX" fixtures/approval.json "$REG")" "0" \
  "TEST-039 fixture: the lite-profile project's sidecar PASSES validate-approval-sidecar"

# AC-026's six named reasons, each an independent fixture with its own
# documented diagnostic. Asserting the SPECIFIC exit code (not merely
# non-zero) is what proves six distinct rejection routes were exercised
# rather than one route reached six ways.
printf -- '--- TEST-026: six independent present-but-invalid reasons ---\n'
assert_eq "$(validate_project valid-full "$CTX" fixtures/nonexistent.json "$REG")" "37" \
  "TEST-026 (1) missing sidecar file rejected (SIDECAR_UNREADABLE)"
assert_eq "$(validate_project bad-schema "$CTX" fixtures/approval.json "$REG")" "32" \
  "TEST-026 (2) content-schema violation rejected (CONTENT_SCHEMA_VIOLATION)"
assert_eq "$(validate_project valid-full fixtures/other-content.yaml fixtures/approval.json "$REG")" "39" \
  "TEST-026 (3) hash mismatch rejected (HASH_MISMATCH)"
assert_eq "$(validate_project valid-full "$CTX" fixtures/approval-badmac.json "$REG")" "40" \
  "TEST-026 (4) HMAC mismatch rejected (HMAC_MISMATCH)"
assert_eq "$(validate_project valid-full "$CTX" fixtures/approval.json fixtures/registry-without-alice.yaml)" "41" \
  "TEST-026 (5) unregistered approver rejected (UNREGISTERED_APPROVER)"
assert_eq "$(validate_project not-yet-effective "$CTX" fixtures/approval.json "$REG")" "42" \
  "TEST-026 (6) not-yet-effective effective_at rejected (EFFECTIVE_AT_NOT_YET_REACHED)"

# Every one of those six projects is physically PRESENT. That is the whole
# point: presence is established independently of validity, so a validation
# failure can never be re-read as absence.
for p in valid-full bad-schema not-yet-effective; do
  assert_eq "$(context_present "$p")" "present" \
    "TEST-026: the '$p' invalid fixture is physically PRESENT (never absent)"
done

# ===========================================================================
# TEST-039: the six-case matrix, resolved independently against each of the
# four documents. 6 cases x 4 documents = 24 routing assertions.
# ===========================================================================
printf -- '--- TEST-039: six-case matrix x four documents ---\n'
for doc in $ALL_DOCS; do
  assert_eq "$(doc_resolution "$doc" C1)" "COMPATIBILITY_FALLBACK" \
    "TEST-039 [$doc] C1 physically absent -> COMPATIBILITY_FALLBACK"
  assert_eq "$(doc_resolution "$doc" C2)" "PROJECT_CONTEXT_INVALID" \
    "TEST-039 [$doc] C2 present-but-invalid -> PROJECT_CONTEXT_INVALID"
  assert_eq "$(doc_resolution "$doc" C3)" "PROMOTE_FULL" \
    "TEST-039 [$doc] C3 lite + --full -> PROMOTE_FULL"
  assert_eq "$(doc_resolution "$doc" C4)" "NO_OP_LITE" \
    "TEST-039 [$doc] C4 lite + --lite -> NO_OP_LITE"
  assert_eq "$(doc_resolution "$doc" C5)" "ERROR_STOP" \
    "TEST-039 [$doc] C5 full + --lite -> ERROR_STOP (never a silent downgrade)"
  assert_eq "$(doc_resolution "$doc" C6)" "NO_OP_FULL" \
    "TEST-039 [$doc] C6 full + --full -> NO_OP_FULL"
done

# The B5 inequality. A document that routed C2 to the fallback would satisfy
# "C2 has a resolution" and even "the fallback is documented"; only comparing
# the two rejects it.
printf -- '--- TEST-026: the two routes are genuinely distinct ---\n'
for doc in $ALL_DOCS; do
  r1=$(doc_resolution "$doc" C1)
  r2=$(doc_resolution "$doc" C2)
  if [ -n "$r1" ] && [ -n "$r2" ] && [ "$r1" != "$r2" ]; then
    pass "TEST-026 [$doc] the absent route and the present-but-invalid route resolve DIFFERENTLY"
  else
    fail "TEST-026 [$doc] the absent route and the present-but-invalid route must resolve DIFFERENTLY (C1=[$r1] C2=[$r2])"
  fi
done

# ===========================================================================
# TEST-MUT: detection power. Every assertion is a DELTA over a pristine copy,
# so a mutation cannot report success merely because the documents are
# already non-conforming.
# ===========================================================================
printf -- '--- TEST-MUT: mutation detection power ---\n'
PRISTINE="$WORK/pristine"
for doc in $ALL_DOCS; do
  mkdir -p "$PRISTINE/$(dirname "$doc")"
  cp "$ROOT/$doc" "$PRISTINE/$doc"
done

if conform_check "$PRISTINE" >"$WORK/pristine.findings" 2>&1; then
  PRISTINE_OK=yes
else
  PRISTINE_OK=no
fi
if [ "$PRISTINE_OK" = yes ]; then
  pass "TEST-MUT baseline: the pristine document copy CONFORMS (mutations below are measurable)"
else
  fail "TEST-MUT baseline: the pristine document copy CONFORMS (mutations below are measurable) -- $(grep -c '^BAD' "$WORK/pristine.findings" 2>/dev/null || echo '?') finding(s)"
fi

MUTATE="$WORK/mutate.py"
cat > "$MUTATE" <<'PYEOF'
"""Apply one named mutation to a throwaway copy of the four documents."""
import os
import sys

CONTRACT_OPEN = "<!-- sdd:track-selection-contract v1 -->"
CONTRACT_CLOSE = "<!-- /sdd:track-selection-contract -->"
HANDSHAKE_OPEN = "<!-- sdd:handshake-wiring v1 -->"

root, name, doc = sys.argv[1], sys.argv[2], sys.argv[3]
path = os.path.join(root, doc)
with open(path, encoding="utf-8") as handle:
    text = handle.read()
before = text


def row_of(case_id):
    """The document's own line for a given case id, or None."""
    for line in text.splitlines():
        if line.strip().startswith("| %s " % case_id):
            return line
    return None


if name == "c2-to-fallback":
    # The exact ADR-0023 fail-open defect: a present-but-invalid Context
    # silently granted the compatibility fallback.
    row = row_of("C2")
    if row:
        text = text.replace(
            row, row.replace("PROJECT_CONTEXT_INVALID", "COMPATIBILITY_FALLBACK"))
elif name == "c5-silent-downgrade":
    # full profile + --lite quietly honored: ADR-0023's originating defect.
    row = row_of("C5")
    if row:
        text = text.replace(row, row.replace("ERROR_STOP", "NO_OP_LITE"))
elif name == "drop-c2":
    row = row_of("C2")
    if row:
        text = text.replace(row + "\n", "")
elif name == "swap-c1-c2-state":
    r1, r2 = row_of("C1"), row_of("C2")
    if r1 and r2:
        c1 = [c for c in r1.strip("|").split("|")]
        c2 = [c for c in r2.strip("|").split("|")]
        c1[1], c2[1] = c2[1], c1[1]
        text = text.replace(r1, "|" + "|".join(c1) + "|")
        text = text.replace(r2, "|" + "|".join(c2) + "|")
elif name == "drop-handshake":
    text = text.replace(HANDSHAKE_OPEN, "<!-- handshake wiring removed -->")
elif name == "table-after-fallback":
    start = text.find(CONTRACT_OPEN)
    end = text.find(CONTRACT_CLOSE)
    if start >= 0 and end >= 0:
        block = text[start:end + len(CONTRACT_CLOSE)]
        text = text[:start] + text[end + len(CONTRACT_CLOSE):] + "\n" + block + "\n"
elif name == "restore-legacy-gate":
    text = text.replace(
        "## Specification Review Gate",
        "## Specification Review Gate\n\n"
        "1. If `spec_profile: lite` in AGENTS.md → SKIP.")
else:
    sys.stderr.write("unknown mutation %r\n" % name)
    sys.exit(2)

if text == before:
    sys.stderr.write("mutation %r changed nothing in %s\n" % (name, doc))
    sys.exit(3)
with open(path, "w", encoding="utf-8") as handle:
    handle.write(text)
PYEOF

# assert_mutation <mutation> <doc> <expected-doc-in-finding> <expected-check> <label>
assert_mutation() {
  m_name=$1; m_doc=$2; m_finddoc=$3; m_check=$4; m_label=$5
  m_dir="$WORK/mut/$m_name-$(echo "$m_doc" | tr '/.' '__')"
  rm -rf "$m_dir"
  for d in $ALL_DOCS; do
    mkdir -p "$m_dir/$(dirname "$d")"
    cp "$ROOT/$d" "$m_dir/$d"
  done
  if ! "$PY" "$MUTATE" "$m_dir" "$m_name" "$m_doc" 2>"$WORK/mut.err"; then
    fail "$m_label (mutation could not be applied: $(head -1 "$WORK/mut.err"))"
    return
  fi
  conform_check "$m_dir" >"$WORK/mut.findings" 2>&1 && m_conformed=yes || m_conformed=no
  if [ "$PRISTINE_OK" != yes ]; then
    fail "$m_label (not measurable: the pristine baseline does not conform)"
  elif [ "$m_conformed" = yes ]; then
    fail "$m_label (mutated copy still CONFORMED -- the check has no detection power)"
  elif grep -q "^BAD|$m_finddoc|$m_check|" "$WORK/mut.findings"; then
    pass "$m_label"
  else
    fail "$m_label (rejected, but not by $m_finddoc/$m_check: $(grep -m1 '^BAD' "$WORK/mut.findings"))"
  fi
}

assert_mutation c2-to-fallback "$DOC_CONTRACTS" "$DOC_CONTRACTS" contract-table-exact \
  "TEST-MUT (1) routing C2 to the compatibility fallback is REJECTED (the B5 fail-open defect)"
assert_mutation c5-silent-downgrade "$DOC_CONTRACTS" "$DOC_CONTRACTS" contract-table-exact \
  "TEST-MUT (2) honoring --lite against a full profile is REJECTED (the ADR-0023 silent downgrade)"
assert_mutation drop-c2 "$DOC_CONTRACTS" "$DOC_CONTRACTS" contract-table-exact \
  "TEST-MUT (3) deleting the present-but-invalid case entirely is REJECTED"
assert_mutation swap-c1-c2-state "$DOC_CONTRACTS" "$DOC_CONTRACTS" contract-table-exact \
  "TEST-MUT (4) swapping the absent and present-but-invalid preconditions is REJECTED"
assert_mutation table-after-fallback "$DOC_CONTRACTS" "$DOC_CONTRACTS" fallback-after-contract \
  "TEST-MUT (5) demoting the four-case rule below the compatibility fallback is REJECTED (AC-024 ordering)"
assert_mutation restore-legacy-gate "$DOC_INTERVIEWER" "$DOC_INTERVIEWER" legacy-gating-removed \
  "TEST-MUT (6) restoring a pre-migration AGENTS.md gate phrase is REJECTED"

# Per-consumer independence: the same defect injected into EACH consumer must
# be caught in THAT consumer. Without this, one conforming document could mask
# two unmigrated ones.
mut_n=6
for doc in $CONSUMER_DOCS; do
  mut_n=$((mut_n + 1))
  assert_mutation c5-silent-downgrade "$doc" "$doc" contract-table-exact \
    "TEST-MUT ($mut_n) the silent-downgrade defect is caught in [$doc] specifically"
done
for doc in $CONSUMER_DOCS; do
  mut_n=$((mut_n + 1))
  assert_mutation drop-handshake "$doc" "$doc" handshake-block-present \
    "TEST-MUT ($mut_n) removing the handshake wiring is caught in [$doc] specifically"
done

# ===========================================================================
# Self-registration (REQ-011 / design.md Test Strategy item 11).
# ===========================================================================
printf -- '--- self-registration ---\n'
if grep -q 'tests/plugin-contracts-track-selection.tests.sh' "$ROOT/tests/run-all.sh"; then
  pass "self-registration: tests/plugin-contracts-track-selection.tests.sh registered in tests/run-all.sh"
else
  fail "self-registration: tests/plugin-contracts-track-selection.tests.sh registered in tests/run-all.sh"
fi
if grep -q 'tests/plugin-contracts-track-selection.tests.ps1' "$ROOT/tests/run-all.ps1"; then
  pass "self-registration: tests/plugin-contracts-track-selection.tests.ps1 registered in tests/run-all.ps1"
else
  fail "self-registration: tests/plugin-contracts-track-selection.tests.ps1 registered in tests/run-all.ps1"
fi
if [ -f "$ROOT/tests/plugin-contracts-track-selection.tests.ps1" ]; then
  pass "self-registration: tests/plugin-contracts-track-selection.tests.ps1 twin exists"
else
  fail "self-registration: tests/plugin-contracts-track-selection.tests.ps1 twin exists"
fi

printf 'PASS: %s\n' "$PASS"
printf 'FAIL: %s\n' "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
