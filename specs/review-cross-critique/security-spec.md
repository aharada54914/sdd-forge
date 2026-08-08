# Security Spec: review-cross-critique

This feature modifies the gate that decides whether work is acceptable, so this
document is load-bearing rather than a formality. The asset being protected is
not data — it is **the meaning of a PASS**. A review gate that silently changes
what its verdict is evidence of is a worse failure than one that fails loudly,
because everything downstream (task approval, implementation, the quality gate,
release provenance) consumes that verdict as an assurance signal.

## Trust Boundaries

### B1 — the blind window

Reviewer A and reviewer B each reach a verdict without having seen the other's
reasoning. This is what makes two FAILs on the same check corroboration rather
than an echo, and it is the reason the merged verdict is permitted to be a
mechanical union of two check arrays (`spec-review-precheck.sh:255-267`) instead
of a judgement call.

It is enforced at five mutually independent layers:

| Layer | Mechanism | Evidence |
|---|---|---|
| L1 role prose | reviewers are told never to read the other's report | `spec-reviewer-b.md:34-35`; `spec-reviewer-a.md:32-33`; `impl-review-loop/SKILL.md:268-269`; `task-review-loop/SKILL.md:295-296` |
| L2 capability | `disallowedPaths` blocks the file at the tool layer, and reviewers are read-only | `spec-reviewer-b.md:4-9` and the same block in the other five role files |
| L3 validator | any manifest containing a raw reviewer report fails the reservation, for every role, unconditionally | `validate-review-context-set.sh:57-61`, applied at `:287-288`; "no exception" at `review-context-boundary.md:134-136` |
| L4 contract replay | reviewer manifests must equal an exactly-computed list, so no extra input survives | `spec-review-precheck.sh:231-240`; superset carve-out limited to four layer specs at `check-workflow-state.sh:455-458` |
| L5 calibration | "Do not use … prior raw reviewer reports … while running the gate" — and this text is itself a hash-bound reviewer input | `reviewer-calibration.md:119-121` |

**The threat this feature creates.** Cross-critique's only possible input is the
artifact all five layers exist to withhold. There is no formulation of "A and B
examine each other's findings" that does not transport reviewer finding text
across this boundary. The design must therefore either relax a gate that
currently has no exception, or confine the phase to a window where the
independence it would violate has already done its work. Both are live (OQ-5),
and neither is chosen here.

**The evasion that must not be chosen.** `is_forbidden_review_output` matches on
filename shape (`reviewer-[ab].json`) and on the `reports/*-review/**/reviewer-*.json`
subtree. Copying finding text into a differently-named file would pass the regex
while defeating the property the regex protects — leaving the written contract
claiming an isolation the system no longer has. That is worse than an agreed
relaxation, and it is named here so it is refused on the record rather than
arrived at under delivery pressure.

### B2 — the merged verdict as an assurance signal

The merged verdict is recomputed from raw severities by four independent
derivations: `spec-review-precheck.sh:255-267` and its PowerShell twin, the
orchestrator's own arithmetic (`impl-review-loop/SKILL.md:160-165`,
`task-review-loop/SKILL.md:161-167`), and `check-workflow-state.sh:517-544`,
which additionally requires each reviewer's own verdict to be the deterministic
function of its own findings at `:498-499`.

That redundancy is the integrity control. A `SEVERITY_CHANGE` or `REJECT` verdict
that moved the gate without moving all four derivations would produce a state the
persisted-state validator rejects — which is the good failure. The bad failure is
a change that moves all four *quietly*, so that a PASS now means something
different from what it meant last release, with no artifact recording the change.

### B3 — the orchestrator's non-waiver property

`impl-review-loop/SKILL.md:261-262` and `task-review-loop/SKILL.md:289-290`:
"Findings from reviewers are facts; the orchestrator counts them but does not
waive or override them." `spec-review-loop/SKILL.md:97`: "Never waive findings."

A `REJECT` verdict is, on its face, a request to waive a finding. If the
orchestrator acts on it, the non-waiver property is gone; if a human acts on it,
the gate acquires a human-in-the-loop step the issue never mentions; if nobody
acts on it, the verdict is decorative. This is OQ-8, and it is a security
boundary rather than a workflow preference because the non-waiver property is
what stops a gate from talking itself into a PASS.

### B4 — the protected-gate surface

