# T-002 attempt 3 preparation scope

Issue #423 / approved shared-review-launch-repair T-002. Owning checkout: `/Users/jrmag/.codex/worktrees/shared-review-launch-integration/sdd-forge`. HEAD: `9ce19abe90df0cb83e385f96855e4843318a8807`. Risk: high (existing approved task; evidence identity/admission preparation only). No implementation, frozen specification, canonical report, ledger, status, commit or other Git write is authorized. The previous admission-20261010 directory remains unchanged.

Required validation: canonical task snapshot and manifest admission; all admitted source hashes; existing PowerShell hash recipe, traceability freeze twins, downstream precheck parity, and exclusive-lock unreadable-equivalence tests; implementation-report validator. Formal quality evaluation is parent-owned. Historical RED is helper-extraction structural RED only; RT-20261009-001 remains T-001-only.

Dependency audit: review-hash-normalization consumes helper plus both PowerShell prechecks; traceability-freeze extracts workflow-state shell fixture helpers, requires workflow-state checker twins, registry/schema, four calibration/risk references, workflow-state-integrity specs and its review artifacts, and task precheck twins with layer validators. Downstream parity requires impl/task precheck twins, review-contract validator twins, risk checker twins, references, shared hash helper, and registry directory topology. Unreadable-equivalence dot-sources the hash suite. Only named plugin files are admitted, not whole plugin directories. Historical workflow fixture files are individually enumerated from the four bounded source trees; verification/ is excluded. check-sdd-structure passed (CLAUDE advisory only).

Existing dirty state before any attempt-3 write (preserved):

