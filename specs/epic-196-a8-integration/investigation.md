# Investigation: epic-196-a8-integration

Source: repository audit performed in worktree `sdd-forge-wt-epic-196`
(branch `feature/epic-196-a8-integration`) at `main`-derived HEAD `1ed84d2`
(2026-07-22), cross-referenced against the sibling worktrees for Epic A1
(`sdd-forge-wt-epic-189`, `feature/epic-189-a1-project-context`, HEAD
`661e05d`), Epic A5 (`sdd-forge-wt-epic-193`,
`feature/epic-193-a5-capability-resolver`, HEAD `2a05ecb`), and Epic A7
(`sdd-forge-wt-epic-195`, `feature/epic-195-a7-compatibility`, HEAD
`1ed84d2`), read-only, per the task's cross-epic consistency requirement.

## Context

`docs/ai-dlc-foundation-decision-v2.md` §7 (Q6) resolves a v1 contradiction
between "every Epic ships its own 3-environment task" and "Epic A8 completes
3-environment work inside one Epic" by splitting the two: each Epic's own
new script/skill/hook/schema surface gets its own 3-environment Done
condition (§7 v2), while Epic A8 is redefined as **統合検証専用**（integration
verification only): cross-runtime handoff E2E, an install/uninstall
matrix, a hook-guard cross-runtime test (including the v2-new hook-activation
handshake), and a path/line-ending regression suite — never the individual
per-Epic 3-environment build-out itself (INV-001). §7 also introduces, as new
in v2, the requirement that "runtime対応" include *proof the hook guard is
actually attached and firing*, not merely that a skill file is readable —
naming Codex's `plugin_hooks` feature-flag dependency and Copilot's
subagent-hook non-firing as the concrete known gaps a synthetic check cannot
close (INV-002). Epic A1 (unmerged) already redesigned its own
hook-activation handshake around this handoff and explicitly delegates the
live-host half of the proof to Epic A8 as this epic's own mandatory Done
condition (INV-004–INV-006); no Foundation Epic before A8 is in a position
to close that condition, because none of A1/A2/A3/A4/A5/A6/A7 runs a real,
multi-runtime, human/CLI session against a live-installed toolchain — they
each specify or exercise synthetic, fixture-driven behavior only (INV-007,
INV-008).

## Findings

