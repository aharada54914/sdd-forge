#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TASK_SH="$ROOT/plugins/sdd-quality-loop/scripts/check-task-state.sh.candidate"
EVID_SH="$ROOT/plugins/sdd-quality-loop/scripts/check-evidence-bundle.sh.candidate"
WORK=$(mktemp -d)
TASK_PS="$WORK/check-task-state.candidate.ps1"
cp "$ROOT/plugins/sdd-quality-loop/scripts/check-task-state.ps1.candidate" "$TASK_PS"
mkdir -p "$WORK/plugins/sdd-quality-loop/scripts"
cp "$ROOT/plugins/sdd-quality-loop/scripts/check-contract.ps1" "$WORK/plugins/sdd-quality-loop/scripts/check-contract.ps1"
cp "$ROOT/plugins/sdd-quality-loop/scripts/check-contract.py" "$WORK/plugins/sdd-quality-loop/scripts/check-contract.py"
EVID_PS="$WORK/plugins/sdd-quality-loop/scripts/check-evidence-bundle.candidate.ps1"
cp "$ROOT/plugins/sdd-quality-loop/scripts/check-evidence-bundle.ps1.candidate" "$EVID_PS"
trap 'rm -rf "$WORK"' EXIT

pass=0
fail=0
ok() { pass=$((pass + 1)); printf 'ok: %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf 'not ok: %s\n' "$1" >&2; }

# Static parity contract: both runtimes recognize the same sigstore truthy set.
for value in '1' 'true' 'yes' 'on'; do
  grep -Fq "\"$value\"" "$EVID_SH" || bad "sh recognizes $value"
done
grep -Fq 'not in {"1", "true", "yes", "on"}' "$EVID_SH" && ok 'sh rejects unrecognized sigstore values' || bad 'sh truthy gate missing'
grep -Fq '@("1", "true", "yes", "on")' "$ROOT/plugins/sdd-quality-loop/scripts/check-evidence-bundle.ps1.candidate" && ok 'ps1 recognizes the same sigstore truthy set' || bad 'ps1 truthy gate missing'

# Runtime parity fixture: both validators reject 0/false/arbitrary markers and
# accept the same recognized truthy marker.
BUNDLE_REPO="$WORK/bundle-repo"
mkdir -p "$BUNDLE_REPO/specs/demo/verification" "$BUNDLE_REPO/reports/quality-gate"
git -C "$BUNDLE_REPO" init -q
git -C "$BUNDLE_REPO" config user.email fixture@example.invalid
git -C "$BUNDLE_REPO" config user.name fixture
cat > "$BUNDLE_REPO/specs/demo/verification/ev.log" <<'EOF'
fixture evidence
EOF
cat > "$BUNDLE_REPO/reports/quality-gate/report.md" <<'EOF'
Task ID: T-001
Feature: demo
Run ID: fixture-run
VERDICT: PASS
Critical: 0
Major: 0
Minor: 0
EOF
cat > "$BUNDLE_REPO/specs/demo/verification/T-001.contract.json" <<'EOF'
{
  "task_id": "T-001",
  "feature": "demo",
  "risk": "critical",
  "required_workflow": "tdd",
  "checks": [
    {"id":"lint","required":true,"passes":true,"evidence":"specs/demo/verification/ev.log"},
    {"id":"typecheck","required":true,"passes":true,"evidence":"specs/demo/verification/ev.log"},
    {"id":"unit-tests","required":true,"passes":true,"evidence":"specs/demo/verification/ev.log","red_evidence":"specs/demo/verification/ev.log","green_evidence":"specs/demo/verification/ev.log"},
    {"id":"build","required":true,"passes":true,"evidence":"specs/demo/verification/ev.log"},
    {"id":"placeholder-scan","required":true,"passes":true,"evidence":"specs/demo/verification/ev.log"},
    {"id":"task-state-check","required":true,"passes":true,"evidence":"specs/demo/verification/ev.log"},
    {"id":"acceptance-tests","required":true,"passes":true,"evidence":"specs/demo/verification/ev.log","red_evidence":"specs/demo/verification/ev.log","green_evidence":"specs/demo/verification/ev.log"},
    {"id":"regression","required":true,"passes":true,"evidence":"specs/demo/verification/ev.log"},
    {"id":"requirement-traceability","required":true,"passes":true,"evidence":"specs/demo/verification/ev.log"}
  ]
}
EOF
git -C "$BUNDLE_REPO" add specs reports
git -C "$BUNDLE_REPO" commit -q -m fixture
python3 - "$BUNDLE_REPO" <<'PY'
import hashlib, json, pathlib, subprocess, sys
repo = pathlib.Path(sys.argv[1])
def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
contract = repo / 'specs/demo/verification/T-001.contract.json'
report = repo / 'reports/quality-gate/report.md'
evidence = repo / 'specs/demo/verification/ev.log'
bundle = {
    'task_id': 'T-001', 'feature': 'demo', 'risk': 'critical',
    'required_workflow': 'tdd', 'spec_revision': '0' * 64,
    'git_commit': subprocess.check_output(['git', '-C', str(repo), 'rev-parse', 'HEAD'], text=True).strip(),
    'git_generated_dirty': False,
    'review_verdict': {'verdict': 'PASS'}, 'build_env': {'os': 'fixture'},
    'quality_report': 'reports/quality-gate/report.md',
    'verification_contract': 'specs/demo/verification/T-001.contract.json',
    'artifacts': [{'path': str(path.relative_to(repo)), 'sha256': digest(path)} for path in (report, contract, evidence)],
    'signature': {'alg': 'sigstore', 'value': 'fixture', 'key_ref': 'sigstore'},
}
(repo / 'specs/demo/verification/T-001.evidence.json').write_text(json.dumps(bundle, indent=2) + '\n', encoding='utf-8')
PY
run_sigstore_case() {
  runtime=$1
  value=$2
  expected=$3
  if [ "$runtime" = sh ]; then
    if SDD_EVIDENCE_SIGSTORE_VERIFIED="$value" sh "$EVID_SH" "$BUNDLE_REPO/specs/demo/verification/T-001.evidence.json" "$BUNDLE_REPO" >/tmp/pr403-evidence.out 2>&1; then rc=0; else rc=$?; fi
  else
    if SDD_EVIDENCE_SIGSTORE_VERIFIED="$value" pwsh -NoProfile -File "$EVID_PS" -BundlePath "$BUNDLE_REPO/specs/demo/verification/T-001.evidence.json" -RepoRoot "$BUNDLE_REPO" >/tmp/pr403-evidence.out 2>&1; then rc=0; else rc=$?; fi
  fi
  if [ "$rc" -eq "$expected" ]; then ok "$runtime sigstore=$value runtime result"; else bad "$runtime sigstore=$value unexpected result"; cat /tmp/pr403-evidence.out >&2; fi
}
for runtime in sh ps1; do
  run_sigstore_case "$runtime" 0 1
  run_sigstore_case "$runtime" false 1
  run_sigstore_case "$runtime" arbitrary 1
  run_sigstore_case "$runtime" true 0
done

# Unsupported algorithm and valid-format mutation of a signed field fail
# closed identically in both validators.
export SDD_EVIDENCE_KEY='fixture signing key'
python3 - "$BUNDLE_REPO/specs/demo/verification/T-001.evidence.json" <<'PY'
import hashlib, hmac, json, pathlib, sys
p = pathlib.Path(sys.argv[1]); b = json.loads(p.read_text())
pairs = sorted(str(a.get('path','')).strip() + '\0' + str(a.get('sha256','')).strip().lower() for a in b['artifacts'])
artifact_digest = hashlib.sha256('\n'.join(pairs).encode()).hexdigest()
fields = ['sdd-evidence-v1', b['task_id'].strip(), b['feature'].strip(), b['risk'].strip(),
          b['required_workflow'].strip(), b['spec_revision'].strip(), b['git_commit'].strip(),
          'false', b['review_verdict']['verdict'].strip(), artifact_digest]
b['signature'] = {'alg':'hmac-sha256', 'value':hmac.new(b'fixture signing key', '\n'.join(fields).encode(), hashlib.sha256).hexdigest()}
p.write_text(json.dumps(b, indent=2) + '\n')
PY
run_hmac_case() {
  runtime=$1
  if [ "$runtime" = sh ]; then
    if sh "$EVID_SH" "$BUNDLE_REPO/specs/demo/verification/T-001.evidence.json" "$BUNDLE_REPO" >/dev/null 2>&1; then rc=0; else rc=$?; fi
  else
    if pwsh -NoProfile -File "$EVID_PS" -BundlePath "$BUNDLE_REPO/specs/demo/verification/T-001.evidence.json" -RepoRoot "$BUNDLE_REPO" >/dev/null 2>&1; then rc=0; else rc=$?; fi
  fi
  [ "$rc" -eq "$2" ] && ok "$runtime $3" || bad "$runtime $3 (exit $rc)"
}
run_hmac_case sh 0 'verifies Python-produced HMAC signature'
run_hmac_case ps1 0 'verifies Python-produced HMAC signature'

cat > "$WORK/sign-with-powershell.ps1" <<'PWSH'
param([string]$Candidate, [string]$BundlePath)
$tokens = $null; $errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($Candidate, [ref]$tokens, [ref]$errors)
$fn = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Get-EvidenceCanonical' }, $true)
if ($null -eq $fn -or $errors.Count) { throw 'candidate canonicalizer not found' }
. ([scriptblock]::Create($fn.Extent.Text))
$bundle = Get-Content -Raw -Encoding Utf8 $BundlePath | ConvertFrom-Json
$canonical = Get-EvidenceCanonical -Bundle $bundle
$key = [System.Text.Encoding]::UTF8.GetBytes('fixture signing key')
$hmac = [System.Security.Cryptography.HMACSHA256]::new($key)
$bytes = $hmac.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($canonical))
$bundle.signature = @{ alg = 'hmac-sha256'; value = (($bytes | ForEach-Object { '{0:x2}' -f $_ }) -join '') }
$bundle | ConvertTo-Json -Depth 30 | Set-Content -Encoding Utf8 $BundlePath
PWSH
if pwsh -NoProfile -File "$WORK/sign-with-powershell.ps1" "$EVID_PS" "$BUNDLE_REPO/specs/demo/verification/T-001.evidence.json" >/dev/null 2>&1; then
run_hmac_case sh 0 'accepts PowerShell-canonicalized HMAC signature'
else
  bad 'PowerShell candidate canonicalizer could not sign fixture'
