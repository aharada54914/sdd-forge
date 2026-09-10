# T-004 Independent Test Record

Date: 2026-08-12; remediation re-test 2026-08-14

Role: independent tester

Verdict: PASS for the T-004 scoped verification. This is not a formal
`quality-gate` Done verdict.

## Evidence correction — 2026-09-05 (primary, RT-20260814-001)

The dated test record below is historical. Only its active RED assertions are
corrected here; this is not a new independent tester PASS. Its earlier 115/1
claim is superseded by the authentic 113/3 replay. Historical 40/0 restore
runs must not be conflated with current-main verification.

### Authentic RED replay provenance

The primary executed the historical harness on September 5. The fixture root
was `/tmp/t004-red.3zg2ns/src`, based on full commit
`b14dcbd202e5e836b58a6587efd5abce0cf850f2`, with only
`tests/structural-compatibility.tests.ps1` restored from full commit
`abc7ab4a01d1aaec2647fdc78a84b0b8f9eb73e6`.
Before and after execution, all 6,070 tracked file blobs were compared to the
base tree. Exactly that one path differed, matching old blob
`13872097fa6db1f999fc50e0f65b29e9406d32d2`.

The actual command, from that fixture root, was:

```sh
rtk proxy env PATH=/bin:/usr/bin:/usr/local/bin:/opt/homebrew/bin /bin/bash specs/epic-195-a7-compatibility/verification/T-004/mutation-proof.sh </dev/null > /tmp/t004-red-primary.8c5Rsa/combined.log 2>&1
```

The executor returned exit 1. All 359 raw stdout/stderr lines were retained,
without changing counts or diagnostics, in `malformed-corpus-red.log`, followed
only by the independently observed `EXIT_CODE=1` footer. A byte comparison
confirmed that exact relationship. Raw SHA-256:
`bc06a51e13ddcb5e8ef768a463f8c0b5a6e9baa87ac5a07f896b1d7ad36b6f63`.
Saved-file SHA-256:
`e38f94a7f9410899c78b9ae7fa37f5826fc90491b42335d3befcc164b3c40847`.

| Historical input | SHA-256 |
|---|---|
| `tests/structural-compatibility.tests.ps1` | `4df6bc5966407eb1d48886164d48007e16869962f34c74e62fa3e2d66e11c6ad` |
| `verification/T-004/mutation-proof.sh` (under this feature) | `f5e03ff8869bf07f6b4890873ba90bc30050bdead4da64125ffb43a0c4e3653d` |
| `tests/lib/markdown-ast-canonicalizer.sh` | `4178e59df40c8a3222913faf5b228181298a4c528b6653221575b987240f5d29` |
| `tests/lib/markdown-ast-canonicalizer.ps1` | `ea522fc5069dd508d8ac5ebbe7a025cf1eadd49a70d0aee2552bac5aed8be96d` |

The saved log has the shipped classifier self-test as its first line, 113
unique mutation kills and exactly three PowerShell survivors. The frontmatter
and heading cases exit 1 without the required strict diagnostic; the coherent
corpus-and-template case exits 0. The harness therefore reports 113/3 and exits
1, as required by the ticket. This authentic RED is expected failure evidence,
not a claim that the current implementation passed.

### Current-main check — separate from historical evidence

The primary reran both unchanged focused suites from the clean-base repair
worktree at `ca023cc85d9db5d44f63ec77e4d3ff73f3f9bfdf`, with the same scoped
PATH above: `/bin/bash tests/structural-compatibility.tests.sh` returned exit 0
at 44 passed / 0 failed; `pwsh -NoProfile -File
tests/structural-compatibility.tests.ps1` returned exit 1 at 43 passed / 1 failed.
Each emitted four explicitly dependency-gated SKIPs. The extra four assertions
relative to the August 40/0 records are the named-SKIP shape assertions added
in the August 25 source revision, not newly executed dependency branches.

The failure is `PowerShell aggregate runner registers this shipped suite`.
The assertion at `tests/structural-compatibility.tests.ps1:204-205` requires an
exact double-quoted line, while `tests/run-all.ps1:71` registers the same path
as a single-quoted array entry with a comma. Registration exists; the assertion
is sensitive to representation. This current failure is not repaired by the
four-file evidence ticket. No current-main focused PASS, independent tester
PASS, new quality-gate verdict, or Done transition is claimed.

The primary also ran the unchanged full mutation harness from this worktree:

```sh
rtk proxy env PATH=/bin:/usr/bin:/usr/local/bin:/opt/homebrew/bin /bin/bash specs/epic-195-a7-compatibility/verification/T-004/mutation-proof.sh </dev/null > /tmp/t004-current-primary.zO2ytp/combined.log 2>&1
```

The executor returned exit 1. The raw log SHA-256 is
`f2ea525df1039e22cc4730491a347afeb3c4bfc3b362b090b7fca92b3a774860`.
It contains 116 kill lines and no survivor lines, followed by Bash restore
44/0 and PowerShell restore 43/1. The harness exits during failed restore,
before printing any `MUTATION SUMMARY` line. Consequently neither the kill
count nor the historical `mutation-proof.log` establishes a fresh GREEN run.
The historical log remains byte-for-byte unchanged. Its existing SHA-256
`6bfc6e7b1c3a2e684f41bcdae4c2695fe92650da39b31df5301cae49441e47f6`
is not a September execution record, regardless of its checkout timestamp.

