#!/usr/bin/env node
/**
 * discover-state-machines.mjs — Deterministic state-machine & formal-verification trigger discovery (ADR-0054 T-005).
 *
 * Scans `specs/<feature>/{requirements,design,tasks}.md` for:
 *   1. Explicit `FormalVerification: Required` task markers
 *   2. Risk tiers matching `guardrails.yaml` `formal_verification.trigger_tiers`
 *   3. State-machine / concurrency / invariant keywords and Mermaid `stateDiagram` blocks
 *
 * Source scans share the ast-grep parser with the agent lint gate.
 *
 * Usage:
 *   node discover-state-machines.mjs --feature <slug> [--root <dir>] [--format json|markdown]
 */
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import {
  assertValidFeatureName,
  createFsReadonlyIo,
  isMainModule,
  loadGuardrailsConfig,
  resolveExplicitOrAutoRoot,
} from './guardrails-lib.mjs';
import { parseTasksSummary } from './v2-readonly-core.mjs';

const SIGNAL_PATTERNS = [
  { id: 'state_diagram', re: /\bstateDiagram(?:-v2)?\b/i, label: 'Mermaid stateDiagram' },
  {
    id: 'state_transition',
    re: /(?:state\s+transition|state\s+machine|状態遷移|ライフサイクル)/i,
    label: 'State transition / lifecycle',
  },
  {
    id: 'concurrency_lock',
    re: /(?:mutex|lock\s+acqui|lease|deadlock|race\s+condition|排他制御|デッドロック|競合状態)/i,
    label: 'Concurrency / lock / lease',
  },
  {
    id: 'idempotency_invariant',
    re: /(?:idempoten|invariant|linearizab|冪等|不変条件)/i,
    label: 'Idempotency / invariant',
  },
];

export function discoverStateMachines({ feature, projectRoot = null }) {
  assertValidFeatureName(feature);
  const root = resolveExplicitOrAutoRoot(projectRoot);
  const io = createFsReadonlyIo(root);
  const config = loadGuardrailsConfig(root);
  const triggerTiers = new Set(
    (config.formal_verification?.trigger_tiers || ['high']).map((t) => String(t).toLowerCase()),
  );

  const files = ['requirements.md', 'design.md', 'tasks.md'];
  const signals = [];
  const texts = {};
  for (const f of files) {
    const rel = `specs/${feature}/${f}`;
    const raw = io.readText(rel);
    if (raw === null) continue;
    texts[f] = raw;
    for (const pat of SIGNAL_PATTERNS) {
      if (pat.re.test(raw)) {
        signals.push({ file: rel, signal: pat.id, label: pat.label });
      }
    }
  }

  const tasksRaw = texts['tasks.md'] || '';
  const tasks = parseTasksSummary(tasksRaw);
  const triggeredTasks = [];
  for (const t of tasks) {
    const explicitRequired = /^[ \t]*(?:[-*+][ \t]*)?(?:\*\*)?FormalVerification:(?:\*\*)?[ \t]*`?Required`?\b/im.test(
      t.block,
    );
    const tierTriggered = triggerTiers.has(String(t.risk || '').toLowerCase());
    if (explicitRequired || tierTriggered) {
      triggeredTasks.push({
        id: t.id,
        title: t.title,
        risk: t.risk,
        reason: explicitRequired ? 'explicit_marker' : `risk_tier:${t.risk}`,
      });
    }
  }

  const formalRequired = triggeredTasks.length > 0 || signals.some((s) => s.signal === 'state_diagram');
  const existingModels = io
    .listDir(`specs/${feature}/formal`)
    .filter((e) => e.isFile && e.name.endsWith('.tla'))
    .map((e) => `specs/${feature}/formal/${e.name}`);

  return {
    schema: 'sdd-state-machine-discovery/v1',
    feature,
    formalRequired,
    triggerTiers: [...triggerTiers],
    triggeredTasks,
    signals,
    existingModels,
    recommendedAdapter: config.formal_verification?.checker?.adapter || 'tlc',
  };
}

