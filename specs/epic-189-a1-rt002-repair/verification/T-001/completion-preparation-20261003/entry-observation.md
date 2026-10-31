# T-001 completion-preparation entry observation

Date: 2026-10-03 JST
Run ID: rt002-t001-completion-preparation-20261003
Agent Instance ID: /root/rt002_completion_preparation
Scope: evidence preparation only; no evaluator identity or verdict.

## Verified owner inputs

Owner HEAD: `1e86fb272643e798db4e1ca0c89f0402317a2fc8`.
All shell commands used `rtk proxy` and `login=false`.
`bash scripts/check-sdd-structure.sh` exited 0 and printed `check-sdd-structure: OK` (plus `advisory: CLAUDE.md`, `host: github`).
The no-argument MCP advisory reported multiple active features; the explicit parent-selected T-001 target governs.

Read-only SHA-256 results:

| File | SHA-256 |
|---|---|
| owner verifier | `1057d1fcd1a8307c1fe55b961f3b37af2576683887f1c4ec2ce5138065e8fe0d` |
| owner Bash suite | `0b5417b86553ebe9001f8ac1871930378330e74289adb65eab8c92148855000c` |
| owner PowerShell suite | `49b537a37f1dbdab192b53b00147bf20377df9ecfe94283ac21f58c8073706cd` |
| owner T-001-results.md | `5a0365bc96c8ed38e54075f313528e98206d812ca950f006b918a3724bcf5aa6` |
| owner T-001-traceability.json | `7cd901486a25f88190a7734f34172e136e1e54e85f67949e637ad0ea0045c334` |
| historical flat implementation report | `1cac7dd5a27fbce39515ed4874672e445df85a407790fba5a033355116b0a4c1` |
| current-evidence-20261002 report | `e3afd5485404f2fdba1d69d9c21a5ac3a038cbfc77ef6f15738db31012ef4479` |
| apply-human.py | `3ce86f7d4fb2da837ab4160cfeba33e98071cf6da8516f3718f675af1973e4f1` |

## Installed-path mismatch before ordinary execution

The historical human helper, `reports/verification/rt002-bare-envelope-candidate-20260929/apply-human.py:27`, names the Codex plugin cache `sdd-quality-loop/1.17.0/scripts/check-hook-activation-handshake.py` as its installed target. The corresponding installed wrapper lookup returned `No such file or directory`; a bounded file inventory found no 1.17.0 verifier in the Codex cache.

The discovered Claude cache 1.17.0 and Codex cache 1.18.0 verifier files both rehashed to `d9277ca516fa79b6ef459e0d0505375624a0a9279c32390758a96650985d0064`, the recorded pre-repair version. Neither matches the owner candidate hash. This does not establish why the cache state differs from the October 2 observation.

The single command `rtk proxy bash /Users/jrmag/.claude/plugins/cache/sdd-plugins/sdd-quality-loop/1.17.0/scripts/check-hook-activation-handshake.sh --emit-challenge` completed with exit 0 and the following actual output:

```json
{
  "canary_target": "sdd/.hook-canary-sentinel",
  "nonce": "166be1bd21f01aef8cbd0c363fd7ac10",
  "schema": "sdd-hook-challenge/v1",
  "tool_call_template": {
    "claude-code": {
      "tool_input": {
        "content": "",
        "file_path": "sdd/.hook-canary-sentinel"
      },
      "tool_name": "Write"
    },
    "codex-cli": {
      "tool_input": {
        "patch": "*** Begin Patch\n*** Add File: sdd/.hook-canary-sentinel\n+\n*** End Patch\n"
      },
      "tool_name": "apply_patch"
    },
    "copilot-cli": {
      "tool_input": {
        "content": "",
        "file_path": "sdd/.hook-canary-sentinel"
      },
      "tool_name": "Write"
    }
  }
}
```

This is the legacy empty patch, not the approved nonce-bound candidate patch. No native dispatch was made, no host response was fabricated, and no response-verification command was run. The nonce is not reusable as later fresh activation evidence. No own-session HOOK_ACTIVE is established. No test suite or installer self-test was executed in this run; ordinary implementation/test execution remains stopped at this entry prerequisite.

## Qualification boundary and handoff

Existing historical RED, GREEN, installed observation and restoration records are retained unchanged; none proves current installed activation for this agent. The missing original target and mismatching discovered versions require identifying and verifying the actual active installation. Any required protected application remains maintainer-owned, with advance pinned backup/restoration preparation, then a fresh challenge, one native dispatch, unchanged response and installed verification. Do not use the owner repository verifier or an alternate copied executor as an installed substitute.

The human-amended Done When 4 permits current-hash-pinned restoration, retained backup and isolated tests; historical pre-application restoration chronology remains unverified. This observation neither changes that amendment nor labels old history PASS.

Required historical ticket, recovery contract and two-envelope precedence files were absent at their owner-relative paths and were read from the primary source checkout. A formal evaluator input bundle must explicitly admit the governing bytes it requires; this read is not an input assembly or evaluator manifest.

No source/test/protected file, approval/status, identity ledger, historical report, CI, Git commit or remote state changed. Only this non-frozen observation is retained. A provisional canonical handoff report was created concurrently with the parent's stop instruction and immediately removed on receipt; no canonical completion report is delivered. T-001 remains Approved / In Progress; T-002 remains Draft / Planned.

## Session Handoff

Context compaction occurred after recording the installed-entry blocker. In accordance with the implement-task context-management rule, this implementer ends without resuming tests or preparation. The next implementer must independently reload the authoritative inputs and establish its own fresh installed activation. This run did not qualify Implementation Complete and did not perform independent review.

## Parent preparation after handoff

The parent separately prepared `reports/verification/rt002-installed-118-human-20261003.py`. It reuses the existing installer only after verifying its SHA-256 `6ff32fbfbeefda0b7c980c0dd6369b58e3b5f622b6436ad7c8d345d58644eded`; fixes the source to this owner candidate and the destination to the Codex 1.18.0 verifier; retains the expected prior hash `d9277ca516fa79b6ef459e0d0505375624a0a9279c32390758a96650985d0064`; and requires candidate `1057d1fcd1a8307c1fe55b961f3b37af2576683887f1c4ec2ce5138065e8fe0d`. Application and restoration remain human-only. The retained prior bb388 backup and historical restoration evidence are not replaced.

Observed parent commands, each through `rtk proxy`, exited 0:

- `python3 reports/verification/rt002-installed-118-human-20261003.py --check`: pinned source and installed prior verifier matched, no changes.
- `python3 reports/verification/rt002-installed-118-human-20261003.py --self-test`: isolated apply, restore, two hash refusals and symlink refusal passed.
- `git diff --check`: no whitespace errors.

These are preparation/isolation checks, not ordinary task regressions or installed activation. No `--apply` or `--restore` was executed by an agent. The maintainer command is `rtk proxy python3 /Users/jrmag/.codex/worktrees/rt002-bounded-integration/sdd-forge/reports/verification/rt002-installed-118-human-20261003.py --apply`. It prints the verified backup and exact rollback command before replacement. After application, a fresh native challenge and unchanged response must be verified through the actual installed path before continuing task execution. The cause of the installation mismatch remains unproven. Of the four additional independent-review executions authorized by the human, two remain unused.
