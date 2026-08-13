# T-004 Independent Test Record

Date: 2026-08-12

Role: independent tester

Verdict: PASS for the T-004 scoped verification. This is not a formal
`quality-gate` Done verdict.

## Fresh runs against the final sources

| Command | Result |
|---|---|
| `bash tests/structural-compatibility.tests.sh` | PASS — 40 passed, 0 failed; F3/F4/F5/F6 emitted the four required named skips |
| `pwsh -NoProfile -File tests/structural-compatibility.tests.ps1` | PASS — 40 passed, 0 failed; the same four named skips were emitted |
| both suites with `STRUCTURAL_COMPAT_REPO_ROOT` set to a newly created empty directory | PASS (negative case) — Bash exit 1 and PowerShell exit 1, each 0 passed / 9 failed on missing shipped product surfaces |
| `cd specs/epic-195-a7-compatibility/human-copy && shasum -a 256 -c MANIFEST.sha256` | PASS — `.github/workflows/test.yml: OK` |
| `bash specs/epic-195-a7-compatibility/verification/T-004/manifest-proof.sh` | PASS — corruption killed, restored candidate GREEN |
| `bash specs/epic-195-a7-compatibility/verification/T-004/mutation-proof.sh` | PASS — restored GREEN in both runtimes; 114 killed, 0 survived |
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
  value immediately created as the oracle. The fresh 114/0 mutation run kills
  every assertion family, including artifact-order normalization and both
  WFI-012 mis-cased negative layers.
- The suite has no network commands and performs no Git-history query. The
  additional shallow proof nevertheless exercises current sources in a real
  `depth=1`, `is-shallow=true` clone and mutation-kills both runtimes there.
- The empty-root negative run confirms the suite cannot pass without product
  code. Malformed frontmatter and unrecognized heading grammar are hard
  failures, while permitted key order, whitespace, and line-ending differences
  normalize.
- Saved RED evidence is genuine missing-product RED (`red-sh.log` and
  `red-ps1.log`, exit 1); saved GREEN evidence is exit 0. The persisted mutation,
  depth-1, manifest, and bump-replay logs agree with the fresh independent runs.

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