## Historical fresh runs against the August sources

| Command | Result |
|---|---|
| `bash tests/structural-compatibility.tests.sh` | PASS — 40 passed, 0 failed; F3/F4/F5/F6 emitted the four required named skips |
| `pwsh -NoProfile -File tests/structural-compatibility.tests.ps1` | PASS — 40 passed, 0 failed; the same four named skips were emitted |
| both suites with `STRUCTURAL_COMPAT_REPO_ROOT` set to a newly created empty directory | PASS (negative case) — Bash exit 1 and PowerShell exit 1, each 0 passed / 9 failed on missing shipped product surfaces |
| `cd specs/epic-195-a7-compatibility/human-copy && shasum -a 256 -c MANIFEST.sha256` | PASS — `.github/workflows/test.yml: OK` |
| `bash specs/epic-195-a7-compatibility/verification/T-004/manifest-proof.sh` | PASS — corruption killed, restored candidate GREEN |
| `bash specs/epic-195-a7-compatibility/verification/T-004/mutation-proof.sh` | PASS — restored GREEN in both runtimes; 116 killed, 0 survived, exit 0 |
| `bash specs/epic-195-a7-compatibility/verification/T-004/classifier-proof.sh` | PASS — removing ANSI stripping and removing wrap compaction each fail at exit 2; restored classifier exits 0 |
| `bash specs/epic-195-a7-compatibility/verification/T-004/depth1-proof.sh` | PASS — real depth-1 clone; mutation killed in both runtimes; restored GREEN at 40/0 each |
| `bash specs/epic-195-a7-compatibility/verification/T-004/bump-replay-proof.sh` | PASS — real unchanged `scripts/bump-version.sh` replay from 1.14.0 to 1.14.1 in scratch; both suites remained 40/0 |

## Test-quality audit

- Expected structural surfaces are derived from shipped sources: full-track
  paths from the bootstrap interviewer's `Required Outputs`, lite-track paths
  from the lite skill, structures and status fields from the shipped templates,
  the corpus schema and anchor digest from `design.md`, the refresh path from
  T-012, and skip dependencies from the acceptance/task records. The suite does
  not embed a copied expected artifact body.
- Assertions compare independently sourced product surfaces (recorded corpus
  versus shipped skills/templates/design/task records). They do not assert on a
  value immediately created as the oracle. The fresh 116/0 mutation run kills
  every assertion family, including artifact-order normalization and both
  WFI-012 mis-cased negative layers.
- The suite has no network commands and performs no Git-history query. The
  additional shallow proof nevertheless exercises current sources in a real
  `depth=1`, `is-shallow=true` clone and mutation-kills both runtimes there.
- The empty-root negative run confirms the suite cannot pass without product
  code. Malformed frontmatter and unrecognized heading grammar are hard
  failures, while permitted key order, whitespace, and line-ending differences
  normalize.
- The original `red-sh.log` and `red-ps1.log` are retained as historical
  missing-asset preflight records and are not used as the task's malformed-
  corpus RED. The authoritative pre-fix `malformed-corpus-red.log` executes the
  coherent malformed-corpus/template case: Bash kills it, PowerShell falsely
  survives at 40/0, and the full harness exits 1 at 113/3. The restored mutation
  log kills the same case in both runtimes and exits 0 at 116/0.
- The ANSI- and width-independent classifier proof reproduces byte-for-byte.
  The persisted mutation, GREEN, depth-1, manifest, and bump-replay logs agree
  with the fresh independent checks.

## Quality-gate cycle 1 remediation test

The August independent tester reported rerunning both focused twins at 40/0 and the classifier
proof, then validated the complete persisted mutation transcript: exactly 116
unique kills (58 Bash and 58 PowerShell), no survivor lines, both restored
40/0 runs, and `EXIT_CODE=0`. The corrected malformed RED contains three
pre-fix PowerShell survivors and exits 1: corpus-bad-frontmatter (exit 1),
corpus-bad-heading (exit 1), and corpus-and-template-bad-heading (exit 0).
The first two lack the strict diagnostic; only the last is a false GREEN.
These corrected RED counts were measured by the primary on September 5, not by
the August tester. The historical tester reported that the human-copy manifest
verifies, `git diff --check` is clean, and the task plan, live workflow,
protected gate tests, and fixture builders have no diff from HEAD.

## Limits

This pass verifies T-004's focused suites and adversarial proof harnesses. It
does not claim a repository-wide aggregate gate: the saved `run-all` transcripts
contain unrelated failures and are incomplete, so the formal SDD quality gate
must evaluate repository-wide disposition separately.

Post-test transcript completion note (root, 2026-08-12): both aggregate runs
subsequently completed. T-004 passed at 40/0 in each transcript. The Bash
aggregate exited 1 with five other failing suites; the PowerShell aggregate
exited 1 with four other failing suites. Those failures are enumerated in the
implementation report and do not change this tester's scoped T-004 verdict.
