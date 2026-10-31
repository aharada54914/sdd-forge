# T-001 Windows new-store synthetic GREEN

Environment: macOS, not native Windows. Source after RED-only commit: `88de4a38`; production changes are uncommitted at this check.

- `rtk proxy node --experimental-vm-modules --test tests/sdd-context/windows-store.test.mjs`: 2 pass, 0 fail, 0 skip. The actual module source ran with synthetic Windows platform and child-process dependencies.
- `rtk proxy node --test-name-pattern=NEW-STORE- --test tests/sdd-context/validation.test.mjs`: 5 pass, 0 fail, 0 skip. These are the existing POSIX new-store regressions, not Windows proof.
- PowerShell AST parsing: helper and native test passed.
- Literal `Add-Type` C# block: compiled on macOS without calling Win32.

Not run: native Windows helper test, real Windows `OwnerV1` end-to-end `prepareStore`, <=1000 ms cold-start assertion, junction/ancestor race probes. Cold `pwsh` + `Add-Type` compilation may exceed the core deadline and fail closed. No same-SID ancestor-race immunity or T-001 completion is claimed.
