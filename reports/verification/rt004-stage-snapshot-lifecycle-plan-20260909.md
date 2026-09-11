# RT004 stage-owned snapshot lifecycle

Status: lifecycle delta authored as patch data; not applied or approved PASS.

## Candidate update after deterministic RED

The composed Bash candidate now carries the stage-owned subshell, caller-owned
snapshot directory and ADR bindings, explicit HUP/INT/TERM exits, exact current
precheck/summary snapshot mapping, and separate contract/precheck identities.
The historical calibration helper accepts an optional fifth evidence identity;
both manifest JSON lookups retain its first (snapshot) argument. Other Git pin
consumers receive the original selected contract identity.

Candidate SHA-256:
`707df63e253eb90805ac9d209bc5295bf017d15befe32cfa34c1b6a94fbce5fb`.
All 18 patch hunk old spans, counts and offsets were compared with the supplied
source text. `git apply --numstat` parses 533 insertions / 18 deletions. Neither
check applies, extracts or executes the candidate; no runtime PASS is claimed.
Independent review was requested from the existing snapshot reviewer. Human
protected application, regression execution and CI remain outstanding.

Scope note: previous-summary snapshots are acquired for ADR-extended later
rounds. Legacy rounds without the extension retain their prior-summary behavior;
this candidate does not establish coherent reads for every legacy prior summary.
The late-contract defect and historical-pin preservation controls are the
immediate original-path regression obligations after application. All broader
verification obligations below remain open; historical design notes below are
retained, with this dated candidate update taking precedence on authoring status.

## Deterministic late-read RED established

`rt004-late-contract-mutation-red-20260909.md` records an original-path Bash
execution where an omitted required calibration reservation is repaired only
after the real reviewer/output consistency read. The static omission is
rejected, but the late replacement is incorrectly accepted. Both controls and
the mutation boundary are verified. This is the previously missing product RED
for contract read continuity, not a mocked helper verdict. The next implementation
step is the reviewed stage-owned snapshot lifetime and original-identity split;
other snapshot inputs and cleanup/signal coverage remain required.

## Prefix received: concrete path dependency

The human supplied lines 1–699 in
`/Users/jrmag/.codex/attachments/9bd3bf9c-03f6-464f-80de-eeec2652bdac/pasted-text.txt`.
Its before/after reported SHA-256 is
`15a4ef0a72c8be78c40b38e692ee7a46d8664d825e61ab99915086dae0f02d1e`.
Together with the earlier excerpts, the requested source is now available;
the source-acquisition blocker below is superseded. These are human-supplied
hash observations, not an independently computed atomic snapshot.

Inspection confirms a real location dependency, not merely a hypothetical
one: `plugins_pin_commit` accepts only evidence paths under REPO_ROOT and
uses their relative path in `git log --diff-filter=A`. Redirecting the
contract argument to a temporary snapshot would reject a legitimate historical
plugin-reference pin. `resolve_verified_investigation_pin` uses the same
function; the amendment-growth reconciliation would likewise fail.
`manifest_has_hash_for_file` mixes JSON reads and this historical lookup in
one contract argument. In contrast, `manifest_has_hash`,
`manifest_recorded_hashes_for_path`, `manifest_has_reviewed_hash`, and
`recorded_repo_root` read contract JSON without deriving its on-disk identity.
Evidence: the supplied prefix definitions of these named functions, especially
the REPO_ROOT case and git-log invocation in `plugins_pin_commit`.

Amendment to proposed steps 5–8:

- Save the selected original contract path before redirecting any read path.
  It is the history identity, never a caller-selected substitute.
- Pass that original identity to `plugins_hash_matches` and
  `investigation_amendment_reconciles`; they do not read the contract JSON.
- Extend `manifest_has_hash_for_file` with an explicit optional fifth argument
  for the original evidence identity (defaulting to its first argument for
  unchanged callers). Its manifest reads must use the snapshot first argument;
  only `plugins_pin_commit` uses the fifth argument. Do not reopen the original
  contract contents or introduce a dynamically scoped fallback variable.
- Keep the JSON-only helpers on the snapshot contract. Preserve logical
  precheck and summary identities as already described below.

Required additional regression: a Git-bearing fixture with a uniquely
introduced contract and legitimately changed plugin reference must retain
historical acceptance after snapshot redirection; forged hashes, ambiguous or
uncommitted evidence identities must still reject. Exercise the same split for
growth-only investigation reconciliation, including a non-growth rejection.
These cases must prove the history fallback was reached, rather than pass via
a matching live hash or a history-less fixture. Existing no-history behavior
is not changed by this amendment. No test result is claimed here.