| ID | Finding | Severity | Evidence |
|----|---------|----------|----------|
| INV-001 | Decision doc §7 v2 fixes the exact role split this epic must follow: "各 Epic＝その Epic が追加した成果物（script／skill／hook／schema）の3環境対応（sh+ps1、3種 plugin 設定、環境別テスト）を自 Epic の Done 条件に含む｡Epic A8＝統合検証専用：cross-runtime handoff E2E／install・uninstall マトリクス／hook guard 横断テスト／path・line-ending 回帰。個別成果物の3環境化はA8に持ち越さない。" This epic's REQ-001–REQ-004 map 1:1 onto that four-item list; it never re-specifies a per-Epic script's own `.sh`/`.ps1` pairing, which stays each producing Epic's own Done condition. | Critical | `docs/ai-dlc-foundation-decision-v2.md:255-259` |
| INV-002 | §7 v2 also fixes the hook-activation handshake concept this epic's REQ-003 must make a "必須ケース" of its cross-runtime handoff test: "runtime が対応している」の判定には hook guard が実際に装着・発火していることの検証を含める｡スキルが読めるだけでは不十分（Codex は plugin_hooks feature flag 必須、Copilot の subagent hook は非発火という既知の実態がある）｡実装：…canary 操作を発行し、拒否されなければ hook 不在と判定して Capability Mode を停止する｡この handshake を cross-runtime handoff テスト（A8）の必須ケースにする｡" | Critical | `docs/ai-dlc-foundation-decision-v2.md:260-263` |
| INV-003 | §19's own Epic A8 entry is the literal REQ list this package decomposes: "cross-runtime handoff E2E／install・uninstall マトリクス（All｜Codex｜Claude｜Copilot）／hook guard 横断テスト（稼働ハンドシェイク含む）／path・line-ending 回帰。個別成果物の3環境化は各Epicの Done 条件（§7）であり、A8には持ち越さない。" | Critical | `docs/ai-dlc-foundation-decision-v2.md:547-549` |
| INV-004 | ADR-0019 (Approval Sidecar Protection) states its own two-tier defense claim is "conditioned on the hook-activation handshake (v2 §7)" and never claims unconditional 3-runtime defense from the hook layer alone — the exact dependency this epic's REQ-003 must discharge before that ADR's own claim is load-bearing in any of the three runtimes. | High | `docs/adr/0019-approval-sidecar-protection.md:70-79` |
| INV-005 | Cross-epic (Epic A1, unmerged): A1's own requirements.md explicitly and by name hands the live-host half of the hook-activation handshake proof to this epic — "that live-host, cross-runtime observation is explicitly OUT of A1's own Done condition and is instead Epic A8's own mandatory Done condition (decision doc §9 v2's two-tier defense scope) — an explicit handoff, not a mere related future test," further scoped "(B4, scoped — see REQ-010)". This is a directive this package cannot decline: A1 does not merely mention A8 in passing, it structurally defers a named Done condition to it. | Critical | `FP-A8-A1-B4-DELEGATION`: `specs/epic-189-a1-project-context/requirements.md:2086-2103`, `sha256:6bdf45b64df3d33b980d23527be6e8cf0a81f2cfdc0f5e67a02b8e13df71b99e`, at sibling worktree `sdd-forge-wt-epic-189` HEAD `661e05d` — read-only |
| INV-006 | Cross-epic (Epic A1, unmerged): A1's own acceptance-tests.md states the scope boundary of its own AC-027 in the identical terms — its `--verify-response` proof covers only "the verify-response logic's correctness against synthetic, fixture-recorded evidence ONLY — it does not and cannot prove a LIVE host's hook actually fires/denies for a real, agent-proposed tool call." This is the precise gap REQ-003's live-host proof must fill; A1's own suite is a necessary but insufficient precondition, never a substitute. | Critical | `FP-A8-A1-AC027-SCOPE`: `specs/epic-189-a1-project-context/acceptance-tests.md:49`, `sha256:1acbd3d39c98d024dbf7bfa84d491838cbbf9b11e02138cebdae7bc161d706da`, at sibling worktree `sdd-forge-wt-epic-189` HEAD `661e05d` |
| INV-007 | Cross-epic (Epic A1, unmerged): REQ-009 migrates exactly five consumer entry points — `sdd-ship`, `sdd-bootstrap`, `sdd-bootstrap-interviewer`, `lite-spec`, `lite-gate` — each independently wired to check the hook-activation handshake (step 4 of A1's own consumer-integration Main Workflow) before trusting Capability Mode. This epic's REQ-003 live-host proof, once Epic A1 merges, must be exercised against these five real entry points per runtime (requirements.md's own AC-016 fixes the full 5-consumer fingerprinted inventory as the actual Done condition, a stricter floor than this investigation's own original "at least one" minimum-viable observation) rather than only a standalone canary script, closing the "standalone script proves nothing about host hook installation" gap A1 itself names (INV-006). | High | `FP-A8-A1-ENTRY-POINTS`: `specs/epic-189-a1-project-context/requirements.md:1971-1994`, `sha256:a4ed779dcace2224a12dd4d652adceb8234b2af9ba5b6c7e3f1315d12f6cb28f`, at sibling worktree `sdd-forge-wt-epic-189` HEAD `661e05d`; consumer names also enumerated at `specs/epic-189-a1-project-context/requirements.md:1644-1652` (AC-039, "30 independent assertions total") |
| INV-008 | Cross-epic (Epic A5, unmerged): A5's own design.md item 10 (`resolve-project-context-caller-contract`) fixes an anchor-fingerprint drift check against the live `sdd-bootstrap-interviewer/SKILL.md` and a spy-harness fixture proving "a Context-absent invocation of the interviewer never invokes `resolve-project-context`'s own subprocess at all." Both are synthetic/fixture-level contracts A5 itself defers authoring; this epic's REQ-003 does not re-specify them, but its cross-runtime hook-guard matrix (REQ-003) and its Context-absent handoff fixture (REQ-001) must remain consistent with this non-invocation guarantee once Epic A5 merges, so a live-host observation never contradicts the synthetic contract A5/A7 already fix. Recomputing this citation against Epic A5's *current* HEAD (`2a05ecb`) yields a digest that no longer matches Epic A7's own recorded `FP-A5-CALLER-CONTRACT-10` value (`9b549be9c9d8897c9efd1badbab8a5d4184086649e98a3c31325ef3210561bff`, recorded against Epic A5 HEAD `919f4ebddcf6`) — a live, observed instance of the exact fingerprint-drift class Epic A7's own REQ-007/AC-035(c) is designed to hard-fail on, not a defect in this package. This package records its own, freshly-recomputed digest below and does not attempt to reconcile it with Epic A7's package (out of scope; Epic A7 owns its own allowlist manifest). | Medium | `FP-A8-A5-CALLER-CONTRACT-10` (recomputed 2026-07-22): `specs/epic-193-a5-capability-resolver/design.md:1886-1915`, `sha256:01c76afecbe2f26125ba2e074928b958b6f6444aeca049421bef189cd9e94312`, at sibling worktree `sdd-forge-wt-epic-193` HEAD `2a05ecb` |
| INV-009 | Cross-epic (Epic A7, unmerged): A7's own package scope is explicitly synthetic/CI-fixture based — its byte-identical test "extends `tests/install.tests.sh` / `tests/uninstall.tests.sh`" (a local, `git archive`-cloned fixture, no live multi-CLI session) and its Non-goals list excludes any change to `plugins/**`, `scripts/**`, `.github/**`, `tests/**`, `contracts/**`, `docs/**`. A7 never claims to observe a real Claude/Codex/Copilot session; it proves functional/byte/event compatibility inside one runtime's CI fixture. This is the textual basis for this package's own role-split statement (Overview, requirements.md): A7 = 機能互換 (functional compatibility, synthetic), A8 = 環境横断の実機統合 (cross-environment, real-toolchain integration) — a distinction A7's own text supports but never states in exactly these terms, since A7 predates this epic's own spec (A7 HEAD `1ed84d2` contains no reference to "Epic A8" anywhere in its four spec files). | High | `specs/epic-195-a7-compatibility/requirements.md:14-29` (Overview), `:98-104` (REQ-001 extends install/uninstall tests), `:229-255` (Non-goals); `grep -rn "Epic A8" specs/epic-195-a7-compatibility/` in sibling worktree `sdd-forge-wt-epic-195` returns no matches (2026-07-22) |
| INV-010 | `install.sh`/`uninstall.sh` accept `--target All\|Codex\|Claude\|Copilot\|FilesOnly` (five values); `install.ps1`/`uninstall.ps1` accept the equivalent `-Target` five-value set. This package's REQ-002 is scoped, per this task's own explicit instruction, to the four named values `All\|Codex\|Claude\|Copilot`; `FilesOnly` (file-copy only, no CLI plugin registration/unregistration) is a fifth, orthogonal value this package records as a Non-goal rather than silently omitting it from the evidence trail (Design Decision D-1, design.md). | High | `install.sh:38,77-78`; `uninstall.sh:37,85-86`; `install.ps1:7` (`$Target = "All"`), `:485` (`FilesOnly` branch); `uninstall.ps1:6`; `README.md:170` (`--target All\|Codex\|Claude\|Copilot\|FilesOnly` table row) |
| INV-011 | The three hook configs are runtime-distinct by construction, each with a self-documented caveat this epic's REQ-003 fixture matrix must exercise: `hooks/claude-hooks.json` invokes `node sdd-hook-guard.js --emit exit` directly (exec form, no feature flag). `hooks/hooks.json` (Codex) invokes the identical guard via `sh`/`command_windows` PowerShell and is "requires the 'plugin_hooks' feature flag" per its own `description` field. `hooks/copilot-hooks.json` emits a `permissionDecision` JSON on stdout and fails safe (`deny`) only when the guard script itself cannot be located — it carries no feature-flag precondition text, but the repository's own troubleshooting doc (INV-012) records that Copilot subagent contexts are a known non-firing case regardless of config correctness. | Critical | `plugins/sdd-quality-loop/hooks/claude-hooks.json:1-27`; `plugins/sdd-quality-loop/hooks/hooks.json:1-27` (description field, line 2); `plugins/sdd-quality-loop/hooks/copilot-hooks.json:1-13` |
| INV-012 | `docs/troubleshooting.md`'s own "フックが発火しない" (hook does not fire) entry names exactly the three known non-firing causes this epic's REQ-003 fixture matrix must reproduce and observe live: "Codex では `plugin_hooks` フラグが無効に設定されている" / "Copilot のサブエージェント内では hook が発火しない場合がある（既知の制限）" / "Claude Code の環境で Node.js が利用不可" — and prescribes the exact manual fallback commands (`check-task-state.sh`, `check-contract.sh`, `check-evidence-bundle.sh`) an operator runs when a hook cannot be relied on. `plugins/sdd-quality-loop/references/deterministic-check-policy.md` independently states the identical Copilot caveat: "hooks may not fire inside Copilot subagents." | Critical | `docs/troubleshooting.md:185-204`; `plugins/sdd-quality-loop/references/deterministic-check-policy.md:106-120` |
| INV-013 | `tests/cli-hook-enforcement.ps1` (self-labeled `(B2)` in its own header comment) already runs on the repository's 3-OS CI matrix (`.github/workflows/test.yml`'s `cli-hook-enforcement` job), installing Claude Code CLI unconditionally and Codex/Copilot CLIs best-effort (`continue-on-error: true`). It asserts a self-approval `Edit` is denied and a benign `Edit` is allowed by directly invoking `sdd-hook-guard.{js,sh,ps1}` with each runtime's exact documented invocation shape (`node … --emit exit`, `pwsh … -Emit exit`, `sh … --emit copilot`), plus a static regex "config-drift" check against the three hook JSON files. It never launches an actual `claude`/`codex`/`copilot` session, never sets the Codex `plugin_hooks` flag, and never observes a Copilot subagent context — i.e. it proves the *guard script's own* command-line/JSON contract is correct on each OS, not that a live CLI's own native hook subsystem actually intercepts a real tool call. This is the identical "standalone script proves nothing about host hook installation" limitation A1 investigation.md already names for its own local canary (INV-006), reproduced here at the CI/cross-runtime level — the concrete gap REQ-003's live-host proof step exists to close, and the concrete asset REQ-003's synthetic/regression half should extend rather than duplicate. | Critical | `tests/cli-hook-enforcement.ps1:1-101` (full file; header line 2 `(B2)`; direct-invocation pattern lines 41-77; config-drift check lines 79-91); `.github/workflows/test.yml:541-568` (`cli-hook-enforcement` job: 3-OS matrix, best-effort Codex/Copilot install, `continue-on-error: true`) |
| INV-014 | `.github/workflows/test.yml` runs a `windows-latest, macos-latest, ubuntu-latest` matrix on at least four separate jobs (main test suite, `mcp-tests`, `local-env-mcp-tests`, `ci-mcp-tests`, `cli-hook-enforcement`) — the existing, reusable 3-OS CI resource this epic's REQ-002 install/uninstall matrix and REQ-004 path/line-ending fixture should register against, rather than provisioning a new CI topology. | Medium | `.github/workflows/test.yml:13-19,382-387,442-447,493-498,541-546` |
| INV-015 | README.md's own top-level feature claim is the literal behavior REQ-001's E2E test must verify empirically: "**3環境に対応**：Claude Code、Codex CLI、Copilot CLI の環境でスキル・エージェント・フック・スクリプトがリポジトリ内ファイルを通じて相互ハンドオフし、環境を超えて作業を継続できます。" `claude`/`codex`/`copilot` appear across many existing test files, but in exactly three non-session capacities: (a) literal path/filename fragments (`.claude-plugin/`, `.codex/agents/`); (b) a direct guard-script invocation carrying a runtime-name flag/argument (`hooks.tests.ps1`'s `Invoke-GuardPs … "copilot"`; `cli-hook-enforcement.ps1`'s `--emit copilot`, INV-013); or (c) a deliberately fake shim binary used only to test CLI-*presence* detection (`install.tests.sh`'s own `make_fake_commands` helper: "Create fake codex / claude / copilot shims in a temp bin dir", never a real CLI's own session logic). No suite anywhere in `tests/` launches a real `claude`/`codex`/`copilot` process as an actual interactive/headless agent session and inspects that session's own behavior — this claim has no existing empirical, multi-CLI-session test today. | High | `README.md:193`; `tests/install.tests.sh:150-157` (`make_fake_commands`); `tests/hooks.tests.ps1:140-150` (`Invoke-GuardPs … "copilot"`); `tests/cli-hook-enforcement.ps1:41-77` (INV-013); grep evidence (`grep -rln "claude\|codex\|copilot" tests/*.tests.sh tests/*.tests.ps1`), this worktree, 2026-07-22 |
| INV-016 | `install.sh`'s default `INSTALL_ROOT` is `${XDG_DATA_HOME:-$HOME/.local/share}/sdd-plugins` (POSIX); `install.ps1`/`uninstall.ps1` use a *platform-native*, not identical, default — `%LOCALAPPDATA%\sdd-plugins` (an earlier draft of this finding incorrectly claimed an "identical default"; design.md's own Platform Install-Root Defaults table fixes the correct per-platform values this epic's REQ-005 drift check and REQ-002 matrix use). Each selected CLI (`Claude`/`Codex`/`Copilot`) registers that install root as its own plugin marketplace (`claude plugin marketplace add`, `codex plugin marketplace add`, `copilot plugin marketplace add`) rather than reading the working repository directly. Once installed, the three CLIs' own runtime state (marketplace cache, `~/.codex/config.toml` MCP blocks, `~/.codex/agents/sdd-*.toml`, Claude's own `claude mcp add`-registered list, VS Code's own `mcp.json`) is a **copy** of the source tree at install time, structurally independent of later edits to the repository's own `plugins/**` — the precondition for a "installed cache vs. repo source of truth" drift class this epic's REQ-005 targets. | High | `install.sh:11` (`INSTALL_ROOT` default), `:174-224` (per-CLI marketplace registration), `:261-284` (Codex agent TOML copy); `uninstall.sh:12`; `install.ps1:5` (`$InstallRoot` default, `%LOCALAPPDATA%\sdd-plugins`); `uninstall.ps1:3`; `install.sh:519-533` (per-target MCP registration surface, Claude/Codex/Cursor/VS Code); `README.md:146` (uninstall reverses the identical install root per platform) |
| INV-017 | `AGENTS.md`'s own "Post-implementation provenance re-review" rule (WFI-004) documents a real, already-occurred instance of exactly the drift class REQ-005 must specify a detection check for: "The mismatch between the review gate plugin's shipped role definitions and the validator's canonical schema is tracked in https://github.com/aharada54914/sdd-forge/issues/86." This is the concrete precedent the orchestrator's "reviewer 定義の欠落チェック事例" instruction refers to — a plugin-shipped definition silently diverging from what its own validator expects, discovered only after the divergence caused a review-gate failure, not caught by any existing pre-flight/CI check. | High | `AGENTS.md:58-77` (full rule text, issue reference at line 75-76) |
| INV-018 | `plugins/sdd-bootstrap/scripts/check-sdd-structure.sh`'s feature-mode check requires exactly nine per-feature files (`requirements.md design.md ux-spec.md frontend-spec.md infra-spec.md security-spec.md acceptance-tests.md tasks.md traceability.md`); `investigation.md` is not one of the nine (it is this repository's own established *additional* evidence document, not a counted item — INV-018 in Epic A7's own investigation.md confirms the identical convention). This package's four Phase-1 files (`investigation.md`, `requirements.md`, `design.md`, `acceptance-tests.md`) satisfy 3 of the 9 counted names; a `check-sdd-structure.sh <root> epic-196-a8-integration` run before Phase 2 begins is expected to report exactly six `missing:` lines (`ux-spec.md`, `frontend-spec.md`, `infra-spec.md`, `security-spec.md`, `tasks.md`, `traceability.md`) — the identical deliberate Phase-1 deviation Epic A7 already established as precedent for this repository's own spec-only-Phase-1 packages. | Medium | `plugins/sdd-bootstrap/scripts/check-sdd-structure.sh:58-78`; `specs/epic-195-a7-compatibility/investigation.md:50` (INV-018, precedent citation) |
| INV-019 | `specs/workflow-state-registry.json`'s schema accepts a minimal full-profile entry of exactly `{"feature": "<slug>", "profile": "full"}` (`additionalProperties: false` on that branch); `local-env-mcp` and `ci-mcp` are existing examples of this minimal shape already committed in this worktree. `plugins/sdd-quality-loop/scripts/check-workflow-state.sh` is the existing repository-wide validator for this registry (sha256-based provenance fallback logic, lines 12-30) and is the deterministic verification command this package's own registration commit runs. | Low | `contracts/workflow-state-registry.schema.json:459-476`; `specs/workflow-state-registry.json:277-283` (`local-env-mcp`/`ci-mcp` entries); `plugins/sdd-quality-loop/scripts/check-workflow-state.sh:1-30` |
| INV-020 | `AGENTS.md`'s "Spec factual-claim evidence citations" rule (WFI-011) requires every checkable factual claim in `investigation.md`/`requirements.md`/`design.md` to cite the specific grep/file:line evidence it rests on, in the document itself — the citation convention this investigation follows throughout, and the convention `spec-review` is expected to enforce (AGENTS.md rule). | Medium | `AGENTS.md:137-145` |
| INV-021 | No file anywhere in this worktree (`plugins/`, `scripts/`, `tests/`, `docs/`, `.github/`) documents a scripted, non-interactive ("headless") invocation contract for the Claude Code CLI, the Codex CLI, or the Copilot CLI (`grep -rln "headless\|non-interactive\|codex exec\|claude -p\b" --include="*.sh" --include="*.ps1" --include="*.md" .` returns no matches other than this package's own future files). `tests/cli-hook-enforcement.ps1` (INV-013) sidesteps this exact gap by never launching a session at all. This package's REQ-001/REQ-003/REQ-006 therefore cannot assume any of the three CLIs' headless-mode contract is already fixed by this repository — each runtime's own actual headless support (if any) is an unconfirmed fact this package's design must treat as a Phase-2/3 verification item, not something this Phase-1 package may assert as already true. | Critical | grep evidence, this worktree, 2026-07-22; `tests/cli-hook-enforcement.ps1:1-101` (no session launch, INV-013) |
| INV-022 | `.gitattributes` already normalizes every text extension this repository ships (`* text=auto eol=lf` plus explicit `*.sh`/`*.ps1`/`*.js`/`*.py`/`*.json`/`*.md`/`*.yml`/`*.toml` `eol=lf` rules) — the git-level line-ending defense decision doc §18.3 names as "多層防御として維持" (defense-in-depth, kept as a second layer). Epic A1's own canonicalizer (unmerged) additionally normalizes CRLF-vs-LF YAML to an identical hash by parsing then re-serializing, "a stronger guarantee than `.gitattributes` alone" per A1's own Edge Cases text — this package's REQ-004 fixture matrix must therefore distinguish the git-attribute layer (this epic's own scope: install/uninstall/skill-file line endings across Windows checkouts) from the canonicalizer layer (Epic A1's own scope, already covered by that epic's own AC-007/canonicalizer tests, never re-specified here). | High | `.gitattributes:1-9`; `docs/ai-dlc-foundation-decision-v2.md:505-510` (§18.3); `specs/epic-189-a1-project-context/requirements.md:2016-2020` (Edge Cases, CRLF-vs-LF canonicalization) — read from sibling worktree `sdd-forge-wt-epic-189` |

