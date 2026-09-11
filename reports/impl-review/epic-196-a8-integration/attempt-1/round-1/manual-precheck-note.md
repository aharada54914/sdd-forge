# Manual Precheck Note: epic-196-a8-integration / attempt 1 / round 1

Date: 2026-07-23T09:14:10Z

## Deviation

The automated command `impl-review-precheck.sh epic-196-a8-integration 1 1`
fails before creating any evidence:
`ERROR: impl-review-precheck: layer review input is missing or substituted:
specs/epic-196-a8-integration/ux-spec.md`. Root cause: the registry
(`specs/workflow-state-registry.json`) registers this feature as
`"profile": "full"`, which the script's layer-file gate (lines ~343-350)
requires to mean `ux-spec.md`/`frontend-spec.md`/`infra-spec.md`/
`security-spec.md` exist in the feature's spec directory. None of the four
exist — by design: `design.md`'s own `## Layer Specifications` section
(line 122) and `requirements.md`'s own Risks section (lines 765-791,
already `Spec-Review-Status: Passed`) both state this four-file,
no-layer-spec scope is intentional, matching Epic A7's precedent
(`investigation.md` INV-018), and explicitly warn against "silently fixing"
this with placeholder files.

This is not the tooling-failure class of defect AGENTS.md's "Review gate
precheck fallback" section describes for issue #61 (`jq` or similar being
unavailable) — `jq` and every other tool this script needs are present and
working; the script runs to completion and fails on a genuine, deliberate
content gap. The manual-precheck mechanism used here is modeled on the
issue #61 fallback's *procedure* (manual execution of the precheck's own
validation steps, recorded in this note, with explicit human authorization)
because no other repository-sanctioned mechanism exists to resolve a
registry-profile-vs-already-approved-spec-scope mismatch; it is not a claim
that this is an instance of issue #61 itself. Full investigation trail:
`reports/notes/epic-196-a8-integration-impl-review-profile-mismatch.md`
(this worktree, commit `d07a35f` and this note's own follow-up commit).

## Human authorization

See the "Human authorization" section of
`reports/notes/epic-196-a8-integration-impl-review-profile-mismatch.md`
for the full record (date, relay chain, verbatim instruction, and scope).
Summary: 2026-07-23, relayed to this orchestrator by the coordinator agent
from the human's own verbatim instruction ("判断2・5については認可する"),
authorizing candidate 2 for this note's decision — a case-scoped manual
`impl-review-precheck` for this feature's impl-review only, waiving the
four-layer-file existence/hash check while keeping identity-ledger
reservation, hash-manifest binding, and reviewer strictness fully intact.
Not a standing exemption; not a registry or requirements.md change.

## Manual checks performed

Equivalence check against `impl-review-precheck.sh`'s own pure-validation
logic, performed by hand, in script order:

1. `bash plugins/sdd-quality-loop/scripts/check-workflow-state.sh --feature
   epic-196-a8-integration` → `workflow-state: ok`.
2. `requirements.md` declares `Spec-Review-Status: Passed` (confirmed
   directly).
3. `design.md` declares `Impl-Review-Status: Pending` (confirmed directly;
   the only value the script accepts to proceed).
4. Legacy-design detection (script's own 5-field/3-missing threshold):
   `## Components` present, `Feature Type:` present, `Data Entities:`
   absent, `Existing Data Affected:` absent, `## Security Boundaries`
   present → 2 of 5 missing, below the 3-missing threshold →
   `legacy_design: false`.
5. `design_req_drift`: not applicable — only computed for round > 1;
   `false` for this round 1.
6. SHA-256 computed directly (`shasum -a 256`) for the three real inputs:
   - `design.md`:
     `a8b14ac80fa578d36d14a1c0371419c02a920d7aef2c3b15b1a5b57bce835f5a`
   - `requirements.md`:
     `6ad8bfa7767a1c1c07ef25d43be0d0d69f9e494e7b180289a3df3678ad4f90b5`
   - `acceptance-tests.md`:
     `eccb74b87747529947540ff290184b5bc7f3111f49d18252b2f8b1bbc5d872cb`
7. `layer_sha256: {}` — the four layer files were reconfirmed absent from
   `specs/epic-196-a8-integration/` (directory listing: only
   `acceptance-tests.md`, `design.md`, `investigation.md`,
   `requirements.md`); `{}` is the only honest value, not a substitute for
   the waived check.
8. `input_sha256` computed with the script's own `full_profile` 4-field
   formula (`design:requirements:acceptance:layer_sha256`, registry profile
   is genuinely `full` and stays `full` — no registry edit was made),
   using the literal empty-object JSON string for the fourth field:
   `sha256("<design_sha256>:<requirements_sha256>:<acceptance_sha256>:{}")`
   = `6833949e7ed3f6355b806ed0b3abb7b8ea877d9ba5e9a972c3b086efe7083cc8`.
9. `require_persisted_pass` equivalent (script lines ~54-224): read
   `reports/spec-review/epic-196-a8-integration/attempt-1/round-1/`
   directly. `integrated-verdict.json` is schema
   `spec-review-integrated-verdict/v1`, `verdict: PASS`, distinct
   `reviewer_a`/`reviewer_b` run and host-session IDs. `spec-review-contract
   .json` is schema `spec-review-contract/v1`, `verdict: PASS`,
   `acceptance_sha256` equals this note's current acceptance hash
   (`eccb74b8...`, item 6) unchanged since spec-review, and
   `requirements_sha256` equals the current requirements.md content with
   only its `Spec-Review-Status` field normalized to `Pending` before
   hashing (the same normalization the automated script itself performs at
   line 351, `reviewed_sha256`) — both reviewers' manifests reference
   `requirements.md`, `acceptance-tests.md`, `investigation.md`, the spec
   calibration reference, and the round's own `precheck-result.json`, and
   reviewer-b's manifest additionally references `integrated-summary.json`,
   exactly as the automated script's `allowed_input` predicate requires.
10. `review-contract-validate.sh` (script lines ~397-402): a pure format
    check on a locally-constructed `review-contract/v1` object; it persists
    no evidence file and gates nothing beyond its own schema shape, which
    is trivially satisfiable by construction. Not separately reproduced as
    a file.
11. Replay safety: `reports/impl-review/epic-196-a8-integration/` did not
    exist before this note and `precheck-result.json` were written
    (confirmed by directory listing beforehand) — this round destination
    was not pre-existing.

## Result

Manual precheck passed under the human-authorized, case-scoped deviation
above. `precheck-result.json` in this directory records exactly the same
11 fields the automated script's own STEP 6 would write, with `layer_sha256:
{}` reflecting the four files' genuine, deliberate absence.
