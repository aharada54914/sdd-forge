#!/usr/bin/env node
/**
 * check-contract.ts — Zero-dependency erasable TypeScript 7.0 port of `check-contract.py` (ADR-0055).
 *
 * Delegates evidence path safety validation directly to `./validate-path.ts`
 * without Python runtime dependencies while preserving full pass 1-7 parity
 * and byte-identical diagnostic strings.
 *
 * Usage:
 *   node plugins/sdd-quality-loop/scripts/check-contract.ts <contract-path> [repo-root]
 */
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { validateEvidencePath } from './validate-path.ts';

export const BASELINE_IDS: ReadonlySet<string> = new Set([
  'lint',
  'typecheck',
  'unit-tests',
  'build',
  'placeholder-scan',
  'task-state-check',
]);

export const RISK_TIERS: Record<string, ReadonlySet<string>> = {
  low: new Set(['lint', 'typecheck', 'build', 'placeholder-scan', 'task-state-check']),
  medium: new Set([
    'lint',
    'typecheck',
    'build',
    'placeholder-scan',
    'task-state-check',
    'unit-tests',
    'acceptance-tests',
    'regression',
  ]),
  high: new Set([
    'lint',
    'typecheck',
    'build',
    'placeholder-scan',
    'task-state-check',
    'unit-tests',
    'acceptance-tests',
    'regression',
    'requirement-traceability',
    'check-component-coverage',
  ]),
  critical: new Set([
    'lint',
    'typecheck',
    'build',
    'placeholder-scan',
    'task-state-check',
    'unit-tests',
    'acceptance-tests',
    'regression',
    'requirement-traceability',
    'check-component-coverage',
  ]),
};

export const COMPILE_CHECKS: ReadonlySet<string> = new Set(['lint', 'typecheck', 'build']);
export const KNOWN_STACKS: ReadonlySet<string> = new Set(['code', 'shell', 'docs', 'spec']);
export const NONCODE_STACKS: ReadonlySet<string> = new Set(['shell', 'docs', 'spec']);
export const TDD_TEST_IDS: ReadonlySet<string> = new Set(['unit-tests', 'acceptance-tests']);
export const PRODUCER_DIGEST_CHECK_ID = 'check-component-coverage';
export const PRODUCER_DIGEST_SCRIPT_NAME = 'check-component-coverage.py';
export const CAPABILITY_STATE_GATED_IDS: ReadonlySet<string> = new Set(['check-component-coverage']);

const ISO_UTC_RE = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z$/;
const HEX_40_OR_64_RE = /^(?:[0-9a-f]{40}|[0-9a-f]{64})$/;

export interface ContractValidationResult {
  taskId: string;
  passed: boolean;
  failures: string[];
}

function sha256Buffer(buf: Buffer): string {
  if (typeof crypto.hash === 'function') {
    return crypto.hash('sha256', buf, 'hex');
  }
  return crypto.createHash('sha256').update(buf).digest('hex');
}

function strField(obj: Record<string, unknown>, key: string): string {
  const val = obj[key];
  return typeof val === 'string' ? val.trim() : '';
}

function capabilityEnforcementDeclared(root: string): boolean {
  const p = path.join(root, 'sdd', 'project-context.yaml');
  try {
    return fs.existsSync(p) && fs.statSync(p).isFile();
  } catch {
    return false;
  }
}

export function discoverProjectRoot(contractPath: string, fallbackRoot: string): string {
  let contractAbs: string;
  try {
    contractAbs = path.resolve(contractPath);
  } catch {
    return fallbackRoot;
  }
  let current = path.dirname(contractAbs);
  while (true) {
    const rel = path.relative(current, contractAbs);
    const segments = rel.split(path.sep);
    if (segments.length > 1 && segments[0] === 'specs') {
      return current;
    }
    const parent = path.dirname(current);
    if (parent === current) {
      return fallbackRoot;
    }
    current = parent;
  }
}

