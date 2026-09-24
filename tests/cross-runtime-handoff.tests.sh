#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s [--fixture <directory>] [--trace-file <path>] [--self-test-activation]\n' "$0" >&2
}
fixture_dir=""
trace_file=""
self_test=0
live_e2e=0
while (($#)); do
  case "$1" in
    --fixture) (($# >= 2)) || { usage; exit 2; }; fixture_dir=$2; shift 2 ;;
    --trace-file) (($# >= 2)) || { usage; exit 2; }; trace_file=$2; shift 2 ;;
    --self-test-activation) self_test=1; shift ;;
    --live-e2e) live_e2e=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage; exit 2 ;;
  esac
done

repo_root=$(git rev-parse --show-toplevel)
default_fixture="$repo_root/tests/fixtures/cross-runtime-handoff"
[[ -n "$fixture_dir" ]] || fixture_dir=$default_fixture
tasks_file=$(printenv SDD_CROSS_RUNTIME_TASKS_PATH 2>/dev/null || true)
[[ -n "$tasks_file" ]] || tasks_file="$repo_root/specs/epic-196-a8-integration/tasks.md"
main_ref=$(printenv SDD_CROSS_RUNTIME_MAIN_REF 2>/dev/null || true)
[[ -n "$main_ref" ]] || main_ref=origin/main
allowlist="$repo_root/plugins/sdd-review-loop/references/a8-skip-allowlist.json"
tmp_root=$(printenv TMPDIR 2>/dev/null || true)
[[ -n "$tmp_root" ]] || tmp_root=/tmp
evidence_dir=$(mktemp -d "$tmp_root/sdd-a8-handoff.XXXXXX")
evidence_dir=$(cd "$evidence_dir" && pwd -P)

fail() {
  printf 'cross-runtime-handoff: %s\n' "$1" >&2
  printf 'Evidence preserved: %s\n' "$evidence_dir" >&2
  exit 1
}
sha256_file() {
  python3 - "$1" <<'PY'
import hashlib, pathlib, sys
print(hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest())
PY
}
new_nonce() { od -An -N16 -tx1 /dev/urandom | tr -d ' \n'; }
task_status() {
  awk '
    /^## T-005 / { in_task=1; next }
    in_task && /^## T-/ { exit }
    in_task && /^Status: / { sub(/^Status: /, ""); print; found=1; exit }
    END { if (!found) exit 1 }
  ' "$1"
}
handshake_exists_on_main() {
  local path
  for path in \
    plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py \
    plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.sh \
    plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.ps1; do
    git ls-tree -r "$main_ref" -- "$path" | awk -v p="$path" '$NF == p { found=1 } END { exit !found }' || return 1
  done
}
canary_activated() {
  case "$1" in
    'In Progress'|'Implementation Complete'|Done) handshake_exists_on_main ;;
    Planned|Draft|Blocked) return 1 ;;
    *) return 2 ;;
  esac
}
self_test_activation() {
  local dir status expected actual rc
  dir=$(mktemp -d "$tmp_root/sdd-a8-gate.XXXXXX")
  dir=$(cd "$dir" && pwd -P)
  for status in Planned Draft Blocked 'In Progress' 'Implementation Complete' Done; do
    case "$status" in Planned|Draft|Blocked) expected=0 ;; *) expected=1 ;; esac
    awk -v s="$status" '
      /^## T-005 / { print; in_task=1; next }
      in_task && /^Status: / { print "Status: " s; replaced=1; next }
      in_task && /^## T-/ { in_task=0 }
      { print }
      END { if (!replaced) exit 3 }
    ' "$tasks_file" > "$dir/tasks.next"
    mv "$dir/tasks.next" "$dir/tasks.md"
    actual_status=$(task_status "$dir/tasks.md") || fail "could not read test fixture status"
    actual=0
    if canary_activated "$actual_status"; then actual=1; else rc=$?; [[ $rc -eq 1 ]] || fail "activation predicate errored for '$status'"; fi
    [[ $actual -eq $expected ]] || fail "activation predicate mismatch for '$status'"
  done
  rm -r "$dir"
  printf 'ok: AC-006 activation gate evaluated all six lifecycle values using disposable tasks.md copies; main handshake paths are present\n'
}

