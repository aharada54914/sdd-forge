# Requirements: epic-196-a8-integration

Spec-Review-Status: Passed
Source Issue: https://github.com/aharada54914/sdd-forge/issues/196 (Epic A8,
tracked under #187 / Epic A0 #188)

## Overview

Epic A8 ("3環境 統合検証") is the integration-verification epic decision doc
§7 (v2 role split) and §19 name: cross-runtime handoff E2E, an
install/uninstall matrix across `--target All\|Codex\|Claude\|Copilot`,
a hook-guard cross-runtime test that includes the v2-new hook-activation
handshake, and a path/line-ending regression suite (INV-001, INV-003). Its
role is deliberately narrow and residual: every other Foundation Epic
(A1–A7) carries its own new script/skill/hook/schema's own 3-environment
Done condition inside its own package (decision doc §7 v2, INV-001); this
epic never re-specifies that per-Epic work. What A8 owns instead is proof
that the *composition* of those per-Epic surfaces — real files, handed off
between real CLI sessions, on real installed toolchains — behaves as this
repository's own README already claims ("スキル・エージェント・フック・
スクリプトがリポジトリ内ファイルを通じて相互ハンドオフ", INV-015), and
one specific, ADR-cited exception: Epic A1 structurally defers the
live-host half of its own hook-activation handshake proof to this epic by
name, as this epic's own mandatory Done condition (ADR-0019; INV-004–
INV-007) — a verification duty only a real host session can discharge, not
a re-implementation of A1's own script.

This package is Phase 1 (specification) only: `investigation.md`,
`requirements.md`, `design.md`, `acceptance-tests.md`. No test code,
fixtures, or registry edits are produced by this task; `tasks.md` and
`traceability.md` follow in a later phase once this package passes
`spec-review-loop`.

## Target Users

- **sdd-forge maintainers** who need a single, authoritative statement of
  which cross-runtime behaviors are proven automatically on CI, which
  require a one-time human-attended CLI session, and exactly what evidence
  a Phase 2/3 implementer must produce for each (REQ-006) — before ever
  claiming "3環境対応" is complete for the Foundation as a whole.
- **A future CI run** (`.github/workflows/test.yml`) that already runs a
  3-OS matrix (INV-014) and already has one direct-invocation hook-guard
  job (`cli-hook-enforcement`, INV-013) this package's REQ-002/REQ-003 must
  extend rather than duplicate.
- **Epic A1 implementers**, who need this package's REQ-003/design.md to
  know exactly what live-host evidence discharges the Done condition their
  own spec explicitly defers here (INV-004–INV-006), so Epic A1's own
  `impl-review-loop`/merge is never blocked on an undefined downstream
  proof.
- **A human operator** running a one-time live-host CLI session where no
  automated path exists (REQ-006) — this package fixes the exact record
  format that session must produce so its result is auditable identically
  to an automated CI artifact.

## Problems

- Decision doc §7 v1 required both "every Epic ships its own 3-environment
  task" and "A8 completes 3-environment work inside one Epic" — a
  contradiction v2 resolves by role split (INV-001), but no package before
  this one restates that split as an enforceable scope boundary for A8
  itself; without one, a future Phase 2/3 task risks silently re-absorbing
  per-Epic work A8 was never supposed to own.
- README.md already asserts a specific, testable cross-runtime behavior —
  file-mediated handoff between Claude Code, Codex CLI, and Copilot CLI
  (INV-015) — that no existing suite exercises with more than one real CLI
  session in the same fixture run; `tests/cli-hook-enforcement.ps1` is the
  closest existing asset and it explicitly never launches any of the three
  CLIs as a session (INV-013).
- `install.sh`/`install.ps1`/`uninstall.sh`/`uninstall.ps1` already support
  a `--target` axis with meaningfully different per-CLI registration
  behavior (INV-010), but no existing suite runs the full
  install→verify→uninstall→verify cycle across all four named values with
  an explicit idempotency/zero-residue check.
- Decision doc §7 v2 (new) requires "runtime対応" to mean the hook guard is
  *actually attached and firing*, naming Codex's `plugin_hooks` flag and
  Copilot's subagent non-firing as known gaps a config-only check cannot
  close (INV-002, INV-011, INV-012); the one existing hook-cross-runtime
  test (`cli-hook-enforcement.ps1`, INV-013) is a direct-invocation
  synthetic check that cannot, by its own construction, observe whether any
  of the three CLIs' own native hook subsystem fires for a real,
  unscripted tool call — the exact standalone-script blind spot Epic A1
  names for its own local canary and structurally hands to this epic
  (INV-005, INV-006).
- Epic A1's own canonicalizer already resolves CRLF-vs-LF drift for its own
  content-hashing surface (INV-022), and `.gitattributes` already
  normalizes line endings at the git layer, but neither has ever been
  exercised against this repository's own install/uninstall/skill-file
  surface under a Windows-path-separator, CRLF, or NFC/NFD-filename fixture
  — the concrete gap decision doc §7's "path・line-ending 回帰" item names.
