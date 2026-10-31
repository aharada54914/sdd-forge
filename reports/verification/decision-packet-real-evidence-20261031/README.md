# Historical MCP evidence through the main-candidate packet CLI

Seven real subprocess checks passed. `evaluate.py` saved the rubric in
`protocol.json` before invoking the CLI; `results.json` retains exact argv and
exit status, and each invocation has stdout/stderr files.

Candidate: `/workspace/scratch/sdd-forge-main-integration`, commit
`de09118d86efa79d3ab9fb8ab96db95932069fee`. Historical evidence source:
`/workspace/sdd-forge`, commit `b1c828355d3b3ff5633f23c4b1d8f28b030817b0`.
The source inventory pins each original path and copied file SHA-256. Historical
MCP observations and review data, v2/v3 HTML previews and feedback are copied
byte-for-byte. A unified HTML diff is generated explicitly for this evaluation.
The task file is a new Draft/Planned integration fixture, not a real approved task.

Checks: JSON validation and Markdown rendering pass; rendered original-log and
both preview paths/hashes resolve to the copied original bytes. Mutation of the
original response log, each of the two previews, or the selected packet rejects
with invalid-or-stale-packet and nonzero exit. Restoring bytes passes. Original
source files are never edited. The previews were not executed in a browser; this
checks inspectable local artifact reachability, not live-site UX or clickability.

Historical observations have no measurement bound to this new packet. They are
therefore displayed as `unknown`, with source evidence and an explicit reason;
no historical success is recertified. Historical owner feedback and choice are
also displayed as evidence only. Human alternative decision remains pending.
No signature, task approval, new human choice, human timing or current model
comparison is created. This is fixture-only contract integration, not #624
completion or the full real-app/human-time acceptance of #622.

Source CLI SHA-256 is ab9ab64ebbf546fc377a405ed2fcc0149110d0a94e87ea5ccdf3cec66ae096bb;
candidate CLI SHA-256 is f15788dd25e282de80c8611f6985820a7493a74d928fc2a93267a73abe9ebcbd.
The candidate additionally checks approved choice snapshot equality and roster
companions. The source lacks these checks. This evaluation invokes neither
signed-choice branch and makes no claim about that difference's acceptability.
The candidate's actual CLI was run, not a copied or modified implementation.

Raw files are retained byte-for-byte in `raw-evidence.zip`; `archive-index.json` pins every member. Absolute paths in the original logs retain their historical meaning. Extract into a new scratch directory before replay; the archived evaluator requires the two stated source checkouts.
