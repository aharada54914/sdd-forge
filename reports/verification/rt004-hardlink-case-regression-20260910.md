# RT004: ordinary hardlink and exact-name regression

Date: 2026-09-10
Status: original-path RED; staged correction is not applied or verified GREEN.

## Executed evidence

Command: `rtk proxy bash tests/impl-review-adr-inputs.tests.sh --admission-path-only`

Terminal session 6359 completed with exit 1: **32 passed, 28 failed**.
Test SHA-256: `da53831219d0818eac521b7585877afdd1a6b2850699e855bff31b89e419a77c`.
Both Bash and local macOS PowerShell ran against original product paths,
for both implementation-reviewer roles. This is not native Windows evidence.

The four new fixture modes account for 16 checks:

| Runtime | Correct-name hardlink, precheck/design × both roles | Wrong-case name, precheck/design × both roles |
| --- | --- | --- |
| Bash | 4 passed | 4 failed: incorrectly accepted, fixture ledger appended |
| PowerShell | 4 failed: incorrectly rejected as symbolic link | 4 passed |

The other 44 checks retained 24 pass / 20 fail. No failure is counted as PASS.
The new modes use empty ADR sets and pinned unchanged content so ADR allowlist
rejection cannot hide the path behavior. Positive fixtures assert same-file
identity and absence of symlinks. Negative fixtures move the original away and
create only the case-variant hardlink. On case-sensitive filesystems those
negative cases also encounter missing canonical names; this host's Bash
acceptance demonstrates the case-insensitive alias was reachable here.
Only temporary fixture ledgers were modified, not the repository identity ledger.

## Cause and candidate delta

The input traversal at
`plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1:530`
rejects every non-null LinkType, including HardLink. The new final hunk of
`reports/verification/adr-runtime-lexical-candidate-20260909.patch` allows
HardLink only for implementation review while always rejecting ReparsePoint.
Other-stage predicates and manifest/ledger/gate-report predicates are unchanged.
This is not an atomic-acquisition fix; the complete held-handle backend remains
required. Bash exact-name checks are already proposed in the staged reader,
but root/Data support remains incomplete.

Candidate SHA-256: `8c59a0b467ac976eb173f23f01622cfe39eae57cca37276e1b9cdd21591290b1`.
`git apply --check --unidiff-zero` and `git diff --check` exited 0.
The first applicability check without `--unidiff-zero` failed because this
existing bundle uses zero-context hunks; no files were applied by either check.

Independent delta review requested from the existing RT004 reviewer. No formal
PASS, ticket resolution, protected application, commit, push or merge occurred.
Next: incorporate review findings, finish the acquisition backend, then review
the complete bundle before human application and original-path GREEN tests.

## Independent finding and corrected execution

The independent reviewer found a fixture Warning: the original wrong-case
negative also used a hardlink, so PowerShell could reject it solely for LinkType.
The earlier four PowerShell case successes therefore do **not** prove exact-case
enforcement. Preserve that observation above as superseded, not a passing claim.

Case fixtures now use two moves, leaving one ordinary file under the variant
name and no second hardlink. Setup checks the actual enumerated name, absence
of the canonical name from enumeration, regular-file/non-symlink type, and logs
whether the canonical spelling reaches the same file.

Final test SHA-256:
`1325ebc680c940823e61a03f9e08f3ae5f9049293cdbf9433c55eea0b982818b`.
The same original-path command completed in session 50987 with exit 1:
**28 passed / 32 failed**. All eight wrong-case fixtures logged
`exact-variant-name=true canonical-alias-reachable=true` and incorrectly
returned success in both runtimes. PowerShell still incorrectly rejects the
four positive hardlink fixtures. Bash accepts all four positive hardlinks.
The other 44 results remain 24 pass / 20 fail.

The limited candidate hunk received no new Critical/Major findings in the
independent static review. The same independent reviewer verified the final
test hash and confirmed its prior Warning resolved. It did not execute tests;
the runtime observations above are the primary agent's execution evidence.
This is not candidate execution or formal PASS. No production source changed.

## Isolated human application handoff

The direct protected-source edit was denied by the active hook. No alternative
executor or cache edit was used. The original source remains SHA-256
`832a00cbd9d9516f990411a684c5f671e8b8d5e92cc8f96d0ed9de4828c38187`.
The previously independently reviewed hardlink hunk is now isolated as data in
`reports/verification/rt004-hardlink-only-human-20260910.patch`, SHA-256
`3d4bfa890895c7553591d9001085e47b0ff41fe3d40ebd1c7245d3c472ac4d4c`.
`git apply --check` on this isolated patch exited 0; this is applicability only,
not production application or runtime verification. A subsequent memory-only
postimage-hash calculation was also denied; no postimage hash is claimed.

Human operation: verify both hashes, back up this one original file, apply only
the isolated patch, and return the diff/checksum. Original-path regression
execution belongs to the agent after application. Existing case/root path
failures remain unresolved and must not be counted as passing. The full lexical
candidate is incomplete and must NOT be applied; rebase its overlapping final
hunk after the limited human application.

The latest user clarification excludes administrator mount manipulation from
the threat model. Previous native acquisition proposals are not proof that such
complexity is necessary; reconcile the design against concrete ordinary-process
mutation and same-bytes validation requirements before further implementation.

## Human application and original-path regression

Human reported successful hash checks and application, backup directory
`/tmp/sdd-rt004-hardlink.x8kpTJ`. The primary agent independently read the
resulting source SHA-256:
`977fd6ac16e4f2b37e11dcd42178b69a2b81addd2fba43483447171927c7ec8e`.
The test source remains `1325ebc680c940823e61a03f9e08f3ae5f9049293cdbf9433c55eea0b982818b`.

Executed the same original-path `--admission-path-only` command in terminal
session 67441, completed exit 1: **32 passed / 28 failed**. All four PowerShell
positive hardlink cases changed from FAIL to PASS. Bash's four hardlink cases
remain PASS. All sixteen precheck/design leaf/parent symlink rejection checks
remain PASS. The eight legacy/zero-bound controls remain PASS. Remaining
failures are twenty root syntax/alias checks and eight exact-case checks;
both runtimes still incorrectly accept them and append only fixture ledgers.
This verifies the limited correction, not the full ticket or native Windows.

Removed the now-applied final hardlink hunk from the incomplete lexical DATA
candidate to avoid duplicate application. Its new SHA-256 is
`8af353703ed532f2b6e9f6a7211db4f4435a03cd0c3117a2be67ad65588dab66`;
`git apply --check --unidiff-zero` exited 0 against the current source.
No other candidate hunk changed. The full candidate is still not ready for
application. No ticket resolution, formal PASS, commit, push or merge occurred.
