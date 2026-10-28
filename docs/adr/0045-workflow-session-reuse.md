# ADR-0045: Bound reuse of full workflow-state checks

Status: Proposed. This describes a candidate implementation for #615; it is not
an approval, a Done decision, or a measurement of overall workflow improvement.

The existing Bash checker accepts an optional `--batch <request.json>` with a
`workflow-state-batch/v1` object containing only `schema` and 1–50 distinct
`requests` labels. It invokes the existing supervised project-skill runner.
Each label denotes a full repository workflow-state check. It does not replace
other gates, task approval or independent review. The normal Bash and PowerShell
entry points and their ordinary full checks remain available.

For example, write `{"schema":"workflow-state-batch/v1","requests":["one","two"]}`
outside the captured repository and call
`bash plugins/sdd-quality-loop/scripts/check-workflow-state.sh --batch /path/to/request.json`.
Exit 0 means the batch's full checks succeeded; exit 1 means a check failed;
exit 2 returns `cold-required` and requires an ordinary full check. A malformed
or mixed-scope CLI invocation is rejected before any batch execution.

The Linux-only candidate captures the complete selected repository tree,
including hidden and untracked files, fixed checker and schema bytes, supervised
runner code and fixed system tools. It rejects symlinks, special files, ACLs,
unsupported filesystem operations, excess sizes and unresolved dependencies. Captured
files are sealed into memfds and mounted privately in a bubblewrap process;
network access and inherited credentials are absent. Current file and directory
identities and exact contents are rechecked after execution and at the end of the
batch. A second request can reuse only an actual successful execution from this
same process with the identical sealed snapshot. Failed checks are re-executed;
no externally supplied receipt or PASS flag can authorize reuse.

The snapshot cannot safely evaluate history-dependent Git reconciliation or
conditional external validators. The checker marks these paths as ineligible;
the batch returns `cold-required` with no prior PASS and the caller must run the
ordinary full check. Host/runtime failures, changing inputs and unsupported
platforms also fail closed. The candidate Bash checker is pinned by SHA-256;
any later change requires a fresh dependency audit before its pin is updated.
The pin is an implementation guard, not independent review.

The result uses `workflow-state-batch-result/v1`, with the source run, execution
or reuse reason, full-snapshot digest, timing, exit code, output bytes and hashes.
Request and observation files should be outside the captured tree. No local or
remote persistent cache is introduced. The caller is responsible for running
all remaining checks and for repeating verification after edits.

Current evidence is limited to local sealed-sandbox tests and existing workflow
regressions. Hosted CI, Windows/macOS execution of the optional batch, a full
lifecycle measurement and any half-time target remain unverified. A three-repeat local synthetic comparison found the batch slower despite
fewer full executions. One clean actual checkout exceeded the file cap and
required a successful ordinary fallback. See
`reports/verification/workflow-session-main-20261028/`.
The batch is not a general command cache and makes no claim about faster Done evaluation.
