#!/usr/bin/env node
/**
 * validate-concept-test.ts — Zero-dependency erasable TypeScript 7.0 Concept Test v2 validator (ADR-0055).
 *
 * Eliminates the `pwsh` / `sh` / Python dispatch chain on Node.js 26.13+ while
 * matching `validate-concept-test.py` exit codes and verdicts:
 *   0: SKIP | CONTINUE
 *   1: BLOCK (stderr explains why)
 *   2: DEFER
 *   3: REJECT
 *
 * Usage:
 *   node plugins/sdd-domain/scripts/validate-concept-test.ts --root <dir> --feature <slug> [--require-v2]
 *   node plugins/sdd-domain/scripts/validate-concept-test.ts --probe-v1 <json|md>
 */
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const DECISIONS: Record<string, 'CONTINUE' | 'DEFER' | 'REJECT'> = {
  proceed: 'CONTINUE',
  'defer-to-domain-update': 'DEFER',
  rejected: 'REJECT',
};

const VALID_PROPOSALS = new Set([
  'FITS_EXISTING_CONCEPTS',
  'NEW_CONCEPT_CANDIDATE',
  'RESPONSIBILITY_CONFLICT',
  'REQUIRES_HUMAN_DECISION',
]);

const VALID_JUDGMENTS = new Set(['same', 'different', 'undecided']);
const DOC_ALLOWED_KEYS = new Set(['schema', 'feature', 'proposal', 'rationale', 'distinctions', 'inputs']);
const DISTINCTION_ALLOWED_KEYS = new Set(['concepts', 'judgment', 'confirmed']);
const INPUT_ALLOWED_KEYS = new Set(['path', 'sha256']);
const DECISION_ALLOWED_KEYS = new Set([
  'schema',
  'feature',
  'proposal_md_sha256',
  'proposal_json_sha256',
  'decision',
]);

const JSON_BLOCK_RE = /^```json\r?\n([\s\S]*?)^```[ \t]*\r?$/gm;
const FEATURE_DDD_RE = /^[a-z0-9][a-z0-9-]*$/;
const SHA256_RE = /^[0-9a-f]{64}$/;

function sha256Bytes(bytes: Buffer): string {
  if (typeof crypto.hash === 'function') {
    return crypto.hash('sha256', bytes, 'hex');
  }
  return crypto.createHash('sha256').update(bytes).digest('hex');
}

function v1Retired(feature: string): string {
  const prefix = `specs/${feature}/concept-test`;
  return (
    `concept-test/v1 records are no longer supported; delete any leftover ${prefix}.approval.json ` +
    'first, then recreate the proposal as concept-test/v2 by running the Concept Test again. ' +
    'In a project without domain/, where the Concept Test does not run, delete ' +
    `${prefix}.md, ${prefix}.json and ${prefix}.approval.json instead`
  );
}

function parseJsonStrictNoDuplicateKeys(raw: string): unknown {
  const parsed = JSON.parse(raw);
  const stack: Array<Set<string>> = [];
  for (const m of raw.matchAll(/("(?:[^"\\]|\\.)*")\s*(:)?|[{}]/g)) {
    const token = m[0];
    if (token === '{') stack.push(new Set());
    else if (token === '}') stack.pop();
    else if (m[2] && m[1]) {
      const top = stack[stack.length - 1];
      const key = JSON.parse(m[1]) as string;
      if (top?.has(key)) throw new Error('duplicate JSON key');
      top?.add(key);
    }
  }
  return parsed;
}

