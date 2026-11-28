# SDD Forge Coding Conventions (Golden Principles R-01 to R-05)

These five rules govern both human contributors and AI coding agents across `sdd-forge` and projects bootstrapped by `sdd-forge` ([ADR-0056](adr/0056-ssot-unification-pitfalls-and-test-lifecycle.md)).

## R-01: SSOT & Context Hygiene (Point, Never Duplicate)
- Never hand-maintain constants, versions, model capabilities, role allocations, or error vocabularies in two places.
- When a rule or behavior is superseded, prune the obsolete text from the SSOT rather than appending patch notes (`Prune, don't patch`).
- Reference SSOT files by pointer or `<!-- BEGIN GENERATED:<id> -->` / `<!-- END GENERATED:<id> -->` blocks.

## R-02: Auto-Discovery & Fail-Closed (No Hardcoded Component Lists)
- Never hardcode plugin or MCP package name arrays in version sync, manifest generation, or validation scripts.
- Always auto-discover `plugins/*/` and `mcp/*/package.json`; fail closed (`exit 1` / `exit 2`) if any component lacks its SSOT manifest (`plugin.manifest.json`) or diverges from `contracts/release-manifest.json`.

## R-03: Remediation-Injecting Lints
- Every sync check, architecture fitness function, or lifecycle gate error must emit:
  1. the offending file path,
  2. the SSOT path to edit, and
  3. the exact repair command (e.g., `Run: node scripts/sync-ssot.mjs --target release`).

## R-04: All-Tier `AGENTS.md` Unification, <=100-Line Index, Zero `CLAUDE.md`
- Claude Code `v2.1.277+` loads `AGENTS.md` natively whenever `CLAUDE.md` is absent.
- Unify all agent instructions on `AGENTS.md` across root and subdirectories (`mcp/AGENTS.md`, `plugins/AGENTS.md`, `tests/AGENTS.md`).
- Keep root `AGENTS.md` at **<= 100 lines** as a concise map/index.
- Prohibit `CLAUDE.md` files and `AGENTS.md` / `CLAUDE.md` symlinks anywhere in the active repository tree (enforced mechanically by `node scripts/sync-ssot.mjs --target conventions --check`).

## R-05: No Direct Edits to Generated Artifacts & GitHub Boundary Protection
- Never edit generated files or `<!-- BEGIN GENERATED:... -->` sections directly; edit the SSOT and run `node scripts/sync-ssot.mjs`.
- Generated files are marked `linguist-generated=true` in `.gitattributes`, and SSOTs / sync scripts / `sdd/approved-test-retirements.json` / `CODEOWNERS` are protected by `CODEOWNERS`.

## Language-Specific Pitfall Catalog & Auto-Generated Guides
- Machine-readable SSOT: [`contracts/pitfalls-catalog.json`](../contracts/pitfalls-catalog.json)
- Auto-generated language guides: [`docs/contributor/coding-standards/`](contributor/coding-standards/)
- Pitfall harvesting & 2x mechanical escalation: `node scripts/harvest-pitfalls.mjs`
