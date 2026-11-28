#!/usr/bin/env node
/**
 * sync-ssot.mjs — Unified SSOT synchronization and verification CLI (ADR-0056).
 *
 * Zero-dependency Node.js 26.13+ ESM single-runtime implementation.
 *
 * Usage:
 *   node scripts/sync-ssot.mjs [--target all|contracts|manifests|agents|release|conventions|docs|diagnostics] [--check] [--json] [--root <dir>]
 *
 * Exit codes:
 *   0 — All targets up to date (--check) or synchronized successfully.
 *   1 — Drift, missing/mismatched auto-discovered package, or policy violation detected (--check).
 *   2 — Malformed SSOT JSON/YAML, broken BEGIN/END markers, or missing plugin.manifest.json.
 */
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const VALID_TARGETS = new Set([
  'all',
  'contracts',
  'manifests',
  'agents',
  'release',
  'conventions',
  'docs',
  'diagnostics',
]);

const DEFAULT_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

const CANONICAL_AGENT_BLOCKS = [
  'Role & Non-Goals',
  'Boundary & Security',
  'Inputs',
  'Process',
  'Verification Criteria',
  'Output & Failure Contract',
];

const AGENT_TOOL_PLACEHOLDERS = {
  claude: {
    READ_TOOLS: 'Read, Grep, Glob',
    SEARCH_TOOLS: 'Grep and Glob',
    SHELL_TOOL: 'Bash',
    EDIT_FORBIDDEN: 'Write, Edit, NotebookEdit',
  },
  codex: {
    READ_TOOLS: 'read-only shell commands (`cat`, `rg`, `find`, `ls`, `head`, `tail`, `stat`)',
    SEARCH_TOOLS: 'read-only `rg` / `find` commands',
    SHELL_TOOL: 'read-only shell commands',
    EDIT_FORBIDDEN: 'any file write, redirect, patch, or mutation command',
  },
  copilot: {
    READ_TOOLS: 'read and search',
    SEARCH_TOOLS: 'search',
    SHELL_TOOL: 'execute',
    EDIT_FORBIDDEN: 'any file write or repository mutation',
  },
};

function sha256(buf) {
  if (typeof crypto.hash === 'function') {
    return crypto.hash('sha256', buf, 'hex');
  }
  return crypto.createHash('sha256').update(buf).digest('hex');
}

function normLf(text) {
  return String(text).replace(/\r\n/g, '\n');
}

function formatJson(obj) {
  return `${JSON.stringify(obj, null, 2)}\n`;
}

function readJsonStrict(absPath, relPath, ctx) {
  if (!fs.existsSync(absPath)) {
    ctx.fatal(relPath, `SSOT file missing: ${relPath}`);
    return null;
  }
  try {
    return JSON.parse(fs.readFileSync(absPath, 'utf8'));
  } catch (err) {
    ctx.fatal(relPath, `Malformed JSON in ${relPath}: ${err instanceof Error ? err.message : String(err)}`);
    return null;
  }
}

/**
 * Minimal strict YAML parser for `contracts/agents/*.agent.yaml`.
 * Supports top-level/nested mappings, inline JSON values, lists (`- item`),
 * and literal block scalars (`|`).
 */
export function parseSimpleYaml(text, relPath) {
  const lines = normLf(text).split('\n');
  let i = 0;

  function parseScalar(raw) {
    const v = raw.trim();
    if (v === '' || v === 'null' || v === '~') return null;
    if (v === 'true') return true;
    if (v === 'false') return false;
    if (/^-?\d+(?:\.\d+)?$/.test(v)) return Number(v);
    if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith('[') && v.endsWith(']')) || (v.startsWith('{') && v.endsWith('}'))) {
      return JSON.parse(v);
    }
    if (v.startsWith("'") && v.endsWith("'")) {
      return v.slice(1, -1).replace(/''/g, "'");
    }
    return v;
  }

  function nextSignificant(idx) {
    while (idx < lines.length) {
      const t = lines[idx].trim();
      if (t !== '' && !t.startsWith('#')) return idx;
      idx += 1;
    }
    return lines.length;
  }

  function indentOf(line) {
    let n = 0;
    while (n < line.length && line[n] === ' ') n += 1;
    return n;
  }

  function parseBlock(minIndent) {
    const first = nextSignificant(i);
    if (first >= lines.length) return {};
    const firstIndent = indentOf(lines[first]);
    if (firstIndent < minIndent) return {};
    const trimmedFirst = lines[first].trim();
    if (trimmedFirst.startsWith('- ')) {
      const arr = [];
      i = first;
      while (i < lines.length) {
        i = nextSignificant(i);
        if (i >= lines.length) break;
        const ind = indentOf(lines[i]);
        if (ind < firstIndent) break;
        if (ind !== firstIndent || !lines[i].trim().startsWith('- ')) break;
        const rest = lines[i].trim().slice(2);
        i += 1;
        arr.push(parseScalar(rest));
      }
      return arr;
    }

    const obj = {};
    i = first;
    while (i < lines.length) {
      i = nextSignificant(i);
      if (i >= lines.length) break;
      const line = lines[i];
      const ind = indentOf(line);
      if (ind < firstIndent) break;
      if (ind !== firstIndent) {
        throw new Error(`${relPath}:${i + 1}: unexpected indentation`);
      }
      const trimmed = line.trim();
      const colonIdx = trimmed.indexOf(':');
      if (colonIdx === -1) {
        throw new Error(`${relPath}:${i + 1}: expected key: value`);
      }
      const key = trimmed.slice(0, colonIdx).trim();
      const rest = trimmed.slice(colonIdx + 1).trim();
      i += 1;
      if (rest === '|' || rest === '|-') {
        const stripTrailing = rest === '|-';
        const blockLines = [];
        let blockIndent = null;
        while (i < lines.length) {
          const rawLine = lines[i];
          if (rawLine.trim() === '') {
            blockLines.push('');
            i += 1;
            continue;
          }
          const curInd = indentOf(rawLine);
          if (blockIndent === null) {
            if (curInd <= firstIndent) break;
            blockIndent = curInd;
          }
          if (curInd < blockIndent) break;
          blockLines.push(rawLine.slice(blockIndent));
          i += 1;
        }
        while (blockLines.length > 0 && blockLines[blockLines.length - 1] === '') {
          blockLines.pop();
        }
        obj[key] = stripTrailing ? blockLines.join('\n') : `${blockLines.join('\n')}\n`;
      } else if (rest === '') {
        const peek = nextSignificant(i);
        if (peek < lines.length && indentOf(lines[peek]) > firstIndent) {
          obj[key] = parseBlock(firstIndent + 1);
        } else {
          obj[key] = null;
        }
      } else {
        obj[key] = parseScalar(rest);
      }
    }
    return obj;
  }

  return parseBlock(0);
}

