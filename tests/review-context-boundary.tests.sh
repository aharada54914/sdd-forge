#!/usr/bin/env bash
# Named claims resolve against current code; behavior tests below verify both
# runtime implementations independently of those documentary anchors.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOC="$ROOT/plugins/sdd-review-loop/references/review-context-boundary.md"
VALIDATOR="$ROOT/plugins/sdd-quality-loop/scripts/validate-review-context-set.sh"
fail() { printf 'not ok: %s\n' "$1" >&2; exit 1; }
python3 "$ROOT/tests/review-context-anchors.tests.py" --repo "$ROOT"

# ==============================================================================
# Reservation/verification boundary (TEST-RCB-001..010)
#
# validate-review-context-set.{sh,ps1} is invoked two ways: `--reserve` to
# claim the next ledger sequence and append it, and a bare invocation to
# verify a manifest. Three checks (identity_ledger_sha256 equality, "extends
# the tip", and "identity not yet persisted") were written for the reserve
# case only but ran unconditionally, so a manifest could never be verified
# again once its own reservation succeeded -- the ledger hash it bound is
# now stale by definition, it is no longer the tip once anything else is
# reserved, and its own identity is now "already persisted". A branch
# merge/re-chain landing later records on top of an already-reserved
# manifest hits exactly this and made every reserved manifest on that
# branch permanently unverifiable.
#
# The validator now keys off the ledger itself: an identity is "reserved"
# once some record's run_id AND host_session_id both match the manifest's.
# If so, this is verification of that identity -- the persisted record must
# match the manifest exactly, and the tip/hash checks that only make sense
# before a reservation happens are skipped. Otherwise it is a reservation,
# and today's checks apply unchanged. A record matching on only one of the
# two identity fields is a distinct third case (two launches colliding on
# one identity) and fails loudly regardless of which mode was requested.
#
# Every fixture below is a disposable temp directory -- never this
# repository's own reports/review-context/identity-ledger.json.
# ==============================================================================

VALIDATOR_PS1="$ROOT/plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1"
[[ -f "$VALIDATOR_PS1" ]] || fail "missing input: ${VALIDATOR_PS1#$ROOT/}"

RCB_TMP="$(mktemp -d)"
trap 'rm -rf "$RCB_TMP"' EXIT

rcb_sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else shasum -a 256 "$1" | awk '{print $1}'; fi
}
rcb_sha256_text() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}'
  else shasum -a 256 | awk '{print $1}'; fi
}

rcb_run_bash() { "$VALIDATOR" "$@"; }
rcb_run_pwsh() {
  local manifest=$1 repository=$2
  shift 2
  if [[ ${1:-} == --reserve ]]; then
    pwsh -NoLogo -NoProfile -File "$VALIDATOR_PS1" \
      -Manifest "$manifest" -RepositoryRoot "$repository" -Reserve
  else
    pwsh -NoLogo -NoProfile -File "$VALIDATOR_PS1" \
      -Manifest "$manifest" -RepositoryRoot "$repository"
  fi
}

# Fresh single-genesis-record ledger, plus one spec-reviewer-a manifest at
# sequence 2 (run RCB-run-2 / session RCB-session-2) that correctly extends
# it. feature "rcb"; the only allowed input is specs/rcb/requirements.md,
# which is authorized for both spec and impl stage reviewers, so tampering
# .stage in the tests below never trips path authorization first.
rcb_new_fixture() {
  local dir=$1
  mkdir -p "$dir/reports/review-context" "$dir/specs/rcb"
  local run1=RCB-run-1 session1=RCB-session-1
  local h1
  h1=$(printf '%s' "1|spec|spec-reviewer-a|${run1}|${session1}|" | rcb_sha256_text)
  cat > "$dir/reports/review-context/identity-ledger.json" <<EOF
{"schema":"review-identity-ledger/v1","records":[{"sequence":1,"stage":"spec","role":"spec-reviewer-a","run_id":"${run1}","host_session_id":"${session1}","previous_record_sha256":"","record_sha256":"${h1}"}]}
EOF
  printf 'rcb fixture requirements\n' > "$dir/specs/rcb/requirements.md"
  local ledger_hash req_hash
  ledger_hash=$(rcb_sha256_of "$dir/reports/review-context/identity-ledger.json")
  req_hash=$(rcb_sha256_of "$dir/specs/rcb/requirements.md")
  cat > "$dir/manifest.json" <<EOF
{
  "schema": "review-context-invocation/v2",
  "input_mode": "file-manifest",
  "fallback_mode": "none",
  "read_only": true,
  "stage": "spec",
  "role": "spec-reviewer-a",
  "feature": "rcb",
  "run_id": "RCB-run-2",
  "host_session_id": "RCB-session-2",
  "sequence": 2,
  "identity_ledger_path": "reports/review-context/identity-ledger.json",
  "identity_ledger_sha256": "${ledger_hash}",
  "previous_record_sha256": "${h1}",
  "allowed_input_manifest": [
    {"path": "specs/rcb/requirements.md", "sha256": "${req_hash}"}
  ]
}
EOF
}