fi

# Adversarial canonical-order parity: Python code-point order and .NET UTF-16
# ordinal order disagree for U+E000 vs U+10000. Also exercise non-boolean
# dirty data so both canonicalizers produce the same false representation.
python3 - "$BUNDLE_REPO/specs/demo/verification/T-001.evidence.json" "$BUNDLE_REPO" <<'PY'
import hashlib, hmac, json, pathlib, sys
p = pathlib.Path(sys.argv[1]); root = pathlib.Path(sys.argv[2]); b = json.loads(p.read_text())
for name in ('\ue000.log', '\U00010000.log'):
    artifact = root / 'specs/demo/verification' / name
    artifact.write_text('unicode ordering fixture\n', encoding='utf-8')
    b['artifacts'].append({'path': artifact.relative_to(root).as_posix(), 'sha256': hashlib.sha256(artifact.read_bytes()).hexdigest()})
b['git_generated_dirty'] = 'false'
pairs = sorted((str(a['path']).strip() + '\0' + str(a['sha256']).strip().lower() for a in b['artifacts']), key=lambda item: item.encode('utf-8'))
artifact_digest = hashlib.sha256('\n'.join(pairs).encode()).hexdigest()
fields = ['sdd-evidence-v1', b['task_id'].strip(), b['feature'].strip(), b['risk'].strip(), b['required_workflow'].strip(), b['spec_revision'].strip(), b['git_commit'].strip(), 'false', b['review_verdict']['verdict'].strip(), artifact_digest]
b['signature'] = {'alg':'hmac-sha256', 'value':hmac.new(b'fixture signing key', '\n'.join(fields).encode(), hashlib.sha256).hexdigest()}
p.write_text(json.dumps(b, ensure_ascii=False, indent=2) + '\n')
PY
run_hmac_case sh 0 'matches Python canonical order for supplementary Unicode and string dirty value'
run_hmac_case ps1 0 'matches Python canonical order for supplementary Unicode and string dirty value'