/**
 * Replace content strictly between `<!-- BEGIN GENERATED:<id> -->` and `<!-- END GENERATED:<id> -->`
 * (or `# BEGIN GENERATED:<id>` / `# END GENERATED:<id>` for shell/ps1).
 * Fails closed (fatal -> exit 2) on missing, duplicated, or inverted markers.
 */
function replaceMarkerSection(content, markerId, generatedBody, relPath, ctx, style = 'html') {
  const beginTag = style === 'hash'
    ? `# BEGIN GENERATED:${markerId}`
    : `<!-- BEGIN GENERATED:${markerId} -->`;
  const endTag = style === 'hash'
    ? `# END GENERATED:${markerId}`
    : `<!-- END GENERATED:${markerId} -->`;

  const beginIdx = content.indexOf(beginTag);
  const endIdx = content.indexOf(endTag);
  if (beginIdx === -1 || endIdx === -1) {
    ctx.fatal(relPath, `Missing marker pair for '${markerId}' (${beginTag} / ${endTag}) in ${relPath}`);
    return null;
  }
  if (content.indexOf(beginTag, beginIdx + beginTag.length) !== -1 ||
      content.indexOf(endTag, endIdx + endTag.length) !== -1) {
    ctx.fatal(relPath, `Duplicate marker '${markerId}' in ${relPath}`);
    return null;
  }
  if (endIdx < beginIdx) {
    ctx.fatal(relPath, `Inverted marker pair for '${markerId}' in ${relPath}`);
    return null;
  }

  const before = content.slice(0, beginIdx + beginTag.length);
  const after = content.slice(endIdx);
  const trimmedBody = normLf(generatedBody).replace(/^\n+|\n+$/g, '');
  return `${before}\n${trimmedBody}\n${after}`;
}

function createContext(root, { check }) {
  const violations = [];
  const fatals = [];
  const updated = [];

  return {
    root,
    check,
    violations,
    fatals,
    updated,
    fatal(file, reason) {
      fatals.push({ file, reason });
    },
    drift({ file, source, target, reason }) {
      violations.push({
        file,
        source,
        command: `node scripts/sync-ssot.mjs --target ${target}`,
        reason,
      });
    },
    writeOrCheck(relPath, expectedText, { source, target, reason }) {
      const absPath = path.join(root, relPath);
      const expected = normLf(expectedText);
      const exists = fs.existsSync(absPath);
      const actual = exists ? normLf(fs.readFileSync(absPath, 'utf8')) : null;
      if (actual === expected) return false;
      if (check) {
        this.drift({
          file: relPath,
          source,
          target,
          reason: reason || (exists ? 'Derived file is out of sync with SSOT' : 'Derived file is missing'),
        });
        return true;
      }
      fs.mkdirSync(path.dirname(absPath), { recursive: true });
      fs.writeFileSync(absPath, expected, 'utf8');
      updated.push(relPath);
      return true;
    },
    updateMarkedFile(relPath, replacements, { source, target, style = 'html' }) {
      const absPath = path.join(root, relPath);
      if (!fs.existsSync(absPath)) {
        this.fatal(relPath, `Target document missing for marker sync: ${relPath}`);
        return;
      }
      const original = normLf(fs.readFileSync(absPath, 'utf8'));
      let next = original;
      for (const [markerId, body] of replacements) {
        const replaced = replaceMarkerSection(next, markerId, body, relPath, this, style);
        if (replaced === null) return;
        next = replaced;
      }
      if (next !== original) {
        if (check) {
          this.drift({
            file: relPath,
            source,
            target,
            reason: `Generated marker section(s) out of sync: ${replacements.map(([id]) => id).join(', ')}`,
          });
        } else {
          fs.writeFileSync(absPath, next, 'utf8');
          updated.push(relPath);
        }
      }
    },
  };
}

// ---------------------------------------------------------------------------
// Target 1: contracts (Phase 1)
// ---------------------------------------------------------------------------
function renderProviderTierTable(capV2, policyV1) {
  const lifecycleById = new Map((policyV1.models || []).map((m) => [m.id, m]));
  const lines = [
    '| Model ID | Canonical Tier | Default Effort | Supported Efforts | Lifecycle | Source Date |',
    '|---|---|---|---|---|---|',
  ];
  for (const m of capV2.models || []) {
    const pol = lifecycleById.get(m.name);
    const lifecycle = pol?.lifecycle || 'unlisted';
    const sourceDate = pol?.source_date ? String(pol.source_date).slice(0, 10) : '—';
    const efforts = Array.isArray(m.supported_efforts) ? m.supported_efforts.join(', ') : '—';
    lines.push(`| \`${m.name}\` | ${m.canonical_tier} | ${m.default_effort} | ${efforts} | ${lifecycle} | ${sourceDate} |`);
  }
  return lines.join('\n');
}

function renderRoleFloorsTable(capV2, policyV1) {
  const roleDefaults = capV2.role_defaults || {};
  const lines = [
    '| Policy Role | Capability Role | Env Override | Min Tier | Default Effort | Candidate Preferences |',
    '|---|---|---|---|---|---|',
  ];
  for (const [roleName, cfg] of Object.entries(policyV1.roles || {})) {
    const capRole = cfg.capability_role || '—';
    const def = capRole !== '—' ? roleDefaults[capRole] : null;
    const minTier = def?.minimum_tier || 'standard';
    const defEffort = def?.default_effort || 'medium';
    const prefs = Array.isArray(cfg.preferences) ? cfg.preferences.map((p) => `\`${p}\``).join(' → ') : '—';
    lines.push(`| \`${roleName}\` | \`${capRole}\` | \`${cfg.model_env}\` | ${minTier} | ${defEffort} | ${prefs} |`);
  }
  return lines.join('\n');
}