self_test_contract() {
  python3 - "$fixture_dir" "$allowlist" <<'PY' || fail "fixture contract self-test failed"
import hashlib, json, pathlib, secrets, shutil, tempfile

fixture_dir, allowlist_path = map(pathlib.Path, __import__('sys').argv[1:])
expected1 = b'token: "<PLACEHOLDER>"\n'
expected2 = b'<!-- nonce: PLACEHOLDER -->\n'
source1 = fixture_dir / 'handoff-01-claude-to-codex.yaml'
source2 = fixture_dir / 'handoff-02-codex-to-copilot.md'
assert source1.read_bytes() == expected1, 'handoff-01 initial bytes differ from contract'
assert source2.read_bytes() == expected2, 'handoff-02 initial bytes differ from contract'
allow = json.loads(allowlist_path.read_text(encoding='utf-8'))
assert allow['schema'] == 'a8-skip-allowlist/v1'
entries = {entry['case_id']: entry for entry in allow['entries']}
assert {'AC-006', 'AC-015', 'AC-016'} <= set(entries)
assert '#189' in entries['AC-006']['reason'] and '#187' in entries['AC-006']['reason']
assert len(entries['AC-006']['upstream_epic_a1_path_blob_ids']) == 3

with tempfile.TemporaryDirectory(prefix='sdd-a8-pseudo-cli-') as raw:
    root = pathlib.Path(raw).resolve()
    one, two = root / source1.name, root / source2.name
    shutil.copyfile(source1, one); shutil.copyfile(source2, two)
    nonce1, nonce2 = secrets.token_hex(16), secrets.token_hex(16)
    assert nonce1 != nonce2
    before1, before2 = hashlib.sha256(one.read_bytes()).hexdigest(), hashlib.sha256(two.read_bytes()).hexdigest()
    one.write_bytes(one.read_bytes().replace(b'<PLACEHOLDER>', nonce1.encode()))
    assert one.read_bytes() == f'token: "{nonce1}"\n'.encode()
    pseudo_codex_stdout = f'HANDOFF-01:{one.read_text().split(chr(34))[1]}'
    assert f'HANDOFF-01:{nonce1}' in pseudo_codex_stdout
    two.write_bytes(two.read_bytes().replace(b'PLACEHOLDER', nonce2.encode()))
    assert two.read_bytes() == f'<!-- nonce: {nonce2} -->\n'.encode()
    pseudo_copilot_output = f'COPILOT-CONSUMED:{nonce2}'.encode()
    expected_output_hash = hashlib.sha256(pseudo_copilot_output).hexdigest()
    output = root / 'handoff-02-output.txt'; output.write_bytes(pseudo_copilot_output)
    assert hashlib.sha256(output.read_bytes()).hexdigest() == expected_output_hash
    assert before1 == hashlib.sha256(expected1).hexdigest()
    assert before2 == hashlib.sha256(expected2).hexdigest()
print('ok: pseudo-CLI contract exercised fixture mutation, stdout marker, generated-file hash, and independent nonces')
PY
}

if ((self_test)); then
  self_test_activation
  exit 0
fi

[[ -f "$fixture_dir/handoff-01-claude-to-codex.yaml" ]] || fail "missing handoff-01 fixture"
[[ -f "$fixture_dir/handoff-02-codex-to-copilot.md" ]] || fail "missing handoff-02 fixture"
[[ -f "$allowlist" ]] || fail "missing AC-006 allowlist"
python3 - "$allowlist" <<'PY' || fail "invalid AC-006 allowlist"
import json, sys
data=json.load(open(sys.argv[1], encoding="utf-8"))
entries={entry.get("case_id"): entry for entry in data.get("entries", [])}
assert data.get("schema")=="a8-skip-allowlist/v1"
assert {"AC-006", "AC-015", "AC-016"} <= set(entries)
assert "#189" in entries["AC-006"].get("reason","") and "#187" in entries["AC-006"].get("reason","")
assert len(entries["AC-006"].get("upstream_epic_a1_path_blob_ids",{}))==3
PY

if ((!live_e2e)); then
  self_test_contract
  self_test_activation
  printf 'Live CLI E2E not run; set --live-e2e and SDD_A8_ALLOW_LIVE_CLI=1 for explicit authenticated sessions.\n'
  exit 0
fi
[[ "${SDD_A8_ALLOW_LIVE_CLI:-}" == 1 ]] || fail "--live-e2e requires explicit SDD_A8_ALLOW_LIVE_CLI=1"

tmp="$evidence_dir/work"
mkdir -p "$tmp/tests/fixtures/cross-runtime-handoff"
cp "$fixture_dir/handoff-01-claude-to-codex.yaml" "$tmp/tests/fixtures/cross-runtime-handoff/"
cp "$fixture_dir/handoff-02-codex-to-copilot.md" "$tmp/tests/fixtures/cross-runtime-handoff/"

