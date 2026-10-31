# Issue 290 — current-byte identity wording candidate

Non-formal preparation evidence. Protected application NOT RUN. No new identity reservation, reviewer turn, formal verdict or task-state change. Existing dirty work and the previous candidate/helper are preserved.

## Why this is a new candidate

The old human helper stopped on an original-hash mismatch and is not recommended for application. Its expected boundary hash `003180de314177a2d5c6de0ee119e65dcebe4f4dd38178f72088160edc215057` was not found in any of the 15 versions returned by this checkout's file history. The old preimage has NOT been recovered; the exact old-to-current diff is unknown.

The current boundary has no working-tree diff and exactly matches commit `4f02bc83368d7b9d2cc4409cbd759f2bab1ccae4`, whose Git-recorded author is aharada54914. Its parent-to-commit diff adds the implementation-only hash-bound ADR extension and updates source-line citations. This is evidence of the current committed content, not proof that it explains the old helper's unmatched pin. The current boundary was read in full. Its ADR, manifest, reservation-chain and scratch-isolation text is retained byte for byte by the new insertion-only candidate.

## Current contract basis and exact scope

- `task-reviewer-a.md:27` and `task-reviewer-b.md:28` both say “fresh run ID, distinct nonblank host-session ID”. Each receives the same six-line insertion explaining corresponding-field uniqueness across reviewers/prior reservations versus equal fields identifying one genuine host root thread.
- `review-context-boundary.md:12` says the canonical validator is authoritative. The third six-line insertion immediately after this paragraph records the same distinction without weakening cross-reviewer uniqueness, fabricated-ID rejection or ledger-wide checks.
- `validate-review-context-set.sh:480`–`:486` validates both identity strings and separately requires unique run IDs and unique host-session IDs over the ledger. `validate-review-context-set.ps1:526`–`:540` uses separate run/session sets and hashes both fields. Neither of these predicates requires inequality within one record. Reservation/verification mismatch handling remains unchanged (`.sh:569`–`:590`, `.ps1:604`–`:623`). These are static source findings, not a newly executed end-to-end canonical-validator suite.

No spec, task body, validator, ledger, launch policy, manifest allowlist or historical verdict is changed. The candidate contains exactly three hunks and 18 added lines, no removals. Existing role changes outside the insertion anchors are retained by exact preimage/afterimage pins.

## Fresh validation performed

1. `rtk proxy git apply --check reports/verification/issue290-role-identity-current-candidate-20261005.patch`: exit 0. An initial candidate-format draft lacked trailing context and was rejected by the check; context was corrected once, without applying either draft.
2. `rtk proxy python3 reports/verification/issue290-role-identity-current-human-apply-20261005.py`: exit 0, dry-run only. It checks the full candidate digest, exact three preimages, unique hunk anchors and exact three predicted afterimages, then runs Git's read-only application check. Seven in-memory negative probes rejected candidate-byte drift, original-byte drift for each target, and already-applied bytes for each target. These probes are helper safety evidence, not validator identity negative tests.
3. `rtk proxy node --test reports/verification/issue290-guarded-task-review-launch.test.mjs`: 11 passed, 0 failed, 0 skipped. Includes same-root thread/session acceptance; inherited context, non-idle thread, wrong session/model/sandbox rejection; receipt hash/sequence/uniqueness rejection; normalized task digest and B-input isolation. This is launcher unit evidence, not a formal review or protected application.
4. Current native host no-reservation probe succeeded: `reports/task-review/sdd-domain-concept-test/attempt-7/round-1/idle-probe-01a109cf-c248-7b51-86a1-697813944d55.json` records `reservation=false`, `turn_started=false`, empty unforked idle context and read-only/no-network sandbox. This ID was only probed, not reserved or reviewed.
5. Original attempt-7 precheck `--verify-inputs` exited 0 earlier in this preparation slice, as recorded in `issue290-provenance-launch-readiness-20261005.md`. It must be re-run immediately before any actual new reviewer reservation/launch; this report is not a freshness substitute.

## SHA-256 inventory

| Artifact | SHA-256 |
|---|---|
| New unified candidate | `7dba363a160751b64ece974ba3eefbcf781759593f5c819ab186565c31318f9c` |
| New human-only helper | `bb080598a6bb0c95d66a93895a288b7d53032f3d2924a913de067223896197d0` |
| Preserved old helper | `8668ec62023f71d14b9475518492111c0b3d4486c8b5e4832d26f94d801f408e` |
| Preserved old candidate | `ea9e8ea0f53897990b5471dbcef0320ee837e751a6fa0e3374aa8475dc03b0f7` |
| Current launcher | `9089d1e39ca2cbc95b22fdd8b47f8bf2b69899046946087dedb03b139fc6c92a` |
| Launcher tests | `5416a86a184822598b8129a0b06fe5af738577f190d6012c688a26234b6b4dc0` |
| Bash canonical validator | `8c760abc0081f5f91f04efe0a73d4a2ec82bf3cad3a40b94a36017ca3b5dad72` |
| PowerShell canonical validator | `179fdb17ca1d8afa6044396ef497dd764353ea814d66c835147ceccd2909786b` |

| Target | Current preimage | Predicted afterimage (NOT applied) |
|---|---|---|
| task-reviewer-a.md | `e114b7a61b673e5230a691df3cc8f338df934b2ecf883fcd1b58206d14bae4a8` | `ffe19bcd4b58ad4fc6a85dea8f08216bbaff6dd3143764e25509402c472906e5` |
| task-reviewer-b.md | `4f0add219de40b025d8bf0b73b5fe048e4d94728de2bd7616da728c930498ae9` | `e124d91630710804ef51ac8364af3207bfae252106a86d13c9380b171a3a20a2` |
| review-context-boundary.md | `b537052a70eb52e73cd9add1ab2bb6e19f2b29796efd58bf7df2684b8bd318c1` | `467255d299b66143911891ec8d92c854b85df602e7633a6f40a7830619d10f89` |

## Remaining boundary and human operation

The historical protected-write refusal is preserved in `issue290-a6-b-distinct-clarification-candidate-20261004.md`. It was not retried via another executor. Therefore only the verified candidate and human-only helper are prepared; no protected original was written.

After inspecting the candidate and helper, an authorized human can run the following in the Issue 290 owner checkout (NOT through an agent):

```sh
rtk proxy python3 reports/verification/issue290-role-identity-current-human-apply-20261005.py --apply-human
```

The helper displays the exact patch and pins, rechecks current bytes, requires an interactive `APPLY-ISSUE290-CURRENT`, retains a unique external backup, applies all three paths in one Git patch operation and validates exact afterimages. The human-write branch has NOT been executed in this evidence run. Any mismatch requires another current-state investigation, not a pin-only refresh.

After actual application/readback: re-verify all attempt inputs, allocate new independent host identities and canonical reservations, execute A then counts-only integration then B, persist canonical evidence and validate workflow state. Do not reuse the probe, old B6, or any prior reservation. Only after lawful provenance re-binding may the next Approved task proceed. Native availability is not the current blocker; unapplied protected wording repair is.
