# Manual Precheck Note: epic-196-a8-integration / attempt 1 / round 2

Date: 2026-07-23T10:09:41Z

## Deviation and authorization scope

Same deviation and same human authorization as round 1
(`reports/impl-review/epic-196-a8-integration/attempt-1/round-1/
manual-precheck-note.md`): the automated `impl-review-precheck.sh` still
requires `ux-spec.md`/`frontend-spec.md`/`infra-spec.md`/`security-spec.md`
because the registry's `epic-196-a8-integration` entry is `"profile":
"full"` (unchanged; no registry edit made or planned). The human's
2026-07-23 authorization ("判断2・5については認可する", candidate 2 in
`reports/notes/epic-196-a8-integration-impl-review-profile-mismatch.md")
was scoped to "a case-scoped manual impl-review-precheck for
`epic-196-a8-integration`'s impl-review only," not to round 1 specifically
— the coordinator confirmed this extends to subsequent rounds of the same
feature's impl-review without a fresh authorization request. `layer_sha256`
remains `{}` in this round's `precheck-result.json`, for the same reason
(the four files still do not exist and design.md/requirements.md's
four-file-only scope is unchanged).

## Manual checks performed

Equivalence check against `impl-review-precheck.sh`'s own pure-validation
logic for a round > 1 invocation, performed by hand:

1. `bash plugins/sdd-quality-loop/scripts/check-workflow-state.sh --feature
   epic-196-a8-integration` → `workflow-state: ok` (re-run fresh for this
   round).
2. `requirements.md` still declares `Spec-Review-Status: Passed`;
   `design.md` still declares `Impl-Review-Status: Pending`.
3. Legacy-design detection re-run against the post-remedy design.md: all
   five required template fields now present (`## Components`,
   `Feature Type:`, `Data Entities:`, `Existing Data Affected:`,
   `## Security Boundaries` — the last two newly added by round 1's own
   DATA-COVERAGE remedy) → 0 of 5 missing, below the 3-missing threshold
   → `legacy_design: false` (unchanged from round 1).
4. SHA-256 recomputed directly for all three core inputs:
   - `design.md` (changed by the three round-1 remedies):
     `08556eb2728d4ee63bf50bd29f47cf72150ca47916e6a740ed4f58303919b4a0`
     (round 1 was `a8b14ac80fa578d36d14a1c0371419c02a920d7aef2c3b15b1a5
     b57bce835f5a` — confirmed different, satisfying the script's own
     round>1 "design.md must have changed since the prior round" gate).
   - `requirements.md` (untouched):
     `6ad8bfa7767a1c1c07ef25d43be0d0d69f9e494e7b180289a3df3678ad4f90b5`
     — identical to round 1's recorded value, so `design_req_drift: false`
     (the script's DESIGN-REQ-DRIFT check compares this round's
     requirements hash against round 1's own stored value; they match).
   - `acceptance-tests.md` (untouched):
     `eccb74b87747529947540ff290184b5bc7f3111f49d18252b2f8b1bbc5d872cb`
     — identical to round 1.
5. `layer_sha256: {}` — the four layer files remain absent (reconfirmed).
6. `input_sha256` recomputed with the same `full_profile` 4-field formula
   as round 1 (`design:requirements:acceptance:{}`):
   `6ec077fe62b32f0ba9ac795ee486274357793ae8423a4671202970e8c9bd13d5`.
7. Prior-round-contract check (script's own round>1 gate): round 1's
   `impl-review-contract.json` exists, is schema-valid
   (`impl-review-contract/v1`), and its own `verdict` is `NEEDS_WORK` (not
   a terminal PASS/BLOCKED) — the state the script requires before
   allowing a round-2 `--edit-summary` re-invocation. Round 1's own
   `design_sha256` field (`a8b14ac8...`) matches what round 1's reviewers
   actually reviewed (independently re-verified when round 1's evidence
   was persisted, not re-derived here).
8. Replay safety: `reports/impl-review/epic-196-a8-integration/
   attempt-1/round-2/` did not exist before this note and
   `precheck-result.json` were written.

## Edit summary (per SKILL.md's round 2/3 `--edit-summary` requirement)

Applied all three remedies from round 1's `design-round-1-proposed-
changes.md` in full, per `reports/impl-review/epic-196-a8-integration/
attempt-1/round-1/`: (1) added `Data Entities:`/`Existing Data Affected:`/
`Migration Strategy:` labeled sub-fields to `## Data Plan` (commit
`51c75821`); (2) added a B1/B2 cross-reference to `## Constraint
Compliance` pointing at `## Security Boundaries` (same commit); (3) added
`docs/adr/0028-live-host-proof-ed25519-signing.md` for the Ed25519
signing/trusted-key mechanism and updated `## ADR Change Log` to cite it
(commit `be7607e6`). No other content changed; no finding was waived —
each remedy directly closes its cited gap.

## Result

Manual precheck passed under the same human-authorized deviation as round
1. `precheck-result.json` in this directory records exactly the same 11
fields the automated script's own STEP 6 would write for a round-2
invocation.
