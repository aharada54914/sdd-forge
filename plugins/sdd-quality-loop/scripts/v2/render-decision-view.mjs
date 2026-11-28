#!/usr/bin/env node
/**
 * render-decision-view.mjs — Human-focused Decision View generator (SDD Forge v2.1).
 * Zero external dependencies — Node.js >= 20 LTS built-in modules only.
 *
 * Thin CLI wrapper over `v2-readonly-core.mjs` (Single Source of Truth).
 *
 * Usage:
 *   node render-decision-view.mjs --feature <feature> [--root <dir>]
 *                                 [--format markdown|html] [--output <path>]
 */
import fs from 'node:fs';
import path from 'node:path';
import { createFsReadonlyIo, loadGuardrailsConfig, resolveExplicitOrAutoRoot, isMainModule } from './guardrails-lib.mjs';
import {
  buildDecisionViewDataCore,
  detectDomains,
  isOpenQuestionConfirmed,
  mergeOpenQuestions,
  parseAlternativesRejected,
  parseOpenQuestions,
  parseTasksSummary,
  renderDecisionViewHtml,
  renderDecisionViewMarkdown,
  splitMarkdownTableRow,
  stripFencedCodeBlocks,
} from './v2-readonly-core.mjs';

export {
  detectDomains,
  isOpenQuestionConfirmed,
  mergeOpenQuestions,
  parseAlternativesRejected,
  parseOpenQuestions,
  parseTasksSummary,
  renderDecisionViewHtml,
  renderDecisionViewMarkdown,
  splitMarkdownTableRow,
  stripFencedCodeBlocks,
};

export function buildDecisionViewData({ feature, projectRoot }) {
  const root = resolveExplicitOrAutoRoot(projectRoot);
  const io = createFsReadonlyIo(root);
  const config = loadGuardrailsConfig(root);
  return buildDecisionViewDataCore(io, { feature, config });
}

function parseArgs(argv) {
  const opts = { feature: null, root: null, format: 'markdown', output: null };
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === '--feature' && argv[i + 1]) opts.feature = argv[++i];
    else if (a === '--root' && argv[i + 1]) opts.root = argv[++i];
    else if (a === '--format' && argv[i + 1]) opts.format = argv[++i];
    else if (a === '--output' && argv[i + 1]) opts.output = argv[++i];
  }
  return opts;
}

const isMain = isMainModule(import.meta.url, 'render-decision-view.mjs');
if (isMain) {
  const argv = process.argv.slice(2);
  if (argv.includes('--warmup')) {
    process.exit(0);
  }
  const opts = parseArgs(argv);
  if (!opts.feature || (opts.format !== 'markdown' && opts.format !== 'html')) {
    process.stderr.write(
      'Usage: node render-decision-view.mjs --feature <feature> [--root <dir>] [--format markdown|html] [--output <path>]\n',
    );
    process.exit(2);
  }
  try {
    const data = buildDecisionViewData({ feature: opts.feature, projectRoot: opts.root || process.cwd() });
    const content = opts.format === 'html' ? renderDecisionViewHtml(data) : renderDecisionViewMarkdown(data);
    if (opts.output) {
      const outPath = path.resolve(opts.output);
      fs.mkdirSync(path.dirname(outPath), { recursive: true });
      fs.writeFileSync(outPath, content, 'utf8');
      process.stdout.write(`Wrote ${opts.format} decision view to ${outPath}\n`);
    } else {
      process.stdout.write(content);
    }
  } catch (err) {
    process.stderr.write(`render-decision-view error: ${err.message}\n`);
    process.exit(2);
  }
}
