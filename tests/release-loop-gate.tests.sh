#!/usr/bin/env bash
# tests/release-loop-gate.tests.sh — text-marker lock for the
# .github/workflows/release.yml required loop-gate job (T-002 / Issue #148 /
# epic-159-pillar-b REQ-002).
#
#   TEST-007 (AC-007) — the new `loop-gate:` job's slice of the workflow
#     text contains both the `tests/loop-consistency.tests.sh` and
#     `tests/loop-inventory.tests.sh` invocation strings.
#   TEST-008 (AC-008) — the build job's (`release:`) slice contains a
#     `needs: loop-gate` (or equivalent list form) entry, and neither that
#     slice nor the `loop-gate:` job's slice contains `continue-on-error:
#     true` or `if: always()`/`if: success() || failure()` (weakened-gate
#     negative scan).
#   TEST-009 (AC-009) — negative-branch canary: a mktemp fixture copy of
#     release.yml with the `needs:` line textually stripped is re-checked by
#     the SAME marker-check function used for TEST-007/TEST-008/TEST-010;
#     asserts the function now reports non-compliance, proving TEST-008's
#     assertion is not vacuously true.
#   TEST-010 (AC-010) — the `loop-gate:` job's slice contains `runs-on:
#     ubuntu-latest` and no `strategy:`/`matrix:` key (single-OS, matching
#     release.yml's existing scope); this suite self-registers in
#     tests/run-all.sh/.ps1 and .github/workflows/test.yml.
#
# Technique: text-marker structural checks over the real release.yml,
# following tests/workflow-state-ci-integration.tests.sh's established
# python3-heredoc precedent (design.md API/Contract Plan) rather than adding
# a YAML-parsing library dependency. The marker-check logic is written once
# to a scratch python3 script and invoked against BOTH the real file
# (TEST-007/TEST-008/TEST-010) and, separately, a mutated mktemp copy
# (TEST-009) — the same function, two inputs, proving the check is not
# vacuous. This suite never writes a real repository path; release.yml is
# read only.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
RELEASE_YML="${ROOT}/.github/workflows/release.yml"
RUN_ALL_SH="${ROOT}/tests/run-all.sh"
TEST_YML="${ROOT}/.github/workflows/test.yml"

