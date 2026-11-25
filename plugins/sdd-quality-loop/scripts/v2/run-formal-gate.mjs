#!/usr/bin/env node
/**
 * run-formal-gate.mjs — Checker-agnostic, Windows-safe Formal Verification & Trace Validation Gate (ADR-0054 T-005).
 *
 * Supports adapters via `guardrails.yaml` `formal_verification.checker.adapter`:
 *   - `tlc`      (default: invokes `java -cp <tla2tools.jar> tlc2.TLC ...` with `{ shell: false }`)
 *   - `apalache` (invokes `java -jar <apalache.jar> check ...` with `{ shell: false }`)
 *   - `lean4`    (reserved for v2.3+; returns NOT_IMPLEMENTED)
 *   - `none`     (explicitly skips external model checking)
 *
 * Never spawns `.cmd`/`.bat` wrappers or `shell: true` (Windows CVE-2024-27980 safe).
 * Also performs deterministic `.tla`/`.cfg`/`mapping.json` structural checks and NDJSON Trace Validation.
 *
 * Exit codes:
 *   0 — PASS (or shadow/skipped)
 *   1 — Verification FAIL (invariant violation, negative control failed to fire, or trace mismatch)
 *   2 — Tool / config / missing binary error (in strict mode)
 */
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import {
  VALID_FORMAL_ADAPTERS,
  isMainModule,
  loadGuardrailsConfig,
  resolveExplicitOrAutoRoot,
} from './guardrails-lib.mjs';

const TLA_MODULE_RE = /-{4,}\s*MODULE\s+([A-Za-z0-9_]+)\s*-{4,}/;
const TLA_TRIVIAL_INV_RE = /^[ \t]*([A-Za-z0-9_]+)\s*==\s*TRUE\b/gm;

/**
 * Builds a Windows/POSIX-safe `{ bin, args, options }` invocation spec for external model checkers.
 * Guarantees `{ shell: false }` and direct `java` execution (no `.cmd`/`.bat` wrappers).
 */
export function buildCheckerCommand({ adapter, tlaFile, cfgFile = null, adapterOptions = {}, jarPath = null }) {
  if (!VALID_FORMAL_ADAPTERS.has(adapter)) {
    throw new Error(`Unallowed formal verification adapter: ${adapter}`);
  }
  if (adapter === 'tlc') {
    const resolvedJar = jarPath || adapterOptions.jar || process.env.TLA2TOOLS_JAR || 'tla2tools.jar';
    const workers = String(adapterOptions.workers || 'auto');
    const args = ['-XX:+UseParallelGC', '-cp', resolvedJar, 'tlc2.TLC', '-workers', workers, '-deadlock'];
    if (cfgFile) args.push('-config', cfgFile);
    args.push(tlaFile);
    return { bin: 'java', args, options: { shell: false, encoding: 'utf8' } };
  }
  if (adapter === 'apalache') {
    const resolvedJar = jarPath || adapterOptions.jar || process.env.APALACHE_JAR || 'apalache.jar';
    const length = String(adapterOptions.length || 10);
    const args = ['-jar', resolvedJar, 'check', `--length=${length}`];
    if (cfgFile) args.push(`--config=${cfgFile}`);
    args.push(tlaFile);
    return { bin: 'java', args, options: { shell: false, encoding: 'utf8' } };
  }
  return null;
}