export function formatDiscoveryMarkdown(report) {
  const lines = [
    `## State Machine Discovery: \`${report.feature}\``,
    '',
    `- **Formal Verification Required**: ${report.formalRequired ? 'YES' : 'NO'}`,
    `- **Recommended Adapter**: \`${report.recommendedAdapter}\``,
    `- **Existing TLA+ Models**: ${report.existingModels.length > 0 ? report.existingModels.map((m) => `\`${m}\``).join(', ') : 'None'}`,
  ];
  if (report.triggeredTasks.length > 0) {
    lines.push('', '### Triggered Tasks');
    for (const t of report.triggeredTasks) {
      lines.push(`- **${t.id}** (${t.risk}, \`${t.reason}\`): ${t.title}`);
    }
  }
  if (report.signals.length > 0) {
    lines.push('', '### Detected State-Machine Signals');
    for (const s of report.signals) {
      lines.push(`- \`${s.file}\`: ${s.label} (\`${s.signal}\`)`);
    }
  }
  return `${lines.join('\n')}\n`;
}

export function validateGraph({ initial, states, transitions }) {
  if (
    !Array.isArray(states) ||
    !states.every((s) => typeof s === 'string') ||
    !states.includes(initial) ||
    !Array.isArray(transitions)
  )
    throw new Error('Expected initial, states and transitions');
  const adjacent = new Map(states.map((s) => [s, []]));
  for (const { from, to } of transitions) {
    if (!adjacent.has(from) || !adjacent.has(to)) throw new Error('Transition refers to an unknown state');
    adjacent.get(from).push(to);
  }
  const reached = new Set([initial]);
  for (const state of reached) for (const next of adjacent.get(state)) reached.add(next);
  const unreachable = states.filter((s) => !reached.has(s));
  return { ok: !unreachable.length, initial, reachable: [...reached], unreachable };
}

export async function scanBranches(root, files) {
  const { analyzeSource } = await import('../../rules/agent-lint-ast.mjs');
  const io = createFsReadonlyIo(root);
  const candidates = files.length
    ? files
    : execFileSync('git', ['ls-files', '-z', '--cached', '--others', '--exclude-standard'], {
        cwd: root,
        encoding: 'utf8',
        maxBuffer: 16 * 1024 * 1024,
      })
        .split('\0')
        .filter((f) => /\.[cm]?[jt]sx?$/.test(f));
  return candidates.flatMap((file) => {
    const source = io.readText(file);
    if (source === null) throw new Error('Cannot read source ' + file);
    return analyzeSource(source, file)
      .findings.filter((f) => f.rule === 'no-combinatorial-flags')
      .map(({ line, endLine, snippet }) => ({ file, line, endLine, snippet }));
  });
}

function parseArgs(argv) {
  const opts = { feature: null, root: null, format: 'json', scan: false, files: [], graph: null };
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === '--feature' && argv[i + 1]) opts.feature = argv[++i];
    else if (a === '--root' && argv[i + 1]) opts.root = argv[++i];
    else if (a === '--format' && argv[i + 1]) opts.format = argv[++i];
    else if (a === '--scan') opts.scan = true;
    else if (a === '--validate' && argv[i + 1]) opts.graph = argv[++i];
    else if (opts.scan && !a.startsWith('-')) opts.files.push(a);
    else throw new Error('Unexpected argument ' + a);
  }
  return opts;
}

if (isMainModule(import.meta.url, 'discover-state-machines.mjs')) {
  try {
    const opts = parseArgs(process.argv.slice(2));
    const root = resolveExplicitOrAutoRoot(opts.root || process.cwd());
    const relative = (file) => path.relative(root, path.resolve(root, file)).split(path.sep).join('/');
    let report;
    if (opts.graph) {
      const source = createFsReadonlyIo(root).readText(relative(opts.graph));
      if (source === null) throw new Error('Cannot read state graph');
      report = validateGraph(JSON.parse(source));
    } else if (opts.scan) {
      report = { signals: await scanBranches(root, opts.files.map(relative)) };
    } else {
      report = discoverStateMachines({ feature: opts.feature, projectRoot: root });
    }
    process.stdout.write(
      opts.format === 'markdown' && !opts.graph && !opts.scan
        ? formatDiscoveryMarkdown(report)
        : JSON.stringify(report, null, 2) + '\n',
    );
    process.exitCode = report.ok === false ? 1 : 0;
  } catch (err) {
    process.stderr.write('discover-state-machines: ' + err.message + '\n');
    process.exitCode = 2;
  }
}
