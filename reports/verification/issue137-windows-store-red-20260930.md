# T-001 Windows new-store synthetic RED

Source: c0cf516b3cea89bde5912c7fa6aef9f5438e95d0.
Environment: macOS Node; synthetic Windows module dependencies.
Command: `rtk proxy node --experimental-vm-modules --test tests/sdd-context/windows-store.test.mjs`.
Actual result: exit 1, 0 passed, 2 failed, 0 skipped.

WINDOWS-DISPATCH failed with content-free `validation-rejected` because the existing POSIX-only preparation rejects the synthetic Windows process. WINDOWS-ADAPTER failed its assertion “Windows adapter is absent”. These are absent dispatch/adapter behavior failures, not native ACL proof. VM experimental warning was emitted. No production edits preceded this run.

Native Windows creation-time ACL, existing target preservation, junction/opened-identity behavior and full T-001 completion remain pending. No workflow, installer, frozen specification or task status changes.
