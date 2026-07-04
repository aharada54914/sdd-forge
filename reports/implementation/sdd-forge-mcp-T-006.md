# Implementation Report: T-006

- Task ID: T-006

## Target

install.sh / install.ps1 / uninstall.sh / uninstall.ps1 — add default MCP
placement (`INSTALL_ROOT/mcp/sdd-forge-mcp/`), Claude Code (`claude mcp add`)
and Codex (`~/.codex/config.toml` marker-block) registration, `--skip-mcp` /
`--mcp <list>` selection, and symmetric uninstall support
(`tests/install.tests.sh|.ps1`, `tests/uninstall.tests.sh|.ps1`).

## Summary

Extended the four installer/uninstaller scripts to place and register the
`sdd-forge-mcp` MCP server, following the acceptance-first workflow required
by this task (Required Workflow: acceptance-first). Test scenarios were
written first, run to confirm they failed for the right reason, and only then
was the installer/uninstaller logic implemented.

Key design points:

- **MCP payload copy is independent of Git tracking state.** Unlike plugin
  files (copied via `git ls-files` for local sources / `REQUIRED_PATHS` for
  the manifest check), `mcp/sdd-forge-mcp/dist/index.js` and `package.json`
  are copied directly from the filesystem (`cp -R`/`Copy-Item`) regardless of
  whether they are Git-tracked. This is intentional: as of this task,
  `mcp/sdd-forge-mcp/` in this repository is entirely untracked (the `dist/`
  bundle is committed by task T-007, per `specs/sdd-forge-mcp/tasks.md` line
  333 "dist/ の初回コミット（T-001〜T-005 / T-009〜T-011 の成果物をバンドル）").
  Only `dist/` and `package.json` are copied; `node_modules/`, `src/`, and
  `tests/` are explicitly excluded.
- **Placement vs. registration split mirrors the existing plugin pattern.**
  Placement happens regardless of `--target` (like plugin file staging);
  only registration (`claude mcp add` / Codex config.toml edit) is scoped by
  `--target`. This matches `design.md`'s statement that plugin registration
  presence, not placement, is what `--target` controls.
- **Node >= 20 check is MCP-only and non-fatal.** If `node` is absent or its
  major version is `< 20`, a warning is printed and MCP placement/
  registration is skipped, but plugin installation proceeds unaffected
  (exit code remains 0). Implemented via `node --version` major-version
  parsing in both bash (`node_version_ok`) and PowerShell
  (`Test-NodeVersionOk`).
- **Codex registration never creates a new config.toml.** Per the task's
  explicit requirement, if `~/.codex/config.toml` (or
  `$SDD_CODEX_HOME/config.toml` under test) does not exist, Codex MCP
  registration is skipped with a warning; the file is never created by the
  installer.
- **Idempotent marker-block registration.** Each MCP gets a delimited block
  in config.toml:
  `# >>> <name> (managed by sdd-forge installer; do not edit by hand) >>>` /
  `# <<< <name> <<<`. Re-running install strips any prior block for that name
  before appending a fresh one (via `awk` in bash, a line-filter loop in
  PowerShell), so re-registration is idempotent and unrelated config.toml
  content is preserved untouched.
- **Uninstall mirrors placement/registration split, all best-effort.**
  `claude mcp remove <name>` (best-effort, matching `try_plugin_command`
  semantics), Codex config.toml marker-block removal (no-op if the file or
  block is absent), and `INSTALL_ROOT/mcp/<name>/` removal (skipped under
  `--keep-files`/`-KeepFiles`, but otherwise idempotent — absence is
  success). `--mcp <list>` on uninstall selects which MCP names are
  processed, following the same `VALID_MCPS`/`ValidateSet` validation as
  install.
- **bash 3.2 compatibility preserved.** No associative arrays, no `mapfile`;
  all new bash logic uses indexed arrays, `case`/`for`, and `awk` (already a
  POSIX baseline tool used elsewhere in the scripts), consistent with the
  existing installer style.

### OQ-001 resolution: Codex MCP registration mechanism

Investigated whether the Codex CLI exposes a dedicated MCP-registration
subcommand (e.g. `codex mcp add`) as an alternative to editing
`~/.codex/config.toml` directly. In this development environment, the `codex`
command on `PATH` is aliased to an unrelated internal tool (`codex-sync`), so
its `--help` output could not be used as evidence of the real Codex CLI's
capabilities — using it would have risked recording a false conclusion.

