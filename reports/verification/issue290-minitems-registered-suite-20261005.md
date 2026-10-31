# T-001 registered-suite cardinality candidate

Date: 2026-10-05. Non-formal implementation verification; original tests NOT APPLIED.

## Scope

The candidate adds two standard-dispatcher controls to each already registered sidecar suite: one input is accepted with exit 0/VALID, and empty inputs are rejected with exit 32 plus the precise CONTENT_SCHEMA_VIOLATION/minItems diagnostic. It reuses each suite's existing concept fixture generator, canonical hash routine, synthetic signer, approver registry, and real dispatcher. The fixture mutation precedes hashing/signing and renders matching Markdown. The old unknown-key mutation remains supported. No validator/schema, approval, frozen artifact, reservation, task state or Git state changes are included.

The prior protected-test write refusal recorded in `issue290-t001-red-blocked-handoff-20261002.md` was respected; it was not retried with another writer. Only the explicitly permitted candidate snapshot and non-frozen delivery artifacts were edited. The owner test files' before hashes were confirmed again after the candidate run and dry-run.

## Candidate and pins

Patch: `reports/verification/issue290-minitems-registered-suite-20261005.patch`

SHA-256: `6ccccf575c8900830239766f0725ad9ea076ebf3c02acf8dde6cd8af546f8079`

| Target | Before (current owner) | Candidate after |
|---|---|---|
| `tests/validate-approval-sidecar.tests.sh` | `72511d69f5407e5f186beb3b32ebb8c5a0fa47b94807f319341f04429dad43e6` | `b39767190ee83d88f17055f67f273db35535e14395e203b84533e54f83c89bc8` |
| `tests/validate-approval-sidecar.tests.ps1` | `a8ed8ee80504e1ff75fbe38c1f33e8a3e614b0c38906f38a88a2d6e19fa7eb09` | `75dede41bdb9aeeec9fdfb5965107897ea19febf4b4eab089313d49d13f7c366` |

## Actual candidate-suite execution

Isolated root: `/private/tmp/issue290-cardinality-suite.0bmlud`. Copied current owner `tests`, `plugins`, `contracts`, and the existing epic-189 human-copy fixture; modified only the two candidate test files. Neither owner files nor historical Git revisions were used as write targets.

| Command (cwd isolated root) | Exit | Result |
|---|---:|---|
| `rtk proxy bash tests/validate-approval-sidecar.tests.sh` | 0 | 115 PASS, 0 FAIL |
| `rtk proxy pwsh -NoProfile -File tests/validate-approval-sidecar.tests.ps1` | 0 | 114 PASS, 0 FAIL |

Both completed once; execution handles were 11806 and 50747. Tool transcript output is available, but a separate complete raw log was not captured (some intermediate returned chunks were truncated). Both final aggregate results were observed. No SKIP was reported. These are actual full registered driver runs with the candidate bytes, not just the prior temporary Python CLI harness. Tests' existing self-registration checks also passed. PowerShell execution was macOS, not native Windows.

New string comparisons use case-sensitive `-ceq` and `.Contains()` in PowerShell, matching case-sensitive grep in Bash; integer comparisons remain numeric. No new cmdlet filter, split, regex or sorting comparison is introduced. Full native-OS parity and independent review are not claimed.

## Human application preparation

Helper: `reports/verification/issue290-minitems-suite-human-apply-20261005.py`

SHA-256: `a63f2e4e147dc6ba3a53ed37a874f24673dff4dd71952eb967a81a92f767f04a`

Executed in owner, exit 0:

```sh
rtk proxy python3 -B reports/verification/issue290-minitems-suite-human-apply-20261005.py --check
```

Output concluded `READY: exact source and patch pins; dry-run only; originals unchanged`. The patch utility prints `patching file` even in this dry-run; afterward both owner hashes were explicitly rechecked and unchanged.

Minimal human-only command, from owner:

```sh
rtk proxy python3 -B reports/verification/issue290-minitems-suite-human-apply-20261005.py --apply-human
```

Type `APPLY-ISSUE290-MINITEMS-SUITES` at its TTY prompt. The helper requires exact patch and source pins, rejects changed/already-applied sources, saves both dirty originals in a retained temporary backup, rechecks pins, applies only the two-file patch, and verifies after hashes. It uses no Git mutation. Its application branch has NOT RUN. On source drift, stop and rebuild/review against current bytes; do not update expected hashes merely to force application.

After human application, run both commands from the owner and capture full logs, compare after hashes, and independently inspect the small diff. Current task-stage role repair/rebinding and formal implementation/quality gates remain separate and were not changed by this candidate. The absence of a registered cardinality case is resolved only in the tested candidate until this application occurs.
