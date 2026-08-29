#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
BUILDER="$REPO_ROOT/tests/lib/fixture-matrix-builder.sh"
CANON="$REPO_ROOT/tests/lib/markdown-ast-canonicalizer.sh"
BOOTSTRAP_SKILL="$REPO_ROOT/plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md"
LITE_SKILL="$REPO_ROOT/plugins/sdd-lite/skills/lite-spec/SKILL.md"
CORPUS="$REPO_ROOT/tests/fixtures/structural-fixture-corpus"
SCHEMA="structural-fixture-corpus/v1"
REFRESH_PROCEDURE="tests/structural-compatibility-live-refresh.tests.sh"

usage() {
  printf 'usage: %s [--fixture F1|F2|all] [--target-dir DIR] [--self-test]\n' "${0##*/}" >&2
  exit 2
}

extract_full_paths() {
  local source=${1:-$BOOTSTRAP_SKILL}
  awk '
    /^## Required Outputs$/ { in_outputs=1; next }
    in_outputs && /^Phase 2 outputs/ { exit }
    in_outputs && /^- `specs\/<feature>\/[^`]+\.md`$/ {
      line=$0; sub(/^- `specs\/<feature>\//, "", line); sub(/`$/, "", line); print line
    }
  ' "$source"
}

extract_lite_paths() {
  awk '
    /次の3ファイルを `specs\/<feature>\/` に生成/ { in_outputs=1; next }
    in_outputs && /^4\./ { exit }
    in_outputs && /- `[^`]+\.md`/ {
      line=$0; sub(/^.*- `/, "", line); sub(/`.*/, "", line); print line
    }
  ' "$LITE_SKILL"
}

template_for() {
  local track=$1 path=$2
  if [[ "$track" == full ]]; then
    printf '%s/plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/%s.template.md\n' "$REPO_ROOT" "${path%.md}"
    return
  fi
  case "$path" in
    requirements.md) printf '%s/plugins/sdd-lite/templates/requirements-lite.md\n' "$REPO_ROOT" ;;
    design.md) printf '%s/plugins/sdd-lite/templates/design-lite.md\n' "$REPO_ROOT" ;;
    tasks.md) printf '%s/plugins/sdd-lite/templates/tasks-lite.md\n' "$REPO_ROOT" ;;
    *) return 1 ;;
  esac
}

status_fields() {
  sed -n -E 's/^([[:alpha:]][[:alnum:] -]*(Status|Approval)):[[:space:]].*$/\1/p' "$1" | LC_ALL=C sort -u
}

validate_candidate() {
  local file=$1 state=$2 track=$3 work expected actual path template raw expected_ast actual_ast
  local expected_status actual_status all_content ids reserved_a reserved_b
  work="$(mktemp -d "${TMPDIR:-/tmp}/structural-live-validate.XXXXXX")"

  if ! jq -e --arg schema "$SCHEMA" --arg state "$state" --arg refresh "$REFRESH_PROCEDURE" '
      type == "object" and
      ((keys | sort) == ["artifacts","fixture_state","recorded_at_commit","recorded_at_model","refresh_procedure","schema"]) and
      .schema == $schema and .fixture_state == $state and
      (.recorded_at_model | type == "string" and length > 0) and
      (.recorded_at_commit | type == "string" and test("^[0-9a-f]{40}$")) and
      .refresh_procedure == $refresh and (.artifacts | type == "array" and length > 0) and
      all(.artifacts[]; type == "object" and (keys | sort) == ["content","path"] and
        (.path | type == "string" and length > 0) and (.content | type == "string"))
    ' "$file" >/dev/null; then
    rm -rf -- "$work"
    return 1
  fi

  expected="$work/expected-paths"
  actual="$work/actual-paths"
  if [[ "$track" == full ]]; then extract_full_paths >"$expected"; else extract_lite_paths >"$expected"; fi
  jq -r '.artifacts[].path' "$file" | LC_ALL=C sort >"$actual"
  LC_ALL=C sort -o "$expected" "$expected"
  if ! cmp -s "$expected" "$actual"; then
    rm -rf -- "$work"
    return 1
  fi

  while IFS= read -r path; do
    template="$(template_for "$track" "$path")" || { rm -rf -- "$work"; return 1; }
    [[ -f "$template" ]] || { rm -rf -- "$work"; return 1; }
    raw="$work/${path//\//_}.md"
    expected_ast="$work/${path//\//_}.expected.ast"
    actual_ast="$work/${path//\//_}.actual.ast"
    if ! jq -er --arg path "$path" '.artifacts[] | select(.path == $path) | .content' "$file" >"$raw" ||
       ! bash "$CANON" "$template" >"$expected_ast" 2>/dev/null ||
       ! bash "$CANON" "$raw" >"$actual_ast" 2>/dev/null ||
       ! cmp -s "$expected_ast" "$actual_ast"; then
      rm -rf -- "$work"
      return 1
    fi
    expected_status="$work/${path//\//_}.expected.status"
    actual_status="$work/${path//\//_}.actual.status"
    status_fields "$template" >"$expected_status"
    status_fields "$raw" >"$actual_status"
    if ! cmp -s "$expected_status" "$actual_status"; then
      rm -rf -- "$work"
      return 1
    fi
  done <"$expected"

  all_content="$work/all-content.md"
  jq -r '.artifacts[].content' "$file" >"$all_content"
  ids="$(grep -Eo '(REQ|AC)-[A-Za-z0-9-]+' "$all_content" || true)"
  if [[ -z "$ids" ]] || grep -Ev '^(REQ|AC)-[0-9]{3}$' <<<"$ids" >/dev/null; then
    rm -rf -- "$work"
    return 1
  fi
  reserved_a="Fac""et"
  reserved_b="capab""ility"
  if grep -Fqi "$reserved_a" "$all_content" || grep -Fqi "$reserved_b" "$all_content" ||
     jq -er '.artifacts[].path' "$file" | grep -Eqi "${reserved_a}|${reserved_b}"; then
    rm -rf -- "$work"
    return 1
  fi

  rm -rf -- "$work"
  return 0
}

fixture_parameters() {
  case "$1" in
    F1) printf '%s\n' 'absent absent disabled-legacy valid --full full f1-full.json' ;;
    F2) printf '%s\n' 'absent present disabled-legacy valid --lite lite f2-lite.json' ;;
    *) return 2 ;;
  esac
}

make_prompt() {
  local state=$1 track_flag=$2 profile=$3 marker_key
  marker_key="capab""ility_enforcement"
  cat <<EOF
Follow the sdd-bootstrap-interviewer workflow at $BOOTSTRAP_SKILL for a throwaway structural recording only.
The fixture is fixture_state=$state with project_context=absent, agents_marker=$profile, ${marker_key}=disabled-legacy, and track_flag=$track_flag.
Do not write files. Generate the track's required specification artifacts structurally, including the shipped required headings, status-field names, and at least REQ-001 and AC-001 where identifiers belong.
Return only compact JSON with exactly one top-level key named artifacts. Its value must be an array of objects with exactly path and content string fields. Do not use Markdown fences or explanatory prose.
EOF
}

recorded_model() {
  jq -er '
    [(.model? // empty), ((.modelUsage? // {}) | keys[]?)]
    | map(select(type == "string" and length > 0)) | unique | join(",")
    | select(length > 0)
  ' "$1"
}

extract_artifacts() {
  jq -cer '
    select(type == "object" and (keys == ["artifacts"]))
    | .artifacts
    | select(type == "array")
    | select(all(.[]; type == "object" and (keys | sort) == ["content","path"] and
        (.path | type == "string" and length > 0) and (.content | type == "string")))
  '
}

refresh_one() {
  local state=$1 target_dir=$2 params project_context agents_marker enforcement validity track_flag track file_name
  params="$(fixture_parameters "$state")"
  read -r project_context agents_marker enforcement validity track_flag track file_name <<<"$params"

  # shellcheck source=tests/lib/fixture-matrix-builder.sh
  source "$BUILDER"
  local fixture_root work response_file result_text artifacts model commit candidate target target_tmp prompt
  fixture_root="$(build_fixture "$project_context" "$agents_marker" "$enforcement" "$validity" "$track_flag")"
  work="$(mktemp -d "${TMPDIR:-/tmp}/structural-live-refresh.XXXXXX")"
  response_file="$work/response.json"
  candidate="$work/candidate.json"
  target="$target_dir/$file_name"
  prompt="$(make_prompt "$state" "$track_flag" "$agents_marker")"

  cleanup_refresh() {
    _fixture_matrix_cleanup "$fixture_root"
    rm -rf -- "$work"
  }

  if ! (cd "$fixture_root" && claude -p "$prompt" --output-format json) >"$response_file"; then
    printf 'FAIL: %s live invocation failed\n' "$state" >&2
    cleanup_refresh
    return 1
  fi
  if ! result_text="$(jq -er '.result | select(type == "string" and length > 0)' "$response_file")" ||
     ! artifacts="$(printf '%s' "$result_text" | extract_artifacts)" ||
     ! model="$(recorded_model "$response_file")"; then
    printf 'FAIL: %s live response did not satisfy the response contract\n' "$state" >&2
    cleanup_refresh
    return 1
  fi
  commit="$(git -C "$REPO_ROOT" rev-parse HEAD)"
  jq -n --arg schema "$SCHEMA" --arg state "$state" --arg model "$model" \
    --arg commit "$commit" --arg refresh "$REFRESH_PROCEDURE" --argjson artifacts "$artifacts" \
    '{schema:$schema, fixture_state:$state, recorded_at_model:$model,
      recorded_at_commit:$commit, refresh_procedure:$refresh, artifacts:$artifacts}' >"$candidate"

  if ! validate_candidate "$candidate" "$state" "$track"; then
    printf 'FAIL: %s candidate failed structural validation; corpus unchanged\n' "$state" >&2
    cleanup_refresh
    return 1
  fi

  mkdir -p -- "$target_dir"
  target_tmp="$(mktemp "$target_dir/.${file_name}.XXXXXX")"
  jq '.' "$candidate" >"$target_tmp"
  chmod 0644 "$target_tmp"
  mv -f -- "$target_tmp" "$target"
  printf 'PASS: %s live response validated before refresh: %s\n' "$state" "$target"
  cleanup_refresh
}

self_test() {
  local test_root stub_dir scratch stub capture failures=0
  test_root="$(mktemp -d "${TMPDIR:-/tmp}/structural-live-self-test.XXXXXX")"
  stub_dir="$test_root/bin"
  scratch="$test_root/corpus"
  capture="$test_root/argv.txt"
  mkdir -p "$stub_dir" "$scratch"
  stub="$stub_dir/claude"
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -euo pipefail' \
    '[[ $# -eq 4 && $1 == -p && $3 == --output-format && $4 == json ]] || exit 64' \
    'prompt=$2' \
    'state=F1; file=f1-full.json' \
    'if [[ "$prompt" == *"fixture_state=F2"* ]]; then state=F2; file=f2-lite.json; fi' \
    'printf "%s\n%s\n%s\n" "$1" "$3" "$4" > "$STRUCTURAL_REFRESH_STUB_CAPTURE"' \
    '[[ "$prompt" == *"project_context=absent"* && "$prompt" == *"disabled-legacy"* ]] || exit 65' \
    'if [[ "$state" == F1 ]]; then [[ ! -e AGENTS.md && "$prompt" == *"track_flag=--full"* ]] || exit 66; else [[ -f AGENTS.md && "$prompt" == *"track_flag=--lite"* ]] || exit 67; fi' \
    'if [[ "${STRUCTURAL_REFRESH_STUB_CASE:-valid}" == missing-result ]]; then jq -cn '\''{modelUsage:{"claude-test":{}}}'\''; exit; fi' \
    'if [[ "${STRUCTURAL_REFRESH_STUB_CASE:-valid}" == bad-payload ]]; then jq -cn '\''{result:"{\"not_artifacts\":[]}",modelUsage:{"claude-test":{}}}'\''; exit; fi' \
    'payload="$(jq -c '\''{artifacts:.artifacts}'\'' "$STRUCTURAL_REFRESH_STUB_CORPUS/$file")"' \
    'if [[ "${STRUCTURAL_REFRESH_STUB_CASE:-valid}" == bad-heading ]]; then payload="$(jq -c '\''.artifacts[0].content += "\n## Unexpected live heading\n"'\'' <<<"$payload")"; fi' \
    'jq -cn --arg result "$payload" '\''{result:$result,modelUsage:{"claude-test":{}}}'\''' \
    >"$stub"
  chmod +x "$stub"

  run_refresh() {
    local state=$1 case_name=$2 target_dir=$3
    PATH="$stub_dir:$PATH" STRUCTURAL_REFRESH_STUB_CORPUS="$CORPUS" \
      STRUCTURAL_REFRESH_STUB_CAPTURE="$capture" STRUCTURAL_REFRESH_STUB_CASE="$case_name" \
      bash "$SCRIPT_DIR/structural-compatibility-live-refresh.tests.sh" --fixture "$state" --target-dir "$target_dir"
  }
  pass() { printf 'PASS: %s\n' "$1"; }
  fail() { printf 'FAIL: %s\n' "$1" >&2; failures=$((failures + 1)); }

  cp "$CORPUS/f1-full.json" "$scratch/f1-full.json"
  local before after rc
  before="$(shasum -a 256 "$scratch/f1-full.json" | awk '{print $1}')"
  set +e
  run_refresh F1 bad-heading "$scratch" >"$test_root/bad-existing.log" 2>&1
  rc=$?
  set -e
  after="$(shasum -a 256 "$scratch/f1-full.json" | awk '{print $1}')"
  if [[ $rc -ne 0 && "$after" == "$before" ]]; then pass 'structurally invalid live response preserves an existing target'; else fail 'structurally invalid live response preserves an existing target'; fi

  rm -f "$scratch/f1-full.json"
  set +e
  run_refresh F1 bad-heading "$scratch" >"$test_root/bad-absent.log" 2>&1
  rc=$?
  set -e
  if [[ $rc -ne 0 && ! -e "$scratch/f1-full.json" ]]; then pass 'structurally invalid live response preserves an absent target'; else fail 'structurally invalid live response preserves an absent target'; fi

  rm -f "$scratch/f1-full.json"
  set +e
  run_refresh F1 missing-result "$scratch" >"$test_root/missing-result.log" 2>&1
  rc=$?
  set -e
  if [[ $rc -ne 0 && ! -e "$scratch/f1-full.json" ]]; then pass 'missing final result is rejected before write'; else fail 'missing final result is rejected before write'; fi

  set +e
  run_refresh F1 bad-payload "$scratch" >"$test_root/bad-payload.log" 2>&1
  rc=$?
  set -e
  if [[ $rc -ne 0 && ! -e "$scratch/f1-full.json" ]]; then pass 'malformed final artifact payload is rejected before write'; else fail 'malformed final artifact payload is rejected before write'; fi

  if run_refresh F1 valid "$scratch" >"$test_root/valid-f1.log" 2>&1 && validate_candidate "$scratch/f1-full.json" F1 full; then pass 'valid F1 response refreshes a scratch target'; else fail 'valid F1 response refreshes a scratch target'; fi
  if run_refresh F2 valid "$scratch" >"$test_root/valid-f2.log" 2>&1 && validate_candidate "$scratch/f2-lite.json" F2 lite; then pass 'valid F2 response refreshes a scratch target'; else fail 'valid F2 response refreshes a scratch target'; fi
  if [[ "$(sed -n '1p' "$capture")" == -p && "$(sed -n '2p' "$capture")" == --output-format && "$(sed -n '3p' "$capture")" == json ]]; then pass 'live invocation uses the exact argument contract'; else fail 'live invocation uses the exact argument contract'; fi

  local miscased_skill="$test_root/miscased-bootstrap-skill.md"
  sed 's/^## Required Outputs$/## required outputs/' "$BOOTSTRAP_SKILL" >"$miscased_skill"
  if [[ -z "$(extract_full_paths "$miscased_skill")" ]]; then pass 'mis-cased required-output anchor is rejected'; else fail 'mis-cased required-output anchor is rejected'; fi

  local mutation mutation_file reserved_a reserved_b
  reserved_a="Fac""et"
  reserved_b="capab""ility"
  for mutation in schema state model commit refresh path frontmatter heading status identifier reserved-a reserved-b; do
    mutation_file="$test_root/mutation-$mutation.json"
    case "$mutation" in
      schema) jq '.schema="STRUCTURAL-FIXTURE-CORPUS/v1"' "$CORPUS/f1-full.json" >"$mutation_file" ;;
      state) jq '.fixture_state="f1"' "$CORPUS/f1-full.json" >"$mutation_file" ;;
      model) jq '.recorded_at_model=""' "$CORPUS/f1-full.json" >"$mutation_file" ;;
      commit) jq '.recorded_at_commit="ABC"' "$CORPUS/f1-full.json" >"$mutation_file" ;;
      refresh) jq '.refresh_procedure="tests/other.sh"' "$CORPUS/f1-full.json" >"$mutation_file" ;;
      path) jq '.artifacts[0].path="Requirements.md"' "$CORPUS/f1-full.json" >"$mutation_file" ;;
      frontmatter) jq '.artifacts[0].content="---\ntitle: broken\n"' "$CORPUS/f1-full.json" >"$mutation_file" ;;
      heading) jq '.artifacts[0].content += "\n####### Broken\n"' "$CORPUS/f1-full.json" >"$mutation_file" ;;
      status) jq '(.artifacts[] | select(.path=="design.md") | .content) |= gsub("Impl-Review-Status";"Impl-Review-State")' "$CORPUS/f1-full.json" >"$mutation_file" ;;
      identifier) jq '(.artifacts[0].content) |= gsub("REQ-001";"REQ-01")' "$CORPUS/f1-full.json" >"$mutation_file" ;;
      reserved-a) jq --arg marker "$reserved_a" '.artifacts[0].content += ("\n"+$marker+"\n")' "$CORPUS/f1-full.json" >"$mutation_file" ;;
      reserved-b) jq --arg marker "$reserved_b" '.artifacts[0].content += ("\n"+$marker+"\n")' "$CORPUS/f1-full.json" >"$mutation_file" ;;
    esac
    if validate_candidate "$mutation_file" F1 full >/dev/null 2>&1; then fail "validator rejects $mutation mismatch"; else pass "validator rejects $mutation mismatch"; fi
  done

  if ! rg -F 'structural-compatibility-live-refresh' "$REPO_ROOT/tests/run-all.sh" "$REPO_ROOT/tests/run-all.ps1" "$REPO_ROOT/.github/workflows/test.yml" >/dev/null; then pass 'live refresh remains outside aggregate runners and CI'; else fail 'live refresh remains outside aggregate runners and CI'; fi

  rm -rf -- "$test_root"
  printf '%d self-tests failed\n' "$failures"
  [[ $failures -eq 0 ]]
}

fixture=all
target_dir=$CORPUS
mode=live
while [[ $# -gt 0 ]]; do
  case "$1" in
    --fixture) [[ $# -ge 2 ]] || usage; fixture=$2; shift 2 ;;
    --target-dir) [[ $# -ge 2 ]] || usage; target_dir=$2; shift 2 ;;
    --self-test) mode=self-test; shift ;;
    *) usage ;;
  esac
done
case "$fixture" in F1|F2|all) ;; *) usage ;; esac

if [[ "$mode" == self-test ]]; then
  self_test
elif [[ "$fixture" == all ]]; then
  refresh_one F1 "$target_dir"
  refresh_one F2 "$target_dir"
else
  refresh_one "$fixture" "$target_dir"
fi
