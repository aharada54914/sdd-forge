#!/usr/bin/env node
/**
 * render-decision-view.mjs — Human-focused Decision View generator (SDD Forge v2.1).
 * Zero external dependencies — Node.js >= 20 LTS built-in modules only.
 *
 * Thin CLI wrapper over `v2-readonly-core.mjs` (Single Source of Truth).
 *
 * Usage:
 *   node render-decision-view.mjs --feature <feature> [--root <dir>]
 *                                 [--format markdown|html|review-hash] [--output <path>]
 *                                 [--require-traceability]
 */
import fs from 'node:fs';
import path from 'node:path';
import { createFsReadonlyIo, loadGuardrailsConfig, resolveExplicitOrAutoRoot, isMainModule } from './guardrails-lib.mjs';
import {
  analyzeTraceabilityCore,
  buildDecisionViewDataCore,
  computeSpecReviewInputsHash,
  detectDomains,
  evaluateSpecCheckReport,
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
  computeSpecReviewInputsHash,
  detectDomains,
  evaluateSpecCheckReport,
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

export function computeReviewInputsHash({ feature, projectRoot }) {
  const root = resolveExplicitOrAutoRoot(projectRoot);
  const io = createFsReadonlyIo(root);
  return computeSpecReviewInputsHash(io, { feature });
}

export function assertDecisionViewTraceability({ feature, projectRoot }) {
  const root = resolveExplicitOrAutoRoot(projectRoot);
  const io = createFsReadonlyIo(root);
  const trace = analyzeTraceabilityCore(io, { feature, checkCodeAndTests: false });
  const hasCycle = (trace.executionPlan?.cyclicTasks?.length || 0) > 0;
  const hasInvalidBlockers = (trace.executionPlan?.invalidBlockerTasks?.length || 0) > 0;
  if (
    !trace.complete ||
    trace.requirements.length === 0 ||
    trace.acceptanceCriteria.length === 0 ||
    trace.tasks.length === 0 ||
    hasCycle ||
    hasInvalidBlockers
  ) {
    throw new Error(
      `Traceability requirement not met for '${feature}' ` +
        `(REQ=${trace.requirements.length}, AC=${trace.acceptanceCriteria.length}, ` +
        `Tasks=${trace.tasks.length}, complete=${trace.complete}, ` +
        `cycles=${trace.executionPlan?.cyclicTasks?.length || 0}, ` +
        `invalidBlockers=${trace.executionPlan?.invalidBlockerTasks?.length || 0}).`,
    );
  }
  return trace;
}

function parseArgs(argv) {
  const opts = { feature: null, root: null, format: 'markdown', output: null, requireTraceability: false };
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === '--feature' && argv[i + 1]) opts.feature = argv[++i];
    else if (a === '--root' && argv[i + 1]) opts.root = argv[++i];
    else if (a === '--format' && argv[i + 1]) opts.format = argv[++i];
    else if (a === '--output' && argv[i + 1]) opts.output = argv[++i];
    else if (a === '--require-traceability') opts.requireTraceability = true;
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
  if (!opts.feature || (opts.format !== 'markdown' && opts.format !== 'html' && opts.format !== 'review-hash')) {
    process.stderr.write(
      'Usage: node render-decision-view.mjs --feature <feature> [--root <dir>] [--format markdown|html|review-hash] [--output <path>] [--require-traceability]\n',
    );
    process.exit(2);
  }
  try {
    const projectRoot = opts.root || process.cwd();
    if (opts.format === 'review-hash') {
      const digest = computeReviewInputsHash({ feature: opts.feature, projectRoot });
      process.stdout.write(`${digest}\n`);
    } else {
      if (opts.requireTraceability) {
        assertDecisionViewTraceability({ feature: opts.feature, projectRoot });
      }
      const data = buildDecisionViewData({ feature: opts.feature, projectRoot });
      const content = opts.format === 'html' ? renderDecisionViewHtml(data) : renderDecisionViewMarkdown(data);
      if (opts.output) {
        const outPath = path.resolve(opts.output);
        fs.mkdirSync(path.dirname(outPath), { recursive: true });
        fs.writeFileSync(outPath, content, 'utf8');
        process.stdout.write(`Wrote ${opts.format} decision view to ${outPath}\n`);
      } else {
        process.stdout.write(content);
      }
    }
  } catch (err) {
    process.stderr.write(`render-decision-view error: ${err.message}\n`);
    process.exit(2);
  }
}