python3 - "$BUNDLE_REPO/specs/demo/verification/T-001.evidence.json" <<'PY'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1]); b = json.loads(p.read_text())
b['signature']['alg'] = 'sha1'
p.write_text(json.dumps(b, indent=2) + '\n')
PY
run_hmac_case sh 1 'rejects unsupported signature algorithm'
run_hmac_case ps1 1 'rejects unsupported signature algorithm'
python3 - "$BUNDLE_REPO/specs/demo/verification/T-001.evidence.json" <<'PY'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1]); b = json.loads(p.read_text())
b['signature']['alg'] = 'hmac-sha256'; b['spec_revision'] = '1' * 64
p.write_text(json.dumps(b, indent=2) + '\n')
PY
run_hmac_case sh 1 'rejects tampered signed spec_revision'
run_hmac_case ps1 1 'rejects tampered signed spec_revision'
python3 - "$BUNDLE_REPO/specs/demo/verification/T-001.evidence.json" "$BUNDLE_REPO" <<'PY'
import hashlib, json, pathlib, sys
p = pathlib.Path(sys.argv[1]); root = pathlib.Path(sys.argv[2]); b = json.loads(p.read_text())
extra = root / 'specs/demo/verification/added-after-signing.log'
extra.write_text('valid but unsigned artifact-set mutation\n', encoding='utf-8')
b['spec_revision'] = '0' * 64
b['artifacts'].append({'path': extra.relative_to(root).as_posix(), 'sha256': hashlib.sha256(extra.read_bytes()).hexdigest()})
p.write_text(json.dumps(b, ensure_ascii=False, indent=2) + '\n')
PY
run_hmac_case sh 1 'rejects independently mutated signed artifact digest'
run_hmac_case ps1 1 'rejects independently mutated signed artifact digest'

