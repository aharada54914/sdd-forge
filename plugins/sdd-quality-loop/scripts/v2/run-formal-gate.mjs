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
 *   2 — Invalid adapter, model configuration, or arguments
 *  10 — Local checker unavailable; defer to CI (1 on CI)
 */
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { prepareTraceReplay } from './formal-trace.mjs';
import { randomUUID } from 'node:crypto';
import {
  VALID_FORMAL_ADAPTERS,
  assertValidFeatureName,
  isMainModule,
  validateGuardrailsFile,
  VALID_GATE_MODES,
  resolveExplicitOrAutoRoot,
} from './guardrails-lib.mjs';

const TLA_MODULE_RE = /-{4,}\s*MODULE\s+([A-Za-z0-9_]+)\s*-{4,}/;
const CFG_SECTION = /^(INIT|NEXT|SPECIFICATION|INVARIANTS?|PROPERT(?:Y|IES)|CONSTANTS?|(?:ACTION_)?CONSTRAINTS?|TYPE(?:_CONSTRAINT)?|VIEW|SYMMETRY|CHECK_DEADLOCK|ALIAS|POSTCONDITION)\b/;

function configuredInvariants(cfgText) {
  const names = [];
  let inInvariants = false;
  for (const line of cfgText.split(/\r?\n/)) {
    let text = line.replace(/\\\*.*/, '').trim();
    const section = CFG_SECTION.exec(text);
    if (section) {
      inInvariants = /^INVARIANTS?$/.test(section[1]);
      text = text.slice(section[0].length).trim();
    }
    if (inInvariants && text) names.push(...text.split(/\s+/));
  }
  return names;
}

// A following operator or module declaration ends the RHS. A continuation
// such as "/\ predicate" on the next line still belongs to the definition.
const TLA_TRUE_DEFINITION = /^[ \t]*(\w+)[ \t]*==\s*TRUE[ \t]*\r?$/gm;
const TLA_NEXT_DECLARATION = /^(?:={4,}|-{4,}|(?:LOCAL\s+)?\w+(?:\s*\([^)]*\))?[ \t]*==|(?:ASSUME|ASSUMPTION|AXIOM|CONSTANTS?|VARIABLES?|INSTANCE|THEOREM|LEMMA)\b)/;

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
    const workers = String(adapterOptions.workers || 1);
    const args = ['-XX:+UseParallelGC', '-cp', resolvedJar, 'tlc2.TLC', '-workers', workers];
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

  let invariants = [];
  if (cfgPath) {
    if (!fs.existsSync(cfgPath)) {
      errors.push(`Config file not found: ${cfgPath}`);
    } else {
      const cfgText = fs.readFileSync(cfgPath, 'utf8');
      invariants = configuredInvariants(cfgText);
      if (invariants.length === 0) {
        errors.push(`No INVARIANT declared in ${cfgPath}`);
      }
      const definitions = tlaText.replace(/\(\*[\s\S]*?\*\)/g, ' ').replace(/\\\*[^\n]*/g, '');
      for (const match of definitions.matchAll(TLA_TRUE_DEFINITION)) {
        const name = match[1];
        if (!invariants.includes(name)) continue;
        const next = definitions.slice(match.index + match[0].length).trimStart();
        if (!next || TLA_NEXT_DECLARATION.test(next)) {
          errors.push(`Trivial tautology invariant detected (${name} == TRUE) in ${tlaPath}`);
        }
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
  if (!lines.length) violations.push('Trace contains no observations');
  const actionSet = new Set(['Init', ...allowedActions]);
  let prevStep = -1;
  for (let i = 0; i < lines.length; i += 1) {
    let ev;
    try {
      ev = JSON.parse(lines[i]);
    } catch (err) {
      violations.push(`Line ${i + 1}: invalid JSON (${err.message})`);
      continue;
    }
    if (
      !ev ||
      !Number.isSafeInteger(ev.step) ||
      ev.step !== prevStep + 1 ||
      typeof ev.action !== 'string' ||
      !ev.state ||
      typeof ev.state !== 'object' ||
      Array.isArray(ev.state)
    ) {
      violations.push(`Line ${i + 1}: expected consecutive step, action and observed state`);
      continue;
    }
    prevStep = ev.step;
    if ((ev.step === 0) !== (ev.action === 'Init') || (allowedActions.length && !actionSet.has(ev.action))) {
      violations.push(`Step ${ev.step}: undeclared action or unexpected Init: ${ev.action}`);
    }
    // Immediate diagnostics for shipped models; the checker replays the full
    // projected trace against Init/Next, including models supplied by users.
    const { state } = ev;
    let error;
    if (modelName === 'Reservation' && (!Array.isArray(state.accepted) || state.accepted.length > 1))
      error = 'OneAccepted';
    if (modelName === 'TaskLock' && (!Array.isArray(state.holders) || state.holders.length > 1)) error = 'SingleOwner';
    if (
      modelName === 'GateLifecycle' &&
      state.status === 'Done' &&
      (state.gateVerdict !== 'PASS' || state.approved !== true)
    )
      error = 'DoneRequiresGatePass';
    if (error) violations.push('Step ' + ev.step + ': ' + error);
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
      timeout: cmdSpec.options.timeout,
      maxBuffer: 8 * 1024 * 1024,
    });
    return { status: 0, stdout: String(stdout || ''), stderr: '' };
  } catch (err) {
    if (
      err &&
      (err.code === 'ENOENT' || /Unable to locate a Java Runtime/i.test(String(err.stderr || err.message || '')))
    ) {
      return {
        status: 127,
        unavailable: true,
        stdout: String(err.stdout || ''),
        stderr: String(err.stderr || err.message || ''),
      };
    }
    return {
      status: typeof err?.status === 'number' ? err.status : 1,
      timedOut: err.code === 'ETIMEDOUT',
      stdout: String(err?.stdout || ''),
      stderr: String(err?.stderr || err?.message || ''),
    };
  }
}