nonce1=$(new_nonce)
nonce2=$(new_nonce)
while [[ "$nonce1" == "$nonce2" ]]; do nonce2=$(new_nonce); done
fixture01="$tmp/tests/fixtures/cross-runtime-handoff/handoff-01-claude-to-codex.yaml"
fixture02="$tmp/tests/fixtures/cross-runtime-handoff/handoff-02-codex-to-copilot.md"
initial01_sha=$(sha256_file "$fixture01")
initial02_sha=$(sha256_file "$fixture02")
expected01_sha=$(python3 - "$fixture_dir/handoff-01-claude-to-codex.yaml" "$nonce1" <<'PY'
import hashlib, pathlib, sys
data=pathlib.Path(sys.argv[1]).read_bytes().replace(b"<PLACEHOLDER>",sys.argv[2].encode())
print(hashlib.sha256(data).hexdigest())
PY
)
expected02_sha=$(python3 - "$fixture_dir/handoff-02-codex-to-copilot.md" "$nonce2" <<'PY'
import hashlib, pathlib, sys
data=pathlib.Path(sys.argv[1]).read_bytes().replace(b"PLACEHOLDER",sys.argv[2].encode())
print(hashlib.sha256(data).hexdigest())
PY
)

require_cli() { command -v "$1" >/dev/null 2>&1 || fail "required headless CLI unavailable: $1"; }
require_cli claude
require_cli codex
require_cli copilot

prompt="In the current isolated temporary workspace, edit only tests/fixtures/cross-runtime-handoff/handoff-01-claude-to-codex.yaml. Replace the exact YAML value <PLACEHOLDER> with $nonce1, preserving all other bytes. Do not inspect or modify anything else. Do not run shell commands. End with a short confirmation."
(cd "$tmp" && claude --print --output-format text --permission-mode acceptEdits --permission-prompts none --allowedTools Read,Edit -- "$prompt") > "$evidence_dir/claude-producer.log" 2>&1 || fail "Claude producer invocation failed"
actual01_sha=$(sha256_file "$fixture01")
[[ "$actual01_sha" == "$expected01_sha" ]] || fail "Claude-produced handoff-01 bytes/hash mismatch"

prompt="Read and parse tests/fixtures/cross-runtime-handoff/handoff-01-claude-to-codex.yaml in this isolated workspace. Extract its token field and emit exactly the marker HANDOFF-01:<token> in your final response. Do not modify files or run shell commands."
codex_first_output="$evidence_dir/codex-consumer.log"
codex exec --ephemeral --skip-git-repo-check --sandbox read-only --ask-for-approval never --cd "$tmp" "$prompt" > "$codex_first_output" 2>&1 || fail "Codex consumer invocation failed"
grep -Fq "HANDOFF-01:$nonce1" "$codex_first_output" || fail "Codex consumer output did not contain the exact handoff marker"

prompt="Read and parse tests/fixtures/cross-runtime-handoff/handoff-01-claude-to-codex.yaml and verify its token is $nonce1. Then edit only tests/fixtures/cross-runtime-handoff/handoff-02-codex-to-copilot.md, replacing the exact PLACEHOLDER in its HTML comment with $nonce2, preserving all other bytes. Do not run shell commands and do not modify any other file. End with the exact marker CODEX-PRODUCED:$nonce2."
codex exec --ephemeral --skip-git-repo-check --sandbox workspace-write --ask-for-approval never --cd "$tmp" "$prompt" > "$evidence_dir/codex-producer.log" 2>&1 || fail "Codex producer invocation failed"
grep -Fq "CODEX-PRODUCED:$nonce2" "$evidence_dir/codex-producer.log" || fail "Codex producer did not attest its nonce"
actual02_sha=$(sha256_file "$fixture02")
[[ "$actual02_sha" == "$expected02_sha" ]] || fail "Codex-produced handoff-02 bytes/hash mismatch"