# The task-state regression fixtures cover critical distinct-approver success,
# noncritical omission, and case-sensitive PowerShell field recognition.
grep -Fq "\$line -cmatch '^Second Approval:" "$ROOT/plugins/sdd-quality-loop/scripts/check-task-state.ps1.candidate" \
  && ok 'PowerShell candidate parses Second Approval case-sensitively' \
  || bad 'PowerShell candidate Second Approval label must use -cmatch'
run_approval_case() {
  runtime=$1; tier=$2; second_line=$3; expected_marker=$4; absent_marker=$5
  case_dir="$WORK/approval-$runtime-$tier-${expected_marker:-pass}"
  mkdir -p "$case_dir/specs/demo/verification" "$case_dir/reports/quality-gate" "$case_dir/reports/implementation"
  cat > "$case_dir/specs/demo/tasks.md" <<EOF
# Tasks
## T-001
Approval: Approved (alice 2026-06-13T10:00:00Z)
Status: Done
Risk: $tier
$second_line
EOF
  printf '{"task_id":"T-001","risk":"%s"}\n' "$tier" > "$case_dir/specs/demo/verification/T-001.contract.json"
  if [ "$runtime" = sh ]; then
    if output=$(sh "$TASK_SH" "$case_dir/specs/demo/tasks.md" "$case_dir/reports/quality-gate" "$case_dir/reports/implementation" "$case_dir" 2>&1); then rc=0; else rc=$?; fi
  else
    if output=$(pwsh -NoProfile -File "$TASK_PS" -TasksPath "$case_dir/specs/demo/tasks.md" -ReportsDir "$case_dir/reports/quality-gate" -ImplReportsDir "$case_dir/reports/implementation" -RepoRoot "$case_dir" 2>&1); then rc=0; else rc=$?; fi
  fi
  if [ -n "$expected_marker" ]; then
    printf '%s\n' "$output" | grep -Fq "$expected_marker" && ok "$runtime $tier approval case rejects expected condition" || bad "$runtime $tier missing diagnostic: $expected_marker"
  else
    if ! printf '%s\n' "$output" | grep -Fq "$absent_marker"; then ok "$runtime $tier approval case does not enforce second approver"; else bad "$runtime $tier unexpectedly enforced second approver"; fi
  fi
}
for runtime in sh ps1; do
  run_approval_case "$runtime" critical '' 'Second Approval is missing' ''
  run_approval_case "$runtime" critical 'Second Approval: Approved (bob 2026-06-13T11:00:00Z)' '' 'Second Approval'
  run_approval_case "$runtime" high '' '' 'Second Approval'
