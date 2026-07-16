# Acceptance Tests: epic-159-pillar-d

TEST IDs (TEST-001..TEST-021) are namespaced to this feature
(`specs/epic-159-pillar-d/`) and do not collide with any other spec
folder's own TEST numbering (different suite files, different CI step
names — design.md Test Strategy).

| Acceptance Criterion | Requirement | Test ID | Test Type | Test Target | Status |
|---|---|---|---|---|---|
| AC-001 | REQ-001 | TEST-001 | document conformance | `docs/contributor/workflow-detail.md`'s WFI lifecycle section (§5) contains the capability-refresh step naming the canonical source list verbatim (Anthropic docs/blog, OpenAI docs/blog, Claude Code/Codex CLI/Copilot CLI release notes) | Planned |
| AC-002 | REQ-001 | TEST-002 | document conformance | same section contains the four check items (model ID validity; new model/feature availability; effort/tool-support changes; v2-registry divergence) and the connection to D2's automated flow / manual fallback, including the stable title marker string (`[model-freshness-divergence]`) stated verbatim with the requirement that any manually-filed issue's title carry it (dedup parity with AC-007) | Planned |
| AC-003 | REQ-001 | TEST-003 | document conformance + existing-suite regression | `docs/agent-capability-matrix.md`'s Provider Tier Mapping table gains trailing "最終確認日"/"参照ソース" columns on all six rows; `tests/agent-model-routing.tests.sh` (unedited) re-run and confirmed green after the edit | Planned |
| AC-004 | REQ-001 | TEST-004 | document conformance | the WFI lifecycle section contains an explicit checklist item tied to `Mechanism: model-routing` WFIs referencing the capability-refresh step | Planned |
| AC-005 | REQ-002 | TEST-005 | configuration conformance (text-marker) | `tests/model-freshness-check.tests.sh`/`.ps1`: text-marker check over `.github/workflows/model-freshness-check.yml` asserts a `schedule:` trigger, a `workflow_dispatch:` trigger, `runs-on: ubuntu-latest`, and a `permissions:` block containing only `contents: read` and `issues: write` | Planned |
| AC-006 | REQ-002 | TEST-006 | integration (fixture-driven, real script) | same suite: `check-model-freshness.sh` invoked with an injected fetch-failure fixture (both vendor sources) exits 0 and its issue-comment call records a "取得不能" marker string, asserted against a stubbed `gh` wrapper capturing invocation arguments (no live network call, no live `gh`) | Planned |
| AC-007 | REQ-002 | TEST-007 | integration (fixture-driven, real script) + dedup negative-branch | same suite: `check-model-freshness.sh` invoked with injected fetch-success fixtures containing a model token absent from a fixture-scoped copy of the v2 registry creates an issue-creation call labeled `workflow-improvement`; a second invocation with a stubbed "already-open matching issue" fixture makes zero additional creation calls (dedup proof) | Planned |
| AC-008 | REQ-002 | TEST-008 | integration-level, recorded manual verification (not CI-repeated) | one-time `workflow_dispatch` run against a fixture branch whose registry carries an intentionally stale entry; the resulting filed issue is captured and referenced in the implementation report (mirrors epic-159-pillar-b's release.yml "observable effect only on actual trigger" pattern — not asserted by the deterministic suite) | Planned |
| AC-009 | REQ-002 | TEST-009 | CI resilience + self-registration conformance | same suite: asserts its own fixture-root normalization uses `pwd -P`; no possibly-empty bash array is expanded under `set -u`; no jq consumption (non-use declaration); no real-validator invocation (non-use declaration); and a grep-based self-check confirms its own basename appears in `tests/run-all.sh`/`.ps1` and the LIVE `.github/workflows/test.yml` (red until the human-copy pre-merge commit lands, AC-011 — no staged-candidate fallback). Branch coverage itself is exercised by TEST-006 (fetch-failure), TEST-007 (diff-detected + dedup second invocation), and TEST-020 (no-diff), per AC-009's explicit branch→TEST mapping — not re-asserted here | Planned |
| AC-010 | REQ-002 | TEST-010 | construction proof (grep self-check) | same suite: a grep-based self-check over the real `self-improvement-pr-guard.sh` source confirms its `.github/workflows/*` case pattern (`self-improvement-pr-guard.sh:34`) still matches `.github/workflows/model-freshness-check.yml` as a literal path string, proving the weekly session could never have authored this file itself | Planned |
| AC-011 | REQ-002 | TEST-011 | protected-file staging conformance | `specs/epic-159-pillar-d/human-copy/.github/workflows/test.yml` exists with a sibling `MANIFEST.sha256` whose recorded hash matches the staged candidate's content; the LIVE `.github/workflows/test.yml` is asserted, at staging time, to still be unmodified by the agent (diff against pre-staging content is empty); the human-copy application itself is observable as a pre-merge commit on the feature PR branch that turns TEST-009's live-file self-check green in the PR's own CI (until then the PR CI is red by design — fail-closed, no special case) | Planned |
| AC-012 | REQ-003 | TEST-012 | document/data conformance | `contracts/agent-model-capabilities.v2.json`'s `models[]` entries match the current-generation Anthropic/OpenAI model families with per-model `supported_efforts`, and a confirmation date + reference URL are present in an adjacent comment or sibling doc section | Planned |
| AC-013 | REQ-003 | TEST-013 | hygiene / non-mutation assertion | `contracts/agent-model-capabilities.json` (v1) is byte-for-byte identical to its pre-T-002 content, asserted via a hash comparison | Planned |
| AC-014 | REQ-003 | TEST-014 | existing-suite regression | `tests/agent-capabilities-v2.tests.sh`/`.ps1` and `tests/agent-model-routing.tests.sh` (both unedited by this feature) re-run and confirmed green after T-002's data update | Planned |
| AC-015 | REQ-004 | TEST-015 | document conformance | `docs/contributor/workflow-detail.md`'s capability-refresh step content (TEST-001/TEST-002) contains no host-specific conditional branch — reviewed as a single, host-neutral prose block | Planned |
| AC-016 | REQ-004 | TEST-016 | hygiene / non-existence + twin-pair conformance | `.github/scripts/check-model-freshness.ps1` does not exist (recorded non-twin degradation, design.md Design Decisions); `tests/model-freshness-check.tests.sh` AND `tests/model-freshness-check.tests.ps1` both exist and both register in `tests/run-all.sh`/`.ps1` | Planned |
| AC-017 | REQ-004 | TEST-017 | review-time conformance (no new automated assertion) | task-implementation-time review confirms each D3 current-generation entry (AC-012) populates both the Claude Code and Codex `effort_control` paths per C1's landed v2 schema; recorded in the T-002 implementation report, covered at the suite level by TEST-014's existing-suite green requirement | Planned |
| AC-018 | REQ-005 | TEST-018 | document conformance | `CHANGELOG.md`'s `## Unreleased` section contains three independent entries citing #156, #157, and #158 respectively (one per task's own PR/commit, not a shared block); applicable doc surfaces reviewed per task with edits only where a genuine reference exists | Planned |
| AC-019 | REQ-005 | TEST-019 | document conformance | existing `validate-repository`/skill-reference count sync CI steps (unchanged by this feature) stay green for each task; review-time check confirms no version-literal edit exists outside a `scripts/bump-version.sh` invocation | Planned |
| AC-020 | REQ-002 | TEST-020 | integration (fixture-driven, real script) — no-diff branch | same suite: `check-model-freshness.sh` invoked with injected fetch-success fixtures whose model tokens ALL match the fixture-scoped v2 registry copy exits 0 with ZERO invocations recorded by the stubbed `gh` wrapper (no issue creation, no comment, no other side effect); fixtures are mktemp-scoped and `pwd -P`-normalized immediately after creation, no possibly-empty bash array under `set -u`, no jq consumption, no real-validator invocation, no live network call | Planned |
| AC-021 | REQ-002 | TEST-021 | integration (fixture-driven, real script) — issue-body trust boundary | same suite: `check-model-freshness.sh` invoked with a malformed/adversarial fetch-success fixture (markdown injection, instruction-like text, script fragments) that also yields one genuine divergence; the stubbed `gh` wrapper's recorded issue-body argument contains the allowlist-validated missing model-ID token (charset `[A-Za-z0-9.\-]`) and NO substring of the adversarial payload verbatim; same conventions as TEST-006/TEST-007 (mktemp-scoped `pwd -P`-normalized fixture root, no possibly-empty bash array under `set -u`, no jq consumption, no real-validator invocation, no live network call, no live `gh`) | Planned |