## Root cause / rationale for a verification-only, no-new-implementation design

Decision doc §7 v2's own designer ruling exists specifically to prevent Epic
A8 from re-absorbing every other Foundation Epic's own 3-environment build
work (INV-001) — a v1 contradiction the orchestrating task's own instruction
("個別成果物の3環境化は各EpicのDone条件であり A8 に持ち越さない") repeats
verbatim. This package's REQ-001–REQ-004 are therefore each phrased as a
verification procedure over artifacts other Epics already build (or will
build), never as a new script/skill this epic ships on some other Epic's
behalf. The one genuine exception decision doc §9/ADR-0019 carve out — the
hook-activation handshake's live-host proof (INV-004–INV-007) — is a
verification duty by its own nature (only a real host session can prove a
real host's hook fires), not an implementation duty, so it fits this epic's
scope without contradicting the v2 role split.

## Safety constraints

- Do not modify `plugins/**`, `scripts/**`, `.github/**`, `tests/**`,
  `contracts/**`, or `docs/**` in this task (Phase 1, spec-only). Every
  file:line citation above is read-only evidence, not a change made by this
  task.
- Do not treat any cross-epic (A1/A5/A7) file cited above as merged or
  stable; each lives on its own unmerged feature branch/worktree and may
  change before this epic's own Phase 2/3 begins. INV-008 is a live
  demonstration of exactly this drift risk materializing between when Epic
  A7 recorded its own citation and when this package recomputed the same
  window — re-verify before authoring tests against any of them. Per
  design.md's Test Strategy item 11 (A5 caller-contract fingerprint
  precheck), re-verification of `FP-A8-A5-CALLER-CONTRACT-10` at Phase
  2/3 start is a mandatory, hard-failing precheck (expected HEAD/blob ID
  match, digest recomputation) — not a `SKIP`/`PASS`-tolerant advisory —
  precisely because INV-008 already observed this drift class occur once
  between Epic A5's and Epic A7's own recorded citations.
