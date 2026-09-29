# Issue 137: native Ubuntu verification

Verified source commit: `13e97d7e9e74c5da9544df7ab016192c9f92cc93`.

Ubuntu 24.04.5 LTS / Linux 6.8.0-142 / aarch64 ran in an isolated
Lima virtual machine with an ext4 guest disk and no host filesystem mounts.
Tools: Node 24.13.0, Git 2.43.0, RTK 0.42.4. Downloaded Node and RTK
archives passed their official SHA-256 checks before execution.

Executed once, without changes to assertions or deadlines:

```sh
rtk proxy node --test --test-concurrency=1 --test-reporter=tap \
  tests/sdd-context/validation.test.mjs tests/sdd-context/privacy.test.mjs \
  tests/sdd-context/privacy-grammar.test.mjs tests/sdd-context/json-admission.test.mjs \
  tests/sdd-context/contract-artifact.test.mjs
```

UTC start: `2026-09-29T15:56:05.175971626Z`.
UTC end: `2026-09-29T15:56:10.784028593Z`.
Result: 205 passed, 0 failed, 0 cancelled, 0 skipped, 0 todo; exit 0.
This includes validation 150, privacy/JSON 34, and contract-artifact 21 cases.
Real Git, POSIX store modes, existing-target preservation, escaping-parent
rejection and owner-registry admission against independently supplied synthetic
confirmation were exercised.

Retained raw-evidence SHA-256:

- stdout: `259cfebdb1c2f2e54199eb8a24cfc912595e65fdb720cd8ef779621e54eb7990`
- stderr (empty): `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`
- input manifest: `871d089ed81aad1b2e77ab53f661227182ae19a8683f516599b700f52a41cec5`
- evidence manifest: `07cf6521d267f4e84cfbd2af5220c2f778c796a965643a28d6d5e213c03bb6ea`

All 11 source/test/contract hashes matched the host checkout; all eight
copied evidence hashes matched the guest manifest. The VM was shut down
after verification and retained for recovery; no host plugin installation changed.

This does not prove native Windows ACL behavior, concurrent ancestor-swap
immunity, installer-confirmed ownership, native product hook activation,
independent JSON Schema engine conformance, CI, formal quality-gate PASS or Done.