Notes:

- TEST-006/TEST-007 form the RED-demonstrable positive/negative pair for
  REQ-002's central behavior: TEST-006 proves the fail-soft path (fetch
  failure never fails CI, only comments), TEST-007 proves the
  divergence-detected path (an issue gets filed) plus its own internal
  dedup negative-branch (a second matching run creates nothing new) —
  mirroring epic-159-pillar-b's TEST-002/TEST-003 pairing convention,
  adapted to Pillar D's fail-soft/fail-closed split (requirements.md Edge
  Cases). TEST-020 completes AC-009's four named branches with the
  no-diff/zero-side-effect branch (fetch success, registry already
  current → zero `gh` invocations of any kind), and TEST-007's second
  invocation supplies the dedup branch — so every branch AC-009 names maps
  to an explicit TEST ID: fetch-failure → TEST-006, diff-detected →
  TEST-007, no-diff → TEST-020, dedup → TEST-007 (second invocation).
- TEST-021 locks Security Boundary B1's issue-body half: its adversarial
  fixture deliberately contains markdown injection, instruction-like text,
  and script fragments alongside one genuinely-missing model token, and
  the assertion is a positive/negative pair — the recorded issue body DOES
  contain the allowlist-validated (`[A-Za-z0-9.\-]`) missing token and
  does NOT contain any adversarial fixture substring verbatim. This is the
  executable proof that fetched content reaches an issue body only as
  validated model-ID tokens, never raw.
