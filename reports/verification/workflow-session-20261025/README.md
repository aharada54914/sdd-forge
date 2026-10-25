# Sealed full-workflow batch verification

The existing checker now offers an optional bounded Linux batch; normal CLI
behavior is unchanged. The shared process owner supervises actual sandboxed gate
execution. Sealed memfds and private copied mounts bind exact bytes; the second
identical request can reference the first real run without another full scan.
Only current-process successes are retained, and the final fingerprint must still
match. This is full-workflow evidence, not approval or a substitute for other gates.

- Session suite: 9 tests passed, including real execution/reuse, independent
  invocation cold start, sealed bytes under host mutation, ABA, input addition /
  movement, environment drift, audited-code mismatch, symlink rejection, invalid
  state parity, request validation and rejected unsealed descriptors.
- Existing project runner: 35 passed. Acquisition: 30 passed / 1 local distinct-UID
  skip (the shared-reader test separately passed hosted CI). Catalog: 46 passed /
  1 skip. Guard parity: 419 passed.
- Independent Linux Bash/PowerShell parity passed. Passed Full historical fixtures
  remain cold-required: raw sealed code 75, public batch code 2, no published PASS.
  Invalid/boundary diagnostics match normal checks. Pending Full is equivalent
  and reuses only within the same process.
- Independent review reproduced an audited-file race: a separate read could audit
  original code but admit another inode. The final implementation audits the very
  captured bytes passed to the sandbox. Red and Green results are preserved.
- Actual FD probes show sealed writes denied, unsealed inputs rejected and private
  caller descriptors absent from the child. Input descriptors do not remain in
  the final sandbox command after bubblewrap consumes their bytes.

Independent scripts retain their original local scratch paths as run evidence;
repository tests are the maintained portable regressions. inputs.json contains
source hashes and is not reusable execution authority. Runtime-unavailable hosts
explicitly skip sealed behavior tests / return cold-required; no Windows/macOS
sealed-runtime execution is claimed. Review code should not infer whole-app
correctness or a performance target from these bounded results.

See ../workflow-session-comparison-20261025/ for actual timings. The original
large workload is cold-only, and the measured cases did not meet a half-time goal.
