# T-002 execution evidence details

This addendum concretizes the approved CI contract. It does not activate categories or alter the workflow. Protocol fixture evidence is never hosted/native proof.

Receipt artifacts use `verification-receipts-<run_id>-<source_attempt>-<job_key>`, where job_key is lowercase SHA-256 of canonical UTF-8 JSON `{name: <exact expanded Actions job name>}` (sorted keys, compact separators, no newline). The collector resolves the digest against the raw API job.name. Aggregate independently expands the revision-bound workflow job/matrix into that exact name and verifies the unique API job. Explicit workflow names expand matrix expressions; implicit names use job ID plus parenthesized matrix values in workflow axis order, separated by comma-space. Matrix-free implicit jobs use the job ID alone. Name collisions on either side fail closed, including omitted axes, reordered values and deceptively similar names. Receipt files reside at `artifacts/<artifact_name>/<member>.json`. The manifest binds each file to original execution `job_id` and `source_attempt`, not a copied rerun observation's replacement ID.

All jobs pages for every attempt through the run's current attempt are collected. Pagination requires same origin and same resource, finite pages, consistent total_count, no duplicates and no cursor loop. Failed historical executions remain evidence. New API IDs/reported attempts with unchanged logical runner/step/time identity inherit the original execution only when the historical match is unique. Original receipt absence or ambiguous history fails.

`verified`, `executed`, `unrelated-category`, and `advisory-inactive` are additional closed result reasons, paired with schema/consumer tests. Acquisition emits only observations, never a verification PASS. Result schema also carries the strict error envelope for exit 2. Exit 1 reports evidence or execution failure; exit 2 reports malformed mandatory contract/input.

Bounds are implementation safeguards, not truncation: any overflow fails collection. ZIP members are validated completely before publication. No raw logs, authentication tokens or signed redirect URLs are persisted. GitHub `gh api` GET uses the admitted API headers; storage redirects must not forward GitHub authentication.

T-003 consumes this grammar when uploading existing runner receipts. No receipt payload fields are added, and runner behavior is unchanged.
