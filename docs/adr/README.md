# Architecture Decision Records — numbering convention and index

## Numbering convention

- Every ADR gets a permanent, 4-digit, zero-padded sequential number
  (`0001`, `0002`, ... `0024`, ...).
- A new ADR's number is **existing max number + 1** at the time it is
  created. Numbers are assigned once and are never reused, even if the
  decision is later superseded or the file is renamed.
- Filenames follow `NNNN-kebab-slug.md` (the number, a hyphen, then a
  short kebab-case slug derived from the title).
- Cross-references use either `ADR-NNNN` (e.g. `ADR-0013`) or the bare
  filename (e.g. `0013-sdd-forge-mcp-readonly-server.md`); both forms are
  valid and may appear together.
- `docs/adr/NNNN-*.md` is the only valid ADR location
  (`AGENTS.md` § Source Artifact Locations). Any `specs/*/adr` directory
  is drift and is flagged by `check-sdd-structure`.

## 2026-07-19 duplicate-number resolution

Before this date, three numbers had two files each, assigned independently
by unrelated feature branches that both incremented from the same stale
max:

| Number | First (kept) file | Second (renumbered) file |
|---|---|---|
| 0002 | `0002-repository-workflow-state-integrity.md` | `0002-sdd-forge-mcp-readonly-server.md` |
| 0003 | `0003-turn-first-agent-routing.md` | `0003-mcp-dist-bundle-distribution.md` |
| 0004 | `0004-local-env-mcp-no-exec-probe-allowlist.md` | `0004-ddd-upstream-domain-lane.md` |

The first file at each number keeps its number (it was accepted first).
The second file at each number was renumbered to the next available
numbers at the time of resolution:

- `0002-sdd-forge-mcp-readonly-server.md` → **`0013-sdd-forge-mcp-readonly-server.md`**
- `0003-mcp-dist-bundle-distribution.md` → **`0014-mcp-dist-bundle-distribution.md`**
- `0004-ddd-upstream-domain-lane.md` → **`0015-ddd-upstream-domain-lane.md`**

The three old paths remain in place as permanent tombstone stubs (15 lines
or fewer, pointing at the new number) rather than being deleted, because
frozen `specs/` and `reports/` artifacts historically reference those
paths and must keep resolving. New work must reference the new numbers;
the tombstones are historical-compatibility only, not live content.

## 2026-08-10 duplicate-number resolution

The same class recurred at 0025, by the same mechanism: two unrelated
branches each incremented from the same stale max.

| Number | First (kept) file | Second (renumbered) file |
|---|---|---|
| 0025 | `0025-human-copy-transactional-bundle.md` | `0025-risk-adaptive-adversarial-review-lane.md` |

- `0025-risk-adaptive-adversarial-review-lane.md` → **`0027-risk-adaptive-adversarial-review-lane.md`**

The same rule applies: the file accepted first (human-copy, 2026-07-21)
keeps the number; the second (risk-adaptive, 2026-08-07) moves to the next
free number and leaves a permanent tombstone at its old path.

Two details worth recording, because they are why this went unnoticed for
three days. First, `0025-human-copy-transactional-bundle.md` was never
listed in the index below, so the branch that took 0025 for the
adversarial lane had no way to see the number was occupied — the index
was the detection mechanism and it had a hole in it. Second, every bare
`ADR-0025` reference outside `docs/adr/` resolves to the human-copy
decision, including the hash-bound `specs/epic-189-a1-project-context/`
documents; renumbering the *second* file therefore left every frozen
artifact untouched. Renumbering the first would have required a
provenance re-review of those frozen specs.

The three in-repo references that did mean the adversarial lane all live
in `0026-gate-cross-critique-phase.md` and were updated to ADR-0027.

## 2026-08-11 duplicate-number resolution (third collision at 0025)

The same class recurred at 0025 a **third** time, and this one was
structurally invisible to the 2026-08-10 resolution: the third file,
`0025-registry-discovery-contract.md`, lived only on the
`feature/epic-190-a2-capability-registry` branch (first committed
2026-07-22, `673e42d6`) and had never reached main, so the 2026-08-10
sweep — which audited main's `docs/adr/` and this index — could not see
it or its branch-side index row. The detection hole named in that
resolution (an ADR this index does not list) bit again in a new form: an
ADR committed on an unmerged feature branch is invisible to any
main-side index scan, indexed or not.

