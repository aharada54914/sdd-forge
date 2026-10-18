# T-007 preflight (before product edits)

Run/session/agent: 01a14f96-e637-7773-aa3b-74e44216f500. Fresh native caller identity;
not inherited process state. Original inputs remain under
`/tmp/cloud-t007-01a14f96/snapshot/initial/`. Manifest paths use `initial/` so
immutable read inputs do not overlap allowed output names (validator contract).

## Consumer enumeration

- install.sh: VALID_PLUGINS, help, fixed-point dependency closure, required-file
  validation, Git-index export, host registrations. install.ps1: ValidateSet,
  dependency switch, Get-RequiredPaths, tracked-file export and host registration.
- uninstall.sh/ps1: allowed/default plugin set, full-vs-partial removal; partial
  uninstall deliberately retains shared files/agents/MCPs. No new GC semantics.
- .agents/plugins/marketplace.json and .claude-plugin/marketplace.json:
  opt-in entry source/name/version; Codex AVAILABLE/ON_INSTALL policy.
- Each provider: .claude-plugin/.codex-plugin/.plugin/plugin.json (three host
  shapes), skills/orchestrate/SKILL.md (public explicit entry). No agent files.
- tests/validate-repository.ps1: expected plugins/versions/skills, mirrored name
  and version validation; currently case-insensitive name comparisons.
- tests/install.tests.{sh,ps1}, install-uninstall-matrix, installer-idempotency,
  uninstall and ci-claude-install suites: fixture export/registration inventories.
  tests/hooks/domain-model-visibility.Tests.ps1 supplies public-entry convention.
- scripts/bump-version.sh discovers manifests; release-wide version change is T008.
  run-all and bootstrap routing are T011; neither edited here.
- Provider scripts/cloud.py: explicit CLOUD_SHARED_RUNTIME_ROOT or sibling
  sdd-quality-loop/scripts. Versioned isolated caches need explicit trusted root
  or authorized packaging-only discovery. Existing execution unchanged.
- T009 final inventory: attempt-2/consumer-inventory.json and
  final-source-inventory.json; actual protected_selection in
  plugins/sdd-quality-loop/scripts/cloud_verification.py:571 resolves
  ../references/cloud-verification-registry.json. Package that exact registry,
  four shared modules (including T010 cloud_dependencies.py), cloud schemas,
  verification-contract-v3 and selected-verification-plan-v2 mirrors.

## WFI-001 field / counterpart / executed mismatch

Actual command: `python3 -B tests/install-cloud.tests.py`.
Result: exit 1, 5 test methods, 77 assertion failures; matched synthetic control
passes. `red-manifest.log` is the actual output. Tests invoke the verbatim existing
manifest-validation block from validate-repository.ps1 (not the unrelated global
workflow/agent prechecks). All mutated records and module/schema bytes are present;
no import/setup failure is counted. The old validator ignores unregistered cloud
records/mirrors: that acceptance is the actual failing assertion, NOT proof of an
existing per-field guard. Post-implementation controls/sensitivity must execute
every newly added check. Case-variant existing domain name also wrongly passes;
its existing version mismatch is rejected.

| Persisted field / packaging claim | Sibling counterpart | Executed failing mismatch test |
|---|---|---|
| Provider manifest name, version, skills (all three host manifests, both providers) | directory name, existing release 1.18.0, host skill path convention | ManifestBoundary.test_cloud_manifest_field_mismatches, each named provider/host/field |
| Marketplace name/source/version (both marketplaces/providers) | exact provider directory and host manifests | ManifestBoundary.test_marketplace_field_mismatches |
| Codex policy.installation/authentication | existing opt-in AVAILABLE/ON_INSTALL policy | same method, policy variant |
| Packaged four shared module bytes including dependency admission | canonical quality-loop scripts | ManifestBoundary.test_runtime_field_mismatches, each scripts/* variant |
| Packaged protected registry bytes | T009 final registry at quality-loop/references | same method, references/* variant |
| Packaged cloud schema, verification-contract-v3, selected-plan-v2 bytes | root cloud contracts / T009 canonical quality-loop contract mirrors | same method, each contracts/* variant |
| Existing manifest name exact case / release compatibility | sdd-domain directory/version | ManifestBoundary.test_existing_name_and_version_guards (name Red; version rejected as before) |

T007 introduces no authorization/receipt/result schema or cloud verdict fields.
Its verification claims will bind actual installed CLI/module paths and denial
results; public no-executor denial is distinguished from in-process dependency
validation. Existing predecessor and registry behavior is consumed, not replaced.
Report evidence identity/hash fields use existing manifest/report validators.
Live provider acceptance, host-model trial, independent review and quality gate
remain separate/root-owned; no PASS or Done claim is made here.

## Additional executed visibility Red before validator repair

`SkillVisibility.test_real_export_consumer_ignores_upstream_reference_skills`
fails in `red-visibility.log` (exit 1): validator counts 30 skills instead of 29,
including the existing pinned AWS reference skill outside exported skills/.
Field: public skill inventory/count; counterpart: manifest-exported skills roots,
not arbitrary SKILL.md files under references/. The test calls the real export
consumer block with actual populated provider packages. This is not missing
setup. Commit this failing test before narrowing discovery to exported roots.