# rcb_append_record <ledger> <sequence> <stage> <role> <run_id> <session>
# Appends a real, chain-valid record directly (simulating what a concurrent
# launch, or a branch merge/re-chain, leaves behind).
rcb_append_record() {
  local ledger=$1 sequence=$2 stage=$3 role=$4 run=$5 session=$6
  local tip hash
  tip=$(jq -r '.records[-1].record_sha256' "$ledger")
  hash=$(printf '%s' "${sequence}|${stage}|${role}|${run}|${session}|${tip}" | rcb_sha256_text)
  jq --arg h "$hash" --arg tip "$tip" --arg stage "$stage" --arg role "$role" \
    --arg run "$run" --arg session "$session" --argjson seq "$sequence" \
    '.records += [{sequence:$seq,stage:$stage,role:$role,run_id:$run,host_session_id:$session,previous_record_sha256:$tip,record_sha256:$h}]' \
    "$ledger" > "$ledger.tmp"
  mv "$ledger.tmp" "$ledger"
}

RCB_RUNTIMES=(bash:rcb_run_bash)
if command -v pwsh >/dev/null 2>&1; then
  RCB_RUNTIMES+=(pwsh:rcb_run_pwsh)
fi

# JSON string contracts must reject collection/scalar coercion before reservation.
for pair in "${RCB_RUNTIMES[@]}"; do
  runtime="${pair%%:*}"; run_fn="${pair##*:}"
  for field in schema input_mode fallback_mode identity_ledger_path stage role; do
    for kind in singleton empty null number boolean object; do
      d="$RCB_TMP/scalar-$runtime-$field-$kind"
      rcb_new_fixture "$d"
      jq --arg field "$field" --arg kind "$kind" '
        .[$field] = (if $kind == "singleton" then [.[$field]]
          elif $kind == "empty" then [] elif $kind == "null" then null
          elif $kind == "number" then 1 elif $kind == "boolean" then true else {} end)
      ' "$d/manifest.json" > "$d/mutated.json"
      ledger="$d/reports/review-context/identity-ledger.json"
      before=$(rcb_sha256_of "$ledger")
      if "$run_fn" "$d/mutated.json" "$d" --reserve > "$d/result.log" 2>&1; then
        fail "scalar boundary ($runtime/$field/$kind): admitted malformed invocation"
      fi
      [[ "$(rcb_sha256_of "$ledger")" == "$before" ]] || fail "scalar boundary: rejection changed ledger"
    done
  done
  for target in manifest ledger ledger-schema; do
    d="$RCB_TMP/root-$runtime-$target"; rcb_new_fixture "$d"
    ledger="$d/reports/review-context/identity-ledger.json"
    if [[ "$target" == manifest ]]; then
      jq '[.]' "$d/manifest.json" > "$d/rewrite.json"; mv "$d/rewrite.json" "$d/manifest.json"
    else
      if [[ "$target" == ledger ]]; then jq '[.]' "$ledger" > "$d/rewrite.json"
      else jq '.schema = [.schema]' "$ledger" > "$d/rewrite.json"; fi
      mv "$d/rewrite.json" "$ledger"
      jq --arg hash "$(rcb_sha256_of "$ledger")" '.identity_ledger_sha256=$hash' "$d/manifest.json" > "$d/rewrite.json"
      mv "$d/rewrite.json" "$d/manifest.json"
    fi
    before=$(rcb_sha256_of "$ledger")
    if "$run_fn" "$d/manifest.json" "$d" --reserve > "$d/result.log" 2>&1; then
      fail "root boundary ($runtime/$target): admitted malformed JSON contract"
    fi
    [[ "$(rcb_sha256_of "$ledger")" == "$before" ]] || fail "root boundary: rejection changed ledger"
  done
  printf 'ok: JSON kinds and object roots rejected before reservation (%s, 39 controls)\n' "$runtime"
