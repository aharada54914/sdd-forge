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
| INV-018 | `plugins/sdd-bootstrap/scripts/check-sdd-structure.sh`'s feature-mode check requires exactly nine per-feature files (`requirements.md design.md ux-spec.md frontend-spec.md infra-spec.md security-spec.md acceptance-tests.md tasks.md traceability.md`); `investigation.md` is not one of the nine (it is this repository's own established *additional* evidence document, not a counted item — INV-018 in Epic A7's own investigation.md confirms the identical convention). As originally recorded, this INV read: "This package's four Phase-1 files (`investigation.md`, `requirements.md`, `design.md`, `acceptance-tests.md`) satisfy 3 of the 9 counted names; a `check-sdd-structure.sh <root> epic-196-a8-integration` run before Phase 2 begins is expected to report exactly six `missing:` lines (`ux-spec.md`, `frontend-spec.md`, `infra-spec.md`, `security-spec.md`, `tasks.md`, `traceability.md`) — the identical deliberate Phase-1 deviation Epic A7 already established as precedent for this repository's own spec-only-Phase-1 packages." Superseded 2026-08-24 (this amendment, under the human's 2026-08-23 frozen-document approval): the package is no longer four files. All nine counted per-feature names now exist in `specs/epic-196-a8-integration/`, so the same command's correct current expectation is **zero** `missing:` lines, and the Phase-1 deviation this INV recorded is discharged rather than outstanding. The original wording is preserved for lineage and must not be used as a current oracle; the nine-file requirement and the `investigation.md`-is-not-counted convention above are unchanged and still hold. | Medium | `plugins/sdd-bootstrap/scripts/check-sdd-structure.sh:58-78`; `specs/epic-195-a7-compatibility/investigation.md:50` (INV-018, precedent citation) |
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
- 2026-08-24: 「A①B①C①でやれ」 — the human's ruling on task-review
  attempt 2 round 1's Critical finding; C① as presented means T-008's
  Done-When is amended to target the `discharged` state (the HUMAN APPLY
  STEP runs Epic A1's now-merged handshake script to produce the real
  session records that discharge the SKIP cells) and the stale
  Out-of-Scope rationale is corrected.
- 2026-08-24: the human's ruling on spec-review attempt 3 round 2's
  reviewer-A `REQ-TESTABILITY` Major — option ① as presented: activate
  AC-006 and make all three Epic-A1-dependent cases (AC-006/AC-015/
  AC-016) consistent, propagating the activation to every statement of
  the rule, while not copying AC-015's "a surviving `SKIP` is a hard
  failure" clause onto AC-006, whose own text carries none. The same
  ruling authorized adding the missing `ux-spec.md` citation below to
  close reviewer B's `APPROVAL-BOUNDARY` Critical. Unlike the two
  entries above, this one is recorded as the substance of the ruling as
  relayed to the executing agent rather than as a verbatim transcript
  string, because no verbatim string is available for it; it is marked
  as such rather than presented as a quotation.

Because these approvals were given in conversation, this committed entry
is itself the durable record of them; no other citable artifact carries
them.

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
- `4aafb7f6120cd20ba89dd1949a474c264ff3c593` — completed the amendment
  in requirements.md's own Assumptions section (spec-review attempt 2
  round 1's REQ-TESTABILITY/CONTRADICTION Critical): the Epic A1
  assumption is flagged as superseded with the original text
  contextualized, mirroring `66d5bdde4cea01b2345f41eee2b4cfcbcf529301`'s
  design.md treatment into the sibling document that was left behind;
  the still-true Epic A5/A7 unmerged statements are untouched. As of
  this commit, `specs/epic-196-a8-integration/requirements.md` =
  `eb1e4c0fb2b0c2304ebedc1d8d27b1fbec3354f5cde5be4c15436ed599f99476`
  (with `Spec-Review-Status: Pending`, the reset-lane state the
  spec-review attempt-2 precheck itself set; the status field is
  normalized by the gates and flips to `Passed` only on a spec-review
  PASS).
