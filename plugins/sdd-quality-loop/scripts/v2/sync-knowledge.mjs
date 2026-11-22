#!/usr/bin/env node
/**
 * sync-knowledge.mjs — 2-layer Knowledge Base initializer & post-feature feedback extractor (F-6).
 *
 * Implements freee Software Factory knowledge lifecycle:
 *   - Separates "仕様 (specs: current behavior & exceptions)" vs "ルール (rules: decision criteria)"
 *   - Separates "共通 (shared)" vs "製品固有 (product)"
 *   - Maintains `sdd/knowledge/INDEX.md` under 3,000 chars and `review-perspectives.yaml`
 *   - Extracts confirmed OQ-NNN decisions, declared Spec Amendments, and Alternatives Rejected
 *     with source file:line provenance so institutional knowledge compounds after every feature.
 *
 * Zero external dependencies — Node.js >= 20 LTS built-in modules only.
 *
 * Usage:
 *   node sync-knowledge.mjs init [--root <dir>]
 *   node sync-knowledge.mjs extract --feature <slug> [--root <dir>] [--write]
 */
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import {
  assertValidFeatureName,
  createFsReadonlyIo,
  extractAmendmentEntriesWithLines,
  resolveExplicitOrAutoRoot,
} from './guardrails-lib.mjs';
import { buildDecisionViewDataCore } from './v2-readonly-core.mjs';

const INITIAL_INDEX_MD = `# Knowledge Base Index

> 2 層ナレッジ索引（3,000 字以内を維持し、詳細は配下の個別ファイルへ分割してください）。
> 仕様（現在の挙動・例外）とルール（判断・実装基準）を分け、すべての変更に理由と出典を残します。

## 仕様（Specs — 今、何がどう動いているか）
- [specs/README.md](specs/README.md) — プロダクト固有の既存挙動・例外・外部連携仕様

## ルール（Rules — 何を基準に判断・実装するか）
- [rules/README.md](rules/README.md) — 設計方針・アクセス権・セキュリティ・非機能基準

## レビュー観点（Review Perspectives）
- [review-perspectives.yaml](review-perspectives.yaml) — プロダクト特有のレビュー観点（Decision View 採否表に自動統合）
`;

const INITIAL_SPECS_README = `# Product Specifications & Exceptions

プロダクト固有の現在の挙動・ユーザー/サポートが知っている例外・他システム連携仕様を記録します。
各エントリには必ず **変更理由** と **出典（PR / ADR / specs/<feature>/requirements.md:Lxx）** を併記してください。
`;

const INITIAL_RULES_README = `# Engineering & Domain Rules

設計・実装・レビューで守るべき判断基準（アクセス権・データ整合性・エラー設計・非機能要件）を記録します。
共通ルールとプロダクト固有ルールを混在させず、根拠（ADR / WFI / 障害再発防止）を明記してください。
`;

const INITIAL_PERSPECTIVES_YAML = `# Product-specific review perspectives merged into render-decision-view.mjs (F-1).
# Dispositions: 最重要 | 採用 | 軽く確認 | 機械検証 | 低優先
# Add perspectives discovered during human review so AI & deterministic gates cover more over time.
perspectives:
  - id: P01
    area: プロダクト固有
    perspective: 既存データ・互換性への遡及影響
    question: 仕様変更前の既存レコード・設定に対して移行または後方互換が担保されているか？
    disposition: 採用
    reason: 既存利用者のデータ破損・無言の挙動変化を防ぐため。
    domains: [Software, SQL, DDD]
`;

export function initKnowledgeBase({ projectRoot = null } = {}) {
  const root = resolveExplicitOrAutoRoot(projectRoot);
  const targets = [
    { rel: 'sdd/knowledge/INDEX.md', content: INITIAL_INDEX_MD },
    { rel: 'sdd/knowledge/specs/README.md', content: INITIAL_SPECS_README },
    { rel: 'sdd/knowledge/rules/README.md', content: INITIAL_RULES_README },
    { rel: 'sdd/knowledge/review-perspectives.yaml', content: INITIAL_PERSPECTIVES_YAML },
  ];
  const created = [];
  const skipped = [];
  for (const t of targets) {
    const abs = path.join(root, ...t.rel.split('/'));
    if (fs.existsSync(abs)) {
      skipped.push(t.rel);
      continue;
    }
    fs.mkdirSync(path.dirname(abs), { recursive: true });
    fs.writeFileSync(abs, t.content, 'utf8');
    created.push(t.rel);
  }
  return { root, created, skipped };
}