done

# Inject only the final jq inventory producer failure, after normal JSON/schema
# validation. Real pinned content is stale; the failure must not erase that input.
d="$RCB_TMP/jq-producer"; rcb_new_fixture "$d"; mkdir "$d/bin"
printf 'changed after manifest pin\n' > "$d/specs/rcb/requirements.md"
if rcb_run_bash "$d/manifest.json" "$d" > "$d/normal.log" 2>&1; then
  fail 'producer control: changed pin accepted'
fi
grep -q 'REVIEW_CONTEXT_HASH:' "$d/normal.log" || fail 'producer control: expected hash rejection'
cat > "$d/bin/jq" <<'WRAPPER'
#!/usr/bin/env bash
for arg in "$@"; do
  if [[ "$arg" == *'sort_by(.path | startswith("docs/adr/"))'* ]]; then
    : > "$RCB_JQ_HIT"
    exit 73
  fi
done
exec "$RCB_REAL_JQ" "$@"
WRAPPER
chmod +x "$d/bin/jq"
ledger="$d/reports/review-context/identity-ledger.json"; before=$(rcb_sha256_of "$ledger")
if RCB_REAL_JQ="$(command -v jq)" RCB_JQ_HIT="$d/hit" PATH="$d/bin:$PATH" \
  rcb_run_bash "$d/manifest.json" "$d" --reserve > "$d/injected.log" 2>&1; then
  fail 'producer failure: jq exit 73 admitted stale pin'
fi
[[ -f "$d/hit" ]] || fail 'producer failure: injection did not reach final inventory producer'
[[ "$(rcb_sha256_of "$ledger")" == "$before" ]] || fail 'producer failure: changed ledger'
grep -q 'input manifest enumeration failed' "$d/injected.log" || fail 'producer failure: missing diagnostic'
printf 'ok: final inventory producer failure rejects before reservation\n'

# Ledger links and invocation identities are exact JSON strings, never cleaned text.
for pair in "${RCB_RUNTIMES[@]}"; do
  runtime="${pair%%:*}"; run_fn="${pair##*:}"
  for kind in ledger-link stage-cr role-cr run_id-cr host_session_id-cr normalized-array; do
    d="$RCB_TMP/exact-$runtime-$kind"; rcb_new_fixture "$d"
    ledger="$d/reports/review-context/identity-ledger.json"
    if [[ "$kind" == ledger-link ]]; then
      jq '.records[0].previous_record_sha256=[""]' "$ledger" > "$d/tmp"; mv "$d/tmp" "$ledger"
      jq --arg h "$(rcb_sha256_of "$ledger")" '.identity_ledger_sha256=$h' "$d/manifest.json" > "$d/tmp"
    elif [[ "$kind" == normalized-array ]]; then
      mkdir -p "$d/reports/task-review/rcb/attempt-1/round-1"
      printf 'Task-Review-Status: Pending\n## T-001\nApproval: Draft\nStatus: Planned\n' > "$d/specs/rcb/tasks.md"
      task_hash=$(rcb_sha256_of "$d/specs/rcb/tasks.md")
      printf 'Task-Review-Status: Passed\n## T-001\nApproval: Approved\nStatus: Done\n' > "$d/specs/rcb/tasks.md"
      precheck='reports/task-review/rcb/attempt-1/round-1/precheck-result.json'
      jq -n --arg hash "$task_hash" '{tasks_sha256_form:["normalized"],tasks_sha256:$hash}' > "$d/$precheck"
      jq --arg task "$task_hash" --arg pc "$precheck" --arg hash "$(rcb_sha256_of "$d/$precheck")" \
        '.stage="task" | .role="task-reviewer-a" | .allowed_input_manifest += [{path:"specs/rcb/tasks.md",sha256:$task},{path:$pc,sha256:$hash}]' "$d/manifest.json" > "$d/tmp"
    else
      field="${kind%-cr}"; [[ "$field" != run ]] || field=run_id
      jq --arg field "$field" '.[$field] += "\r"' "$d/manifest.json" > "$d/tmp"
    fi
    mv "$d/tmp" "$d/manifest.json"
    if [[ "$kind" == normalized-array ]]; then
      cp "$d/$precheck" "$d/malformed-precheck"
      jq '.tasks_sha256_form="normalized"' "$d/$precheck" > "$d/tmp"; mv "$d/tmp" "$d/$precheck"
      jq --arg pc "$precheck" --arg hash "$(rcb_sha256_of "$d/$precheck")" '(.allowed_input_manifest[] | select(.path==$pc) | .sha256)=$hash' "$d/manifest.json" > "$d/control.json"
      "$run_fn" "$d/control.json" "$d" > "$d/control.log" 2>&1 || fail "normalized policy ($runtime): valid scalar rejected"
      mv "$d/malformed-precheck" "$d/$precheck"
    fi
    before=$(rcb_sha256_of "$ledger")
    if "$run_fn" "$d/manifest.json" "$d" --reserve > "$d/log" 2>&1; then
      fail "exact value ($runtime/$kind): malformed identity or policy admitted"
    fi
    [[ "$(rcb_sha256_of "$ledger")" == "$before" ]] || fail 'exact value rejection changed ledger'
  done
  printf 'ok: ledger link, CR identities and normalized policy arrays rejected (%s)\n' "$runtime"