function validateEvidenceWithBaseNote(
  label: string,
  rawPath: unknown,
  root: string,
  failures: string[],
  baseNote: string,
): void {
  const before = failures.length;
  validateEvidencePath(label, rawPath, root, failures);
  if (baseNote) {
    for (let i = before; i < failures.length; i += 1) {
      failures[i] = `${failures[i]} (${baseNote})`;
    }
  }
}

function pass1DuplicateIds(checks: Array<Record<string, unknown>>, failures: string[]): void {
  const seen = new Set<string>();
  for (const check of checks) {
    const cid = typeof check.id === 'string' ? check.id : '?';
    if (seen.has(cid)) {
      failures.push(`duplicate check id '${cid}'`);
    } else {
      seen.add(cid);
    }
  }
}

function pass2PerCheckRules(
  checks: Array<Record<string, unknown>>,
  root: string,
  failures: string[],
  baseNote: string,
): void {
  for (const check of checks) {
    const cid = typeof check.id === 'string' ? check.id : '?';

    const required = check.required ?? false;
    if (typeof required !== 'boolean') {
      failures.push(`check '${cid}' has invalid type for required: ${typeof required} (expected bool)`);
      continue;
    }

    const passes = check.passes ?? false;
    if (typeof passes !== 'boolean') {
      failures.push(`check '${cid}' has invalid type for passes: ${typeof passes} (expected bool)`);
      continue;
    }

    const evidence = strField(check, 'evidence');
    const waiverReason = strField(check, 'waiver_reason');

    if (check.command !== undefined && check.command !== null) {
      if (typeof check.command !== 'string' || !check.command.trim()) {
        failures.push(`check '${cid}' has invalid command: expected a non-empty string`);
      }
    }
    if (check.exit_code !== undefined && check.exit_code !== null) {
      if (typeof check.exit_code !== 'number' || !Number.isInteger(check.exit_code)) {
        failures.push(`check '${cid}' has invalid exit_code: expected an integer`);
      }
    }
    for (const tsField of ['started_at', 'finished_at'] as const) {
      const ts = check[tsField];
      if (ts === undefined || ts === null) continue;
      if (typeof ts !== 'string' || !ISO_UTC_RE.test(ts)) {
        failures.push(`check '${cid}' has invalid ${tsField}: expected ISO-8601 UTC (YYYY-MM-DDTHH:MM:SSZ)`);
      }
    }

    if (!required && !passes) {
      if (!waiverReason) {
        failures.push(
          `check '${cid}' is optional and has passes=false but waiver_reason is empty; ` +
            'either run the check or record why it does not apply in waiver_reason',
        );
      }
    }

    if (required && !passes) {
      failures.push(`required check '${cid}' has passes=false`);
      continue;
    }

    if (passes) {
      if (!evidence) {
        failures.push(`check '${cid}' passes without evidence`);
        continue;
      }
      validateEvidenceWithBaseNote(`check '${cid}' evidence`, evidence, root, failures, baseNote);
    }
  }
}

function pass3RequiredSet(checks: Array<Record<string, unknown>>, failures: string[]): void {
  const presentIds = new Set(checks.map((c) => (typeof c.id === 'string' ? c.id : '?')));
  for (const bid of [...BASELINE_IDS].sort()) {
    if (!presentIds.has(bid)) {
      failures.push(`check removed from contract: '${bid}' is a required baseline check id`);
      continue;
    }
    const found = checks.find((c) => c.id === bid);
    if (found && !found.required) {
      const waiverReason = strField(found, 'waiver_reason');
      if (!waiverReason) {
        failures.push(
          `baseline check '${bid}' is downgraded to required:false without waiver_reason; ` +
            'downgrading a baseline check requires justification recorded in the quality-gate report ' +
            '(set a non-empty waiver_reason)',
        );
      }
    }
  }
}