- Do not assert or imply that any of Claude Code CLI, Codex CLI, or Copilot
  CLI already has a confirmed, documented headless/non-interactive
  invocation contract in this repository (INV-021); this package's Phase
  2/3 tasks must independently confirm each runtime's own actual capability
  before building an automated E2E path around it, and must never present a
  manual-fallback record as an automated result.
- Do not fabricate a live-host hook-firing observation. Per REQ-003/REQ-006,
  a live-host proof is valid only when it carries a genuine, dated,
  attributable session record; a synthetic/fixture-only result (matching
  the existing `tests/cli-hook-enforcement.ps1` pattern, INV-013) must never
  be presented as satisfying the ADR-0019/A1 live-host Done condition
  (INV-004-INV-006).

## Amendment Re-Review Context

This package is in a declared amendment re-review context: its frozen
Phase 1 documents were amended after earlier attempts of this feature's
review stages had already reviewed and pinned them, the amendments are
human-approved, and this entry — committed into the hash-pinned,
review-pinned package — is the durable, citable approval record.

### Human approval (verbatim, dated)

- 2026-08-23: 「194/195/196の凍結文書について人間は承認する」 — the
  human's approval of the frozen-document amendments for epics 194, 195,
  and 196, given as the authorization for re-running the affected review
  stage against the amended documents at a new attempt.

