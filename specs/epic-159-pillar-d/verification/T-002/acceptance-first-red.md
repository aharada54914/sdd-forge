# T-002 acceptance-first RED-side evidence (epic-159-pillar-d, #158)

Captured before any data edit to `contracts/agent-model-capabilities.v2.json`.

## External Blocker re-verification (Main Workflows item 2)

Pillar C's C1 (#149) is confirmed landed on `main`:

```
$ git log origin/main --oneline -1 -- contracts/agent-model-capabilities.v2.json
825d6c6 feat(effort-routing): epic-159 Pillar C - effort routing v2 (Phase 1) (#185)

$ git diff origin/main -- contracts/agent-model-capabilities.v2.json contracts/agent-model-capabilities.json
(empty — worktree matches origin/main byte-for-byte)
```

Landed v2 schema shape re-verified directly against the actual file (not
assumed from requirements.md's description): `schema`,
`models[].{name,canonical_tier,supported_efforts,default_effort,
effort_control.{claude-code,codex-cli}}`, `risk_effort_matrix`,
`role_defaults` — matches issue #149's described shape and
requirements.md Assumptions with no material difference. Safe to proceed
past the External Blocker.

## AC-013 baseline (v1 frozen hash, pre-T-002)

```
6cc5a9dbefaee26a887900520e8e7274c361550f07289605a7ac76a4db85da1c  contracts/agent-model-capabilities.json
```

(`v1-hash-before.txt`, re-compared after the data edit lands.)

## Pre-edit v2 `models[]` state (C1 bootstrap content — the RED side)

Saved verbatim at `pre-edit-v2-registry.json`. Content: 3 Anthropic entries
(`anthropic/haiku`/`sonnet`/`opus`, tier-alias names, no version) + 4
OpenAI entries (`openai/gpt-5.1-codex-mini`, `gpt-5.1-codex`,
`gpt-5.2-codex`, `gpt-5.1-codex-max`) — i.e. C1's own issue-body-stated
"may start with v1-equivalent content" bootstrap: identical model set to
v1, only the schema shape (supported_efforts/default_effort/
effort_control) is new. No confirmation-date or reference-URL record
exists anywhere adjacent to the file.

TEST-012's expectation (AC-012): `models[]` entries matching
current-generation Anthropic (Claude 5 family alias policy) and OpenAI
(`gpt-5.4`/`5.5`/`5.6` family) data, WITH a confirmation date + reference
URL recorded adjacent to the file. Neither condition holds pre-edit:

- No confirmation-date/reference-URL record exists at all (RED).
- The OpenAI entries are `gpt-5.1`/`gpt-5.2`-generation — per
  investigation.md's own background note ("現に OpenAI エントリが 2 世代
  前"), stale relative to the `gpt-5.4`/`5.5`/`5.6` family issue #158
  names as the current generation (RED, OpenAI leg).
- The Anthropic entries are alias-named (`anthropic/haiku` etc., no
  version embedded) — per issue #158's own parenthetical ("Claude 5 系の
  エイリアス方針含む", i.e. "including the Claude 5 generation's alias
  policy"), this IS the correct current-generation shape for Anthropic:
  Anthropic's alias policy means the alias name itself never encodes a
  generation number, so `anthropic/haiku`/`sonnet`/`opus` are already
  structurally correct for "current-generation Anthropic data" — the gap
  on the Anthropic side is documentation-only (no confirmation record),
  not a naming/data gap.

Baseline suite runs (both green pre-edit, confirming the starting point is
a clean baseline, not an already-broken tree):

- `red-baseline-agent-capabilities-v2.log` — `tests/agent-capabilities-v2.tests.sh`, exit 0, pass=10 fail=0.
- `red-baseline-agent-model-routing.log` — `tests/agent-model-routing.tests.sh`, exit 0.

## Suite-compatibility conflict discovered during investigation (blocks a naive "rename to current-gen names" approach)

Direct inspection of the two suites AC-014 requires to stay green
UNEDITED surfaces a structural constraint the design's Data Plan
("each entry's `name` ... updated to current-generation values") does not
itself analyze:

1. `tests/agent-capabilities-v2.tests.sh`'s `validate_parity()`
   (`tests/agent-capabilities-v2.tests.sh:189-231`) performs a
   NAME-KEYED lookup: every v1 model `name` must resolve to a v2 entry of
   the identical `canonical_tier` (`v2_by_name.get(name)` — a v1 name
   absent from v2 is a hard failure, `tests/agent-capabilities-v2.tests.sh:212-215`).
   Because AC-013 freezes v1 byte-for-byte, this means all 7 of v1's exact
   `name` strings (`anthropic/haiku`, `anthropic/sonnet`, `anthropic/opus`,
   `openai/gpt-5.1-codex-mini`, `openai/gpt-5.1-codex`,
   `openai/gpt-5.2-codex`, `openai/gpt-5.1-codex-max`) MUST remain present,
   unrenamed, at their existing `canonical_tier`, in v2 forever — renaming
   or removing any of them turns this suite red, and this suite is listed
   as "re-run only, never edited" (tasks.md Must Read, Out of Scope).
2. `tests/agent-model-routing.tests.sh` goes further: it drives the REAL
   `select-agent-model.sh` directly against the REAL, shipped
   `contracts/agent-model-capabilities.v2.json` (`$REGISTRY_V2`) using
   synthetic candidate fixtures that hardcode the SAME v1-era OpenAI
   names:
   - `tests/agent-model-routing.tests.sh:415-421` ("Sanity: schema
     auto-detection recognizes the REAL, shipped v2 registry") asserts
     `.model == "openai/gpt-5.1-codex-mini"` when selecting against
     `$REGISTRY_V2` with the `all-tiers.json` fixture
     (`openai/gpt-5.1-codex-mini`/`openai/gpt-5.1-codex`/
     `openai/gpt-5.2-codex` only).
   - TEST-034 (`tests/agent-model-routing.tests.sh:868-884`) asserts the
     REAL v1 registry and the REAL v2 registry select the IDENTICAL
     `.model`/`.canonical_tier` for the same candidates file across all
     three tiers — which requires v2 to still contain a model literally
     named `openai/gpt-5.1-codex-mini` (lightweight), `openai/gpt-5.1-codex`
     (standard), and `openai/gpt-5.2-codex` (strong) for the comparison to
     hold.
   This suite is also explicitly "re-run only" (Out of Scope: "Authoring
   new test suites or extending `tests/agent-model-routing.tests.sh`... —
   verification-only obligation").

**Conclusion:** literally RENAMING any of the 7 existing entries (the
"OpenAI 2 世代前" ones included) to `gpt-5.4`/`5.5`/`5.6`-family names
would deterministically turn one or both of these unedited suites red —
not a hypothetical risk, a mechanically-provable one from the exact lines
cited above. No fixture update inside either suite is in scope (Out of
Scope, Non-goals: "verification-only obligation," "re-run only, never
edited") to accommodate a rename, and none is authored here.

**Resolution (documented before the edit, per the acceptance-first
workflow):** this is NOT a stop-and-report situation, because a
suite-safe resolution exists entirely within `contracts/agent-model-
capabilities.v2.json`'s own DATA (no suite edit required, no schema
change, "data values only" — squarely inside T-002's Risk Rationale and
Breaking-API statement):

- The 7 existing entries are left byte-for-byte identical (name,
  canonical_tier, supported_efforts, default_effort, effort_control
  unchanged) — required for AC-013/AC-014 to hold unedited.
- For Anthropic, no new entry is added: issue #158's own "Claude 5 family
  alias policy" phrase means the alias names (`anthropic/haiku`/`sonnet`/
  `opus`) never encode a generation number by design — they are ALREADY
  the correct current-generation shape. This is recorded as a
  documentation-only confirmation (adjacent record), not a data change.
- For OpenAI, three NEW entries are ADDED (not renaming/removing the
  existing 4) reflecting the `gpt-5.4`/`5.5`/`5.6` family issue #158
  names, one per canonical tier (lightweight/standard/strong), each fully
  populating BOTH `effort_control` host paths (AC-017). Adding entries is
  schema-safe (`validate_schema_shape`/`validate_parity`/
  `validate_risk_matrix`/`validate_role_defaults` reject nothing about
  extra models; the routing suite's fixed candidate files never reference
  the new names, so selection outcomes for the fixed fixtures are
  unaffected) and satisfies AC-012's "current-generation... entries"
  condition by making the actual current-generation model IDs present and
  fully described in the registry, while the pre-existing 4 remain as the
  suite-anchored, byte-frozen legacy/parity set.
- The confirmation date + reference URLs (both vendor families) are
  recorded in a new sibling doc, `contracts/agent-model-capabilities.v2.md`
  (design.md API/Contract Plan's named placement option), per the
  no-network-fetch constraint: no live fetch was performed; the source
  descriptions are the canonical list T-001 already documents (Anthropic
  official docs (models overview) / Anthropic blog; OpenAI developers docs
  (Codex) / OpenAI blog; release notes) applied against issue #158's own
  fixed family description, cross-referenced against this environment's
  own in-context model self-identification (`claude-sonnet-5`) as direct,
  non-network evidence for the Anthropic Claude 5 generation claim.
- `docs/agent-capability-matrix.md`'s Provider Tier Mapping confirmation-
  date column is intentionally left `未確認` for all six rows by T-002:
  those rows are the routing-pinned CLI/tooling values (locked verbatim by
  `tests/agent-model-routing.tests.sh`'s `assert_literal` checks,
  `tests/agent-model-routing.tests.sh:98-117`), not the v2 registry's
  current-generation catalog T-002 actually updates; T-001's own
  CHANGELOG entry already records these as "初期化し次回リフレッシュ実施
  時に更新される想定" (initialized, to be updated at a future refresh) —
  T-002 has no genuine, dated confirmation that the specific pinned
  routing strings remain accurate (no network fetch performed), so filling
  in a confirmed date here would overstate verification actually
  performed. This is the REQ-005 "genuine reference" condition
  legitimately not being met for this task, verify-and-leave-unchanged.

## Planned data edit (about to be applied)

Add to `contracts/agent-model-capabilities.v2.json`'s `models[]`:

- `openai/gpt-5.4-codex-mini` — lightweight, `supported_efforts: ["low"]`,
  `default_effort: "low"`, `effort_control: {"claude-code":"none","codex-cli":"flag"}`
- `openai/gpt-5.5-codex` — standard, `supported_efforts: ["medium"]`,
  `default_effort: "medium"`, `effort_control: {"claude-code":"none","codex-cli":"flag"}`
- `openai/gpt-5.6-codex` — strong, `supported_efforts: ["high","xhigh"]`,
  `default_effort: "high"`, `effort_control: {"claude-code":"none","codex-cli":"flag"}`

Create `contracts/agent-model-capabilities.v2.md` recording the
confirmation date (2026-07-19) and reference URLs per vendor family.

Green-side re-run of both suites plus a re-hash of v1 follows in
`green-agent-capabilities-v2.log` / `green-agent-model-routing.log` /
`v1-hash-after.txt`.