Six of this feature's likely targets cannot be written by an agent
(`plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4`, matched by
`endswith()` at `sdd-hook-guard.py:1005-1009`): the impl and task SKILL files and
the four impl/task reviewer role files. The spec stage's three equivalents are
**not** protected.

That asymmetry is itself a security-relevant fact. The layers that *enforce* the
rule (L3 validator, L4 prechecks) are agent-writable; four of the six files that
*state* the rule are not. A delivery therefore lands enforcement changes at agent
speed and prose changes at human speed by default, and the interval between them
is a window in which the written contract and the actual behaviour disagree.

This is not hypothetical. It has already happened, in the opposite direction and
it is live today: `impl-reviewer-a.md:43`'s contradiction with the impl precheck
was resolved in the protected file by commit `fea5ccd0`, while
`review-context-boundary.md:110-132` still describes it in the present tense and
`:165-168` still lists it as an open item for a human (INV-023). That document is
named as required reading in every reviewer role file
(`spec-reviewer-a.md:49-54`, `spec-reviewer-b.md:51-56`), so a reviewer running
today is told a resolved contradiction is unresolved.

### B5 — the identity ledger

Every reviewer launch is preceded by an append-only, chain-verified reservation
with a globally unique `run_id` and `host_session_id`
(`validate-review-context-set.sh:234-235`, `:260-261`, `:262-265`). This is what
makes "reviewer B ran in a fresh context" auditable rather than asserted.

It also forecloses the source protocol's cost model: resuming an agent reuses its
session, and a reused session cannot reserve. So a cross-critique participant is a
fresh context (OQ-6), and any design that tries to route around the ledger to
recover the resumption saving is dismantling the audit property that makes the
blind-pass claim checkable at all.

## STRIDE Analysis

| Boundary | Category | Threat | Current state | Disposition in this feature |
|---|---|---|---|---|
| B1 | **Information disclosure (intended-isolation breach)** | reviewer A's finding text reaches reviewer B before or during B's independent verdict, turning corroboration into an echo | closed at five layers (L1–L5) | **Not decided — OQ-5.** REQ-002 fixes the floor: the first pass stays blind at every stage. What may cross afterwards is the open decision. |
| B1 | **Tampering (by evasion)** | finding text is copied into a file whose name does not match `reviewer-[ab].json`, passing L3 while defeating it | reachable today by any orchestrator that chooses to | **Refused on the record** in this document and in `design.md`. Not closed by a mechanism — closed by an explicit prohibition plus AC-006/TEST-006's role-independence pin. |
| B2 | **Spoofing of assurance** | a PASS is produced whose meaning silently differs from the previous release's PASS | four redundant derivations make an inconsistent change fail; a consistent-but-undocumented change would not | Closed by REQ-004 + AC-009 (four derivations agree) and AC-010c/d (a silent OQ-7/OQ-8 resolution fails the suite). |
| B3 | **Repudiation / silent evidence loss** | a finding is raised, rejected by the peer reviewer, and disappears from the record | non-waiver holds today; a `REJECT` verdict is what would break it | **Not decided — OQ-8.** Prior art exists: the source protocol keeps rejected findings in the report with the rejection reason (`skills/adversarial-review/SKILL.md:38`). Recorded, not adopted. |
| B4 | **Elevation of privilege (contract drift)** | enforcement is relaxed on the agent-writable side while the protected role text still forbids it — or the reverse | **live today** as INV-023, in the reverse direction | Closed by REQ-003 + AC-007's five per-layer branches, and AC-008 closes the existing instance. |
| B4 | **Tampering (guard bypass)** | a protected gate file is written by an agent | guard denies by `endswith()` on the repo-relative path | Closed by REQ-007 + AC-015's six per-target branches, with AC-016/TEST-018 asserting the guard is actually loaded (`sdd-hook-guard.py:952` empties the list on import failure). |
| B5 | **Repudiation (audit dilution)** | orphan ledger records accumulate on every routine run, so "which contexts actually ran" becomes noisy | orphans are legitimate and no gate flags them (`review-context-boundary.md:90-101`) | Closed by AC-001's **reservation count**, not merely its launch count. This is the assertion that catches a design reserving before deciding to fire. |
| B1/B5 | **Denial of service (cost)** | routine reviews become materially more expensive, and the gate gets disabled | no cost telemetry exists anywhere in the loop (INV-021) | Closed structurally by REQ-001 (AC-001, AC-002): a non-triggering run performs exactly today's launches, reservations and artifacts. A measured budget is out of scope and named as such. |

