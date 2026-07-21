# ADR 0025: Registry Discovery Contract

Status: Accepted

Date: 2026-07-21

## Context

Epic A2 (Capability Registry, tracking issue #190) introduces the
`contracts/capability-registry.json` Registry, its JSON Schema, and a
companion `contracts/lite-upgrade-reason-catalog.json`, plus four
deterministic scripts around them (Predicate DSL evaluator, Registry
validator, `registry_digest` generator, projection generator) added to the
existing `plugins/sdd-quality-loop/` plugin
(`specs/epic-190-a2-capability-registry/design.md`).

Every one of those scripts, when installed standalone into a consuming
project (Claude Code, Codex CLI, or Copilot CLI, per decision document v2
§16's per-Epic 3-environment Done condition), must locate the Registry
artifacts without a monorepo checkout. `specs/epic-190-a2-capability-registry/`'s
first two design drafts left this undefined or runtime-fragile: the first
draft hardcoded a top-level `contracts/` path with no standalone-install
story at all; the second depended on a runtime-specific plugin-root
environment variable (`${CLAUDE_PLUGIN_ROOT}`) plus undefined "Codex/Copilot
analogs" — a dependency that could not be verified for two of the three
supported runtimes (Epic A2's adversarial spec review, 2026-07-22, closed
per orchestrator ruling P10).

Separately, `contracts/capability-registry.json` is designed as the
repository's sole machine-readable source of truth for Gate/Capability data
(decision document v2 §13), and Epic A2's own Cross-Layer Dependencies
section names Epic A5's Resolver as a specific, anticipated future consumer
of this same Registry via this same discovery path (REQ-002/REQ-004, and,
for full Capability data, the Registry itself). Epic A2's impl-review gate
(round 2, `impl-reviewer-a`, 2026-07-21) found that recording this pattern
only as prose in Epic A2's own `design.md`, with no formal ADR, leaves a
concrete, self-acknowledged implementation-misalignment risk: if Epic A5
were to design its own, materially different discovery convention
independently, the two Epics would carry two undocumented, divergent
patterns for the same problem with no ADR recording either as canonical —
the same class of cross-cutting, reusable mechanism this repository's ADR
convention already formalizes elsewhere (e.g. ADR-0011 for the human-copy
protected-file pattern, which Epic A2 itself also reuses unmodified).

This ADR promotes Epic A2's already-designed discovery contract (unchanged
in substance) to a formal, citable, cross-Epic standard, so that Epic A5 —
or any other future script needing to locate a repository-shipped
`contracts/*` artifact from a standalone plugin install — has one canonical
pattern to adopt rather than an implicit, single-Epic-scoped convention.

## Decision

Any script that needs to locate a canonical `contracts/<filename>` artifact
(a JSON Schema, a data instance, or a versioned catalog) from either an
in-repository checkout or a standalone plugin install resolves it via the
following three-step, **script-relative** procedure — never a
runtime-specific environment variable, and never a hardcoded top-level path
assumption:

1. **Script-relative packaged copy.** Resolve the currently-executing
   script's own file path to its real, symlink-resolved location (the
   equivalent of `os.path.realpath(__file__)`/`readlink -f "$0"` — a script
   invoked through a symlinked entry point, e.g. from an installed plugin's
   own layout, still resolves to its true on-disk directory). From that
   real directory, look for the packaged copy at the fixed, script-relative
   offset `../contracts/<filename>` (i.e., for a script at
   `.../plugins/<plugin>/scripts/<name>.py`, the packaged copy is
   `.../plugins/<plugin>/contracts/<filename>`). If it exists, use it — no
   environment variable of any kind is consulted, and no host-process
   identity (Claude Code vs. Codex CLI vs. Copilot CLI) is inspected.
2. **git-root fallback.** Otherwise, resolve the repository root via
   `git rev-parse --show-toplevel` (falling back to walking upward from the
   script's real directory to the nearest `.git` file/directory if the
   `git` command itself is unavailable), and use
   `<git-root>/contracts/<filename>` (the in-repo development case).
3. **Fail closed.** If neither location resolves, or the artifact's own
   version check (below) fails, exit non-zero with a diagnostic naming both
   attempted paths and the version-check result — never silently proceed
   with a stale or absent artifact.

