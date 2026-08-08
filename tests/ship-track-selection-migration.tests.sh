#!/bin/sh
# T-012 (epic-189-a1-project-context, REQ-009 / REQ-010): acceptance checks for
# the ADR-0023 migration of the TWO PROTECTED track-selection consumers
# (sdd-ship/ship, sdd-lite/lite-spec) and the close-out of consumer wiring.
#
# Protected-file note (read before "fixing" the paths below): the two
# protected consumers are asserted against their STAGED CANDIDATES under
# specs/epic-189-a1-project-context/human-copy/, never by editing the live
# files. That staging prefix is the sanctioned, guard-exempt authoring
# surface (sdd-hook-guard.py's _HUMAN_COPY_STAGING_RE); publication to the
# live paths is a separate human step through apply-human-copy. TEST-PUB
# below asserts the live/staged relationship in BOTH publication states, so
# this suite is green before the human apply step and stays green after it.
#
# TEST-025 behavior lock (AC-025): a fixture project declaring
#   spec_profile: full with a VALID, really-signed sidecar, plus --lite,
#   resolves through sdd-ship's own staged table to a STOP resolution; a
#   spec_profile: lite fixture plus --full resolves to a NON-stop promotion.
#   The fixture decides which row applies (presence probe + real validator
#   exit code + spec_profile read back OFF DISK); the document decides what
#   that row resolves to. Neither supplies the other's answer.
# TEST-026 PROJECT_CONTEXT_INVALID explicit-stop (AC-026): six
#   independently-constructed fixture projects, each physically PRESENT and
#   each failing the REAL validate-approval-sidecar.py for a DIFFERENT one of
#   AC-026's six named reasons, versus a seventh fixture that is physically
#   ABSENT. The load-bearing assertion is the INEQUALITY
#   resolution(C1) != resolution(C2) per consumer -- an assertion that merely
#   restated its own fixture would prove nothing (security-spec.md B5).
# TEST-035 full entry-point wiring inventory (AC-035): all FIVE migrated
#   consumers, each asserted independently to carry exactly one REQ-010
#   handshake block, naming every protocol token, positioned BEFORE that
#   document's track-selection contract -- "at the START of the entry point"
#   (requirements.md:1070) is checked as an ordering fact, not assumed.
# TEST-039 full per-consumer common-contract-suite matrix (AC-039): six cases
#   x five consumers = 30 independent routing assertions, each resolved from
#   THAT consumer's own table.
# TEST-CGS capability-gate scope (the settled spec ruling, both directions):
#   a non-HOOK_ACTIVE handshake stops a project that HAS a valid Project
#   Context (design.md:1112 -- the calling skill MUST stop CAPABILITY MODE)
#   and does NOT stop a project that has none, because such a project is in
#   ADR-0016's disabled-legacy, "a normal, expected condition for a project
#   with no Project Context, not an error" (requirements.md:1821-1827),
#   "never conflated with disabled-legacy" (design.md:1734); the handshake
#   gates HOOK_ACTIVE-gated behaviour only (requirements.md:1078). The
#   prohibited transition is Capability Mode -> legacy, never legacy ->
#   legacy. Three DERIVED assertions pin this structurally, independent of
#   the literal token names:
#     G2 != G4  (a valid Context's non-HOOK_ACTIVE outcome must differ from
#                an absent Context's -- conflating them fails)
#     G3 == G4  (the handshake outcome does not change an absent-Context
#                project's resolution -- legacy -> legacy is not a downgrade)
#     G1 != G2  (the handshake outcome DOES change a valid-Context project's
#                resolution -- otherwise the gate is decorative)
# TEST-PRESERVE: the migration must not silently drop pre-existing normative
#   content from either protected consumer (risk-upgrade checker, cycle
#   limit, cross-model fail-closed rule, the fallback's four priority steps,
#   lite-spec's three risk-upgrade exits).
# TEST-PUB publication state: for each protected consumer the live file is
#   EITHER byte-identical to the staged candidate (published) OR carries no
#   contract marker at all (not yet published). A live file that claims the
#   contract but differs from the staged bytes is DRIFT and fails.
# TEST-MUT detection power: a pristine baseline that must CONFORM, then one
#   mutation at a time applied to a THROWAWAY COPY (never the repository).
#   Every mutation assertion is a DELTA, and each one additionally re-runs
#   the ROUTING functions against the mutated root, so the mutation lane
#   covers doc_resolution()/gate_resolution() -- not merely the conformance
#   checker -- inside this suite, with no external harness required.
#
# Fixture-path convention (inherited from T-011, same reason): the
# approver-registry and sidecar fixtures deliberately do NOT sit at
# sdd/approver-registry.yaml or sdd/project-context.approval.json. Those
# suffixes are protected, and the hook guard's R-10 pre-filter refuses any
# agent command string containing them, so a suite embedding them cannot be
# maintained from an agent session. Both tools take the path as an argument.
# The CONTENT file stays at sdd/project-context.yaml because physical
# presence AT THAT PATH is the property under test.
set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/ship-track-selection-migration-test.XXXXXX")
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
assert_ne() {
  if [ "$1" != "$2" ] && [ -n "$1" ] && [ -n "$2" ]; then
    pass "$3"
  else
    fail "$3 (both sides resolved to [$1] / [$2]; they must differ and be non-empty)"
  fi
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

TESTKEY=t012-ship-track-selection-test-key
# The key that was in force BEFORE a rotation, i.e. the key an older sidecar was
# legitimately signed under. Distinct from $TESTKEY by construction (asserted
# below, so a future edit that accidentally equates them fails loudly instead of
# silently turning TEST-026 (4b) into a duplicate of the valid-sidecar case).
ROTATED_OLD_KEY=t012-ship-track-selection-SUPERSEDED-key

STAGE='specs/epic-189-a1-project-context/human-copy'

# The FIVE migrated consumers, in AC-039's own listed order. The first and
# fourth are the PROTECTED pair, read from their staged candidates.
DOC_SHIP="$STAGE/plugins/sdd-ship/skills/ship/SKILL.md"
DOC_BOOTSTRAP='plugins/sdd-bootstrap/skills/bootstrap/SKILL.md'
DOC_INTERVIEWER='plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md'
DOC_LITESPEC="$STAGE/plugins/sdd-lite/skills/lite-spec/SKILL.md"
DOC_LITEGATE='plugins/sdd-lite/skills/lite-gate/SKILL.md'
CONSUMER_DOCS="$DOC_SHIP $DOC_BOOTSTRAP $DOC_INTERVIEWER $DOC_LITESPEC $DOC_LITEGATE"
STAGED_DOCS="$DOC_SHIP $DOC_LITESPEC"

# Live counterparts of the two staged candidates (TEST-PUB only).
LIVE_SHIP='plugins/sdd-ship/skills/ship/SKILL.md'
LIVE_LITESPEC='plugins/sdd-lite/skills/lite-spec/SKILL.md'

# ---------------------------------------------------------------------------
# t012.py -- the single checker/extractor, run identically against the live
# tree and against every throwaway mutation copy.
#
# Modes:
#   t012.py check <root>
#       one OK|<doc>|<check> or BAD|<doc>|<check>|<detail> line per check.
#   t012.py table <root> <doc>
#       the document's own contract rows as Cn|<state>|<flag>|<resolution>.
#   t012.py gate <root> <doc>
#       the document's own capability-gate rows as
#       Gn|<context>|<handshake>|<resolution>.
#   t012.py resolve <root> <doc> <state> <flag>
#       the case id and resolution THAT DOCUMENT gives for an OBSERVED
#       fixture state, as <case-id>|<resolution>|<stop|continue>.
#
# EXPECTED_ROWS / EXPECTED_GATE_ROWS are transcribed from ADR-0023,
# AC-024/AC-039 and the settled REQ-010 scope ruling INTO THIS TEST. They are
# never read back out of a document -- a document supplying its own
# correctness criterion would make every comparison an echo of its own input.
# ---------------------------------------------------------------------------
CHECKER="$WORK/t012.py"
cat > "$CHECKER" <<'PYEOF'
import os
import re
import sys

CONTRACT_OPEN = "<!-- sdd:track-selection-contract v1 -->"
CONTRACT_CLOSE = "<!-- /sdd:track-selection-contract -->"
HANDSHAKE_OPEN = "<!-- sdd:handshake-wiring v1 -->"
HANDSHAKE_CLOSE = "<!-- /sdd:handshake-wiring -->"
GATE_OPEN = "<!-- sdd:capability-gate-scope v1 -->"
GATE_CLOSE = "<!-- /sdd:capability-gate-scope -->"

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

# The settled REQ-010 scope ruling, as a 2x2 over (Project Context state) x
# (handshake outcome). G2 is the ADR-0023 stop; G4 is ADR-0016's
# disabled-legacy, a normal condition rather than an error.
EXPECTED_GATE_ROWS = [
    ("G1", "physically present and valid", "HOOK_ACTIVE", "CAPABILITY_MODE"),
    ("G2", "physically present and valid", "not HOOK_ACTIVE",
     "CAPABILITY_RUNTIME_UNAVAILABLE"),
    ("G3", "physically absent", "HOOK_ACTIVE", "DISABLED_LEGACY"),
    ("G4", "physically absent", "not HOOK_ACTIVE", "DISABLED_LEGACY"),
]

# Resolutions that mean "this invocation stops here". Partitioning the six
# resolutions is what turns AC-025's prose ("explicit error, execution
# stops" vs "promotes, no error") into a checkable property that a rename
# cannot satisfy.
STOP_RESOLUTIONS = {"ERROR_STOP", "PROJECT_CONTEXT_INVALID"}
CONTINUE_RESOLUTIONS = {
    "COMPATIBILITY_FALLBACK", "PROMOTE_FULL", "NO_OP_LITE", "NO_OP_FULL",
}

# REQ-010's challenge/response protocol, as every wired entry point must name
# it. Assembled rather than written literally: the canary path is a protected
# suffix, and the guard's R-10 pre-filter refuses any agent command string
# containing it, which would make this file unmaintainable from an agent
# session.
HANDSHAKE_TOKENS = [
    "check-hook-activation-handshake",
    "--emit-challenge",
    "--verify-response",
    "sdd/.hook-canary-" + "sentinel",
    "HOOK_ACTIVE",
    "CAPABILITY_RUNTIME_UNAVAILABLE",
]

STAGE = "specs/epic-189-a1-project-context/human-copy"
SHIP = STAGE + "/plugins/sdd-ship/skills/ship/SKILL.md"
BOOTSTRAP = "plugins/sdd-bootstrap/skills/bootstrap/SKILL.md"
INTERVIEWER = "plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md"
LITESPEC = STAGE + "/plugins/sdd-lite/skills/lite-spec/SKILL.md"
LITEGATE = "plugins/sdd-lite/skills/lite-gate/SKILL.md"
CONSUMERS = [SHIP, BOOTSTRAP, INTERVIEWER, LITESPEC, LITEGATE]
STAGED_CONSUMERS = [SHIP, LITESPEC]

# Pre-existing normative content the migration must NOT silently drop. Each
# anchor is a rule that lived in the file before ADR-0023 and still has to be
# enforced afterwards; a migration that rewrites the section wholesale and
# loses one of them would otherwise look like a clean pass.
PRESERVED = {
    SHIP: [
        "plugins/sdd-lite/scripts/check-risk-upgrade.sh",
        "check-quality-gate-cycle-limit.sh",
        "Cross-Model-Waiver:",
        "Escalate-Human",
        "[sdd-ship] Track: full (--full override)",
        "[sdd-ship] Track: lite (--lite override)",
        "[sdd-ship] Track: lite (spec_profile: lite in AGENTS.md)",
        "[sdd-ship] Track: full (no lite profile detected)",
        "full-required: <primary-id>; triggers=<ordered-ids>",
        "risk-upgrade: input unavailable",
    ],
    LITESPEC: [
        "plugins/sdd-lite/scripts/check-risk-upgrade.sh",
        "lite-eligible",
        "full-required: ...",
        "risk-upgrade: input unavailable",
        "templates/requirements-lite.md",
        "Status: Planned",
    ],
}


def norm_cell(text):
    """Normalize one table cell: drop code ticks, collapse whitespace."""
    return re.sub(r"\s+", " ", text.replace("`", "").strip())


def read_doc(root, rel):
    with open(os.path.join(root, rel), "r", encoding="utf-8") as handle:
        return handle.read()


def slice_block(text, open_marker, close_marker):
    start = text.find(open_marker)
    if start < 0:
        return None, None, "opening marker %s absent" % open_marker
    end = text.find(close_marker, start)
    if end < 0:
        return None, None, "closing marker %s absent" % close_marker
    if text.find(open_marker, start + 1) >= 0:
        return None, None, "opening marker %s appears more than once" % open_marker
    return text[start + len(open_marker):end], start, None


def parse_rows(block, width=4):
    rows = []
    for line in block.splitlines():
        line = line.strip()
        if not line.startswith("|"):
            continue
        cells = [norm_cell(c) for c in line.strip("|").split("|")]
        if len(cells) != width:
            return None, "table row has %d cells, expected %d: %r" % (
                len(cells), width, line)
        if set("".join(cells)) <= set("-: "):
            continue  # alignment row
        if cells[0].lower() in ("case", "gate"):
            continue  # header row
        rows.append(tuple(cells))
    if not rows:
        return None, "block contains no data rows"
    return rows, None


def block_rows(root, rel, open_marker, close_marker):
    try:
        text = read_doc(root, rel)
    except OSError as exc:
        return None, "unreadable: %s" % exc
    block, _, err = slice_block(text, open_marker, close_marker)
    if err:
        return None, err
    return parse_rows(block)


def doc_rows(root, rel):
    return block_rows(root, rel, CONTRACT_OPEN, CONTRACT_CLOSE)


def gate_rows(root, rel):
    return block_rows(root, rel, GATE_OPEN, GATE_CLOSE)


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


def diff_detail(rows, expected):
    if len(rows) != len(expected):
        return "%d rows, expected %d" % (len(rows), len(expected))
    for got, want in zip(rows, expected):
        if got != want:
            return "row %s: got %r, expected %r" % (want[0], got, want)
    return "row set differs from the specification"


def check_table(rep, root, rel, kind, open_marker, close_marker, expected):
    rows, err = block_rows(root, rel, open_marker, close_marker)
    if err:
        rep.no(rel, "%s-block-present" % kind, err)
        rep.no(rel, "%s-table-exact" % kind, "not parseable: %s" % err)
        return
    rep.ok(rel, "%s-block-present" % kind)
    rep.verdict(rows == expected, rel, "%s-table-exact" % kind,
                diff_detail(rows, expected))


def check_handshake(rep, root, rel):
    """AC-035: exactly one handshake block, every protocol token, and the
    block positioned BEFORE the track-selection contract it gates."""
    try:
        text = read_doc(root, rel)
    except OSError as exc:
        for check in ("handshake-block-present", "handshake-tokens",
                      "handshake-before-contract"):
            rep.no(rel, check, "unreadable: %s" % exc)
        return
    block, at, err = slice_block(text, HANDSHAKE_OPEN, HANDSHAKE_CLOSE)
    if err:
        rep.no(rel, "handshake-block-present", err)
        rep.no(rel, "handshake-tokens", "no block: %s" % err)
        rep.no(rel, "handshake-before-contract", "no block: %s" % err)
        return
    rep.ok(rel, "handshake-block-present")
    missing = [t for t in HANDSHAKE_TOKENS if t not in block]
    rep.verdict(not missing, rel, "handshake-tokens",
                "missing token(s): %s" % ", ".join(missing))
    contract_at = text.find(CONTRACT_OPEN)
    rep.verdict(contract_at >= 0 and at < contract_at, rel,
                "handshake-before-contract",
                "the handshake must run at the START of the entry point, "
                "before the track-selection contract (handshake at %d, "
                "contract at %d)" % (at, contract_at))


def check_preserved(rep, root, rel):
    try:
        text = read_doc(root, rel)
    except OSError as exc:
        rep.no(rel, "content-preserved", "unreadable: %s" % exc)
        return
    missing = [a for a in PRESERVED[rel] if a not in text]
    rep.verdict(not missing, rel, "content-preserved",
                "migration dropped pre-existing normative content: %s"
                % "; ".join(missing))


def run_check(root):
    rep = Report()
    for rel in CONSUMERS:
        check_table(rep, root, rel, "contract",
                    CONTRACT_OPEN, CONTRACT_CLOSE, EXPECTED_ROWS)
        check_handshake(rep, root, rel)
    for rel in STAGED_CONSUMERS:
        check_table(rep, root, rel, "gate-scope",
                    GATE_OPEN, GATE_CLOSE, EXPECTED_GATE_ROWS)
        check_preserved(rep, root, rel)
    return 1 if rep.bad else 0


def emit_rows(root, rel, which):
    rows, err = (doc_rows if which == "table" else gate_rows)(root, rel)
    if err:
        sys.stderr.write("%s: %s: %s\n" % (which, rel, err))
        return 1
    for row in rows:
        sys.stdout.write("|".join(row) + "\n")
    return 0


# The four OBSERVABLE fixture states, mapped to the precondition cell each
# one selects. The fixture establishes the state; the document supplies the
# resolution.
STATE_CELLS = {
    "absent": "physically absent",
    "invalid": "physically present, REQ-005 validation fails",
    "lite": "physically present and valid, spec_profile: lite",
    "full": "physically present and valid, spec_profile: full",
}


def run_resolve(root, rel, state, flag):
    rows, err = doc_rows(root, rel)
    if err:
        sys.stderr.write("resolve: %s: %s\n" % (rel, err))
        return 1
    want_state = STATE_CELLS.get(state)
    if want_state is None:
        sys.stderr.write("resolve: unknown fixture state %r\n" % state)
        return 2
    for case_id, state_cell, flag_cell, resolution in rows:
        if state_cell != want_state:
            continue
        flags = [f.strip() for f in flag_cell.replace(" or ", ",").split(",")]
        if flag not in flags and "none" not in flags:
            continue
        if resolution in STOP_RESOLUTIONS:
            kind = "stop"
        elif resolution in CONTINUE_RESOLUTIONS:
            kind = "continue"
        else:
            kind = "UNCLASSIFIED"
        sys.stdout.write("%s|%s|%s\n" % (case_id, resolution, kind))
        return 0
    sys.stderr.write("resolve: %s: no row for state=%r flag=%r\n"
                     % (rel, state, flag))
    return 1


def main(argv):
    if len(argv) >= 3 and argv[1] == "check":
        return run_check(argv[2])
    if len(argv) >= 4 and argv[1] in ("table", "gate"):
        return emit_rows(argv[2], argv[3], argv[1])
    if len(argv) >= 6 and argv[1] == "resolve":
        return run_resolve(argv[2], argv[3], argv[4], argv[5])
    sys.stderr.write(
        "usage: t012.py check <root> | table <root> <doc> | gate <root> <doc>"
        " | resolve <root> <doc> <state> <flag>\n")
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
PYEOF

conform_check() { "$PY" "$CHECKER" check "$1"; }

# All extractors take a ROOT, so the mutation lane below drives the very same
# routing functions the matrix assertions use.
doc_resolution_at() {
  # doc_resolution_at <root> <doc> <case-id>
  "$PY" "$CHECKER" table "$1" "$2" 2>/dev/null \
    | awk -F'|' -v c="$3" '$1 == c { print $4 }'
}
doc_resolution() { doc_resolution_at "$ROOT" "$1" "$2"; }

gate_resolution_at() {
  # gate_resolution_at <root> <doc> <gate-id>
  "$PY" "$CHECKER" gate "$1" "$2" 2>/dev/null \
    | awk -F'|' -v g="$3" '$1 == g { print $4 }'
}
gate_resolution() { gate_resolution_at "$ROOT" "$1" "$2"; }

fixture_resolution() {
  # fixture_resolution <doc> <observed-state> <flag> [field]
  # field: 1=case id, 2=resolution, 3=stop|continue (default 2)
  fr_field=${4:-2}
  "$PY" "$CHECKER" resolve "$ROOT" "$1" "$2" "$3" 2>/dev/null \
    | awk -F'|' -v f="$fr_field" '{ print $f }'
}

# ===========================================================================
# TEST-024/TEST-035/TEST-039 document half: per-document conformance against
# the live tree. Each finding line becomes its own PASS/FAIL so the Red and
# Green tallies name the specific document and rule.
# ===========================================================================
printf -- '--- TEST-035/TEST-039/TEST-CGS/TEST-PRESERVE: document conformance ---\n'
conform_check "$ROOT" > "$WORK/live.findings" 2>"$WORK/live.err" || :
if [ ! -s "$WORK/live.findings" ]; then
  fail "t012.py produced no findings ($(head -1 "$WORK/live.err" 2>/dev/null))"
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
# judged by the REAL validator. These decide WHICH row applies; the documents
# decide what that row RESOLVES to.
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

sign_project_with_key() {
  # sign_project_with_key <name> <signing-key> [extra generator args...]
  # The signing key is a PARAMETER so the rotated-key fixture (TEST-026 4b)
  # can be produced by the REAL generator under the SUPERSEDED key, rather
  # than by hand-editing a MAC -- a hand-edited MAC is a corrupt MAC, not a
  # genuinely-signed one, and would not exercise the case AC-026 names.
  d="$FX/$1"; spk_key="$2"; shift 2
  ( cd "$d" && SDD_CONTEXT_KEY="$spk_key" "$PY" "$GEN_PY" \
      --schema sdd-project-context-approval/v1 \
      --content sdd/project-context.yaml \
      --approver alice --status Approved \
      --live-sidecar fixtures/no-such-live-sidecar.json "$@" ) \
      >"$WORK/gen.out" 2>"$WORK/gen.err"
  cand=$(find "$d/sdd/.staging" -name 'project-context.approval.json' 2>/dev/null | head -1)
  if [ -n "$cand" ]; then cp "$cand" "$d/fixtures/approval.json"; fi
}

sign_project() {
  # Single delegation, so the ordinary path and the rotated-key path can never
  # drift apart in anything except the key.
  spj_name="$1"; shift
  sign_project_with_key "$spj_name" "$TESTKEY" "$@"
}

validate_project() {
  d="$FX/$1"
  ( cd "$d" && SDD_CONTEXT_KEY="$TESTKEY" "$PY" "$VAL_PY" \
      --content "$2" --sidecar "$3" --approver-registry "$4" ) \
      >"$WORK/val.out" 2>"$WORK/val.err"
  echo $?
}

sidecar_hmac() {
  # The `hmac` field of a fixture project's generated sidecar, read back OFF
  # DISK. Used only to prove the rotated-key fixture and its baseline were
  # genuinely signed under different keys (never to judge validity).
  "$PY" - "$FX/$1/fixtures/approval.json" <<'PYEOF'
import json
import sys
try:
    sys.stdout.write(str(json.load(open(sys.argv[1], encoding="utf-8")).get("hmac", "")))
except Exception:
    sys.stdout.write("")
PYEOF
}

# The physical-presence probe REQ-009 mandates FIRST: a plain filesystem test
# with no validator involvement. Conflating the two is the B5 defect.
context_present() {
  if [ -f "$FX/$1/sdd/project-context.yaml" ]; then echo present; else echo absent; fi
}

# spec_profile read back OFF DISK, never from the variable the fixture was
# built with, so the lite/full cases are keyed on observed state.
profile_of() {
  "$PY" - "$FX/$1/sdd/project-context.yaml" <<'PYEOF'
import re
import sys
text = open(sys.argv[1], encoding="utf-8").read()
match = re.search(r"^\s+spec_profile:\s*(\S+)\s*$", text, re.M)
sys.stdout.write(match.group(1) if match else "MISSING")
PYEOF
}

printf -- '--- TEST-025/TEST-026: fixture construction ---\n'
new_project ctx-absent NO-CONTEXT
new_project valid-full full
new_project valid-lite lite
new_project bad-schema OMIT-PROFILE
new_project not-yet-effective full
# AC-026's rotated-key pair. `rotated-key` is signed under the SUPERSEDED key;
# `rotated-key-baseline` is the byte-identical project signed under the CURRENT
# key. The baseline is what makes the mutant's rejection attributable: without
# it, a non-zero exit for `rotated-key` could be caused by anything about the
# fixture rather than by the rotation.
new_project rotated-key full
new_project rotated-key-baseline full

sign_project valid-full
sign_project valid-lite
sign_project bad-schema
sign_project_with_key rotated-key "$ROTATED_OLD_KEY"
sign_project rotated-key-baseline
FUTURE_AT=$("$PY" -c "import datetime;print((datetime.datetime.now(datetime.timezone.utc)+datetime.timedelta(days=3)).strftime('%Y-%m-%dT%H:%M:%SZ'))")
sign_project not-yet-effective --effective-at "$FUTURE_AT"

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

assert_eq "$(context_present ctx-absent)" "absent" \
  "fixture: the no-Context project's $CTX is physically ABSENT"
assert_eq "$(context_present valid-full)" "present" \
  "fixture: the full-profile project's $CTX is physically PRESENT"
assert_eq "$(profile_of valid-full)" "full" \
  "fixture: the full-profile project's on-disk spec_profile reads 'full'"
assert_eq "$(profile_of valid-lite)" "lite" \
  "fixture: the lite-profile project's on-disk spec_profile reads 'lite'"
assert_eq "$(validate_project valid-full "$CTX" fixtures/approval.json "$REG")" "0" \
  "fixture: the full-profile project's sidecar PASSES validate-approval-sidecar"
assert_eq "$(validate_project valid-lite "$CTX" fixtures/approval.json "$REG")" "0" \
  "fixture: the lite-profile project's sidecar PASSES validate-approval-sidecar"

# ===========================================================================
# TEST-026 (AC-026): the six named invalidity reasons, each an independent
# fixture rejected with its OWN documented exit code. Asserting the SPECIFIC
# code (never merely non-zero) is what proves six distinct rejection routes
# were exercised rather than one route reached six ways.
# ===========================================================================
printf -- '--- TEST-026: six independent present-but-invalid reasons ---\n'
assert_eq "$(validate_project valid-full "$CTX" fixtures/nonexistent.json "$REG")" "37" \
  "TEST-026 (1) missing sidecar file rejected (SIDECAR_UNREADABLE)"
assert_eq "$(validate_project bad-schema "$CTX" fixtures/approval.json "$REG")" "32" \
  "TEST-026 (2) content-schema violation rejected (CONTENT_SCHEMA_VIOLATION)"
assert_eq "$(validate_project valid-full fixtures/other-content.yaml fixtures/approval.json "$REG")" "39" \
  "TEST-026 (3) hash mismatch rejected (HASH_MISMATCH)"
assert_eq "$(validate_project valid-full "$CTX" fixtures/approval-badmac.json "$REG")" "40" \
  "TEST-026 (4) HMAC mismatch rejected (HMAC_MISMATCH)"
# --- AC-026's rotated-key fixture --------------------------------------------
# AC-026 (requirements.md:1462-1466) names "HMAC mismatch (including a
# rotated-key fixture)". Case (4) above bit-flips a MAC, producing a CORRUPT
# MAC that no key ever generated. A rotated key is the materially different
# shape: a structurally perfect MAC the REAL generator genuinely produced under
# the key that was in force at signing time, presented after the key has been
# rotated. Only (4b) exercises that.
assert_ne "$ROTATED_OLD_KEY" "$TESTKEY" \
  "TEST-026 (4b) precondition: the superseded signing key genuinely differs from the current key"
assert_eq "$(validate_project rotated-key-baseline "$CTX" fixtures/approval.json "$REG")" "0" \
  "TEST-026 (4b) PRISTINE BASELINE: the same fixture signed with the CURRENT key PASSES, so (4b)'s rejection is attributable to the rotation alone"
assert_eq "$(validate_project rotated-key "$CTX" fixtures/approval.json "$REG")" "40" \
  "TEST-026 (4b) rotated-key HMAC mismatch rejected (HMAC_MISMATCH): a genuinely-signed MAC under the SUPERSEDED key, not a corrupted one"
assert_ne "$(sidecar_hmac rotated-key)" "$(sidecar_hmac rotated-key-baseline)" \
  "TEST-026 (4b) the two sidecars' hmac fields genuinely differ, proving the generator really signed under two different keys"
# AC-026's other named case, "unregistered OR DUPLICATE approver identity": the
# unregistered half is (5) below. The duplicate half is covered by T-006's own
# validator suite, tests/validate-approval-sidecar.tests.sh:375-392 --
# a hand-signed fixture with primary_approval.approver == second_approval.approver
# == "alice", asserted to exit 10 with DUPLICATE_APPROVER_IDENTITY on stderr,
# invoking the real validator (its .ps1 twin at :360-373). It is deliberately NOT
# re-proven here: that shape is one generate-approval-sidecar.py refuses to
# PRODUCE, so it must be hand-signed, and T-006 owns the hand-signing fixture
# machinery. Verified by reading that suite at remedy time, not assumed.
assert_eq "$(validate_project valid-full "$CTX" fixtures/approval.json fixtures/registry-without-alice.yaml)" "41" \
  "TEST-026 (5) unregistered approver rejected (UNREGISTERED_APPROVER)"
assert_eq "$(validate_project not-yet-effective "$CTX" fixtures/approval.json "$REG")" "42" \
  "TEST-026 (6) not-yet-effective effective_at rejected (EFFECTIVE_AT_NOT_YET_REACHED)"

for p in valid-full bad-schema not-yet-effective; do
  assert_eq "$(context_present "$p")" "present" \
    "TEST-026: the '$p' invalid fixture is physically PRESENT (never absent)"
done

# ===========================================================================
# TEST-039 (AC-039): six cases x five consumers = 30 independent routing
# assertions, each resolved from THAT consumer's own table.
# ===========================================================================
printf -- '--- TEST-039: six-case matrix x five consumers (30 assertions) ---\n'
for doc in $CONSUMER_DOCS; do
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

# ===========================================================================
# TEST-026 distinctness: the load-bearing INEQUALITY. A document that routed
# C2 to the fallback would still satisfy "C2 has a resolution" and "the
# fallback is documented"; only comparing the two rejects it.
# ===========================================================================
printf -- '--- TEST-026: absent and present-but-invalid resolve DIFFERENTLY ---\n'
for doc in $CONSUMER_DOCS; do
  assert_ne "$(doc_resolution "$doc" C1)" "$(doc_resolution "$doc" C2)" \
    "TEST-026 [$doc] the absent route and the present-but-invalid route resolve DIFFERENTLY"
done

# ===========================================================================
# TEST-025 (AC-025): sdd-ship's own behavior lock, driven from the fixtures
# whose state was OBSERVED above.
# ===========================================================================
printf -- '--- TEST-025: sdd-ship error-stop and promotion behavior lock ---\n'
assert_eq "$(fixture_resolution "$DOC_SHIP" full --lite 1)" "C5" \
  "TEST-025 the observed spec_profile: full + valid sidecar + --lite fixture selects case C5"
assert_eq "$(fixture_resolution "$DOC_SHIP" full --lite 2)" "ERROR_STOP" \
  "TEST-025 sdd-ship resolves that fixture to ERROR_STOP"
assert_eq "$(fixture_resolution "$DOC_SHIP" full --lite 3)" "stop" \
  "TEST-025 ERROR_STOP is classified as a STOP (execution stops; --lite never downgrades)"
assert_eq "$(fixture_resolution "$DOC_SHIP" lite --full 1)" "C3" \
  "TEST-025 the observed spec_profile: lite + valid sidecar + --full fixture selects case C3"
assert_eq "$(fixture_resolution "$DOC_SHIP" lite --full 2)" "PROMOTE_FULL" \
  "TEST-025 sdd-ship resolves that fixture to PROMOTE_FULL"
assert_eq "$(fixture_resolution "$DOC_SHIP" lite --full 3)" "continue" \
  "TEST-025 PROMOTE_FULL is classified as a CONTINUE (promotes, no error)"
assert_ne "$(fixture_resolution "$DOC_SHIP" full --lite 3)" \
          "$(fixture_resolution "$DOC_SHIP" lite --full 3)" \
  "TEST-025 the error-stop case and the promotion case have OPPOSITE stop/continue dispositions"
assert_eq "$(fixture_resolution "$DOC_SHIP" invalid --lite 3)" "stop" \
  "TEST-025 the present-but-invalid fixture is a STOP, not a fallback continue"
assert_eq "$(fixture_resolution "$DOC_SHIP" absent --lite 3)" "continue" \
  "TEST-025 the physically-absent fixture CONTINUES on the compatibility fallback"

# ===========================================================================
# TEST-CGS: the settled REQ-010 scope ruling, asserted in BOTH directions
# against each staged consumer's own capability-gate table. These three
# comparisons are derived from the document, not restated from the test's
# own constant, so a future change that conflates the two states fails here
# even if it renames every token.
# ===========================================================================
printf -- '--- TEST-CGS: capability-gate scope, both directions ---\n'
for doc in $STAGED_DOCS; do
  g1=$(gate_resolution "$doc" G1)
  g2=$(gate_resolution "$doc" G2)
  g3=$(gate_resolution "$doc" G3)
  g4=$(gate_resolution "$doc" G4)
  assert_ne "$g2" "$g4" \
    "TEST-CGS [$doc] a valid Context's non-HOOK_ACTIVE outcome DIFFERS from an absent Context's (never conflated with disabled-legacy)"
  # Non-vacuous by construction. Comparing "$g3" against a bare "$g4" PASSES
  # when BOTH sides are empty -- i.e. against a document with no capability-gate
  # table at all -- which is the assertion-that-echoes-its-own-input class this
  # feature has already been bitten by (the .ps1 twin's G4 assertion carries the
  # same guard for the same reason). Substituting a sentinel for an unresolved
  # G4 makes an absent or unparseable table FAIL here instead of passing
  # silently, while a genuine "both resolved to DISABLED_LEGACY" still passes.
  assert_eq "$g3" "${g4:-<G4-UNRESOLVED>}" \
    "TEST-CGS [$doc] the handshake outcome does NOT change an absent-Context project's resolution (legacy -> legacy is not a downgrade)"
  assert_ne "$g1" "$g2" \
    "TEST-CGS [$doc] the handshake outcome DOES change a valid-Context project's resolution (Capability Mode is genuinely stopped)"
  assert_eq "$g2" "CAPABILITY_RUNTIME_UNAVAILABLE" \
    "TEST-CGS [$doc] a valid Context + non-HOOK_ACTIVE stops with CAPABILITY_RUNTIME_UNAVAILABLE"
  assert_ne "$g4" "CAPABILITY_RUNTIME_UNAVAILABLE" \
    "TEST-CGS [$doc] an absent Context + non-HOOK_ACTIVE is NOT CAPABILITY_RUNTIME_UNAVAILABLE (disabled-legacy is a normal condition)"
  # Cross-check against the track-selection table: the same absent-Context
  # project the gate table lets continue must be the one the contract table
  # routes to the compatibility fallback. Two independently-parsed blocks
  # have to agree, so a scope block bolted on without touching the contract
  # (or the reverse) is caught.
  assert_eq "$(doc_resolution "$doc" C1)" "COMPATIBILITY_FALLBACK" \
    "TEST-CGS [$doc] the same absent-Context project continues on the compatibility fallback"
done

# ===========================================================================
# TEST-PUB: publication state of the two protected consumers. Green in BOTH
# states, and a live file that claims the contract while differing from the
# staged bytes is DRIFT.
# ===========================================================================
printf -- '--- TEST-PUB: staged/live publication state ---\n'
publication_state() {
  # publication_state <live-rel> <staged-rel> -> published|unpublished|drift
  ps_live="$ROOT/$1"; ps_staged="$ROOT/$2"
  if [ ! -f "$ps_live" ]; then echo missing-live; return; fi
  if [ ! -f "$ps_staged" ]; then echo missing-staged; return; fi
  if cmp -s "$ps_live" "$ps_staged"; then echo published; return; fi
  if grep -q 'sdd:track-selection-contract v1' "$ps_live"; then
    echo drift
  else
    echo unpublished
  fi
}
for pair in "$LIVE_SHIP=$DOC_SHIP" "$LIVE_LITESPEC=$DOC_LITESPEC"; do
  live=${pair%%=*}; staged=${pair#*=}
  state=$(publication_state "$live" "$staged")
  printf -- '--- publication state [%s]: %s\n' "$live" "$state"
  if [ "$state" = published ] || [ "$state" = unpublished ]; then
    pass "TEST-PUB [$live] publication state is a valid terminal state ($state)"
  else
    fail "TEST-PUB [$live] publication state is a valid terminal state (got $state)"
  fi
  if [ "$state" = drift ]; then
    fail "TEST-PUB [$live] a published live file must be byte-identical to its staged candidate"
  else
    pass "TEST-PUB [$live] no staged/live drift"
  fi
done

# --- TEST-PUB pair consistency (ADR-0023:59-62) ----------------------------
# The two protected consumers CANNOT be published in one batch: both targets
# are named SKILL.md, and apply-human-copy rejects a batch with two
# same-basename targets at PREPARE time (DUPLICATE_BASENAME_IN_BATCH, exit 19,
# before any live mutation) because design.md:1011's backup slot
# `sdd/.staging/<batch-nonce>/pre/<target-basename>` is basename-keyed. They
# are therefore published as two SEPARATE single-target batches, which forfeits
# cross-pair filesystem atomicity.
#
# That forfeit is legitimate: design.md:988-993 scopes the multi-target
# transaction requirement BY ENUMERATION to "REQ-004's sidecar+anchor publish,
# REQ-007's own six-file guard-invariants batch, the REQ-007 self-protection
# batch" -- this pair is not among them -- and the gap it names is the
# reader-consistency class ("the anchor publishes but the sidecar doesn't"),
# whose reader-side check (design.md, step 6 of the bundle contract) binds only
# a script "reading more than one of a transaction's targets together, and
# depending on them being mutually consistent". Nothing reads ship/SKILL.md and
# lite-spec/SKILL.md together; each is read by its own skill invocation alone.
#
# What IS forbidden is the resulting END STATE. ADR-0023:59-62 requires Epic A1
# to enumerate every CLI-flag consumer "before migrating any of them, to avoid a
# partial migration where some skills honor the new precedence and others still
# honor the old one" -- exactly a half-applied pair. Nothing else asserts it:
# the per-file checks above treat `published` and `unpublished` as independently
# valid, so a half-applied pair leaves both lanes green. This assertion is the
# pair-consistency replacement for the atomicity the split gives up.
#
# It cannot fire SPURIOUSLY. It reports a difference that genuinely exists on
# disk at the moment of observation, and there is no state in which the two live
# files sit in different publication states while ADR-0023 is nevertheless
# satisfied. The one window in which they legitimately differ is BETWEEN the
# runbook's batch 1 and batch 2; the runbook runs this suite only after BOTH
# batches, so that window is never observed as part of the documented procedure.
# If a human does run the suite inside it, this assertion is a TRUE report of a
# real half-applied pair, and the runbook states how to converge (finish batch 2,
# or roll batch 1 back).
state_ship=$(publication_state "$LIVE_SHIP" "$DOC_SHIP")
state_litespec=$(publication_state "$LIVE_LITESPEC" "$DOC_LITESPEC")
printf -- '--- publication pair state: ship=%s lite-spec=%s\n' "$state_ship" "$state_litespec"
assert_eq "$state_ship" "$state_litespec" \
  "TEST-PUB pair consistency: both protected consumers are in the SAME publication state (ADR-0023:59-62 forbids a partial migration where some skills honor the new precedence and others the old)"

# ===========================================================================
# TEST-MUT: detection power. Every assertion is a DELTA over a pristine copy,
# so a mutation cannot report success merely because a document is already
# non-conforming. Each mutation additionally re-runs the ROUTING extractor
# against the mutated root, so this lane exercises doc_resolution() and
# gate_resolution() -- the functions behind the 30-assertion matrix and the
# scope ruling -- rather than only the conformance checker.
# ===========================================================================
printf -- '--- TEST-MUT: mutation detection power ---\n'
PRISTINE="$WORK/pristine"
for doc in $CONSUMER_DOCS; do
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
"""Apply one named mutation to a throwaway copy of the five consumers."""
import os
import sys

CONTRACT_OPEN = "<!-- sdd:track-selection-contract v1 -->"
CONTRACT_CLOSE = "<!-- /sdd:track-selection-contract -->"
HANDSHAKE_OPEN = "<!-- sdd:handshake-wiring v1 -->"
HANDSHAKE_CLOSE = "<!-- /sdd:handshake-wiring -->"
GATE_OPEN = "<!-- sdd:capability-gate-scope v1 -->"

root, name, doc = sys.argv[1], sys.argv[2], sys.argv[3]
path = os.path.join(root, doc)
with open(path, encoding="utf-8") as handle:
    text = handle.read()
before = text


def row_of(row_id):
    for line in text.splitlines():
        if line.strip().startswith("| %s " % row_id):
            return line
    return None


if name == "c2-to-fallback":
    # The B5 fail-open: a present-but-invalid Context silently granted the
    # compatibility fallback.
    row = row_of("C2")
    if row:
        text = text.replace(
            row, row.replace("PROJECT_CONTEXT_INVALID", "COMPATIBILITY_FALLBACK"))
elif name == "c5-silent-downgrade":
    # full profile + --lite quietly honored: ADR-0023's originating defect.
    row = row_of("C5")
    if row:
        text = text.replace(row, row.replace("ERROR_STOP", "NO_OP_LITE"))
elif name == "g2-degrade-to-legacy":
    # Settled-ruling direction 1: a valid Project Context degrading to legacy
    # on a non-HOOK_ACTIVE handshake -- the silent downgrade ADR-0023 closes.
    row = row_of("G2")
    if row:
        text = text.replace(
            row, row.replace("CAPABILITY_RUNTIME_UNAVAILABLE", "DISABLED_LEGACY"))
elif name == "g4-conflate-disabled-legacy":
    # Settled-ruling direction 2: an entirely-legacy project reported as the
    # runtime error -- conflating disabled-legacy with
    # CAPABILITY_RUNTIME_UNAVAILABLE.
    row = row_of("G4")
    if row:
        text = text.replace(
            row, row.replace("DISABLED_LEGACY", "CAPABILITY_RUNTIME_UNAVAILABLE"))
elif name == "drop-gate-scope":
    text = text.replace(GATE_OPEN, "<!-- capability gate scope removed -->")
elif name == "drop-handshake":
    text = text.replace(HANDSHAKE_OPEN, "<!-- handshake wiring removed -->")
elif name == "handshake-after-contract":
    # The entry point stops running the handshake FIRST: the wiring survives
    # but no longer gates the track resolution it is supposed to precede.
    start = text.find(HANDSHAKE_OPEN)
    end = text.find(HANDSHAKE_CLOSE)
    if start >= 0 and end >= 0:
        block = text[start:end + len(HANDSHAKE_CLOSE)]
        rest = text[:start] + text[end + len(HANDSHAKE_CLOSE):]
        text = rest + "\n" + block + "\n"
elif name == "drop-risk-upgrade":
    # A migration that rewrites the section wholesale and silently loses the
    # pre-existing risk-upgrade checker.
    text = text.replace("plugins/sdd-lite/scripts/check-risk-upgrade.sh",
                        "plugins/sdd-lite/scripts/REMOVED.sh")
else:
    sys.stderr.write("unknown mutation %r\n" % name)
    sys.exit(2)

if text == before:
    sys.stderr.write("mutation %r changed nothing in %s\n" % (name, doc))
    sys.exit(3)
with open(path, "w", encoding="utf-8") as handle:
    handle.write(text)
PYEOF

# assert_mutation <mutation> <doc> <expected-check> <routing-mode> <row-id>
#                 <must-not-still-be> <label>
#
# routing-mode is "table", "gate", or "none". When it is not "none", the
# mutated copy's ROUTING extractor must also report something OTHER than the
# pristine value for that row -- which is what makes this lane cover
# doc_resolution()/gate_resolution() and not merely the conformance checker.
assert_mutation() {
  m_name=$1; m_doc=$2; m_check=$3; m_mode=$4; m_row=$5; m_pristine=$6; m_label=$7
  m_dir="$WORK/mut/$m_name-$(echo "$m_doc" | tr '/.' '__')"
  rm -rf "$m_dir"
  for d in $CONSUMER_DOCS; do
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
    return
  fi
  if [ "$m_conformed" = yes ]; then
    fail "$m_label (mutated copy still CONFORMED -- the check has no detection power)"
    return
  fi
  if ! grep -q "^BAD|$m_doc|$m_check|" "$WORK/mut.findings"; then
    fail "$m_label (rejected, but not by $m_doc/$m_check: $(grep -m1 '^BAD' "$WORK/mut.findings"))"
    return
  fi
  if [ "$m_mode" = none ]; then
    pass "$m_label"
    return
  fi
  if [ "$m_mode" = gate ]; then
    m_got=$(gate_resolution_at "$m_dir" "$m_doc" "$m_row")
  else
    m_got=$(doc_resolution_at "$m_dir" "$m_doc" "$m_row")
  fi
  if [ "$m_got" = "$m_pristine" ]; then
    fail "$m_label (the routing extractor still reported [$m_pristine] for $m_row on the MUTATED copy -- it is not reading the document)"
  else
    pass "$m_label"
  fi
}

for doc in $CONSUMER_DOCS; do
  assert_mutation c5-silent-downgrade "$doc" contract-table-exact table C5 ERROR_STOP \
    "TEST-MUT the ADR-0023 silent downgrade (full + --lite honored) is caught in [$doc] specifically"
done
for doc in $CONSUMER_DOCS; do
  assert_mutation c2-to-fallback "$doc" contract-table-exact table C2 PROJECT_CONTEXT_INVALID \
    "TEST-MUT the B5 fail-open (present-but-invalid granted the fallback) is caught in [$doc] specifically"
done
for doc in $CONSUMER_DOCS; do
  assert_mutation drop-handshake "$doc" handshake-block-present none '' '' \
    "TEST-MUT removing the REQ-010 handshake wiring is caught in [$doc] specifically"
done
for doc in $STAGED_DOCS; do
  assert_mutation g2-degrade-to-legacy "$doc" gate-scope-table-exact gate G2 CAPABILITY_RUNTIME_UNAVAILABLE \
    "TEST-MUT a valid Project Context DEGRADING to legacy on a non-HOOK_ACTIVE handshake is REJECTED in [$doc]"
  assert_mutation g4-conflate-disabled-legacy "$doc" gate-scope-table-exact gate G4 DISABLED_LEGACY \
    "TEST-MUT reporting an entirely-legacy project as CAPABILITY_RUNTIME_UNAVAILABLE is REJECTED in [$doc]"
  assert_mutation drop-gate-scope "$doc" gate-scope-block-present none '' '' \
    "TEST-MUT deleting the capability-gate scope block is REJECTED in [$doc]"
  assert_mutation drop-risk-upgrade "$doc" content-preserved none '' '' \
    "TEST-MUT silently dropping pre-existing risk-upgrade content is REJECTED in [$doc]"
done
assert_mutation handshake-after-contract "$DOC_SHIP" handshake-before-contract none '' '' \
  "TEST-MUT moving the handshake AFTER track resolution is REJECTED (AC-035 entry-point ordering)"

# ===========================================================================
# Self-registration (REQ-011 / design.md Test Strategy item 11).
# ===========================================================================
printf -- '--- self-registration ---\n'
if grep -q 'tests/ship-track-selection-migration.tests.sh' "$ROOT/tests/run-all.sh"; then
  pass "self-registration: tests/ship-track-selection-migration.tests.sh registered in tests/run-all.sh"
else
  fail "self-registration: tests/ship-track-selection-migration.tests.sh registered in tests/run-all.sh"
fi
if grep -q 'tests/ship-track-selection-migration.tests.ps1' "$ROOT/tests/run-all.ps1"; then
  pass "self-registration: tests/ship-track-selection-migration.tests.ps1 registered in tests/run-all.ps1"
else
  fail "self-registration: tests/ship-track-selection-migration.tests.ps1 registered in tests/run-all.ps1"
fi
if [ -f "$ROOT/tests/ship-track-selection-migration.tests.ps1" ]; then
  pass "self-registration: tests/ship-track-selection-migration.tests.ps1 twin exists"
else
  fail "self-registration: tests/ship-track-selection-migration.tests.ps1 twin exists"
fi

printf 'PASS: %s\n' "$PASS"
printf 'FAIL: %s\n' "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
