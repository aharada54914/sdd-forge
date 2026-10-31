# T-001 candidate only: Copilot Auto and the AC-004 chain oracle

Status: **not applied to the live driver or frozen specification**. This is a reviewable candidate, not acceptance evidence. The repo remains at the original head's behavior.

Prepared artifacts: `candidate/tests/` contains both runnable harness twins and the Bash contract self-test; `candidate/specs/epic-196-a8-integration/` contains the exact proposed frozen design/task amendments. `candidate.patch` is their unified five-file patch against detached HEAD `ef97fd9d275780cacb82c69884ac6a34ee8bae54`. `git apply --check` succeeded against that HEAD. No `Approval:`, `Status:`, or review-status header changed.

Candidate-only verification on a disposable local clone at that HEAD: `bash tests/cross-runtime-cli-contract.tests.sh`, `bash tests/cross-runtime-handoff.tests.sh`, and `pwsh -NoProfile -File tests/cross-runtime-handoff.tests.ps1` all exited 0 without live mode. `nonce-chain-regression.py` executes the old and candidate Bash final-hash expressions: changing only nonce1 leaves the old oracle unchanged but changes the candidate oracle. These results do not prove real host loading or the authenticated three-hop handoff.

2026-10-01 candidate self-test completion: the existing Bash contract self-test now executes the live Bash final-hash expression twice with only nonce1 changed; the PowerShell embedded self-test does the same with its parsed live `$outputBytes` assignment. In the isolated clone, unmutated Bash contract, Bash fixture, and PowerShell fixture tests each exited 0. Reverting only each runtime's live final-hash expression to nonce2-only made Bash contract, Bash fixture, and PowerShell fixture each exit 1 with `live Copilot hash oracle ignores nonce1`. The clone was restored to candidate bytes before regenerating `candidate.patch`; `git apply --check` against the original detached HEAD exited 0. The separate `nonce-chain-regression.py` exited 0; it remains outside normal CI and is not the basis for the newly integrated detection. No live CLI, formal attempt, or quality gate was run.

Current SHA-256 inventory:

| Candidate artifact | SHA-256 |
|---|---|
| `candidate.patch` | `76158fa2592d5bc6d62263d34f7561da9f142d56fcce31546d4a72b860cc9f42` |
| `nonce-chain-regression.py` | `50bd4787497a2f5ef7cb879c0e9ae168ad344c4f5ea8783b6ef654f947fb3eca` |
| `candidate/tests/cross-runtime-handoff.tests.sh` | `285e0a41a6dea3188d65aa7268af5244dae7d5abc23653736cfde2cf84be452f` |
| `candidate/tests/cross-runtime-handoff.tests.ps1` | `81eaa216cd9d01cd811fae572c43000f3203a85cdf940cdabb198df3f4f1e912` |
| `candidate/tests/cross-runtime-cli-contract.tests.sh` | `6e31b101bc1a36ba2ebae070e054dfff1386d25f9151be4546b7195be33b38e2` |
| `candidate/specs/epic-196-a8-integration/design.md` | `24f0980ed1a274136b9f249738954b811963f2da0f06f337e13ebb317d194290` |
| `candidate/specs/epic-196-a8-integration/tasks.md` | `3211bf9a8e3dbd284ccc760bd2491eb9a18b1b95f9e5131e939cdf6bf4d28aad` |

Formal history audit: `reports/spec-review/epic-196-a8-integration/` contains attempts 1–3, `reports/task-review/epic-196-a8-integration/` attempts 1–3, and `reports/impl-review/epic-196-a8-integration/` attempts 1–7; `reports/implementation/epic-196-a8-integration/T-001.md` records Task Attempt Count 3. No new review input, ledger reservation, implementation attempt, live CLI run, or quality gate was started for this candidate. Before adoption, a human must authorize the hash-frozen design/task change and select a valid provenance re-review path without resetting any persisted budget.

## Evidence and scope

- `requirements.md` AC-004 requires final Copilot-consumed state to reflect both upstream contributions. The current final hash depends only on `nonce2`; `nonce-chain-regression.py` demonstrates that changing `nonce1` leaves it unchanged.
- The current `design.md` Fixture Contract and T-001 Goal/Scope call for that one-nonce output, contradicting AC-004 and T-001's own Done When. These reviewed, hash-bound inputs cannot be edited in this preparation. Obtain the required human design/task amendment and re-review before applying the driver change or claiming acceptance.
- The authenticated Copilot 1.0.90 default-model probe worked; explicitly passing the only listed model `mai-code-1.1-flash` failed with `Model "mai-code-1.1-flash" from --model flag is not available.` This supports omitting `--model` for default/Auto, not a claim that a full handoff passed.

