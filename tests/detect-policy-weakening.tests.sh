#!/bin/sh
# T-005 (epic-189-a1-project-context, REQ-006): acceptance checks for
# plugins/sdd-quality-loop/scripts/detect-policy-weakening.py and its
# .sh/.ps1 dispatcher wrappers, plus the wiring-completion proof against
# generate-approval-sidecar.py (T-003's seam).
#
# TEST-016 per-category classification (3 implemented categories classify
#   policy_weakening: true; 6 documented-N/A categories reported n/a
#   explicitly, never a proxy classification) -- AC-016.
# TEST-017 strengthening-change negative proof -- AC-017.
# TEST-018 two-person/cooldown verdict (2-identity -> true; 1-identity ->
#   false, cooldown_hours 24) -- AC-018.
# TEST-030 approved-context anchor CLI contract: identical-to-anchor ->
#   false; genuine diff -> true (immediately AND after landing as an
#   ordinary git commit); production call path immune to
#   --approved-context; NO_APPROVED_CONTEXT_ANCHOR fail-closed rule;
#   HUMAN_COPY_PUBLISH_IN_PROGRESS fail-closed on a live TRANSACTION.json
#   -- AC-030.
# TEST-031 glob-coverage narrowing algorithm: pattern removed; pattern
#   replaced at unchanged count; exclude added; exclude replaced broader;
#   pure broadening (non-weakening) -- five independent fixtures -- AC-031.
# TEST-046 zero-identity verdict half: an approvers: [] fixture emits
#   two_person_required: false, cooldown_hours: 24, identical to the
#   1-identity case -- AC-046 (schema-conformance half is T-004's).
# WIRING (tasks.md T-005 Done-When, remedy task-review attempt-3 round-2
#   OBSERVABLE-DONE finding): a non-bootstrap signing fixture through
#   generate-approval-sidecar.py embeds the EXACT in-process-computed
#   verdict; WEAKENING_DETECTOR_UNAVAILABLE no longer fires for it; the
#   production call path never passes --approved-context.
# TEST-HARDEN(a..e): fail-closed exhaustiveness for CANDIDATE_NOT_SCHEMA_VALID
#   / APPROVED_CONTEXT_ANCHOR_UNREADABLE / APPROVER_REGISTRY_UNREADABLE /
#   usage errors -- never an uncaught traceback.
#
# This suite invokes the tool through detect-policy-weakening.sh (the real
# dispatcher surface), mirroring canonicalize-sdd-yaml.tests.sh's and
# generate-approval-sidecar.tests.sh's own convention.
set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/detect-policy-weakening-test.XXXXXX")
# Physical-path normalization (design.md Test Strategy item 12).
WORK=$(cd "$WORK" && pwd -P)
trap 'rm -rf "$WORK"' EXIT INT TERM

DETECT_SH="$ROOT/plugins/sdd-quality-loop/scripts/detect-policy-weakening.sh"
DETECT_PY="$ROOT/plugins/sdd-quality-loop/scripts/detect-policy-weakening.py"
GEN_SH="$ROOT/plugins/sdd-quality-loop/scripts/generate-approval-sidecar.sh"

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; }

if command -v python3 >/dev/null 2>&1; then
  PY=python3
elif command -v python >/dev/null 2>&1; then
  PY=python
else
  printf 'FAIL: no python3/python interpreter available\n'
  exit 1
fi

# run_detect [args...] -- invokes the .sh dispatcher, capturing stdout to
# $WORK/out, stderr to $WORK/err, and returning its exit code.
run_detect() {
  "$DETECT_SH" "$@" >"$WORK/out" 2>"$WORK/err"
  return $?
}