export function validateTlaModelStructure({ tlaPath, cfgPath = null, mappingPath = null }) {
  const errors = [];
  if (!fs.existsSync(tlaPath)) {
    return { ok: false, moduleName: null, invariants: [], errors: [`TLA+ file not found: ${tlaPath}`] };
  }
  const tlaText = fs.readFileSync(tlaPath, 'utf8');
  const modMatch = TLA_MODULE_RE.exec(tlaText);
  if (!modMatch) {
    errors.push(`Missing TLA+ MODULE header in ${tlaPath}`);
  }
  if (!/={4,}/.test(tlaText)) {
    errors.push(`Missing TLA+ ==== footer in ${tlaPath}`);
  }

  TLA_TRIVIAL_INV_RE.lastIndex = 0;
  let m;
  while ((m = TLA_TRIVIAL_INV_RE.exec(tlaText)) !== null) {
    errors.push(`Trivial tautology invariant detected (${m[1]} == TRUE) in ${tlaPath}`);
  }

  const invariants = [];
  if (cfgPath) {
    if (!fs.existsSync(cfgPath)) {
      errors.push(`Config file not found: ${cfgPath}`);
    } else {
      const cfgText = fs.readFileSync(cfgPath, 'utf8');
      for (const line of cfgText.split(/\r?\n/)) {
        const invMatch = /^\s*INVARIANT\s+([A-Za-z0-9_]+)/.exec(line);
        if (invMatch) invariants.push(invMatch[1]);
      }
      if (invariants.length === 0) {
        errors.push(`No INVARIANT declared in ${cfgPath}`);
      }
    }
  }

  let mapping = null;
  if (mappingPath) {
    if (!fs.existsSync(mappingPath)) {
      errors.push(`mapping.json not found: ${mappingPath}`);
    } else {
      try {
        mapping = JSON.parse(fs.readFileSync(mappingPath, 'utf8'));
        if (!mapping.property || !mapping.mapping || typeof mapping.mapping !== 'object') {
          errors.push(`mapping.json must define "property" and "mapping" object`);
        }
      } catch (err) {
        errors.push(`Invalid JSON in mapping.json: ${err.message}`);
      }
    }
  }

  return {
    ok: errors.length === 0,
    moduleName: modMatch ? modMatch[1] : null,
    invariants,
    mapping,
    errors,
  };
}

/**
 * Deterministic NDJSON Trace Validator (REQ-006 / SELF-REQ-002).
 * Validates that every step in an implementation NDJSON trace:
 *   1. Uses only declared actions from `allowedActions` (Init + mapping actions)
 *   2. Maintains monotonically increasing step indices
 *   3. Satisfies the model's safety invariant predicates at every state
 */
export function validateNdjsonTrace({ tracePath, allowedActions = [], modelName = null }) {
  if (!fs.existsSync(tracePath)) {
    return { ok: false, stepsChecked: 0, violations: [`Trace file not found: ${tracePath}`] };
  }
  const lines = fs
    .readFileSync(tracePath, 'utf8')
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter(Boolean);

  const violations = [];
  const actionSet = new Set(['Init', ...allowedActions]);
  let prevStep = -1;
  let sawGatePass = false;

  for (let i = 0; i < lines.length; i += 1) {
    let ev;
    try {
      ev = JSON.parse(lines[i]);
    } catch (err) {
      violations.push(`Line ${i + 1}: invalid JSON (${err.message})`);
      continue;
    }
    if (typeof ev.step !== 'number' || ev.step <= prevStep) {
      violations.push(`Line ${i + 1}: non-monotonic step ${ev.step} (prev=${prevStep})`);
    }
    prevStep = typeof ev.step === 'number' ? ev.step : prevStep;

    if (allowedActions.length > 0 && !actionSet.has(ev.action)) {
      violations.push(`Step ${ev.step}: undeclared action "${ev.action}"`);
    }

    const state = ev.state && typeof ev.state === 'object' ? ev.state : {};

    // Model-specific safety invariants
    if (modelName === 'Reservation' && Array.isArray(state.accepted) && state.accepted.length > 1) {
      violations.push(`Step ${ev.step}: OneAccepted invariant violated (accepted=${JSON.stringify(state.accepted)})`);
    }
    if (modelName === 'TaskLock') {
      if (Array.isArray(state.holders) && state.holders.length > 1) {
        violations.push(`Step ${ev.step}: SingleOwner invariant violated (holders=${JSON.stringify(state.holders)})`);
      }
    }
    if (modelName === 'GateLifecycle') {
      if (state.gateVerdict === 'PASS') sawGatePass = true;
      if (state.status === 'Done' && !sawGatePass && state.gateVerdict !== 'PASS') {
        violations.push(`Step ${ev.step}: DoneRequiresGatePass invariant violated (status=Done without PASS verdict)`);
      }
    }
  }

  return {
    ok: violations.length === 0 && lines.length > 0,
    stepsChecked: lines.length,
    violations,
  };
}

function defaultExecRunner(cmdSpec) {
  try {
    const stdout = execFileSync(cmdSpec.bin, cmdSpec.args, {
      ...cmdSpec.options,
      stdio: ['ignore', 'pipe', 'pipe'],
      timeout: 60000,
    });
    return { status: 0, stdout: String(stdout || ''), stderr: '' };
  } catch (err) {
    if (err && (err.code === 'ENOENT' || /Unable to locate a Java Runtime/i.test(String(err.stderr || err.message || '')))) {
      return { status: 127, unavailable: true, stdout: String(err.stdout || ''), stderr: String(err.stderr || err.message || '') };
    }
    return {
      status: typeof err?.status === 'number' ? err.status : 1,
      stdout: String(err?.stdout || ''),
      stderr: String(err?.stderr || err?.message || ''),
    };
  }
}

