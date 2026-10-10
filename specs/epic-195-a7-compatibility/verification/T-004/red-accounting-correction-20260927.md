# T-004 RED accounting correction — 2026-09-27

Authority: approved additional evidence repair for RT-20260814-001.
Scope: evidence only; no product, frozen specification, task status, identity
reservation, or quality-gate verdict changes.

## Supersession

The 2026-08-14 `115 killed / 1 survived` claim does not reproduce with
the shipped `mutation-proof.sh` and the exact pre-fix PowerShell twin.
It is withdrawn as reproducible evidence, not rounded or treated as equivalent
to the measured result. `malformed-corpus-red.log` is retained byte-for-byte
as a superseded historical transcript; the old independent verdicts and old
quality-gate reports are not rewritten. The implementation report's output
hash table remains its historical snapshot, not a digest manifest for this
addendum or the modified independent-record notices.

These six original claim sites are superseded (line numbers before the notices):

| Historical record | Original span / claim | Correction |
|---|---|---|
| `reports/implementation/epic-195-a7-compatibility/T-004.md` | line 75, summary: `115 killed / 1 survived` | measured RED classification is 113/3 |
| same | line 247, regression: complete harness `115/1` | measured 113/3; exit 1 also includes an unrelated restore incompatibility |
| same | line 306, quality-gate focus: confirm saved `115/1` | use this dated replay and its raw log, not the withdrawn accounting |
| same | line 333, independent-test summary: exact `115/1` | historical attribution only; not fresh independent verification |
| `independent-test.md` | line 48, full harness `115/1`; later “exactly the one expected” survivor | three classifier survivors, not one |
| `independent-implementation-review.md` | line 38, sole survivor `(115/1, exit 1)` | three classifier survivors; original verdict retained as history |

## Reproduction inputs and commands

`red-accounting-replay.sh` creates a disposable git-backed copy of the current
working tree, pins that copy's `origin/main` to the source ref, and for RED
replaces only `tests/structural-compatibility.tests.ps1` with `git show` output
from the pre-fix commit. GREEN retains both current twins. The production
working tree is never mutated by either replay.

- Source HEAD: `196b3f9c6d5413ee128b09840ec989876be717e4`
- Source `origin/main`: `3b155fb21aa5cf10ac0811865dc8815b6f103cc3`
- Exact pre-fix commit: `abc7ab4a01d1aaec2647fdc78a84b0b8f9eb73e6`
- Shipped harness SHA-256: `62c44804c97243524fedba413fef76113eebecb570a317e6b47694413bc97af2`
- Current Bash twin SHA-256: `03c99523c8eedcb3caa5010f9f00ab48c1b9cb9efdef74904b28f729afc82fda`
- Pre-fix PowerShell twin SHA-256: `4df6bc5966407eb1d48886164d48007e16869962f34c74e62fa3e2d66e11c6ad`
- Current PowerShell twin SHA-256: `45de3d896127c43a6d1c89af365bf39a4ae3f38c04848f1cfede749ab02a4f2a`

Executed from the repository root with `rtk proxy`, `login=false`:

```sh
rtk proxy bash specs/epic-195-a7-compatibility/verification/T-004/red-accounting-replay.sh red > specs/epic-195-a7-compatibility/verification/T-004/red-accounting-20260927-red.log 2>&1
rtk proxy bash specs/epic-195-a7-compatibility/verification/T-004/red-accounting-replay.sh green > specs/epic-195-a7-compatibility/verification/T-004/red-accounting-20260927-green.log 2>&1
```

The replay wrapper accepts the expected harness exit (RED 1 / GREEN 0) and
returns 0 only for that expectation. Raw harness exit is printed as `EXIT_CODE`.

## Observed RED

Raw replay: `red-accounting-20260927-red.log`; machine-counted extraction:
`red-accounting-20260927-counts.log`. There are 113 `MUTATION-KILLED` records
and three `MUTATION-SURVIVED` records. All three are PowerShell corpus cases:
`corpus-bad-frontmatter`, `corpus-bad-heading`, and
`corpus-and-template-bad-heading`. They lack the classifier's required
`FAIL: full requirements.md canonicalizes without parse fallback` diagnostic.

This classification is not the same as saying all three suites exit zero.
In this current-tree replay their exits are 1: the first two have other
structural failures; the coherent corpus-and-template case has only the
unrelated old PowerShell suite-registration failure. The retained historical
40/0 false-GREEN observation is not claimed as a fresh 40/0 result here.

Restore results are Bash 61 passed / 0 failed and pre-fix PowerShell 39 passed /
1 failed (`PowerShell aggregate runner registers this shipped suite`). That
pre-fix runner-contract incompatibility is separate from malformed-parser
classification. The shipped harness's `set -e` exits at that restore failure,
before its summary print; raw `EXIT_CODE=1` therefore does not by itself prove
that the survivor-count final assertion ran. The 113/3 count is derived from
the actual per-mutation records, not a manufactured summary line.

## Current GREEN

The completed current replay is `red-accounting-20260927-green.log`:
116 killed / 0 survived, raw harness `EXIT_CODE=0`, replay wrapper exit 0.
The unmutated restore runs passed: Bash 61 passed / 0 failed; PowerShell
68 passed / 0 failed. Every RED classifier-survivor case is killed by the
current PowerShell twin with the required parse-fallback diagnostic.
`red-accounting-20260927-counts.log` contains the machine-counted extraction
for both replays. These are implementation-side evidence measurements, not
a renewed independent verdict or formal quality-gate / Done decision.

## Preservation and local validation

The complete RED/GREEN terminal logs are retained locally, not committed:
they contain host-specific temporary paths. The committed count extraction
and replay script allow independent reproduction; hashes identify the exact
retained logs, but are not a substitute for a fresh independent review.

- RED terminal-log SHA-256: `dff468d0e5d53525178384c72bd02b0d4d407218aab84c03f98365d1549e4283`.
- GREEN terminal-log SHA-256: `203245a690e494038c0205be590f0d06b762e3140f404333e4ac60da2104ace7`.

- `malformed-corpus-red.log` retains SHA-256
  `25f1d633426a432407e30cf0412bf1a9185f3fd23ec4c309c269ff805629cea8`.
- Both current twins and the shipped harness retain the input digests above.
- `bash -n red-accounting-replay.sh` and `git diff --check` passed.
- The only existing-file edits are the dated supersession notices in the
  implementation report and two independent records. No old verdict,
  product code, frozen spec, approval, or task lifecycle field was changed.