function pass4RiskTier(
  checks: Array<Record<string, unknown>>,
  contract: Record<string, unknown>,
  root: string,
  failures: string[],
): void {
  const risk = strField(contract, 'risk');
  let stack = strField(contract, 'stack') || 'code';
  if (!risk) return; // Legacy mode: no risk field

  if (!KNOWN_STACKS.has(stack)) {
    failures.push(`contract stack is invalid: ${stack}`);
    stack = 'code';
  }
  const tierSet = RISK_TIERS[risk];
  if (!tierSet) {
    failures.push(`contract risk is invalid: ${risk}`);
    return;
  }

  if (strField(contract, 'schema') === 'verification-contract/v2' && (risk === 'high' || risk === 'critical')) {
    const specRevision = strField(contract, 'spec_revision');
    if (!HEX_40_OR_64_RE.test(specRevision)) {
      failures.push(`risk ${risk} requires a well-formed spec_revision (40- or 64-hex lowercase) under verification-contract/v2`);
    }
  }

  const requiredIds = new Set(tierSet);
  if (!capabilityEnforcementDeclared(root)) {
    for (const gated of CAPABILITY_STATE_GATED_IDS) requiredIds.delete(gated);
  }
  const presentIds = new Set(checks.map((c) => (typeof c.id === 'string' ? c.id : '?')));
  const compileWaivable = NONCODE_STACKS.has(stack);

  for (const reqId of [...requiredIds].sort()) {
    if (!presentIds.has(reqId)) {
      failures.push(`risk ${risk} requires check '${reqId}' present and required:true (missing)`);
    } else {
      const found = checks.find((c) => c.id === reqId);
      if (found && !found.required) {
        if (!(compileWaivable && COMPILE_CHECKS.has(reqId))) {
          failures.push(`risk ${risk} requires check '${reqId}' to be required:true`);
        }
      }
    }
  }
}

function pass5TddEvidence(
  checks: Array<Record<string, unknown>>,
  contract: Record<string, unknown>,
  root: string,
  failures: string[],
  baseNote: string,
): void {
  if (strField(contract, 'required_workflow') !== 'tdd') return;
  for (const check of checks) {
    const cid = typeof check.id === 'string' ? check.id : '?';
    if (!TDD_TEST_IDS.has(cid) || !check.required) continue;
    const redEvidence = strField(check, 'red_evidence');
    const greenEvidence = strField(check, 'green_evidence');
    if (!redEvidence) {
      failures.push(`check '${cid}' required_workflow tdd needs non-empty red_evidence`);
      continue;
    }
    if (!greenEvidence) {
      failures.push(`check '${cid}' required_workflow tdd needs non-empty green_evidence`);
      continue;
    }
    validateEvidenceWithBaseNote(`check '${cid}' red_evidence`, redEvidence, root, failures, baseNote);
    validateEvidenceWithBaseNote(`check '${cid}' green_evidence`, greenEvidence, root, failures, baseNote);
  }
}

function pass5bRiskWorkflow(contract: Record<string, unknown>, failures: string[]): void {
  const risk = strField(contract, 'risk');
  const requiredWorkflow = strField(contract, 'required_workflow');
  if (risk === 'high' || risk === 'critical') {
    if (!requiredWorkflow) {
      failures.push(`risk ${risk} requires required_workflow: tdd (field missing or empty)`);
    } else if (requiredWorkflow !== 'tdd') {
      failures.push(`risk ${risk} requires required_workflow: tdd (got '${requiredWorkflow}')`);
    }
  }
}

function pass6CrossModel(
  checks: Array<Record<string, unknown>>,
  contract: Record<string, unknown>,
  failures: string[],
): void {
  const crossModel = strField(contract, 'cross_model');
  if (!crossModel || crossModel === 'legacy') return;
  if (crossModel !== 'required' && crossModel !== 'waived') {
    failures.push(`contract cross_model is invalid: ${crossModel}`);
    return;
  }
  const cmCheck = checks.find((c) => c.id === 'cross-model-verification');
  if (crossModel === 'required') {
    if (!cmCheck) {
      failures.push("cross_model:required needs a 'cross-model-verification' check present and required:true with evidence");
    } else if (!cmCheck.required) {
      failures.push("cross_model:required needs 'cross-model-verification' to be required:true");
    }
  } else {
    if (!cmCheck) {
      failures.push("cross_model:waived needs a 'cross-model-verification' check present with a non-empty waiver_reason");
    } else if (!strField(cmCheck, 'waiver_reason')) {
      failures.push("cross_model:waived needs a non-empty waiver_reason on 'cross-model-verification'");
    }
  }
}

