#!/usr/bin/env node
/**
 * check-contract.ts — Zero-dependency erasable TypeScript 7.0 port of `check-contract.py` (ADR-0055).
 *
 * Delegates evidence path safety validation directly to `./validate-path.ts`
 * without Python runtime dependencies.
 *
 * Usage:
 *   node plugins/sdd-quality-loop/scripts/check-contract.ts <contract-path> [repo-root]
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { validateEvidencePath } from './validate-path.ts';

const RISK_TIERS: Record<string, ReadonlySet<string>> = {
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

const COMPILE_CHECKS = new Set(['lint', 'typecheck', 'build']);
const NONCODE_STACKS = new Set(['shell', 'docs', 'spec']);
const KNOWN_STACKS = new Set(['code', 'shell', 'docs', 'spec']);
const CAPABILITY_STATE_GATED_IDS = new Set(['check-component-coverage']);

export interface ContractValidationResult {
  passed: boolean;
  failures: string[];
}

export function validateContractFile(contractPath: string, repoRoot: string): ContractValidationResult {
  const failures: string[] = [];
  if (!contractPath || !fs.existsSync(contractPath) || !fs.statSync(contractPath).isFile()) {
    return { passed: false, failures: [`contract file missing: ${contractPath}`] };
  }

  let doc: unknown;
  try {
    doc = JSON.parse(fs.readFileSync(contractPath, 'utf8'));
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return { passed: false, failures: [`invalid JSON in contract: ${message}`] };
  }

  if (!doc || typeof doc !== 'object' || Array.isArray(doc)) {
    return { passed: false, failures: ['contract root must be a JSON object'] };
  }
  const contract = doc as Record<string, unknown>;
  const risk = typeof contract.risk === 'string' ? contract.risk.trim().toLowerCase() : '';
  const tierRequired = RISK_TIERS[risk];
  if (!tierRequired) {
    failures.push(`unknown or missing risk tier: ${String(contract.risk ?? '')}`);
  }

  const stack = typeof contract.stack === 'string' ? contract.stack.trim().toLowerCase() : 'code';
  if (!KNOWN_STACKS.has(stack)) {
    failures.push(`unknown stack: ${stack}`);
  }

  const checks = Array.isArray(contract.checks) ? contract.checks : null;
  if (!checks || checks.length === 0) {
    failures.push('contract checks must be a non-empty array');
    return { passed: false, failures };
  }

  const seenIds = new Set<string>();
  for (const item of checks) {
    if (!item || typeof item !== 'object' || Array.isArray(item)) {
      failures.push('check entry must be an object');
      continue;
    }
    const check = item as Record<string, unknown>;
    const id = typeof check.id === 'string' ? check.id.trim() : '';
    if (!id) {
      failures.push('check entry missing id');
      continue;
    }
    if (seenIds.has(id)) {
      failures.push(`duplicate check id: ${id}`);
    }
    seenIds.add(id);

    const status = typeof check.status === 'string' ? check.status.trim().toLowerCase() : '';
    const isNa = status === 'not-applicable' || status === 'n/a';
    const passes = check.passes === true;

    if (isNa) {
      const reason = typeof check.reason === 'string' ? check.reason.trim() : '';
      if (!reason) {
        failures.push(`check '${id}' is not-applicable without a reason`);
      }
      if (NONCODE_STACKS.has(stack) && COMPILE_CHECKS.has(id)) {
        continue;
      }
      if (tierRequired?.has(id) && !CAPABILITY_STATE_GATED_IDS.has(id)) {
        failures.push(`required check '${id}' cannot be not-applicable for risk '${risk}'`);
      }
      continue;
    }

    if (!passes) {
      failures.push(`check '${id}' did not pass`);
    }
    validateEvidencePath(`check '${id}' evidence`, check.evidence, repoRoot, failures);
  }

  if (tierRequired) {
    const hasProjectContext = fs.existsSync(path.join(repoRoot, 'sdd', 'project-context.yaml'));
    for (const requiredId of tierRequired) {
      if (CAPABILITY_STATE_GATED_IDS.has(requiredId) && !hasProjectContext) continue;
      if (NONCODE_STACKS.has(stack) && COMPILE_CHECKS.has(requiredId)) continue;
      if (!seenIds.has(requiredId)) {
        failures.push(`missing required check for risk '${risk}': ${requiredId}`);
      }
    }
  }

  return { passed: failures.length === 0, failures };
}

function main(): number {
  const contractPath = process.argv[2] || process.env.CONTRACT || '';
  const repoRoot = process.argv[3] || process.env.ROOT || process.cwd();
  const result = validateContractFile(contractPath, repoRoot);
  if (!result.passed) {
    for (const msg of result.failures) {
      process.stderr.write(`check-contract: FAIL: ${msg}\n`);
    }
    return 1;
  }
  process.stdout.write('check-contract: PASS\n');
  return 0;
}

if (path.resolve(process.argv[1] || '') === path.resolve(fileURLToPath(import.meta.url))) {
  process.exit(main());
}