- `19005e7741e600ff8b3c4b01cfb33681bb8aec64` — amended T-008 per the
  human's 2026-08-24 ruling 「A①B①C①でやれ」 (C①, above): the HUMAN
  APPLY STEP's Done-When criterion targets the `discharged` state
  (running Epic A1's merged handshake script to produce the genuine
  session records that discharge the five semantic cells, confirmed by
  `validate-live-host-proof` observing `discharged`), replacing the
  `pending` criterion task-review attempt 2 round 1 found unobservable
  under the amended Activation Gate; the stale "not yet merged"
  Out-of-Scope rationale is corrected in T-008 and in T-005's
  cross-reference. Every other Done-When item is byte-identical. As of
  this commit, `specs/epic-196-a8-integration/tasks.md` =
  `e5b6e991a2905fda0ea5e9fb1a6839e9737a9dee4917986865c3cf760359d0aa`.
- `e36a4436f7d12cc368d36e17dcdba04748b4547e` — completed the
  discharged-state amendment across every swept statement of the
  superseded pending-state rule (task-review attempt 2 round 2's
  TRACEABILITY-SYNC Major): traceability.md's Final Status now records
  that a `Done` for T-008 shows `validate-live-host-proof` reporting
  `discharged`, with T-004/T-005's window carrying the designed-red
  hard failure design.md names as intended; tasks.md's
  "pre-merge/post-merge" SKIP-state vocabulary is renamed to design.md's
  own amended "pre-activation/post-activation" names, and the remaining
  temporally-stale phrases ("once Epic A1 merges", "once they exist",
  "`SKIP`ped pre-merge") are corrected to the merged fact. As of this
  commit, `specs/epic-196-a8-integration/tasks.md` =
  `0bd5df1d6a0f8c73c24d07d028d773d4eaf24d9552270159919efb7476bce92d`
  and `specs/epic-196-a8-integration/traceability.md` =
  `b3ca32a2ce5d22208918f58f17a4f1736492023d78ec91dc40f6633e9d039f61`.
- `fa861f510d5bbd6485a4d21ac209487865876bd0` — completed both of
  spec-review attempt 3 round 1's amendments across every swept sibling
  statement. (a) Classification-table scope (reviewer A's REQ-TESTABILITY
  Critical): arbitrated by reading design.md's own table, whose scope
  sentence declares it exhaustive over "every check REQ-001 through
  REQ-005 name" and which contains rows for AC-001–AC-024 plus one AC-028
  row and none for AC-025/AC-026/AC-027/AC-029/AC-030. requirements.md's
  REQ-007 and AC-025 wordings are narrowed to that twenty-five-check set,
  acceptance-tests.md's closing paragraph no longer claims the table
  covers "every check in this document", and the five REQ-006/REQ-007
  process-check rows are re-attributed to this document instead of the
  table; design.md is unchanged because it already stated the surviving
  scope. (b) Phase framing and structure-check expectation (reviewer B's
  CONTRADICTION Major): requirements.md's Phase-1-only paragraph and
  Risks bullet and this file's INV-018 now record that all nine counted
  per-feature files exist and that the correct expectation for
  `check-sdd-structure.sh` is zero `missing:` lines, with each original
  claim preserved verbatim as a dated quotation rather than erased. As of
  this commit, `specs/epic-196-a8-integration/requirements.md` =
  `598dcf737dc2544fc81b59e84a0b1ad201ee4201d03edc38ef9f21b068cd29cf`
  (with `Spec-Review-Status: Pending`, the reset-lane state the
  spec-review attempt-3 precheck set; the status field is normalized by
  the spec gate and flips to `Passed` only on a spec-review PASS),
  `specs/epic-196-a8-integration/acceptance-tests.md` =
  `0324cdaa476f9657a5380fdfe788d156d62640bd74c409c05e8d4b5b41b074ad`,
  and `specs/epic-196-a8-integration/investigation.md` =
  `e95fdcaa97558cb478f3f6b87d194d12327a2a24a4f2f237c17c1e861b87af1c`.
  design.md, tasks.md, traceability.md and the layer specifications are
  deliberately unchanged by this commit: they carry sibling statements of
  the phase framing (design.md:1667, infra-spec.md:249, infra-spec.md:288,
  tasks.md:1258) but are hash-pinned by the impl attempt-5 and task
  attempt-2 round-3 PASS contracts, so amending them here would fire
  those stages' own staleness diagnostics; they belong to those gates.