- TEST-010 is this feature's own construction proof that D2's automation
  could not have been authored by the weekly `self-improvement.yml`
  session itself — the mirror image of a normal no-bypass self-check: here
  the assertion is that a DIFFERENT actor (the weekly session) is
  correctly denied, not that this feature's own actor lacks a bypass.
- `tests/gates.tests.sh`, `tests/eval.tests.sh`, `tests/guard-parity.tests.sh`,
  and `tests/constant-parity.tests.sh` are enforcement-chain protected
  files; nothing in this feature touches them. `.github/workflows/test.yml`
  IS touched (TEST-011's registration line), and that single touch point is
  staged via the human-copy procedure, never written live by any suite or
  by the agent.
- Fixtures are synthetic and mktemp-scoped in every case: TEST-005..010
  and TEST-020/TEST-021
  operate on the real `model-freshness-check.yml` (text-marker, read-only)
  and a stubbed `gh`-wrapper/fixture-source-file harness for
  `check-model-freshness.sh` (never a live network call, never a live `gh`
  invocation); TEST-011 operates on a small mktemp comparison of the
  human-copy staging directory. No test writes a real repo path outside
  its own new files, invokes the real `gh` CLI, or emits an approval
  string (security-spec.md).
- This is CI/docs/data-wiring work with no user-facing entry point; the UI
  integration checklist is not applicable (ux-spec.md, frontend-spec.md).
- `tests/model-freshness-check.tests.ps1` re-implements the same
  text-marker/fixture-driven logic natively (no shelling to `bash`,
  design.md's Design Decisions) because `check-model-freshness.sh` is a
  GitHub-Actions-only script with no cross-host runtime claim to make
  (unlike epic-159-pillar-b's `bump-version-gate.tests.ps1`, which had to
  shell out to a bash-only real script that DOES run on operator
  workstations) — TEST-005..010 and TEST-020/TEST-021 run unconditionally
  on both lanes.
- TEST-008 is explicitly NOT re-run by ordinary CI; it is a one-time,
  recorded verification performed once at T-003 implementation time
  against a disposable fixture branch, following the same
  observable-effect-only-on-actual-trigger reasoning epic-159-pillar-b's
  design.md Test Strategy applied to `release.yml`'s own job.
