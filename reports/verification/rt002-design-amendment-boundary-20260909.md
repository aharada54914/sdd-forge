# RT002 design amendment entry boundary

Date: 2026-09-09
State: AC-028 contract amendment applied; new spec precheck passed; independent review in progress

## Subsequent AC-028 amendment

The human additionally authorized "その他の設計変更も承認する". Requirements,
acceptance tests, design and infra now define canonical live CI registration,
retired-snapshot rejection and preservation of existing mandatory CI checks.
Original spec-review-precheck attempt-3/round-1 --reset exited 0; the spec
status is Pending. Reviewer A was reserved at identity sequence 974 and launched
in fresh read-only Astra context 01a08618-6daa-78b2-b994-b079bdd53dbd.
No new review verdict, implementation/test success or integration is claimed.
The earlier design precheck is retained as history and does not bind these new
bytes. All narratives below describe their respective earlier scopes.

## Subsequent authorized reference repair

The user approved evidence-based reference repair for all 14 missing ACs.
The crosswalk is now appended at design.md:1919, including an explicit
unresolved-conflict entry for AC-028 rather than a satisfaction claim.
The original attempt-4/round-1 provenance precheck subsequently exited 0.
See rt002-missing-ac-mapping-20260909.md for the command, current hashes and
scope boundaries. No requirements or acceptance tests were changed by this
follow-up, no formal reviewers launched, and no new verdict was recorded.
The failure narrative below is retained as history, not current precheck status.

## Authorized execution outcome

The user explicitly approved: "RT002限定の設計3文書の改訂・正式再レビューの承認".
Applied dated additive amendments to design.md (90 lines), infra-spec.md
(32 lines) and security-spec.md (49 lines). No existing line was removed;
the historical design header and all earlier verdicts remain unchanged.
The ordinary apply_patch operation succeeded; no alternate executor or
protection bypass was used. Scoped git diff --check exited 0.

Ran the original precheck:

`rtk proxy bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh epic-189-a1-project-context 4 1 --provenance-rereview`

Exit 1. Stale prior input hashes were advisory in the sanctioned provenance
mode, but the AC-coverage check rejected missing design references:
AC-002, AC-004, AC-006, AC-010, AC-011, AC-015, AC-018, AC-020, AC-022,
AC-024, AC-025, AC-028, AC-029 and AC-041.
Read-only rg for those exact identifiers in current design.md returned no
matches (exit 1), confirming the diagnostic is not a substring-detector false
positive. The original precheck enforces this at lines 339-364. No reviewer
identity was reserved, no reviewers launched and no new PASS was recorded.

Next proposed scope: map each rejected AC to its actual existing design and
test plan, add only truthful explicit trace references where already covered,
and disclose any real design gap for separate resolution. Do not append a
bare AC list merely to pass the detector. This expands beyond the approved
REQ-010/AC-027/AC-032 amendment and therefore needs a human scope decision.
The skill's STEP 1 requires halting this gate on nonzero precheck; it has not
been rerun or weakened. Implementation, native activation and merge remain
unproven.

The specification amendment passed attempt-2/round-2. This does not establish
implementation-policy review, task review, activation, CI success or merge
readiness.

## Confirmed constraints

- The installed impl-review-loop skill, “Post-Implementation Provenance
  Re-Review”, requires retaining the Passed design header after tasks exist.
  Its “Controlled re-binding boundary” says this mode does not license content
  changes to frozen artifacts; sanctioned updates belong in non-frozen addenda.
- AGENTS.md “Post-review artifact freeze” binds design and the recorded layer
  specifications. A repair review admission alone does not expressly release
  these frozen inputs for content amendment.
- `plugins/sdd-quality-loop/scripts/check-workflow-state.sh:860` defines the
  stage manifest allowlist. Its impl entries include the canonical design and
  four layers, but not a verification addendum or ADR. An out-of-manifest
  addendum therefore cannot silently govern the formal reviewers.
- The scoped propagation inventory is
  `reports/verification/hook-host-provenance-propagation-map-20260909.md`.
  It identifies affected design, infrastructure and security descriptions;
  the specification amendment does not itself rewrite those descriptions.

## Proposed narrow resolution requiring explicit authorization

Authorize a human-applied, dated RT002 amendment to design.md, infra-spec.md
and security-spec.md for epic-189-a1-project-context only. Preserve the prior
text and prior evidence; name precisely the superseded statements. Propagate
the reviewed versioned adapter, exact operation/nonce binding, plain-file trust
limit and unchanged three-outcome cleanup guarantees. Keep ux/frontend content
unchanged unless a concrete conflict is found and separately scoped.

After preparing and inspecting the exact diff, use the permitted human path
for any protected application. Retain the Passed header as required for the
provenance entry, but never present that historical header as approval of the
new amendment. Run a new independent design provenance attempt, with all
current inputs hash-bound and no convergence waiver for changed semantics.
Retain every previous review. No validator allowlist changes, skipped checks,
historical verdict rewrites or protection bypass are proposed.

Task provenance, original-path regressions, fresh native activation and CI
remain subsequent required steps. No production files, frozen design inputs,
review verdicts, remote branches or PRs were changed during this boundary
investigation.
