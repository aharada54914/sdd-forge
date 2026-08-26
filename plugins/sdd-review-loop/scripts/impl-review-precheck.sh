#!/usr/bin/env bash
# impl-review-precheck.sh
# Usage: impl-review-precheck.sh <feature-slug> <attempt> <round> [--verify-inputs|--provenance-rereview]
#
# Generates precheck-result.json for the impl-review-loop.
# Outputs to: reports/impl-review/<feature>/attempt-<M>/round-<N>/
#
# Exit codes:
#   0  — precheck passed (downstream reviewers may run)
#   1  — precheck failed (halt review loop; display error)

set -euo pipefail

FEATURE="${1:?Usage: impl-review-precheck.sh <feature-slug> <attempt> <round>}"
ATTEMPT="${2:?Usage: impl-review-precheck.sh <feature-slug> <attempt> <round>}"
ROUND="${3:?Usage: impl-review-precheck.sh <feature-slug> <attempt> <round>}"
MODE="${4:-}"

SPECS_DIR="specs/${FEATURE}"
REPORT_DIR="reports/impl-review/${FEATURE}/attempt-${ATTEMPT}/round-${ROUND}"
DESIGN_MD="${SPECS_DIR}/design.md"
REQS_MD="${SPECS_DIR}/requirements.md"
ACCEPT_MD="${SPECS_DIR}/acceptance-tests.md"
SPEC_REPORT_ROOT="reports/spec-review/${FEATURE}"
IMPL_REPORT_ROOT="reports/impl-review/${FEATURE}"
CALIBRATION_MD="plugins/sdd-review-loop/references/reviewer-calibration.md"
REGISTRY="specs/workflow-state-registry.json"
LAYER_FILES=("ux-spec.md" "frontend-spec.md" "infra-spec.md" "security-spec.md")
repo_root="$(cd "$(dirname "$0")/../../.." && pwd -P)"
calibration_sha256=""

fail() { echo "ERROR: impl-review-precheck: $*" >&2; exit 1; }
sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}';
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}';
  else fail "neither sha256sum nor shasum is available"; fi
}
sha256_stream() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}';
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 | awk '{print $1}';
  else fail "neither sha256sum nor shasum is available"; fi
}
reviewed_sha256() {
  local file="$1" status_field="$2" reviewed_status="$3"
  local replacement="${status_field}: ${reviewed_status}"
  if LC_ALL=C grep -q "^${status_field}:.*"$'\r$' "$file"; then
    replacement+=$'\r'
  fi
  sed "s/^${status_field}:[[:space:]]*.*/${replacement}/" "$file" | sha256_stream
}
# Shared predecessor-verdict validation (require_persisted_pass and
# assert_contract_reviewer_agreement) lives in lib/review-precheck-common.sh,
# shared with the sibling precheck. It calls this script's fail/sha256/
# reviewed_sha256 helpers and reads FEATURE/repo_root/CALIBRATION_MD/
# LAYER_FILES, all defined above.
if ! . "$(cd "$(dirname "$0")" && pwd -P)/lib/review-precheck-common.sh"; then
  fail "lib/review-precheck-common.sh unavailable beside this script"
fi

command -v jq >/dev/null 2>&1 || fail "jq is required"
# Fail closed when no SHA-256 tool exists: with the bare else-shasum shape a
# host with neither tool captures an empty digest and empty == empty passes.
command -v sha256sum >/dev/null 2>&1 || command -v shasum >/dev/null 2>&1 ||
  fail "neither sha256sum nor shasum is available"

[[ "$FEATURE" =~ ^[a-z0-9][a-z0-9-]*$ ]] || fail "invalid feature slug"
[[ "$ATTEMPT" =~ ^[1-9][0-9]*$ ]] || fail "attempt must be a positive integer"
[[ "$ROUND" =~ ^[1-9][0-9]*$ ]] || fail "round must be a positive integer"
[[ -z "$MODE" || "$MODE" == "--verify-inputs" || "$MODE" == "--provenance-rereview" ]] ||
  fail "unknown mode: $MODE"
profile="$(jq -r --arg feature "$FEATURE" '.entries[]? | select(.feature == $feature) | .profile' "$REGISTRY" | tail -n 1)"
full_profile=false
[[ "$profile" == "full" ]] && full_profile=true

