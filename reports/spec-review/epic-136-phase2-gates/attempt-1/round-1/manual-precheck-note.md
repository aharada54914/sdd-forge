# Manual Precheck Note: epic-136-phase2-gates / attempt 1 / round 1

Date: 2026-07-13T04:09:08Z

## Deviation

`plugins/sdd-review-loop/scripts/spec-review-precheck.sh epic-136-phase2-gates 1 1`
was invoked and stopped before creating a report with:

```text
ERROR: spec-review-precheck: jq is required
```

This is the upstream precheck defect tracked in issue #61. The PowerShell twin
does not exist for this stage in the installed plugin, so the automatic path
cannot be used on this host.

## Human authorization

The human user invoked `sdd-sudo` for 24 hours and instructed the agent to
continue the Phase 2 work on 2026-07-13. That explicit workflow-bypass
authority authorizes this documented issue-#61 manual-precheck deviation only;
it does not waive independent review, identity reservation, deterministic test,
or quality-gate requirements.

## Manual checks performed

- Repository, `specs/`, report root, feature directory, requirements,
  acceptance tests, and calibration file exist and are non-symlink paths.
- Feature slug is `epic-136-phase2-gates`; attempt and round are positive
  `1`; requirements status is `Pending`; no prior report destination exists.
- SHA-256 hashes and the canonical composite input hash are recorded in
  `precheck-result.json` next to this note.
- The current review identity ledger is schema-valid and hash-chain-valid;
  each reviewer launch is still reserved through
  `validate-review-context-set.ps1 -Reserve` immediately before launch.
- On this Windows PowerShell 5.1 host the validator stops at its PowerShell 7
  `ConvertFrom-Json -AsHashtable` dependency with
  `REVIEW_CONTEXT_JSON: manifest is not valid JSON`; the persisted invocation
  schema, canonical allowed-path list, input hashes, unique identity, ledger
  hash, sequence, and record-hash calculation are therefore checked manually
  and recorded beside each reviewer launch.
- `scripts/check-sdd-structure.sh`, `check-workflow-state.ps1`, and the
  placeholder scan passed before the review.

## Result

Manual precheck passed. This note is limited to the open issue-#61 fallback.