Because this approval was given in conversation, this committed entry is
itself the durable record of it; no other citable artifact carries it.

### Amendment commits (full hashes) and amended-document SHA-256 values

- `899eba39929cb9a5caf145ea09c1074c32eea3e8` — revised the SKIP Allowlist
  Activation Gate so activation required the owning task to have started
  in addition to the dependency artifacts existing on `main`. As of this
  commit, `specs/epic-196-a8-integration/design.md` =
  `f5dae71c7e53efa40faa5bf629ea2d69eaf554c14e60f240a1ee67f95661fcf0`.
- `caea5556623aa1ba6b26d3dac73404ed203e57ac` — propagated that
  activation-gate revision across the layer specifications and corrected
  its justification. As of this commit,
  `specs/epic-196-a8-integration/design.md` =
  `b3cd3bc5a0b4a908b1bac518c80149f55bc95f4a5d01388c46a5d2f8a9a0c261`,
  `specs/epic-196-a8-integration/frontend-spec.md` =
  `cd8048b30777d10869b6144c23845eb8a7656e12f01d2ee2159df13b531acd82`,
  `specs/epic-196-a8-integration/infra-spec.md` =
  `57d2fe6b722691d06e34ccb7325c30bc045eced805376974c974aa348835f9e4`,
  `specs/epic-196-a8-integration/security-spec.md` =
  `2b707290e5ea1c5e7267687d82ff18f6cbcf91a74134c388c0f4022795d6e5e4`.