```text
 M .github/workflows/test.yml
 M AGENTS.md
 M plugins/sdd-quality-loop/agents/evaluator.md
 M plugins/sdd-quality-loop/references/guard-invariants.json
 M plugins/sdd-quality-loop/scripts/generate-guard-invariants.py
 M plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.js
 M plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.ps1
 M plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.sh
 M plugins/sdd-quality-loop/scripts/generated/guard_invariants.py
 M plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1
 M plugins/sdd-quality-loop/scripts/validate-review-context-set.sh
 M plugins/sdd-quality-loop/skills/quality-gate/SKILL.md
 M plugins/sdd-review-loop/references/review-context-boundary.md
 M plugins/sdd-review-loop/scripts/impl-review-precheck.ps1
 M plugins/sdd-review-loop/scripts/spec-review-precheck.ps1
 M plugins/sdd-review-loop/scripts/spec-review-precheck.sh
 M plugins/sdd-review-loop/scripts/task-review-precheck.ps1
 M plugins/sdd-review-loop/skills/impl-review-loop/SKILL.md
 M plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md
 M plugins/sdd-review-loop/skills/task-review-loop/SKILL.md
 M reports/review-context/identity-ledger.json
 M specs/workflow-state-registry.json
 M tests/review-agent-isolation.tests.sh
 M tests/review-context-boundary.tests.sh
 M tests/review-scratch-history.tests.py
 M tests/run-all.ps1
 M tests/run-all.sh
?? docs/review-tickets/RT-20261009-001.yml
?? handoffs/shared-review-launch-repair-T-001/
?? handoffs/shared-review-launch-repair-T-005-attempt-3/
?? handoffs/shared-review-launch-repair-T-005-attempt-4/
?? handoffs/shared-review-launch-repair-T-005-attempt-5/
?? handoffs/shared-review-launch-repair-T-005-attempt-6/
?? plugins/sdd-quality-loop/scripts/preflight-evaluator-delivery.py
?? plugins/sdd-quality-loop/scripts/review-conditional-inputs.py
?? plugins/sdd-quality-loop/scripts/supplemental-delivery-inputs.py
?? plugins/sdd-review-loop/scripts/launch-impl-review.py
?? plugins/sdd-review-loop/scripts/nontty-impl-pretool-guard.mjs
?? plugins/sdd-review-loop/scripts/preflight-host-review.py
?? plugins/sdd-review-loop/scripts/probe-nontty-review.py
?? plugins/sdd-review-loop/scripts/review-hash-normalization.ps1
?? plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py
?? reports/impl-review/shared-review-launch-repair/
?? reports/implementation/shared-review-launch-repair/
?? reports/quality-gate/20261009-shared-review-launch-repair-T-001-compact.md
?? reports/quality-gate/20261009-shared-review-launch-repair-T-001.md
?? reports/quality-gate/20261010-shared-review-launch-repair-T-005.md
?? reports/quality-gate/launch-017c10b4-2937-4075-ad93-727610cca773/
?? reports/quality-gate/launch-01a989f0-ff77-4890-b86b-8af32c9a1708/
?? reports/quality-gate/launch-028aa5f2-3d0d-4eb7-b37e-f5514cc32173/
?? reports/quality-gate/launch-732e65bb-612e-4ef3-bef7-5d06d9bf94bb/
?? reports/quality-gate/launch-85d6d84c-eb23-481f-8940-91bb5e436ad9/
?? reports/quality-gate/launch-93b6c91a-c34e-43c9-bdb4-02bf2ff13404/
?? reports/quality-gate/launch-a16870fe-3127-4386-9c40-4c0988275a0c/
?? reports/quality-gate/launch-dbc34028-569d-4e31-95a1-ea8c5b4af90a/
?? reports/quality-gate/launch-fbe735ad-d472-4b5e-957d-4b246fe04636/
?? reports/quality-gate/shared-launch-T001-followup-declaration.md
?? reports/review-context/T-001-compact-640-unreserved-diagnostic.json
?? reports/review-context/T-001-compact-settings-unreserved-diagnostic.json
?? reports/review-context/T-001-current-unreserved-diagnostic-source.json
?? reports/review-context/scratch-reservations/0286abf597fafeac465d28091a034f52fb8b2a41557ae8e500cf694a628e7d97.json
?? reports/review-context/scratch-reservations/0686bde5b882cb179ff91b2755dfd9f51ce118e6702ee03ba61bd03aafb9b296.json
?? reports/review-context/scratch-reservations/12470536d01b84977e53d54df8dd9b8591ca9e5787360772fed21153fabc20cf.json
?? reports/review-context/scratch-reservations/172710fe2914947e496f64526f5904da78bd7686e545241e4a1640a1a70cc330.json
?? reports/review-context/scratch-reservations/267e6220adaa83bd21c2ccba388444c4b467fcda0bca1076697126c8654b4c8a.json
?? reports/review-context/scratch-reservations/886efcf5695ad7fd9e1d09f19b6e0c13eb3ae24977e60df858559861d53b7c54.json
?? reports/review-context/scratch-reservations/b64954e3bcba2e95703925b33c1ddccbc2f92a973b2b21c07418d035bb76e2e2.json
?? reports/review-context/scratch-reservations/de27ea498edae4f81058510b9ac1277ca81a3d1bfbe62201487a05d61ee3cbeb.json
?? reports/review-context/shared-launch-T001-quality-01a989f0-ff77-4890-b86b-8af32c9a1708.json
?? reports/review-context/shared-launch-T001-quality-028aa5f2-3d0d-4eb7-b37e-f5514cc32173.json
?? reports/review-context/shared-launch-T001-quality-732e65bb-612e-4ef3-bef7-5d06d9bf94bb.json
?? reports/review-context/shared-launch-T001-quality-93b6c91a-c34e-43c9-bdb4-02bf2ff13404.json
?? reports/review-context/shared-launch-T001-quality-a459e047-f9c1-4361-a1ae-eda673e34ea1.json
?? reports/review-context/shared-launch-T001-quality-fbe735ad-d472-4b5e-957d-4b246fe04636.json
?? reports/review-context/shared-launch-T005-quality-017c10b4-2937-4075-ad93-727610cca773.json
?? reports/review-context/shared-launch-T005-quality-76c78a12-3fcd-4f45-bb88-10ef2dcccf6e.json
?? reports/review-context/shared-launch-T005-quality-85d6d84c-eb23-481f-8940-91bb5e436ad9.json
?? reports/review-context/shared-launch-T005-quality-a16870fe-3127-4386-9c40-4c0988275a0c.json
?? reports/review-context/shared-launch-T005-quality-dbc34028-569d-4e31-95a1-ea8c5b4af90a.json
?? reports/review-context/shared-review-launch-repair-impl-a1r1-a.json
?? reports/review-context/shared-review-launch-repair-impl-a1r1-b.json
?? reports/review-context/shared-review-launch-repair-spec-a1r1-a.json
?? reports/review-context/shared-review-launch-repair-spec-a1r1-b.json
?? reports/review-context/shared-review-launch-repair-task-a1r1-a.json
?? reports/review-context/shared-review-launch-repair-task-a1r1-b.json
?? reports/review-context/shared-review-launch-repair-task-a1r2-a.json
?? reports/review-context/shared-review-launch-repair-task-a1r2-b.json
?? reports/review-context/shared-review-launch-repair-task-a1r3-a.json
?? reports/review-context/shared-review-launch-repair-task-a1r3-b.json
?? reports/spec-review/shared-review-launch-repair/
?? reports/task-review/shared-review-launch-repair/
?? reports/verification/reflect-shared-launch-approval-human.py
?? reports/verification/shared-launch-handoff/
?? reports/verification/shared-launch-python-validation-blocker.md
?? reports/verification/shared-review-launch-integration.md
?? specs/shared-review-launch-repair/
?? tests/host-review-preflight.tests.py
?? tests/quality-nontty-transport.tests.py
?? tests/review-conditional-inputs.tests.py
?? tests/review-hash-normalization.tests.ps1
?? tests/shared-launch-build.tests.py
?? tests/shared-launch-python-requirements.txt
?? tests/shared-launch-python/
?? tests/spec-review-verify-inputs.tests.py
?? tests/supplemental-delivery-declaration.tests.py
?? tests/t001-evaluation-preparation.tests.py
?? tests/task-structured-output.tests.py
?? tests/traceability-freeze-contract.tests.py
?? tests/unified-launch-order.tests.py
?? tests/unified-task-launch.tests.py
```

