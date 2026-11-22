import { createReportLookup } from '../parsers/report-lookup.js';
import { createHash } from 'node:crypto';
import { basename } from 'node:path';
import { guardedRead } from '../path-guard.js';
import { parseActiveSpecDirectories } from '../parsers/agents-md.js';
import { getSpecStatus, getTaskState, getNextSddCommand } from '../tools/core.js';
import type { SddRoot } from '../root.js';
import { readDecisions, type DecisionSet } from './decision-reader.js';

export const SCHEMA = 'sdd-dashboard/v1';
export interface DashboardTask {
  key: string; id: string; feature: string; title: string; body: string;
  status: string; approval: string; risk: string; release: string | null;
  source: string; failures: string[];
}
export interface DashboardData {
  project: string;
  features: { id: string; displayName?: string; phase: string; nextCommand: string; warnings: string[] }[];
  tasks: DashboardTask[];
  decisionSets?: DecisionSet[];
}
export interface Snapshot {
  schema: string; revision: string; checkedAt: string | null; changedAt: string | null;
  lastSuccessAt: string | null; attemptedAt: string; error: string | null;
  data: DashboardData | null;
}
export function selectPresentation(parentService: string): 'sites' | 'artifacts' {
  if (parentService === 'chatgpt') return 'sites';
  if (parentService === 'claude') return 'artifacts';
  throw new Error('親サービスを chatgpt または claude として指定してください。子のモデルからは選択しません。');
}
const TASK_HEADER_FIELD = /^[A-Z][A-Za-z0-9-]*(?: [A-Z][A-Za-z0-9-]*)*:(?:[ \t]|$)/;
const CANONICAL_STANDARD_RISK = /^Risk:[ \t]+standard[ \t]*$/;
/**
 * Dashboard-only display helper for v2 `Risk: standard`.
 * Scans only the task's leading metadata header (ignoring subsections, fences,
 * prose, and trailing non-task sections) and requires exact lowercase `standard`
 * so legacy parser/gate semantics remain unchanged.
 */