- The installer copies files into a CLI-registered install root
  (`${XDG_DATA_HOME:-$HOME/.local/share}/sdd-plugins`, INV-016) structurally
  independent of later edits to the working repository; `AGENTS.md`'s own
  WFI-004 rule already documents one real, already-occurred instance of a
  plugin-shipped definition silently diverging from its own validator's
  expectation (issue #86, INV-017) — no existing pre-flight or CI check
  catches this class of drift before it causes a downstream failure.
- No file in this repository documents a confirmed, scripted
  ("headless"/non-interactive) invocation contract for any of the three
  CLIs (INV-021); a package that assumes such a contract already exists
  risks specifying an automated test path around a capability that turns
  out not to exist, or — worse — silently substituting a synthetic result
  for a genuine live-host observation.

## Goals

- **REQ-001** (Cross-runtime handoff E2E): specify a fixture-project-based
  end-to-end verification procedure proving that a repository-file artifact
  one runtime produces (e.g. a spec/skill/config file a Claude Code session
  writes) is correctly consumed by a subsequent Codex CLI session, and that
  a file the Codex session in turn produces is correctly consumed by a
  subsequent Copilot CLI session (decision doc §7 v2's role-split item 1;
  README's own claim, INV-015) — for each of the two adjacent CLI pairs and
  for the full three-hop chain. The procedure names, for each of the three
  CLIs independently, its own headless/non-interactive invocation contract
  where one is confirmed to exist, and a normative manual-session record
  format (REQ-006) for any CLI where Phase 2/3 confirms no such contract
  exists (INV-021) — this package fixes the format now so a later
  implementer never has to invent one ad hoc. The v2-new hook-activation
  canary probe (INV-002) is a mandatory case inside this same fixture chain
  (REQ-003 fixes its own live-host proof procedure; this REQ fixes only
  that the case is present in the handoff fixture, never skipped as
  "out of scope for handoff").
- **REQ-002** (Install/uninstall matrix): specify the exact
  install→verify→uninstall→verify cycle run against each of the four named
  `--target` values `All\|Codex\|Claude\|Copilot` (decision doc §19's own
  named four-value matrix; INV-010), asserting idempotency (a second
  install over an already-installed state produces the identical
  registered/copied result) and zero residue (a post-uninstall filesystem
  and CLI-registration state is indistinguishable from pre-install, modulo
  explicitly-named exceptions design.md fixes). It fixes the division of
  labor between a single local macOS run (fast iteration, one OS) and the
  existing 3-OS CI matrix (INV-014) — never proposing a new CI topology —
  and records `--target FilesOnly` as an explicitly out-of-matrix fifth
  value (INV-010; Non-goals).
- **REQ-003** (Hook guard cross-runtime test, including the live-host
  hook-activation handshake): specify (a) a cross-runtime guard-behavior
  fixture — self-approval denied, benign edit allowed — exercised through
  each of the three runtimes' own real invocation shape, extending rather
  than duplicating the existing `tests/cli-hook-enforcement.ps1` direct
  -invocation/config-drift checks (INV-013); (b) both states of Codex's
  `plugin_hooks` feature flag (enabled/disabled) as independently asserted
  fixture branches, and Copilot's known subagent non-firing case as an
  explicitly asserted, documented expected-state (never a silently passing
  gap) (INV-002, INV-011, INV-012); and (c) the live-host hook-activation
  handshake proof ADR-0019/Epic A1 structurally defer to this epic by name
  as its own mandatory Done condition (INV-004–INV-007) — a genuine,
  attributable, human-session-backed observation that each runtime's own
  installed hook subsystem denies a real, unscripted agent tool call,
  never a synthetic/fixture-only substitute (Safety constraints,
  investigation.md). Once Epic A1 merges, all five of its migrated
  consumer entry points (INV-007) are exercised per runtime, in a
  fingerprinted inventory (AC-016), rather than only a standalone canary
  script or a single sampled entry point.
- **REQ-004** (Path/line-ending regression): specify a cross-platform
  fixture matrix covering (a) Windows path-separator handling in
  install/uninstall output and any generated file path, (b) CRLF-vs-LF
  content at the `.gitattributes` layer (INV-022) — explicitly scoped to
  this epic's own install/uninstall/skill-file surface, never re-specifying
  Epic A1's own canonicalizer-layer CRLF handling, which stays that epic's
  own AC/test — and (c) NFC-vs-NFD filename/content normalization across a
  macOS-authored, Windows/Linux-consumed fixture. Each fixture asserts
  against this repository's own existing `.gitattributes` contract
  (INV-022), never a new, competing normalization rule.
- **REQ-005** (Known environment-difference detection: installed cache vs.
  repository drift): specify a detection check comparing a CLI-installed
  plugin cache (platform-correct default per install.sh/install.ps1's own
  actual install-root convention, or the `--install-root` override,
  INV-016) against the repository's own current install/uninstall-touched
  source surface — `plugins/**`, the Codex agent role TOML files
  (`~/.codex/agents/sdd-*.toml`), the Codex `~/.codex/config.toml` MCP
  delimited block, and the three hook config files (INV-016) — this
  broadened scope resolved and fixed by design.md's own Coverage Scope
  table, never narrowed back to `plugins/**` alone, modeled on the real,
  already-occurred drift class `AGENTS.md`'s WFI-004 rule documents (issue
  #86, "shipped role definitions" diverging from "the validator's
  canonical schema", INV-017) — so that class of divergence is caught by
  a pre-flight/CI check rather than only discovered downstream, the next
  time it recurs.
- **REQ-006** (Automated vs. manual verification boundary): specify a
  single classification — for every check REQ-001 through REQ-005 name —
  of whether it is fully automatable today, automatable pending a Phase
  2/3-confirmed capability (naming exactly which unconfirmed fact gates
  it, INV-021), or inherently manual (a human must attend a live CLI
  session because no scripted equivalent exists or has been confirmed to
  exist). For every manual-required item, this REQ fixes the exact record
  format (session date, operator identity, CLI name+version, runtime OS,
  Codex `plugin_hooks` flag state where applicable, the real tool-call
  transcript/evidence observed, and the pass/fail verdict) a human-attended
  session must produce — so "this was verified" always means either a
  reproducible automated artifact or an auditable manual record, never an
  unlogged claim (orchestrator's own instruction: "自動化を偽装しない").
- **REQ-007** (Process and traceability integrity): specify the
  requirement→AC→concrete-test-case→oracle→evidence-artifact traceability
  discipline this package's own acceptance-tests.md and design.md must
  jointly satisfy — every AC is reachable from exactly one *primary*
  REQ-001–REQ-006 entry above (acceptance-tests.md's own `Requirement`
  column carries exactly one REQ value per AC row; a secondary,
  supporting dependency on another REQ, where one genuinely exists — e.g.
  AC-005's own classification vocabulary depending on REQ-006, or
  AC-028's own aggregate-gate mechanics depending on REQ-006 — is recorded
  in that AC's own prose cross-reference, never by listing a second REQ in
  the `Requirement` column itself), except AC-029/AC-030, whose own
  subject is this package's process integrity (scope-boundary self-check;
  citation compliance) rather than any single artifact REQ-001–REQ-006
  name; those two ACs map to this REQ-007 instead of to "REQ (process),"
  a placeholder label acceptance-tests.md must not use. REQ-007 also
  fixes that design.md's Automated / Manual Classification Table (AC-025)
  is this package's single normative source for every check's
  classification — acceptance-tests.md's own `Test Type` column must
  cite that table's value directly rather than carrying an independent
  `TBD` marker once design.md has already fixed it.

## Non-goals

- Re-implementing or re-specifying any individual Epic's (A1–A7) own
  script/skill/hook/schema, or that Epic's own 3-environment Done condition
  work (`.sh`/`.ps1` pairs, 3 plugin configs, environment-specific tests)
  — decision doc §7 v2's own role split places that inside each producing
  Epic, never inside A8 (INV-001).
- Building or registering any new CI job, workflow file, or test harness.
  This package specifies what a Phase 2/3 task must build and where it
  registers (existing `tests/run-all.{sh,ps1}` and
  `.github/workflows/test.yml` conventions, matching Epic A7's own
  precedent), but authors no such file itself in this task.
- Specifying `--target FilesOnly`'s own install/uninstall behavior as part
  of REQ-002's mandated four-value matrix (INV-010) — `FilesOnly` skips CLI
  plugin registration entirely by design and is orthogonal to the
  cross-runtime concern this epic exists to verify; a future task may add
  it to the matrix as an explicit scope extension, not this package.
- Re-specifying Epic A1's own canonicalizer-layer YAML/CRLF/NFC handling
  (REQ-003/AC-007 of Epic A1's own package) or Epic A5's own
  `resolve-project-context-caller-contract` fixture (design.md item 10) —
  this package's REQ-003/REQ-004 stay consistent with both (read-only,
  INV-008, INV-022) without re-authoring either.
- Building or committing the live-host hook-activation handshake's own
  actual manual-session evidence records — this package fixes the record
  *format* (REQ-006) a later Phase 2/3 task, run against each runtime's own
  real installed toolchain, actually produces.
- Any change to `plugins/**`, `scripts/**`, `.github/**`, `tests/**`,
  `contracts/**`, or `docs/**` in this task.

## User Stories

As a maintainer merging Epic A1's hook-activation handshake, I can point to
this package's REQ-003/design.md and know exactly what live-host evidence
Epic A8 must produce, per runtime, before ADR-0019's two-tier defense claim
is load-bearing — without having to invent that proof's shape myself inside
Epic A1. As a maintainer running the install/uninstall matrix before a
release, I can run one local macOS pass for fast iteration and trust the
existing 3-OS CI job to catch anything platform-specific, without
provisioning new CI infrastructure. As an operator asked to attend a
one-time live CLI session because no automated path exists yet for that
runtime, I can follow this package's REQ-006 record format and know my
session's result is exactly as auditable as an automated CI artifact, never
a weaker, unlogged substitute.

## Acceptance Criteria

- AC-001: A fixture-project definition (design.md) names, for each of the
  two adjacent-runtime handoffs (Claude→Codex, Codex→Copilot), the exact
  repository-relative artifact path, its exact initial bytes, the exact
  nonce-bearing mutation each producing runtime applies, the exact final
  bytes/hash the artifact must carry, and a machine-checkable
  `consumer_observable` oracle (not a free-text description) proving the
  consuming runtime actually used the artifact (not merely that the file
  exists) — resolving REQ-001's own fixture contract, with no
  implementer-discretion gap, before any Phase 2/3 task authors it.
- AC-002: The Claude→Codex handoff step is independently verifiable: a
  file a Claude Code session produces is read, and its content correctly
  influences, a subsequent Codex CLI session's own output or behavior.
- AC-003: The Codex→Copilot handoff step is independently verifiable,
  symmetric to AC-002.
- AC-004: The full three-hop chain (Claude→Codex→Copilot) is verified as
  one continuous fixture run, asserting the final Copilot-consumed state
  reflects both upstream steps' own contributions — the literal claim
  README.md:193 makes (INV-015).
- AC-005: For each of the three CLIs independently, design.md names either
  (a) a confirmed headless/non-interactive invocation contract (command,
  flags, exit-code/output contract) this package cites with file:line or
  external-doc evidence, or (b) an explicit "unconfirmed as of this
  package" marker deferring to REQ-006's manual-session record format —
  never an assumed contract with no supporting evidence (INV-021).
- AC-006: The v2-new hook-activation canary probe (decision doc §7,
  INV-002) is present as a named, mandatory case inside the REQ-001
  fixture chain — its own live-host proof procedure is REQ-003's, but its
  presence in the handoff fixture is asserted here. Named `SKIP` (citing
  Epic A1's tracking issue) until Epic A1 merges (Edge Cases, below).
- AC-007: The install/uninstall matrix (REQ-002) is defined as exactly the
  cycle install→verify→uninstall→verify, run independently against each of
  `--target All`, `--target Codex`, `--target Claude`, `--target Copilot`
  — four independent matrix cells, never one cell generalized to stand for
  another. design.md fixes a target × phase × surface table (marketplace,
  plugin registration, MCP config, Codex agent/config TOML) naming each
  cell's own expected present/absent/unchanged state, the sole oracle
  TEST-007/008/009 evaluate against.
- AC-008: Each matrix cell's own idempotency is asserted: running `install`
  a second time over an already-installed state (same `--target`, same
  `--install-root`) produces a registered/copied state identical to the
  first run — no duplicate marketplace entries, no duplicate config.toml
  blocks (INV-016's Codex-specific per-MCP marker-delimited
  `~/.codex/config.toml` block is the existing idempotency mechanism
  REQ-005/AC-022's own drift check re-uses for that one surface; Claude's
  and Copilot's own marketplace/plugin-registration idempotency is
  independently checked against each CLI's own registration state, since
  neither uses that same marker-delimited-block mechanism — this
  assertion checks, never re-designs, either).
- AC-009: Each matrix cell's own zero-residue post-uninstall state is
  asserted: after `uninstall --target <value>` followed by a re-run
  verify, no installed file, CLI plugin registration, marketplace entry,
  or Codex agent TOML this project's own installer created remains —
  scoped explicitly to files/registrations this project's own installer is
  responsible for (never asserting removal of a user's own pre-existing,
  unrelated CLI configuration).
- AC-010: design.md fixes the exact division of labor between a single
  local macOS install/uninstall matrix run (fast-iteration, pre-CI check)
  and the existing 3-OS CI matrix (`.github/workflows/test.yml`, INV-014)
  — the local run is never presented as a substitute for Windows/Linux CI
  coverage, and the CI registration this epic's Phase 2/3 task adds reuses
  the existing matrix rather than provisioning a new one.
- AC-011: `--target FilesOnly` is explicitly and visibly recorded as
  out-of-scope for the REQ-002 four-value matrix (Non-goals; INV-010) —
  never silently treated as a fifth matrix cell nor silently dropped from
  the evidence trail without explanation.
- AC-012: A cross-runtime hook-guard fixture asserts, through each of the
  three runtimes' own real invocation shape (`node …js --emit exit`,
  `sh\|pwsh …ps1 -Emit exit`, `…--emit copilot` JSON), that a self-approval
  edit is denied and a benign edit is allowed — extending
  `tests/cli-hook-enforcement.ps1`'s existing direct-invocation assertions
  (INV-013) rather than re-authoring an equivalent check from scratch.
- AC-013: Both states of Codex's `plugin_hooks` feature flag (enabled,
  disabled) are independently exercised and asserted through a genuine
  Codex CLI session dispatch — never a config-file toggle plus a direct
  `sdd-hook-guard` invocation, which sets no Codex flag and never engages
  Codex's own native hook dispatcher (investigation.md:50-52;
  `plugins/sdd-quality-loop/hooks/hooks.json:2`). Enabled → the guard fires
  per AC-012, corresponding to the `Codex-enabled-active` cell of the
  REQ-003 semantic live-host matrix (design.md); disabled → the guard does
  not fire and this is the expected, correctly-detected
  `Codex-disabled-expected-unavailable` cell state
  (`CAPABILITY_RUNTIME_UNAVAILABLE` or this epic's own equivalent
  non-firing signal, design.md), never silently treated as a guard failure
  or silently passed over. Until design.md's classification table confirms
  a scripted, native-dispatcher-engaging Codex session contract exists,
  both cells stay `manual-required`/`automated-pending-confirmation`
  (never `automated` on the strength of a direct guard invocation alone).
