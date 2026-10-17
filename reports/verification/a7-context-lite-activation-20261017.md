# A7 Context-present Lite activation verification

The structural compatibility suites previously emitted F5/F6 skips unconditionally. Dependency checks also searched deleted branch names despite the corresponding changes already being merged. This left Context-present Lite behavior untested.

The existing immutable merge-receipt mechanism now records the actual A1, A5, and A6 ancestral merges. Terminal specification status and fingerprint checks still apply. The A6 fingerprint's line coordinates follow its current location; its approved content hash is unchanged. Historical specifications, review records, and captured responses are unchanged.

When the A1/A6 conditions are satisfied, both structural suites replay the existing F2 recorded response through the current Resolver and its real dependencies under F5 advisory and F6 required Context. This is an offline recorded-response injection, not a new model capture. Assertions independently verify the actual enforcement state, exact eligible Lite summary, unchanged three human Markdown artifacts, the two expected machine artifacts, and absence of a Full projection. Current-product state mutations must fail before producing an observed response.

A5's merge receipt does not substitute for its separate executable-caller predicate. That predicate remains false where only skill instructions describe the call; the existing loop tests continue to distinguish an inactive caller from an executable integration.

## Validation

- Structural suite: Bash 125 passed, PowerShell 132 passed.
- Structural activation: 10 cases passed, including current Resolver mutations for both Context states and runtimes.
- Skip allowlist: Bash 29 passed, PowerShell 32 passed.
- Escalation activation: 10 cases passed.
- Workflow-state validation: passed for the A7 feature in both runtimes.
- All seven dependency entries have ancestral merge receipts and matching fingerprints.
- Repository validation and human-copy mirror freshness passed without rewriting historical mirrors.
- Isolated structural mutation controls passed in both runtimes; the selected envelope and runner/parser-root checks killed all six selected mutations.
- Four affected inactive-skip mutation shards passed in both runtimes: eight mutations killed, zero survived. This is targeted coverage, not a new exhaustive mutation-run claim.

The inactive-dependency mutation fixtures explicitly use nonancestral receipts. This preserves the negative skip-path checks after production dependencies become active; expected failure diagnostics and mutation targets are unchanged.

These checks establish current-product behavior for the recorded-response compatibility seam. They do not claim new live-model, multi-host authentication, release, or approval evidence.