export function runFormalGate({
  projectRoot = null,
  tlaPath,
  cfgPath = null,
  negativeCfgPath = null,
  expectedViolatedInvariant = null,
  mappingPath = null,
  tracePath = null,
  adapter = null,
  mode = null,
  jarPath = null,
  execRunner = defaultExecRunner,
}) {
  const root = resolveExplicitOrAutoRoot(projectRoot);
  const config = loadGuardrailsConfig(root);
  const fvCfg = config.formal_verification || {};
  const effectiveAdapter = adapter || fvCfg.checker?.adapter || 'tlc';
  const effectiveMode = mode || (fvCfg.enabled ? fvCfg.mode : 'shadow');

  if (!VALID_FORMAL_ADAPTERS.has(effectiveAdapter)) {
    return {
      schema: 'sdd-formal-gate/v1',
      adapter: effectiveAdapter,
      mode: effectiveMode,
      status: 'TOOL_ERROR',
      exitCode: 2,
      errors: [`Unallowed formal adapter: ${effectiveAdapter}`],
    };
  }

  const resolvedTla = path.isAbsolute(tlaPath) ? tlaPath : path.resolve(root, tlaPath);
  const resolvedCfg = cfgPath ? (path.isAbsolute(cfgPath) ? cfgPath : path.resolve(root, cfgPath)) : null;
  const resolvedNegCfg = negativeCfgPath
    ? path.isAbsolute(negativeCfgPath)
      ? negativeCfgPath
      : path.resolve(root, negativeCfgPath)
    : null;
  const resolvedMapping = mappingPath
    ? path.isAbsolute(mappingPath)
      ? mappingPath
      : path.resolve(root, mappingPath)
    : null;
  const resolvedTrace = tracePath ? (path.isAbsolute(tracePath) ? tracePath : path.resolve(root, tracePath)) : null;

  const structure = validateTlaModelStructure({
    tlaPath: resolvedTla,
    cfgPath: resolvedCfg,
    mappingPath: resolvedMapping,
  });

  const allowedActions = structure.mapping?.mapping ? Object.keys(structure.mapping.mapping) : [];
  const traceResult = resolvedTrace
    ? validateNdjsonTrace({ tracePath: resolvedTrace, allowedActions, modelName: structure.moduleName })
    : null;

  if (!structure.ok) {
    return {
      schema: 'sdd-formal-gate/v1',
      adapter: effectiveAdapter,
      mode: effectiveMode,
      moduleName: structure.moduleName,
      status: 'FAIL',
      exitCode: effectiveMode === 'strict' ? 1 : 0,
      structure,
      trace: traceResult,
      checker: null,
    };
  }

  if (traceResult && !traceResult.ok) {
    return {
      schema: 'sdd-formal-gate/v1',
      adapter: effectiveAdapter,
      mode: effectiveMode,
      moduleName: structure.moduleName,
      status: 'FAIL',
      exitCode: effectiveMode === 'strict' ? 1 : 0,
      structure,
      trace: traceResult,
      checker: null,
    };
  }

  if (effectiveAdapter === 'none') {
    return {
      schema: 'sdd-formal-gate/v1',
      adapter: 'none',
      mode: effectiveMode,
      moduleName: structure.moduleName,
      status: 'PASS',
      exitCode: 0,
      structure,
      trace: traceResult,
      checker: { skipped: true, reason: 'adapter=none' },
    };
  }

  if (effectiveAdapter === 'lean4') {
    return {
      schema: 'sdd-formal-gate/v1',
      adapter: 'lean4',
      mode: effectiveMode,
      moduleName: structure.moduleName,
      status: 'NOT_IMPLEMENTED',
      exitCode: effectiveMode === 'strict' ? 2 : 0,
      structure,
      trace: traceResult,
      checker: { skipped: true, reason: 'Lean 4 adapter is reserved for v2.3+ (ADR-0054)' },
    };
  }

  const adapterOptions = fvCfg.checker?.adapter_options?.[effectiveAdapter] || {};
  const baselineCmd = buildCheckerCommand({
    adapter: effectiveAdapter,
    tlaFile: resolvedTla,
    cfgFile: resolvedCfg,
    adapterOptions,
    jarPath,
  });

  const baselineRes = execRunner(baselineCmd);
  if (baselineRes.unavailable) {
    return {
      schema: 'sdd-formal-gate/v1',
      adapter: effectiveAdapter,
      mode: effectiveMode,
      moduleName: structure.moduleName,
      status: effectiveMode === 'strict' ? 'TOOL_ERROR' : 'SHADOW_UNAVAILABLE',
      exitCode: effectiveMode === 'strict' ? 2 : 0,
      structure,
      trace: traceResult,
      checker: {
        baseline: { unavailable: true, bin: baselineCmd.bin, shell: baselineCmd.options.shell, stderr: baselineRes.stderr },
        negative: null,
      },
    };
  }

  const baselineOk = baselineRes.status === 0;
  let negativeCheck = null;
  let negativeOk = true;

  if (resolvedNegCfg) {
    const negCmd = buildCheckerCommand({
      adapter: effectiveAdapter,
      tlaFile: resolvedTla,
      cfgFile: resolvedNegCfg,
      adapterOptions,
      jarPath,
    });
    const negRes = execRunner(negCmd);
    const combinedOutput = `${negRes.stdout || ''}\n${negRes.stderr || ''}`;
    const invariantMentioned = expectedViolatedInvariant
      ? combinedOutput.includes(expectedViolatedInvariant)
      : true;
    negativeOk = negRes.status !== 0 && invariantMentioned;
    negativeCheck = {
      ok: negativeOk,
      status: negRes.status,
      expectedViolatedInvariant,
      invariantMentioned,
    };
  }

  const allPassed = baselineOk && negativeOk;
  return {
    schema: 'sdd-formal-gate/v1',
    adapter: effectiveAdapter,
    mode: effectiveMode,
    moduleName: structure.moduleName,
    status: allPassed ? 'PASS' : 'FAIL',
    exitCode: allPassed ? 0 : effectiveMode === 'strict' ? 1 : 0,
    structure,
    trace: traceResult,
    checker: {
      command: { bin: baselineCmd.bin, args: baselineCmd.args, shell: baselineCmd.options.shell },
      baseline: { ok: baselineOk, status: baselineRes.status },
      negative: negativeCheck,
    },
  };
}

