# RT002 original-wrapper rejection matrix progress

State: expected RED, not implementation approval or live activation proof.

The authorized recovery contract remains
`reports/verification/hook-recovery-entry-contract-20260909.md`. Production
Python and both original wrappers were not changed. No installed-cache edit,
copied validator execution, native canary dispatch, commit, push or merge was
performed in this slice. Older diagnostic-only human helpers remain stale;
their hash checks must not be removed to use them against these newer tests.

## Additions and measured results

Both existing original suites now add the same 47 cases / 94 assertions:

- Sixteen individual raw-envelope mutations: prefix, quotation, suffix,
  truncation, changed guard text, other target, extra operation, old patch,
  terminal newline, leading newline, CRLF, and five non-string JSON types.
- Twenty-two field mutations: every missing key, executed types/true,
  outer/inner/malformed nonce, recorded and CLI runtime mismatches, each
  extra plugin flag in both boolean states, and an arbitrary extra key.
- Eight response duplicate-member cases: each required key, nested duplicate,
  and contradictory executed values in both orders.
- A newly emitted challenge whose patch must equal the complete normative
  template with the same newly emitted nonce. It is not dispatched.

Existing positive, cleanup, stale-start and non-mutation tests are retained.
New PowerShell string assertions use explicit case-sensitive comparisons.

Commands from the repository root:

```sh
rtk proxy sh tests/check-hook-activation-handshake.tests.sh
rtk proxy pwsh -NoProfile -File tests/check-hook-activation-handshake.tests.ps1
rtk proxy git diff --check
```

| Original suite | Passed assertions | Failed assertions | Exit |
| --- | ---: | ---: | ---: |
| Shell | 153 | 58 | 1 |
| PowerShell on macOS | 152 | 58 | 1 |
| Whitespace | n/a | 0 | 0 |

Full logs: `hook-host-matrix-posix-red-20260909.log` and
`hook-host-matrix-pwsh-red-20260909.log` in this directory. Earlier raw-envelope
slice logs are retained separately. Both final suites complete normally and
their existing three-runtime positive activation fixtures remain successful.
No Windows-native result or coverage percentage is claimed.

The 36 extra failures over the preceding 22-failure baseline are sixteen raw
error-category assertions, eleven field-category assertions, eight response
duplicate-category assertions, and one emitted-patch assertion. Invalid raw
envelopes already fail closed, but under the old missing-plugin-flag category;
this is not evidence that those malformed envelopes were accepted. Existing
selector-fallback and cleanup duplicate failures do expose undesired success.

## Review input manifest

All paths below are relative to the repository root. Review is advisory and
independent, not a formal SDD gate or a task Done decision.

```text
878942094199aa2ae34de1c91a5968cb3019a2c83672d0e762964be5fcd835ad  docs/review-tickets/RT-20260909-002.yml
2ca4125082c495724b0bbde33e7451edb21fc4042827c1e67b4354eb9215e79f  reports/verification/hook-recovery-entry-contract-20260909.md
07834d4078fde6aa71820c6bed1789ba5d4e2f7fa6eee2d91d40b2195fb2099d  reports/verification/hook-evidence-contract-repair-20260909.md
d9277ca516fa79b6ef459e0d0505375624a0a9279c32390758a96650985d0064  plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py
c9a6a330238e8b466a3e08345affc3e0d51545091c84150ade94f8f8a7b06e12  plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.sh
5837fcfa74fd7ea277163df531e1b0d42841aa8a5f8ca68c2500f8e5d59a9f00  plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.ps1
56dfe05ec3372f12fd8162e68670c29b7cd6ed23a3f54984ea12c419b1001044  tests/check-hook-activation-handshake.tests.sh
2e03838d2cd52648ab4368a26837e21da79d550b3bd6af9715dfe72eb7f4043b  tests/check-hook-activation-handshake.tests.ps1
```

Independent reviewer: `/root/hook_contract_security_review`, existing contract
reviewer and not test author. Expanded test review requested; result pending
when this record was created. Complete remaining matrix gaps before production
repair, then review candidate and the hash-pinned human application helper.
Repair-specific formal provenance reviews and fresh original installed-path
host verification remain mandatory before ordinary entry can resume.

## Other PR / unPR status recheck

GitHub open PR heads remain unchanged: 401 at 135b1479, 400 at 8fa3eb85,
394 at 423edd3b, 390 at ade30494, 381 at 3971c93a, 371 at 9e39c396,
245 at 54b1ff24. No new queued/running checks were observed. PR400's committed
checks are green, but that does not validate the dirty repairs or resolve its
formal evidence requirements. PR245 remains conflicting and has no Actions
result in its rollup. Other five PRs retain failed required checks.

UnPR duplicate findings and the actual blocked original-guard probe remain
recorded in `issue295-unpr-selection-20260909.md`; do not create duplicate PRs
or claim either auto branch is already delivered. Previously completed remote
branch deletions remain recorded in `merged-branch-cleanup-20260909.md`.

## Follow-up: independent review gaps closed (same date)

The independent reviewer found no serialization defect but identified missing
syntax-isolated nonce checks, case-only raw mutations, and otherwise-valid
legacy Codex/Copilot fallback checks; it also reminded us of forbidden plugin
flag types. These were added, not substituted for existing checks:

- Four malformed nonces matched consistently across CLI, outer nonce and
  echoed patch: uppercase hex, 31 characters, 33 characters, and non-hex.
- Guard-signature and target-path case-only mutations.
- All seven schema selectors against otherwise-valid legacy Codex and Copilot
  evidence, including their required success fields (14 cases).
- Each forbidden flag with null, string, number, array and object (10 cases).

This follow-up adds 30 cases / 60 assertions per wrapper. The entire turn adds
77 cases / 154 assertions per wrapper over the earlier initial slice. The
historical counts and hashes above remain the earlier reviewed snapshot, not
the current test files.

Current hashes:

```text
b1c3349821bb5a1a67543239eed8b32090b70126f2b52d11cb3654d080be96df  tests/check-hook-activation-handshake.tests.sh
a84200632214187c8d37de43876b9802fed074d0888157815493c738042c213b  tests/check-hook-activation-handshake.tests.ps1
```

Original-wrapper reruns both completed with exit 1: Shell **169 passed / 102
failed**, PowerShell on macOS **168 passed / 102 failed**. Full separate logs
are `hook-host-matrix-expanded-posix-red-20260909.log` and
`hook-host-matrix-expanded-pwsh-red-20260909.log`. These remain expected RED,
not a passing product. Production Python retains the manifest hash above.

Independent follow-up reviewer `/root/hook_contract_security_review` verified
both current hashes and reported all listed gaps resolved with no remaining
concrete defect in the additions. The review was read-only: no independent
execution, production candidate assessment, formal gate verdict or live proof.

Next implementation boundary: create the approved minimal candidate under
RT002 after its high-risk persisted-field preflight, then independently review
the candidate and replacement hash-pinned human helper. Do not apply or execute
a protected candidate through a renamed/copied alternative. Formal repair-only
provenance reviews and original installed-path fresh native dispatch are still
required; no other PR is made merge-ready merely by this test review.
