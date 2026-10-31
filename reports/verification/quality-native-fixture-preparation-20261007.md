# Quality synthetic native-driver preparation

Scope: option 2 local launch-path verification; `tests/unified-launch-native.py` only.
Owner: `/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge`.
HEAD: `25813ee4baf8ae8fff344a6c979da61fbd23d2c7`.
Existing checkout is dirty with concurrent owners; preserve all existing changes,
including the driver's spec/task/impl branches. No production source edits.

Risk: fixture-only diagnostic extension exercising high-risk launch boundaries.
Contracts: quality invocation v2, canonical preview, separate evaluator scratch,
raw input hashes, immutable production ledger and evaluator role. The canonical
Opus role remains unchanged. Only a disposable copied role uses Sonnet; its
result cannot establish formal quality approval or production review completion.

Planned validation: syntax and argument branching first; after shared source pins
are fixed, canonical preview without reservation and source-ledger equality.
External/native execution requires the coordinating owner's later instruction.
No frozen evidence, task state, approval, reservation or verdict is changed by
preparation. CI, native delivery and formal evaluation are not yet verified.

Executed local checks: Python in-memory syntax compilation passed; six CLI
argument/help checks passed; `git diff --check` passed. Driver SHA-256:
`c2ba6997ba0fab6ea4eee246fbf8fb682c9bca1c33e7737344ed35f55aaef7cb`.
The new `--quality --prepare-only` branch stops after canonical preview;
`--quality --run-native` additionally invokes the shared launcher. Neither
branch has been executed yet: shared-source copying and canonical preview await
the coordinator's fixed-source notification. Existing spec/task/impl function
bodies are unchanged. No live delivery or formal quality result is claimed.
