import { createReportLookup } from '../parsers/report-lookup.js';
import { createHash } from 'node:crypto';
import { basename } from 'node:path';
import { guardedRead } from '../path-guard.js';
import { parseActiveSpecDirectories } from '../parsers/agents-md.js';
import { getSpecStatus, getTaskState, getNextSddCommand } from '../tools/core.js';
import type { SddRoot } from '../root.js';

export const SCHEMA = 'sdd-dashboard/v1';
export interface DashboardTask {
  key: string; id: string; feature: string; title: string; body: string;
  status: string; approval: string; risk: string; release: string | null;
  source: string; failures: string[];
}
export interface DashboardData {
  project: string;
  features: { id: string; phase: string; nextCommand: string; warnings: string[] }[];
  tasks: DashboardTask[];
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
function readData(root: SddRoot): { data: DashboardData; digest: string } {
  const specs = parseActiveSpecDirectories(root);
  if (!specs.ok) throw new Error('機能一覧を読み込めません: ' + specs.error.code);
  const data: DashboardData = { project: basename(root.path), features: [], tasks: [] };
  const reports = createReportLookup();
  const hash = createHash('sha256').update(JSON.stringify(specs.data));
  for (const { feature } of specs.data) {
    const source = `specs/${feature}/tasks.md`;
    const file = guardedRead(root, source);
    const spec = getSpecStatus(root, feature);
    const next = getNextSddCommand(root, feature, reports);
    const warnings: string[] = [];
    if (!spec.ok) warnings.push('仕様の状態を確認できません: ' + spec.error.code);
    if (!next.ok) warnings.push('次の工程を判断できません: ' + next.error.code);
    data.features.push({ id: feature, phase: next.ok ? next.data.phase : 'unknown', nextCommand: next.ok ? next.data.nextCommand : '', warnings });
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
        body, source, status: task.status, approval: task.approval, risk: task.risk ?? 'unknown', release,
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