- `43b237fa438e2cd23982d5d035f6aa1bbe44ff6f` — narrowed the Activation
  Gate's two-clause predicate to AC-006 alone and restored the
  single-clause AC-015/AC-016 rule requirements.md:389/:536 state,
  closing impl-review attempt 3's Critical. As of this commit,
  `specs/epic-196-a8-integration/design.md` =
  `fc9e3c830f7c13fee5e6b863ccb670ad347a86f97c201c37829b21a1d68a5549`,
  `specs/epic-196-a8-integration/frontend-spec.md` =
  `c992f19d99797c4189fe013380ba28d86c8b18dd691ddf642c09fbaa7aadfa76`,
  `specs/epic-196-a8-integration/infra-spec.md` =
  `59f2f26bbead2b5b5effa89642b58867f168db602b9c0738a65350a1fa02ae9e`,
  `specs/epic-196-a8-integration/security-spec.md` =
  `2918b235e3e80d6245664094027a8992398172fd31d1cc9f5af7e07b6b361975`.
- `66d5bdde4cea01b2345f41eee2b4cfcbcf529301` — completed the amendment in
  design.md's own Assumptions section (impl-review attempt 4 round 1's
  ASSUMPTIONS-VALID Major): the section now flags requirements.md's
  Epic A1 assumption as superseded (Epic A1 merged on 2026-08-08, its
  handshake script and five consumer entry points exist on `main`) and
  keeps the still-true Epic A5/A7 unmerged statements. As of this commit,
  `specs/epic-196-a8-integration/design.md` =
  `4a2068c5961329faa01572a0b4ae441ce272d3bab2033e1a68c727a4fe5d614e`;
  the layer specifications are unchanged from
  `43b237fa438e2cd23982d5d035f6aa1bbe44ff6f`.