done

# A POSIX FIFO is a leaf but not a regular input: reject before opening it.
if command -v mkfifo >/dev/null 2>&1 && [[ "${OS:-}" != Windows_NT ]]; then
  for fifo_target in input manifest ledger; do
  d="$RCB_TMP/fifo-$fifo_target"; rcb_new_fixture "$d"
  case "$fifo_target" in
    input) fifo_path="$d/specs/rcb/requirements.md" ;;
    manifest) fifo_path="$d/manifest.json" ;;
    ledger) fifo_path="$d/reports/review-context/identity-ledger.json" ;;
  esac
  rm "$fifo_path"; mkfifo "$fifo_path"
  python3 - "$VALIDATOR" "$VALIDATOR_PS1" "$d" "$fifo_target" <<'PYFIFO'
import pathlib, shutil, subprocess, sys
bash, ps, root, target = sys.argv[1:]
ledger = pathlib.Path(root) / 'reports/review-context/identity-ledger.json'
before = ledger.read_bytes() if target != 'ledger' else None
commands = [['bash', bash, root + '/manifest.json', root, '--reserve']]
if shutil.which('pwsh'):
    commands.append(['pwsh', '-NoProfile', '-File', ps, '-Manifest', root + '/manifest.json', '-RepositoryRoot', root, '-Reserve'])
for command in commands:
    result = subprocess.run(command, capture_output=True, text=True, timeout=5)
    assert result.returncode != 0, result.stdout + result.stderr
    assert (ledger.read_bytes() if target != 'ledger' else None) == before, 'FIFO rejection changed ledger'
print('ok: POSIX FIFO ' + target + ' rejected before opening in each available runtime')
PYFIFO
  done
fi