prompt="Read tests/fixtures/cross-runtime-handoff/handoff-02-codex-to-copilot.md, extract the nonce in the HTML comment, and create only tests/fixtures/cross-runtime-handoff/handoff-02-output.txt with the exact bytes COPILOT-CONSUMED:<nonce> (no trailing newline). Do not run shell commands or access the network."
copilot -p "$prompt" -C "$tmp" --disable-builtin-mcps --available-tools='read,write' --allow-tool='read,write' > "$evidence_dir/copilot-consumer.log" 2>&1 || fail "Copilot consumer invocation failed"
output_file="$tmp/tests/fixtures/cross-runtime-handoff/handoff-02-output.txt"
[[ -f "$output_file" ]] || fail "Copilot did not produce handoff-02-output.txt"
expected_output_sha=$(printf 'COPILOT-CONSUMED:%s' "$nonce2" | python3 -c 'import hashlib,sys; print(hashlib.sha256(sys.stdin.buffer.read()).hexdigest())')
actual_output_sha=$(sha256_file "$output_file")
[[ "$actual_output_sha" == "$expected_output_sha" ]] || fail "Copilot-generated file hash mismatch"

status=$(task_status "$tasks_file") || fail "could not read T-005 lifecycle status"
if canary_activated "$status"; then
  canary_result=FAIL
  coverage_complete=false
  top_result=FAIL
  skip_reason="T-005 status '$status' and Epic A1 handshake files on main activate AC-006; live-host proof remains owned by T-005 (#189/#187)."
  exit_code=1
else
  rc=$?
  [[ $rc -eq 1 ]] || fail "failed closed while evaluating AC-006 activation gate"
  canary_result=SKIP
  coverage_complete=false
  top_result=PASS
  skip_reason="AC-006 presence-only in T-001; live-host handshake remains tracked by #189/#187 and T-005 is not started (status: $status)."
  exit_code=0
fi

python3 - "$initial01_sha" "$actual01_sha" "$nonce1" "$initial02_sha" "$actual02_sha" "$nonce2" "$codex_first_output" "$evidence_dir/claude-producer.log" "$evidence_dir/codex-producer.log" "$evidence_dir/copilot-consumer.log" "$expected_output_sha" "$canary_result" "$coverage_complete" "$top_result" "$skip_reason" "$evidence_dir/trace.json" <<'PY'
import json, sys
(initial1, final1, nonce1, initial2, final2, nonce2, log_codex_consumer,
 log_claude, log_codex_producer, log_copilot, output_sha, canary_result,
 coverage, result, skip_reason, out)=sys.argv[1:]
trace={
  "schema":"cross-runtime-handoff-trace/v1",
  "fixture_id":"cross-runtime-handoff",
  "result":result,
  "coverage_complete":coverage=="true",
  "skip_allowlist_version":"a8-skip-allowlist/v1",
  "upstream_commit":None,
  "headless_contracts":[
    {"runtime":"claude","status":"confirmed","invocation":"claude --print","evidence":"https://docs.anthropic.com/en/docs/claude-code/cli-usage"},
    {"runtime":"codex","status":"confirmed","invocation":"codex exec","evidence":"https://github.com/openai/codex/blob/main/codex-rs/exec/src/cli.rs"},
    {"runtime":"copilot","status":"confirmed","invocation":"copilot -p","evidence":"https://docs.github.com/en/copilot/how-tos/copilot-cli/automate-copilot-cli/run-cli-programmatically"}
  ],
  "steps":[
    {"producer_runtime":"claude","consumer_runtime":"codex","artifact_path":"tests/fixtures/cross-runtime-handoff/handoff-01-claude-to-codex.yaml","artifact_initial_sha256":"sha256:"+initial1,"artifact_final_sha256":"sha256:"+final1,"mutation_nonce":nonce1,"consumer_observable":{"kind":"stdout_substring","expected":"HANDOFF-01:"+nonce1},"invocation_mode":"automated","result":"PASS","evidence_refs":[log_claude,log_codex_consumer]},
    {"producer_runtime":"codex","consumer_runtime":"copilot","artifact_path":"tests/fixtures/cross-runtime-handoff/handoff-02-codex-to-copilot.md","artifact_initial_sha256":"sha256:"+initial2,"artifact_final_sha256":"sha256:"+final2,"mutation_nonce":nonce2,"consumer_observable":{"kind":"generated_file_hash","expected":"sha256:"+output_sha},"invocation_mode":"automated","result":"PASS","evidence_refs":[log_codex_producer,log_copilot]}
  ],
  "canary_case":{"present":True,"result":canary_result,"skip_reason":skip_reason}
}
with open(out,"w",encoding="utf-8",newline="\n") as f: json.dump(trace,f,ensure_ascii=False,indent=2); f.write("\n")
PY

if [[ -n "$trace_file" ]]; then
  cp "$evidence_dir/trace.json" "$trace_file"
  cat "$trace_file"
else
  cat "$evidence_dir/trace.json"
fi
printf 'Evidence directory: %s\n' "$evidence_dir" >&2
exit "$exit_code"