function evidenceDirectory(root, runId) {
  if (!/^[A-Za-z0-9][A-Za-z0-9._-]{0,100}$/.test(runId)) throw new Error('Invalid formal run ID');
  let dir = root;
  for (const segment of ['reports', 'verification', runId]) {
    dir = path.join(dir, segment);
    fs.mkdirSync(dir, { recursive: true });
    if (!fs.lstatSync(dir).isDirectory()) throw new Error('Unsafe formal evidence directory');
  }
  return fs.mkdtempSync(path.join(dir, 'checker-'));
}

function recordFormalQuestion(root, feature, evidence, model, phase, result) {
  let directory = root;
  for (const segment of ['reports', 'verification', feature, 'formal-questions']) {
    directory = path.join(directory, segment);
    fs.mkdirSync(directory, { recursive: true });
    if (!fs.lstatSync(directory).isDirectory()) throw new Error('Unsafe formal question directory');
  }
  const reason =
    result.reason || (result.timedOut ? 'timeout' : result.violatedInvariant || 'checker exit ' + result.status);
  const fact = model + ' (' + phase + '): ' + reason;
  const taken = new Set();
  for (const name of ['requirements.md', 'design.md']) {
    const file = path.join(root, 'specs', feature, name);
    if (fs.existsSync(file))
      for (const match of fs.readFileSync(file, 'utf8').matchAll(/\bOQ-\d+\b/g)) taken.add(match[0]);
  }
  const pending = fs.mkdtempSync(path.join(directory, '.pending-'));
  const candidate = path.join(pending, 'question.json');
  try {
    for (let n = 1; ; n++) {
      const id = 'OQ-' + String(n).padStart(3, '0');
      if (taken.has(id)) continue;
      const file = path.join(directory, id + '.json');
      const relative = path.relative(root, file).split(path.sep).join('/');
      const question = { id, feature, status: 'Provisional', fact, evidence };
      fs.writeFileSync(candidate, JSON.stringify(question, null, 2) + '\n');
      try {
        fs.linkSync(candidate, file);
        return { id, path: relative };
      } catch (err) {
        if (err.code !== 'EEXIST') throw err;
      }
      if (!fs.lstatSync(file).isFile()) throw new Error('Invalid existing formal question');
      const existing = JSON.parse(fs.readFileSync(file, 'utf8'));
      if (existing.fact === fact && existing.status === 'Provisional') return { id, path: relative };
    }
  } finally {
    fs.rmSync(pending, { recursive: true, force: true });
  }
}

function inputsChanged(root, baseRef, files) {
  const git = (...args) => execFileSync('git', args, { cwd: root, encoding: 'utf8', shell: false });
  const sha = git('rev-parse', '--verify', '--end-of-options', baseRef + '^{commit}').trim();
  const paths = files.filter(Boolean).map((x) => path.relative(root, x));
  if (paths.some((p) => p.startsWith('..') || path.isAbsolute(p))) return true;
  return Boolean(
    git('diff', '--name-only', sha, '--', ...paths).trim() ||
      git('ls-files', '--others', '--exclude-standard', '--', ...paths).trim(),
  );
}