# Domain reviewer identities must pin their exact input set, including the
# attempt/round precheck path. Reusing an old reservation for another round
# must fail even when every rewritten current input hash is correct.
for pair in "${RCB_RUNTIMES[@]}"; do
  runtime="${pair%%:*}"; run_fn="${pair##*:}"
  for role in a b; do
    d="$RCB_TMP/domain-binding-$runtime-$role"
    rcb_new_fixture "$d"
    mkdir -p "$d/domain" "$d/reports/domain-review/attempt-1/round-1" "$d/reports/domain-review/attempt-2/round-1"
    printf 'Domain-Model-Status: Pending\n' > "$d/domain/context-map.md"
    printf '{}\n' > "$d/reports/domain-review/attempt-1/round-1/precheck-result.json"
    cp "$d/reports/domain-review/attempt-1/round-1/precheck-result.json" "$d/reports/domain-review/attempt-2/round-1/precheck-result.json"
    jq --arg role "domain-reviewer-$role" \
      --arg model "$(rcb_sha256_of "$d/domain/context-map.md")" \
      --arg precheck "$(rcb_sha256_of "$d/reports/domain-review/attempt-1/round-1/precheck-result.json")" \
      '.stage="domain" | .role=$role | .feature="sdd-domain-model" |
       .allowed_input_manifest=[{path:"domain/context-map.md",sha256:$model},
       {path:"reports/domain-review/attempt-1/round-1/precheck-result.json",sha256:$precheck}]' \
      "$d/manifest.json" > "$d/domain.json"
    "$run_fn" "$d/domain.json" "$d" --reserve >/dev/null || fail "domain binding ($runtime/$role): reserve failed"
    expected=$(jq -jr '[.allowed_input_manifest[] | .path + "\t" + .sha256] | join("\n")' "$d/domain.json" | rcb_sha256_text)
    ledger="$d/reports/review-context/identity-ledger.json"
    [[ "$(jq -r '.records[-1].allowed_inputs_sha256 // empty' "$ledger")" == "$expected" ]] ||
      fail "domain binding ($runtime/$role): reservation did not bind its exact ordered inputs"
    "$run_fn" "$d/domain.json" "$d" >/dev/null || fail "domain binding ($runtime/$role): unchanged verification failed"
    rcb_append_record "$ledger" 3 host orchestrator RCB-later-run RCB-later-session
    "$run_fn" "$d/domain.json" "$d" >/dev/null || fail "domain binding ($runtime/$role): later identity broke verification"
    before=$(rcb_sha256_of "$ledger")
    jq '.allowed_input_manifest[1].path="reports/domain-review/attempt-2/round-1/precheck-result.json"' "$d/domain.json" > "$d/replay.json"
    jq '.allowed_input_manifest |= .[:1]' "$d/domain.json" > "$d/omitted.json"
    printf 'Changed current content\n' > "$d/domain/context-map.md"
    jq --arg hash "$(rcb_sha256_of "$d/domain/context-map.md")" '.allowed_input_manifest[0].sha256=$hash' "$d/domain.json" > "$d/rebound.json"
    for mutation in replay omitted rebound; do
      if out=$("$run_fn" "$d/$mutation.json" "$d" 2>&1); then
        fail "domain binding ($runtime/$role): accepted $mutation"
      fi
      [[ "$out" == *"reserved input manifest changed"* ]] || fail "domain binding ($runtime/$role): wrong $mutation diagnostic: $out"
      [[ "$(rcb_sha256_of "$ledger")" == "$before" ]] || fail "domain binding ($runtime/$role): verification changed ledger"
    done
    echo "ok: domain binding ($runtime/$role) rejects replay, omitted inputs and rebound content without changing reservations"
  done
done

# --- TEST-RCB-001: reserve, then verify the SAME manifest without --reserve.
for pair in "${RCB_RUNTIMES[@]}"; do
  runtime="${pair%%:*}"; run_fn="${pair##*:}"
  d="$RCB_TMP/rcb001-$runtime"
  rcb_new_fixture "$d"
  "$run_fn" "$d/manifest.json" "$d" --reserve >/dev/null ||
    fail "TEST-RCB-001 ($runtime): reservation of a fresh identity failed"
  "$run_fn" "$d/manifest.json" "$d" >/dev/null ||
    fail "TEST-RCB-001 ($runtime): verifying the just-reserved manifest without --reserve must pass"
  echo "ok: TEST-RCB-001 ($runtime) verify-after-reserve passes"
done

