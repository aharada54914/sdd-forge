# T-002 deterministic evidence reconciliation

Issue #423; owner `/Users/jrmag/.codex/worktrees/shared-review-launch-integration/sdd-forge`; HEAD `9ce19abe90df0cb83e385f96855e4843318a8807`; risk high. This preparation writes only the T-002 verification directory and T-002.contract.json. Task state, source, report, ledger and old evidence are untouched.

## Executed verification

`collect.py` independently rechecked all 242 canonical report Outputs hashes against current owner files and 217 authorized modes: no mismatches. `fresh-binding.json` records each comparison; `fresh-binding-after.json` rechecks the same 242 hashes and report after deterministic execution. The four native suites remain snapshot executions; matching current bytes does not relabel them as new owner executions.

The canonical report has two explicit parent adoption additions relative to the retained native report: an Input manifest line and Parent adoption provenance. `report-adoption.diff` preserves the exact difference. The first collector invocation rejected presumed byte identity at this point before running any check; the collector was corrected to preserve this known adoption difference, not to alter either report. Native report SHA-256 is verified against its original delivery index; canonical hash is recorded separately.

Fresh commands/cwd/exit codes/log hashes are in `checks.json`: T-005's six-module Ruff and mypy checks, isolated FilesOnly assembly, placeholder scan (expanded to T-002 product paths), risk, task state, traceability and canonical report validation all exited 0. These Python static/build checks cover the shared launch delivery and do not purport to type-check PowerShell. PowerShell recipe behavior is covered by the admitted native tests. Component coverage exited 0 with `not-applicable (disabled-legacy)`; that is not PASS.

Native attempt-3 evidence was preserved and promoted unchanged under `../native-revalidation-attempt-3-20261010/`: hash-parity 0, traceability-freeze-retry-1 0, downstream-parity 0, unreadable-equivalence 0. `execution-summary.json` and `commands.json` carry actual commands/cwd/exit codes. Initial traceability-freeze exit 1 was missing iconv in the execution-only restricted PATH; retry supplied existing installed iconv/rmdir links. No product source was repaired, and this failure is not RED. Both first and retry logs remain.

## RED boundary and corrected ordinary-TDD mapping

`../historical-red-recovery-20261010.md` is authentic historical structural helper-extraction RED followed by GREEN, source-mapped to the unchanged current helper. Unit evidence is limited to that extraction/equivalence requirement (REQ-005). It is not all-output product RED. Historical traceability failures were test-fixture errors, not product RED. RT-20261009-001 grants no T-002 exception.

Correction on 2026-10-10 following the parent audit: the previous preparer interpreted the acceptance obligation as requiring additional all-output behavioral RED and recorded required/false with empty red_evidence. That interpretation is superseded. Authentic pre-extraction structural RED exercises the intended shared-helper refactoring; the subsequent GREEN proves the new shared structure and preserves existing behavior. Together with all four current native equivalence/boundary suites for AC-004/AC-005, 242 matching owner output hashes, and 217 matching modes, these are ordinary TDD evidence for this behavior-preserving task. The acceptance-tests contract check now maps that historical extraction record as red_evidence and native execution-summary.json as green_evidence, with passes true. This neither claims that a pre-existing behavior first failed nor requires an invented behavioral regression for every unchanged output.

The old contract.log and contract-result.json remain unchanged as the actual failed deterministic run under the superseded interpretation. The corrected gate run is separately recorded as contract-corrected.log and contract-corrected-result.json. This is an evidence-mapping correction, not a RED exception: RT-20261009-001 remains T-001-only, and neither historical traceability fixture errors nor the attempt-3 iconv PATH error is counted as RED. Formal independent evaluation remains separate; this file supplies no waiver or verdict.

The traceability checker confirms existing REQ/AC/TEST/evidence links, not RED adequacy. Regression evidence is the four successful suites bound to all current matching output bytes. Earlier eight-file disposable restoration is documented in the retained independent-verification and before/mutated/restored hashes, not a new installed rollback execution.

## Exclusions

No formal verdict, reservation, task transition, compaction-free claim, fresh RED, native Windows, installed-baseline trust, installed rollback, final-head CI, merge or promotion is asserted. The native run disclosed compaction; its continuity limitation remains in the canonical report. The formal quality evaluation is separate from this deterministic preparation.