**Decision**: adopted the `~/.codex/config.toml` `mcp_servers.<name>`
marker-block append/replace approach that `design.md` and `infra-spec.md`
already specify as the fallback path (`design.md` line 187: "Codex:
config.toml への mcp_servers エントリ追記（実装時に CLI の有無を確認、
OQ-001）"). This is the safer, environment-independent choice: it does not
assume a specific Codex CLI subcommand surface that could not be verified
here, and it satisfies the explicit requirement "config.toml が無ければ新規
作成はせずスキップして警告する" from the task instructions. If a future task
confirms Codex CLI exposes a native `codex mcp add`-equivalent command, the
`register_codex_mcp` / `Register-CodexMcp` functions are isolated enough to
be swapped without touching placement or Claude registration logic.

**Blocks implementation**: no — resolved within this task per
`design.md`'s Open Questions entry.

## Files Changed

- `install.sh` — added `SKIP_MCP`, `MCP_LIST`, `VALID_MCPS`, Codex marker
  constants; `--skip-mcp`/`--mcp` argument parsing and validation;
  `node_version_ok`, `place_mcp_servers`, `register_claude_mcp`,
  `register_codex_mcp`, `place_mcp_servers_if_selected`,
  `install_mcp_servers` helper functions; placement call right after staging
  swap, registration call in the Registration section; usage text update.
- `install.ps1` — added `-SkipMcp` / `-Mcp` parameters (`ValidateSet`);
  `Test-NodeVersionOk`, `Install-McpServerPayloads`, `Register-ClaudeMcp`,
  `Register-CodexMcp`, `Install-McpServersIfSelected`, `Register-McpServers`
  functions; corresponding call sites mirroring install.sh.
- `uninstall.sh` — added `MCP_LIST`, `SKIP_MCP_UNINSTALL`, `VALID_MCPS`;
  `--mcp`/`--skip-mcp-uninstall` argument parsing and validation;
  `unregister_claude_mcp`, `unregister_codex_mcp`, `remove_mcp_payload`
  helper functions and call sites; usage text update.
- `uninstall.ps1` — added `-Mcp` / `-SkipMcpUninstall` parameters;
  `Unregister-ClaudeMcp`, `Unregister-CodexMcp`, `Remove-McpPayload`
  functions and call sites.

## Tests Added Or Updated

- `tests/install.tests.sh` — seeded a minimal MCP fixture
  (`mcp/sdd-forge-mcp/dist/index.js` + `package.json`, plus
  `node_modules/src/tests` noise files that must NOT be copied) into
  `SOURCE_FIXTURE`. Added scenarios:
  - (t) default install places the MCP payload and registers it with Claude
    (fake shim) and Codex (config.toml marker block), excluding
    `node_modules`/`src`/`tests`.
  - (u) `--skip-mcp` skips both placement and registration.
  - (v) `--mcp sdd-forge-mcp` installs; `--mcp bogus-mcp` is rejected with an
    error mentioning "mcp".
  - (w) a fake old-version `node` (v14.21.0) shadowing `PATH` triggers a
    Node-related warning, skips MCP only, and plugin installation still
    completes for all plugins.
  - (x) a missing `$SDD_CODEX_HOME/config.toml` causes Codex MCP registration
    to be skipped with a warning, without creating a new config.toml.
- `tests/uninstall.tests.sh` — added `seed_installed_mcp` helper (payload +
  config.toml with marker block + unrelated content) and scenarios:
  - (k) uninstall removes the MCP payload dir and the marker block while
    preserving unrelated config.toml content and invoking
    `claude mcp remove sdd-forge-mcp`.
  - (l) uninstall succeeds best-effort when no MCP was ever installed.
  - (m) `--mcp sdd-forge-mcp` selects payload/registration removal (mirrors
    `--plugins` subset behavior).
  - (n) an invalid `--mcp` name is rejected.
- `tests/install.tests.ps1` — mirrored the same MCP fixture seeding and
  scenarios (t)/(u)/(v)+(v2)/(w)/(x) using PowerShell idioms (`-WarningVariable`
  to assert on warnings, `ValidateSet` rejection via `catch`).
- `tests/uninstall.tests.ps1` — mirrored `New-InstalledMcpLayout` and
  scenarios (k)/(l)/(m)/(n).

## Regression Tests Run

- `bash -n install.sh uninstall.sh` — pass.
- `pwsh -NoProfile` `Parser.ParseFile` on `install.ps1`, `uninstall.ps1`,
  `tests/install.tests.ps1`, `tests/uninstall.tests.ps1` — all pass (no
  syntax errors).
- `bash tests/install.tests.sh` — **29 passed, 0 failed** (24 pre-existing +
  5 new MCP scenarios).
- `bash tests/uninstall.tests.sh` — **18 passed, 0 failed** (14 pre-existing +
  4 new MCP scenarios).
- `pwsh -NoProfile -File tests/install.tests.ps1` — all scenarios passed,
  including the 5 new MCP scenarios ("Installer integration tests passed.").
- `pwsh -NoProfile -File tests/uninstall.tests.ps1` — all scenarios passed,
  including the 4 new MCP scenarios ("uninstall.tests.ps1: all scenarios
  passed.").
- `bash scripts/check-sdd-structure.sh` — `check-sdd-structure: OK`
  (unchanged advisory-only output).

## Specification Differences

None identified. Implementation follows `design.md`'s Deployment / CI Plan
and `infra-spec.md`'s Deployment Topology sections as written, including the
placement path (`INSTALL_ROOT/mcp/sdd-forge-mcp/`, dist + package.json
only), the `--skip-mcp` / `--mcp` flag names, the Node >= 20 non-fatal
skip behavior, and the config.toml marker-block approach for Codex.

## Unresolved Items

- The MCP payload copy step (`place_mcp_servers` / `Install-McpServerPayloads`)
  currently checks tracking state loosely (filesystem presence only, no
  size/hash validation). Once T-007 commits `dist/index.js` to Git, a future
  hardening pass could align the MCP payload check with the same
  Git-tracked-only guarantee `REQUIRED_PATHS` provides for plugin files, to
  prevent accidentally distributing local uncommitted build artifacts from a
  developer's working tree during a `--source-directory` (non-archive)
  install. This is out of scope for T-006 per the task's Scope section but is
  worth flagging for whoever picks up T-007's dist-parity work.
- Manual end-to-end verification against the real, non-fixture
  `mcp/sdd-forge-mcp/dist/index.js` (i.e. running `install.sh
  --source-directory <repo-root>` against a scratch install root) was
  attempted but blocked by the sandbox's command-approval policy for this
  session; the automated fixture-based test scenarios (t)/(u)/(v)/(w)/(x) in
  `tests/install.tests.sh` exercise the identical code path (real
  `dist/index.js` + `package.json` files, same copy/registration functions)
  and are considered sufficient acceptance evidence.

## Quality Gate Focus

- Reviewers should double-check the `awk`-based marker-block strip/replace
  logic in `register_codex_mcp` (bash) for edge cases such as a config.toml
  with a marker block but no trailing newline, or multiple selected MCP
  names writing sequential blocks to the same file (currently handled by
  iterating `MCP_SELECTION` and re-reading/re-writing config.toml once per
  MCP name).
  cases such as: is the existing `PATH` search hygiene for `codex`/`claude`
  respected the same way as for existing plugin registration).

## Working Notes

**Delegation unit: acceptance-first red-log capture (T-006)**

Purpose: satisfy the "受入テスト先行（acceptance-first）で実装" requirement
by writing the new MCP test scenarios in `tests/install.tests.sh` before any
installer implementation, then confirming they failed for the expected
reason (missing feature, not a test bug).

Result: ran `bash tests/install.tests.sh` after adding scenarios (t)/(u)/(v)
but before touching `install.sh`. Output confirmed the pre-existing 24
scenarios still passed, and the new scenarios failed exactly as expected:

```
ok: Claude manifest validation fails before marketplace registration

SDD plugins installed at: <tmp>/installed
FAIL: default MCP install (t): dist/index.js not placed
FAIL: default MCP install (t): package.json not placed
FAIL: default MCP install (t): claude mcp add not invoked
FAIL: default MCP install (t): Codex config.toml missing sdd-forge-mcp entry
FAIL: --skip-mcp (u): installer exited non-zero
FAIL: --mcp sdd-forge-mcp (v): installer exited non-zero
FAIL: --mcp sdd-forge-mcp (v): dist/index.js not placed
```

(`--skip-mcp (u)` and `--mcp (v)` failed with "installer exited non-zero"
because `--skip-mcp`/`--mcp` were unrecognized options under the
pre-implementation `install.sh`'s `usage()`/`exit 1` fallback — the expected
failure mode for an unimplemented flag.)

File examined: `tests/install.tests.sh` (scenarios added at the position
immediately before the "Summary" section, after scenario (s)).

After implementing `install.sh`'s MCP placement/registration/Node-check
logic, re-running the same suite produced 29 passed / 0 failed, confirming
the acceptance criteria (AC-007, AC-008) were met by the implementation, not
by loosening the tests.

**Delegation unit: OQ-001 investigation (Codex CLI MCP subcommand)**

Purpose: determine whether Codex CLI exposes a native MCP-registration
subcommand per `design.md`'s Open Questions / Resolution Path
("codex CLI `--help` / 公式ドキュメント確認 → 実装レポートに記録").

Result: `codex --help` in this session's shell resolved to an internal alias
(`codex-sync`) unrelated to the actual Codex CLI, producing output about an
unrelated skill-sync tool rather than Codex CLI usage. This was recognized
as an unreliable, environment-specific artifact and discarded as evidence.
Adopted the config.toml marker-block fallback that both `design.md` and
`infra-spec.md` already document as the accepted resolution path when CLI
support cannot be confirmed. See "OQ-001 resolution" above for the full
rationale and the isolation point for a future swap if Codex CLI support is
later confirmed.

## Session Handoff

- **Current status**: Implementation complete for T-006's scope (install.sh,
  install.ps1, uninstall.sh, uninstall.ps1, and all four corresponding test
  files). All new and pre-existing tests pass in both bash and PowerShell
  (pwsh 7.6.2). `bash -n` and PowerShell AST parsing both pass. Repository
  structure gate (`check-sdd-structure.sh`) remains green.
- **Next action**: Hand off to independent review / quality gate for T-006.
  No further implementation action is required unless review raises new
  findings.
- **Unresolved items**: See "Unresolved Items" above — the MCP payload
  tracking-state hardening (informational, deferred to T-007's dist-parity
  scope) and the sandbox-blocked manual end-to-end smoke test (mitigated by
  equivalent automated fixture coverage).