# --- TEST-RCB-002: reserve, append two UNRELATED records, then verify the
# original manifest again. This is the case that fails without the fix: the
# manifest is no longer the tip and its identity_ledger_sha256 is stale.
for pair in "${RCB_RUNTIMES[@]}"; do
  runtime="${pair%%:*}"; run_fn="${pair##*:}"
  d="$RCB_TMP/rcb002-$runtime"
  rcb_new_fixture "$d"
  "$run_fn" "$d/manifest.json" "$d" --reserve >/dev/null ||
    fail "TEST-RCB-002 ($runtime): reservation failed"
  ledger="$d/reports/review-context/identity-ledger.json"
  rcb_append_record "$ledger" 3 impl impl-reviewer-a RCB-run-3 RCB-session-3
  rcb_append_record "$ledger" 4 impl impl-reviewer-b RCB-run-4 RCB-session-4
  "$run_fn" "$d/manifest.json" "$d" >/dev/null ||
    fail "TEST-RCB-002 ($runtime): verify must still pass once unrelated records have landed on top (merge/re-chain case)"
  echo "ok: TEST-RCB-002 ($runtime) verify survives unrelated ledger extension"
done

# rcb_tampered <runtime> <run_fn> <test-id> <jq-filter> <expected-diagnostic-substring>
# Reserves a fresh identity, then verifies a manifest COPY with one field
# changed -- the persisted ledger record is untouched and honest, so this
# exercises the "manifest disagrees with its own persisted record" check in
# isolation, not the whole-ledger chain-hash check.
rcb_tampered() {
  local runtime=$1 run_fn=$2 id=$3 jq_filter=$4 expected=$5
  local d="$RCB_TMP/${id}-${runtime}"
  rcb_new_fixture "$d"
  "$run_fn" "$d/manifest.json" "$d" --reserve >/dev/null ||
    fail "$id ($runtime): reservation failed"
  jq "$jq_filter" "$d/manifest.json" > "$d/tampered.json"
  local out
  if out=$("$run_fn" "$d/tampered.json" "$d" 2>&1); then
    fail "$id ($runtime): a manifest disagreeing with its persisted record must be rejected (got: $out)"
  fi
  [[ "$out" == *"$expected"* ]] ||
    fail "$id ($runtime): unexpected diagnostic: $out"
  echo "ok: $id ($runtime) rejected"
}

for pair in "${RCB_RUNTIMES[@]}"; do
  runtime="${pair%%:*}"; run_fn="${pair##*:}"
  # TEST-RCB-003: persisted record's stage no longer matches the manifest.
  rcb_tampered "$runtime" "$run_fn" TEST-RCB-003 \
    '.stage = "impl" | .role = "impl-reviewer-a"' \
    "invocation stage does not match the persisted identity-ledger record"
  # TEST-RCB-004: persisted record's previous_record_sha256 no longer
  # matches the manifest.
  rcb_tampered "$runtime" "$run_fn" TEST-RCB-004 \
    ".previous_record_sha256 = (\"f\" * 64)" \
    "invocation previous-record hash does not match the persisted identity-ledger record"
  # TEST-RCB-005: manifest sequence disagrees with the persisted record.
  rcb_tampered "$runtime" "$run_fn" TEST-RCB-005 \
    '.sequence = 999' \
    "invocation sequence does not match the persisted identity-ledger record"
  # Bonus: role alone (same stage, the other valid role for it) disagreeing
  # with the persisted record -- same field family the spec calls out
  # ("sequence, stage, role, run_id, host_session_id and
  # previous_record_sha256" must all match exactly).
  rcb_tampered "$runtime" "$run_fn" TEST-RCB-005b \
    '.role = "spec-reviewer-b"' \
    "invocation role does not match the persisted identity-ledger record"
done

# --- TEST-RCB-006: --reserve against an already-persisted identity fails
# with the double-reservation diagnostic, not the reservation-mode checks.
for pair in "${RCB_RUNTIMES[@]}"; do
  runtime="${pair%%:*}"; run_fn="${pair##*:}"
  d="$RCB_TMP/rcb006-$runtime"
  rcb_new_fixture "$d"
  "$run_fn" "$d/manifest.json" "$d" --reserve >/dev/null ||
    fail "TEST-RCB-006 ($runtime): initial reservation failed"
  out=$("$run_fn" "$d/manifest.json" "$d" --reserve 2>&1) &&
    fail "TEST-RCB-006 ($runtime): reserving an already-persisted identity must fail"
  [[ "$out" == *"cannot be reserved twice"* ]] ||
    fail "TEST-RCB-006 ($runtime): unexpected diagnostic: $out"
  echo "ok: TEST-RCB-006 ($runtime) double reservation is rejected"
