# RT004 POSIX root spelling: isolated human handoff

Status: candidate only; not applied or runtime verified.

Candidate: `reports/verification/rt004-posix-root-candidate-20260910.patch`
SHA-256: `2b81bc746e059a0b287052f7c1054dbc739f219e1151f3a42aa46c0d0ab237dd`.

The current original-path admission suite has 32 passes and 28 failures
(see `rt004-hardlink-case-regression-20260910.md`). Twenty failures concern
root spelling/root leaf aliases; eight concern exact-case input names.
This candidate addresses the first category, not the entire RT004 contract.
Exact-case descendant acquisition, race guarantees and native Windows proof
remain incomplete. No previous FAIL is reclassified.

The independent RT004 contract reviewer found no new Critical/Major in this
isolated DATA diff. Its two verification limits were checked by the primary
agent against current original source: PowerShell lines 175–247 contain
manifest/stage/identity checks, with the next root consumption at line 248;
Bash lines 210–294 likewise perform manifest/stage/identity validation, not
execution of the earlier root-consuming function definitions. Existing
PowerShell `ConvertFrom-Json -AsHashtable` already requires PowerShell Core;
the new `$IsWindows` check does not introduce Windows PowerShell 5 support.
Local runtime was PowerShell 7.6.2, not native Windows.

Original hashes checked before handoff:

- Bash: `04e01b60cac4b8ccda12df069013a6052cd6825a1430256d59ccdf837a3af2f8`
- PowerShell: `977fd6ac16e4f2b37e11dcd42178b69a2b81addd2fba43483447171927c7ec8e`

`git apply --check --unidiff-zero` exited 0. This is applicability only.
The implementation edit was previously denied by the active protection hook;
RT-20260908-004 explicitly requires human instructions instead of an alternate
executor after denial. The helper below must therefore run in the human's
terminal, not through an agent tool:

```bash
rtk proxy bash /Users/jrmag/sdd-forge/reports/verification/rt004-posix-root-human-20260910.sh
```

It verifies exact source and candidate hashes, backs up both sources in a
fresh directory, then applies only this patch. It does not alter review
verdicts, commit, push or merge. If a check fails, stop and return the output.
After application the agent must run the original-path admission regression,
check remaining boundaries, and rebase the overlapping incomplete lexical
candidate before any subsequent use. Do not apply that larger candidate.

## Applied-state observation and original-path tests

Subsequent read-only inspection found the sources updated. The isolated patch
no longer applies forwards, and `git apply --reverse --check --unidiff-zero`
exits 0. No reverse application was executed. Observed source hashes:

- Bash: `97deb3c9eeec2e8cf3689f547512ad96c6f266a7f28d5875c20d9098a31698b9`
- PowerShell: `b58df1ddfb5ae7d4c8bc31b6a32fe222780b582d529d8759c8d234dd730d2db3`

First original-path admission run (session 60048) exited 1, 44 passed /
16 failed. This run is confounded: the native TMPDIR ends with `/`, while
test line 5 appends another separator. Its supposedly ordinary roots contain
`//`. All sixteen positive controls fail the new root grammar, and case/link
negatives can be rejected before reaching the intended check. Do not count
these negative successes as evidence for case or link enforcement.

Controlled rerun kept the same physical temporary-directory parent, with only
its trailing separator removed via the command environment:

```bash
rtk proxy env TMPDIR=/var/folders/7z/hjmz6jdj4wb40srf64sl368w0000gn/T bash tests/impl-review-adr-inputs.tests.sh --admission-path-only
```

Session 70524 completed exit 1: **52 passed / 8 failed**. All twenty root
syntax/leaf-link regressions now pass, all sixteen positive controls pass,
and all sixteen descendant link negatives pass. Eight wrong-case negatives
still incorrectly succeed and append fixture ledgers. Thus root repair is
supported by this subset, while exact-case enforcement remains broken.
Test SHA remains `1325ebc680c940823e61a03f9e08f3ae5f9049293cdbf9433c55eea0b982818b`.
No source or test was edited for this rerun; native Windows remains untested.

Next: repair the harness's ordinary temporary-root construction without
normalizing intentionally malformed negative roots; retain the default-env
failure as baseline. Rebase the incomplete lexical DATA patch before use.
Full RT004, recovery activation, formal gates, CI and integration are pending.

## Default-environment harness correction and rerun

The ordinary fixture parent is now resolved with `pwd -P` before `mktemp`,
and its trailing separator is removed before appending the template. The
intentional malformed-root and link/case fixture inputs remain unchanged.
The existing `set -euo pipefail` retains failure on parent resolution or
temporary-directory allocation failure. This is a test-harness correction,
not a relaxation of the implementation root grammar.

Test SHA256:
`ba009da41ae2d6f6216c751e846eb0a2d00163f83aa5e01bb787c70fb61628c2`.
`rtk proxy bash -n tests/impl-review-adr-inputs.tests.sh` exited 0.

The default-environment command, without a TMPDIR override, was:

```bash
rtk proxy bash tests/impl-review-adr-inputs.tests.sh --admission-path-only
```

Session 35975 completed with exit 1: **52 passed / 8 failed**. The twenty
root tests, sixteen positive controls (including hardlinks), and sixteen
descendant-link negatives pass. The eight exact-case negatives still
incorrectly accept and append fixture ledgers. Those cases report
`exact-variant-name=true canonical-alias-reachable=true`.

This covers Bash and PowerShell on macOS, not native Windows. The primary
agent's narrow harness review is not an independent formal gate. Previous
failed runs remain failed; full RT004, formal review, CI and main integration
remain incomplete.