if [[ "$MODE" == "--verify-inputs" ]]; then
  precheck="${REPORT_DIR}/precheck-result.json"
  [[ -f "$precheck" && ! -L "$precheck" ]] || fail "precheck evidence is missing or substituted"
  for path in "$DESIGN_MD" "$REQS_MD" "$ACCEPT_MD"; do
    [[ -f "$path" && ! -L "$path" ]] || fail "review input is missing or substituted: $path"
  done
  jq -e --arg design "$(sha256 "$DESIGN_MD")" --arg requirements "$(sha256 "$REQS_MD")" \
    --arg acceptance "$(sha256 "$ACCEPT_MD")" --arg feature "$FEATURE" \
    --argjson attempt "$ATTEMPT" --argjson round "$ROUND" '
      .schema == "impl-review-precheck/v1" and
      .feature == $feature and .attempt == $attempt and .round == $round and
      .design_sha256 == $design and .requirements_sha256 == $requirements and
      .acceptance_sha256 == $acceptance
    ' "$precheck" >/dev/null || fail "core review inputs changed after precheck"
  bound_layer_count="$(jq -r '(.layer_sha256 // {}) | length' "$precheck")"
  if $full_profile || [[ "$bound_layer_count" -gt 0 ]]; then
    jq -e '(.layer_sha256 | keys) == ["frontend-spec.md","infra-spec.md","security-spec.md","ux-spec.md"]' \
      "$precheck" >/dev/null || fail "precheck layer manifest is incomplete"
    for name in "${LAYER_FILES[@]}"; do
      path="${SPECS_DIR}/${name}"
      [[ -f "$path" && ! -L "$path" ]] || fail "layer review input is missing or substituted: $path"
      jq -e --arg name "$name" --arg hash "$(sha256 "$path")" \
        '.layer_sha256[$name] == $hash' "$precheck" >/dev/null ||
        fail "layer review input changed after precheck: $path"
    done
  fi
  echo "impl-review-precheck: inputs verified for reviewer invocation."
  exit 0
fi

[[ ! -e "$REPORT_DIR" && ! -L "$REPORT_DIR" ]] || fail "round destination already exists (replay is forbidden)"
[[ -d "$SPECS_DIR" && ! -L "$SPECS_DIR" ]] || fail "feature specification directory must be a real directory"
[[ "$(cd "$SPECS_DIR" && pwd -P)" == "$repo_root/specs/$FEATURE" ]] || fail "feature specification directory escapes repository"
if [[ "$MODE" == "--provenance-rereview" ]]; then
  # Post-implementation evidence re-binding. Mirrors task-review-precheck.sh's
  # mode of the same name, with the same guard: a prior persisted PASS at this
  # stage must already exist, so this mode can only ever re-bind evidence for a
  # design that genuinely passed -- it can never stand in for a first review.
  #
  # The canonical gate is advisory here rather than fatal, because a stale
  # impl-stage contract hash is exactly the condition this mode exists to
  # repair: requiring the gate to be green first would make the repair
  # unreachable from the state that needs it.
  prior_pass=false
  while IFS= read -r verdict_file; do
    if jq -e --arg feature "$FEATURE" \
      '.feature == $feature and .stage == "impl" and .verdict == "PASS"' \
      "$verdict_file" >/dev/null 2>&1; then
      prior_pass=true
      break
    fi
  done < <(find "$IMPL_REPORT_ROOT" -type f -name integrated-verdict.json ! -lname '*' -print 2>/dev/null)
  [[ "$prior_pass" == "true" ]] ||
    fail "provenance re-review requires a prior persisted impl-review PASS verdict"
  if ! bash "$repo_root/plugins/sdd-quality-loop/scripts/check-workflow-state.sh" --feature "$FEATURE" --opening "impl:${ATTEMPT}:${ROUND}"; then
    echo "NOTE: impl-review-precheck: canonical workflow-state validation failed;" \
      "proceeding under --provenance-rereview (impl-stage evidence re-binding in progress)." >&2
  fi
else
  bash "$repo_root/plugins/sdd-quality-loop/scripts/check-workflow-state.sh" --feature "$FEATURE" --opening "impl:${ATTEMPT}:${ROUND}" ||
    fail "canonical workflow-state validation failed"
fi

# ──────────────────────────────────────────────────────────────────────────────
# STEP 1: Check design.md exists and has Impl-Review-Status: Pending
# ──────────────────────────────────────────────────────────────────────────────

if [[ ! -f "${DESIGN_MD}" || -L "${DESIGN_MD}" ]]; then
  echo "ERROR: impl-review-precheck: ${DESIGN_MD} not found." >&2
  exit 1
fi

if [[ ! -f "${REQS_MD}" || -L "${REQS_MD}" ]]; then
  echo "ERROR: impl-review-precheck: ${REQS_MD} not found." >&2
  exit 1
