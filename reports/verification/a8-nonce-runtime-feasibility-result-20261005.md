# A8 two-contribution oracle feasibility — candidate only

Date: 2026-10-05

Scope: diagnostic runtime execution, not implementation completion, native-host evidence, reservation, review verdict or task approval. Frozen sources and implementation files were not edited. Existing design-revision candidate remains unapplied.

## Finding and minimal targets

The affected implementation belongs to T-001 (`tasks.md:136`), not T-004 (`tasks.md:671`, independent REQ-003 hook assertions). T-001 Done When already demands an output derived from both contributions (`tasks.md:291-293`).

`tests/cross-runtime-handoff.tests.sh:214,218` and `tests/cross-runtime-handoff.tests.ps1:200,204` contain the live defect: Copilot is instructed to read only handoff-02 and the expected final hash depends only on nonce2. The preceding Codex consumption of handoff-01 does not establish the final artifact's dependence on nonce1.

The smallest coherent live change is four statements across those two files:

1. Each Copilot prompt names both existing input artifacts, extracts YAML token as nonce1 and HTML-comment nonce as nonce2, and requests exactly UTF-8 `COPILOT-CONSUMED:<nonce1>:<nonce2>` with no BOM/newline. Nonce values must not be supplied in the final consumer prompt.
2. Bash expected-hash expression changes `printf 'COPILOT-CONSUMED:%s' "$nonce2"` to `printf 'COPILOT-CONSUMED:%s:%s' "$nonce1" "$nonce2"`.
3. PowerShell expected bytes change `'COPILOT-CONSUMED:' + $nonce2` to `'COPILOT-CONSUMED:' + $nonce1 + ':' + $nonce2`.

No model selection, automatic-model guard, CLI permission, fixture schema, output path or T-004 change is required. This remains contingent on legitimate adoption/re-review of the design revision; it is not authority to edit frozen originals.

The permanent fixture regressions also need strengthening at Bash lines 128-131 and PowerShell lines 154-156: simulate the consumer by reading both mutated fixture files, derive the expected digest independently from producer-owned values, and reject a stale baseline output after changing each nonce separately. Currently Bash hashes its own constructed output for the expected result; PowerShell constructs both output and expectation from the same nonce2 expression. These are not two-contribution negative tests. Merely adding nonce1 to both duplicated fixture expressions would still leave a weak self-confirming test.

## New bounded experiment

Command: `rtk proxy python3 reports/verification/a8-nonce-runtime-feasibility-20261005.py`

Exit: 0. The probe strictly locates the current source oracle statements, executes those exact expressions and their minimal in-memory substitution in Bash and PowerShell, and compares against independently constructed expected bytes. It does not run either complete test driver or any agent CLI. No historical candidate's unrelated Auto changes are used.

```text
CURRENT sh nonce1-only: stale-baseline-output ACCEPTED (defect)
CURRENT sh nonce2-only: stale-baseline-output REJECTED
CANDIDATE sh nonce1-only: stale-baseline-output REJECTED
CANDIDATE sh nonce2-only: stale-baseline-output REJECTED
CANDIDATE sh trailing-newline: REJECTED
CANDIDATE sh utf8-bom: REJECTED
CANDIDATE sh nonce2-only-output: REJECTED
CURRENT ps1 nonce1-only: stale-baseline-output ACCEPTED (defect)
CURRENT ps1 nonce2-only: stale-baseline-output REJECTED
CANDIDATE ps1 nonce1-only: stale-baseline-output REJECTED
CANDIDATE ps1 nonce2-only: stale-baseline-output REJECTED
CANDIDATE ps1 trailing-newline: REJECTED
CANDIDATE ps1 utf8-bom: REJECTED
CANDIDATE ps1 nonce2-only-output: REJECTED
Probe complete: exact-source oracle expressions executed in Bash and PowerShell; no native-host or formal gate claim.
```

This proves the current oracle's nonce1 insensitivity and the candidate oracle's independent sensitivity to both nonces in both runtimes. It does not prove that a real Copilot invocation reads both artifacts or writes the specified bytes; that remains the approved native E2E's job after design adoption and formal launch preconditions. The final-consumer prompt must change together with the expected digest, otherwise a conforming old consumer correctly fails the new oracle.

## Input hashes

| Path | SHA-256 |
|---|---|
| tests/cross-runtime-handoff.tests.sh | 479ab524fae57a47c117129f16fcf045b7010af9544f181bb369389d957027ae |
| tests/cross-runtime-handoff.tests.ps1 | 8a01086d9612cf4f21a243ac407fef5cb26af9f94082209927e12e118daf29f9 |
| reports/verification/a8-nonce-runtime-feasibility-20261005.py | 5af74e810538a3efacabbff6d9e4a9fb3c0a87740ed5c6ecd1d40c26bf3c903a |

Next bounded implementation scope after legitimate design adoption: the four live statements plus independent two-input fixture consumption/mutation assertions in the same two test drivers. No new admission framework, ADR-only workaround or T-004 edit is needed.
