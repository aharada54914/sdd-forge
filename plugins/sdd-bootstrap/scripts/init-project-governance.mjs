#!/usr/bin/env node
/**
 * init-project-governance.mjs — User-project SSOT & Strategic DDD 3-tier initializer (ADR-0056 Phase 5).
 *
 * Detects project languages and module/monorepo layout, selects a Strategic DDD tier
 * (`lite` | `standard` | `full`), and scaffolds:
 *   - Lightweight root `AGENTS.md` (<= 100 lines, all-tier AGENTS.md / zero CLAUDE.md rule)
 *   - `sdd/glossary.json` (Ubiquitous Language SSOT)
 *   - `sdd/context-map.json` + `<context>/AGENTS.md` (Standard / Full tiers)
 *   - `sdd/pitfalls-catalog.json` (language-scoped initial AI pitfalls)
 *   - `sdd/verification-catalog.json` & `sdd/approved-test-retirements.json`
 *   - `.gitattributes` (`linguist-generated=true`)
 *
 * Usage:
 *   node plugins/sdd-bootstrap/scripts/init-project-governance.mjs --root <dir> [--tier auto|lite|standard|full] [--contexts a,b] [--json]
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

function detectProjectProfile(root) {
  const languages = new Set(['common']);
  const detectedModules = [];
  const entries = fs.existsSync(root) ? fs.readdirSync(root, { withFileTypes: true }) : [];

  const hasFile = (name) => fs.existsSync(path.join(root, name));
  if (hasFile('package.json') || hasFile('tsconfig.json')) languages.add('ts-js');
  if (hasFile('pyproject.toml') || hasFile('requirements.txt') || hasFile('setup.py')) languages.add('python');

  for (const e of entries) {
    if (e.name.startsWith('.') || e.name === 'node_modules' || e.name === 'sdd' || e.name === 'specs') continue;
    const full = path.join(root, e.name);
    if (e.isFile()) {
      if (/\.(?:ts|tsx|js|mjs|cjs)$/.test(e.name)) languages.add('ts-js');
      if (e.name.endsWith('.py')) languages.add('python');
      if (e.name.endsWith('.sh')) languages.add('bash');
      if (e.name.endsWith('.ps1')) languages.add('powershell');
    } else if (e.isDirectory()) {
      if (['packages', 'apps', 'services', 'contexts', 'modules'].includes(e.name)) {
        for (const sub of fs.readdirSync(full, { withFileTypes: true })) {
          if (sub.isDirectory() && !sub.name.startsWith('.')) {
            detectedModules.push({ name: sub.name, rootDir: `${e.name}/${sub.name}` });
          }
        }
      }
      if (e.name === 'src') {
        for (const sub of fs.readdirSync(full, { withFileTypes: true })) {
          if (sub.isDirectory() && !sub.name.startsWith('.') && !['shared', 'lib', 'utils'].includes(sub.name)) {
            detectedModules.push({ name: sub.name, rootDir: `src/${sub.name}` });
          }
        }
      }
    }
  }

  let recommendedTier = 'lite';
  const isMonorepo = hasFile('pnpm-workspace.yaml') || hasFile('turbo.json') || hasFile('nx.json') || detectedModules.length >= 4;
  if (isMonorepo) recommendedTier = 'full';
  else if (detectedModules.length >= 2) recommendedTier = 'standard';

  return {
    languages: [...languages].sort(),
    detectedModules,
    recommendedTier,
  };
}

function seedPitfallsForLanguages(languages) {
  const catalog = [
    {
      id: 'PIT-COM-001',
      language: 'common',
      severity: 'high',
      symptom: 'Duplicating constants or coexisting CLAUDE.md alongside AGENTS.md causes Context Clash',
      bad_pattern: 'Hand-copying configuration or adding CLAUDE.md next to AGENTS.md',
      good_pattern: 'Point to the single SSOT and keep instructions unified in AGENTS.md',
      detection_layer: 'ci-test',
      remediation_cmd: 'node check-architecture-fitness.mjs --root .',
      source_ticket: 'ADR-0056',
      occurrences: 2,
      status: 'enforced-by-lint',
    },
    {
      id: 'PIT-TS-001',
      language: 'ts-js',
      severity: 'high',
      symptom: 'Importing internal files of another Bounded Context bypasses its public API boundary',
      bad_pattern: "import { repo } from '../billing/internal/db.js'",
      good_pattern: "Import only from declared allowedDependencies via the target context's publicApi entrypoint",
      detection_layer: 'ast-fitness',
      remediation_cmd: 'node check-architecture-fitness.mjs --root .',
      source_ticket: 'ADR-0056',
      occurrences: 2,
      status: 'enforced-by-lint',
    },
    {
      id: 'PIT-PY-001',
      language: 'python',
      severity: 'high',
      symptom: 'Omitting encoding="utf-8" or using shell=True in subprocess introduces platform/security bugs',
      bad_pattern: 'subprocess.run(cmd, shell=True)',
      good_pattern: 'Use argv arrays with shell=False and explicit encoding="utf-8"',
      detection_layer: 'review-checklist',
      remediation_cmd: 'python3 -m unittest',
      source_ticket: 'ADR-0056',
      occurrences: 1,
      status: 'active',
    },
    {
      id: 'PIT-SH-001',
      language: 'bash',
      severity: 'high',
      symptom: 'Missing set -euo pipefail or unquoted variables silently mask failures',
      bad_pattern: 'rm -rf $dir',
      good_pattern: 'Use set -euo pipefail and quote "$dir"',
      detection_layer: 'review-checklist',
      remediation_cmd: 'bash -n script.sh',
      source_ticket: 'ADR-0056',
      occurrences: 1,
      status: 'active',
    },
    {
      id: 'PIT-PS-001',
      language: 'powershell',
      severity: 'high',
      symptom: 'Case-insensitive -eq/-match diverges from POSIX case-sensitive checks',
      bad_pattern: 'if ($a -eq $b)',
      good_pattern: 'Use -ceq / -cmatch when case sensitivity matters',
      detection_layer: 'review-checklist',
      remediation_cmd: 'pwsh -NoProfile -Command ...',
      source_ticket: 'ADR-0056',
      occurrences: 1,
      status: 'active',
    },
  ];
  const langSet = new Set(languages);
  return catalog.filter((p) => langSet.has(p.language));
}

export function initProjectGovernance({
  root,
  tier = 'auto',
  contexts = [],
} = {}) {
  const absRoot = path.resolve(root);
  fs.mkdirSync(path.join(absRoot, 'sdd'), { recursive: true });
  const profile = detectProjectProfile(absRoot);
  const resolvedTier = tier === 'auto' ? profile.recommendedTier : tier;
  if (!['lite', 'standard', 'full'].includes(resolvedTier)) {
    throw new Error(`Invalid DDD tier '${resolvedTier}'; expected lite, standard, or full`);
  }

  const created = [];
  const writeIfChanged = (rel, content) => {
    const dest = path.join(absRoot, rel);
    fs.mkdirSync(path.dirname(dest), { recursive: true });
    fs.writeFileSync(dest, content, 'utf8');
    created.push(rel);
  };

  // Build context list for standard/full
  const ctxList = contexts.length > 0
    ? contexts.map((c) => ({ name: c, rootDir: `src/${c}` }))
    : profile.detectedModules.length > 0
      ? profile.detectedModules
      : resolvedTier === 'lite'
        ? []
        : [{ name: 'core', rootDir: 'src/core' }, { name: 'app', rootDir: 'src/app' }];

  // 1. sdd/glossary.json (all tiers)
  const glossary = {
    schema: 'sdd-glossary/v1',
    dddTier: resolvedTier,
    terms: [
      {
        term: 'BoundedContext',
        definition: 'Explicit domain boundary owning its own vocabulary, data, and public API.',
        forbiddenSynonyms: ['GodModule', 'MiscHelper'],
      },
    ],
  };
  writeIfChanged('sdd/glossary.json', `${JSON.stringify(glossary, null, 2)}\n`);

  // 2. sdd/context-map.json + per-context AGENTS.md (standard / full)
  if (resolvedTier === 'standard' || resolvedTier === 'full') {
    const contextMap = {
      schema: 'sdd-context-map/v1',
      dddTier: resolvedTier,
      fitnessRules: {
        domainIsolated: true,
        contextViaApi: true,
        requireAggregateInvariants: resolvedTier === 'full',
      },
      contexts: ctxList.map((c, idx) => ({
        name: c.name,
        rootDir: c.rootDir,
        publicApi: `${c.rootDir}/index.ts`,
        domainDir: `${c.rootDir}/domain`,
        notResponsibleFor: ['Cross-context persistence internals', 'Unrelated UI presentation'],
        allowedDependencies: idx === 0 ? [] : [ctxList[0].name],
        invariants: resolvedTier === 'full' ? [`${c.name}-state-consistency`] : [],
      })),
    };
    writeIfChanged('sdd/context-map.json', `${JSON.stringify(contextMap, null, 2)}\n`);

    for (const c of contextMap.contexts) {
      const ctxAgents = [
        `# ${c.name} — Bounded Context AGENTS.md`,
        '',
        `- **Context Root**: \`${c.rootDir}\``,
        `- **Public API**: \`${c.publicApi}\` (external contexts must import only from here)`,
        `- **Allowed Dependencies**: ${c.allowedDependencies.length > 0 ? c.allowedDependencies.join(', ') : 'None (domain-isolated)'}`,
        `- **Not Responsible For**: ${c.notResponsibleFor.join('; ')}`,
        '- **Context Hygiene (R-04)**: Keep rules in `AGENTS.md`; do not create `CLAUDE.md`.',
        '',
      ].join('\n');
      writeIfChanged(`${c.rootDir}/AGENTS.md`, ctxAgents);
    }
  }

  // 3. sdd/pitfalls-catalog.json
  const pitfallsDoc = {
    schema: 'sdd-pitfalls-catalog/v1',
    languages: profile.languages,
    pitfalls: seedPitfallsForLanguages(profile.languages),
  };
  writeIfChanged('sdd/pitfalls-catalog.json', `${JSON.stringify(pitfallsDoc, null, 2)}\n`);

  // 4. sdd/verification-catalog.json & sdd/approved-test-retirements.json
  const verifCatalog = {
    schema: 'sdd-verification-catalog/v1',
    dddTier: resolvedTier,
    suites: [
      {
        path: 'tests/architecture-fitness.test.mjs',
        triggers: ['src/**', 'sdd/context-map.json', 'sdd/glossary.json'],
        invariants: resolvedTier === 'full' ? ctxList.map((c) => `${c.name}-state-consistency`) : [],
      },
    ],
  };
  writeIfChanged('sdd/verification-catalog.json', `${JSON.stringify(verifCatalog, null, 2)}\n`);

  const retirements = {
    schema: 'sdd-approved-test-retirements/v1',
    retirements: [],
  };
  writeIfChanged('sdd/approved-test-retirements.json', `${JSON.stringify(retirements, null, 2)}\n`);

  // 5. Lightweight root AGENTS.md (<= 100 lines, zero CLAUDE.md rule)
  const rootAgents = [
    '# AGENTS.md',
    '',
    `Project governance map (DDD Tier: \`${resolvedTier}\`). Standardizes on \`AGENTS.md\` across all directories (do not add \`CLAUDE.md\`).`,
    '',
    '## Required Workflow',
    '',
    '1. Define specifications under `specs/<feature>/{requirements,design,tasks}.md`.',
    '2. Obtain human approval (`Approval: Approved`) before implementation.',
    '3. Inject language pitfalls before coding and verify architecture fitness + tests before Done.',
    '4. Run the Compound step after review/bugfix to update `sdd/pitfalls-catalog.json`.',
    '',
    '## Sources of Truth',
    '',
    '- Ubiquitous language: `sdd/glossary.json`',
    ...(resolvedTier !== 'lite' ? ['- Bounded Context map: `sdd/context-map.json` (1 context = 1 subdirectory `AGENTS.md`)'] : []),
    '- Language pitfalls: `sdd/pitfalls-catalog.json`',
    '- Test impact & safe retirement: `sdd/verification-catalog.json`, `sdd/approved-test-retirements.json`',
    '',
    '## Active Spec Directories',
    '',
  ].join('\n');
  writeIfChanged('AGENTS.md', rootAgents);

  // 6. .gitattributes (linguist-generated=true)
  const gitattributes = [
    '* text=auto eol=lf',
    'dist/** linguist-generated=true',
    'sdd/generated/** linguist-generated=true',
    '',
  ].join('\n');
  writeIfChanged('.gitattributes', gitattributes);

  return {
    root: absRoot,
    dddTier: resolvedTier,
    languages: profile.languages,
    contexts: ctxList.map((c) => c.name),
    created,
  };
}

function parseCliArgs(argv) {
  const opts = { root: process.cwd(), tier: 'auto', contexts: [], json: false };
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === '--root' && i + 1 < argv.length) opts.root = argv[++i];
    else if (a === '--tier' && i + 1 < argv.length) opts.tier = argv[++i];
    else if (a === '--contexts' && i + 1 < argv.length) {
      opts.contexts = argv[++i].split(',').map((s) => s.trim()).filter(Boolean);
    } else if (a === '--json') opts.json = true;
    else if (a === '--help' || a === '-h') {
      process.stdout.write('Usage: node init-project-governance.mjs --root <dir> [--tier auto|lite|standard|full] [--contexts a,b] [--json]\n');
      process.exit(0);
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
  const result = initProjectGovernance(opts);
  if (opts.json) {
    process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  } else {
    process.stdout.write(`Initialized project governance (tier=${result.dddTier}, files=${result.created.length})\n`);
  }
}