- AC-014: Copilot's known subagent non-firing case (INV-012) is
  independently exercised inside a genuine Copilot subagent context —
  never a direct guard-script invocation carrying a `copilot` flag/argument
  (`tests/cli-hook-enforcement.ps1`'s existing `--emit copilot` pattern,
  which never launches an actual Copilot subagent, investigation.md:50-52)
  — and contrasted against a genuine Copilot primary-context session in
  which the guard does fire, corresponding to the REQ-003 semantic matrix's
  `Copilot-primary-active` and `Copilot-subagent-expected-unavailable`
  cells (design.md). The subagent cell is asserted as an expected,
  documented non-firing state — with the manual fallback commands
  `docs/troubleshooting.md` already prescribes (INV-012) recorded as this
  fixture's own remediation reference, never silently absent from the
  suite. Until design.md's classification table confirms a scripted,
  real-subagent-dispatching Copilot session contract exists, both cells
  stay `manual-required`/`automated-pending-confirmation`.
- AC-015: A live-host hook-activation handshake proof — a genuine, real
  installed-toolchain session in which the agent's own real tool call is
  intercepted and denied by that runtime's own native hook subsystem — is
  produced independently for each of the REQ-003 semantic live-host
  matrix's five cells (`Claude-active`, `Codex-enabled-active`,
  `Codex-disabled-expected-unavailable`, `Copilot-primary-active`,
  `Copilot-subagent-expected-unavailable` — design.md), discharging the
  ADR-0019/Epic A1 Done-condition delegation (INV-004–INV-006) in full. The
  three "-active" cells' Done condition is a genuine denial `PASS`; the two
  "-expected-unavailable" cells' Done condition is a correctly-detected
  fail-closed/unavailable result, never a silently-passing gap and never a
  cell conflated with a differently-named cell. Each proof is either a
  reproducible automated artifact (if REQ-006's classification finds
  automation available for that runtime) or a REQ-006-format manual-session
  record that additionally satisfies AC-026's fortified
  `live-host-verification-record/v1` fields (A1-issued single-use nonce,
  raw host tool-request/tool-result hashes, host session/event ID,
  installed hook/config digest, session start/end timestamps, and a
  two-party operator + independent-reviewer signed attestation); a
  synthetic/fixture-only result, a direct guard-script invocation, or a
  record missing any fortified field is never accepted in place of either
  (Safety constraints, investigation.md; AC-027). All five cells' records
  are aggregated and re-validated by the `validate-live-host-proof`
  aggregate check (design.md), which is a Done gate for this epic and for
  the AI-DLC Foundation as a whole (AC-028), and a release gate. Named
  `SKIP` (citing Epic A1's tracking issue, `sdd-forge-wt-epic-189`) until
  Epic A1 merges and its handshake script
  (`check-hook-activation-handshake.{py,sh,ps1}`) exists to be exercised;
  a `SKIP` surviving `validate-live-host-proof` after Epic A1 merges is a
  non-zero-exit hard failure, never a passing state.
- AC-016: Once Epic A1 merges, all five of its migrated consumer entry
  points (`sdd-ship`, `sdd-bootstrap`, `sdd-bootstrap-interviewer`,
  `lite-spec`, `lite-gate` — INV-007) are exercised per runtime as part of
  AC-015's own live-host proof, each recorded in a fingerprinted inventory
  (entry-point name, file:line or commit citation into Epic A1's own
  package, and the runtime/cell it was exercised under) — never relying on
  a single sampled entry point to stand in for the remaining four, and
  never a partial inventory silently presented as complete.
- AC-017: `tests/cli-hook-enforcement.ps1`'s existing config-drift and
  direct-invocation assertions (INV-013) remain green and are registered
  as this epic's own REQ-003 "synthetic/regression half," independently of
  and never blocking on AC-015's live-host proof — the two halves are
  asserted as structurally separate checks (design.md), so a live-host
  session's own unavailability (e.g. no CI runner with a real interactive
  CLI session) never fails the synthetic regression suite.
