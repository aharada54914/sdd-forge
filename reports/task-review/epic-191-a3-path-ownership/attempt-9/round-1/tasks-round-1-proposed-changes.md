# Task Review Report: epic-191-a3-path-ownership — Round 1 / Attempt 9

## Verdict: NEEDS_WORK

| Field | Value |
|---|---|
| Feature | epic-191-a3-path-ownership |
| Round | 1 of 3 |
| Attempt | 9 (post-implementation provenance re-review after the 00744ac3 T-006 scope supersession) |
| Reviewer-A Verdict | NEEDS_WORK |
| Reviewer-B Verdict | NEEDS_WORK |
| Critical Findings | 0 |
| Major Findings | 2 |
| Minor Findings | 0 |
| Generated | 2026-08-12T01:25:00Z |

## Reviewer-A Findings (Structural Coverage)

- **SINGLE-CONCERN** (severity: Major, task: T-006):
  NEW defect introduced by commit 00744ac3 (2026-08-12 T-006 scope supersession) — judged fresh, not shielded by TYPE-H convergence since this text is not byte-identical to the attempt-8 round-1 PASS-bound T-006 section. The supersession's Planned Files list adds 'plugins/sdd-quality-loop/scripts/check-component-coverage.ps1 (existing, agent-editable — added by the 2026-08-12 scope supersession...)' and a matching Scope Commit A bullet authorizing a direct edit to that file. This contradicts tasks.md's own Protected Files section (situation 1, 'six already-protected files': 'plugins/sdd-quality-loop/references/guard-invariants.json gains three new protected_gate_suffixes entries (check-component-coverage.{sh,ps1,py})'; 'No task below writes any protected path directly. Every corrected copy is staged under specs/epic-191-a3-path-ownership/human-copy/<real-relative-path> with a MANIFEST.sha256 entry') and design.md's Components table, which marks 'check-component-coverage.sh / .ps1' Protected: 'yes, once registered (T-004)'. Live-repository verification confirms T-004's registration has already landed: plugins/sdd-quality-loop/references/guard-invariants.json:47 and plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4 currently list plugins/sdd-quality-loop/scripts/check-component-coverage.ps1 in protected_gate_suffixes/PROTECTED_GATE_SUFFIXES (consistent with T-004's Status: Done, whose Done-When required the Bundle-A human-apply step to be confirmed first). T-006's scope description is therefore incoherent as written: it labels a genuinely R-10-protected file 'agent-editable' with no human-copy staging path, no MANIFEST.sha256 entry, and no corresponding HUMAN APPLY STEP Done-When bullet (unlike T-004's own Bundle A/Bundle B precedent for the identical file family) — an implementer following this text as written would attempt a direct write to a protected path, which this feature's own governing rules forbid. By contrast the sibling Planned Files entry in the same bullet list, resolve-component-paths.ps1, is accurate: design.md's Components table marks it 'Protected? no', and grep confirms it carries no PROTECTED_GATE_SUFFIXES entry in the live repository — only the check-component-coverage.ps1 entry is defective. Evaluate the scope description, not only the title (SINGLE-CONCERN's own instruction): the scope-as-written does not hold together with this document's own protected-file regime for one of its two named files.

## Reviewer-B Findings (Quality/Risk)

- **ROLLBACK-PLAN** (severity: Major, task: T-006):
  T-006's unchanged Rollback field ('nothing protected is written directly') is contradicted by the 2026-08-12 scope supersession (commit 00744ac3), which adds plugins/sdd-quality-loop/scripts/check-component-coverage.ps1 to Planned Files as directly 'agent-editable' -- a file tasks.md's own Protected Files section (item 3) and T-004's Planned Files entry designate as one that 'BECOMES protected once registered', a registration T-004 (Status: Done, Done-When-gated on confirmed human-apply) has already completed per the document's own internal logic, and which security-spec.md's B1 boundary/STRIDE row (protected-content boundary includes 'the new check-component-coverage.{sh,ps1,py} suffix registration itself'; mitigation: 'No script this feature ships writes to a protected path directly') treats as protected going forward. This also sits in unreconciled tension with T-006's own unchanged final Out of Scope bullet ('Any protected-file edit beyond staging this suite's own test.yml CI-step candidate'). The Rollback field does not address how this newly-sanctioned direct edit would be safely reverted, so rollback consideration for the newly-added change is effectively absent.

## Proposed Changes

Both reviewers converge independently on the same root defect in commit
00744ac3's supersession text:
`plugins/sdd-quality-loop/scripts/check-component-coverage.ps1` is R-10
protected content (T-004's `protected_gate_suffixes` registration,
`guard-invariants.json:47`, human-applied), so labeling it "existing,
agent-editable" with a direct-edit Scope bullet contradicts the plan's own
Protected Files regime, the security-spec B1 boundary, T-006's final Out of
Scope bullet, and the unchanged Rollback field. The sibling
`resolve-component-paths.ps1` entry is verified accurate (unprotected).

Remediation, all confined to the T-006 section's already-amended spans:

1. Planned Files: replace the direct `check-component-coverage.ps1` entry
   with the human-copy staged-candidate form —
   `specs/epic-191-a3-path-ownership/human-copy/plugins/sdd-quality-loop/scripts/check-component-coverage.ps1`
   (staged candidate, agent-editable; R-10 protected real path) — plus its
   `MANIFEST.sha256` entry, mirroring T-004's own precedent for the same
   file family.
2. Scope Commit A amended bullet: state that the
   `resolve-component-paths.ps1` correction is a direct edit (unprotected)
   while the `check-component-coverage.ps1` correction is STAGED under
   `human-copy/` with a manifest row; the live protected file is never
   written by the agent.
3. Out of Scope supersession: reconcile with the final bullet ("Any
   protected-file edit beyond staging this suite's own `test.yml` CI-step
   candidate") by extending that staging allowance to this one additional
   staged candidate, and note GREEN on the coverage pair is contingent on
   the human apply step.
4. Done When / Rollback: add the human apply step for the new staged
   candidate (cp plus sha-256 verification), and extend the Rollback
   wording so the staged-candidate path is covered ("nothing protected is
   written directly" remains true; a revert PR states whether an
   already-applied candidate should be hand-reverted — the wording the
   field already uses for `test.yml`).

## Next Steps

Edit `specs/epic-191-a3-path-ownership/tasks.md` per the proposed changes
and re-invoke the task review loop as round 2 of attempt 9 with
`--edit-summary`.
