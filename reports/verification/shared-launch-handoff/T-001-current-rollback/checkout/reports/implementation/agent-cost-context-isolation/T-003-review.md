# Independent Review: agent-cost-context-isolation T-003

## Verdict

**FAIL**

Reviewer: `T-003-independent-reviewer`
Review scope: exactly T-003
Reason: two Critical snapshot-boundary defects allow a published snapshot to
remain mutable or to resolve through a parent symlink. T-003 must not advance
to the quality gate until these defects are fixed and independently retested.

## Input Integrity

The review manifest
`reports/implementation/agent-cost-context-isolation/manifests/T-003-review.json`
was read first. All 16 declared allowed-input SHA-256 values were recomputed
before use and matched. No chat-only or unlisted task input was used. Only this
manifest-declared review report was written.

## Findings

### Critical — Published snapshots are writable

Both snapshot builders publish files with writable mode
`-rw-r--r--`; neither builder makes the completed tree read-only before
publication. An adversarial check successfully replaced the content of both
published `data/input.txt` files with `changed`.

This violates REQ-007, the design's immutable snapshot contract, and the
security specification's atomically published read-only snapshot boundary.
Hash verification during copying does not protect the agent from mutation
after publication.

Affected locations:

- `plugins/sdd-implementation/scripts/prepare-task-snapshot.sh:137-149`
- `plugins/sdd-implementation/scripts/prepare-task-snapshot.ps1:90-96`

Required action: make every copied file and directory non-writable before
publication, verify the final tree's modes/ACLs, and add paired tests that
attempt post-publication mutation and require failure. If host sandboxing is
the actual enforcement boundary, T-003 must implement and test that boundary
rather than publishing a writable snapshot and calling it immutable.

### Critical — Validators follow parent symlinks inside the snapshot

Both validators check only the final input item. A fixture where
`<snapshot>/specs` was a symlink to an external tree, while the final
`input.txt` was a regular file with the declared hash, returned
`TASK_INPUT_OK` in both Bash and PowerShell.

An external target can therefore be changed after validation while the agent
continues to read it through the snapshot path. This defeats repository
containment and immutability despite the final-component symlink checks.

Affected locations:

- `plugins/sdd-implementation/scripts/validate-task-input-manifest.sh:148-157`
- `plugins/sdd-implementation/scripts/validate-task-input-manifest.ps1:83-89`

Required action: walk every snapshot-relative path component without following
links/reparse points, bind validation to an opened regular-file identity, and
verify containment beneath a non-symlink snapshot root. Add the same parent
symlink fixture to both committed suites.

### Warning — Calendar-invalid timestamps are accepted

The schema and both validators accepted
`2026-99-99T99:99:99Z` as valid. The checks enforce only the textual shape, not
an actual ISO-8601 UTC instant.

Affected locations:

- `contracts/task-input-manifest.schema.json:60-63`
- `plugins/sdd-implementation/scripts/validate-task-input-manifest.sh:57,119-120`
- `plugins/sdd-implementation/scripts/validate-task-input-manifest.ps1:32-36,65`

Required action: parse strictly as an invariant UTC timestamp, reject
normalization and impossible dates/times, require exact round-trip canonical
form, and add paired boundary cases.

### Warning — Ancestor and output/output overlaps are accepted

Both validators accepted an input `specs/demo/input.txt` with output
`specs/demo` (no trailing slash), and simultaneously accepted outputs
`reports/` and `reports/out.md`. The current overlap logic treats only a
trailing-slash output as a directory root and never compares outputs with one
another.

Affected locations:

- `plugins/sdd-implementation/scripts/validate-task-input-manifest.sh:158-168`
- `plugins/sdd-implementation/scripts/validate-task-input-manifest.ps1:92-103`

Required action: compare normalized path components and reject every exact,
ancestor, or descendant overlap across input/output and output/output sets,
independent of a trailing slash. Add paired cases for both orderings.

### Warning — Atomic no-overwrite publication is check-then-rename

Normal pre-existing destinations and an injected destination created before
the final check were rejected. However, both builders still perform a separate
existence check followed by `rename`/`Move-Item`, leaving a TOCTOU window in
which no-overwrite is not atomic.

Affected locations:

- `plugins/sdd-implementation/scripts/prepare-task-snapshot.sh:142-144`
- `plugins/sdd-implementation/scripts/prepare-task-snapshot.ps1:95-96`

Required action: use a platform-appropriate atomic no-replace primitive and
test a destination created at the publication boundary. Do not rely on
`exists`/`Test-Path` immediately before a replacing move.

### Warning — TDD evidence does not preserve the claimed negative matrix

The red log demonstrates only the first missing-script failure. The green log
claims a paired temporary negative matrix for scalar roots, overlap, parent
symlink, and related cases, but neither its fixture nor its command is
persisted in the allowed test files. The committed Bash and PowerShell suites
omit several of those cases, and the missing coverage allowed the Critical
parent-symlink and writable-publication regressions above.

Required action: commit the full paired negative matrix, including the new
adversarial cases, then regenerate reproducible red/green evidence with exact
commands and results.

## Verification Results

- Allowed-input SHA-256 verification: **PASS (16/16)**
- JSON syntax and Bash/PowerShell parser checks: **PASS**
- `tests/task-context-isolation.tests.sh`: **PASS**
- `tests/task-context-isolation.tests.ps1`: **PASS**
- Task-ID, traversal, missing fields, scalar outputs, unauthorized output,
  chat-only handoff, malformed cost, hash tampering, and batch identity:
  **PASS in the existing paired suites or focused checks**
- Source mutation during copy: **PASS**; both builders failed closed
- Existing snapshot / injected destination before final publication check:
  **PASS**; both builders failed closed
- Parent symlink in source input: **PASS**; builders failed closed
- Parent symlink in validated snapshot: **FAIL**; both validators accepted it
- Post-publication mutation: **FAIL**; both snapshots were writable
- Calendar-invalid canonical timestamp: **FAIL**; both validators accepted it
- Input/output and output/output ancestor overlap: **FAIL**; both validators
  accepted it
- Bash/PowerShell diagnostic-category parity: **PASS for exercised rejection
  cases**; the three acceptance defects are also behaviorally paired

Native Windows reparse-point, ACL, and move semantics were not available on
this macOS host and remain unverified.

## Gate

Critical findings: **2**
Warnings: **4**
Suggestions: **0**

**Final result: FAIL — return T-003 to implementation.**