fi

spec_review_status=$(sed -n 's/^Spec-Review-Status:[[:space:]]*//p' "${REQS_MD}" | head -n 1 | tr -d '[:space:]')
[[ "$spec_review_status" == "Passed" ]] || fail "requirements.md must declare Spec-Review-Status: Passed"

# Check for Impl-Review-Status field
impl_review_status=$(sed -n 's/^Impl-Review-Status:[[:space:]]*//p' "${DESIGN_MD}" | head -n 1 | tr -d '[:space:]')

if [[ -z "${impl_review_status}" ]]; then
  echo "ERROR: impl-review-precheck: design.md is missing 'Impl-Review-Status:' header field." \
    "Add 'Impl-Review-Status: Pending' to design.md before invoking impl-review-loop." >&2
  exit 1
fi

if [[ "$MODE" == "--provenance-rereview" ]]; then
  # The header stays Passed for the whole re-binding, deliberately. Flipping it
  # to Pending is not an option here: check-workflow-state.sh's task-lifecycle
  # rule requires every stage to read Passed once any task is Approved or past
  # Planned, so a Pending header on a feature that has already shipped trades
  # this stage's contradiction for a worse one.
  if [[ "${impl_review_status}" != "Passed" ]]; then
    echo "ERROR: impl-review-precheck: --provenance-rereview requires design.md to" \
      "declare 'Impl-Review-Status: Passed'; it declares '${impl_review_status}'." \
      "Without a prior pass there is no provenance to re-bind -- run an ordinary" \
      "attempt instead." >&2
    exit 1
  fi
elif [[ "${impl_review_status}" != "Pending" ]] && [[ "${impl_review_status}" != "pending" ]]; then
  echo "ERROR: impl-review-precheck: Impl-Review-Status is '${impl_review_status}', expected 'Pending'." \
    "If a previous review has already passed and this is an evidence re-binding," \
    "use --provenance-rereview." >&2
  exit 1
fi

# ──────────────────────────────────────────────────────────────────────────────
# STEP 2: Detect legacy_design
# Criteria: design.md predates new template if it lacks required template fields
# ──────────────────────────────────────────────────────────────────────────────

legacy_design=false
required_fields=(
  "## Components"
  "Feature Type:"
  "Data Entities:"
  "Existing Data Affected:"
  "## Security Boundaries"
)

missing_count=0
for field in "${required_fields[@]}"; do
  if ! grep -qF "${field}" "${DESIGN_MD}" 2>/dev/null; then
    missing_count=$((missing_count + 1))
  fi
done

# If 3 or more required template fields are missing, treat as legacy design
if [[ "${missing_count}" -ge 3 ]]; then
  legacy_design=true
fi

# ──────────────────────────────────────────────────────────────────────────────
# STEP 3: Compute sha256 for each input file
# ──────────────────────────────────────────────────────────────────────────────

design_sha256=$(sha256 "${DESIGN_MD}")
requirements_sha256=$(sha256 "${REQS_MD}")

acceptance_sha256=""
[[ -f "${ACCEPT_MD}" && ! -L "${ACCEPT_MD}" ]] || fail "${ACCEPT_MD} not found"
acceptance_sha256=$(sha256 "${ACCEPT_MD}")
[[ -f "${CALIBRATION_MD}" && ! -L "${CALIBRATION_MD}" ]] || fail "${CALIBRATION_MD} not found"
calibration_sha256=$(sha256 "${CALIBRATION_MD}")
layer_sha256='{}'
if $full_profile; then
  for name in "${LAYER_FILES[@]}"; do
    path="${SPECS_DIR}/${name}"
    [[ -f "$path" && ! -L "$path" ]] || fail "layer review input is missing or substituted: $path"
    layer_sha256="$(jq -c --arg name "$name" --arg hash "$(sha256 "$path")" \
      '. + {($name): $hash}' <<<"$layer_sha256")"
  done
fi
spec_review_requirements_sha256="$(reviewed_sha256 "$REQS_MD" "Spec-Review-Status" "Pending")"
require_persisted_pass "$SPEC_REPORT_ROOT" spec "$spec_review_requirements_sha256" "$acceptance_sha256" "" "$requirements_sha256" ""

# ──────────────────────────────────────────────────────────────────────────────
# STEP 4: Round > 1 — verify design.md changed; check DESIGN-REQ-DRIFT
# ──────────────────────────────────────────────────────────────────────────────

design_req_drift=false

