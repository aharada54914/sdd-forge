# Changed-input prelaunch recovery — draft addendum candidate

Status: DRAFT, non-frozen preparation only. Not an admitted recovery contract,
specification approval, precheck, reservation, verdict or implementation.
Target feature: `guard-role-read-regression` in
`/private/tmp/sdd-guard-main.3JEj4I/repo`.

## Difference from the A7 route

A7 root: `/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge`.
Reference contract:
`reports/verification/a7-spec-fresh-review-contract-attempt13-20261005.json`.
Its `plugins/sdd-review-loop/scripts/fresh-review-recovery.py:60-67,107-126`
requires the current v2 shape, next attempt at least four, and a real terminal
anchor with six historical artifacts. Lines 128–165 require contiguous partial
attempts, `reviewer-a-host-allocation.json`, and canonical external invocations.
Lines 196–207 bind a current-conversation approval audit to current input hashes.

This target has attempt 1 / round 1 only, no terminal anchor, and three files:
`precheck-result.json`, `reviewer-a-host-receipt.json`, and
`review-context-spec-reviewer-a.json`. It cannot satisfy A7 v2 by renaming,
fabricating a terminal attempt, inventing history or treating old outputs as PASS.

The existing `specs/spec-review-prelaunch-recovery/requirements.md:50-53,94-95`
and `acceptance-tests.md:45-48` reject changed live inputs. Therefore that pending
proposal also cannot authorize this changed-input case without a reviewed
explicit amendment. Preserve its current bytes; this addendum is only a proposed
delta, not an override of its REQ-004 / AC-006 / TEST-006.

## Proposed minimal scope

1. Add a distinct versioned no-terminal/prelaunch recovery discriminator for the
   exact attempt-1/round-1 source and attempt-2/round-1 Pending target. Do not
   weaken ordinary advance/reset or A7 terminal-history predicates.
2. Preserve and bind the raw historical three-file inventory, original input
   pins, consumed A identity, complete ledger chain and host no-turn evidence.
   Missing or contradictory no-turn/identity evidence is a stop, not an inference.
3. Bind current requirements, acceptance, calibration, boundary and investigation
   presence/absence separately from historical inputs. Authorized differences
   are explicit old/new path+hash pairs. An unlisted change or later drift rejects.
4. Bind the human's existing recovery authorization using its exact trusted
   statement and source reference, scope, feature, target counter and current
   hashes. Root transcribes the authorization already held; do not ask for the
   same approval again. Coordination messages are not fabricated direct-human
   quotations and a local boolean is not evidence of human origin.
5. Quarantine old evidence as diagnostic-only; do not retrospectively validate
   transition legality. Publish only the new Pending precheck plus recovery
   provenance under lock, after rechecking old/current pins and target absence.
6. Fresh host allocation and identity reservation remain separate normal launch
   steps. Never reuse the old A host/run ID or derive a fictitious one. No reviewer
   starts until complete manifest/receipt delivery and tool-policy compatibility
   are verified. No role write-canary, permission relaxation or refused-command retry.
7. Require downstream provenance validation and Bash/PowerShell parity. Keep all
   historical ledgers, frozen artifacts, statuses and reservations byte-identical
   except the normal later append-only fresh reservation.

## Observed pins (2026-10-05, reverify at consumption)

All paths below are relative to the target root. They are observed pins, not a
complete machine-consumable recovery manifest.

| Artifact | SHA-256 |
|---|---|
| reports/spec-review/guard-role-read-regression/attempt-1/round-1/precheck-result.json | 6f9658547bf99b867c2352fae5055242540899fb46b95bbe2459f07e35d7b032 |
| reports/spec-review/guard-role-read-regression/attempt-1/round-1/reviewer-a-host-receipt.json | ed55a8e913af1ed3ce32ed5e206ee41aa4373856d202816f5d266515d8c18173 |
| reports/spec-review/guard-role-read-regression/attempt-1/round-1/review-context-spec-reviewer-a.json | 215441b255369e5082f52934fd15703fba3d6400021bc3cea1e0ac54b9eef65e |
| specs/guard-role-read-regression/requirements.md | bd5434d414bffa1344a4249c56b325fbd8a22322c12bb5eb91cc49cf429ab672 |
| specs/guard-role-read-regression/acceptance-tests.md | 05423a3aedc0914406f33708d2e78b3eda2b64bc57c1c75fe21e8b90b3d10095 |
| plugins/sdd-review-loop/references/spec-review-calibration.md | 537f776558cf4b4a99ee455a974857a67e249242dce5806e23d37d6802f2a385 |

Historical precheck requirements pin: 4683d30289101edd00c1d0399c01e7275975f2be12ccfaf1f39cb3c6dc3e4358.
Historical acceptance pin: 4d6d475ba78ee3d8f8298080b7259cf07fbdf6784c36071f26857511333e48c4.
Historical values were read in `read-policy-precheck-current-20261005.md`.
Current boundary hash, investigation presence/absence, complete ledger validation,
host-native no-turn evidence and exact trusted approval transcript are not yet
assembled into this candidate. A hash command mistakenly named the quality-loop
boundary path and returned ordinary file-not-found; the actual boundary path is
`plugins/sdd-review-loop/references/review-context-boundary.md`. No successful
hash observation is claimed for it here.

## Planned explicit assertions (not executed)

- Positive: named no-turn source with separately bound authorized req/AC changes
  produces only fresh Pending precheck; all old bytes unchanged.
- Positive: unchanged-source route retains existing semantics.
- Negative, each separately: changed old evidence; unlisted current input change;
  post-authorization drift in requirements, acceptance, calibration, boundary or
  investigation; absent/present investigation disagreement; missing/agent-only/
  wrong-scope authority; A-start/output; B identity/output; incomplete ledger;
  duplicate key; bad hash/path; symlink/escape; target exists; concurrent writer.
- Delivery/identity: full receipt and manifest bytes arrive; old identity reuse
  rejects; fresh identity is observed rather than invented; no review on refusal.

## Next formal boundary

Resolve the recorded consumer-preparation protection refusal through the normal
policy-governed repair/apply process. Review this explicit changed-input delta
with the existing proposal before implementing recovery behavior or read-policy
guard product code. Native allocation/turn and new reservation remain unstarted.