function pass7ProducerDigest(checks: Array<Record<string, unknown>>, root: string, failures: string[]): void {
  const scriptDir = path.dirname(fileURLToPath(import.meta.url));
  const producerScript = path.join(scriptDir, PRODUCER_DIGEST_SCRIPT_NAME);
  for (const check of checks) {
    if (check.id !== PRODUCER_DIGEST_CHECK_ID || !check.passes) continue;
    const evidence = strField(check, 'evidence');
    if (!evidence) continue;
    const evidencePath = path.resolve(root, evidence);
    let record: unknown;
    try {
      record = JSON.parse(fs.readFileSync(evidencePath, 'utf8'));
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      failures.push(`check '${PRODUCER_DIGEST_CHECK_ID}' evidence could not be read/parsed for producer-digest verification: ${message}`);
      continue;
    }
    const producer = record && typeof record === 'object' ? (record as Record<string, unknown>).producer : null;
    const recordedSha256 =
      producer && typeof producer === 'object' ? (producer as Record<string, unknown>).sha256 : null;
    if (typeof recordedSha256 !== 'string' || !recordedSha256) {
      failures.push(`check '${PRODUCER_DIGEST_CHECK_ID}' evidence is missing producer.sha256`);
      continue;
    }
    let liveSha256 = '';
    try {
      liveSha256 = sha256Buffer(fs.readFileSync(producerScript));
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      failures.push(
        `check '${PRODUCER_DIGEST_CHECK_ID}' producer-digest verification could not read the live script ${PRODUCER_DIGEST_SCRIPT_NAME}: ${message}`,
      );
      continue;
    }
    if (recordedSha256 !== liveSha256) {
      failures.push(
        `check '${PRODUCER_DIGEST_CHECK_ID}' evidence producer.sha256 (${recordedSha256}) ` +
          `does not match the live on-disk ${PRODUCER_DIGEST_SCRIPT_NAME} (${liveSha256})`,
      );
    }
  }
}