if [[ "${ROUND}" -gt 1 ]]; then
  prior_round=$((ROUND - 1))
  prior_contract="reports/impl-review/${FEATURE}/attempt-${ATTEMPT}/round-${prior_round}/impl-review-contract.json"

  if [[ -f "${prior_contract}" ]]; then
    # The prior round's own verdict must belong to the text its reviewers read.
    # This is the site where the epic-136-phase4-docs attempt-2 round-2 defect
    # lived: require_persisted_pass only inspects the spec contract, so without
    # this call an impl round-to-round handoff carries no such check at all.
    assert_contract_reviewer_agreement "${prior_contract}" impl

    prior_design_sha256=$(python3 -c "import json,sys; d=json.load(open('${prior_contract}')); print(d.get('design_sha256',''))" 2>/dev/null || echo "")

    if [[ "${design_sha256}" == "${prior_design_sha256}" ]]; then
      echo "ERROR: impl-review-precheck: design.md sha256 is unchanged from round ${prior_round}." \
        "A new round must review changed text; edit design.md, then re-invoke." >&2
      exit 1
    fi

    # DESIGN-REQ-DRIFT: compare requirements_sha256 against round-1 stored value
    round1_contract="reports/impl-review/${FEATURE}/attempt-${ATTEMPT}/round-1/impl-review-contract.json"
    if [[ -f "${round1_contract}" ]]; then
      round1_req_sha256=$(python3 -c "import json,sys; d=json.load(open('${round1_contract}')); print(d.get('requirements_sha256',''))" 2>/dev/null || echo "")

      if [[ -n "${round1_req_sha256}" ]] && [[ "${requirements_sha256}" != "${round1_req_sha256}" ]]; then
        design_req_drift=true
        echo "WARNING: impl-review-precheck: requirements.md has changed since round 1 of this attempt." \
          "DESIGN-REQ-DRIFT detected. Reviewers will note this condition." >&2
      fi
    fi
  fi
fi

# AC coverage. Every AC-NNN in requirements.md must be named in design.md.
#
# This is deterministic work that was being paid for with reviewer rounds. On
# epic-136-phase4-docs, impl review spent rounds 2 and 3 of attempt 1 finding
# AC-013 and then AC-012 missing from the design plan, one per round, and the
# attempt escalated to BLOCKED. A later mechanical sweep found AC-001 and AC-014
# absent as well. Every one of them was an AC that spec review had added late as
# a gap-closer, which the design -- written against the REQ-* headings -- dropped
# silently. A design that does not name an AC cannot be audited for covering it.
#
# NARROW EXCEPTION (human ruling, 2026-08-24). Some acceptance criteria are
# structurally not design content, and no design document can honestly name
# them: epic-194's AC-023/AC-024 and epic-193's AC-035/AC-036/AC-037 are
# criteria about the SPEC PACKAGE'S OWN REGISTRATION COMMIT -- AC-024 requires
# both status headers to read `Pending` "at commit time", which is not a
# property any design plans for and is now historically false since both read
# `Passed`. Demanding a design citation for those is demanding a false
# statement.
#
# The exception keys on a property the requirements document states about
# ITSELF, never on a list of AC ids and never on "cited somewhere in the spec
# package". requirements.md's acceptance table gives every criterion a
# requirement-trace cell, and that cell is bimodal across this repository: it
# either names the REQ-NNN the criterion refines, or it declares the criterion
# process-and-registration scope rather than behaviour. Two spellings of the
# latter are in use -- `| AC-023 | Global |` (epic-194) and
# `| AC-035 (Global) | - |` (epic-193) -- and both are read here.
#
# This is narrow in the way that matters. The declaration is made in
# requirements.md, in the row that defines the criterion, where spec review
# reads and adjudicates it -- an author cannot quietly excuse a behaviour AC
# without visibly restating its scope in the document the spec reviewers are
# looking at. And it leaves the epic-136 class fully caught: those were
# gap-closer criteria added late under a REQ-* heading, so their rows carry a
# REQ trace and the gate still demands the design name them. Only the first
# cell and the trace cell of a criterion's OWN defining row are consulted;
# mentions of an AC id in prose or in another criterion's text are never a
# declaration of scope.
ac_scoped_global() {
  LC_ALL=C awk -v id="$1" '
    {
      line = $0
      sub(/\r$/, "", line)
      if (substr(line, 1, 1) != "|") next
      # Bracketed, not a bare "|": a one-character split separator is treated
      # literally by some awks and as an ERE by others, and "|" as an ERE is
      # empty alternation. [|] is unambiguous everywhere.
      n = split(line, cell, "[|]")
      if (n < 4) next
      c1 = cell[2]; c2 = cell[3]
      sub(/^[ \t]+/, "", c1); sub(/[ \t]+$/, "", c1)
      sub(/^[ \t]+/, "", c2); sub(/[ \t]+$/, "", c2)
      annotated = 0
      if (c1 ~ /\(Global\)$/) {
        annotated = 1
        sub(/\(Global\)$/, "", c1)
        sub(/[ \t]+$/, "", c1)
      }
      if (c1 != id) next
      if (annotated || c2 == "Global") { global = 1 }
      found = 1
      exit
    }
    END { exit (found && global ? 0 : 1) }
  ' "${REQS_MD}"
}
ac_missing=""
ac_global=""
if [[ -f "${REQS_MD}" && -f "${DESIGN_MD}" ]]; then
  while IFS= read -r ac_id; do
    [[ -n "${ac_id}" ]] || continue
    if ac_scoped_global "${ac_id}"; then
      ac_global+="${ac_id} "
      continue
    fi
    grep -Fq -- "${ac_id}" "${DESIGN_MD}" || ac_missing+="${ac_id} "
  done < <(grep -oE 'AC-[0-9]{3}' "${REQS_MD}" | sort -u)