function renderV2GuardrailsTable() {
  return [
    '| Constraint | Rule | Enforcement (v2) |',
    '|---|---|---|',
    '| **Kill switch (`AGENT_STOP`)** | When `AGENT_STOP` exists at project root, all tool calls are denied (no bypass) | `plugins/sdd-quality-loop/scripts/v2/sdd-soft-guard.mjs` |',
    '| **Approval self-escalation** | Agents cannot add `Approval: Approved` in `tasks.md` or `Domain-Model-Status: Approved` in `domain/context-map.md` | `plugins/sdd-quality-loop/scripts/v2/sdd-soft-guard.mjs` |',
    '| **Approved spec protection** | Edits to approved `requirements.md` / `design.md` / `tasks.md` trigger configured mode (`confirm` / `warn` / `strict`); `Spec Amendments` remains editable | `sdd-soft-guard.mjs` + `check-spec-drift.mjs` |',
    '| **Concept Test receipt integrity** | Agent edits to `concept-test.decision.json` / approval receipts are denied across all file tool families | `sdd-soft-guard.mjs` + `run-sdd-gate.mjs` |',
    '| **SSOT & CI merge boundary** | Generated artifacts, `CODEOWNERS`, and test lifecycle rules are verified fail-closed in CI | `scripts/sync-ssot.mjs --check` + `.github/workflows/test.yml` |',
  ].join('\n');
}

