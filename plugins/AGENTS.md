# plugins/AGENTS.md — Plugin Ecosystem Scoped Guidelines

- Every directory under `plugins/*/` MUST declare `plugin.manifest.json` (SSOT). Never edit generated `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`, `.plugin/plugin.json`, `.antigravity-plugin/plugin.json`, `gemini-extension.json`, or `marketplace.json` directly — run `node scripts/sync-ssot.mjs --target manifests`.
- Every agent definition (`.codex/agents/*.toml`, `plugins/*/agents/*.md`, `plugins/*/copilot-agents/*.agent.md`) is generated from `contracts/agents/<role>.agent.yaml` — run `node scripts/sync-ssot.mjs --target agents`.
- Plugin-local `contracts/*.json` files mirroring root `contracts/` are synchronized via `node scripts/sync-ssot.mjs --target contracts`.
- When porting `.sh` to `.ps1`, sweep operators (`-ceq`/`-cmatch`) and cmdlets separately for case-sensitivity (WFI-012) and check symlink-safe `realpathSync` entrypoints (#869).
- Review/evidence rules (WFI-001..023) live in `docs/contributor/workflow-detail.md` and `contracts/pitfalls-catalog.json`.