- This entry is itself an amendment to
  `specs/epic-196-a8-integration/investigation.md`. Its own
  post-amendment SHA-256 cannot be cited from inside itself; it is pinned
  externally by the impl-review attempt-4 round-2 reviewer invocation
  manifests and the identity-ledger records their reservations append.
  The pre-amendment investigation.md — as pinned by the attempt-4
  round-1 reviewer manifests (identity-ledger sequences 769/770,
  evidence commit `f1360cd9979ec5094fc94f5d4db21981c7cf9ce0`) — =
  `1e34fc7c0db738d66736194e84521bcd0aaee87a5dd75e62aaa1ee088cd6fdf2`.

### Later-phase artifacts this package references (commit / SHA-256)

- `specs/epic-196-a8-integration/tasks.md` — SHA-256
  `3568d38c77cb8df69791cf99a2ad5eb234d2ac242715e83de4648ec123ad285d`,
  last amended in commit `ff73ebaa7b1e575a7da5d0a1c4fd90f20c8bf117`.
  Defines T-008, the task the amended Activation Gate names as the sole
  owner of the `AC-015`/`AC-016` allowlist entries, and carries the
  task-stage review evidence this feature's earlier attempts pinned.
- Impl-review attempt-4 round-1 evidence (the round that raised the
  ASSUMPTIONS-VALID finding `66d5bdde4cea01b2345f41eee2b4cfcbcf529301`
  remediates) — commit `f1360cd9979ec5094fc94f5d4db21981c7cf9ce0`,
  `reports/impl-review/epic-196-a8-integration/attempt-4/round-1/`.

### Scope

This entry documents amendment lineage and authorization; it waives no
review finding. Every check other than the amendment-supersession basis
the shared reviewer calibration's Amendment Re-Review Context section
describes is judged exactly as it would be without this entry.