## Data Classification and Protection

Nothing in this feature reads, writes, or transports a secret. The material in
scope is review findings about repository artifacts — text the reviewer produced
by reading files it was explicitly authorized to read.

Two properties matter anyway:

- **Finding text is not public-safe by default.** A finding cites `file:line`
  from the repository under review. Any transport channel introduced for
  cross-critique stays inside the repository's own `reports/` tree; nothing is
  sent to an external vendor. (The cross-model panel does send sanitized bundles
  externally, but it is a different plugin with its own consent gate and is out
  of scope here.)
- **Absence is a security property.** For a non-triggering run, the correct
  outcome is that no cross-critique artifact exists at all — which is why AC-002
  asserts file-set **equality** rather than containment. An empty placeholder
  written "harmlessly" on every routine run is both the cost regression AC 2
  forbids and a false signal that a critique occurred.

## Authorization

- **No agent writes a `PROTECTED_GATE_SUFFIXES` file** (BL-005, REQ-007). Six
  targets are on the list at HEAD `c19b40f8`. Delivery of the protected half is
  OQ-15; the repository's convention is a `specs/<feature>/human-copy/` draft
  with a `MANIFEST.sha256` and an apply script, as used by
  `specs/epic-136-phase2-gates/human-copy/`.
- **Re-verification instruction** (AGENTS.md `## Rules` sweep 3,
  `AGENTS.md:203-211`, WFI-013). `PROTECTED_GATE_SUFFIXES` is repository-wide,
  git-tracked, shared state this branch does not own. Re-derive membership from
  `guard_invariants.py:4` by `endswith()` on each repo-relative target at
  spec-review time and again at implementation start.
- **No `SDD_SUDO` interaction.** Sudo explicitly does not apply to these skills
  (`impl-review-loop/SKILL.md:271-275`, `task-review-loop/SKILL.md:298-302`).
  This feature must not become the exception, and no acceptance criterion here
  depends on sudo state.
- **The guard's Bash-command matcher is broader than its write-path list.**
  `sdd-hook-guard.py:1348-1352` substring-matches the entire command against
  `PROTECTED_GATE_SUFFIXES`, so a purely read-only command naming a gate script
  can be denied. This cost a command during the investigation. Restructure the
  command; do not work around the guard.

## Security Tests

The mapping from boundary to executable check:

| Boundary | Test | What would be missed without it |
|---|---|---|
| B1 blind pass preserved | TEST-003a/b/c, TEST-004a/b/c | a manifest quietly widened at one of the three stages |
| B1 L3 still refuses raw reports | TEST-005 (six enumerated roles) | a carve-out that opened the channel for a role nobody checked |
| B1 refusal is role-independent | TEST-006 | a per-role exception list that all six fixtures still pass against |
| B2 four derivations agree | TEST-009a/b/c/d | a PowerShell-only divergence in the verdict arithmetic |
| B2 no silent OQ-7 resolution | TEST-010c | a `SEVERITY_CHANGE` that moves the gate with nothing recording the decision |
| B3 no silent OQ-8 resolution | TEST-010d | a `REJECT` that retires a finding, breaking the non-waiver property |
| B4 five-layer synchronisation | TEST-007a/b/c/d/e | a delivery landing enforcement without prose — INV-023's failure mode |
| B4 existing drift closed | TEST-008 | the live staleness that misleads a reviewer today |
| B4 no protected file written | TEST-017a–f | one target quietly dropped from the human-copy set |
| B4 the guard is real | TEST-018 | every AC-015 row passing in an environment where the guard failed to load |
| B5 ledger not diluted | TEST-001a/b/c (reservation count) | orphan reservations accumulating on every routine run |
| cost | TEST-002a/b/c (set equality) | a placeholder artifact on every non-triggering run |

TEST-006, TEST-008 and TEST-018 are the three that carry disproportionate weight:
each is a non-vacuity or drift check without which a whole group of other tests
could pass against a broken system. TEST-018 in particular is the reason AC-015's
six rows mean anything — `sdd-hook-guard.py:952` sets
`_PROTECTED_GATE_SUFFIXES = ()` on an import failure, so an unguarded environment
passes every protected-file assertion trivially.

Every case drives fixture artifacts and local scripts. No security test may
require a network, a vendor credential, or a live external service: a security
test that cannot run in CI is not a control.