PASS=0
FAIL=0
ok()   { PASS=$((PASS + 1)); printf 'ok: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; }

CLEANUP_ROOTS=()
cleanup() {
  local d
  for d in "${CLEANUP_ROOTS[@]:-}"; do
    [[ -n "$d" && -d "$d" ]] && rm -rf "$d"
  done
}
trap cleanup EXIT

# The marker-check python3 script is written once to a scratch file (never a
# real repository path) and reused by every case below via
# check_release_yml(). Scoping the job-key search to lines AFTER the
# top-level `jobs:` key (rather than the whole file) is deliberate: this
# workflow's `on:` trigger section itself contains a 2-space-indented
# `release:` key (`release.yml:10-13`'s `on: release: types: [published]`)
# that would otherwise be misidentified as a job boundary.
#
# NOTE: the mktemp template below ends in a bare XXXXXX (no literal suffix
# after it) deliberately -- BSD/macOS mktemp (unlike GNU mktemp) only
# substitutes a trailing run of X's when it is the LAST thing in the
# template; a template like "name.XXXXXX.py" is returned byte-for-byte
# un-randomized on BSD mktemp, so every run after the first collides with
# "File exists". A mktemp -d directory (bare XXXXXX suffix) holding a
# fixed-name file inside it is the portable pattern.
CHECKER_DIR="$(mktemp -d "${TMPDIR:-/tmp}/release-loop-gate-checker.XXXXXX")"
CHECKER_DIR="$(cd "$CHECKER_DIR" && pwd -P)"
CLEANUP_ROOTS+=("$CHECKER_DIR")
CHECKER_PY="${CHECKER_DIR}/checker.py"
cat > "$CHECKER_PY" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
lines = text.split("\n")

JOBS_KEY_RE = re.compile(r"^jobs:\s*$")
JOB_KEY_RE = re.compile(r"^  [A-Za-z0-9_-]+:\s*$")

jobs_start = None
for i, line in enumerate(lines):
    if JOBS_KEY_RE.match(line):
        jobs_start = i
        break

if jobs_start is None:
    job_starts = []
else:
    job_starts = [
        i for i in range(jobs_start + 1, len(lines)) if JOB_KEY_RE.match(lines[i])
    ]


def job_slice(name):
    marker = f"  {name}:"
    start = None
    for i in job_starts:
        if lines[i].rstrip() == marker:
            start = i
            break
    if start is None:
        return ""
    end = len(lines)
    for i in job_starts:
        if i > start:
            end = i
            break
    return "\n".join(lines[start:end])


loop_gate_slice = job_slice("loop-gate")
release_slice = job_slice("release")

ESCAPE_HATCH_MARKERS = (
    "continue-on-error: true",
    "if: always()",
    "if: success() || failure()",
)


def has_escape_hatch(slice_text):
    return any(marker in slice_text for marker in ESCAPE_HATCH_MARKERS)


needs_scalar = re.search(r"needs:\s*loop-gate\s*$", release_slice, re.MULTILINE)
# The inline list may name other jobs alongside loop-gate (RT-20260821-004
# added a ci-green gate), so match loop-gate as a MEMBER rather than as the
# sole entry. The assertion is unchanged in substance: the release job must
# depend on loop-gate.
# Confined to ONE line: a newline-spanning class would let a `needs:` from a
# neighbouring job satisfy this after the release job's own line is stripped,
# which is exactly what the AC-009 negative fixture checks for.
needs_inline_list = re.search(
    r"needs:[ \t]*\[[^\]\n]*\bloop-gate\b[^\]\n]*\]", release_slice
)
needs_block_list = re.search(r"needs:\s*\n\s*-\s*loop-gate\b", release_slice)
release_has_needs = bool(needs_scalar or needs_inline_list or needs_block_list)

results = {
    "loop_gate_slice_found": bool(loop_gate_slice),
    "release_slice_found": bool(release_slice),
    "loop_gate_has_consistency": "tests/loop-consistency.tests.sh" in loop_gate_slice,
    "loop_gate_has_inventory": "tests/loop-inventory.tests.sh" in loop_gate_slice,
    "release_has_needs": release_has_needs,
    "loop_gate_has_escape_hatch": has_escape_hatch(loop_gate_slice),
    "release_has_escape_hatch": has_escape_hatch(release_slice),
    "loop_gate_runs_on_ubuntu": "runs-on: ubuntu-latest" in loop_gate_slice,
    "loop_gate_has_strategy": ("strategy:" in loop_gate_slice)
    or ("matrix:" in loop_gate_slice),
}

for key in sorted(results):
    print(f"{key}={results[key]}")
PY

# check_release_yml <path> — prints "key=True"/"key=False" marker lines for
# the given workflow-file path; callers grep the captured output.
check_release_yml() {
  python3 "$CHECKER_PY" "$1"
}

# ---------------------------------------------------------------------------
# TEST-007 (AC-007): loop-gate job slice contains both suite invocations
# ---------------------------------------------------------------------------
run_test_007() {
  echo "=== TEST-007 (AC-007): loop-gate job slice contains both suite invocations ==="
  local output
  output="$(check_release_yml "$RELEASE_YML")"

  if grep -qF 'loop_gate_slice_found=True' <<<"$output"; then
    ok "TEST-007 (AC-007): a loop-gate: job slice was found in release.yml"
  else
    fail "TEST-007 (AC-007): no loop-gate: job slice found in release.yml"
    return
  fi

  if grep -qF 'loop_gate_has_consistency=True' <<<"$output"; then
    ok "TEST-007 (AC-007): loop-gate job slice invokes tests/loop-consistency.tests.sh"
  else
    fail "TEST-007 (AC-007): loop-gate job slice does not invoke tests/loop-consistency.tests.sh"
  fi

  if grep -qF 'loop_gate_has_inventory=True' <<<"$output"; then
    ok "TEST-007 (AC-007): loop-gate job slice invokes tests/loop-inventory.tests.sh"
  else
    fail "TEST-007 (AC-007): loop-gate job slice does not invoke tests/loop-inventory.tests.sh"
  fi
}

# ---------------------------------------------------------------------------
# TEST-008 (AC-008): release job needs: loop-gate + weakened-gate negative
# scan
# ---------------------------------------------------------------------------
run_test_008() {
  echo "=== TEST-008 (AC-008): release job needs: loop-gate + no escape hatch ==="
  local output
  output="$(check_release_yml "$RELEASE_YML")"

  if grep -qF 'release_has_needs=True' <<<"$output"; then
    ok "TEST-008 (AC-008): release job slice carries a needs: loop-gate entry"
  else
    fail "TEST-008 (AC-008): release job slice does not carry a needs: loop-gate entry"
  fi

  if grep -qF 'loop_gate_has_escape_hatch=False' <<<"$output"; then
    ok "TEST-008 (AC-008): loop-gate job slice carries no continue-on-error:true / if:always() / if:success()||failure() escape hatch"
  else
    fail "TEST-008 (AC-008): loop-gate job slice carries an escape hatch (weakened-gate threat)"
  fi

  if grep -qF 'release_has_escape_hatch=False' <<<"$output"; then
    ok "TEST-008 (AC-008): release job slice carries no continue-on-error:true / if:always() / if:success()||failure() escape hatch"
  else
    fail "TEST-008 (AC-008): release job slice carries an escape hatch (weakened-gate threat)"
  fi
}

# ---------------------------------------------------------------------------
# TEST-009 (AC-009): negative-branch canary — needs: textually stripped
# ---------------------------------------------------------------------------
run_test_009() {
  echo "=== TEST-009 (AC-009): negative-branch canary (needs: stripped) ==="
  local fixture_dir fixture_copy output

  fixture_dir="$(mktemp -d "${TMPDIR:-/tmp}/release-loop-gate-canary.XXXXXX")"
  fixture_dir="$(cd "$fixture_dir" && pwd -P)"
  CLEANUP_ROOTS+=("$fixture_dir")
  fixture_copy="${fixture_dir}/release.yml"

  # Strip whichever form the file actually uses. The scalar-only pattern this
  # started as went vacuous the moment release.yml moved to the inline-list
  # form (RT-20260821-004's ci-green gate): nothing was removed, so the
  # checker was asked about an unmutated copy.
  grep -vE '^[[:space:]]*needs:[[:space:]]*(loop-gate[[:space:]]*|\[[^]]*loop-gate[^]]*\][[:space:]]*)$' \
    "$RELEASE_YML" > "$fixture_copy"

  output="$(check_release_yml "$fixture_copy")"
  if grep -qF 'release_has_needs=False' <<<"$output"; then
    ok "TEST-009 (AC-009): the needs:-stripped fixture copy is reported non-compliant (release_has_needs=False), proving TEST-008's assertion is not vacuously true"
  else
    fail "TEST-009 (AC-009): the needs:-stripped fixture copy was still reported compliant -- the marker-check function is vacuous"
  fi
}

# ---------------------------------------------------------------------------
# TEST-010 (AC-010): ubuntu-latest only + self-registration
# ---------------------------------------------------------------------------
run_test_010() {
  echo "=== TEST-010 (AC-010): ubuntu-latest only + self-registration ==="
  local output
  output="$(check_release_yml "$RELEASE_YML")"

  if grep -qF 'loop_gate_runs_on_ubuntu=True' <<<"$output"; then
    ok "TEST-010 (AC-010): loop-gate job slice declares runs-on: ubuntu-latest"
  else
    fail "TEST-010 (AC-010): loop-gate job slice does not declare runs-on: ubuntu-latest"
  fi

  if grep -qF 'loop_gate_has_strategy=False' <<<"$output"; then
    ok "TEST-010 (AC-010): loop-gate job slice carries no strategy:/matrix: key (single-OS, matching release.yml's existing scope)"
  else
    fail "TEST-010 (AC-010): loop-gate job slice unexpectedly carries a strategy:/matrix: key"
  fi

  if registered_suites="$(bash "$RUN_ALL_SH" --list)" &&
      grep -Fx 'tests/release-loop-gate.tests.sh' <<< "$registered_suites" >/dev/null \
      && grep -qF 'release-loop-gate.tests.sh' "$TEST_YML" 2>/dev/null; then
    ok "TEST-010 (AC-010): release-loop-gate.tests.sh is registered in tests/run-all.sh and .github/workflows/test.yml"
  else
    fail "TEST-010 (AC-010): release-loop-gate.tests.sh is NOT registered in tests/run-all.sh and/or .github/workflows/test.yml"
  fi
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
run_test_007
run_test_008
run_test_009
run_test_010

printf -- '---- summary: pass=%d fail=%d ----\n' "$PASS" "$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  printf 'not ok: release-loop-gate suite FAILED (%d failures)\n' "$FAIL" >&2
  exit 1
fi
printf 'ok: release-loop-gate suite passed (%d checks)\n' "$PASS"

# Execute the real release steps over distinct tag/dispatch commits. Network,
# signing and publication are replaced by record-only API boundaries.
python3 - "$RELEASE_YML" "$BASH" <<'PY'
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

workflow = Path(sys.argv[1])
lines = workflow.read_text().splitlines()
bash = sys.argv[2]  # Preserve Git Bash rather than selecting WSL through PATH.
repo = workflow.resolve().parents[2]

def body(name):
    start = lines.index('      - name: ' + name)
    run = next(i for i in range(start, len(lines)) if lines[i].startswith('        run:'))
    if lines[run] != '        run: |':
        return lines[run].removeprefix('        run: ')
    result = []
    for line in lines[run + 1:]:
        if line and not line.startswith('          '):
            break
        result.append(line[10:])
    return '\n'.join(result)

def job(name):
    start = lines.index('  ' + name + ':', lines.index('jobs:'))
    end = next((i for i in range(start + 1, len(lines))
                if lines[i].startswith('  ') and not lines[i].startswith('   ')
                and lines[i].endswith(':')), len(lines))
    return '\n'.join(lines[start:end])

def checkout(name):
    steps = job(name).split('      - ')
    checkouts = [step for step in steps if step.startswith('uses: actions/checkout@')]
    assert len(checkouts) == 1, name + ' must have exactly one source checkout'
    return checkouts[0]

for name in ('loop-gate', 'release'):
    section = checkout(name)
    assert 'ref: ${{ needs.ci-green.outputs.sha }}' in section, name
    assert 'persist-credentials: false' in section, name
# Source validation resolves history-bound evidence. Checkout's default depth=1
# makes valid manifests appear stale; the actual loop checkout must retain history.
assert '          fetch-depth: 0' in checkout('loop-gate').splitlines(), 'release source validation requires full history'
assert 'needs: ci-green' in job('loop-gate')
assert 'run: bash ./tests/validate-repository.sh' in job('loop-gate')
assert 'contents: read' in job('loop-gate')
assert 'id-token: write' not in job('loop-gate')
assert 'sha: ${{ steps.source.outputs.sha }}' in job('ci-green')
for key, output in (('TAG', 'tag'), ('RELEASE_SHA', 'sha'), ('PKG', 'pkg')):
    assert key + ': ${{ needs.ci-green.outputs.' + output + ' }}' in job('release')
assert 'predicate-type: https://slsa.dev/provenance/v1' in job('release')
assert 'predicate-path: release-provenance.json' in job('release')
assert 'GITHUB_SHA:' not in job('release'), 'do not forge the workflow identity'

def invoke(script, env, cwd=None):
    assert '${{' not in script, 'Actions values must enter through environment'
    return subprocess.run([bash, '-e', '-o', 'pipefail', '-c', script], cwd=cwd,
                          env=env, capture_output=True, timeout=20)

restriction = body('Restrict manual dispatch to main or a tag ref')
for ref, accepted in (('refs/heads/main', True), ('refs/tags/v1', True), ('refs/heads/other', False)):
    result = invoke(restriction, dict(os.environ, GITHUB_REF=ref))
    assert (result.returncode == 0) == accepted, (ref, result.stderr)

gate = body('Verify CI success for the release commit')
upload_stub = '''gh() {
  if [ "$1" = api ]; then
    case "$2" in
      */git/refs/tags/*) printf '{"object":{"sha":"%s","type":"%s"}}' "$CURRENT_TAG_SHA" "${CURRENT_TAG_TYPE:-commit}" ;;
      */git/tags/*) printf '{"object":{"sha":"%s","type":"%s"}}' "$CURRENT_PEELED_SHA" "${CURRENT_PEELED_TYPE:-commit}" ;;
      *) return 99 ;;
    esac
  else
    printf '%s\\0' "$@"
  fi
}
'''
stub = '''gh() {
  printf '%s\\n' "$*" >> "$API_LOG"
  case "$2" in
    */git/refs/tags/*) printf '{"object":{"sha":"%s","type":"%s"}}' "$FAKE_SHA" "$FAKE_TYPE" ;;
    */git/tags/*) printf '{"object":{"sha":"%s","type":"%s"}}' "$PEELED_SHA" "$PEELED_TYPE" ;;
    *actions/workflows/*)
      if [[ "${FAKE_API_ERROR:-0}" != 0 ]]; then return "$FAKE_API_ERROR"; fi
      if [[ "$*" == *"--jq .total_count"* ]]; then
        printf '%s' "$FAKE_COUNT"
      else
        printf '%s' "$FAKE_RUN_PAGES"
      fi ;;
    *) return 99 ;;
  esac
}
'''
with tempfile.TemporaryDirectory() as temporary:
    root = Path(temporary)
    output, log, sentinel = (root / name for name in ('output', 'api.log', 'sentinel'))
    env = dict(os.environ, INPUT_TAG='v1.2.3', GITHUB_REF_NAME='main', GITHUB_REPOSITORY='owner/repo',
               GITHUB_OUTPUT=output.as_posix(), API_LOG=log.as_posix(), FAKE_SHA='a' * 40,
               FAKE_TYPE='commit', PEELED_SHA='b' * 40, PEELED_TYPE='commit', FAKE_COUNT='1')
    def test_run(**changes):
        return dict({'id': 101, 'head_sha': 'a' * 40, 'event': 'push', 'head_branch': 'main',
                     'status': 'completed', 'conclusion': 'success', 'path': '.github/workflows/test.yml',
                     'repository': {'full_name': 'owner/repo'}, 'head_repository': {'full_name': 'owner/repo'}}, **changes)
    def run_pages(rows, total=1):
        return json.dumps({'total_count': total, 'workflow_runs': rows})
    def run_gate(**changes):
        output.unlink(missing_ok=True)
        log.unlink(missing_ok=True)
        values = {**env, **changes}
        source_sha = values['PEELED_SHA'] if values['FAKE_TYPE'] == 'tag' else values['FAKE_SHA']
        values.setdefault('FAKE_RUN_PAGES', run_pages([test_run(head_sha=source_sha)]))
        return invoke(stub + gate, values)
    # PR API head_sha names the PR head, while checkout tests its synthetic merge.
    # Aggregate success must not admit that untested head as a release tree.
    cases = [
        ('PR-only success', test_run(event='pull_request'), False),
        ('PR target success', test_run(event='pull_request_target'), False),
        ('merge queue success', test_run(event='merge_group'), False),
        ('main push', test_run(), True),
        ('other branch push', test_run(head_branch='feature'), False),
        ('manual main', test_run(event='workflow_dispatch'), True),
        ('manual tag', test_run(event='workflow_dispatch', head_branch='v1.2.3'), True),
        ('different SHA', test_run(head_sha='c' * 40), False),
        ('unfinished run', test_run(status='in_progress'), False),
        ('failed run', test_run(conclusion='failure'), False),
        ('skipped run', test_run(conclusion='skipped'), False),
        ('different workflow', test_run(path='.github/workflows/other.yml'), False),
        ('different repository', test_run(repository={'full_name': 'other/repo'}), False),
        ('fork source', test_run(head_repository={'full_name': 'other/repo'}), False),
        ('missing source repository', test_run(head_repository=None), False),
    ]
    for label, candidate, accepted in cases:
        result = run_gate(FAKE_RUN_PAGES=run_pages([candidate], total=99))
        assert (result.returncode == 0) == accepted, (label, result.stderr)
        if not accepted:
            assert not output.exists(), 'failed CI gate emitted admitted source: ' + label
    for response in ('', 'null', 'not-json', '{}', run_pages([], total=99),
                     json.dumps({'workflow_runs': {}}), run_pages([None])):
        result = run_gate(FAKE_RUN_PAGES=response)
        assert result.returncode != 0 and not output.exists(), response
    # A valid source-exact run may be beyond a page of newer PR-only successes.
    paginated = '\n'.join(json.dumps(page) for page in (
        {'total_count': 101, 'workflow_runs': [test_run(event='pull_request', id=n + 1) for n in range(100)]},
        {'total_count': 101, 'workflow_runs': [test_run()]}))
    result = run_gate(FAKE_RUN_PAGES=paginated)
    assert result.returncode == 0, result.stderr
    assert '--paginate' in log.read_text() and '--slurp' not in log.read_text(), 'use portable gh pagination; jq collects pages'
    result = run_gate(FAKE_API_ERROR='7')
    assert result.returncode != 0 and not output.exists(), 'API failure must not emit admitted source'
    for changes in ({'FAKE_SHA': 'null'}, {'FAKE_SHA': 'A' * 40}, {'FAKE_TYPE': 'tree'},
                    {'FAKE_TYPE': 'tag', 'PEELED_TYPE': 'blob'},
                    {'FAKE_TYPE': 'tag', 'PEELED_TYPE': 'tag'}):
        assert run_gate(**changes).returncode != 0, changes
        assert not output.exists()
    for kind, expected in (('commit', 'a' * 40), ('tag', 'b' * 40)):
        result = run_gate(FAKE_TYPE=kind)
        assert result.returncode == 0, result.stderr
        assert output.read_text().splitlines() == ['tag=v1.2.3', 'sha=' + expected,
                                                   'pkg=sdd-forge-v1.2.3.tar.gz']
        assert log.read_text().count('/git/refs/tags/') == 1
        assert 'head_sha=' + expected + '&status=success' in log.read_text()
    for value in ('$(touch ' + str(sentinel) + ')', 'bad"tag', 'bad\ntag', 'bad\\tag'):
        assert run_gate(INPUT_TAG=value).returncode != 0
        assert not sentinel.exists() and not output.exists()
    # Tag fallback and option boundaries stay data-only.
    assert run_gate(INPUT_TAG='', GITHUB_REF_NAME='v2').returncode == 0
    assert output.read_text().startswith('tag=v2\n')
    result = invoke(upload_stub + body('Upload release assets'),
                    dict(os.environ, TAG='--help', PKG='sdd-forge-test.tar.gz',
                         GITHUB_REPOSITORY='owner/repo', RELEASE_SHA='a' * 40, CURRENT_TAG_SHA='a' * 40))
    assert result.returncode == 0, result.stderr
    assert result.stdout.split(b'\0')[:5] == [b'release', b'upload', b'--clobber', b'--', b'--help']

with tempfile.TemporaryDirectory() as temporary:
    root = Path(temporary)
    (root / '.github/scripts').mkdir(parents=True)
    shutil.copyfile(repo / '.github/scripts/generate-sbom.py', root / '.github/scripts/generate-sbom.py')
    lock = root / 'mcp/example/package-lock.json'
    lock.parent.mkdir(parents=True)
    def write_lock(name):
        lock.write_text(json.dumps({'packages': {'node_modules/' + name: {'version': '1.0.0'}}}))
    def git(*args):
        return subprocess.run(['git', '-C', str(root), *args], check=True, capture_output=True,
                              timeout=10, text=True).stdout.strip()
    git('init', '-q')
    git('config', 'user.name', 'Release test')
    git('config', 'user.email', 'release-test@example.invalid')
    (root / 'tests').mkdir()
    scripts = ('validate-repository.sh', 'loop-consistency.tests.sh', 'loop-inventory.tests.sh', 'release-host-smoke.sh')
    for name in scripts:
        path = root / 'tests' / name
        path.write_text('#!/usr/bin/env bash\nprintf "tagged ' + name + '\\n" >> "$RUNNER_TEMP/executed"\n')
        path.chmod(0o755)
    write_lock('tagged-dependency')
    git('add', '.')
    git('commit', '-qm', 'tagged source')
    tagged = git('rev-parse', 'HEAD')
    git('tag', 'v1')
    write_lock('dispatch-only-dependency')
    for name in scripts:
        (root / 'tests' / name).write_text('#!/usr/bin/env bash\nexit 91\n')
    (root / '.github/scripts/generate-sbom.py').write_text('raise SystemExit(92)\n')
    git('add', '.')
    git('commit', '-qm', 'different dispatch source')
    dispatch = git('rev-parse', 'HEAD')
    assert tagged != dispatch
    env = dict(os.environ, TAG='v1', PKG='sdd-forge-v1.tar.gz', RELEASE_SHA=tagged,
               GITHUB_SHA=dispatch, GITHUB_WORKFLOW_SHA=dispatch, GITHUB_REF_NAME='main',
               GITHUB_WORKFLOW_REF='owner/repo/.github/workflows/release.yml@refs/heads/main',
               GITHUB_REPOSITORY='owner/repo', GITHUB_SERVER_URL='https://github.com',
               GITHUB_REPOSITORY_ID='123456', GITHUB_REPOSITORY_OWNER_ID='654321',
               RUNNER_ENVIRONMENT='github-hosted',
               GITHUB_EVENT_NAME='workflow_dispatch', GITHUB_RUN_ID='123', GITHUB_RUN_ATTEMPT='2',
               RUNNER_TEMP=root.as_posix())
    for step in ('Verify loop checkout', 'Build reproducible source tarball'):
        result = invoke(body(step), env, root)
        assert result.returncode != 0, 'dispatch checkout was accepted: ' + step
    # The mutable tag now names another commit. Only the prior admitted SHA
    # may select the loops, optional smoke, archive and SBOM generator.
    git('tag', '-f', 'v1', dispatch)
    git('checkout', '-q', '--detach', tagged)
    for step in ('Verify loop checkout', 'Validate release source', 'Test loop consistency suite', 'Test loop inventory suite',
                 'Build reproducible source tarball', 'Release-only real host smoke',
                 'Generate CycloneDX SBOM', 'Record immutable build inputs'):
        result = invoke(body(step), env, root)
        assert result.returncode == 0, (step, result.stdout, result.stderr)
    assert (root / 'executed').read_text().splitlines() == ['tagged ' + name for name in scripts]
    names = {entry['name'] for entry in json.loads((root / 'sdd-forge-sbom.cdx.json').read_text())['components']}
    assert names == {'tagged-dependency'}, names
    assert not list(root.glob('release-sbom.*')), 'source export scratch was not cleaned'
    predicate = json.loads((root / 'release-provenance.json').read_text())
    dependencies = predicate['buildDefinition']['resolvedDependencies']
    assert dependencies[0] == {'uri': 'git+https://github.com/owner/repo@refs/heads/main',
                               'digest': {'gitCommit': dispatch}}
    assert dependencies[1] == {'uri': 'git+https://github.com/owner/repo@refs/tags/v1',
                               'digest': {'gitCommit': tagged}}
    assert predicate['buildDefinition']['externalParameters']['workflow']['ref'] == 'refs/heads/main'
    assert predicate['buildDefinition']['internalParameters']['github'] == {
        'event_name': 'workflow_dispatch', 'repository_id': '123456',
        'repository_owner_id': '654321', 'runner_environment': 'github-hosted'}
    assert predicate['runDetails']['builder']['id'] == 'https://github.com/owner/repo/.github/workflows/release.yml@refs/heads/main'
    assert predicate['runDetails']['metadata']['invocationId'].endswith('/runs/123/attempts/2')
    for required in ('GITHUB_REPOSITORY_ID', 'GITHUB_REPOSITORY_OWNER_ID', 'RUNNER_ENVIRONMENT'):
        incomplete = {key: value for key, value in env.items() if key != required}
        result = invoke(body('Record immutable build inputs'), incomplete, root)
        assert result.returncode != 0, 'missing GitHub provenance identity accepted: ' + required
    release_env = {**env, 'GITHUB_EVENT_NAME': 'release', 'GITHUB_WORKFLOW_SHA': tagged,
                   'GITHUB_WORKFLOW_REF': 'owner/repo/.github/workflows/release.yml@refs/tags/v1'}
    result = invoke(body('Record immutable build inputs'), release_env, root)
    assert result.returncode == 0, result.stderr
    release_predicate = json.loads((root / 'release-provenance.json').read_text())
    assert release_predicate['buildDefinition']['resolvedDependencies'] == [dependencies[1]]
    assert release_predicate['runDetails']['builder']['id'].endswith('@refs/tags/v1')
    # A later tag read can reject publication, but must never choose new input
    # bytes. API responses here use the actual moved fixture ref.
    for current in (git('rev-parse', 'refs/tags/v1'), 'null', 'A' * 40):
        result = invoke(upload_stub + body('Upload release assets'), {**env, 'CURRENT_TAG_SHA': current}, root)
        assert result.returncode != 0 and b'release\0upload\0' not in result.stdout
    git('tag', '-f', 'v1', tagged)
    result = invoke(upload_stub + body('Upload release assets'),
                    {**env, 'CURRENT_TAG_SHA': git('rev-parse', 'refs/tags/v1')}, root)
    assert result.returncode == 0, result.stderr
    assert result.stdout.split(b'\0')[:5] == [b'release', b'upload', b'--clobber', b'--', b'v1']
    for kind, peeled, accepted in (('commit', tagged, True), ('commit', dispatch, False), ('tree', tagged, False)):
        result = invoke(upload_stub + body('Upload release assets'),
                        {**env, 'CURRENT_TAG_SHA': 'c' * 40, 'CURRENT_TAG_TYPE': 'tag',
                         'CURRENT_PEELED_SHA': peeled, 'CURRENT_PEELED_TYPE': kind}, root)
        assert (result.returncode == 0) == accepted, (kind, peeled, result.stderr)
    # The release job needs the gate's success. An actual validator failure
    # therefore stops the dependent build, even with a previously admitted SHA.
    package = root / env['PKG']
    package.unlink()
    (root / 'tests/validate-repository.sh').write_text('#!/usr/bin/env bash\nexit 93\n')
    result = invoke(body('Validate release source') + '\n' + body('Build reproducible source tarball'), env, root)
    assert result.returncode == 93 and not package.exists(), 'source validation failure reached the release build'
    # A present corrupt lock remains an error, not zero dependency evidence.
    for invalid in ('{', '[]', '{"packages":[]}'):
        lock.write_text(invalid)
        output = root / 'invalid-sbom.json'
        result = subprocess.run([sys.executable, str(root / '.github/scripts/generate-sbom.py'),
                                 '--source-root', str(root), '--output', str(output)],
                                capture_output=True, timeout=10)
        assert result.returncode != 0 and not output.exists(), result.stderr
        assert b'SBOM_SOURCE_INVALID' in result.stderr

print('ok: release consumers retain the admitted SHA across dispatch/tag drift; workflow identity stays distinct')
PY