- `78ffa5e2a53114d7f6adca4342f2330d3cd46a23` — closed both of
  spec-review attempt 3 round 2's findings across every swept sibling
  statement. That commit also carried this entry's own
  investigation.md text; the entry was then reverted out of the tree by
  `42e3d0b75fd99cef12bacf3189e9402b5c021969` and re-landed unchanged
  inside spec-review attempt 3 round 3's own window, after that round's
  precheck and before any reviewer identity was reserved, because
  `plugins/sdd-review-loop/scripts/spec-review-precheck.sh`'s
  `validate_contract` compares this file's *live* SHA-256 against the
  prior round's pinned reviewer manifest and would otherwise refuse to
  open round 3 at all. That is the same window every entry above
  occupies: an investigation.md amendment is pinned by the reviewer
  invocation manifests of the round that reviews it, never by that
  round's own precheck. (a) AC-006 activation (reviewer A's
  `REQ-TESTABILITY` Major), under the human's 2026-08-24 option-①
  ruling above: requirements.md's AC-006 bullet, Main Workflows items 2
  and 7, and the Assumptions "Epic A1 — superseded" bullet, plus
  acceptance-tests.md's AC-006 row, now all record that Epic A1's
  2026-08-08 merge crossed AC-006's own "until Epic A1 merges" trigger,
  that AC-006's substantive presence claim is live and directly verified
  by TEST-006 against this package's own fixture chain, and that AC-006
  carries no hard-failure clause of its own — AC-015's single-clause
  hard-failure sentence is deliberately not copied onto it, and
  design.md's own two-clause SKIP Allowlist Activation Gate predicate
  remains the single normative source for when a `SKIP` record still
  standing for AC-006 becomes a non-zero-exit hard failure. Each
  original sentence is preserved verbatim and marked superseded rather
  than erased. design.md, tasks.md, traceability.md, infra-spec.md,
  frontend-spec.md and security-spec.md are deliberately unchanged
  because every one of them already states this identical rule
  (design.md's SKIP Allowlist Activation Gate and Risks sections;
  tasks.md T-001's Done When and Out of Scope; infra-spec.md:21, :95,
  :144-146, :154; frontend-spec.md:47; security-spec.md's B3 Trust
  Boundary and STRIDE rows) — requirements.md and acceptance-tests.md
  were the only two documents the earlier activation sweep left behind,
  and this amendment brings those two into line with the other six
  rather than moving the rule itself. (b) `ux-spec.md` citation
  (reviewer B's `APPROVAL-BOUNDARY` Critical): the "Later-phase
  artifacts this package references" list below now carries
  `ux-spec.md`'s creating commit and SHA-256; it was verified against
  the amended Overview's nine-file inventory to be the only counted
  per-feature file this section referenced by bare path alone. As of
  `78ffa5e2a53114d7f6adca4342f2330d3cd46a23`, and unchanged since,
  `specs/epic-196-a8-integration/requirements.md` =
  `a240355ad5b237fd6502782423e00497365535272668d79289e48c0473236363`
  (with `Spec-Review-Status: Pending`, the reset-lane state the
  spec-review attempt-3 precheck set; the status field is normalized by
  the spec gate and flips to `Passed` only on a spec-review PASS), and
  `specs/epic-196-a8-integration/acceptance-tests.md` =
  `4d089666d69b5f565c4cd6fd091404e31b15eda063463850a862a816d42797c1`.
  Two boundaries are disclosed rather than silently taken. First, the
  remaining Epic-A1-conditional phrasings in requirements.md's REQ-003
  goal text, AC-016, AC-028 and Main Workflows item 4, and in
  acceptance-tests.md's AC-015/AC-016/AC-028 rows, are statements of
  *those* cases' own rule and not of AC-006's; they were already
  superseded by the Assumptions bullet in commit
  `4aafb7f6120cd20ba89dd1949a474c264ff3c593`, and neither round-2
  reviewer raised them, so they are left as they stand. Second, because
  this amendment inserts lines into requirements.md above AC-015,
  design.md's own raw-line citations of requirements.md (`:283-287`,
  `:389`, `:536`, `:665-670`) drift further; those citations were
  already stale by roughly twenty lines before this commit, design.md is
  hash-pinned by the impl attempt-5 PASS contract, and it is not amended
  here.