function checkRun({ adapter, model, cfg, options, jar, timeout, work, runner, expected }) {
  const stagedModel = path.join(work, path.basename(model));
  for (const entry of fs.readdirSync(path.dirname(model))) {
    if (entry.endsWith('.tla') || entry.endsWith('.cfg'))
      fs.copyFileSync(path.join(path.dirname(model), entry), path.join(work, entry));
  }
  fs.copyFileSync(cfg, path.join(work, path.basename(cfg)));
  const command = buildCheckerCommand({
    adapter,
    tlaFile: path.basename(stagedModel),
    cfgFile: path.basename(cfg),
    adapterOptions: options,
    jarPath: jar,
  });
  command.options.cwd = work;
  command.options.timeout = Math.max(1, Math.floor(timeout));

  if (adapter === 'tlc') command.args.splice(command.args.indexOf('tlc2.TLC') + 1, 0, '-generateSpecTE');
  if (adapter === 'apalache' && expected)
    command.args.splice(command.args.indexOf('check') + 1, 0, '--inv=' + expected);
  const result = runner(command);
  const log = [result.stdout, result.stderr].filter(Boolean).join('\n');
  const tlcViolation = /^(?:Error: )?Invariant (\w+) is violated\./m.exec(log)?.[1];
  const violated =
    adapter === 'tlc' ? tlcViolation : expected && /state invariant 0 violated/i.test(log) ? expected : null;
  const checked =
    adapter === 'tlc'
      ? /Model checking completed\. No error has been found\./.test(log)
      : /Checker reports no error|NoError|EXITCODE: OK/.test(log);
  const ok =
    !result.timedOut && (expected ? result.status === 12 && violated === expected : result.status === 0 && checked);
  return {
    ok,
    status: result.status,
    unavailable: Boolean(result.unavailable),
    timedOut: Boolean(result.timedOut),
    violatedInvariant: violated || null,
    distinctStates: Number(log.match(/(\d+) distinct states found, \d+ states? left on queue\./)?.[1]) || null,
    depth: Number(log.match(/depth of the complete state graph search is (\d+)\./)?.[1]) || null,
    version:
      log.match(/^TLC2 Version [^\r\n]+/m)?.[0] ||
      log.match(/APALACHE version: ([^ |]+) \| build: ([a-f0-9]+)/)?.[0] ||
      null,
    ...(adapter === 'apalache' ? { length: Number(options.length || 10) } : {}),
    ...(expected ? { expectedViolatedInvariant: expected, invariantMentioned: violated === expected } : {}),
    log,
    command: { bin: command.bin, shell: false, args: command.args },
  };
}