| Number | Kept file | Renumbered file |
|---|---|---|
| 0025 | `0025-human-copy-transactional-bundle.md` | `0025-registry-discovery-contract.md` |

- `0025-registry-discovery-contract.md` → **`0029-registry-discovery-contract.md`**

0028 was skipped deliberately: `0028-live-host-proof-ed25519-signing.md`
already exists on `feature/epic-196-a8-integration`. The same all-refs
audit (`git log --all --name-only`, plus `git ls-tree` on every remote
branch, 2026-08-11) also found a **fourth** latent collision — a second,
different 0027 (`0027-component-path-ownership-resolver-semantics.md`)
on `feature/epic-191-a3-path-ownership` — which is not resolved here and
falls due when that branch merges. 0029 was the lowest number free
across every local and remote ref.

A timeline note for future archaeology: by raw first-commit time the
yielding file was actually the earlier one (`673e42d6`, 2026-07-22 08:27
JST, branch-only) — main's `0025-human-copy-transactional-bundle.md`
followed twenty minutes later (`e28ba891`, 08:47 JST), and both files'
Date lines say 2026-07-21. The number nonetheless stays with human-copy,
consistent with both precedent resolutions: it has held 0025 on main
through two prior collision resolutions, every bare `ADR-0025` reference
in the hash-bound `specs/epic-189-a1-project-context/` documents means
it, and renumbering the main-side incumbent would force a provenance
re-review of frozen specs — exactly the cost the 2026-08-10 note records
avoiding. Since 2026-07-22 that note's claim that "every bare `ADR-0025`
reference outside `docs/adr/` resolves to the human-copy decision" no
longer holds branch-wide: the frozen
`specs/epic-190-a2-capability-registry/` documents use bare `ADR-0025`
meaning the Registry Discovery Contract. Disambiguation is by subject
matter, per § Legacy bare-number references below.

Live, unfrozen, unpinned references that meant the Registry Discovery
Contract (`plugins/sdd-quality-loop/scripts/registry_discovery.py`,
`vendor-capability-registry.py`, `tests/registry-discovery.tests.sh`,
`tests/registry-discovery.tests.ps1`, and `CHANGELOG.md`'s epic-190-a2
T-003 entry) were updated to ADR-0029. The frozen
`specs/epic-190-a2-capability-registry/` trio
(requirements/design/tasks), `traceability.md` (pinned by the attempt-7
task-review manifests, seq 0682/0683), and all historical `reports/`
keep their bare `ADR-0025` references and resolve per § Legacy
bare-number references.

## 2026-08-12 duplicate-number resolution (branch-side note, fourth collision, at 0027)

The same class recurred at 0027, and this instance was cross-branch: this
feature branch (`feature/epic-191-a3-path-ownership`) independently
authored `0027-component-path-ownership-resolver-semantics.md` (first
drafted 2026-07-23, locally renumbered from a provisional 0025 slot to
0027 on 2026-08-08 per that file's own Numbering note, at a time when
0025/0026 were the only occupied numbers this branch could see). Separately
and later, main resolved its own second file at 0025
(`0025-risk-adaptive-adversarial-review-lane.md`) by moving it to
**ADR-0027** on 2026-08-10 — a change this branch had not yet merged, so
neither side could see the other's claim on 0027 until this audit.

| Number | Kept file (main, unmerged here) | Renumbered file (this branch) |
|---|---|---|
| 0027 | `0027-risk-adaptive-adversarial-review-lane.md` | `0027-component-path-ownership-resolver-semantics.md` |

Per the same rule as the prior three resolutions, the file that landed on
main first keeps the number; this branch's file — never merged, so not yet
"first" in main's history — moves to the next free number:

- `0027-component-path-ownership-resolver-semantics.md` → **`0030-component-path-ownership-resolver-semantics.md`**