- **This commit** — remediated task-review attempt 3 round 1's
  `SCOPE-DISJOINT` and `DEPENDENCY-OVERLAP` Majors (reviewer B; the two
  findings are one defect stated twice). T-002's, T-005's and T-006's
  own `### Blockers` fields read `None` while each one's own Planned
  Files entry required a *named* predecessor's already-staged content to
  exist: T-002 appends its CI steps "after T-001's", T-005 "after
  T-003's", and T-006 "after T-005's", all to the single staged
  `specs/epic-196-a8-integration/human-copy/.github/workflows/test.yml`
  candidate that T-001 creates and every later chain task appends to;
  and each of the three additionally lists
  `specs/epic-196-a8-integration/human-copy/MANIFEST.sha256` as
  *existing*, a classification that holds only once T-001 has run. Each
  of the three now names its own immediate shared-resource-chain
  predecessor — T-002 → `T-001`, T-005 → `T-003`, T-006 → `T-005` — in
  the exact shape T-003 (`T-002`), T-007 (`T-001, T-002, T-003, T-005,
  T-006`) and T-008 (`T-001, T-005`) already use: one line of
  comma-separated task IDs, no new notation. Nothing else in tasks.md is
  touched: no `Status:` line, no `Depends On:` line, no Scope, Done When,
  Out of Scope or Planned Files text — those three lines are the whole of
  this commit's tasks.md diff. As of this commit,
  `specs/epic-196-a8-integration/tasks.md` =
  `0b590a8fc78b6cb51236790325e905eb843a86ae7a32ee57f25fe8902f94fa75`.
  Three boundaries are disclosed rather than silently taken. First,
  unlike every entry above, this bullet is committed *together with* the
  amendment it records rather than in a following "extend the Amendment
  Re-Review Context with `<hash>`" commit, so it cannot cite its own
  commit SHA from inside itself; the post-amendment tasks.md SHA-256
  above is the citable fingerprint, and the commit is otherwise
  identified by its subject line and by being the sole commit whose
  tasks.md diff is exactly these three `### Blockers` lines. Second, the
  `Depends On:` parentheticals of the three amended tasks still read
  "Global Constraints — serialized only; no functional dependency". That
  wording is not contradicted on this package's own reading of the
  field — all three predecessors were already named in those same
  `Depends On:` lines, and `### Blockers` here records the immediate
  shared-resource-chain predecessor whether or not the dependency is
  functional, which is precisely why T-003 lists `T-002` and not the
  transitively-required `T-001`. A reader who instead takes `###
  Blockers` to be strictly the functional subset of `Depends On:` would
  need those parentheticals amended as well; that reading was not taken,
  and the question is recorded here rather than resolved silently.
  Third, the same round's two other Major findings — `TASK-SIZE` (T-005)
  and `EDGE-CASE-COVERAGE` (T-001: AC-006's Activation Gate clause (a),
  "T-005 ... has started", has no defined machine-detection mechanism in
  design.md, security-spec.md or tasks.md, unlike clause (b)'s plain
  file-existence check) — are deliberately **not** remediated by this
  commit and are pending a human decision. This entry records them as
  open, not as waived (Scope, below).