- AC-018: A fixture asserts install/uninstall correctness under a
  Windows-path-separator (`\`) working directory and install root,
  independent of the existing forward-slash-normalized fixture paths
  `install.tests.sh`/`.ps1` already use (INV-016), covering at minimum one
  generated file path and one CLI-registration path string, as one axis of
  the REQ-004 pairwise covering combination matrix (design.md) rather than a
  single isolated case.
- AC-019: A fixture asserts CRLF-vs-LF content parity at the
  `.gitattributes` layer (INV-022) for at least one install/uninstall
  script output and one skill/plugin manifest file this epic's own matrix
  touches — explicitly scoped to git-attribute-layer normalization, never
  asserting or depending on Epic A1's own canonicalizer-layer YAML
  handling (Non-goals) — as one axis of the same REQ-004 pairwise covering
  combination matrix (design.md).
- AC-020: A fixture asserts NFC-vs-NFD equivalence for at least one
  filename or file-content string this epic's own fixtures touch,
  authored on a macOS (NFD-tending) filesystem and consumed by a
  Windows/Linux (NFC-only) checkout, against this epic's own dedicated
  Unicode-normalization contract (design.md: owning algorithm, raw-byte
  preservation and collision policy, per-OS expected path/content bytes) —
  never against `.gitattributes` (INV-022), which normalizes only
  text/EOL and defines no Unicode-normalization rule of its own, and never
  introducing a normalization rule that competes with Epic A1's own
  canonicalizer-layer handling (Non-goals). This is the third axis of the
  same REQ-004 pairwise covering combination matrix (design.md), which fixes a
  per-cell source bytes/name, resolved path, copied bytes, stdout, and
  uninstall-residue oracle across OS × path-separator × LF/CRLF ×
  NFC/NFD × sh/ps1 × install/uninstall, superseding any reading of
  AC-018–AC-020 as three independent single-case spot checks.
- AC-021: design.md's Compatibility/regression table (mirroring Epic A7's
  own Compatibility Matrix convention) enumerates every REQ-004 fixture
  cell with its own single disposition drawn from the same three-value
  vocabulary Epic A7 established (`ASSERT` / `SKIP-with-activation` /
  `N/A`) — REQ-004's own cells happen to resolve to `ASSERT`/`N/A` only
  (no upstream-Epic gating applies to this epic's own install/uninstall/
  skill-file surface), so `SKIP-with-activation` is reserved vocabulary for
  any future cell that does gate on an upstream Epic, never a value this
  package's own table is required to populate — so no path/line-ending cell
  is silently omitted from the
  evidence trail.
- AC-022: A drift-detection check (design.md fixes its exact script
  name/flags, per-platform install-root default) compares a CLI-installed
  plugin cache (platform-correct default per install.sh/install.ps1's own
  actual `INSTALL_ROOT`/`$InstallRoot` value, or an explicit
  `--install-root` override, INV-016) against the repository's own current
  install/uninstall-touched source surface (`plugins/**` plus any script,
  manifest, agent-role, or hook-config file the installer copies or
  generates, matching this package's own Installed-cache-drift Field
  Definition) for a concrete divergence class this package models directly
  on the `AGENTS.md` WFI-004/issue #86 precedent (INV-017): a
  plugin-shipped role/definition file present in the installed cache that
  no longer matches (by content hash) its own repository-source
  counterpart. In addition to this positive-divergence class, at least one
  independent negative-lifecycle case is asserted with an exact diff/exit
  oracle — either a prior-version install followed by a source-tree
  revision, or a direct mutate/delete/add against the installed cache —
  distinct from the always-freshly-installed happy path a same-source
  install-then-immediate-compare alone cannot rule out.
- AC-023: The REQ-005 drift check reports a distinct, non-zero-exit
  diagnostic (design.md names it) when divergence is detected, and a
  distinct, zero-exit pass when the installed cache and repository source
  agree — never a silent pass on divergence (a "not installed" state is
  independently distinguished from an "installed but drifted" state).
  This "not installed never hard-fails" behavior holds only in the drift
  check's own standalone `preflight` mode; run in `verify` mode as
  REQ-002's own post-install verify sub-step (AC-024), a "not installed"
  result is instead a `FAIL`, because a verify step by construction runs
  after an `install` phase already claimed success, so a
  `not_installed` result there means path resolution or the copy itself
  silently failed. design.md's own two-mode schema (`mode: preflight` vs.
  `mode: verify`) is this AC's own normative disambiguation, never a
  design-only elaboration this AC's own text contradicts.
- AC-024: The REQ-005 drift check is wired as a verify-step addition to
  REQ-002's own install→verify→uninstall→verify cycle (design.md), rather
  than specified as an unrelated, standalone check with no lifecycle
  attachment point.
- AC-025: A single classification table (design.md) lists every check
  REQ-001 through REQ-005 name and marks each one `automated`,
  `automated-pending-confirmation` (naming the exact unconfirmed
  capability gating it, INV-021), or `manual-required` (naming the exact
  reason no automated path exists) — exhaustive over every check this
  package names, never partial.
- AC-026: A single manual-session record schema (design.md;
  `live-host-verification-record/v1`) fixes the required fields for every
  `manual-required` (and `automated`-classified, once upgraded) item
  AC-025's table names: session date (its own field, independent of the
  start/end timestamps it is derived from), session start/end timestamps,
  operator identity plus a resolvable operator key ID, an independent
  reviewer identity plus a resolvable reviewer key ID distinct from the
  operator's, an A1-issued single-use challenge nonce recorded in a
  dedicated nonce-issuance ledger, references to the committed raw host
  tool-request and tool-result capture files plus their sha256 hashes
  (independently recomputable from those files, never a bare claimed
  hash), a host-issued session ID and event ID, a digest of the installed
  hook/config file(s) actually exercised (checked against a
  maintainer-committed expected-digest manifest, never trusted
  self-reported), CLI name and version, host OS, Codex `plugin_hooks`
  flag state (when applicable), a human-readable tool-call evidence
  summary, the pass/fail verdict, and a two-party attestation (operator
  signature + independent-reviewer signature, each keyed to a registered,
  trusted signing key) over the record's own canonicalized content hash
  (design.md's own Signing Contract fixes the canonicalization,
  signing-target, and algorithm). A record missing any of these fields,
  reusing a nonce already consumed by a prior record or absent from the
  nonce ledger, whose raw-capture hash does not match its own referenced
  file, whose installed-hook-config digest does not match the expected
  -digest manifest, or carrying an attestation signature that does not
  verify against a trusted key is invalid per this schema (AC-027's
  classification-mismatch/replay guard) — no operator self-attestation or
  freeform transcript excerpt alone discharges AC-028.
- AC-027: No check classified `automated` in AC-025's table may be
  satisfied by a `manual-required`-format record, and no check classified
  `manual-required` may be satisfied by an automated artifact claiming
  live-host observation it did not actually make (e.g. a synthetic
  `cli-hook-enforcement.ps1`-style result presented as AC-015's live-host
  proof) — a structural classification-mismatch rule design.md's Test
  Strategy independently enforces.
- AC-028: The ADR-0019/Epic A1 hook-activation-handshake Done-condition
  delegation (INV-004–INV-006) is considered discharged only once AC-015's
  live-host proof exists, as a fortified `live-host-verification-record/v1`
  (AC-026), for all five cells of the REQ-003 semantic live-host matrix
  (`Claude-active`, `Codex-enabled-active`,
  `Codex-disabled-expected-unavailable`, `Copilot-primary-active`,
  `Copilot-subagent-expected-unavailable` — design.md's own matrix,
  superseding any "three runtimes × two flag states" six-cell framing) —
  or, before Epic A1 merges, is explicitly recorded as `SKIP` (AC-015)
  rather than silently unaddressed. Discharge is computed only by the
  `validate-live-host-proof` aggregate check (design.md), never asserted
  by inspection of individual record files alone; that aggregate check is
  wired as both this epic's own Done gate and a release gate, and reports
  a non-zero exit on any missing, `SKIP`-after-merge, `FAIL`, stale
  (nonce/session mismatch or expired), config-digest-mismatch, or
  duplicate-nonce record among the five cells.
- AC-029: This package's own scope boundary (Non-goals; decision doc §7
  v2, INV-001) is independently checkable: no AC above names a new
  `.sh`/`.ps1` pair, a new plugin hook config, or a new environment-specific
  test this epic's own Phase 2/3 would build *for* another Epic's own
  surface — every AC above verifies composition/integration of artifacts
  another Epic's own package already builds or will build.
- AC-030: This package cites file:line evidence (WFI-011) for every
  checkable factual claim about current repository behavior;
  `spec-review` is expected to reject an uncited claim as a structural gap
  (AGENTS.md rule, INV-020).

## Field Definitions

- **Cross-runtime handoff**: a sequence in which one CLI (Claude Code,
  Codex CLI, or Copilot CLI) produces a repository-tracked file artifact
  that a *different* CLI, in a later invocation, reads and whose content
  measurably influences that later invocation's own output or behavior —
  never merely "the file exists and the second CLI could theoretically
  read it" (README.md:193, INV-015).
- **Live-host hook-activation handshake proof**: a genuine, dated,
  attributable observation — automated or manual per REQ-006's
  classification — that a specific runtime's own natively-installed hook
  subsystem intercepted and denied a real, unscripted agent tool call
  against that runtime's own real CLI session, distinct from and never
  satisfied by a synthetic/fixture-only invocation of the guard script
  directly (the `tests/cli-hook-enforcement.ps1` pattern, INV-013; Epic
  A1's own local-canary scope statement, INV-006), and never satisfied by
  a direct-invocation shim that carries a runtime-name flag/argument
  (e.g. `--emit copilot`) without actually engaging that runtime's own
  native dispatcher or subagent context (investigation.md:50-52). Recorded
  only as a fortified `live-host-verification-record/v1` (AC-026)
  carrying a single-use nonce, raw tool-request/result hashes, session/
  event IDs, an installed hook/config digest, start/end timestamps, and a
  two-party operator + independent-reviewer attestation — an
  unfortified freeform transcript excerpt or self-attested JSON does not
  meet this definition.
- **Semantic live-host matrix cell**: one of the five REQ-003 cells this
  package's live-host proof is organized around — `Claude-active`,
  `Codex-enabled-active`, `Codex-disabled-expected-unavailable`,
  `Copilot-primary-active`, `Copilot-subagent-expected-unavailable`
  (design.md) — never the un-semantic "3 runtimes × 2 Codex flag states =
  6" direct product, which double-counts Claude (no flag dimension) and
  never represents Copilot's primary-vs-subagent dimension at all.
- **Unicode-normalization contract**: this epic's own dedicated
  specification (design.md) of the NFC algorithm, raw-byte preservation
  and collision policy, and per-OS expected path/content bytes governing
  AC-020's NFC-vs-NFD fixture — distinct from `.gitattributes`, whose own
  `text=auto eol=lf` rules (INV-022) normalize only text content and line
  endings and define no Unicode-normalization behavior of their own.
- **Installed-cache drift**: a state in which a CLI-registered install
  root's own copy of a repository-sourced file (script, plugin manifest,
  agent role definition, hook config) no longer matches, by content hash,
  the repository's own current source for that same file — the class
  `AGENTS.md`'s WFI-004 rule and issue #86 already document one real
  instance of (INV-017).
- **Manual-required check**: a verification item this package's REQ-006
  classification marks as having no automated equivalent, either because
  no scripted invocation contract for the relevant CLI has been confirmed
  to exist (INV-021) or because the check's own nature (a human attending
  a live interactive session) cannot be scripted at all.
- **Zero-residue uninstall**: a post-uninstall state in which no file,
  directory, CLI plugin registration, marketplace entry, or Codex agent
  TOML that this project's own installer created remains present, verified
  against a pre-install baseline snapshot of the same install root and CLI
  registration surfaces (REQ-002, AC-009).

## Roles and Permissions

- **Maintainer**: reviews and, where a manual-required live-host session
  is involved (REQ-006/AC-026), attests to the session record's own
  authenticity before that record is treated as discharging the
  ADR-0019/Epic A1 Done-condition delegation (AC-028).
- **Operator (any maintainer or authorized contributor)**: runs a
  manual-required session per REQ-006's record format when no automated
  path exists for a given runtime/check combination; never presents a
  synthetic or partial result as satisfying a manual-required item
  (AC-027); is one of the two required signatories on every
  `live-host-verification-record/v1` (AC-026).
- **Independent reviewer**: a maintainer or authorized contributor other
  than the session's own operator who countersigns a
  `live-host-verification-record/v1` (AC-026) after independently
  checking its nonce, hash bindings, and timestamps — the record's second
  required signatory; a record signed only by its own operator is invalid
  per AC-026/AC-027 (never a self-attested single-signature record).
- **CI**: runs every fully-`automated`-classified check (AC-025) on its
  existing 3-OS matrix (INV-014); never itself produces or claims to
  produce a `manual-required` live-host proof record.
- **Epic A1 implementer**: consumes this package's REQ-003/design.md to
  know exactly which live-host evidence Epic A8 (this epic) is
  responsible for producing on Epic A1's own behalf, per the explicit
  delegation Epic A1's own spec already states (INV-004–INV-006); does not
  need to build any live-host proof mechanism inside Epic A1 itself beyond
  the synthetic/fixture-level handshake script it already specifies.

## Main Workflows

1. A future Phase 2/3 task reads this package and, per REQ-006's
   classification (design.md), confirms or refutes each CLI's own
   headless/non-interactive invocation contract (INV-021) before building
   any automated E2E path — an unconfirmed capability is never silently
   assumed.
2. That task builds the REQ-001 fixture project and its two adjacent-CLI
   handoff assertions (AC-001–AC-004), registering the v2-new
   hook-activation canary probe (AC-006) as a named case, `SKIP`ped
   (citing Epic A1's tracking issue) until Epic A1 merges.
3. That task extends `tests/cli-hook-enforcement.ps1`'s existing
   direct-invocation/config-drift checks (INV-013) with the REQ-003
   cross-runtime fixture (AC-012–AC-014) and the Codex `plugin_hooks`
   flag-state matrix (AC-013), keeping the synthetic/regression half
   (AC-017) independently green.
4. That task runs (or schedules a human operator and an independent
   reviewer to run) the REQ-003 live-host hook-activation handshake proof
   (AC-015) for each of the five semantic live-host matrix cells,
   producing either an automated artifact or a fortified,
   two-party-attested REQ-006-format manual record — discharging the
   ADR-0019/Epic A1 delegation (AC-028) once `validate-live-host-proof`
   confirms all five cells' records exist and pass, or recording `SKIP`
   before Epic A1 merges.
5. That task builds the REQ-002 install/uninstall matrix (AC-007–AC-011)
   as one local macOS run plus a registration in the existing 3-OS CI job
   (AC-010), wiring the REQ-005 drift check (AC-022–AC-024) into its own
   verify step.
6. That task builds the REQ-004 path/line-ending fixture matrix (AC-018–
   AC-021), scoped to this epic's own install/uninstall/skill-file surface
   and explicitly excluding Epic A1's own canonicalizer-layer CRLF
   handling (Non-goals).
7. As Epic A1 merges, a follow-up task un-skips AC-006/AC-015/AC-016
   (verifying Epic A1's own handshake script exists and matches this
   package's citations first) and exercises all five of A1's migrated
   consumer entry points per runtime, in a fingerprinted inventory
   (AC-016) — never a single sampled entry point standing in for the
   remaining four.

## Edge Cases

- A runtime whose headless contract is confirmed unavailable (REQ-006)
  never silently drops out of REQ-001's/REQ-003's own coverage — its own
  cell is recorded `manual-required` in AC-025's table, with a
  REQ-006-format record as its own evidence, never an `N/A`/omitted cell.
- Codex CLI installed but with `plugin_hooks` disabled is a *correctly
  detected non-firing state*, not a test-harness failure (AC-013) — this
  distinguishes "the guard is absent because the runtime does not support
  hooks at all" from "the guard is absent because a required flag was not
  enabled," both of which decision doc §7 v2 requires this epic to
  observe and report distinctly (never conflated into one generic
  "hook did not fire" outcome).
- A Copilot subagent context in which the guard does not fire (INV-012) is
  the expected, already-documented state (AC-014) — this epic's own
  fixture asserts the *presence and correctness* of the documented manual
  fallback (`docs/troubleshooting.md`, INV-012), never that the subagent
  hook itself somehow fires contrary to the repository's own known
  limitation.
- A live-host proof session that observes the hook subsystem *not* denying
  the canary tool call (a genuine, unexpected finding, distinct from a
  known non-firing case like Copilot subagents) is recorded as a FAIL in
  the REQ-006 manual-session record, never silently discarded or re-run
  until it passes — a negative live-host result is itself load-bearing
  evidence this package's design.md Test Strategy must treat as
  actionable, not as noise.
- An installed-cache drift check (REQ-005) run in standalone `preflight`
  mode against an install root that does not exist at all (never
  installed) is a distinct, non-failing "not installed" result (AC-023),
  never conflated with a "drifted" result. The identical "not installed"
  state observed in `verify` mode (REQ-002's own post-install verify
  sub-step, AC-024) is instead a `FAIL` — a verify step that finds no
  install root at all after its own `install` phase claimed success
  indicates the install itself silently did not happen, never a
  non-failing state in that mode.

## Security Boundaries

| Trust Boundary | Auth/Authz Requirement | PII / Data Classification | Regulatory Constraints |
|---|---|---|---|
| B1: live-host hook-activation handshake session (REQ-003/AC-015) | A genuine, real installed-toolchain session is required; a synthetic/fixture-only result is never accepted as discharging the ADR-0019/Epic A1 delegation (AC-028). Manual-required sessions (REQ-006) are attributable to a named operator and reviewed by a maintainer before the record is treated as authoritative evidence (Roles and Permissions). | none (repository fixtures/session transcripts only; no production credentials or user data touched) | none identified |
| B2: installed-cache drift check (REQ-005/AC-022) | Read-only comparison of a local install root against repository source; the check never writes to either side (no auto-remediation, no silent re-install) — divergence is reported, not corrected, by this epic's own scope (design.md). | none | none identified |

This is internal test-infrastructure specification work with no
user-facing entry point; the UI Integration Checklist is not applicable.

## Assumptions

- Epic A1 (`sdd-forge-wt-epic-189`) remains unmerged and in active
  implementation/review through this epic's own Phase 1; its own
  hook-activation handshake script (`check-hook-activation-handshake.
  {py,sh,ps1}`) and five migrated consumer entry points (INV-007) do not
  exist on `main` yet. AC-006/AC-015/AC-016's own `SKIP` status is the
  direct consequence, matching Epic A7's own established SKIP-governance
  precedent (`specs/epic-195-a7-compatibility/requirements.md` REQ-007) —
  this package does not invent a competing SKIP mechanism.
- Epic A5 (`sdd-forge-wt-epic-193`) and Epic A7
  (`sdd-forge-wt-epic-195`) remain unmerged; any cross-epic fact this
  package cites from either (INV-008, INV-009) may shift before this
  epic's own Phase 2/3 begins — re-verified then, per investigation.md's
  Safety constraints.
- `docs/ai-dlc-foundation-decision-v2.md` and ADR-0019 remain the
  authoritative, unrevised source of the Q6/§7 role split and the
  hook-activation-handshake delegation respectively; this package adds no
  new design judgment beyond what they already fix.
- `.gitattributes`, `install.sh`/`install.ps1`/`uninstall.sh`/
  `uninstall.ps1`, and the three hook config files remain this
  repository's own authoritative cross-runtime surfaces through this
  epic's own Phase 2/3; a structural rewrite of any of them (outside this
  epic's own scope) would require re-verifying this package's own file:line
  citations first.

## Open Questions

- OQ-001: whether the Claude Code CLI, Codex CLI, and/or Copilot CLI each
  have a confirmed, stable headless/non-interactive invocation contract
  suitable for CI automation is not resolved by this package (INV-021) —
  design.md's own classification table (AC-025) names this as the single
  gating unconfirmed fact for REQ-001's/REQ-003's own automation boundary,
  to be confirmed empirically by the Phase 2/3 implementer before any
  automated E2E path is built around it, never assumed here.
- OQ-002 (resolved): the REQ-005 drift check covers `~/.codex/
  config.toml` MCP registration blocks, `~/.codex/agents/sdd-*.toml`
  role files (both also install-root-copied, INV-016), and the three
  hook config files (`claude-hooks.json`/`hooks.json`/
  `copilot-hooks.json`) in addition to `plugins/**`-sourced files —
  design.md's own Coverage Scope table and Design Decisions fix this
  broadened scope concretely, each surface carrying its own comparison
  disposition (whole-file hash for `plugins/**`, agent TOML, and hook
  config files; delimited-region hash for the MCP block).
  This package's own REQ-005 (Goals, above) states this resolved scope
  directly, never a `plugins/**`-only scope with the rest deferred.

## Risks

- Critical: this package's REQ-003 live-host proof (AC-015) is the one
  genuine hard dependency on a human-attended session this repository's
  existing CI cannot fully automate today (OQ-001); if Phase 2/3 discovers
  none of the three CLIs' headless modes support the canary-probe
  interaction pattern at all, the ADR-0019/Epic A1 delegation (AC-028) may
  remain permanently `manual-required` rather than becoming CI-automated —
  an accepted, explicitly-classified outcome (REQ-006) rather than a
  defect to silently paper over with a synthetic substitute.
- High: extending `tests/cli-hook-enforcement.ps1` (INV-013) — an existing,
  already-passing 3-OS CI asset — carries regression risk if the new
  cross-runtime/flag-state assertions this epic adds are not kept
  structurally independent (AC-017) from the live-host proof's own
  potentially-manual, potentially-`SKIP`ped status; a Phase 2/3
  implementer conflating the two could accidentally make the existing
  synthetic suite depend on an unavailable live-host session and fail CI
  for an unrelated reason.
- Medium: this package's deliberate 4-file (no layer-spec, no Phase-2)
  scope deviates from `check-sdd-structure.sh`'s own full-profile
  expectation (INV-018), matching Epic A7's own established precedent; a
  `check-sdd-structure.sh <root> epic-196-a8-integration` run before Phase
  2 begins is expected to report six `missing:` lines
  (`ux-spec.md`/`frontend-spec.md`/`infra-spec.md`/`security-spec.md`/
  `tasks.md`/`traceability.md`) — intentional per this task's explicit
  Phase-1-only mandate, not a defect to silently "fix" with placeholder
  files.
