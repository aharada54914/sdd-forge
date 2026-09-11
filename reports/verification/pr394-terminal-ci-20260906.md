# PR394 terminal CI observation

Head: `423edd3b0f9f6710e1de00183e4040fdd8de8ef3`.
Run: `34023439393`.

Live GitHub query (tool result 89dd1f) confirms the run completed with failure.
`test (windows-latest)` and the aggregate `required-checks` failed; all other
listed jobs succeeded. This is no longer an active run to wait on.
The earlier observed Windows near-boundary failures remain unresolved; no
deadline or assertion was weakened, and no merge or automatic retry occurred.

Related diagnostic PR400: `gh pr checks 400` (e42552) reports all 25 Actions
checks passed at its existing head, but CodeRabbit's pass-labelled result says
`Review skipped: draft pull request`. It is not independent-review approval.
PR400 still needs its formal verification and current-base integration checks.