fi
# Never silent: an exercised exception is reported whether or not the gate then
# fails, so a reader can see which criteria were excused and go check the rows
# that excused them.
if [[ -n "${ac_global}" ]]; then
  echo "NOTE: impl-review-precheck: not requiring design.md to name these criteria," \
    "which requirements.md scopes Global (process and registration, not design): ${ac_global% }" >&2
fi
if [[ -n "${ac_missing}" ]]; then
  echo "ERROR: impl-review-precheck: design.md never names these acceptance criteria: ${ac_missing% }" >&2
  echo "       Each appears in requirements.md without being scoped Global there -- so each states" >&2
  echo "       behaviour this design must plan for -- yet none of these strings occurs anywhere in" >&2
  echo "       design.md, so an implementer could satisfy the plan and still not deliver them." >&2
  exit 1
fi

# ──────────────────────────────────────────────────────────────────────────────
# STEP 5: Validate the shared portable contract before creating output evidence.
# ──────────────────────────────────────────────────────────────────────────────

if $full_profile; then
  input_material="$(printf '%s:%s:%s:%s' "$design_sha256" "$requirements_sha256" "$acceptance_sha256" "$layer_sha256")"
else
  input_material="$(printf '%s:%s:%s' "$design_sha256" "$requirements_sha256" "$acceptance_sha256")"
fi
input_sha256="$(printf '%s' "$input_material" | sha256_stream)"
foundation_contract="$(mktemp)"
trap 'rm -f "$foundation_contract"' EXIT
jq -n --arg feature "$FEATURE" --argjson attempt "$ATTEMPT" --argjson round "$ROUND" --arg input_sha256 "$input_sha256" \
  '{schema:"review-contract/v1",stage:"impl",feature:$feature,attempt:$attempt,round:$round,input_sha256:$input_sha256,run_id:"impl-precheck",verdict:"PASS"}' > "$foundation_contract"
mkdir -p "reports/impl-review"
"${repo_root}/plugins/sdd-review-loop/scripts/review-contract-validate.sh" --feature "$FEATURE" --attempt "$ATTEMPT" --round "$ROUND" --stage impl --report-root "$IMPL_REPORT_ROOT" --contract "$foundation_contract" >/dev/null

# ──────────────────────────────────────────────────────────────────────────────
# STEP 6: Create output directory and write precheck-result.json
# ──────────────────────────────────────────────────────────────────────────────

mkdir -p "${REPORT_DIR}"

generated_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

cat > "${REPORT_DIR}/precheck-result.json" <<EOF
{
  "schema": "impl-review-precheck/v1",
  "feature": "${FEATURE}",
  "attempt": ${ATTEMPT},
  "round": ${ROUND},
  "impl_review_status_field": "${impl_review_status}",
  "legacy_design": ${legacy_design},
  "design_req_drift": ${design_req_drift},
  "design_sha256": "${design_sha256}",
  "requirements_sha256": "${requirements_sha256}",
  "acceptance_sha256": "${acceptance_sha256}",
  "layer_sha256": ${layer_sha256},
  "input_sha256": "${input_sha256}",
  "generated_at": "${generated_at}"
}
EOF

echo "impl-review-precheck: complete. Output written to ${REPORT_DIR}/"

exit 0