function canonicalJson(value: unknown): string {
  if (value === null || typeof value !== 'object') return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(',')}]`;
  const obj = value as Record<string, unknown>;
  const keys = Object.keys(obj).sort();
  return `{${keys.map((k) => `${JSON.stringify(k)}:${canonicalJson(obj[k])}`).join(',')}}`;
}

function readSafe(root: string, rel: string, optional = false): Buffer | null {
  const parts = rel.split('/');
  if (parts.some((p) => p === '' || p === '.' || p === '..') || rel.includes('\\')) {
    throw new Error('unsafe conditional input path');
  }
  let current = root;
  for (let i = 0; i < parts.length; i += 1) {
    const part = parts[i]!;
    if (fs.existsSync(current)) {
      const entries = fs.readdirSync(current);
      if (!entries.includes(part)) {
        if (optional) return null;
        throw new Error(`missing Concept Test input: ${rel}`);
      }
    }
    current = path.join(current, part);
    let stat: fs.Stats;
    try {
      stat = fs.lstatSync(current);
    } catch {
      if (optional) return null;
      throw new Error(`missing Concept Test input: ${rel}`);
    }
    if (stat.isSymbolicLink() || (i < parts.length - 1 && !stat.isDirectory())) {
      throw new Error('unsafe conditional input path');
    }
    if (i === parts.length - 1 && !stat.isFile()) {
      throw new Error('non-regular conditional input');
    }
  }
  return fs.readFileSync(current);
}

function markdownSchema(raw: Buffer): string | null {
  try {
    const text = new TextDecoder('utf-8', { fatal: true }).decode(raw);
    const matches = [...text.matchAll(JSON_BLOCK_RE)];
    if (matches.length !== 1 || !matches[0]?.[1]) return null;
    const doc = parseJsonStrictNoDuplicateKeys(matches[0][1]);
    return doc && typeof doc === 'object' && !Array.isArray(doc) && typeof (doc as Record<string, unknown>).schema === 'string'
      ? ((doc as Record<string, unknown>).schema as string)
      : null;
  } catch {
    return null;
  }
}

export function validateConceptTest(
  rootDir: string,
  feature: string,
  requireV2 = false,
): 'SKIP' | 'CONTINUE' | 'DEFER' | 'REJECT' {
  const root = fs.realpathSync(path.resolve(rootDir));
  if (!feature || feature === '.' || feature === '..' || /[\\/\0]/.test(feature)) {
    throw new Error('invalid feature');
  }
  const domainDir = path.join(root, 'domain');
  if (fs.existsSync(domainDir)) {
    const st = fs.lstatSync(domainDir);
    if (st.isSymbolicLink() || !st.isDirectory()) throw new Error('unsafe domain directory');
  } else if (!requireV2) {
    return 'SKIP';
  }
  if (!FEATURE_DDD_RE.test(feature)) {
    throw new Error(
      `concept-test: BLOCK: DDD features need lowercase kebab-case names ([a-z0-9][a-z0-9-]*); rename specs/${feature}/ to use the DDD lane`,
    );
  }

  const prefix = `specs/${feature}/concept-test`;
  const jsonBytes = readSafe(root, `${prefix}.json`, true);
  if (jsonBytes === null) {
    const mdBytes = readSafe(root, `${prefix}.md`, true);
    if (mdBytes !== null && markdownSchema(mdBytes) === 'concept-test/v1') {
      throw new Error(v1Retired(feature));
    }
    throw new Error(`missing Concept Test input: ${prefix}.json`);
  }

  const rawDoc = parseJsonStrictNoDuplicateKeys(new TextDecoder('utf-8', { fatal: true }).decode(jsonBytes));
  if (!rawDoc || typeof rawDoc !== 'object' || Array.isArray(rawDoc)) {
    throw new Error('invalid Concept Test document');
  }
  const doc = rawDoc as Record<string, unknown>;
  if (doc.schema === 'concept-test/v1') {
    throw new Error(v1Retired(feature));
  }
  if (doc.schema !== 'concept-test/v2') {
    throw new Error('unsupported Concept Test version for this operation');
  }
  if (doc.feature !== feature) {
    throw new Error('wrong Concept Test feature');
  }
  if (typeof doc.proposal !== 'string' || !VALID_PROPOSALS.has(doc.proposal)) {
    throw new Error('invalid Concept Test document');
  }
  if (typeof doc.rationale !== 'string' || doc.rationale.length === 0) {
    throw new Error('invalid Concept Test document');
  }
  for (const key of Object.keys(doc)) {
    if (!DOC_ALLOWED_KEYS.has(key)) {
      throw new Error('invalid Concept Test document');
    }
  }

  const mdBytes = readSafe(root, `${prefix}.md`);
  if (!mdBytes) throw new Error(`missing Concept Test input: ${prefix}.md`);
  const mdText = new TextDecoder('utf-8', { fatal: true }).decode(mdBytes);
  const blocks = [...mdText.matchAll(JSON_BLOCK_RE)];
  if (
    blocks.length !== 1 ||
    !blocks[0]?.[1] ||
    canonicalJson(parseJsonStrictNoDuplicateKeys(blocks[0][1])) !== canonicalJson(doc)
  ) {
    throw new Error('Markdown and JSON evidence differ');
  }

  const inputs = Array.isArray(doc.inputs) ? doc.inputs : null;
  if (!inputs || inputs.length < 2) throw new Error('invalid Concept Test document');
  const pinnedPaths = new Set<string>();
  for (const entry of inputs) {
    if (!entry || typeof entry !== 'object' || Array.isArray(entry)) {
      throw new Error('invalid Concept Test document');
    }
    const item = entry as Record<string, unknown>;
    for (const k of Object.keys(item)) {
      if (!INPUT_ALLOWED_KEYS.has(k)) throw new Error('invalid Concept Test document');
    }
    const rel = typeof item.path === 'string' ? item.path : '';
    const expectedHash = typeof item.sha256 === 'string' ? item.sha256 : '';
    if (!rel || !SHA256_RE.test(expectedHash)) throw new Error('invalid Concept Test document');
    if (pinnedPaths.has(rel) || rel.startsWith(`${prefix}.`)) {
      throw new Error('duplicate or circular Concept Test input');
    }
    if (rel.startsWith('/') || rel.includes('\\') || rel.includes(':') || rel.split('/').some((p) => p === '' || p === '.' || p === '..')) {
      throw new Error('unsafe Concept Test input');
    }
    if (!rel.startsWith('domain/') && rel !== `specs/${feature}/concept-test-seed.md`) {
      throw new Error('Concept Test inputs must be domain evidence or the feature seed');
    }
    pinnedPaths.add(rel);
    const bytes = readSafe(root, rel);
    if (!bytes || sha256Bytes(bytes) !== expectedHash) {
      throw new Error('Concept Test input changed');
    }
  }

  if (!pinnedPaths.has('domain/domain-contract.json') || !pinnedPaths.has(`specs/${feature}/concept-test-seed.md`)) {
    throw new Error('domain contract and feature seed must be pinned');
  }

  const domainBytes = readSafe(root, 'domain/domain-contract.json');
  if (!domainBytes) throw new Error('missing domain/domain-contract.json');
  const domain = parseJsonStrictNoDuplicateKeys(new TextDecoder('utf-8', { fatal: true }).decode(domainBytes)) as Record<
    string,
    unknown
  >;
  const meta = domain.meta as Record<string, unknown> | undefined;
  if (domain.schema !== 'domain-contract/v2' || meta?.status !== 'Approved') {
    throw new Error('domain model must be approved');
  }
  const contextMapBytes = readSafe(root, 'domain/context-map.md', true);
  if (
    !pinnedPaths.has('domain/context-map.md') ||
    !contextMapBytes ||
    !/^Domain-Model-Status: Approved[ \t]*\r?$/m.test(contextMapBytes.toString('utf8'))
  ) {
    throw new Error('approved context map must be pinned');
  }
  const generatedFrom = Array.isArray(meta?.generated_from) ? (meta.generated_from as string[]) : [];
  for (const genPath of generatedFrom) {
    if (!pinnedPaths.has(genPath)) throw new Error('domain source inputs must be pinned');
  }

  const concepts = Array.isArray(domain.concepts) ? (domain.concepts as Array<Record<string, unknown>>) : [];
  const knownConcepts = new Set(concepts.map((c) => String(c.id || '')));
  const distinctions = Array.isArray(doc.distinctions) ? (doc.distinctions as Array<Record<string, unknown>>) : null;
  if (!distinctions || distinctions.length === 0) {
    throw new Error('invalid Concept Test document');
  }
  for (const d of distinctions) {
    if (!d || typeof d !== 'object' || Array.isArray(d)) {
      throw new Error('invalid Concept Test document');
    }
    for (const k of Object.keys(d)) {
      if (!DISTINCTION_ALLOWED_KEYS.has(k)) throw new Error('invalid Concept Test document');
    }
    if (d.confirmed !== true || typeof d.judgment !== 'string' || !VALID_JUDGMENTS.has(d.judgment)) {
      throw new Error('invalid Concept Test document');
    }
    const ids = Array.isArray(d.concepts) ? (d.concepts as unknown[]) : null;
    if (!ids || ids.length === 0 || ids.some((x) => typeof x !== 'string' || x.length === 0)) {
      throw new Error('invalid Concept Test document');
    }
    for (const cid of ids as string[]) {
      if (!knownConcepts.has(cid)) throw new Error('unknown concept in distinction');
    }
  }

  const approvalBytes = readSafe(root, `${prefix}.approval.json`, true);
  const decisionBytes = readSafe(root, `${prefix}.decision.json`, true);
  if (approvalBytes !== null) {
    throw new Error(`leftover ${prefix}.approval.json from a retired v1 record: delete it, then validate again`);
  }
  const fits = doc.proposal === 'FITS_EXISTING_CONCEPTS';
  if (fits) {
    if (decisionBytes !== null || 'decision' in doc) {
      throw new Error('incompatible Concept Test decision records');
    }
    return 'CONTINUE';
  }
  if (decisionBytes === null) {
    throw new Error('run --confirm in a separate human-operated terminal');
  }
  const decision = parseJsonStrictNoDuplicateKeys(
    new TextDecoder('utf-8', { fatal: true }).decode(decisionBytes),
  ) as Record<string, unknown>;
  if (!decision || typeof decision !== 'object' || Array.isArray(decision)) {
    throw new Error('invalid Concept Test document');
  }
  for (const k of Object.keys(decision)) {
    if (!DECISION_ALLOWED_KEYS.has(k)) throw new Error('invalid Concept Test document');
  }
  if (decision.schema !== 'concept-test-decision/v1') {
    throw new Error('invalid Concept Test document');
  }
  if (decision.feature !== feature) {
    throw new Error('wrong local decision feature');
  }
  if (
    decision.proposal_md_sha256 !== sha256Bytes(mdBytes) ||
    decision.proposal_json_sha256 !== sha256Bytes(jsonBytes)
  ) {
    throw new Error('local decision refers to an earlier proposal');
  }
  const verdict = DECISIONS[String(decision.decision || '')];
  if (!verdict) throw new Error('invalid Concept Test decision');
  return verdict;
}

function main(): number {
  const argv = process.argv.slice(2);
  if (argv[0] === '--probe-v1' && (argv[1] === 'json' || argv[1] === 'md')) {
    const raw = fs.readFileSync(0);
    let isV1 = false;
    try {
      if (argv[1] === 'md') {
        isV1 = markdownSchema(raw) === 'concept-test/v1';
      } else {
        const parsed = parseJsonStrictNoDuplicateKeys(new TextDecoder('utf-8', { fatal: true }).decode(raw));
        isV1 = Boolean(parsed && typeof parsed === 'object' && (parsed as Record<string, unknown>).schema === 'concept-test/v1');
      }
    } catch {
      isV1 = false;
    }
    process.stdout.write(`${isV1 ? 'V1' : 'OTHER'}\n`);
    return 0;
  }

  let root = '';
  let feature = '';
  let requireV2 = false;
  let confirm = false;
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === '--root' && i + 1 < argv.length) root = argv[++i] ?? '';
    else if (a === '--feature' && i + 1 < argv.length) feature = argv[++i] ?? '';
    else if (a === '--require-v2') requireV2 = true;
    else if (a === '--confirm') confirm = true;
    else {
      process.stderr.write(`concept-test: BLOCK: unrecognized arguments: ${a}\n`);
      return 2;
    }
  }
  if (!root || !feature) {
    process.stderr.write('Usage: node validate-concept-test.ts --root <dir> --feature <slug> [--require-v2]\n');
    return 1;
  }
  if (confirm) {
    if (!process.stdin.isTTY || !process.stdout.isTTY) {
      process.stderr.write('concept-test: BLOCK: confirmation requires an interactive human-operated terminal\n');
      return 1;
    }
  }
  try {
    const outcome = validateConceptTest(root, feature, requireV2);
    process.stdout.write(`${outcome}\n`);
    return outcome === 'SKIP' || outcome === 'CONTINUE' ? 0 : outcome === 'DEFER' ? 2 : 3;
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    process.stderr.write(msg.startsWith('concept-test: BLOCK:') ? `${msg}\n` : `concept-test: BLOCK: ${msg}\n`);
    return 1;
  }
}

const isDirectMain =
  Boolean(process.argv[1]) &&
  (() => {
    try {
      return fs.realpathSync(path.resolve(process.argv[1] || '')) === fs.realpathSync(fileURLToPath(import.meta.url));
    } catch {
      return path.resolve(process.argv[1] || '') === path.resolve(fileURLToPath(import.meta.url));
    }
  })();

if (isDirectMain) {
  process.exit(main());
}
