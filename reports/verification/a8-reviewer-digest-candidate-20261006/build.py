"""Create isolated candidate sources/diff; never edit repository originals."""
from pathlib import Path
import difflib
import hashlib
import json
import re
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
Q = 'plugins/sdd-quality-loop/scripts/'
R = 'plugins/sdd-review-loop/'
files = [Q + 'validate-review-context-set.sh', Q + 'validate-review-context-set.ps1',
         R + 'agents/spec-reviewer-a.md', R + 'agents/spec-reviewer-b.md',
         R + 'references/review-context-boundary.md', R + 'skills/spec-review-loop/SKILL.md',
         'tests/review-context-boundary.tests.sh']
BASE = HERE / 'baseline'
OUT = HERE / 'candidate'


def replace_once(text, old, new):
    assert text.count(old) == 1, old
    return text.replace(old, new, 1)


def build():
    baseline = {}
    sources = {}
    for rel in files:
        data = (ROOT / rel).read_bytes()
        path = BASE / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        if path.exists():
            assert path.read_bytes() == data, 'original drift: ' + rel
        else:
            path.write_bytes(data)
        baseline[rel] = hashlib.sha256(data).hexdigest()
        sources[rel] = data.decode()
    sh = Q + 'validate-review-context-set.sh'
    sources[sh] = replace_once(sources[sh], 'set -euo pipefail\n', '''set -euo pipefail

# Calculation only. This branch never reaches ledger reads or reservation.
if [[ ${3:-} == --reviewer-receipt ]]; then
  [[ $# -eq 4 ]] || { printf '%s\\n' 'REVIEWER_DIGEST_ERROR: invalid arguments' >&2; exit 1; }
  exec python3 -B "$(dirname "$0")/reviewer-receipt.py" "$1" "$2" "$4"
fi
''')
    ps = Q + 'validate-review-context-set.ps1'
    sources[ps] = replace_once(sources[ps], '[switch]$Reserve\n', '[switch]$Reserve,\n\n    [string]$ReviewerReceipt\n')
    sources[ps] = replace_once(sources[ps], "$ErrorActionPreference = 'Stop'\n", '''$ErrorActionPreference = 'Stop'

# Calculation only. No ledger access and no reservation in this branch.
if ($PSBoundParameters.ContainsKey('ReviewerReceipt')) {
    if ($Reserve -or [string]::IsNullOrEmpty($ReviewerReceipt)) {
        [Console]::Error.WriteLine('REVIEWER_DIGEST_ERROR: invalid arguments')
        exit 1
    }
    & python3 -B (Join-Path $PSScriptRoot 'reviewer-receipt.py') $Manifest $RepositoryRoot $ReviewerReceipt
    exit $LASTEXITCODE
}
''')
    role_note = '''
### Restricted digest calculation capability

Bash is available only for the caller-pinned exact invocation of
`validate-review-context-set.sh <fixed-manifest> <fixed-root> --reviewer-receipt <fixed-receipt>`
(or its PowerShell equivalent). No general shell, file creation, normal validator,
reservation, changed argument, pipeline, redirection, or command chaining is allowed.
The saved receipt is exactly `<fixed-manifest>.receipt.txt`, copied byte-for-byte
from the caller's successful reservation stdout. Compare it with the quoted receipt
and verify this context's real run/session correspondence before using the calculator.
Run the pinned calculator after those checks and require exit 0 / REVIEWER_DIGEST_OK;
it recomputes the ordered input and record digests and every admitted raw file hash
without reading the ledger. It does not prove host identity, receipt authenticity,
global uniqueness, precheck completeness or a review verdict. All existing checks
remain mandatory. Any missing/denied capability blocks delivery; no executor fallback.
'''
    for suffix in ('a', 'b'):
        rel = R + 'agents/spec-reviewer-' + suffix + '.md'
        sources[rel] = replace_once(sources[rel], 'tools: Read, Grep, Glob\n', 'tools: Read, Grep, Glob, Bash\n') + role_note
        sources[rel] = replace_once(sources[rel],
            'Never run `validate-review-context-set` against your own manifest after the\n',
            'Never run ordinary/reservation modes of `validate-review-context-set` against your own manifest after the\n')
    boundary_note = '''
## Spec reviewer calculation-only entrypoint

The optional `--reviewer-receipt` branch of the shared context validator provides
the above existing digest recipes to spec reviewers without ledger access. Its
only control inputs are a fixed canonical `reports/review-context/*.json` invocation
and its `.json.receipt.txt` sidecar containing exactly the existing reservation
stdout line. These are launch metadata, not additions to allowed_input_manifest.
The caller saves the original receipt once; a reviewer compares it with the quoted
receipt and verifies real context identity before using it. No receipt is invented
or re-reserved. The mode reads only authorized spec inputs named in that invocation,
checks their raw hashes, recomputes allowed-inputs-v1 and the record digest, and
emits REVIEWER_DIGEST_OK rather than REVIEW_CONTEXT_OK. It never authorizes a launch,
proves ledger history, replaces preflight/postflight, or grants a verdict.

Both CLI entrypoints delegate this spec-only calculation to reviewer-receipt.py.
Safe descriptor-relative no-link reads require a supported POSIX runtime; other
runtimes fail closed, with native Windows support unverified/not enabled. Ordinary
validator paths and all other stages retain their existing behavior.
'''
    sources[R + 'references/review-context-boundary.md'] += boundary_note
    # Existing load-bearing line citations and their regression anchors must move
    # with the dispatch; no check text or ordinary behavior changes.
    delta = sources[sh].count('\n') - (BASE / sh).read_text().count('\n')
    def shifted(match):
        return ':' + '-'.join(str(int(n) + delta) for n in match.group(1).split('-'))
    doc = R + 'references/review-context-boundary.md'
    sources[doc] = re.sub(
        r'(?<=`):([0-9]+(?:-[0-9]+)?)(?=`)', shifted, sources[doc])
    test = 'tests/review-context-boundary.tests.sh'
    sources[test] = re.sub(r'^:([0-9]+(?:-[0-9]+)?)(?= validator )', shifted, sources[test], flags=re.M)
    skill_note = '''
## Required spec reviewer digest capability

Before idle allocation, fix the invocation path under reports/review-context and
its `.json.receipt.txt` sidecar path. Pin the installed calculator/entrypoint bytes.
Provision only the exact calculation command described in the role, with dontAsk,
Read/Grep/Glob and restricted Bash capability. No wildcard/prefix shell allowance,
script writing, permission bypass or inferred inherited broad Bash access is allowed.
Confirm the effective host policy rejects changed argv, other paths, --reserve,
redirection, substitution and chained commands before formal dispatch. Unit/mocked
checks are not host proof. Do not execute a refused operation via another executor.

Run normal caller preflight/reservation unchanged. Save its successful stdout once
at the fixed receipt sidecar (never overwrite old evidence), quote that same line
to the reviewer, and preserve actual identity correspondence. The reviewer compares
the saved receipt/manifest/real identity and invokes only the restricted calculator.
Its result is not a replacement for any prior or subsequent required check.
If the installed tools or host policy cannot support this boundary, stop before
review input delivery; do not reserve a provisional or already-executed review.
'''
    sources[R + 'skills/spec-review-loop/SKILL.md'] += skill_note
    sources[Q + 'reviewer-receipt.py'] = (HERE / 'reviewer-receipt.py').read_text()
    patch = ''
    for rel, after in sources.items():
        before = (BASE / rel).read_text() if rel in files else ''
        target = OUT / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(after)
        patch += ''.join(difflib.unified_diff(before.splitlines(True), after.splitlines(True),
                                             fromfile='a/' + rel if rel in files else '/dev/null',
                                             tofile='b/' + rel))
    (HERE / 'candidate.patch').write_text(patch)
    (HERE / 'baseline-hashes.json').write_text(json.dumps(baseline, indent=2) + '\n')
    (HERE / 'dirty-before.txt').write_text(subprocess.check_output(['rtk', 'proxy', 'git', 'status', '--short'], cwd=ROOT, text=True))
    launcher = (ROOT / 'reports/verification/a8-spec-idle-identity-candidate-20261006/idle_launcher_candidate.py').read_text()
    launcher = replace_once(launcher, "'tools': ['Read', 'Grep', 'Glob']", "'tools': ['Read', 'Grep', 'Glob', 'Bash']")
    launcher = replace_once(launcher, "'--tools', 'Read,Grep,Glob',", "'--tools', 'Read,Grep,Glob,Bash',\n            '--allowedTools', 'Bash(' + digest_command(role) + ')',")
    helper = '''
def digest_command(role):
    if role not in ('spec-reviewer-a', 'spec-reviewer-b'):
        raise ValueError('invalid spec reviewer role')
    manifest = 'reports/review-context/a8-spec-attempt4-round1-' + role + '.json'
    # All tokens here are fixed ASCII path tokens, not caller-provided shell text.
    return ('rtk proxy bash plugins/sdd-quality-loop/scripts/validate-review-context-set.sh '
            + manifest + ' ' + str(ROOT) + ' --reviewer-receipt ' + manifest + '.receipt.txt')

'''
    launcher = replace_once(launcher, '\ndef allocation_args(role):', helper + '\ndef allocation_args(role):')
    (HERE / 'idle_launcher_candidate.py').write_text(launcher)
    print('candidate generated; originals untouched; native launch NOT RUN')


if __name__ == '__main__':
    build()