done

# --- TEST-RCB-007/008: a record matching run_id but not host_session_id (or
# vice versa) is a distinct failure naming which field matched and which did
# not -- never silently treated as either a reservation or a verification.
for pair in "${RCB_RUNTIMES[@]}"; do
  runtime="${pair%%:*}"; run_fn="${pair##*:}"
  d="$RCB_TMP/rcb007-$runtime"
  rcb_new_fixture "$d"
  "$run_fn" "$d/manifest.json" "$d" --reserve >/dev/null ||
    fail "TEST-RCB-007 ($runtime): reservation failed"

  jq '.run_id = "RCB-run-2" | .host_session_id = "RCB-session-OTHER" | .sequence = 5' \
    "$d/manifest.json" > "$d/partial-run.json"
  out=$("$run_fn" "$d/partial-run.json" "$d" 2>&1) &&
    fail "TEST-RCB-007 ($runtime): a run_id-only match must be rejected"
  [[ "$out" == *"run ID matches a persisted identity-ledger record but host-session ID does not"* ]] ||
    fail "TEST-RCB-007 ($runtime): unexpected diagnostic: $out"
  echo "ok: TEST-RCB-007 ($runtime) run_id-only match names the mismatch"

  jq '.host_session_id = "RCB-session-2" | .run_id = "RCB-run-OTHER" | .sequence = 5' \
    "$d/manifest.json" > "$d/partial-session.json"
  out=$("$run_fn" "$d/partial-session.json" "$d" 2>&1) &&
    fail "TEST-RCB-008 ($runtime): a host-session-id-only match must be rejected"
  [[ "$out" == *"host-session ID matches a persisted identity-ledger record but run ID does not"* ]] ||
    fail "TEST-RCB-008 ($runtime): unexpected diagnostic: $out"
  echo "ok: TEST-RCB-008 ($runtime) host-session-id-only match names the mismatch"
done

# --- TEST-RCB-009/010: reservation-mode behaviour for a genuinely new
# identity (no ledger record matches it at all) is unchanged: a manifest
# that does not extend the tip still fails, and one that does still
# succeeds and appends.
for pair in "${RCB_RUNTIMES[@]}"; do
  runtime="${pair%%:*}"; run_fn="${pair##*:}"
  d="$RCB_TMP/rcb009-$runtime"
  rcb_new_fixture "$d"

  jq '.sequence = 99' "$d/manifest.json" > "$d/bad-sequence.json"
  out=$("$run_fn" "$d/bad-sequence.json" "$d" --reserve 2>&1) &&
    fail "TEST-RCB-009 ($runtime): a non-extending fresh manifest must not reserve"
  [[ "$out" == *"invocation does not extend the canonical identity ledger"* ]] ||
    fail "TEST-RCB-009 ($runtime): unexpected diagnostic: $out"
  echo "ok: TEST-RCB-009 ($runtime) non-extending fresh manifest is rejected"

  "$run_fn" "$d/manifest.json" "$d" --reserve >/dev/null ||
    fail "TEST-RCB-010 ($runtime): a correctly extending fresh manifest must reserve"
  [[ "$(jq '.records | length' "$d/reports/review-context/identity-ledger.json")" -eq 2 ]] ||
    fail "TEST-RCB-010 ($runtime): reservation did not append exactly one record"
  echo "ok: TEST-RCB-010 ($runtime) extending fresh manifest reserves and appends"
done

printf 'ok: validate-review-context-set reservation/verification boundary is idempotent through merges (TEST-RCB-001..010, bash+pwsh)\n'

# Both runtimes must bind new declarations; the legacy hash recipe stays valid.
grep -Fq 'scratch-declaration-v1' "$VALIDATOR" || fail 'missing bound hash formula'
grep -Fq 'scratch_declaration_sha256' "$DOC" || fail 'missing reviewer binding recipe'

# Issue #288: fresh completeness must not rewrite historical input contracts.
python3 "$ROOT/tests/review-investigation-runtime.tests.py"
for file_kind in regular hardlink symlink; do
  python3 "$ROOT/tests/review-investigation-completeness.tests.py" \
    --repo "$ROOT" --file-kind "$file_kind"
done