- **This commit** — closes the two Majors the bullet above left open,
  under two human rulings dated 2026-08-25, and resolves the `Depends
  On:` question that bullet recorded rather than answered. All four
  changes land in this single commit deliberately: each stage's
  re-review pins `specs/epic-196-a8-integration/investigation.md` at its
  *current* hash (`impl-review-precheck.sh:241-243`,
  `task-review-precheck.sh:210-213`), so amending across several commits
  would re-stale each predecessor as soon as it had been refreshed.
  Nothing is appended to this file after task-review attempt 3 round 2
  opens.
  **(a) `EDGE-CASE-COVERAGE` (T-001 / AC-006 clause (a)) — human ruling,
  option ①.** "T-005 ... has started" is now defined as: T-005's own
  lifecycle field in `specs/epic-196-a8-integration/tasks.md` reading one
  of `In Progress`, `Implementation Complete`, `Done`. The mechanism
  lives in design.md's SKIP Allowlist Activation Gate as a new
  `Status:`-based detection bullet sibling to the existing
  Existence-based detection bullet, and T-001's and T-005's own
  Scope/Done When now carry the corresponding per-run obligation
  (Test Strategy item 1). The rationale recorded for the ruling:
  `plugins/sdd-quality-loop/scripts/check-task-state.sh:93` already
  parses that same field and enumerates exactly that five-value
  lifecycle, so clause (a) becomes a deterministic read of a
  repository-tracked file through an existing parser — the same shape as
  clause (b)'s file-existence check against `main`, and the "named,
  machine-checkable enforcement mechanism" requirements.md's own AC-006
  bullet already claimed for this gate before any mechanism existed. The
  three tempting alternatives were rejected on evidence, not taste:
  `specs/epic-196-a8-integration/verification/T-005/` already holds four
  files while T-005's lifecycle field still reads `Planned`, so keying
  clause (a) to that directory would activate AC-006 immediately — the
  exact outcome clause (a) exists to prevent; an implementation report is
  required only at `Implementation Complete`, strictly later than
  "started"; a quality-gate report is later still; and an identity-ledger
  record identifies a reviewer, never a task start. Two consequences are
  recorded rather than smoothed over, both accepted by the human. First,
  the gate is **self-flipping**: the moment T-005 moves to `In Progress`,
  clause (a) holds, clause (b) has held since Epic A1's 2026-08-08 merge,
  so AC-006 activates and T-001's canary `SKIP` becomes a non-zero-exit
  hard failure while T-005's own TDD red phase is still running. This is
  stated explicitly in design.md's new bullet and in T-005's own Scope
  as the same designed-red shape this package already accepts for
  AC-015/AC-016, not left to be discovered. It does not make T-001's own
  approved contract unsatisfiable, because T-001 precedes T-005 in the
  serialized chain — which is the guarantee clause (a) was introduced to
  provide. Second, reading the lifecycle field makes an ordinary task
  status edit a security-relevant state change that security-spec.md's
  B3 authorization column did not cover; B3's `AuthN/AuthZ` cell is
  amended to authorize it explicitly, using only content this repository
  already fixes (tasks.md's own Lifecycle sentence for who may write the
  field; `check-task-state.sh` for the deterministic enforcement,
  including its refusal of the three activating values on a task without
  a recorded approval), and discloses rather than mitigates the residual
  that `Blocked` — a lifecycle-legal exit from any active state — is not
  an activating value, so moving T-005 to `Blocked` after activation
  returns AC-006's `SKIP` to a valid, non-failing state. No new security
  judgment beyond that was invented; where the amendment needed content
  the ruling had not authorized, the residual is disclosed instead. Two
  sibling statements of the same fact elsewhere in security-spec.md were
  swept with it — the B3 STRIDE row's mitigation cell and the Test
  Strategy item 5 verification row, both of which described AC-006's
  activation without the mechanism.
  **(b) `TASK-SIZE` (T-005) — human ruling: accept the size with a
  recorded rationale.** T-005 is not split. A new `Size Rationale:` field
  in T-005 records why, and records it as accepted-with-reasons rather
  than as a rebuttal: the reviewer's observation that T-005 is large is
  correct. The reasons: only a 3-way split along AC-026/AC-027/AC-028 is
  traceability-legal, because the other bundled areas (the `matrix_cell`
  discriminator, the Expected-Digest Manifest comparison, the three-state
  SKIP Representation) carry no AC of their own and would yield tasks
  that fail task-reviewer-a's AC-traceability check; that legal split
  does not separate the two heaviest areas, since the Nonce Issuance
  Ledger checks and the Signing Contract's Ed25519 verification both sit
  under AC-026 and AC-028 and would land in the same fragment; the split
  would rewrite the twelve `traceability.md` rows naming T-005 and the
  fifty-five further T-005 citations across seven other documents of this
  frozen package (all counts measured at this commit); it would re-open
  the impl and spec stages, both currently green, at the last stage of
  the walk; and each new task would need a fresh human approval it cannot
  inherit. It is also recorded that the same reviewer passed
  `RISK-APPROPRIATE` and `HIGH-CRITICAL-EVIDENCE` on this same task and
  raised `TASK-SIZE` as Major, not Critical.
  **(c) The `Depends On:` question the previous bullet left open is now
  resolved by amending, and that bullet's reading is superseded.** That
  bullet took `### Blockers` to mean "the immediate shared-resource-chain
  predecessor, functional or not", citing T-003 naming `T-002` and not
  the transitively-required `T-001`. Re-checked against all eight
  entries, that reading does not hold: T-007's `### Blockers` names all
  five of its predecessors, not its immediate chain predecessor alone.
  The reading that fits all three pre-existing entries exactly — T-003
  (`T-002`, its one functional `Depends On:` entry), T-007 (all five,
  each marked functional) and T-008 (`T-001, T-005`, both marked
  functional) — is that `### Blockers` carries exactly the *functional*
  subset of `Depends On:`. Under that convention the three
  `Blockers` values the previous commit recorded are correct and the
  dependencies are genuinely functional (each of T-002/T-005/T-006
  appends to a predecessor's already-staged
  `human-copy/.github/workflows/test.yml` candidate and lists
  `human-copy/MANIFEST.sha256` as existing), but the matching `Depends
  On:` parentheticals were then wrong to read "no functional dependency".
  All three are amended to name the artifact dependency precisely while
  keeping the ordering-only characterisation for the predecessors it
  still fits, and tasks.md's Global Constraints paragraph is given one
  sentence recording that in this package every chain edge after T-001
  turns out to be functional as well as ordered, so its "even where two
  adjacent tasks ... have no functional dependency" allowance is not read
  as a claim about this chain. Leaving the question open into a terminal
  review round would have converted it into a BLOCKED attempt, which is
  why it is answered here rather than carried forward.
  **Pins knowingly moved by this commit.** `specs/epic-196-a8-integration/
  design.md` (pinned by the impl-review attempt-6 round-1 PASS contract at
  `4a2068c5961329faa01572a0b4ae441ce272d3bab2033e1a68c727a4fe5d614e`),
  `specs/epic-196-a8-integration/security-spec.md` (pinned by that same
  contract's four-entry layer map at
  `2918b235e3e80d6245664094027a8992398172fd31d1cc9f5af7e07b6b361975`),
  `specs/epic-196-a8-integration/tasks.md`, and this file. As of this
  commit: tasks.md =
  `219a7a23735ca1667dd13bd42e1781365968442986f3392741f2683b79cc74e3`,
  design.md =
  `14862a80a6f44b49dbf7e1393af66c82c0434bf1109b248e7ff9b4b695fcd18c`,
  security-spec.md =
  `45adc9bd1ffcfc1519444ce61a798b7d0f270851e393729b867c853d2aafcbe7`.
  The consequence was known and accepted before the amendment was
  written: because this file and security-spec.md are both freshness-
  checked (never `continue`d) by `check-workflow-state.sh`'s stage-
  provenance loop, the spec stage and then the impl stage must each be
  re-bound by a provenance re-review, in that order, before task-review
  attempt 3 round 2's own precheck can pass. requirements.md,
  acceptance-tests.md and traceability.md are byte-unchanged by this
  commit. No review finding is waived here; both Majors are closed by
  amendment under a human ruling, and the remaining round-1 findings
  (`SCOPE-DISJOINT`, `DEPENDENCY-OVERLAP`) were closed by the commit the
  bullet above records.
  Like that bullet, this one is committed *together with* the amendment
  it records and so cannot cite its own commit SHA; the three
  post-amendment hashes above are its citable fingerprint.