done
run_approval_case ps1 critical 'second approval: Approved (bob 2026-06-13T11:00:00Z)' 'Second Approval is missing' ''

# Dynamic fail-closed regression: a critical contract cannot be downgraded by
# a lower tasks.md risk; the candidate must report the mismatch and critical
# approval requirement.
mkdir -p "$WORK/specs/demo/verification" "$WORK/reports/implementation"
cat > "$WORK/specs/demo/tasks.md" <<'EOF'
# Tasks
## T-001
Approval: Approved
Status: Done
Risk: low
Second Approval: Approved (reviewer 2026-01-01T00:00:00Z)
EOF
cat > "$WORK/specs/demo/verification/T-001.contract.json" <<'EOF'
{"task_id":"T-001","risk":"critical"}
EOF
if output=$(sh "$TASK_SH" "$WORK/specs/demo/tasks.md" "$WORK/reports/quality-gate" "$WORK/reports/implementation" "$WORK" 2>&1); then
  bad 'tasks.md/contract risk mismatch unexpectedly passed'
else
  printf '%s\n' "$output"
  printf '%s\n' "$output" | grep -Fq "tasks.md risk 'low' != contract risk 'critical'" && ok 'risk mismatch fails closed' || bad 'risk mismatch diagnostic missing'
  printf '%s\n' "$output" | grep -Fq 'critical Done' && ok 'critical approval uses contract risk' || bad 'contract risk was not used for approval tier'
fi
if output=$(pwsh -NoProfile -File "$TASK_PS" -TasksPath "$WORK/specs/demo/tasks.md" -ReportsDir "$WORK/reports/quality-gate" -ImplReportsDir "$WORK/reports/implementation" -RepoRoot "$WORK" 2>&1); then
  bad 'ps1 tasks.md/contract risk mismatch unexpectedly passed'
else
  printf '%s\n' "$output" | grep -Fq "tasks.md risk 'low' != contract risk 'critical'" && ok 'ps1 risk mismatch fails closed' || bad 'ps1 risk mismatch diagnostic missing'
  printf '%s\n' "$output" | grep -Fq 'critical Done' && ok 'ps1 critical approval uses contract risk' || bad 'ps1 contract risk was not used for approval tier'
fi

[ "$fail" -eq 0 ] || exit 1
printf 'candidate regression passed (%d checks)\n' "$pass"
