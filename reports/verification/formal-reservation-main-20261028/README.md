# Bounded reservation verification on main

Source revision: `45c203f0aff9e4481845649a34530a0c04ccc52f`. The
verification covers the pinned Bash reservation tail described in the
project-local `verify-review-reservation` skill, not the full application.
The two-contender, one-attempt model assumes atomic directory creation and
same-directory rename, and excludes crashes, retries and Windows semantics.

The prior 2026-10-25 result used the `v1.8.0` asset with SHA-256
`d15655eeaff4b3f7b3d65c46b838bc0f35d131b2ef4b1e473689b62c98d4726f`.
On 2026-10-27, GitHub's
[release metadata](https://api.github.com/repos/tlaplus/tlaplus/releases/tags/v1.8.0)
reported the replacement asset created 2026-10-26 23:14:29 UTC with SHA-256
`78f7e2c6bf9a8b65eda665a23e94431255587e0b43a834a4e2af1723562d9b4a`;
the downloaded bytes matched that digest. This result is a new verification
with TLC build `2026.10.26.231022 (rev: fad899c)`, not a reproduction of the
earlier asset's result.

The negative model produced an invariant counterexample and the corresponding
real-code lock-removal replay accepted two contenders. The intact model passed
and its real-code replay accepted one. See `report.json` and the two TLC text logs.
The command in the skill was also repeated independently in a fresh output
directory with the same expected outcomes.

The first two observations above used a short child-side barrier; under a slow
start that barrier could time out and fail to reproduce the intended race.
After review, the negative replay was changed to wait for explicit parent
release only after both contenders pass the hash check. The
`synchronized-report.json` and matching TLC text logs record a fresh run:
the mutated replay accepted two contenders and the intact replay accepted one.
Separate tests delay one contender and force a synchronization timeout.