function parseArgs(argv) {
  const opts = {
    root: null,
    tla: null,
    cfg: null,
    negativeCfg: null,
    expectedInvariant: null,
    mapping: null,
    trace: null,
    adapter: null,
    mode: null,
    jar: null,
  };
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === '--root' && argv[i + 1]) opts.root = argv[++i];
    else if (a === '--tla' && argv[i + 1]) opts.tla = argv[++i];
    else if (a === '--cfg' && argv[i + 1]) opts.cfg = argv[++i];
    else if (a === '--negative-cfg' && argv[i + 1]) opts.negativeCfg = argv[++i];
    else if (a === '--expected-invariant' && argv[i + 1]) opts.expectedInvariant = argv[++i];
    else if (a === '--mapping' && argv[i + 1]) opts.mapping = argv[++i];
    else if (a === '--trace' && argv[i + 1]) opts.trace = argv[++i];
    else if (a === '--adapter' && argv[i + 1]) opts.adapter = argv[++i];
    else if (a === '--mode' && argv[i + 1]) opts.mode = argv[++i];
    else if (a === '--jar' && argv[i + 1]) opts.jar = argv[++i];
  }
  return opts;
}

if (isMainModule(import.meta.url, 'run-formal-gate.mjs')) {
  const opts = parseArgs(process.argv.slice(2));
  if (!opts.tla) {
    process.stderr.write(
      'Usage: node run-formal-gate.mjs --tla <model.tla> [--cfg <model.cfg>] [--negative-cfg <neg.cfg>] [--expected-invariant <Inv>] [--mapping <mapping.json>] [--trace <trace.ndjson>] [--adapter tlc|apalache|lean4|none] [--mode shadow|strict] [--root <dir>]\n',
    );
    process.exit(2);
  }
  const report = runFormalGate({
    projectRoot: opts.root || process.cwd(),
    tlaPath: opts.tla,
    cfgPath: opts.cfg,
    negativeCfgPath: opts.negativeCfg,
    expectedViolatedInvariant: opts.expectedInvariant,
    mappingPath: opts.mapping,
    tracePath: opts.trace,
    adapter: opts.adapter,
    mode: opts.mode,
    jarPath: opts.jar,
  });
  process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
  process.exit(report.exitCode);
}