- This entry is itself an amendment to
  `specs/epic-196-a8-integration/investigation.md`. Its own
  post-amendment SHA-256 cannot be cited from inside itself; it is pinned
  externally by the impl-review attempt-4 round-2 and spec-review
  attempt-2 reviewer invocation manifests and the identity-ledger
  records their reservations append. The pre-amendment
  investigation.md — as pinned by the attempt-4 round-1 reviewer
  manifests (identity-ledger sequences 769/770, evidence commit
  `f1360cd9979ec5094fc94f5d4db21981c7cf9ce0`) — =
  `1e34fc7c0db738d66736194e84521bcd0aaee87a5dd75e62aaa1ee088cd6fdf2`;
  as pinned by the impl attempt-4 round-2 and spec attempt-2 round-1
  manifests (sequences 771/772 and 773/774) =
  `6bd0c353f774d4c736965fe39e33b8df62bb895c46fa5de1950b028a6bd40209`;
  as pinned by the impl attempt-5, spec attempt-2 round-2, and
  task attempt-2 round-1 reviewer manifests (sequences 775-780) =
  `742c27bbace6767d82863defb5c40606ba9c16d7914b993d5f4ef01841a22184`.

### Later-phase artifacts this package references (commit / SHA-256)

- `specs/epic-196-a8-integration/tasks.md` — SHA-256
  `219a7a23735ca1667dd13bd42e1781365968442986f3392741f2683b79cc74e3`,
  last amended in this commit (the clause-(a) detection obligation in
  T-001/T-005, T-005's `Size Rationale:`, the three amended `Depends On:`
  parentheticals and the Global Constraints sentence, recorded as the
  final amendment bullet above; that bullet cannot cite its own commit
  SHA, so this line names the commit the same way)
  (previously `0b590a8fc78b6cb51236790325e905eb843a86ae7a32ee57f25fe8902f94fa75`
  at the `### Blockers` remediation commit
  `e28e12d8bf965640fdfa6726fbf671df0a86d1fe`,
  `0bd5df1d6a0f8c73c24d07d028d773d4eaf24d9552270159919efb7476bce92d`
  at commit `e36a4436f7d12cc368d36e17dcdba04748b4547e`,
  `e5b6e991a2905fda0ea5e9fb1a6839e9737a9dee4917986865c3cf760359d0aa`
  at commit `19005e7741e600ff8b3c4b01cfb33681bb8aec64`, and
  `3568d38c77cb8df69791cf99a2ad5eb234d2ac242715e83de4648ec123ad285d`
  at commit `ff73ebaa7b1e575a7da5d0a1c4fd90f20c8bf117`).
  Defines T-008, the task the amended Activation Gate names as the sole
  owner of the `AC-015`/`AC-016` allowlist entries, and carries the
  task-stage review evidence this feature's earlier attempts pinned.
