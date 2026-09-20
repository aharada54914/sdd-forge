# T-002 High-Risk Persisted-Evidence Preflight

Recorded before production implementation, as required by WFI-001.

| Persisted evidence field | Sibling contract / traceability counterpart | Failing mismatch test written before implementation |
|---|---|---|
| `manifest.schema_version` | `design.md` Golden-baseline manifest contract (`golden-baseline-manifest/v1`) | `manifest records ... every target/script hash`; malformed/missing schema is rejected by the manifest assertion |
| `manifest.pre_capability_commit_sha` | REQ-006 / AC-018; Epic A1 merge `a8d65c7316f53787121874968e14878bc90c75aa` first parent `50b20364e996432cb06061df03ffb4d173c27fa6` | `manifest/counterpart mismatches fail closed` changes the field to a non-counterpart SHA and requires default capture failure |
| `manifest.fixed_environment.TZ` | Global Constraint fixed `TZ=UTC` | `manifest/counterpart mismatches fail closed` changes the field away from `UTC` and requires default capture failure |
| `manifest.fixed_environment.LC_ALL` | Global Constraint fixed `LC_ALL=C` | `manifest/counterpart mismatches fail closed` changes the field away from `C` and requires default capture failure |
| `manifest.fixed_environment.ambient_sdd_variables` | Global Constraint: no ambient `SDD_*` is read | `manifest/counterpart mismatches fail closed` inserts an ambient variable name and requires default capture failure |
| `manifest.capture_scripts[].path` and `.sha256` | AC-018 exact capture-script versions; live `tests/capture-golden-baseline.sh` and `.ps1` | manifest hash test compares both live scripts; mismatch test replaces a recorded hash and requires default capture failure |
| Every `manifest.targets[].name` and `.capture_format` | `design.md` REQ-001 canonical target inventory (nine exact rows) | manifest shape test compares the complete ordered name/format tuple to the inventory |
| Every `manifest.targets[].path` and `.sha256` | Target artifact at the recorded repository-relative candidate/canonical path | manifest hash test recomputes every artifact hash; mismatch test replaces all nine hashes and requires default capture failure |

The implementation must not begin until the Red evidence confirms that the two
promotion guards are absent from an intentionally permissive implementation.
