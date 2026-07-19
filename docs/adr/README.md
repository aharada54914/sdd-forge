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
