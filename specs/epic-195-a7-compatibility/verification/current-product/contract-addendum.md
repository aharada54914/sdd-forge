# Current-product compatibility contract

This addendum describes the current acceptance implementation for Issue #195.
It does not revise the historical reviewed specification, approval hashes,
canonical baseline, golden capture scripts, or their recorded execution results.

The original byte suite ran the pinned pre-capability snapshot again for both
F1 and F2. A current generator changed to print unexpected output and exit 42
still produced a successful 25/0 result. That was historical reproducibility,
not a test of the current product's absent-Context fallback.

The existing byte-identical twins now execute the indexed **working-tree
bytes**, including uncommitted edits, in each real F1/F2 fixture directory.
The selected product root supplies every executed script and payload input.
F1 has no Project Context or marker; F2 retains its `spec_profile: lite` marker.
Both invocations run without ambient `SDD_*` variables under fixed timezone,
locale, and an isolated home. Historical capture caches cannot skip execution.

All nine categories remain tested twice:

| Category | Independent expected result |
| --- | --- |
| deterministic-script-output | Historical raw stdout/stderr tuple |
| exit-code | Historical successful status |
| stdout-stderr | Historical raw stdout/stderr tuple |
| template-copy-result | Current indexed template source paths and SHA-256 bytes, collected before execution |
| schema-validator-result | Historical successful status from the **real** current domain-contract validator, plus mandatory rejection of an invalid contract |
| install-result | Current indexed source bytes in the documented FilesOnly root layout, with MCP excluded by SkipMcp |
| uninstall-result | Historical empty installation root |
| generated-directory-listing | Current indexed generated-path inventory, retaining every historical required artifact |
| plugin-manifest | Current indexed plugin manifest paths and SHA-256 bytes, collected before execution |

The generated inventory includes the existing `gate-capabilities.json` added
since the historical four-file snapshot. It is validated as an exact current
source-backed path, not ignored as an unexpected file. Missing historical
artifacts, extra generated output, extra installed files, missing files, and
corrupt copies fail the comparisons.

The source fixture follows the existing installer acceptance harness's bounded
payload: specification/report archives are excluded because they are test
history rather than runtime payload. `tests/fixtures` is excluded as in the
public release layout, including its platform-specific symlinks. The development
repository's root `AGENTS.md` and `sdd/` project metadata are omitted so the
actual F1/F2 project inputs are preserved. A product checkout with its own
Project Context and approver registry must not populate the absent-Context
fixture. If the running product creates Context, the capture still fails. The F2 marker is untracked project input, not release payload. All
other indexed source files are copied byte-for-byte, and FilesOnly installation
must reproduce the independently declared payload exactly. Expected manifests
never read installed/copied output or reuse installer implementation logic. The
existing installer suites remain responsible for general full-release payload
installation and platform-specific filesystem behavior; this bounded F1/F2
fixture is not a claim that every repository archive was installed.

Six CLI cells compare both live documents with independent FULL/LITE outcomes:
explicit flags win; otherwise only the lite marker selects LITE. Agreement
between two incorrectly edited documents is insufficient.

`tests/current-byte-capture.tests.py` exercises the production capture helper
with real current executables. Regressions cover current generator failure,
actual fixture cwd/marker delivery, valid and invalid validator behavior,
missing/extra/corrupt installation payload, copy and directory-listing drift,
uncommitted input updates, project-metadata isolation, forbidden Context
creation, stale-cache bypass, and jointly incorrect CLI
contracts. Existing loop registry/driver/consistency/escalation suites retain
ownership of orchestration compatibility; no parallel loop architecture is
introduced. Live LLM generation remains non-gating per REQ-002 and AC-031.

The executable T-003 mutation harnesses now construct valid current product
fixtures, prove their unmutated controls, and require the targeted failure
diagnostic. Missing dependencies or non-Git product directories cannot count
as successful mutation detection. Historical execution logs remain unchanged.