0028 and 0029 were both already claimed elsewhere (`0028-live-host-proof-
ed25519-signing.md` on `feature/epic-196-a8-integration`;
`0029-registry-discovery-contract.md` on
`feature/epic-190-a2-capability-registry`, itself the 2026-08-11
resolution of a *third* collision at 0025 — see that branch's
`docs/adr/README.md` for the full account). An all-refs audit
(`git log --all --name-only` plus `git ls-tree` on every local and remote
branch, 2026-08-12) found 0030 as the lowest number free across every ref.

The only in-branch, non-frozen, non-hash-bound references that meant the
component-path decision — `plugins/sdd-quality-loop/scripts/
resolve-component-paths.py` (two comment references) — were updated to
ADR-0030. The frozen `specs/epic-191-a3-path-ownership/` trio
(`requirements.md`, `design.md`, `tasks.md`), `traceability.md` (pinned by
the attempt-7 task-review manifests, seq 0684-0687), and all historical
`reports/` and `docs/review-tickets/` records keep their bare `ADR-0027`
references as accurate statements of what was true when each was written.

**Reconciled on merge (2026-08-13).** When this section was written, this
branch had not yet merged main's own 2026-08-10 and 2026-08-11 resolution
sections, so it recorded only this branch's half of the fourth collision and
deferred full reconciliation to the merge. That merge is this one. Main's two
sections now stand above this one in date order, the Index below carries all
four resolutions' rows, and every tombstone from both sides is kept. Main's
2026-08-11 section had already anticipated this collision, naming it as one
"not resolved here" that "falls due when that branch merges"; it is resolved
here, exactly as both sides described.

## Legacy bare-number references

Tombstone stubs resolve a *path* reference (e.g.
`0002-sdd-forge-mcp-readonly-server.md`) to its new number. They do not by
themselves resolve a **bare** `ADR-NNNN` reference (no filename) written
inside a frozen `specs/` or `reports/` artifact before the 2026-07-19
renumbering — at the time those artifacts were written, three numbers
(0002/0003/0004) each had two ADRs assigned, so a bare number alone is
ambiguous. Disambiguation is by **the subject matter of the surrounding
reference context** (what decision the artifact's text is actually
describing), not by the number alone.

**General rule**: any frozen artifact written before 2026-07-19 that
references ADR-0002, ADR-0003, or ADR-0004 in the sense of the topic
that was renumbered (read-only MCP server / dist-bundle distribution /
DDD upstream domain lane, respectively) resolves to ADR-0013, ADR-0014,
or ADR-0015 respectively — regardless of which `specs/` or `reports/`
directory it appears in, and regardless of whether the citing text is a
spec, a report, or a CI comment. The table below lists the
frozen-artifact families known to contain such references as of this
writing; it is a **representative enumeration, not an exhaustive one** —
any other frozen artifact found later that references one of these
numbers in the same renumbered sense resolves the same way under the
general rule above, without requiring a table update first.