function retainCheck(dir, name, result, work) {
  fs.writeFileSync(path.join(dir, name + '.log'), result.log);
  // TLC writes a trace module, Apalache writes one under its run directory.
  const copyTraces = (from, depth) => {
    if (depth > 5) return;
    for (const entry of fs.readdirSync(from, { withFileTypes: true })) {
      const source = path.join(from, entry.name);
      if (entry.isDirectory() && entry.name !== 'states') copyTraces(source, depth + 1);
      if (
        entry.isFile() &&
        /^SpecTE\.(?:cfg|tla)$|(?:_TTrace_|_TE\.|^counterexample|^violation\d+).*\.(?:tla|json)$|_TE\.tla$/i.test(
          entry.name,
        )
      )
        fs.copyFileSync(source, path.join(dir, name + '-' + entry.name));
    }
  };
  copyTraces(work, 0);
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
  ci = Boolean(process.env.CI && process.env.CI !== 'false'),
  risk = null,
  feature = null,
  round = 0,
  runId = null,
  baseRef = null,
}) {
  const root = resolveExplicitOrAutoRoot(projectRoot);
  const settings = validateGuardrailsFile(root);
  const config = settings.config;
  const fv = config.formal_verification;
  adapter ||= fv.checker.adapter;
  mode ||= fv.enabled ? fv.mode : 'off';
  const report = { schema: 'sdd-formal-gate/v1', adapter, mode };
  const finish = (status, exitCode, more = {}) => ({ ...report, status, exitCode, ...more });
  const failed = mode === 'strict' ? 1 : 0;
  if (!settings.ok) return finish('TOOL_ERROR', 2, { errors: settings.errors });
  if (!VALID_FORMAL_ADAPTERS.has(adapter) || !VALID_GATE_MODES.has(mode))
    return finish('TOOL_ERROR', 2, { errors: ['Invalid formal adapter or mode'] });
  if (mode === 'off') return finish('SKIPPED', 0, { reason: 'mode=off' });
  if (!Number.isSafeInteger(round) || round < 0) return finish('TOOL_ERROR', 2, { errors: ['Invalid repair round'] });
  if (feature) assertValidFeatureName(feature);
  const model = path.resolve(root, tlaPath);
  const stem = model.slice(0, -path.extname(model).length);
  const resolve = (file, fallback) =>
    file ? path.resolve(root, file) : fallback && fs.existsSync(fallback) ? fallback : null;
  const cfg = resolve(cfgPath, stem + '.cfg');
  const negative = resolve(negativeCfgPath, stem + '.negative.cfg');
  const mapping = resolve(mappingPath, path.join(path.dirname(model), 'mapping.json'));
  const trace = resolve(tracePath);
  const structure = validateTlaModelStructure({ tlaPath: model, cfgPath: cfg, mappingPath: mapping });
  const contract = structure.mapping?.models?.[structure.moduleName] || structure.mapping;
  Object.assign(report, { moduleName: structure.moduleName, structure, trace: null, checker: null });
  if (!structure.ok) return finish('FAIL', failed);
  expectedViolatedInvariant ||= contract?.expected_violated_invariant || null;
  if (['high', 'critical'].includes(risk) && (!trace || !contract?.trace || adapter === 'none'))
    return finish('FAIL', 1, { errors: ['High-risk checking needs a supported implementation trace projection'] });
  if (
    baseRef &&
    !inputsChanged(root, baseRef, [
      path.dirname(model),
      feature && path.join(root, 'specs', feature, 'tasks.md'),
      cfg,
      negative,
      mapping,
      trace,
      ...(contract?.sources || []).map((s) => path.resolve(root, s)),
      path.join(root, 'sdd', 'guardrails.yaml'),
      path.join(root, 'sdd', 'guardrails.json'),
    ])
  )
    return finish('SKIPPED', 0, { reason: 'formal inputs unchanged at ' + baseRef });
  function traceFailure(errors) {
    if (runId || execRunner === defaultExecRunner) {
      const dir = evidenceDirectory(root, runId || 'formal-' + randomUUID());
      if (trace && fs.existsSync(trace) && fs.lstatSync(trace).isFile())
        fs.copyFileSync(trace, path.join(dir, 'observed.ndjson'));
      fs.writeFileSync(path.join(dir, 'trace.log'), errors.join('\n') + '\n');
      report.evidence = path.relative(root, dir).split(path.sep).join('/');
      if (feature && round >= config.limits.max_auto_fix_rounds) {
        report.openQuestion = recordFormalQuestion(root, feature, report.evidence, structure.moduleName, 'trace', {
          reason: errors[0],
        });
      }
    }
    return finish('FAIL', failed, { errors });
  }
  if (trace) {
    report.trace = validateNdjsonTrace({
      tracePath: trace,
      modelName: structure.moduleName,
      allowedActions: Object.keys(contract?.actions || contract?.mapping || {}),
    });
    if (!report.trace.ok) return traceFailure(report.trace.violations);
  }
  if (adapter === 'none') return finish('SKIPPED', 0, { checker: { skipped: true, reason: 'adapter=none' } });
  if (adapter === 'lean4') return finish('NOT_IMPLEMENTED', mode === 'strict' ? 2 : 0);
  if (!cfg || !negative || !fs.existsSync(negative) || !/^[A-Za-z][A-Za-z0-9_]*$/.test(expectedViolatedInvariant || ''))
    return finish('TOOL_ERROR', 2, { errors: ['Baseline CFG, negative CFG and expected violated invariant required'] });
  const negativeStructure = validateTlaModelStructure({ tlaPath: model, cfgPath: negative });
  if (
    !structure.invariants.includes(expectedViolatedInvariant) ||
    !negativeStructure.invariants.includes(expectedViolatedInvariant)
  )
    return finish('TOOL_ERROR', 2, { errors: ['Baseline and negative CFG must check the named invariant'] });
  const options = fv.checker.adapter_options[adapter];
  const jar = path.resolve(
    root,
    jarPath ||
      options.jar ||
      (adapter === 'tlc' ? process.env.TLA2TOOLS_JAR : process.env.APALACHE_JAR) ||
      (adapter === 'tlc' ? 'tla2tools.jar' : 'apalache.jar'),
  );
  const unavailable = () =>
    finish(ci ? 'TOOL_UNAVAILABLE' : 'DEFERRED_TO_CI', ci ? 1 : 10, {
      errors: ['Checker or Java runtime unavailable'],
    });
  if (execRunner === defaultExecRunner && !fs.existsSync(jar)) return unavailable();
  const deadline = Date.now() + fv.pr_total_budget_sec * 1000;
  const scratch = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-checker-'));
  let saved = null;
  try {
    const runs = [
      ['baseline', model, cfg, null],
      ['negative', model, negative, expectedViolatedInvariant],
    ];
    if (trace) {
      if (!contract?.trace) return traceFailure(['Missing trace projection in mapping.json']);
      try {
        const replay = prepareTraceReplay({
          model,
          cfg,
          contract,
          tracePath: trace,
          directory: path.join(scratch, 'projection'),
        });
        runs.push(['replay', replay.model, replay.cfg, 'TraceIncomplete']);
      } catch (err) {
        return traceFailure([err.message]);
      }
    }
    for (const [name, source, file, expected] of runs) {
      const work = path.join(scratch, name);
      fs.mkdirSync(work);
      const remaining = Math.min(fv.timeout_sec * 1000, deadline - Date.now());
      const budgetError = 'Formal run exceeded total time budget';
      const result =
        remaining <= 0
          ? { ok: false, status: null, timedOut: true, reason: budgetError, log: budgetError + '\n', command: null }
          : checkRun({
              adapter,
              model: source,
              cfg: file,
              options,
              jar,
              timeout: remaining,
              work,
              runner: execRunner,
              expected,
            });
      const { log, command, ...summary } = result;
      report.checker ||= { baseline: null, negative: null, command };
      report.checker[name] = { ...summary, command };
      if (name === 'replay') {
        report.trace.ok = result.ok;
        if (!result.ok) report.trace.violations.push('The baseline model could not reproduce the observed trace');
      }
      if (result.unavailable) return unavailable();
      if (runId || execRunner === defaultExecRunner) {
        saved ||= evidenceDirectory(root, runId || 'formal-' + randomUUID());
        retainCheck(saved, name, result, work);
        if (name === 'replay') {
          fs.copyFileSync(trace, path.join(saved, 'observed.ndjson'));
          fs.copyFileSync(source, path.join(saved, 'SDDTraceReplay.tla'));
          fs.copyFileSync(file, path.join(saved, 'SDDTraceReplay.cfg'));
        }
        report.evidence = path.relative(root, saved).split(path.sep).join('/');
      }
      if (!result.ok) {
        if (feature && round >= config.limits.max_auto_fix_rounds && saved) {
          const question = recordFormalQuestion(root, feature, report.evidence, structure.moduleName, name, summary);
          report.openQuestion = question;
        }
        return finish('FAIL', result.timedOut ? 1 : failed, result.reason ? { errors: [result.reason] } : {});
      }
    }
    return finish('PASS', 0);
  } finally {
    fs.rmSync(scratch, { recursive: true, force: true });
  }
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
    else if (a === '--feature' && argv[i + 1]) opts.feature = argv[++i];
    else if (a === '--round' && argv[i + 1]) opts.round = Number(argv[++i]);
    else if (a === '--run-id' && argv[i + 1]) opts.runId = argv[++i];
    else if (a === '--base-ref' && argv[i + 1]) opts.baseRef = argv[++i];
    else if (a === '--risk' && argv[i + 1]) opts.risk = argv[++i];
    else if (a === '--jar' && argv[i + 1]) opts.jar = argv[++i];
  }
  return opts;
}

if (isMainModule(import.meta.url, 'run-formal-gate.mjs')) {
  const opts = parseArgs(process.argv.slice(2));
  if (!opts.tla) {
    process.stderr.write(
      'Usage: node run-formal-gate.mjs --tla <model.tla> [--cfg <model.cfg>] [--negative-cfg <neg.cfg>] [--expected-invariant <Inv>] [--mapping <mapping.json>] [--trace <trace.ndjson>] [--adapter tlc|apalache|lean4|none] [--mode shadow|strict] [--root <dir>] [--feature <slug>] [--round <n>] [--run-id <id>] [--base-ref <revision>] [--risk high]\n',
    );
    process.exit(2);
  }
  let report;
  try {
    report = runFormalGate({
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
      feature: opts.feature,
      round: opts.round,
      runId: opts.runId,
      baseRef: opts.baseRef,
      risk: opts.risk,
    });
  } catch (err) {
    report = { status: 'TOOL_ERROR', exitCode: 2, errors: [err.message] };
  }
  process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
  process.exit(report.exitCode);
}
