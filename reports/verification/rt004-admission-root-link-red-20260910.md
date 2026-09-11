# RT004 repository-root symlink regression

Status: RED; not a quality-gate verdict.

Original-path command:

```sh
rtk proxy bash tests/impl-review-adr-inputs.tests.sh --admission-path-only
```

Session 86809 completed with exit 1: `ADR admission: passed=24 failed=4`.
Test SHA-256: `e8796c42d476fe1c3a5958ee277889c1a9415ca6169a0b294d5f4c6247aeb8d0`.

The new `path-link-root` fixture supplies a symlink to its already-built
repository as the validator root. Both the link and its target are inside the
fresh test fixture directory. Descendant files, input hashes and contracts are
unchanged. No protected validator is copied or executed from another path.

| Runtime | Role | Actual exit | Expected exit | Synthetic ledger unchanged |
|---|---|---:|---:|---|
| Bash | impl-reviewer-a | 0 | 1 | false |
| Bash | impl-reviewer-b | 0 | 1 | false |
| PowerShell | impl-reviewer-a | 0 | 1 | false |
| PowerShell | impl-reviewer-b | 0 | 1 | false |

All 24 existing controls and child-path symlink checks still passed. The four
new cases returned REVIEW_CONTEXT_OK and appended sequence 2 to their synthetic
ledgers. These are test ledgers, not evidence of a production-ledger mutation.
`bash -n tests/impl-review-adr-inputs.tests.sh` also exited 0.

This reproduces stationary root-symlink acceptance, not an initial-open race.
It is macOS PowerShell evidence, not native Windows evidence. The proposed
anchored-read design requires a root bootstrap policy; that policy and its
compatibility consequences still require resolution. Do not infer that a child
path helper alone repairs this result: normalization may have already removed
the supplied root's lexical identity.

The unapplied admission candidate remains NEEDS_WORK. Its SHA-256 remains
`0cfa88d533f22b4940bd90626329846411e09e494b92533fdccd80504e2b9ba1`.
The separately applied workflow PowerShell validator remains
`291ee7531594757d6ebc04c144bb8b35938f7715ae76665c9bdf723df09b1ff5`.
The earlier workflow-history 137/0 result and JSON-only 20/32 result retain
their own scopes. No CI, commit, push, merge, or review verdict was changed.

## Original-path revalidation after human root/hardlink application

Date: 2026-09-11. This addendum preserves, rather than replaces, the earlier
24/4 root-symlink observation above.

Executed `rtk proxy bash tests/impl-review-adr-inputs.tests.sh --admission-path-only`
in the canonical repository. Tool session 16469 completed with exit 1 and
`ADR admission: passed=52 failed=8`. No copied validator was executed.

Observed source hashes:

- Bash validator: `97deb3c9eeec2e8cf3689f547512ad96c6f266a7f28d5875c20d9098a31698b9`.
- PowerShell validator: `b58df1ddfb5ae7d4c8bc31b6a32fe222780b582d529d8759c8d234dd730d2db3`.
- Test driver: `ba009da41ae2d6f6216c751e846eb0a2d00163f83aa5e01bb787c70fb61628c2`.

For both runtimes and both implementation-reviewer roles, only
`path-case-precheck` and `path-case-design` failed: actual exit 0, expected
rejection, synthetic ledger unchanged=false. The fixture setup separately
confirmed an exact variant filename existed and its canonical-case alias was
reachable. The remaining 52 controls/negative cases passed, including root
symlinks, ambiguous root components and accepted exact-name hardlinks.

This is macOS evidence (including PowerShell on macOS), not native Windows
verification. It demonstrates stationary case-alias admission, not an actual
concurrent attack and not the necessity of the proposed Darwin ACL bridge.
ADR 0034's clarified complexity limit remains applicable: establish a concrete
contract conflict before adding that optional bridge. Neither this run nor a
candidate text inspection establishes atomic acquisition or same-bytes review
dispatch. No implementation candidate, formal review, CI or merge is passed
by this addendum.