export function extractKnowledgeProposal({ projectRoot = null, feature, write = false }) {
  assertValidFeatureName(feature);
  const root = resolveExplicitOrAutoRoot(projectRoot);
  const io = createFsReadonlyIo(root);
  const dv = buildDecisionViewDataCore(io, { feature });

  const confirmedOqs = dv.openQuestions.filter((q) => q.confirmed);
  const amendments = [];
  for (const fileName of ['requirements.md', 'design.md', 'tasks.md']) {
    const rel = `specs/${feature}/${fileName}`;
    const raw = io.readText(rel);
    if (!raw) continue;
    for (const entry of extractAmendmentEntriesWithLines(raw, rel)) {
      amendments.push({
        file: rel,
        line: entry.sourceLine,
        sourceRef: entry.sourceRef,
        text: entry.text,
      });
    }
  }

  const lines = [
    `# Knowledge Sync: ${feature}`,
    '',
    `- **Generated**: ${new Date().toISOString()}`,
    `- **Source Feature**: \`specs/${feature}/\``,
    `- **Domains**: ${dv.domains.join(' / ')}`,
    '',
    '## Confirmed Decisions (from Open Questions)',
    '',
  ];
  if (confirmedOqs.length === 0) {
    lines.push('- 該当なし');
  } else {
    for (const q of confirmedOqs) {
      lines.push(`- **${q.id} [${q.category}]** (\`${q.sourceRef || `specs/${feature}/requirements.md`}\`): ${q.fact}`);
      lines.push(`  - 理由: ${q.reason}`);
    }
  }

  lines.push('', '## Alternatives Rejected（不採用判断の記録）', '');
  if (dv.alternativesRejected.length === 0) {
    lines.push('- 該当なし');
  } else {
    for (const alt of dv.alternativesRejected) {
      lines.push(`- **${alt.option}** (\`${alt.sourceRef || `specs/${feature}/design.md`}\`): ${alt.reason}（再検討条件: ${alt.revisitWhen}）`);
    }
  }

  lines.push('', '## Declared Spec Amendments（仕様改訂履歴）', '');
  if (amendments.length === 0) {
    lines.push('- 該当なし');
  } else {
    for (const a of amendments) {
      lines.push(`- (\`${a.sourceRef || a.file}\`) ${a.text}`);
    }
  }

  const autoStart = '<!-- sdd-forge:knowledge-auto-start -->';
  const autoEnd = '<!-- sdd-forge:knowledge-auto-end -->';
  const markdown = `${autoStart}\n${lines.join('\n')}\n${autoEnd}\n`;
  let writtenPath = null;
  let indexUpdated = false;
  if (write) {
    const outRel = `sdd/knowledge/specs/${feature}.md`;
    const outAbs = path.join(root, ...outRel.split('/'));
    fs.mkdirSync(path.dirname(outAbs), { recursive: true });
    if (fs.existsSync(outAbs)) {
      const existing = fs.readFileSync(outAbs, 'utf8');
      const startIdx = existing.indexOf(autoStart);
      const endIdx = existing.indexOf(autoEnd);
      if (startIdx !== -1 && endIdx !== -1 && endIdx > startIdx) {
        const merged = `${existing.slice(0, startIdx)}${markdown.trimEnd()}${existing.slice(endIdx + autoEnd.length)}`;
        fs.writeFileSync(outAbs, merged.endsWith('\n') ? merged : `${merged}\n`, 'utf8');
      } else {
        const preserved = `## Manual Notes (preserved)\n\n${existing.trimEnd()}\n\n${markdown}`;
        fs.writeFileSync(outAbs, preserved, 'utf8');
      }
    } else {
      fs.writeFileSync(outAbs, markdown, 'utf8');
    }
    writtenPath = outRel;

    const indexAbs = path.join(root, 'sdd', 'knowledge', 'INDEX.md');
    if (fs.existsSync(indexAbs)) {
      const linkEntry = `- [specs/${feature}.md](specs/${feature}.md) — ${feature}（自動抽出ナレッジ）`;
      const idxContent = fs.readFileSync(indexAbs, 'utf8');
      if (!idxContent.includes(`specs/${feature}.md`)) {
        const candidate = idxContent.includes('## ルール（Rules')
          ? idxContent.replace('## ルール（Rules', `${linkEntry}\n\n## ルール（Rules`)
          : `${idxContent.trimEnd()}\n${linkEntry}\n`;
        if (candidate.length <= 3000) {
          fs.writeFileSync(indexAbs, candidate, 'utf8');
          indexUpdated = true;
        }
      }
    }
  }

  return {
    feature,
    confirmedDecisionCount: confirmedOqs.length,
    alternativesRejectedCount: dv.alternativesRejected.length,
    amendmentCount: amendments.length,
    writtenPath,
    indexUpdated,
    markdown,
  };
}

function parseArgs(argv) {
  const cmd = argv[0] || '';
  const opts = { cmd, root: null, feature: null, write: false };
  for (let i = 1; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === '--root' && argv[i + 1]) opts.root = argv[++i];
    else if (a === '--feature' && argv[i + 1]) opts.feature = argv[++i];
    else if (a === '--write') opts.write = true;
  }
  return opts;
}

const isMain =
  process.argv[1] &&
  path.basename(process.argv[1]) === 'sync-knowledge.mjs' &&
  pathToFileURL(path.resolve(process.argv[1])).href === import.meta.url;

if (isMain) {
  const opts = parseArgs(process.argv.slice(2));
  try {
    if (opts.cmd === 'init') {
      const res = initKnowledgeBase({ projectRoot: opts.root });
      process.stdout.write(`${JSON.stringify(res, null, 2)}\n`);
      process.exit(0);
    }
    if (opts.cmd === 'extract' && opts.feature) {
      const res = extractKnowledgeProposal({
        projectRoot: opts.root,
        feature: opts.feature,
        write: opts.write,
      });
      if (opts.write) {
        process.stdout.write(`${JSON.stringify({ feature: res.feature, writtenPath: res.writtenPath }, null, 2)}\n`);
      } else {
        process.stdout.write(res.markdown);
      }
      process.exit(0);
    }
    process.stderr.write(
      'Usage: node sync-knowledge.mjs <init|extract --feature <slug> [--write]> [--root <dir>]\n',
    );
    process.exit(2);
  } catch (err) {
    process.stderr.write(`sync-knowledge error: ${err.message}\n`);
    process.exit(2);
  }
}