function readCanonicalStandardRisk(body: string): 'standard' | null {
  let canonicalRiskLine: string | undefined;
  for (const rawLine of body.split('\n')) {
    const line = rawLine.endsWith('\r') ? rawLine.slice(0, -1) : rawLine;
    if (/^[ \t]*$/.test(line)) continue;
    if (!TASK_HEADER_FIELD.test(line)) break;
    if (line.startsWith('Risk:')) canonicalRiskLine = line;
  }
  return canonicalRiskLine !== undefined && CANONICAL_STANDARD_RISK.test(canonicalRiskLine) ? 'standard' : null;
}
function readData(root: SddRoot): { data: DashboardData; digest: string } {
  const labelsFile = guardedRead(root, 'dashboard-labels.json');
  let labels: Record<string, string> = {};
  if (labelsFile.ok) {
    const value: unknown = JSON.parse(labelsFile.data.contents);
    if (!value || typeof value !== 'object') throw new Error('表示名設定の形式が不正です');
    const config = value as {schema?: unknown; features?: unknown};
    if (config.schema !== 'sdd-dashboard-labels/v1' || !config.features || typeof config.features !== 'object' || Array.isArray(config.features) || Object.keys(value).some(k => !['schema','features'].includes(k))) throw new Error('表示名設定の形式が不正です');
    for (const [key, label] of Object.entries(config.features)) {
      if (!/^[a-z0-9][a-z0-9-]*$/.test(key) || typeof label !== 'string' || !label.trim() || label.length > 200) throw new Error('表示名設定の値が不正です');
    }
    labels = config.features as Record<string,string>;
  } else if (labelsFile.error.code !== 'not-found') throw new Error('表示名設定を読めません: ' + labelsFile.error.code);
  const specs = parseActiveSpecDirectories(root);
  if (!specs.ok) throw new Error('機能一覧を読み込めません: ' + specs.error.code);
  const data: DashboardData = { project: basename(root.path), features: [], tasks: [] };
  const reports = createReportLookup();
  const hash = createHash('sha256').update(JSON.stringify(specs.data));
  for (const { feature } of specs.data) {
    const decisions = readDecisions(root, feature);
    if (decisions) (data.decisionSets ??= []).push(decisions);
    const source = `specs/${feature}/tasks.md`;
    const file = guardedRead(root, source);
    const spec = getSpecStatus(root, feature);
    const next = getNextSddCommand(root, feature, reports);
    const warnings: string[] = [];
    if (!spec.ok) warnings.push('仕様の状態を確認できません: ' + spec.error.code);
    if (!next.ok) warnings.push('次の工程を判断できません: ' + next.error.code);
    else if (next.data.phase === 'spec-check') warnings.push(next.data.rationale);
    data.features.push({ id: feature, ...(Object.hasOwn(labels,feature) ? {displayName:labels[feature]!} : {}), phase: next.ok ? next.data.phase : 'unknown', nextCommand: next.ok ? next.data.nextCommand : '', warnings });
    hash.update(JSON.stringify(spec));
    if (!file.ok) {
      if (file.error.code !== 'not-found') throw new Error(`${source}: ${file.error.code}`);
      warnings.push('タスク未作成');
      hash.update(source + ':missing');
      continue;
    }
    hash.update(source).update(file.data.contents);
    const state = getTaskState(root, feature, reports);
    if (!state.ok) throw new Error(`${source}: ${state.error.code}`);
    const sections = [...file.data.contents.matchAll(/^##\s+(T-\d+)\b([^\n]*)\n([\s\S]*?)(?=^##\s+T-\d+\b|(?![\s\S]))/gm)];
    if (!sections.length || !state.data.tasks.length) throw new Error(`${source}: タスク形式を読み取れません`);
    for (const task of state.data.tasks) {
      const section = sections.find(s => s[1] === task.id);
      if (!section) throw new Error(`${source}: タスク本文が不整合です`);
      const body = section[3] ?? '';
      const release = body.match(/^Release:[ \t]*(\S[^\r\n]*)\r?$/m)?.[1]?.trim() || null;
      data.tasks.push({ key: `${feature}/${task.id}`, feature, id: task.id,
        title: (section[2] ?? '').replace(/^\s*[:—-]\s*/, '').trim() || task.id,
        body, source, status: task.status, approval: task.approval, risk: task.risk ?? readCanonicalStandardRisk(body) ?? 'unknown', release,
        failures: state.data.failures.filter(f => !f.taskId || f.taskId === task.id).map(f => f.message) });
    }
  }
  hash.update(JSON.stringify(data));
  return { data, digest: hash.digest('hex') };
}
/** Retains last-good data; a read failure must never advance source freshness. */
export class DashboardReader {
  private previous: Snapshot | undefined;
  constructor(private readonly root: SddRoot, private readonly read = readData) {}
  sample(now = new Date()): Snapshot {
    const attemptedAt = now.toISOString();
    try {
      let before = this.read(this.root);
      let stable: ReturnType<typeof readData> | undefined;
      for (let retry = 0; retry < 2; retry++) {
        const after = this.read(this.root);
        if (before.digest === after.digest) { stable = after; break; }
        before = after;
      }
      if (!stable) throw new Error('更新途中のため整合性を確認できません');
      this.previous = { schema: SCHEMA, revision: stable.digest, checkedAt: attemptedAt,
        changedAt: this.previous?.revision === stable.digest ? this.previous.changedAt : attemptedAt,
        lastSuccessAt: attemptedAt, attemptedAt, error: null, data: stable.data };
    } catch (error) {
      this.previous = { schema: SCHEMA, revision: '', checkedAt: null, changedAt: null,
        lastSuccessAt: null, data: null, ...this.previous, attemptedAt,
        error: error instanceof Error ? error.message : '取得に失敗しました' };
    }
    return this.previous;
  }
}