export function validateContractFile(contractPath: string, repoRoot: string): ContractValidationResult {
  if (!contractPath || !fs.existsSync(contractPath)) {
    return { taskId: '?', passed: false, failures: [`contract file not found: ${contractPath}`] };
  }

  let doc: unknown;
  try {
    doc = JSON.parse(fs.readFileSync(contractPath, 'utf8'));
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return { taskId: '?', passed: false, failures: [`contract JSON parse error: ${message}`] };
  }

  if (!doc || typeof doc !== 'object' || Array.isArray(doc)) {
    return { taskId: '?', passed: false, failures: ['contract must be a JSON object'] };
  }
  const contract = doc as Record<string, unknown>;
  const taskId = typeof contract.task_id === 'string' && contract.task_id ? contract.task_id : '?';

  // Cloud profile contracts (verification-contract/v3): saved evidence is never provenance.
  // Case-sensitive checks ensure malformed keys/values fail with invalid profile/schema diagnostics.
  if (contract.schema === 'verification-contract/v3') {
    if (contract.profile !== 'cloud') {
      return {
        taskId,
        passed: false,
        failures: [`cloud profile invalid: expected profile 'cloud', got '${String(contract.profile ?? '')}'`],
      };
    }
    return {
      taskId,
      passed: false,
      failures: ['cloud profile requires fresh authenticated collection; saved evidence is not provenance'],
    };
  }
  if (Object.prototype.hasOwnProperty.call(contract, 'profile')) {
    return { taskId, passed: false, failures: ['cloud profile requires verification-contract/v3'] };
  }
  // Reject wrong-cased Profile key (e.g., "Profile": "cloud") explicitly
  for (const key of Object.keys(contract)) {
    if (key.toLowerCase() === 'profile' && key !== 'profile') {
      return { taskId, passed: false, failures: [`contract has unrecognized profile key: ${key}`] };
    }
  }

  const failures: string[] = [];
  const checksRaw = contract.checks ?? [];
  if (!Array.isArray(checksRaw)) {
    failures.push(`contract 'checks' is not a list (got ${typeof checksRaw})`);
    return { taskId, passed: false, failures };
  }

  for (const name of ['risk', 'stack', 'required_workflow', 'spec_revision', 'cross_model', 'schema', 'task_id'] as const) {
    if (contract[name] !== undefined && contract[name] !== null && typeof contract[name] !== 'string') {
      failures.push(`contract ${name} must be a string`);
    }
  }
  if (failures.length > 0) return { taskId, passed: false, failures };

  const contractSchema = strField(contract, 'schema');
  if (contractSchema && contractSchema !== 'verification-contract/v2') {
    failures.push(`contract schema is unrecognized: ${contractSchema}`);
    return { taskId, passed: false, failures };
  }

  const nonDictIndices: number[] = [];
  const checks: Array<Record<string, unknown>> = [];
  for (let i = 0; i < checksRaw.length; i += 1) {
    const entry = checksRaw[i];
    if (!entry || typeof entry !== 'object' || Array.isArray(entry)) {
      nonDictIndices.push(i);
    } else {
      checks.push(entry as Record<string, unknown>);
    }
  }
  if (nonDictIndices.length > 0) {
    failures.push(`contract 'checks' has non-dict elements at indices: [${nonDictIndices.join(', ')}]`);
  }
  for (let i = 0; i < checks.length; i += 1) {
    const check = checks[i]!;
    for (const name of ['id', 'evidence', 'waiver_reason', 'red_evidence', 'green_evidence'] as const) {
      if (check[name] !== undefined && check[name] !== null && typeof check[name] !== 'string') {
        failures.push(`check at index ${i} ${name} must be a string`);
      }
    }
  }
  if (failures.length > 0) return { taskId, passed: false, failures };

  const evidenceRoot = discoverProjectRoot(contractPath, repoRoot);
  const baseNote =
    path.resolve(evidenceRoot) !== path.resolve(repoRoot)
      ? `project-root-relative base: ${evidenceRoot}`
      : '';

  pass1DuplicateIds(checks, failures);
  pass2PerCheckRules(checks, evidenceRoot, failures, baseNote);
  pass3RequiredSet(checks, failures);
  pass4RiskTier(checks, contract, repoRoot, failures);
  pass5TddEvidence(checks, contract, evidenceRoot, failures, baseNote);
  pass5bRiskWorkflow(contract, failures);
  pass6CrossModel(checks, contract, failures);
  pass7ProducerDigest(checks, evidenceRoot, failures);

  return { taskId, passed: failures.length === 0, failures };
}

function main(): number {
  const argv = process.argv.slice(2);
  if (argv[0] === '--help' || argv[0] === '-h') {
    process.stdout.write('Usage: node check-contract.ts <contract-path> [repo-root]\n');
    return 0;
  }
  const contractPath = argv[0] || process.env.CONTRACT || '';
  const repoRoot = argv[1] || process.env.ROOT || '.';
  if (!contractPath) {
    process.stderr.write('check-contract: usage: check-contract.ts <contract-path> [repo-root]\n');
    return 1;
  }
  const result = validateContractFile(contractPath, repoRoot);
  if (!result.passed) {
    process.stdout.write(`Verification contract FAILED for task ${result.taskId}:\n`);
    for (const msg of result.failures) {
      process.stdout.write(` - ${msg}\n`);
    }
    return 1;
  }
  process.stdout.write(`Verification contract passed for task ${result.taskId}.\n`);
  return 0;
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
