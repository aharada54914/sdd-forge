# RT002 remaining fixture completion

Date: 2026-09-09 JST. Recovery-only RT-20260909-002 work.

## Change and authority

Added three cases to each original wrapper suite, retaining all previous
checks: new response schema with both CLI and recorded runtime set to Claude;
the corresponding Copilot case; and truncated new-response JSON. The two
runtime cases include their legacy-success fields and assert exit 64,
UNRECOGNIZED_RESULT and CAPABILITY_RUNTIME_UNAVAILABLE. The truncated JSON
case asserts exit 61, RECORDED_RESULT_UNREADABLE and unavailable status.

No product source, historical verdict, approval field or task status changed.
This completes the two narrowly identified advisory review Warnings; it does
not certify all 109 proposed specification rows or implement the adapter.

## Executed checks

| Command | Result |
| --- | --- |
| `rtk proxy sh -n tests/check-hook-activation-handshake.tests.sh` | exit 0 |
| PowerShell Parser.ParseFile on original .ps1 suite | exit 0, no parse errors |
| `rtk proxy sh tests/check-hook-activation-handshake.tests.sh` | exit 1, 190 passed / 211 failed assertions |
| `rtk proxy pwsh -NoProfile -File tests/check-hook-activation-handshake.tests.ps1` | exit 1, 190 passed / 211 failed assertions |
| `rtk proxy git diff --check` | exit 0 |

Both runs used macOS and original wrappers; this is not native Windows proof.
Sessions 20254 and 3695 are terminal. Each full log has 403 lines (401
assertions plus two summary lines). Previous logs remain untouched.

Compared with preceding RED runs (187 / 205), the new runtime fixtures add
six failing assertions and the truncated JSON case adds three passing ones
per wrapper. The old verifier actually returns HOOK_ACTIVE for both new
runtime fixtures. This proves the tests detect the unauthorized fallback;
the failure is not reclassified as product success. Prior RT002 failures
remain unresolved until reviewed production application.

Full logs and SHA-256:

- rt002-matrix-completion-red-shell-20260909.log:
  66781ab478822f434277b36afd8f5440ad8fe853e2977b948b74d04af414e81a
- rt002-matrix-completion-red-powershell-20260909.log:
  2680ea38e8f55111241f629be0f5cce1ef7b1376d9bf3fd4933224971edcd297
- rt002-matrix-completion-inputs-20260909.sha256:
  c5a88896909b641f5638f4b97636219e440cb68af5708f0e930492a414171812

## Independent advisory follow-up

Reviewer identity: existing independent agent
`/root/hook_contract_security_review`. Read-only inspection; no execution or
authoring. Reviewer verified current test hashes and unchanged product hash:

- Shell: bf0ca7472e4fc508f5e7da34c3559be79c620e89bb4744441cbb449d798d0dcd
- PowerShell: 9506cb7c0605ab37355ba697d8b40129e7492755cb633964532503c79ca47d05
- Product: d9277ca516fa79b6ef459e0d0505375624a0a9279c32390758a96650985d0064

Actual outcome: both previous Warnings resolved; no Critical or Warning in
these additions. This is NOT formal SDD PASS, full-suite coverage certification,
or live activation proof. The previous input manifest remains historical;
the new manifest above binds the current files.

## Remaining entry condition and other-PR authority

Human publication of the scoped spec amendment remains outstanding via
rt002-spec-human-application-20260909.md. Then complete repair-specific
provenance reviews, reviewed protected production application, both original
suite GREEN runs and a fresh native host challenge/denial/verification. No
unrelated integration is admitted before the recovery contract exit.

User's additional #403 decision is explicitly recorded here for handoff:
“#403 は「契約をリスク判定の正本とし、tasks.md と不一致なら拒否する」方式で修正してよい”.
This authorizes that risk-authority choice and mismatch rejection, not unrelated
RT-20260828-001 falsy-value semantics or automatic alteration of frozen reviews.
No #403 implementation or ticket-status change occurred in this recovery step.

#404 run 34288587300 was rechecked during the local tests: Windows version-gates
still in progress, overall run in progress. Existing three native failures
remain. No retry, push, merge, issue closure or branch deletion performed.