- `specs/epic-196-a8-integration/traceability.md` — SHA-256
  `b3ca32a2ce5d22208918f58f17a4f1736492023d78ec91dc40f6633e9d039f61`,
  last amended in commit `e36a4436f7d12cc368d36e17dcdba04748b4547e`
  (previously `fce97d001d727d44d08fd051daa016883dd2f5a717e0e1f05a43458163e6efc2`,
  the hash every prior stage's evidence pinned).
- `specs/epic-196-a8-integration/ux-spec.md` — SHA-256
  `c4dfe23795970cdcd3e6afe1bb8bd4cd512b14d638040598722c8b13d416e286`,
  created in commit `7f50a58acfa87b1ee2fb0a548aa626dad66d6d11` and never
  amended since (it carries no amendment-commit line above for that
  reason, not because its fingerprint is unrecorded). It is one of the
  nine counted per-feature files requirements.md's amended Overview names
  as now existing, and it restates this package's own "no user-facing
  entry point; the UI Integration Checklist is not applicable"
  determination in the review harness's canonical layer-file shape; no
  Layer Spec cell in traceability.md cites it directly, since no REQ has
  a UX surface of its own to point at. Added 2026-08-24 to close
  spec-review attempt 3 round 2's APPROVAL-BOUNDARY Critical: it was the
  single artifact named by the amended Overview's nine-file inventory
  that this section referenced only by bare path, and the calibration's
  evidence bar (item 4) is all-or-nothing.
- Impl-review attempt-4 round-1 evidence (the round that raised the
  ASSUMPTIONS-VALID finding `66d5bdde4cea01b2345f41eee2b4cfcbcf529301`
  remediates) — commit `f1360cd9979ec5094fc94f5d4db21981c7cf9ce0`,
  `reports/impl-review/epic-196-a8-integration/attempt-4/round-1/`.

### Scope

This entry documents amendment lineage and authorization; it waives no
review finding. Every check other than the amendment-supersession basis
the shared reviewer calibration's Amendment Re-Review Context section
describes is judged exactly as it would be without this entry.
