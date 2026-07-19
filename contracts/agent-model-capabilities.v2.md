# `agent-model-capabilities.v2.json` — current-generation confirmation record

(epic-159-pillar-d T-002, Issue #158)

This note is the confirmation-date/reference-URL record design.md's
API/Contract Plan requires adjacent to
`contracts/agent-model-capabilities.v2.json` (AC-012). It is NOT part of
the JSON schema itself (a top-of-file JSON comment is not valid JSON) —
schema shape remains entirely Pillar C's C1 ownership; this file records
provenance only.

**No network fetch was performed to produce this record** (T-002's
implementation constraint). The confirmation below applies the canonical
source list `docs/contributor/workflow-detail.md`'s capability-refresh
step already documents (epic-159-pillar-d T-001, #156) against the fixed
family description issue #158's own body states, cross-referenced against
this implementation session's own in-context model self-identification
where a live citation was not obtainable.

## Confirmation date

**2026-07-19**

## Anthropic — Claude 5 family, alias policy

`anthropic/haiku`, `anthropic/sonnet`, `anthropic/opus` in `models[]` are
NOT renamed by this task. Anthropic's alias policy (issue #158: "Claude 5
系のエイリアス方針含む") means the registry's alias-style names never
embed a generation number — `anthropic/sonnet` names an alias Anthropic
itself keeps repointed at its current Sonnet-tier model, not a pinned
snapshot. As of this confirmation date, that current generation is Claude
5 (Haiku 5 / Sonnet 5 / Opus 5) — directly evidenced in-repository,
without a network fetch, by this implementation session's own runtime
model identity (`claude-sonnet-5`, i.e. "Sonnet 5") and by every
`reports/runs/RUN-*.json` / `reports/retrospective/*.md` record in this
repository already citing `claude-sonnet-5` as of this date. The alias
names in `models[]` therefore already correctly represent
"current-generation Anthropic data" per issue #158's own framing; no
`name`/`canonical_tier` change was needed or made.

- Reference source class: Anthropic official docs (models overview);
  Anthropic blog (per the canonical source list,
  `docs/contributor/workflow-detail.md`'s capability-refresh step,
  T-001/#156).
- No specific dated URL is cited — no live fetch was performed this task;
  see the constraint statement above.

## OpenAI — `gpt-5.4`/`5.5`/`5.6` family

The 4 pre-existing OpenAI entries (`openai/gpt-5.1-codex-mini`,
`openai/gpt-5.1-codex`, `openai/gpt-5.2-codex`,
`openai/gpt-5.1-codex-max`) are LEFT UNCHANGED — they are locked,
byte-for-byte, by two suites this task must keep green UNEDITED:
`tests/agent-capabilities-v2.tests.sh`'s v1⇔v2 parity lock (v1 is frozen
at these exact names, AC-013) and `tests/agent-model-routing.tests.sh`'s
direct assertions against the REAL registry file (`tests/agent-model-
routing.tests.sh:415-421`, `:868-884` — both require these literal names
present at their existing tier). Renaming or removing any of them would
turn one or both suites red; see
`specs/epic-159-pillar-d/verification/T-002/acceptance-first-red.md` for
the full analysis.

Three NEW entries are ADDED instead, reflecting the actual current
OpenAI-Codex generation issue #158 names (`gpt-5.4`/`5.5`/`5.6` family),
one per canonical tier, mirroring the existing tier→model shape:

| `name` | `canonical_tier` | `supported_efforts` | `default_effort` |
|---|---|---|---|
| `openai/gpt-5.4-codex-mini` | lightweight | `["low"]` | `low` |
| `openai/gpt-5.5-codex` | standard | `["medium"]` | `medium` |
| `openai/gpt-5.6-codex` | strong | `["high", "xhigh"]` | `high` |

Each new entry populates BOTH `effort_control` host paths (AC-017):
`claude-code: "none"` (Anthropic-hosted tooling has no OpenAI-model effort
concept, mirroring every other OpenAI entry already in the file) and
`codex-cli: "flag"` (the Codex CLI's `--effort` flag applies, same as
every other OpenAI entry).

- Reference source class: OpenAI developers docs (Codex); OpenAI blog;
  release notes for Codex CLI (per the canonical source list,
  `docs/contributor/workflow-detail.md`'s capability-refresh step,
  T-001/#156).
- No specific dated URL is cited — no live fetch was performed this task;
  see the constraint statement above. The specific version numbers
  (`5.4`/`5.5`/`5.6`) and tier assignment are taken directly from issue
  #158's own fixed body text ("OpenAI 現行世代（5.4/5.5/5.6 系）"), not
  independently verified against a live OpenAI source.

## Follow-up

A future capability-refresh pass (`docs/contributor/workflow-detail.md`'s
WFI lifecycle checklist, T-001/#156) or a weekly `model-freshness-check`
run (T-003/#157, once landed) should re-confirm these specific model IDs
against a live fetch of the canonical sources and update this record's
confirmation date accordingly. This record does not itself change
`docs/agent-capability-matrix.md`'s Provider Tier Mapping confirmation-
date column (left `未確認` by this task — that table's model-family
values are separately locked routing/CLI pins, not this registry's
current-generation catalog; see
`specs/epic-159-pillar-d/verification/T-002/acceptance-first-red.md`).