# assert_json_field <json_file> <python_expr_on_d> <expected> <label>
assert_json_field() {
  file=$1; expr=$2; expected=$3; label=$4
  actual=$("$PY" -c "
import json
d = json.load(open('$file'))
print($expr)
" 2>/dev/null)
  if [ "$actual" = "$expected" ]; then
    pass "$label"
  else
    fail "$label (got '$actual', want '$expected')"
  fi
}

# ---------------------------------------------------------------------------
# TEST-016: per-category classification + N/A reporting -- AC-016.
# ---------------------------------------------------------------------------

mkdir -p "$WORK/t016"

cat > "$WORK/t016/baseline_cap.yaml" <<'EOF'
schema: sdd-project-context/v1
workflow:
  spec_profile: full
  artifact_layout: lite-three-file
  capability_enforcement: required
EOF
cat > "$WORK/t016/candidate_cap.yaml" <<'EOF'
schema: sdd-project-context/v1
workflow:
  spec_profile: full
  artifact_layout: lite-three-file
  capability_enforcement: advisory
EOF
run_detect --candidate "$WORK/t016/candidate_cap.yaml" --approved-context "$WORK/t016/baseline_cap.yaml"
rc=$?
if [ "$rc" = 0 ]; then
  pass "TEST-016 capability_enforcement_weakened: tool exits 0"
else
  fail "TEST-016 capability_enforcement_weakened: tool exits 0 (got $rc; stderr: $(cat "$WORK/err")"
fi
assert_json_field "$WORK/out" "d['categories']['capability_enforcement_weakened']" "weakened" \
  "TEST-016 capability_enforcement_weakened classifies 'weakened' (required -> advisory)"
assert_json_field "$WORK/out" "d['policy_weakening']" "True" \
  "TEST-016 capability_enforcement_weakened: overall policy_weakening is True"

# The 6 documented-N/A categories are reported explicitly, never omitted --
# checked once here (the categories map shape does not vary by fixture).
for cat in capability_removed public_distribution_descoped criticality_lowered \
  provider_allowlist_widened production_write_path_changed required_gate_removed; do
  assert_json_field "$WORK/out" "d['categories']['$cat']" "n/a" \
    "TEST-016 N/A category '$cat' reported explicitly as n/a, never omitted"
done

cat > "$WORK/t016/baseline_path.yaml" <<'EOF'
schema: sdd-project-context/v1
workflow:
  spec_profile: full
  artifact_layout: lite-three-file
  capability_enforcement: required
components:
  - id: comp-a
    paths:
      include:
        - src/**
      exclude: []
EOF
cat > "$WORK/t016/candidate_path.yaml" <<'EOF'
schema: sdd-project-context/v1
workflow:
  spec_profile: full
  artifact_layout: lite-three-file
  capability_enforcement: required
components:
  - id: comp-a
    paths:
      include:
        - src/desktop/**
      exclude: []
EOF
run_detect --candidate "$WORK/t016/candidate_path.yaml" --approved-context "$WORK/t016/baseline_path.yaml"
assert_json_field "$WORK/out" "d['categories']['component_path_narrowed']" "weakened" \
  "TEST-016 component_path_narrowed classifies 'weakened' (src/** -> src/desktop/**)"
assert_json_field "$WORK/out" "d['policy_weakening']" "True" \
  "TEST-016 component_path_narrowed: overall policy_weakening is True"

cat > "$WORK/t016/baseline_spec.yaml" <<'EOF'
schema: sdd-project-context/v1
workflow:
  spec_profile: full
  artifact_layout: lite-three-file
  capability_enforcement: required
EOF
cat > "$WORK/t016/candidate_spec.yaml" <<'EOF'
schema: sdd-project-context/v1
workflow:
  spec_profile: lite
  artifact_layout: lite-three-file
  capability_enforcement: required
EOF
run_detect --candidate "$WORK/t016/candidate_spec.yaml" --approved-context "$WORK/t016/baseline_spec.yaml"
assert_json_field "$WORK/out" "d['categories']['spec_profile_full_to_lite']" "weakened" \
  "TEST-016 spec_profile_full_to_lite classifies 'weakened' (full -> lite)"
assert_json_field "$WORK/out" "d['policy_weakening']" "True" \
  "TEST-016 spec_profile_full_to_lite: overall policy_weakening is True"

# ---------------------------------------------------------------------------
# TEST-017: strengthening-change negative proof -- AC-017.
# ---------------------------------------------------------------------------

cat > "$WORK/t016/baseline_strengthen.yaml" <<'EOF'
schema: sdd-project-context/v1
workflow:
  spec_profile: full
  artifact_layout: lite-three-file
  capability_enforcement: advisory
EOF
cat > "$WORK/t016/candidate_strengthen.yaml" <<'EOF'
schema: sdd-project-context/v1
workflow:
  spec_profile: full
  artifact_layout: lite-three-file
  capability_enforcement: required
EOF
run_detect --candidate "$WORK/t016/candidate_strengthen.yaml" --approved-context "$WORK/t016/baseline_strengthen.yaml"
rc=$?
assert_json_field "$WORK/out" "d['categories']['capability_enforcement_weakened']" "not_weakened" \
  "TEST-017 a strengthening change (advisory -> required) classifies 'not_weakened'"
assert_json_field "$WORK/out" "d['policy_weakening']" "False" \
  "TEST-017 a strengthening change is NOT misclassified as weakening"

# ---------------------------------------------------------------------------
# TEST-018: two-person/cooldown verdict -- AC-018.
# ---------------------------------------------------------------------------

mkdir -p "$WORK/t018-two/sdd/.approved-context"
cp "$WORK/t016/baseline_cap.yaml" "$WORK/t018-two/sdd/.approved-context/project-context.approved.yaml"
cp "$WORK/t016/candidate_cap.yaml" "$WORK/t018-two/candidate.yaml"
cat > "$WORK/t018-two/sdd/approver-registry.yaml" <<'EOF'
schema: sdd-approver-registry/v1
approvers:
  - id: alice
    name: Alice A
  - id: bob
    name: Bob B
EOF
(cd "$WORK/t018-two" && "$DETECT_SH" --candidate candidate.yaml >"$WORK/out" 2>"$WORK/err")
assert_json_field "$WORK/out" "d['two_person_required']" "True" \
  "TEST-018 a 2-distinct-identity registry emits two_person_required: true"
assert_json_field "$WORK/out" "d['cooldown_hours']" "None" \
  "TEST-018 the two-person path emits cooldown_hours: null"

mkdir -p "$WORK/t018-one/sdd/.approved-context"
cp "$WORK/t016/baseline_cap.yaml" "$WORK/t018-one/sdd/.approved-context/project-context.approved.yaml"
cp "$WORK/t016/candidate_cap.yaml" "$WORK/t018-one/candidate.yaml"
cat > "$WORK/t018-one/sdd/approver-registry.yaml" <<'EOF'
schema: sdd-approver-registry/v1
approvers:
  - id: alice
    name: Alice A
EOF
(cd "$WORK/t018-one" && "$DETECT_SH" --candidate candidate.yaml >"$WORK/out" 2>"$WORK/err")
assert_json_field "$WORK/out" "d['two_person_required']" "False" \
  "TEST-018 a 1-identity registry emits two_person_required: false"
assert_json_field "$WORK/out" "d['cooldown_hours']" "24" \
  "TEST-018 a 1-identity registry emits cooldown_hours: 24"

# ---------------------------------------------------------------------------
# TEST-046: zero-identity verdict half -- AC-046.
# ---------------------------------------------------------------------------

mkdir -p "$WORK/t046/sdd/.approved-context"
cp "$WORK/t016/baseline_cap.yaml" "$WORK/t046/sdd/.approved-context/project-context.approved.yaml"
cp "$WORK/t016/candidate_cap.yaml" "$WORK/t046/candidate.yaml"
cat > "$WORK/t046/sdd/approver-registry.yaml" <<'EOF'
schema: sdd-approver-registry/v1
approvers: []
EOF
(cd "$WORK/t046" && "$DETECT_SH" --candidate candidate.yaml >"$WORK/out" 2>"$WORK/err")
assert_json_field "$WORK/out" "d['two_person_required']" "False" \
  "TEST-046 a zero-entry (approvers: []) registry emits two_person_required: false"
assert_json_field "$WORK/out" "d['cooldown_hours']" "24" \
  "TEST-046 a zero-entry registry emits cooldown_hours: 24, identical to the 1-identity case"

# A registry file that does not exist at all is treated identically to a
# present-but-empty one (same documented zero-identity boundary).
mkdir -p "$WORK/t046-absent/sdd/.approved-context"
cp "$WORK/t016/baseline_cap.yaml" "$WORK/t046-absent/sdd/.approved-context/project-context.approved.yaml"
cp "$WORK/t016/candidate_cap.yaml" "$WORK/t046-absent/candidate.yaml"
(cd "$WORK/t046-absent" && "$DETECT_SH" --candidate candidate.yaml >"$WORK/out" 2>"$WORK/err")
assert_json_field "$WORK/out" "d['two_person_required']" "False" \
  "TEST-046 a MISSING registry file is treated identically to a zero-entry one (two_person_required: false)"
assert_json_field "$WORK/out" "d['cooldown_hours']" "24" \
  "TEST-046 a MISSING registry file emits cooldown_hours: 24"

# ---------------------------------------------------------------------------
# TEST-031: glob-coverage narrowing algorithm boundary cases -- AC-031.
# ---------------------------------------------------------------------------

write_paths_fixture() {
  # $1=path $2=full "include:" block (own key line + nested items,
  # trailing newline) $3=full "exclude:" block (same shape) -- callers
  # supply the complete key line so an empty array can be written INLINE
  # ("exclude: []") per the canonicalizer's accepted subset (`[]`/`{}` are
  # only accepted as a complete inline value, never a nested-block token).
  path=$1
  {
    printf 'schema: sdd-project-context/v1\n'
    printf 'workflow:\n'
    printf '  spec_profile: full\n'
    printf '  artifact_layout: lite-three-file\n'
    printf '  capability_enforcement: required\n'
    printf 'components:\n'
    printf '  - id: comp-a\n'
    printf '    paths:\n'
    printf '%s' "$2"
    printf '%s' "$3"
  } > "$path"
}

mkdir -p "$WORK/t031"

# (1) pattern removed: baseline [a/**, b/**] -> candidate [a/**] (narrows).
write_paths_fixture "$WORK/t031/b1.yaml" "      include:
        - a/**
        - b/**
" "      exclude: []
"
write_paths_fixture "$WORK/t031/c1.yaml" "      include:
        - a/**
" "      exclude: []
"
run_detect --candidate "$WORK/t031/c1.yaml" --approved-context "$WORK/t031/b1.yaml"
assert_json_field "$WORK/out" "d['categories']['component_path_narrowed']" "weakened" \
  "TEST-031 (1) an include pattern removed narrows coverage"

# (2) pattern replaced at unchanged count: src/** -> src/desktop/** (narrows).
write_paths_fixture "$WORK/t031/b2.yaml" "      include:
        - src/**
" "      exclude: []
"
write_paths_fixture "$WORK/t031/c2.yaml" "      include:
        - src/desktop/**
" "      exclude: []
"
run_detect --candidate "$WORK/t031/c2.yaml" --approved-context "$WORK/t031/b2.yaml"
assert_json_field "$WORK/out" "d['categories']['component_path_narrowed']" "weakened" \
  "TEST-031 (2) an include pattern replaced by a more specific one at unchanged count narrows coverage"

# (3) exclude pattern added: [] -> [src/secret/**] (narrows).
write_paths_fixture "$WORK/t031/b3.yaml" "      include:
        - src/**
" "      exclude: []
"
write_paths_fixture "$WORK/t031/c3.yaml" "      include:
        - src/**
" "      exclude:
        - src/secret/**
"
run_detect --candidate "$WORK/t031/c3.yaml" --approved-context "$WORK/t031/b3.yaml"
assert_json_field "$WORK/out" "d['categories']['component_path_narrowed']" "weakened" \
  "TEST-031 (3) an exclude pattern added narrows coverage"

# (4) exclude pattern replaced broader: src/secret/deep/** -> src/secret/** (narrows).
write_paths_fixture "$WORK/t031/b4.yaml" "      include:
        - src/**
" "      exclude:
        - src/secret/deep/**
"
write_paths_fixture "$WORK/t031/c4.yaml" "      include:
        - src/**
" "      exclude:
        - src/secret/**
"
run_detect --candidate "$WORK/t031/c4.yaml" --approved-context "$WORK/t031/b4.yaml"
assert_json_field "$WORK/out" "d['categories']['component_path_narrowed']" "weakened" \
  "TEST-031 (4) an exclude pattern replaced by a broader one narrows coverage"

# (5) pure broadening: [src/**] -> [src/**, docs/**] (does NOT narrow).
write_paths_fixture "$WORK/t031/b5.yaml" "      include:
        - src/**
" "      exclude: []
"
write_paths_fixture "$WORK/t031/c5.yaml" "      include:
        - src/**
        - docs/**
" "      exclude: []
"
run_detect --candidate "$WORK/t031/c5.yaml" --approved-context "$WORK/t031/b5.yaml"
assert_json_field "$WORK/out" "d['categories']['component_path_narrowed']" "not_weakened" \
  "TEST-031 (5) a pure-broadening change (include pattern added, nothing removed) does NOT narrow"
assert_json_field "$WORK/out" "d['policy_weakening']" "False" \
  "TEST-031 (5) a pure-broadening change is not classified as policy-weakening"

# ---------------------------------------------------------------------------
# TEST-030: approved-context anchor CLI contract -- AC-030.
# ---------------------------------------------------------------------------

# (1) identical-to-anchor candidate classifies false for every category.
mkdir -p "$WORK/t030-identical/sdd/.approved-context"
cp "$WORK/t016/baseline_cap.yaml" "$WORK/t030-identical/sdd/.approved-context/project-context.approved.yaml"
cp "$WORK/t016/baseline_cap.yaml" "$WORK/t030-identical/candidate.yaml"
(cd "$WORK/t030-identical" && "$DETECT_SH" --candidate candidate.yaml >"$WORK/out" 2>"$WORK/err")
assert_json_field "$WORK/out" "d['policy_weakening']" "False" \
  "TEST-030 (1) a candidate identical to the approved anchor classifies policy_weakening: false"

# (2) genuine diff classifies true, both immediately and after landing as
# ordinary git commits (a new commit alone never moves the anchor).
if command -v git >/dev/null 2>&1; then
  GITWORK="$WORK/t030-git"
  mkdir -p "$GITWORK/sdd/.approved-context"
  cp "$WORK/t016/baseline_cap.yaml" "$GITWORK/sdd/.approved-context/project-context.approved.yaml"
  cp "$WORK/t016/baseline_cap.yaml" "$GITWORK/project-context.yaml"
  (
    cd "$GITWORK" && git init -q && \
    git -c user.email=t@t.example -c user.name=t add -A && \
    git -c user.email=t@t.example -c user.name=t commit -q -m init
  ) >/dev/null 2>&1
  (cd "$GITWORK" && "$DETECT_SH" --candidate project-context.yaml >"$WORK/out" 2>"$WORK/err")
  assert_json_field "$WORK/out" "d['policy_weakening']" "False" \
    "TEST-030 (2a) before any change, candidate matches the anchor: policy_weakening: false"
  cp "$WORK/t016/candidate_cap.yaml" "$GITWORK/project-context.yaml"
  (cd "$GITWORK" && "$DETECT_SH" --candidate project-context.yaml >"$WORK/out" 2>"$WORK/err")
  assert_json_field "$WORK/out" "d['policy_weakening']" "True" \
    "TEST-030 (2b) a genuine weakening diff classifies true IMMEDIATELY (before any commit)"
  (
    cd "$GITWORK" && git -c user.email=t@t.example -c user.name=t add -A && \
    git -c user.email=t@t.example -c user.name=t commit -q -m weaken
  ) >/dev/null 2>&1
  (cd "$GITWORK" && "$DETECT_SH" --candidate project-context.yaml >"$WORK/out" 2>"$WORK/err")
  assert_json_field "$WORK/out" "d['policy_weakening']" "True" \
    "TEST-030 (2c) the weakening diff STILL classifies true AFTER landing as an ordinary git commit (a commit never moves the anchor)"
else
  printf 'SKIP: git not available; TEST-030 (2) git-commit-immutability sub-case skipped\n'
fi

# (3) production call path immune to a caller-supplied override: neither
# generate-approval-sidecar.py nor validate-approval-sidecar.py's source
# ever passes --approved-context (structurally unavailable on that path).
if grep -q -- '--approved-context' "$ROOT/plugins/sdd-quality-loop/scripts/generate-approval-sidecar.py"; then
  fail "TEST-030 (3) generate-approval-sidecar.py never passes --approved-context to the detector"
else
  pass "TEST-030 (3) generate-approval-sidecar.py never passes --approved-context to the detector"
fi

# (4) no anchor snapshot exists yet: NO_APPROVED_CONTEXT_ANCHOR, exit 0,
# every category treated as a new addition (never an error, never a silent
# "assume weakening").
mkdir -p "$WORK/t030-noanchor"
cp "$WORK/t016/candidate_cap.yaml" "$WORK/t030-noanchor/candidate.yaml"
(cd "$WORK/t030-noanchor" && "$DETECT_SH" --candidate candidate.yaml >"$WORK/out" 2>"$WORK/err")
rc=$?
if [ "$rc" = 0 ] && grep -q NO_APPROVED_CONTEXT_ANCHOR "$WORK/err"; then
  pass "TEST-030 (4) no approved-context anchor yet: exit 0 with the documented NO_APPROVED_CONTEXT_ANCHOR note"
else
  fail "TEST-030 (4) no approved-context anchor yet: exit 0 with NO_APPROVED_CONTEXT_ANCHOR (exit $rc; stderr: $(cat "$WORK/err")"
fi
assert_json_field "$WORK/out" "d['policy_weakening']" "False" \
  "TEST-030 (4) with no anchor, every category treated as a new addition (policy_weakening: false)"

# (5) a live human-copy transaction journal naming the anchor path fails
# closed (HUMAN_COPY_PUBLISH_IN_PROGRESS) rather than proceeding on
# possibly torn cross-file state.
mkdir -p "$WORK/t030-inprogress/sdd/.approved-context" "$WORK/t030-inprogress/sdd/.staging/some-nonce"
cp "$WORK/t016/baseline_cap.yaml" "$WORK/t030-inprogress/sdd/.approved-context/project-context.approved.yaml"
cp "$WORK/t016/candidate_cap.yaml" "$WORK/t030-inprogress/candidate.yaml"
cat > "$WORK/t030-inprogress/sdd/.staging/some-nonce/TRANSACTION.json" <<'EOF'
{
  "nonce": "some-nonce",
  "status": "in-progress",
  "targets": [
    {"live_path": "sdd/.approved-context/project-context.approved.yaml", "pre_hash": "ABSENT", "post_hash": "deadbeef"}
  ]
}
EOF
(cd "$WORK/t030-inprogress" && "$DETECT_SH" --candidate candidate.yaml >"$WORK/out" 2>"$WORK/err")
rc=$?
if [ "$rc" = 21 ] && grep -q HUMAN_COPY_PUBLISH_IN_PROGRESS "$WORK/err"; then
  pass "TEST-030 (5) a live TRANSACTION.json naming the anchor fails closed (exit 21/HUMAN_COPY_PUBLISH_IN_PROGRESS)"
else
  fail "TEST-030 (5) a live TRANSACTION.json naming the anchor fails closed (exit $rc; stderr: $(cat "$WORK/err")"
fi
if [ -s "$WORK/out" ]; then
  fail "TEST-030 (5) the in-progress-publish refusal emits no verdict on stdout"
else
  pass "TEST-030 (5) the in-progress-publish refusal emits no verdict on stdout"
fi

# ---------------------------------------------------------------------------
# WIRING: end-to-end proof against generate-approval-sidecar.py (tasks.md
# T-005 Done-When, remedy task-review attempt-3 round-2 OBSERVABLE-DONE
# finding).
# ---------------------------------------------------------------------------

mkdir -p "$WORK/wiring/sdd/.approved-context"
cp "$WORK/t016/baseline_cap.yaml" "$WORK/wiring/sdd/.approved-context/project-context.approved.yaml"
cp "$WORK/t016/baseline_cap.yaml" "$WORK/wiring/project-context.yaml"
cat > "$WORK/wiring/live-sidecar.json" <<'EOF'
{"schema": "sdd-project-context-approval/v1", "context_sha256": "sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc", "approval_epoch": 1}
EOF
(
  cd "$WORK/wiring" && \
  SDD_CONTEXT_KEY="test-context-key-epic189-t005" "$GEN_SH" \
    --schema sdd-project-context-approval/v1 \
    --content project-context.yaml \
    --approver alice \
    --status Approved \
    --live-sidecar live-sidecar.json \
    --stage-dir stage-out >"$WORK/wiring-out" 2>"$WORK/wiring-err"
)
rc=$?
if [ "$rc" = 0 ]; then
  pass "WIRING a non-bootstrap signing fixture succeeds now that the detector is present (exit 0)"
else
  fail "WIRING a non-bootstrap signing fixture succeeds now that the detector is present (exit $rc; stderr: $(cat "$WORK/wiring-err")"
fi
if grep -q WEAKENING_DETECTOR_UNAVAILABLE "$WORK/wiring-err"; then
  fail "WIRING WEAKENING_DETECTOR_UNAVAILABLE no longer fires for this fixture"
else
  pass "WIRING WEAKENING_DETECTOR_UNAVAILABLE no longer fires for this fixture"
fi
STAGED_SIDECAR="$WORK/wiring/stage-out/project-context.approval.json"
if [ -f "$STAGED_SIDECAR" ]; then
  pass "WIRING a staged sidecar candidate was written"
else
  fail "WIRING a staged sidecar candidate was written"
fi
embedded_verdict=$("$PY" -c "
import json
print(json.dumps(json.load(open('$STAGED_SIDECAR'))['weakening_verdict'], sort_keys=True))
" 2>/dev/null)
directly_computed_verdict=$(cd "$WORK/wiring" && "$DETECT_SH" --candidate project-context.yaml 2>/dev/null | "$PY" -c "
import json, sys
print(json.dumps(json.load(sys.stdin), sort_keys=True))
")
if [ -n "$embedded_verdict" ] && [ "$embedded_verdict" = "$directly_computed_verdict" ]; then
  pass "WIRING the sidecar's embedded weakening_verdict is EXACTLY the in-process-computed verdict"
else
  fail "WIRING the sidecar's embedded weakening_verdict is EXACTLY the in-process-computed verdict (embedded=$embedded_verdict direct=$directly_computed_verdict)"
fi

# WIRING carry-forward regression (T-003 QG round-2 seq0352 advance
# findings #1/#2/#3): the seam's compute_verdict() call site is inside the
# classified try-wrap, a malformed verdict is rejected before preimage
# construction, and a None verdict is refused for a non-bootstrap
# transition. Exercised via a substitute scripts directory (a copy of
# generate-approval-sidecar.py alongside a deliberately-bugged
# detect-policy-weakening.py stand-in) so the REAL detector is never
# altered.
mkdir -p "$WORK/seam-fixtures"
cp "$ROOT/plugins/sdd-quality-loop/scripts/generate-approval-sidecar.py" "$WORK/seam-fixtures/generate-approval-sidecar.py"
cp "$ROOT/plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.py" "$WORK/seam-fixtures/canonicalize-sdd-yaml.py"

mkdir -p "$WORK/seam-proj"
cp "$WORK/t016/baseline_cap.yaml" "$WORK/seam-proj/project-context.yaml"
cp "$WORK/wiring/live-sidecar.json" "$WORK/seam-proj/live-sidecar.json"

run_seam() {
  # $1 = detector stand-in source (written to $WORK/seam-fixtures/detect-policy-weakening.py)
  printf '%s' "$1" > "$WORK/seam-fixtures/detect-policy-weakening.py"
  "$PY" "$WORK/seam-fixtures/generate-approval-sidecar.py" \
    --schema sdd-project-context-approval/v1 \
    --content "$WORK/seam-proj/project-context.yaml" \
    --approver alice \
    --status Approved \
    --live-sidecar "$WORK/seam-proj/live-sidecar.json" \
    --stage-dir "$WORK/seam-proj/stage-$2" \
    >"$WORK/out" 2>"$WORK/err"
  return $?
}

SDD_CONTEXT_KEY="test-context-key-epic189-t005"
export SDD_CONTEXT_KEY

# Finding #1: compute_verdict() raises an unexpected (non-detector) exception.
run_seam 'class DetectPolicyWeakeningError(Exception):
    def __init__(self, category, message):
        super().__init__(message)
        self.category = category
        self.message = message


def compute_verdict(candidate_path, approved_context_path=None):
    raise RuntimeError("seam-fixture: unexpected failure")
' finding1
rc=$?
if [ "$rc" = 17 ] && grep -q WEAKENING_DETECTOR_ERROR "$WORK/err" && ! grep -qi traceback "$WORK/err"; then
  pass "WIRING carry-forward #1: an unexpected compute_verdict() exception surfaces as classified WEAKENING_DETECTOR_ERROR (exit 17), never a raw traceback"
else
  fail "WIRING carry-forward #1: an unexpected compute_verdict() exception surfaces as classified WEAKENING_DETECTOR_ERROR (exit $rc; stderr: $(cat "$WORK/err")"
fi

# Finding #1b: compute_verdict() raises the detector's OWN named error --
# passed through verbatim, not collapsed into a generic label.
run_seam 'class DetectPolicyWeakeningError(Exception):
    def __init__(self, category, message):
        super().__init__(message)
        self.category = category
        self.message = message


def compute_verdict(candidate_path, approved_context_path=None):
    raise DetectPolicyWeakeningError("CANDIDATE_NOT_SCHEMA_VALID", "seam-fixture: pass-through proof")
' finding1b
rc=$?
if [ "$rc" = 20 ] && grep -q CANDIDATE_NOT_SCHEMA_VALID "$WORK/err" && ! grep -qi traceback "$WORK/err"; then
  pass "WIRING carry-forward #1b: the detector's own named category is passed through verbatim (exit 20/CANDIDATE_NOT_SCHEMA_VALID), never collapsed to a generic label"
else
  fail "WIRING carry-forward #1b: the detector's own named category is passed through verbatim (exit $rc; stderr: $(cat "$WORK/err")"
fi

# Finding #2: compute_verdict() returns a malformed (non-schema-shaped) verdict.
run_seam 'def compute_verdict(candidate_path, approved_context_path=None):
    return {"policy_weakening": True}
' finding2
rc=$?
if [ "$rc" = 18 ] && grep -q WEAKENING_VERDICT_MALFORMED "$WORK/err" && ! grep -qi traceback "$WORK/err"; then
  pass "WIRING carry-forward #2: a malformed verdict is rejected BEFORE preimage construction (exit 18/WEAKENING_VERDICT_MALFORMED), never a downstream TypeError"
else
  fail "WIRING carry-forward #2: a malformed verdict is rejected before preimage construction (exit $rc; stderr: $(cat "$WORK/err")"
fi

# Finding #2b: compute_verdict() returns a non-JSON-serializable verdict
# (schema-shaped keys present, but an un-serializable value smuggled in).
run_seam 'def compute_verdict(candidate_path, approved_context_path=None):
    class NotSerializable:
        pass
    return {
        "policy_weakening": True,
        "categories": {
            "capability_enforcement_weakened": "weakened",
            "capability_removed": "n/a",
            "component_path_narrowed": "not_weakened",
            "public_distribution_descoped": "n/a",
            "criticality_lowered": "n/a",
            "provider_allowlist_widened": "n/a",
            "production_write_path_changed": "n/a",
            "required_gate_removed": "n/a",
            "spec_profile_full_to_lite": "not_weakened",
        },
        "two_person_required": False,
        "cooldown_hours": NotSerializable(),
    }
' finding2b
rc=$?
if [ "$rc" = 18 ] && grep -q WEAKENING_VERDICT_MALFORMED "$WORK/err" && ! grep -qi traceback "$WORK/err"; then
  pass "WIRING carry-forward #2b: a non-serializable cooldown_hours value is rejected as WEAKENING_VERDICT_MALFORMED (exit 18), never an uncaught TypeError"
else
  fail "WIRING carry-forward #2b: a non-serializable verdict field is rejected cleanly (exit $rc; stderr: $(cat "$WORK/err")"
fi

# Finding #3: compute_verdict() returns None for a non-bootstrap transition.
run_seam 'def compute_verdict(candidate_path, approved_context_path=None):
    return None
' finding3
rc=$?
if [ "$rc" = 18 ] && grep -q WEAKENING_VERDICT_MALFORMED "$WORK/err" && ! grep -qi traceback "$WORK/err"; then
  pass "WIRING carry-forward #3: a None verdict for a non-bootstrap transition is refused (exit 18/WEAKENING_VERDICT_MALFORMED), never embedded as weakening_verdict: null"
else
  fail "WIRING carry-forward #3: a None verdict for a non-bootstrap transition is refused (exit $rc; stderr: $(cat "$WORK/err")"
fi
if [ -e "$WORK/seam-proj/stage-finding3" ]; then
  fail "WIRING carry-forward #3: the refusal writes no staged candidate"
else
  pass "WIRING carry-forward #3: the refusal writes no staged candidate"
fi

unset SDD_CONTEXT_KEY

# ---------------------------------------------------------------------------
# TEST-HARDEN(a..e): fail-closed exhaustiveness -- every rejection path has
# a stable documented category + exit code, never an uncaught traceback.
# ---------------------------------------------------------------------------

run_detect --candidate "$WORK/does-not-exist.yaml"
rc=$?
if [ "$rc" = 20 ] && grep -q CANDIDATE_NOT_SCHEMA_VALID "$WORK/err" && ! grep -qi traceback "$WORK/err"; then
  pass "TEST-HARDEN(a) a missing --candidate file is rejected cleanly (exit 20/CANDIDATE_NOT_SCHEMA_VALID), never a traceback"
else
  fail "TEST-HARDEN(a) a missing --candidate file is rejected cleanly (exit $rc; stderr: $(cat "$WORK/err")"
fi

cat > "$WORK/t016/bad_schema.yaml" <<'EOF'
schema: sdd-something-else/v1
workflow:
  spec_profile: full
  artifact_layout: lite-three-file
  capability_enforcement: required
EOF
run_detect --candidate "$WORK/t016/bad_schema.yaml" --approved-context "$WORK/t016/baseline_cap.yaml"
rc=$?
if [ "$rc" = 20 ] && grep -q CANDIDATE_NOT_SCHEMA_VALID "$WORK/err" && ! grep -qi traceback "$WORK/err"; then
  pass "TEST-HARDEN(b) an unrecognized 'schema' field is rejected cleanly (exit 20/CANDIDATE_NOT_SCHEMA_VALID), never a traceback"
else
  fail "TEST-HARDEN(b) an unrecognized 'schema' field is rejected cleanly (exit $rc; stderr: $(cat "$WORK/err")"
fi

cat > "$WORK/t016/corrupt_anchor.yaml" <<'EOF'
schema: sdd-project-context/v1
schema: sdd-project-context/v1
EOF
run_detect --candidate "$WORK/t016/candidate_cap.yaml" --approved-context "$WORK/t016/corrupt_anchor.yaml"
rc=$?
if [ "$rc" = 22 ] && grep -q APPROVED_CONTEXT_ANCHOR_UNREADABLE "$WORK/err" && ! grep -qi traceback "$WORK/err"; then
  pass "TEST-HARDEN(c) a corrupt (out-of-subset) approved-context anchor is rejected cleanly (exit 22/APPROVED_CONTEXT_ANCHOR_UNREADABLE), never a traceback"
else
  fail "TEST-HARDEN(c) a corrupt approved-context anchor is rejected cleanly (exit $rc; stderr: $(cat "$WORK/err")"
fi

mkdir -p "$WORK/t023-badreg/sdd/.approved-context"
cp "$WORK/t016/baseline_cap.yaml" "$WORK/t023-badreg/sdd/.approved-context/project-context.approved.yaml"
cp "$WORK/t016/candidate_cap.yaml" "$WORK/t023-badreg/candidate.yaml"
cat > "$WORK/t023-badreg/sdd/approver-registry.yaml" <<'EOF'
- just_a_list_item
EOF
(cd "$WORK/t023-badreg" && "$DETECT_SH" --candidate candidate.yaml >"$WORK/out" 2>"$WORK/err")
rc=$?
if [ "$rc" = 23 ] && grep -q APPROVER_REGISTRY_UNREADABLE "$WORK/err" && ! grep -qi traceback "$WORK/err"; then
  pass "TEST-HARDEN(d) a malformed (non-object) approver-registry.yaml is rejected cleanly (exit 23/APPROVER_REGISTRY_UNREADABLE), never a traceback"
else
  fail "TEST-HARDEN(d) a malformed approver-registry.yaml is rejected cleanly (exit $rc; stderr: $(cat "$WORK/err")"
fi

"$DETECT_SH" >"$WORK/out" 2>"$WORK/err"
rc=$?
if [ "$rc" = 2 ] && ! grep -qi traceback "$WORK/err"; then
  pass "TEST-HARDEN(e) a missing required --candidate argument is a clean usage error (exit 2), never a traceback"
else
  fail "TEST-HARDEN(e) a missing required --candidate argument is a clean usage error (exit $rc; stderr: $(cat "$WORK/err")"
fi

# ---------------------------------------------------------------------------
# Self-registration (design.md Test Strategy item 11).
# ---------------------------------------------------------------------------

if grep -q 'detect-policy-weakening\.tests\.sh' "$ROOT/tests/run-all.sh"; then
  pass "self-registration: tests/detect-policy-weakening.tests.sh registered in tests/run-all.sh"
else
  fail "self-registration: tests/detect-policy-weakening.tests.sh registered in tests/run-all.sh"
fi
if grep -q 'detect-policy-weakening\.tests\.ps1' "$ROOT/tests/run-all.ps1"; then
  pass "self-registration: tests/detect-policy-weakening.tests.ps1 registered in tests/run-all.ps1"
else
  fail "self-registration: tests/detect-policy-weakening.tests.ps1 registered in tests/run-all.ps1"
fi
if [ -f "$ROOT/tests/detect-policy-weakening.tests.ps1" ]; then
  pass "self-registration: tests/detect-policy-weakening.tests.ps1 twin exists"
else
  fail "self-registration: tests/detect-policy-weakening.tests.ps1 twin exists"
fi

printf 'PASS: %s\n' "$PASS"
printf 'FAIL: %s\n' "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
