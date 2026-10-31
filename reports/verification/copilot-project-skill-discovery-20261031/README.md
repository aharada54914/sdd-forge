# Copilot native project-skill discovery

Copilot CLI 1.0.105 discovered the generated project skill: absent before
projection, present with the exact generated name after projection, and absent
after cleanup. All six commands returned zero. The isolated temporary workspace
was removed and product sources remained unchanged.

This is discovery-only evidence from source 363aa6e3. No model invocation,
authentication, result reading, Claude execution, or complete #602 acceptance
is claimed. `result.json` in the archive records exact source hashes, arguments,
CLI version and wrapper hash. The wrapper hash is not the full native binary
closure. The later executable-bit fix is outside this historical run.

`raw-evidence.zip` retains the evaluator, generated canonical documents and raw
stdout/stderr unchanged. `archive-index.json` pins every member and original
scratch prefix. Extract into a new scratch directory for inspection; replay
requires the original CLI and source paths, and produces a new result.
