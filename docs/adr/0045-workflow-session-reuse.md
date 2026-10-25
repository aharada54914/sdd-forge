# ADR-0045: Reuse sealed full-workflow executions within a bounded batch

Status: Accepted (limited Linux execution profile)

Issues #615/#618 require eliminating repeated measured-heavy full workflow checks
without replacing existing selection, independent review or cheap contract/bundle
validation. The existing full checker owns an optional `--batch <requests.json>`
entry. It delegates bounded execution to its session module and reuses the existing
project runner's subprocess supervision. Lite promotion is not a Full coordinator
and is unchanged. There is no daemon, disk cache, remote service or model-review
cache. Arbitrary build/test commands are not admitted to this profile.

## Inputs and execution

The request uses workflow-state-batch/v1 with only `schema` and `requests`, one to
50 distinct string labels. Labels identify callers; they grant no task or review
authority. The module captures every file/directory in the selected repository,
including hidden, dirty, untracked and Git data, with names, modes, exact bytes
and filesystem identities. Symlinks, ACLs, special files, excessive count/size and
noncanonical registry paths are ineligible. The complete selected tree, installed
checker/schema, issuer code, fixed runtime, caller environment hash, kernel/Python
identity, cwd and registry/command identity bind the result. There are no
mtime-only hits. Stat identities detect ABA changes during capture/execution.

The canonical Bash checker is admitted only when the **actual captured bytes**
match the audited checker digest. Changing its code requires re-auditing this
restricted dependency closure before updating that digest. A separate preliminary
read is insufficient: independent review reproduced an inode-switch race that
could otherwise audit one program and execute another.

A host staging directory mounted readonly would still allow host mutation. Instead,
sealed Linux memfds feed bubblewrap `--ro-bind-data`; private copied files have no
mutable host backing. Each child's gate, schema, repository and system tool bytes
are those hashed and sealed. The existing supervisor accepts only fully sealed
input descriptors, keeps its status pipe separate, and retains its original
behavior when no descriptors are supplied. Copies preserve canonical absolute
paths for existing manifest bindings. Private procfs/dev support Bash process
substitution; network and inherited credentials are absent. Private tmp supports
existing temporary-file use. No production writes are introduced.

The first profile uses Linux bubblewrap, system-owned Bash/jq/coreutils and their
resolved ELF loader/libraries. It fixes PATH/LC_ALL/LANG/TZ/HOME/TMPDIR instead of
claiming arbitrary environments equivalent. UTF-8 positive/negative conversion
and process substitution run inside the sandbox before admission. The installed
system tools and host administrator remain trusted. Unknown or unavailable
runtime dependencies fail closed, with no host-directory bind fallback.

## Eligibility and final binding

Git history reconciliation and conditional external validators cannot be evaluated
in this restricted profile. The existing checker marks those branches before any
historical no-Git tolerance and propagates a dedicated exit 75 across feature
subshells. The batch returns `cold-required` (exit 2), no earlier PASS, and the caller
runs the ordinary full checker. Ordinary CLI behavior, Bash/PowerShell parity and
Full/Lite/legacy rules remain unchanged. Only the optional batch has this narrower
Linux profile; Windows/macOS and larger/symlink-bearing trees remain cold.

Only an actual successful execution retained in the current process can be reused.
The second request must have an identical fresh fingerprint, retains the original
run ID, timestamps and raw stdout/stderr, and identifies that no new execution
occurred. A second process always runs cold. Failed scans are not cached. The
batch publishes once, after all requests and a final full re-fingerprint. A mutation
invalidates prior results; it never falls back to an old success. No saved JSON,
receipt, timestamp or caller-supplied PASS is loaded as execution authority.

`workflow-state-batch-result/v1` records full-workflow scope, actual origin runs,
sealed input identity, raw-output hashes and reuse relationships. This is an API
result, not a new generic observation system: use the existing run-measurement
owner to collect comparative timings and existing contract/bundle checks to
validate required evidence. The caller still performs all other required checks,
keeps independent reviewers independent, and repeats verification after edits.
The batch request/output/measurement files belong outside the checked tree so
recording observations does not change the input under assessment.

## Limits and evaluation

The initial bounds are 4,096 files, 256 MiB, at most 50 requests, and the existing
runner timeout/output limits. Capturing a giant working checkout is intentionally
not optimized by omitting ignored files. Historical Passed Full fixtures can be
ineligible even when the ordinary checker passes; that is not a measured speedup.
Compare cold/warm total wall time including sealing, runtime probes and repeated
fingerprints. Preserve #614's original workload separately from eligible workloads;
do not alter approval/status records to manufacture cache hits or claim a global
half-time result. Further per-spec incremental evaluation or broader command
caching needs evidence of benefit and a separately proven dependency closure.

The first actual comparison found no half-time result. The frozen #614 repository
had 19,069 files and stayed cold: two ordinary full checks took 78.003 s, versus
79.237 s including batch refusal and ordinary fallback (one pair). A separate
48-Pending-Full workload showed median 2-request time 1.388→1.575 s, 5-request time
3.293→2.562 s, and 10-request time 6.347→3.588 s. Thus the optional procedure is
restricted to cases with measured total-time benefit; two-request batches are not
a default recommendation. These are local component timings, not a new full
lifecycle benchmark or proof of faster Done evaluation. The original approval
records were not changed. See reports/verification/workflow-session-comparison-20261025/.