The earlier advisory disposition covers only the outer boundary. This newly
identified helper change still needs independent contract/security scrutiny
and regression coverage before protected application.

### Supplied call-site inventory

Attachment line numbers below identify the supplied text, not new production
line numbers. This separates the three history-sensitive calls from ordinary
JSON reads and prevents a blanket argument replacement.

| Call site | Supplied attachment / line | Contract argument after redirection |
| --- | --- | --- |
| `recorded_repo_root` | `92ed9379…/pasted-text.txt:148` | Snapshot JSON path |
| `plugins_hash_matches` | `92ed9379…/pasted-text.txt:229` | Original selected contract identity |
| `investigation_amendment_reconciles` | `92ed9379…/pasted-text.txt:242` | Original selected contract identity |
| `manifest_has_hash_for_file` | `0a31403f…/pasted-text.txt:133` | Snapshot JSON plus original identity as fifth argument |
| `manifest_has_reviewed_hash` (impl) | `0a31403f…/pasted-text.txt:154` | Snapshot JSON path |
| `manifest_has_reviewed_hash` (task) | `0a31403f…/pasted-text.txt:193` | Unchanged task contract path |

Regression design must cover a plugin-reference pin in the manifest loop and
the later calibration-specific helper separately. A successful manifest-loop
test alone would not prove that the fifth-argument forwarding works.

### Prefix-based independent advisory disposition

`/root/rt004_snapshot_static_review` inspected the supplied prefix and amended
plan. No new Critical/Major was identified in this limited path-separation
design; this is not implementation verification or a formal PASS.

Its required counterexamples are retained:

- With a mismatching snapshot manifest, changing the original contract JSON
  to matching content after capture must not rescue validation. Both initial
  and historical-fallback manifest checks must read the snapshot.
- With a mismatching live plugin hash, a legitimate historical pin selected
  by the original contract identity must still be accepted.
- History lookup runs Git against SCRIPT_ROOT, not REPO_ROOT. Merely creating
  a Git repository in a registry fixture does not prove that lookup used the
  intended history. A test must establish the actual consulted history while
  respecting original-path execution restrictions. Do not create artificial
  commits in the user's repository or execute a relocated validator merely to
  make this fixture convenient. Until an authorized deterministic test seam or
  suitable existing history establishes this branch, mark it unverified.

This resolves the missing-source and helper-design questions. Candidate
implementation, lifecycle/fallback regression execution, formal review and
integration remain outstanding. The composed candidate hash remains
`fee3d720fc6b3517e5e4a9fe474d86bc838d6b62f684cec2b61e5b4da7ebff34`;
no executable code was changed during this prefix-inspection step.

## Newly supplied evidence

The human supplied the remainder (line 1020 through EOF) in
`/Users/jrmag/.codex/attachments/0a31403f-bfb4-4860-9086-0ded5565c6c8/pasted-text.txt`.
Both reported hashes equal
`15a4ef0a72c8be78c40b38e692ee7a46d8664d825e61ab99915086dae0f02d1e`,
matching the preceding 700–1020 excerpt. The complete outer function and its
feature-level caller are now visible. No further source request for this tail
is needed. These are supplied observations, not an atomic source acquisition.

The tail shows three sequential validate_passed_stage calls in one feature
subshell. It also reveals a second reconstruction of precheck-result.json
after the reviewer-output jq, used for required-input hashes and layer pins.
Changing only round_precheck is insufficient.

## Proposed change boundary

1. Preserve review-root selection and the unconditional stage_is_being_opened
   call in validate_passed_stage's existing shell. This preserves the verified
   opening state used by the following stages in the same feature invocation.
2. Start a nested subshell immediately after that unconditional call, ending
   immediately before validate_passed_stage's closing brace. All downstream
   checks and early successful opening returns execute within that lifetime.
   No other state assignment in the supplied tail is relied upon by the three
   stage calls; this must still be checked in review and regression tests.
3. Invoke the history acquisition helper directly inside the nested subshell,
   not through command substitution and not through a helper-owned subshell.
   Give its output two caller-owned variables: the verified ADR binding JSON
   and the private snapshot directory. The helper must not shadow them with
   local declarations. Do not transmit executable shell assignments or eval.