function syncContracts(ctx) {
  const capV2 = readJsonStrict(
    path.join(ctx.root, 'contracts/agent-model-capabilities.v2.json'),
    'contracts/agent-model-capabilities.v2.json',
    ctx,
  );
  const policyV1 = readJsonStrict(
    path.join(ctx.root, 'contracts/model-policy.v1.json'),
    'contracts/model-policy.v1.json',
    ctx,
  );
  const capReg = readJsonStrict(
    path.join(ctx.root, 'contracts/capability-registry.json'),
    'contracts/capability-registry.json',
    ctx,
  );
  if (!capV2 || !policyV1 || !capReg) return;

  // Auto-discover all plugins/*/contracts/*.json that mirror root contracts/*.json
  const pluginsDir = path.join(ctx.root, 'plugins');
  if (fs.existsSync(pluginsDir)) {
    const pluginNames = fs.readdirSync(pluginsDir).sort();
    for (const pluginName of pluginNames) {
      const pluginContractsDir = path.join(pluginsDir, pluginName, 'contracts');
      if (!fs.existsSync(pluginContractsDir) || !fs.statSync(pluginContractsDir).isDirectory()) continue;
      const files = fs.readdirSync(pluginContractsDir).filter((f) => f.endsWith('.json')).sort();
      for (const file of files) {
        const rootContractAbs = path.join(ctx.root, 'contracts', file);
        if (!fs.existsSync(rootContractAbs)) continue;
        const rootBytes = fs.readFileSync(rootContractAbs, 'utf8');
        const relDerived = `plugins/${pluginName}/contracts/${file}`;
        ctx.writeOrCheck(relDerived, rootBytes, {
          source: `contracts/${file}`,
          target: 'contracts',
          reason: `SHA-256 mismatch between contracts/${file} and ${relDerived}`,
        });
      }
    }
  }

  // Sync docs/agent-capability-matrix.md marker blocks
  const matrixRel = 'docs/agent-capability-matrix.md';
  if (fs.existsSync(path.join(ctx.root, matrixRel))) {
    ctx.updateMarkedFile(
      matrixRel,
      [
        ['capability-matrix-tiers', renderProviderTierTable(capV2, policyV1)],
        ['capability-matrix-role-floors', renderRoleFloorsTable(capV2, policyV1)],
        ['capability-matrix-v2-guardrails', renderV2GuardrailsTable()],
      ],
      {
        source: 'contracts/agent-model-capabilities.v2.json, contracts/model-policy.v1.json',
        target: 'contracts',
      },
    );
  }

  // Sync delegation policy marker block
  const delegationRel = 'plugins/sdd-implementation/skills/implement-task/references/agent-delegation-policy.md';
  if (fs.existsSync(path.join(ctx.root, delegationRel))) {
    const delegationSummary = [
      '> **SSOT Notice**: Model tiers, role floors, and candidate preferences are defined solely in `contracts/agent-model-capabilities.v2.json` and `contracts/model-policy.v1.json` (rendered in `docs/agent-capability-matrix.md`). Do not hardcode legacy model IDs in prose.',
      '',
      renderRoleFloorsTable(capV2, policyV1),
    ].join('\n');
    ctx.updateMarkedFile(
      delegationRel,
      [['delegation-role-floors', delegationSummary]],
      {
        source: 'contracts/agent-model-capabilities.v2.json, contracts/model-policy.v1.json',
        target: 'contracts',
      },
    );
  }

  // Sync cross-model verification policy marker block
  const crossModelRel = 'plugins/sdd-quality-loop/references/cross-model-verification-policy.md';
  if (fs.existsSync(path.join(ctx.root, crossModelRel))) {
    const currentModels = (policyV1.models || [])
      .filter((m) => m.lifecycle === 'current')
      .map((m) => `\`${m.id}\` (${Object.keys(m.hosts || {}).join(', ') || 'unassigned'})`)
      .join(', ');
    const crossSummary = [
      '> **SSOT Notice**: Active frontier model IDs are maintained in `contracts/model-policy.v1.json` and `contracts/agent-model-capabilities.v2.json`.',
      `> Current registered frontier candidates: ${currentModels}.`,
    ].join('\n');
    ctx.updateMarkedFile(
      crossModelRel,
      [['cross-model-policy-models', crossSummary]],
      {
        source: 'contracts/model-policy.v1.json',
        target: 'contracts',
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Target 2: manifests (Phase 2)
// ---------------------------------------------------------------------------
function syncManifests(ctx) {
  const release = readJsonStrict(
    path.join(ctx.root, 'contracts/release-manifest.json'),
    'contracts/release-manifest.json',
    ctx,
  );
  if (!release) return;
  const version = release.version;
  const pluginsDir = path.join(ctx.root, 'plugins');
  if (!fs.existsSync(pluginsDir)) {
    ctx.fatal('plugins/', 'plugins/ directory missing');
    return;
  }

  const pluginDirs = fs
    .readdirSync(pluginsDir, { withFileTypes: true })
    .filter((d) => d.isDirectory() && !d.name.startsWith('.'))
    .map((d) => d.name)
    .sort();

  const manifests = [];
  for (const dirName of pluginDirs) {
    const relManifest = `plugins/${dirName}/plugin.manifest.json`;
    const absManifest = path.join(ctx.root, relManifest);
    if (!fs.existsSync(absManifest)) {
      ctx.fatal(relManifest, `Plugin directory plugins/${dirName}/ is missing required SSOT ${relManifest} (Fail-Closed)`);
      continue;
    }
    const manifest = readJsonStrict(absManifest, relManifest, ctx);
    if (!manifest) continue;
    if (manifest.name !== dirName) {
      ctx.fatal(relManifest, `Manifest name '${manifest.name}' does not match directory '${dirName}'`);
      continue;
    }
    manifests.push({ dirName, relManifest, manifest });
  }
  if (ctx.fatals.length > 0) return;

  // Deterministic order for marketplaces: use explicit order field if present, then name
  const ordered = [...manifests].sort((a, b) => {
    const oa = typeof a.manifest.order === 'number' ? a.manifest.order : 999;
    const ob = typeof b.manifest.order === 'number' ? b.manifest.order : 999;
    return oa - ob || a.dirName.localeCompare(b.dirName);
  });

  const claudeMarketplacePlugins = [];
  const codexMarketplacePlugins = [];

  for (const { dirName, relManifest, manifest } of ordered) {
    const targets = manifest.targets || {};
    const author = manifest.author || { name: release.marketplace?.owner || 'Harada' };
    const skillsDir = manifest.skillsDir || './skills/';

    // 1. .claude-plugin/plugin.json
    const claudeCfg = targets.claude || {};
    const claudeObj = {
      name: manifest.name,
      version,
      description: claudeCfg.description || manifest.description,
      author,
      skills: [skillsDir],
    };
    if (claudeCfg.hooks) claudeObj.hooks = claudeCfg.hooks;
    ctx.writeOrCheck(`plugins/${dirName}/.claude-plugin/plugin.json`, formatJson(claudeObj), {
      source: relManifest,
      target: 'manifests',
    });

    // 2. .codex-plugin/plugin.json
    const codexCfg = targets.codex || {};
    const codexObj = {
      name: manifest.name,
      version,
      description: codexCfg.description || manifest.description,
      author,
      skills: skillsDir,
    };
    if (codexCfg.hooks) codexObj.hooks = codexCfg.hooks;
    if (codexCfg.interface) codexObj.interface = codexCfg.interface;
    ctx.writeOrCheck(`plugins/${dirName}/.codex-plugin/plugin.json`, formatJson(codexObj), {
      source: relManifest,
      target: 'manifests',
    });

    // 3. .plugin/plugin.json (Copilot)
    const copilotCfg = targets.copilot || {};
    const copilotObj = {
      name: manifest.name,
      version,
      description: copilotCfg.description || manifest.description,
      author,
      skills: skillsDir.replace(/^\.\//, ''),
    };
    if (copilotCfg.agents) copilotObj.agents = copilotCfg.agents;
    if (copilotCfg.hooks) copilotObj.hooks = copilotCfg.hooks;
    ctx.writeOrCheck(`plugins/${dirName}/.plugin/plugin.json`, formatJson(copilotObj), {
      source: relManifest,
      target: 'manifests',
    });

    // 4. .antigravity-plugin/plugin.json
    const agyCfg = targets.antigravity || {};
    const agyObj = {
      name: manifest.name,
      version,
      description: agyCfg.description || manifest.description,
      author,
    };
    ctx.writeOrCheck(`plugins/${dirName}/.antigravity-plugin/plugin.json`, formatJson(agyObj), {
      source: relManifest,
      target: 'manifests',
    });

    // 5. Gemini extension manifest(s) — unified `name` = manifest.name (resolves AC-004 mismatch)
    const geminiCfg = targets.gemini || {};
    const geminiPaths = Array.isArray(geminiCfg.paths) ? geminiCfg.paths : ['gemini-extension.json'];
    const geminiObj = {
      name: manifest.name,
      version,
      description: geminiCfg.description || manifest.description,
      contextFileName: geminiCfg.contextFileName || 'GEMINI.md',
    };
    for (const relGeminiPath of geminiPaths) {
      ctx.writeOrCheck(`plugins/${dirName}/${relGeminiPath}`, formatJson(geminiObj), {
        source: relManifest,
        target: 'manifests',
      });
    }

    // Marketplace entries
    claudeMarketplacePlugins.push({
      name: manifest.name,
      source: `./plugins/${dirName}`,
      description: manifest.marketplaceDescription || manifest.description,
      version,
      author,
    });
    codexMarketplacePlugins.push({
      name: manifest.name,
      version,
      source: {
        source: 'local',
        path: `./plugins/${dirName}`,
      },
      policy: manifest.policy || {
        installation: 'AVAILABLE',
        authentication: 'ON_INSTALL',
      },
      category: manifest.category || 'Developer Tools',
    });
  }

  const claudeMarketplace = {
    $schema: 'https://anthropic.com/claude-code/marketplace.schema.json',
    name: release.marketplace?.name || 'sdd-plugins',
    description: release.marketplace?.description || 'Three-stage specification, implementation, and quality plugins.',
    owner: { name: release.marketplace?.owner || 'Harada' },
    metadata: {
      description: release.marketplace?.metadataDescription || 'Prepare approved specifications, implement one task, then independently verify it.',
    },
    plugins: claudeMarketplacePlugins,
  };
  ctx.writeOrCheck('.claude-plugin/marketplace.json', formatJson(claudeMarketplace), {
    source: 'plugins/*/plugin.manifest.json, contracts/release-manifest.json',
    target: 'manifests',
  });

  const codexMarketplace = {
    name: release.marketplace?.name || 'sdd-plugins',
    interface: {
      displayName: release.marketplace?.displayName || 'SDD Plugins',
    },
    plugins: codexMarketplacePlugins,
  };
  ctx.writeOrCheck('.agents/plugins/marketplace.json', formatJson(codexMarketplace), {
    source: 'plugins/*/plugin.manifest.json, contracts/release-manifest.json',
    target: 'manifests',
  });
}

// ---------------------------------------------------------------------------
// Target 3: agents (Phase 2 — Section 4.5)
// ---------------------------------------------------------------------------
function expandAgentPlaceholders(text, cli) {
  const map = AGENT_TOOL_PLACEHOLDERS[cli];
  return String(text).replace(/\{\{([A-Z_]+)\}\}/g, (match, key) => (
    Object.prototype.hasOwnProperty.call(map, key) ? map[key] : match
  ));
}

function renderAgentBody(spec, cli) {
  const blocks = spec.blocks || {};
  const parts = [`# ${spec.title || spec.role}`, ''];
  for (const heading of CANONICAL_AGENT_BLOCKS) {
    const content = blocks[heading];
    if (!content || typeof content !== 'string' || !content.trim()) {
      throw new Error(`Missing canonical 6-block section '${heading}'`);
    }
    parts.push(`## ${heading}`, '', expandAgentPlaceholders(content.trim(), cli), '');
  }
  return `${parts.join('\n').trimEnd()}\n`;
}

function resolveCodexModelComment(spec, capV2, policyV1) {
  const roleDefaults = capV2.role_defaults || {};
  const capRole = spec.capability_role || spec.role;
  const def = roleDefaults[capRole] || { minimum_tier: 'standard', default_effort: 'medium' };
  const policyRole = (policyV1.roles || {})[spec.policy_role || spec.role];
  const currentCodexModels = (policyV1.models || []).filter(
    (m) => m.lifecycle === 'current' && m.hosts && m.hosts['codex-cli'],
  );
  const preferred = (policyRole?.preferences || []).find((id) =>
    currentCodexModels.some((m) => m.id === id),
  );
  const modelId = preferred || currentCodexModels[0]?.id || 'gpt-6-astra';
  const effort = def.default_effort || 'medium';
  return { modelId, effort };
}

function syncAgents(ctx) {
  const capV2 = readJsonStrict(
    path.join(ctx.root, 'contracts/agent-model-capabilities.v2.json'),
    'contracts/agent-model-capabilities.v2.json',
    ctx,
  );
  const policyV1 = readJsonStrict(
    path.join(ctx.root, 'contracts/model-policy.v1.json'),
    'contracts/model-policy.v1.json',
    ctx,
  );
  if (!capV2 || !policyV1) return;

  // Enforce retirement of render-agent-frontmatter.{sh,ps1}
  for (const retired of ['render-agent-frontmatter.sh', 'render-agent-frontmatter.ps1']) {
    if (fs.existsSync(path.join(ctx.root, retired))) {
      ctx.drift({
        file: retired,
        source: 'contracts/agents/*.agent.yaml',
        target: 'agents',
        reason: `Retired legacy renderer ${retired} must be removed (replaced by scripts/sync-ssot.mjs --target agents)`,
      });
    }
  }

  const agentsDir = path.join(ctx.root, 'contracts/agents');
  if (!fs.existsSync(agentsDir)) {
    ctx.fatal('contracts/agents/', 'contracts/agents/ SSOT directory missing');
    return;
  }
  const files = fs.readdirSync(agentsDir).filter((f) => f.endsWith('.agent.yaml')).sort();
  if (files.length === 0) {
    ctx.fatal('contracts/agents/', 'No *.agent.yaml files found in contracts/agents/');
    return;
  }

  for (const file of files) {
    const relSource = `contracts/agents/${file}`;
    let spec;
    try {
      spec = parseSimpleYaml(fs.readFileSync(path.join(agentsDir, file), 'utf8'), relSource);
    } catch (err) {
      ctx.fatal(relSource, `YAML parse error in ${relSource}: ${err instanceof Error ? err.message : String(err)}`);
      continue;
    }

    const targets = spec.targets || {};
    // 1. Claude (.md)
    if (targets.claude) {
      let body;
      try {
        body = renderAgentBody(spec, 'claude');
      } catch (err) {
        ctx.fatal(relSource, `${relSource}: ${err.message}`);
        continue;
      }
      const fmLines = [
        '---',
        `name: ${spec.claude_name || spec.role}`,
        `description: ${JSON.stringify(spec.description)}`,
        `model: ${spec.claude_model || 'inherit'}`,
      ];
      if (Array.isArray(spec.claude_tools) && spec.claude_tools.length > 0) {
        fmLines.push(`tools: [${spec.claude_tools.join(', ')}]`);
      }
      if (Array.isArray(spec.claude_disallowed_tools) && spec.claude_disallowed_tools.length > 0) {
        fmLines.push(`disallowedTools: [${spec.claude_disallowed_tools.join(', ')}]`);
      }
      if (Array.isArray(spec.claude_disallowed_paths)) {
        if (spec.claude_disallowed_paths.length === 0) {
          fmLines.push('disallowedPaths: []');
        } else {
          fmLines.push('disallowedPaths:');
          for (const dp of spec.claude_disallowed_paths) {
            fmLines.push(`  - ${JSON.stringify(dp)}`);
          }
        }
      }
      fmLines.push('---', '');
      const header = `<!-- Generated by scripts/sync-ssot.mjs --target agents; edit ${relSource} -->\n\n`;
      ctx.writeOrCheck(targets.claude, `${fmLines.join('\n')}${header}${body}`, {
        source: relSource,
        target: 'agents',
      });
    }

    // 2. Codex (.toml)
    if (targets.codex) {
      let body;
      try {
        body = renderAgentBody(spec, 'codex');
      } catch (err) {
        ctx.fatal(relSource, `${relSource}: ${err.message}`);
        continue;
      }
      if (/\bRead,\s*Grep,\s*(?:or\s+)?Glob\b/.test(body)) {
        ctx.fatal(relSource, `Claude-specific tool names leaked into Codex output for ${relSource}`);
        continue;
      }
      const { modelId, effort } = resolveCodexModelComment(spec, capV2, policyV1);
      const escapedBody = body.replace(/"""/g, '\\"\\"\\"');
      const toml = [
        `# Generated by scripts/sync-ssot.mjs --target agents; edit ${relSource}`,
        `# x-sdd-model: ${modelId}`,
        `# x-sdd-effort: ${effort}`,
        `name = ${JSON.stringify(spec.role)}`,
        `description = ${JSON.stringify(spec.description)}`,
        `sandbox_mode = ${JSON.stringify(spec.sandbox_mode || 'read-only')}`,
        'developer_instructions = """',
        escapedBody.trimEnd(),
        '"""',
        '',
      ].join('\n');
      ctx.writeOrCheck(targets.codex, toml, {
        source: relSource,
        target: 'agents',
      });
    }

    // 3. Copilot (.agent.md)
    if (targets.copilot) {
      let body;
      try {
        body = renderAgentBody(spec, 'copilot');
      } catch (err) {
        ctx.fatal(relSource, `${relSource}: ${err.message}`);
        continue;
      }
      const copilotTools = Array.isArray(spec.copilot_tools) ? spec.copilot_tools : ['read', 'search', 'execute'];
      const md = [
        '---',
        `name: ${spec.role}`,
        `description: ${JSON.stringify(spec.description)}`,
        `tools: ${JSON.stringify(copilotTools)}`,
        '---',
        '',
        `<!-- Generated by scripts/sync-ssot.mjs --target agents; edit ${relSource} -->`,
        '',
        body.trimEnd(),
        '',
      ].join('\n');
      ctx.writeOrCheck(targets.copilot, md, {
        source: relSource,
        target: 'agents',
      });
    }
  }
}

// ---------------------------------------------------------------------------
// Target 4: release (Phase 3 — Unified v2.x versioning, Node 26.13+, required paths)
// ---------------------------------------------------------------------------
function syncRelease(ctx) {
  const release = readJsonStrict(
    path.join(ctx.root, 'contracts/release-manifest.json'),
    'contracts/release-manifest.json',
    ctx,
  );
  if (!release) return;
  const { version, minNodeVersion, nodeCiVersion, requiredPaths, cloudEntryFiles } = release;
  if (!/^\d+\.\d+\.\d+$/.test(String(version || '')) || !/^\d+\.\d+\.\d+$/.test(String(minNodeVersion || ''))) {
    ctx.fatal('contracts/release-manifest.json', 'Invalid semver for version or minNodeVersion');
    return;
  }
  const [minMajor, minMinor, minPatch] = minNodeVersion.split('.').map(Number);

  // 1. Auto-discover ALL mcp/*/package.json (R-02 Fail-Closed)
  const mcpDir = path.join(ctx.root, 'mcp');
  if (fs.existsSync(mcpDir)) {
    const entries = fs
      .readdirSync(mcpDir, { withFileTypes: true })
      .filter((d) => d.isDirectory() && d.name !== 'shared' && !d.name.startsWith('.'))
      .map((d) => d.name)
      .sort();
    for (const pkgDir of entries) {
      const relPkg = `mcp/${pkgDir}/package.json`;
      const absPkg = path.join(ctx.root, relPkg);
      if (!fs.existsSync(absPkg)) continue;
      const pkg = readJsonStrict(absPkg, relPkg, ctx);
      if (!pkg) continue;
      const expectedEngine = `>=${minNodeVersion}`;
      const updatedPkg = {
        ...pkg,
        version,
        engines: { ...(pkg.engines || {}), node: expectedEngine },
      };
      ctx.writeOrCheck(relPkg, formatJson(updatedPkg), {
        source: 'contracts/release-manifest.json',
        target: 'release',
        reason: `${relPkg} version (${pkg.version}) or engines.node (${pkg.engines?.node}) differs from release-manifest (${version} / ${expectedEngine})`,
      });

      // Keep package-lock.json root version aligned if present
      const relLock = `mcp/${pkgDir}/package-lock.json`;
      const absLock = path.join(ctx.root, relLock);
      if (fs.existsSync(absLock)) {
        const lockText = normLf(fs.readFileSync(absLock, 'utf8'));
        const lockObj = JSON.parse(lockText);
        if (lockObj.version !== version || (lockObj.packages && lockObj.packages[''] && lockObj.packages[''].version !== version)) {
          lockObj.version = version;
          if (lockObj.packages && lockObj.packages['']) {
            lockObj.packages[''].version = version;
            if (lockObj.packages[''].engines) {
              lockObj.packages[''].engines.node = expectedEngine;
            }
          }
          ctx.writeOrCheck(relLock, formatJson(lockObj), {
            source: 'contracts/release-manifest.json',
            target: 'release',
            reason: `${relLock} version out of sync with release-manifest (${version})`,
          });
        }
      }

      // Keep server.ts / index.ts hardcoded version literals synced
      for (const srcFile of [`mcp/${pkgDir}/src/server.ts`, `mcp/${pkgDir}/src/index.ts`]) {
        const absSrc = path.join(ctx.root, srcFile);
        if (!fs.existsSync(absSrc)) continue;
        const srcText = normLf(fs.readFileSync(absSrc, 'utf8'));
        const replaced = srcText.replace(/(\bversion:\s*")\d+\.\d+\.\d+(")/g, `$1${version}$2`);
        if (replaced !== srcText) {
          ctx.writeOrCheck(srcFile, replaced, {
            source: 'contracts/release-manifest.json',
            target: 'release',
            reason: `${srcFile} version literal out of sync with release-manifest (${version})`,
          });
        }
      }
    }
  }

  // 2. README.md current-release line
  const readmeAbs = path.join(ctx.root, 'README.md');
  if (fs.existsSync(readmeAbs)) {
    const readme = normLf(fs.readFileSync(readmeAbs, 'utf8'));
    const nextReadme = readme.replace(/^v\d+\.\d+\.\d+(\s+—)/m, `v${version}$1`);
    ctx.writeOrCheck('README.md', nextReadme, {
      source: 'contracts/release-manifest.json',
      target: 'release',
    });
  }

  // 3. install.sh generated markers (minNodeVersion + REQUIRED_PATHS)
  if (fs.existsSync(path.join(ctx.root, 'install.sh')) && Array.isArray(requiredPaths)) {
    const shNodeBlock = [
      `    local minimum_major=${minMajor} minimum_minor=${minMinor} minimum_patch=${minPatch}`,
      `    local min_node_display="${minNodeVersion}"`,
    ].join('\n');
    const shPathsBlock = [
      'REQUIRED_PATHS=(',
      ...requiredPaths.map((p) => `    "${p}"`),
      ')',
      `CLOUD_ENTRY_FILES=(${(cloudEntryFiles || []).join(' ')})`,
    ].join('\n');
    ctx.updateMarkedFile(
      'install.sh',
      [
        ['install-min-node', shNodeBlock],
        ['install-required-paths', shPathsBlock],
      ],
      { source: 'contracts/release-manifest.json', target: 'release', style: 'hash' },
    );
  }

  // 4. install.ps1 generated markers (minNodeVersion + Get-RequiredPaths)
  if (fs.existsSync(path.join(ctx.root, 'install.ps1')) && Array.isArray(requiredPaths)) {
    const psNodeBlock = `    $script:MinNodeVersion = "${minNodeVersion}"`;
    const psPathsBlock = [
      '    $required = [System.Collections.Generic.List[string]]::new()',
      '    $basePaths = @(',
      ...requiredPaths.map((p) => `        '${p}'`),
      '    )',
      '    foreach ($p in $basePaths) { $required.Add($p) }',
    ].join('\n');
    ctx.updateMarkedFile(
      'install.ps1',
      [
        ['install-min-node', psNodeBlock],
        ['install-required-paths', psPathsBlock],
      ],
      { source: 'contracts/release-manifest.json', target: 'release', style: 'hash' },
    );
  }

  // 5. Verify CI workflows pin node-version to nodeCiVersion
  const ciWorkflows = [
    '.github/workflows/test.yml',
    '.github/workflows/release.yml',
    '.github/workflows/sdd-guardrails.yml',
  ];
  for (const wfRel of ciWorkflows) {
    const wfAbs = path.join(ctx.root, wfRel);
    if (!fs.existsSync(wfAbs)) continue;
    const wfText = normLf(fs.readFileSync(wfAbs, 'utf8'));
    const nextWf = wfText.replace(/(node-version:\s*["']?)\d+(?:\.\d+)*(["']?)/g, `$1${nodeCiVersion}$2`);
    if (nextWf !== wfText) {
      ctx.writeOrCheck(wfRel, nextWf, {
        source: 'contracts/release-manifest.json',
        target: 'release',
        reason: `${wfRel} node-version does not match release-manifest nodeCiVersion (${nodeCiVersion})`,
      });
    }
  }
}

// ---------------------------------------------------------------------------
// Target 5: conventions (Phase 3 — pitfalls-catalog.json, AGENTS.md <= 100 lines, zero CLAUDE.md)
// ---------------------------------------------------------------------------
function renderPitfallsTable(entries) {
  if (entries.length === 0) {
    return '_No active pitfalls registered for this language._';
  }
  const lines = [
    '| ID | Severity | Symptom | Good Pattern | Layer | Status | Source |',
    '|---|---|---|---|---|---|---|',
  ];
  for (const p of entries) {
    const esc = (s) => String(s || '').replace(/\|/g, '\\|').replace(/\n/g, ' ');
    lines.push(
      `| \`${esc(p.id)}\` | ${esc(p.severity)} | ${esc(p.symptom)} | ${esc(p.good_pattern)} | \`${esc(p.detection_layer)}\` | \`${esc(p.status)}\` | ${esc(p.source_ticket || '—')} |`,
    );
  }
  return lines.join('\n');
}

function walkForClaudeMdAndSymlinks(dir, relBase, results) {
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    if (entry.name === '.git' || entry.name === 'node_modules' || entry.name === 'dist-test') continue;
    const rel = relBase ? `${relBase}/${entry.name}` : entry.name;
    // Historical immutable verification snapshots are excluded from active governance checks.
    if (rel === 'reports/verification' || rel.startsWith('reports/verification/')) continue;
    const full = path.join(dir, entry.name);
    if (entry.isSymbolicLink()) {
      if (entry.name === 'AGENTS.md' || entry.name === 'CLAUDE.md') {
        results.symlinks.push(rel);
      }
      continue;
    }
    if (entry.isDirectory()) {
      walkForClaudeMdAndSymlinks(full, rel, results);
    } else if (entry.name === 'CLAUDE.md') {
      results.claudeFiles.push(rel);
    }
  }
}

function syncConventions(ctx) {
  const catalog = readJsonStrict(
    path.join(ctx.root, 'contracts/pitfalls-catalog.json'),
    'contracts/pitfalls-catalog.json',
    ctx,
  );
  if (!catalog) return;
  if (!Array.isArray(catalog.pitfalls)) {
    ctx.fatal('contracts/pitfalls-catalog.json', 'pitfalls must be an array');
    return;
  }

  // 1. Generate per-language pitfall tables in docs/contributor/coding-standards/*.md
  const langFiles = [
    ['common', 'docs/contributor/coding-standards/common.md'],
    ['ts-js', 'docs/contributor/coding-standards/typescript-javascript.md'],
    ['python', 'docs/contributor/coding-standards/python.md'],
    ['powershell', 'docs/contributor/coding-standards/powershell.md'],
    ['bash', 'docs/contributor/coding-standards/bash.md'],
  ];
  for (const [lang, relFile] of langFiles) {
    const activeEntries = catalog.pitfalls
      .filter((p) => p.language === lang && p.status !== 'retired')
      .sort((a, b) => String(a.id).localeCompare(String(b.id)));
    ctx.updateMarkedFile(
      relFile,
      [[`pitfalls-${lang}`, renderPitfallsTable(activeEntries)]],
      { source: 'contracts/pitfalls-catalog.json', target: 'conventions' },
    );
  }

  // 2. Enforce AGENTS.md <= 100 lines and Active Spec Directories sync
  const agentsAbs = path.join(ctx.root, 'AGENTS.md');
  if (!fs.existsSync(agentsAbs)) {
    ctx.fatal('AGENTS.md', 'Root AGENTS.md is missing');
  } else {
    const agentsText = normLf(fs.readFileSync(agentsAbs, 'utf8'));
    const lineCount = agentsText.split('\n').length - (agentsText.endsWith('\n') ? 1 : 0);
    if (lineCount > 100) {
      ctx.drift({
        file: 'AGENTS.md',
        source: 'docs/coding-conventions.md',
        target: 'conventions',
        reason: `Root AGENTS.md has ${lineCount} lines (max allowed: 100 lines per R-04 Context Hygiene)`,
      });
    }
    if (!agentsText.includes('## Required Workflow') || !agentsText.includes('## Active Spec Directories')) {
      ctx.fatal('AGENTS.md', 'Root AGENTS.md must retain "## Required Workflow" and "## Active Spec Directories"');
    }
  }

  // 3. Enforce zero CLAUDE.md and zero AGENTS.md/CLAUDE.md symlinks across active tree
  const scan = { claudeFiles: [], symlinks: [] };
  walkForClaudeMdAndSymlinks(ctx.root, '', scan);
  for (const rel of scan.claudeFiles) {
    ctx.drift({
      file: rel,
      source: 'docs/coding-conventions.md',
      target: 'conventions',
      reason: `CLAUDE.md is forbidden under R-04 (Claude Code v2.1.277+ loads AGENTS.md natively; coexisting CLAUDE.md shadows AGENTS.md)`,
    });
  }
  for (const rel of scan.symlinks) {
    ctx.drift({
      file: rel,
      source: 'docs/coding-conventions.md',
      target: 'conventions',
      reason: `Symlinked instruction file ${rel} is forbidden under R-04 (breaks on Windows)`,
    });
  }
}

// ---------------------------------------------------------------------------
// Target 6: docs (Phase 4 — PLUGIN-CONTRACTS.md, docs/skill-reference.md)
// ---------------------------------------------------------------------------
function syncDocs(ctx) {
  const pluginsDir = path.join(ctx.root, 'plugins');
  const contractsDir = path.join(ctx.root, 'contracts');
  if (!fs.existsSync(pluginsDir) || !fs.existsSync(contractsDir)) return;

  const pluginNames = fs
    .readdirSync(pluginsDir, { withFileTypes: true })
    .filter((d) => d.isDirectory() && !d.name.startsWith('.'))
    .map((d) => d.name)
    .sort();
  const schemaFiles = fs
    .readdirSync(contractsDir)
    .filter((f) => f.endsWith('.schema.json'))
    .sort();

  const skillRows = [];
  for (const pluginName of pluginNames) {
    const skillsDir = path.join(pluginsDir, pluginName, 'skills');
    if (!fs.existsSync(skillsDir)) continue;
    const skills = fs
      .readdirSync(skillsDir, { withFileTypes: true })
      .filter((d) => d.isDirectory() && fs.existsSync(path.join(skillsDir, d.name, 'SKILL.md')))
      .map((d) => d.name)
      .sort();
    for (const s of skills) {
      skillRows.push(`| \`${s}\` | \`${pluginName}\` | \`plugins/${pluginName}/skills/${s}/SKILL.md\` |`);
    }
  }

  const pluginContractsSummary = [
    `Shipped plugins (${pluginNames.length}): ${pluginNames.map((p) => `\`${p}\``).join(', ')}`,
    '',
    `Root contract schemas (${schemaFiles.length}): auto-discovered from \`contracts/*.schema.json\`.`,
  ].join('\n');

  if (fs.existsSync(path.join(ctx.root, 'PLUGIN-CONTRACTS.md'))) {
    ctx.updateMarkedFile(
      'PLUGIN-CONTRACTS.md',
      [['plugin-contracts-summary', pluginContractsSummary]],
      { source: 'plugins/*/, contracts/*.schema.json', target: 'docs' },
    );
  }

  const skillSummary = [
    `Shipped plugins: **${pluginNames.length}** / Shipped plugin skills: **${skillRows.length}**`,
    '',
    '| Skill | Plugin | Path |',
    '|---|---|---|',
    ...skillRows,
  ].join('\n');

  if (fs.existsSync(path.join(ctx.root, 'docs/skill-reference.md'))) {
    ctx.updateMarkedFile(
      'docs/skill-reference.md',
      [['skill-reference-summary', skillSummary]],
      { source: 'plugins/*/skills/*/SKILL.md', target: 'docs' },
    );
  }
}

// ---------------------------------------------------------------------------
// Target 7: diagnostics (unifies mcp/shared/sync-diagnostics.py)
// ---------------------------------------------------------------------------
function syncDiagnostics(ctx) {
  const sharedRel = 'mcp/shared/diagnostics-core.ts';
  const sharedAbs = path.join(ctx.root, sharedRel);
  if (!fs.existsSync(sharedAbs)) return;
  const sharedText = normLf(fs.readFileSync(sharedAbs, 'utf8'));
  const expected = `// Generated by mcp/shared/sync-diagnostics.py; edit mcp/shared/diagnostics-core.ts.\n${sharedText}`;

  for (const pkg of ['ci-mcp', 'local-env-mcp']) {
    const destRel = `mcp/${pkg}/src/diagnostics-core.ts`;
    if (!fs.existsSync(path.join(ctx.root, `mcp/${pkg}/src`))) continue;
    // Only sync if mirror file is used by the server
    if (fs.existsSync(path.join(ctx.root, destRel))) {
      ctx.writeOrCheck(destRel, expected, {
        source: sharedRel,
        target: 'diagnostics',
        reason: `${destRel} drifted from ${sharedRel}`,
      });
    }
  }
}

export function runSync({ root = DEFAULT_ROOT, target = 'all', check = false } = {}) {
  if (!VALID_TARGETS.has(target)) {
    return {
      exitCode: 2,
      target,
      check,
      fatals: [{ file: '<cli>', reason: `Unknown --target '${target}'. Expected one of: ${[...VALID_TARGETS].join(', ')}` }],
      violations: [],
      updated: [],
    };
  }
  const ctx = createContext(path.resolve(root), { check });
  const runTarget = (name, fn) => {
    if (target === 'all' || target === name) fn(ctx);
  };

  runTarget('contracts', syncContracts);
  runTarget('manifests', syncManifests);
  runTarget('agents', syncAgents);
  runTarget('release', syncRelease);
  runTarget('conventions', syncConventions);
  runTarget('docs', syncDocs);
  runTarget('diagnostics', syncDiagnostics);

  const exitCode = ctx.fatals.length > 0 ? 2 : ctx.violations.length > 0 ? 1 : 0;
  return {
    exitCode,
    target,
    check,
    fatals: ctx.fatals,
    violations: ctx.violations,
    updated: ctx.updated,
  };
}

function parseCliArgs(argv) {
  const opts = { target: 'all', check: false, json: false, root: DEFAULT_ROOT };
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === '--check') opts.check = true;
    else if (a === '--json') opts.json = true;
    else if (a === '--target' && i + 1 < argv.length) opts.target = argv[++i];
    else if (a.startsWith('--target=')) opts.target = a.slice('--target='.length);
    else if (a === '--root' && i + 1 < argv.length) opts.root = argv[++i];
    else if (a.startsWith('--root=')) opts.root = a.slice('--root='.length);
    else if (a === '--help' || a === '-h') {
      process.stdout.write(
        'Usage: node scripts/sync-ssot.mjs [--target all|contracts|manifests|agents|release|conventions|docs|diagnostics] [--check] [--json] [--root <dir>]\n',
      );
      process.exit(0);
    } else {
      process.stderr.write(`Unknown argument: ${a}\n`);
      process.exit(2);
    }
  }
  return opts;
}

const isDirectMain =
  Boolean(process.argv[1]) &&
  (() => {
    try {
      return fs.realpathSync(path.resolve(process.argv[1])) === fs.realpathSync(fileURLToPath(import.meta.url));
    } catch {
      return path.resolve(process.argv[1]) === path.resolve(fileURLToPath(import.meta.url));
    }
  })();

if (isDirectMain) {
  const opts = parseCliArgs(process.argv.slice(2));
  const result = runSync(opts);
  if (opts.json) {
    process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  } else if (result.exitCode === 2) {
    for (const f of result.fatals) {
      process.stderr.write(`FATAL [ssot]: ${f.file} — ${f.reason}\n`);
    }
  } else if (result.exitCode === 1) {
    for (const v of result.violations) {
      process.stderr.write(
        `DRIFT [ssot]: ${v.file}\n  Reason: ${v.reason}\n  SSOT:   ${v.source}\n  Run:    ${v.command}\n`,
      );
    }
  } else if (!opts.check) {
    process.stdout.write(
      `sync-ssot (${result.target}): ${result.updated.length} file(s) updated.\n`,
    );
  } else {
    process.stdout.write(`sync-ssot --check (${result.target}): CLEAN\n`);
  }
  process.exit(result.exitCode);
}