**Version check — a per-artifact key, not one shared rule.** Each artifact
kind defines its own, independent version check, specific to its own shape;
no script applies one artifact's check to another's file, or assumes a
single shared "schema" field covers every kind. (For Epic A2's own three
artifacts specifically: `capability-registry.json` checks top-level
`schema == "capability-registry/v1"`; `capability-registry.schema.json`
checks that `$schema` is present and `$id` equals its own declared `$id`;
`lite-upgrade-reason-catalog.json` checks top-level
`schema == "lite-upgrade-reason-catalog/v1"`. A future consumer's own
artifact defines its own equivalent check under this same pattern.)

**Vendored-copy drift check (release gate).** The packaging/vendoring step
that refreshes a plugin's packaged `contracts/*` copy from the canonical
top-level `contracts/*` originals must itself support a `--check` mode: for
each artifact, compute the sha256 of the canonical `contracts/<filename>`
and compare it to the sha256 of the packaged
`plugins/<plugin>/contracts/<filename>`; any mismatch is a non-zero-exit
failure naming the stale file. This check gates any release/version bump —
a version bump must not proceed while a packaged copy is stale relative to
its canonical source.

This is a **discovery and freshness** contract only. It does not define how
a consuming script *interprets* the artifact it locates (that is each
artifact's own schema/contract, e.g. Epic A2's `design.md` API / Contract
Plan for the Capability Registry specifically), and it does not by itself
grant any script permission to *write* to a `contracts/*` path — write
access to a protected `contracts/*` file remains governed by the
repository's existing protected-file mechanism (guard-invariants,
human-copy).

## Consequences

- Any future Epic or script needing to locate a repository-shipped
  `contracts/*` artifact from a standalone install (Epic A5's Resolver
  being the first concretely named case) adopts this same three-step
  procedure rather than inventing a second, divergent convention — closing
  the "two undocumented patterns for the same problem" risk Epic A2's
  impl-review round 2 identified.
- No runtime-specific environment variable (`${CLAUDE_PLUGIN_ROOT}` or any
  future Codex/Copilot equivalent) is ever required by this pattern; a
  script following this ADR works identically regardless of which host
  process invoked it, and regardless of whether that host process defines
  any plugin-root variable at all.
- Every consumer of this pattern inherits its fail-closed guarantee: an
  unresolved path or a failed version check is always a diagnosed,
  non-zero-exit failure, never a silent fallback to a stale or absent
  artifact.
- A plugin's packaged `contracts/*` copy is only as fresh as its last
  packaging run; this ADR requires that staleness to be mechanically
  checkable (the vendored-copy drift check) and gated at release time, not
  left as an unmitigated risk each consumer would otherwise have to
  rediscover independently.
- This ADR does not itself obligate Epic A5 (or any other future Epic) to
  adopt this pattern — it makes the pattern citable and canonical so that
  *if* a future Epic's own design intends to reuse it (as Epic A2's own
  Cross-Layer Dependencies section already anticipates for Epic A5), that
  design can reference this ADR by number instead of re-deriving or
  re-describing the same three-step procedure inline.

## References

- `specs/epic-190-a2-capability-registry/design.md` API / Contract Plan,
  "Registry discovery contract (REQ-005)" — the originating, unchanged-in-
  substance design content this ADR promotes.
- `specs/epic-190-a2-capability-registry/design.md` Cross-Layer
  Dependencies and Risks — Epic A5's Resolver named as an anticipated
  future consumer of this same contract.
- `specs/epic-190-a2-capability-registry/investigation.md` — INV-016 (P10
  ruling closing the runtime-variable-dependent second draft).
- `docs/ai-dlc-foundation-decision-v2.md` §13 (Q12, Registry/Pack split,
  sole machine-readable source of truth), §16 (Q15, per-Epic 3-environment
  Done condition).
- ADR-0011 (human-copy protected-file pattern — the precedent for
  formalizing a reusable, cross-cutting mechanism as its own ADR rather
  than leaving it as one Epic's inline design decision).
- Tracking issue #190 (Epic A2), Epic A0 issue #188 (AI-DLC Foundation).
