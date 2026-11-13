# Quality exact declarations before conditional prefixes — #743

The actual Full T-003 delivery rejected `design-system/build/tokens.css` before reservation despite its exact path/SHA declaration in the implementation report. The unchanged historical diagnostic and exit/command record are preserved here. The optional concept-test branch intercepted the path before the ordinary quality delivery declaration could authorize it. Both Bash and PowerShell shared the ordering defect.

The fix uses the already-supported quality output, gate-output and supplemental declaration channels before conditional prefix checks. It does not make a whole directory trusted. An undeclared conditional path still goes through the unchanged conditional resolver. Report/task/feature binding, exact SHA checks, path safety, forbidden raw-reviewer reports and identity reservations remain enforced. Other reviewer stages gain no admission. Reading an exact declared input is not a gate PASS, a concept-test approval, or permission to modify the file.

Paired canonical-admission tests now explicitly cover generated token CSS, all three design-system source documents, domain/concept artifacts, gate outputs, undeclared/stale outputs, mismatched supplemental hashes, links, other stages and forbidden reviewer reports. All 39 tests pass through both Bash and PowerShell. Role authorization parity separately passes 65 checks in each runtime. The existing broad review-context boundary suite is recorded separately; final results are in `results.json`.

Commands use the installed PowerShell shim (`/workspace/.tools/sdd-forge-dev/bin/pwsh`) on Linux. This is not native Windows PowerShell 5.1 evidence. No runtime cache or pinned historical calibration was overwritten by this change. Full/SQLite resume owners copy only the two source validators into new immutable run snapshots and perform fresh native delivery. The historical rejected invocation is not retroactively promoted or reused as a successful review.

## Actual Full invocation after repair

The Full resume owner copied runtime v9 into a new v10 snapshot and replaced only the two validators. Both Bash and PowerShell preview the original failing T-003 invocation successfully (`REVIEW_CONTEXT_OK`, exit 0), without reserving an identity. The unchanged 279 other source assets and existing calibration pins are recorded in the copied provenance. This confirms admission on the actual consumer inputs; it is not a substantive evaluator verdict or task completion.

The broad boundary suite completed with exit 0, including named-anchor mutation controls, both-runtime JSON/identity/path/FIFO negatives, existing domain/ADR binding and reservation-history checks. Its three reported case groups contain 116, 84 and 84 passes respectively; the complete log retains the other named controls.
