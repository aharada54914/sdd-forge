# Issue 137 current-checkpoint Ubuntu regression

Run ID: issue137-ubuntu-current-20260930
Task: T-001; implementation remains In Progress.

Source commit: `1b934c06dde2342c9102c0daf1a4e0b5ee088ddf`. An archive of its context module, context tests and contracts was extracted into a fresh guest directory only after archive generation and digest verification succeeded. Archive SHA-256: `e2a6f429bdc3bc933a4cc752b106373ff33d32835ae9d7f92f10a5387b5a783f`.

Actual environment: Ubuntu 24.04.5 LTS, Linux 6.8.0-142-generic, aarch64, ext4; Lima guest without host mounts. Node 24.13.0 and RTK 0.42.4 archives were checked against their publishers' downloaded checksums before extraction. The VM was stopped after private evidence collection.

`rtk proxy node --experimental-vm-modules --test tests/sdd-context/*.test.mjs` completed with exit 0: **207 passed, 0 failed, 0 skipped**, 5,865.609672 ms. This includes the independently confirmed registry-owner admission checks, POSIX store preparation and synthetic Windows dispatch tests. Input digest checks after execution all passed; captured evidence checksums also passed after transfer.

Captured stdout SHA-256: `ca527319b24ca94009e13d0e6498d0ad86f7a569dcd83540953fd48117f66e33`; input-digest list SHA-256: `dc7b52dc3243fc478b1968de5e4c208cc55824f5b2784eece0191cd546b7289e`. Stderr was empty. Raw host-identifying evidence remains private.

This is current Linux execution, not the older 205-test checkpoint and not native Windows proof. The experimental VM-module flag is required by the synthetic dispatch tests. Windows creation-time ACL/junction checks, cold Node-to-PowerShell execution within 1,000 ms, complete T-001 acceptance, formal verification, CI, merge and issue closure remain pending. No approval, frozen review input or task status was changed.