## Proposed exact behavior

1. Keep both committed fixture stubs and both independently generated nonces. Codex's second invocation still verifies `nonce1` and mutates only handoff-02 with `nonce2`.
2. Copilot reads **both** fixture files. It writes exactly `COPILOT-CONSUMED:<nonce1>:<nonce2>` as UTF-8 with no trailing newline. The driver compares that output file's SHA-256 against the same byte string. This changes the existing `generated_file_hash` oracle without expanding trace schema or requiring an incidental extra file.
3. If `SDD_A8_COPILOT_MODEL` is unset, empty, or case-insensitive `Auto`, invoke `copilot -p ...` without `--model`. If set to another value, preserve explicit `--model <value>`. Do not call a default-model session “pinned”; record the effective model from the CLI's real run evidence if needed for AC-005.
4. Apply the corresponding behavior to both Bash and PowerShell. Replace their pseudo-CLI expected output and their current explicit-model guard. Update `tests/cross-runtime-cli-contract.tests.sh` and PowerShell's embedded contract self-test so they assert both modes, instead of rejecting Auto. Retain the scoped Copilot tool arguments and all existing Claude/Codex restrictions.
5. Amend the frozen `design.md` Fixture Contract row and following paragraph to specify the two-nonce final bytes/hash and both-file Copilot read. Amend T-001 Goal/Scope references to “reusing handoff-02's nonce” to say the final state depends on both nonces. Keep AC-004 and trace schema otherwise unchanged; do not normalize this discrepancy away by weakening AC-004.

## Exact replacement anchors for the later reviewed batch

| File | Current anchor | Candidate replacement |
|---|---|---|
| `tests/cross-runtime-handoff.tests.sh` | `pseudo_copilot_output = f'COPILOT-CONSUMED:{nonce2}'.encode()` | `pseudo_copilot_output = f'COPILOT-CONSUMED:{nonce1}:{nonce2}'.encode()` |
| same | current `SDD_A8_COPILOT_MODEL` non-Auto guard | `copilot_model_args=(); if [[ -n "${SDD_A8_COPILOT_MODEL:-}" && ! "${SDD_A8_COPILOT_MODEL}" =~ ^[aA][uU][tT][oO]$ ]]; then copilot_model_args=(--model "$SDD_A8_COPILOT_MODEL"); fi` (multiline) |
| same | `copilot --model "$SDD_A8_COPILOT_MODEL" -p` | `copilot "${copilot_model_args[@]}" -p` |
| same | Copilot prompt reads only handoff-02 | prompt reads handoff-01 and handoff-02, extracts token and nonce, writes `COPILOT-CONSUMED:<token>:<nonce>` |
| same | `printf 'COPILOT-CONSUMED:%s' "$nonce2"` | `printf 'COPILOT-CONSUMED:%s:%s' "$nonce1" "$nonce2"` |
| `tests/cross-runtime-handoff.tests.ps1` | pseudo output and `$outputBytes` use only `$nonce2` | both use `'COPILOT-CONSUMED:' + $nonce1 + ':' + $nonce2` |
| same | empty/Auto model guard | `$copilotModelArgs = @(); if ($env:SDD_A8_COPILOT_MODEL -and $env:SDD_A8_COPILOT_MODEL -ine 'auto') { $copilotModelArgs = @('--model', $env:SDD_A8_COPILOT_MODEL) }` |
| same | `Invoke-Cli 'copilot' @('--model', $env:SDD_A8_COPILOT_MODEL, '-p', ...)` | `Invoke-Cli 'copilot' ($copilotModelArgs + @('-p', ...))` |
| same | Copilot prompt reads only handoff-02 | same two-file, two-nonce prompt as Bash |
| `design.md` | `sha256("COPILOT-CONSUMED:" + mutation_nonce)` and ensuing one-nonce chain claim | `sha256("COPILOT-CONSUMED:" + first mutation_nonce + ":" + second mutation_nonce)`; Copilot must read both artifacts, and the final hash must change when either nonce changes |
| `tasks.md` T-001 Goal and TEST-004 Scope | “reusing `handoff-02`'s own nonce” | “using both handoff-01 and handoff-02 nonces in the final generated-file hash” |

Application must be **one reviewed batch** after the frozen design/task amendment is authorized and its required provenance review path is satisfied. The candidate already includes model-mode and nonce1-contribution checks in the existing suites; their normal and nonce2-only mutation results are recorded above. The live authenticated E2E and formal quality gate remain separate subsequent checks; neither was rerun for this candidate. No identity ledger, verdict, status, protected path, or live host was changed here.

Local candidate regression: `rtk proxy python3 specs/epic-196-a8-integration/verification/T-001/nonce-chain-regression.py`.
