import { createHash } from 'node:crypto';
import { guardedRead } from '../path-guard.js';
import type { SddRoot } from '../root.js';
import { validDecisions } from './decisions.js';

export interface Decision {
  id: string; title: string; problem: string; status: 'pending' | 'decided' | 'deferred';
  basis: {path: string; sha256: string}[];
  options: {id: string; title: string; benefit: string; drawback: string; impact: string;
    diagram: {kind: 'flow' | 'screen' | 'states'; steps: string[]}}[];
  recommended: string; reason: string; selected: string | null; resolution: string | null;
}
export interface DecisionSet {
  feature: string; source: string; stale: boolean; decisions: Decision[];
}
export function readDecisions(root: SddRoot, feature: string): DecisionSet | undefined {
  const source = `specs/${feature}/decisions.json`;
  const file = guardedRead(root, source);
  if (!file.ok) {
    if (file.error.code === 'not-found') return;
    throw new Error(`${source}: ${file.error.code}`);
  }
  let value: {schema?: unknown; decisions?: unknown};
  try { value = JSON.parse(file.data.contents); }
  catch { throw new Error(`${source}: 仕様相談のJSONを読み取れません`); }
  if (!value || Object.keys(value).length !== 2 || value.schema !== 'sdd-decisions/v1' || !validDecisions(value.decisions)) throw new Error(`${source}: 仕様相談の形式が不正です`);
  const decisions = value.decisions as Decision[];
  let stale = false;
  for (const decision of decisions) for (const basis of decision.basis) {
    const input = guardedRead(root, `specs/${feature}/${basis.path}`);
    if (!input.ok || createHash('sha256').update(input.data.contents).digest('hex') !== basis.sha256) stale = true;
  }
  return {feature, source, stale, decisions};
}
