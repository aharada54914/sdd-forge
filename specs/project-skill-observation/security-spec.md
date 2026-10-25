# Security spec: Project skill execution methods and verification observations (#594)

DRAFT. Covers REQ-005 to REQ-010 and AC-002 to AC-006. Revised 2026-10-22
after an informal content review.

## Trust boundary

Project skill content and observations are untrusted inputs. They count only
after the passive validator recomputes every digest from current bytes. Stored
paths never confer trust.

A supplied `task-input-manifest/v1` is not proof of approval. Admission of that
manifest for the current run happens upstream, in the existing orchestration
and `validate-task-input-manifest.{sh,ps1}` (requirements G-5). Consumers
(#596) must establish that admission before they rely on a task-mode VALID.

## Threats and controls

| Threat | Control | Tests |
|---|---|---|
| Helper or admitted-input tampering after approval | closure sha256; in task mode every `allowed_inputs` entry rehashed to its pin regardless of ignore status | TEST-024, TEST-044, TEST-054, TEST-090 |
| Hidden or omitted helper in the skill tree | closure set equality, checked recursively | TEST-022, TEST-023 |
| Path escape or symlink redirection | semantic path grammar; no symlinks or special entries | TEST-014–TEST-020 |
| Outside helper or shell text via argv | fixed argv `[runtime, closure entry, literal args]`; args may contain no path or space | TEST-008–TEST-010, TEST-016, TEST-017 |
| Stale or replayed observation | run identity, manifest digest and source-set content digest | TEST-036, TEST-039, TEST-046–TEST-050 |
| Validator reading beyond admitted scope | reads only discovery, admitted-input, output-root and observation paths in the execution root | TEST-091 |
| Fabricated runtime resolution | `runtime_path` null when runtime missing or not run; required for executed outcomes | TEST-057, TEST-092–TEST-094 |
| Output source added, changed or deleted after a pass | every regular file under the output roots is in the source set; absent paths omitted (no index dependence) | TEST-048–TEST-050, TEST-056 |
| Observation invalidating itself; evidence used as input; unadmitted destination | only the run's evidence directory is excluded; evidence subtree rejected as input; destination must be covered by `allowed_outputs` | TEST-045, TEST-051–TEST-053 |
| Fabricated or ambiguous task input | digest equality, schema check, duplicate-path and overlap rejection; admission happens upstream | TEST-039–TEST-045 |
| Shadowing another skill | a collision fails discovery; there is no precedence | TEST-013 |
| Weakening obligations | no obligation field; the projection touches execution fields only | TEST-066–TEST-072 |
| Unknown or stale success becoming PASS | a single fallback clears all execution fields | TEST-063, TEST-064 |
| Trial evidence used for gating | trial observations are never projected | TEST-076 |

## Limits (stated, not solved by #594)

- **Runner claims.** Outcome, timestamps, exit code, OS, host and
  `runtime_path` are runner claims. That is the same trust level as today's
  contract `checks[]`. #594 adds binding, not attestation.
- **Run-time file access.** The validator executes nothing. It cannot prove
  what the entrypoint reads or executes at run time, or which program PATH
  resolved. Run-time enforcement belongs to the runner (#595/#596).
- **Unadmitted files.** Files that are neither admitted inputs nor under output
  roots, such as unrelated dependency caches, are runtime environment and not
  bound. An explicit admitted input is never in this class; it is always
  rehashed. Trial mode binds the skill closure only.
- **Execution root.** #596 composes it from the immutable snapshot and declared
  outputs via existing orchestration; #594 does not build it.
- **Commit.** `source.commit` is a runner provenance claim, never compared and
  never approval or provenance proof. Content binding comes from the tree digest.
- **Re-execution.** Independent re-execution stays with quality-gate.
