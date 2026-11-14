# Installed model-selector registry resolution

The marketplace plugin cache contains each plugin under its own version directory. Both selector front doors previously reached three parents upward for `contracts/agent-model-capabilities*.json`; that directory is not part of the plugin package. The PowerShell policy bridge also assumed an unversioned quality-plugin sibling.

The implementation plugin now ships exact mirrors of the canonical v1 and v2 capability registries. Source-layout selection keeps the original root contracts; standalone and versioned plugin selection uses the package's own contracts. Explicit registry arguments are unchanged. Policy-mode PowerShell resolves the same-version quality-plugin native argument helper. No model, tier, effort support, availability claim, or policy was added to either registry.

`before-after.json` reproduces the failure using the pre-fix selector bytes and the fixed bytes in the same isolated versioned package: Bash and PowerShell both change from exit 1 (`MODEL_SELECTION_ERROR`) to exit 0. The fixture has poisoned consumer and cache-parent contracts to catch fallback to the wrong authority.

The final package suite has 8 passing tests, covering both shells, canonical mirror byte equality, versioned and standalone installs, legacy default v1, policy default v2 and its PowerShell bridge, explicit v2 selection, preserved explicit overrides, missing-package failures and rejection of unregistered models. Policy observations and costs in these tests are explicitly synthetic fixture inputs, not native availability evidence. The separate full-session host discovery supplies actual model availability.

Commands:

```sh
export PATH=/workspace/.tools/sdd-forge-dev/bin:/workspace/.tools/rtk/0.51.0:$PATH
python3 tests/model-selector-package.tests.py
bash tests/agent-capabilities-v2.tests.sh
pwsh -NoProfile -File tests/agent-capabilities-v2.tests.ps1
bash tests/agent-model-routing.tests.sh
python3 tests/verification-catalog.tests.py
```

All commands passed; logs and command results are retained here. `model-selector-package-final.tests.log` includes the final standalone test added after the initial 7-test run. Syntax and `git diff --check` passed.

For the normal unmanaged route, a registered v2 model can be selected without caller-supplied tiers:

```sh
bash "$implementation_plugin/scripts/select-agent-model.sh" \
  --risk "$task_risk" \
  --registry "$implementation_plugin/contracts/agent-model-capabilities.v2.json" \
  --candidates-file "$observed_candidates" --host codex-cli --json
```

Candidate IDs and availability must come from actual host evidence; cost remains the existing invocation estimate. This fix does not assert arbitrary model capability from its name or introduce managed-routing fallback. It does not redesign the separate root-installed managed launch-controls inventory.