| Frozen artifact family | Bare reference | Resolves to |
|---|---|---|
| `specs/sdd-forge-mcp/**` and its related `reports/` | `ADR-0002` (read-only MCP server) | ADR-0013 |
| `specs/sdd-forge-mcp/**` and its related `reports/` | `ADR-0003` (dist-bundle distribution) | ADR-0014 |
| `specs/ci-mcp/**` and its related `reports/` | `ADR-0003` (dist-bundle distribution) | ADR-0014 |
| `specs/local-env-mcp/**` and its related `reports/`, where the reference is to the dist-bundle distribution pattern (not to local-env-mcp's own decision) | `ADR-0003` (dist-bundle distribution) | ADR-0014 |
| `specs/evidence-deep-verify/**` and its related `reports/` | `ADR-0003` (dist-bundle distribution) | ADR-0014 |
| `.github/workflows/test.yml` comments (e.g. the `local-env-mcp-tests` and `ci-mcp-tests` job headers) | `ADR-0003` (dist-bundle distribution) | ADR-0014 |
| `specs/sdd-domain/**` and its related `reports/` | `ADR-0004` (DDD upstream domain lane) | ADR-0015 |
| `specs/local-env-mcp/**` and other artifacts referencing the no-exec probe allowlist (local-env-mcp's own decision) | `ADR-0004` | ADR-0004 (unchanged — the first-mover at this number keeps it) |
| `specs/epic-190-a2-capability-registry/**` and its related `reports/` (implementation, impl-review, quality-gate) | `ADR-0025` (Registry Discovery Contract) | ADR-0029 |
| `specs/epic-189-a1-project-context/**` and its related `reports/` | `ADR-0025` (human-copy transactional bundle) | ADR-0025 (unchanged — the incumbent at this number keeps it) |
| `specs/epic-191-a3-path-ownership/**` and its related `reports/` and `docs/review-tickets/` | `ADR-0027` (component path ownership resolver semantics) | ADR-0030 |
| Any artifact predating 2026-08-10 | `ADR-0027` (risk-adaptive adversarial review lane) | ADR-0027 (unchanged — main's incumbent at this number keeps it) |

New work must always cite the current number or filename directly and
must never rely on a bare legacy number.

## Index

| Number | Title | Status |
|---|---|---|
| 0001 | Add an independent specification-review gate | Accepted |
| 0002 | Repository-wide workflow-state integrity | Proposed |
| 0002 | sdd-forge-mcp-readonly-server — renumbered to ADR-0013 | (tombstone) |
| 0003 | Turn-First Agent Routing | Accepted |
| 0003 | mcp-dist-bundle-distribution — renumbered to ADR-0014 | (tombstone) |
| 0004 | local-env-mcp は実行機能を提供せず固定 allowlist プローブのみで環境情報を取得する | Proposed |
| 0004 | ddd-upstream-domain-lane — renumbered to ADR-0015 | (tombstone) |
| 0005 | Cursor / VS Code への MCP 登録は installer の冪等 JSON upsert で行う | Proposed |
| 0006 | ci-mcp は GitHub Actions を read-only(GET 専用)で提供し write 機能を持たない | Proposed |
| 0007 | レビュー後アーティファクト更新の再バインドは「provenance 再レビュー(新 attempt)」で行い、バリデータには選択的再バインド機構を追加しない | Proposed |
| 0008 | evidence_deep_verify は署名鍵を読まず署名を検証せず、git 祖先検証も host-deferred とする | Proposed |
| 0009 | evidence_deep_verify は host スクリプトの正準式を再発明せず逐語一致で再実装する | Proposed |
| 0010 | ループ状態機械の唯一のレジストリとして機械可読ループインベントリを採用し、fixture-profile 語彙 greenfield/brownfield と cap_source 軸を定義する | Proposed |
| 0011 | Handle-relative protected-file publication | Accepted |
| 0012 | Effort/Tier Decoupling for Agent Model Routing | Accepted |
| 0013 | read-only MCP サーバー sdd-forge-mcp を repo 内 mcp/ に置き Evidence 機能を統合する | Accepted |
| 0014 | MCP サーバーはバンドル済み dist/ をコミットして配布し、installer が登録まで行う | Accepted |
| 0015 | DDD upstream domain lane as a seventh plugin | Accepted |
| 0016 | Workflow Axes Separation | Accepted |
| 0017 | Gate Stage Model | Accepted |
| 0018 | Provider Binding Separation | Accepted |
| 0019 | Approval Sidecar Protection | Accepted |
| 0020 | Conditional Predicate DSL | Accepted |
| 0021 | Context Projection Staleness | Accepted |
| 0022 | Lite Capability Upgrade | Accepted |
| 0023 | Track Selection Contract Migration | Accepted |
| 0024 | Workflow State Registry vs. Project Context | Accepted |
| 0025 | Human-Copy Publisher Transactional Bundle | Accepted |
| 0025 | Registry Discovery Contract — renumbered to ADR-0029 | (tombstone) |
| 0025 | Risk-Adaptive Adversarial Review Lane — renumbered to ADR-0027 | (tombstone) |
| 0026 | High/Critical-Only Cross-Critique Phase for the Review Loops | Proposed |
| 0027 | Risk-Adaptive Adversarial Review Lane | Proposed |
| 0027 | component-path-ownership-resolver-semantics — renumbered to ADR-0030 | (tombstone) |
| 0029 | Registry Discovery Contract | Accepted |
| 0030 | Component Path Ownership Resolver Semantics | Accepted |
| 0031 | Node Runtime Baseline 22.19.0 | Accepted |
| 0032 | Concept Design Layer — Phased Introduction | Accepted |