4. Allocate the snapshot directory with umask 077 and terminal XXXXXX. Register
   cleanup in the stage subshell immediately after successful allocation; keep
   it live until every later stage read completes. Name only the known snapshot
   files, remove the now-empty directory, preserve a failed status and make
   cleanup failure nonzero. Do not replace a live parent trap or recursively
   remove an unvalidated directory. Explicit signal handling and allocation
   failure need tests; SIGKILL cannot promise cleanup.
5. For impl only, rebind contract, verdict, reviewer A/B and summary read
   variables to the verified snapshot files. Keep round_dir, root and manifest
   identities referring to the original repository paths. Run the saved-state
   validation before the existing opening early return, as in the old candidate.
6. Rebind BOTH round_precheck and the later precheck read to the acquired file.
   Keep a separate original logical precheck path for manifest suffix matching
   and diagnostics. The early legacy /dev/null fallback remains where it was;
   the later PASS path still requires its precheck, as the supplied tail does.
7. In the manifest-input loop, preserve the original manifest_relative and its
   path safety checks. Reads/hashes of the current round precheck and summary,
   and an acquired previous-round summary, must use the corresponding snapshot
   bytes rather than reopen the originals. Do not indiscriminately map ADRs,
   calibration, design or layer inputs to temporary paths.
8. Retain source-stability comparisons during acquisition; snapshots provide
   later read continuity, not an atomic/no-follow acquisition guarantee.
   The current-declaration check consumes the snapshot contract. All old
   failures, reservations and review outputs remain unchanged.

## Verification obligations before protected application

- Existing 118-case suite remains intact; last actual result is 14/104 RED.
- Add deterministic acquisition-to-consumption mutation coverage, separately
  for contract/verdict/reviewers/summary/precheck and prior summary. Require
  either consistent verified-snapshot evaluation or explicit rejection, never
  acceptance based on unchecked replacement bytes. A control must prove each
  mutation actually occurred at its intended boundary.
- Exercise opening state propagation across spec → impl → task with the same
  previously permitted stale-byte tolerances and unchanged omission rejection.
- Exercise normal success, opening early return, invalid evidence, allocation
  failure, cleanup failure and supported signals; prove private files are gone
  where cleanup is possible and failures cannot become successful exits.
- Preserve absent legacy precheck versus missing required PASS input behavior,
  original logical manifest identities and unchanged non-impl validation.
- Use original-path authorized execution only, not extracted/copied validators.
  No candidate GREEN, Bash 3.2, native Windows or full parity is claimed.

Independent review is requested before authoring the lifecycle delta. This
plan does not close RT004, supersede mandatory checks or permit integration.

## Parent call-site audit

In the second supplied attachment, lines 122–142 reconstruct the original
precheck and derive two logical suffixes from its path. Lines 159–179 reuse
its JSON layer pins. Keep a logical precheck identity separate from its read
path throughout all those uses, not merely the first jq slurp.

The contract is also passed to existing helpers (`plugins_hash_matches`,
`investigation_amendment_reconciles`, `manifest_has_hash_for_file`, and
`manifest_has_reviewed_hash`). Their call sites alone do not prove that moving
the contract read path to a temporary directory preserves helper behavior.
Before implementation, confirm from authorized source evidence whether they
derive other paths from the contract location; if they do, carry original
logical identity explicitly. Do not infer path independence from their names.

The proposed read redirection is therefore not yet implementation-ready.
The supplied outer-tail blocker is resolved; helper path semantics and the
new regression boundary must be settled without bypassing denied reads.

## Independent disposition

The existing independent reviewer `/root/rt004_snapshot_static_review` reviewed
this plan and both supplied excerpts. No concrete Critical/Major defect was
established at the visible caller boundary. It confirmed that the nested
subshell must be the final function command so its cleanup-adjusted status
is propagated, and prior-summary mapping must match its complete relative
path, not its basename. The missing helper definitions prevent an
implementation-ready conclusion. This was read-only advisory review, not a
formal PASS or runtime proof. No production or candidate code was modified.

To avoid further fragmented requests, the remaining original-source prefix
can be supplied in one read-only operation:

```bash
cd /Users/jrmag/sdd-forge || exit 1
/bin/bash <<'BASH'
set -eu
source_file='plugins/sdd-quality-loop/scripts/check-workflow-state.sh'
/usr/bin/shasum -a 256 "$source_file"
/usr/bin/sed -n '1,699p' "$source_file"
/usr/bin/shasum -a 256 "$source_file"
printf '\nRead-only prefix collection complete. Send all output to Codex.\n'
BASH
```

Together with the two existing excerpts this covers the entire reported
source revision, including the helper definitions. Do not repeat acquisition
of the protected source through another tool or executor.
