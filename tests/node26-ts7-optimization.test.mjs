/**
 * Comprehensive verification suite for ADR-0055 / specs/node26-ts7-mcpv2-optimization.
 * Covers AC-001 through AC-016:
 *   - Phase 0: Node 26.13+ CI/engines, TS 7.0 (tsgo) erasableSyntaxOnly typecheck,
 *     diagnostics_channel runtime profiler, and benchmark runner.
 *   - Phase 1: 2-stage portable Compile Cache, --warmup entrypoints, sdd-doctor
 *     --rebuild-cache and runtime/cache/Git diagnostics, hook env wiring.
 *   - Phase 2: Fast Node built-in primitives (crypto.hash, RegExp.escape, fs.promises.glob,
 *     AbortSignal.timeout), node:sqlite incremental scan cache & metrics aggregation,
 *     explicit resource management (using / Symbol.dispose) for task locks,
 *     and 5 buildless erasable .ts ports with exact Parity tests against Python/Bash originals.
 *   - Phase 3: MCP SDK v2 migration (@modelcontextprotocol/server v2 + cacheHints),
 *     local-env-mcp deprecation boundary, role Node config profiles, and real
 *     --permission / --disallow-code-generation-from-strings / --disable-proto=throw
 *     security boundary enforcement.
 */
import test from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { execFileSync, spawn, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  attachProfileCollector,
  getProfileEvents,
  profilePhase,
  recordStartup,
  resetProfileEvents,
} from '../plugins/sdd-quality-loop/scripts/v2/runtime-profile.mjs';
import {
  inspectCompileCache,
  warmCompileCache,
} from '../plugins/sdd-quality-loop/scripts/v2/compile-cache.mjs';
import {
  escapeRegExp,
  sha256Text,
} from '../plugins/sdd-quality-loop/scripts/v2/v2-pure-lib.mjs';
import { openScanCache } from '../plugins/sdd-quality-loop/scripts/v2/scan-cache.mjs';
import {
  createTimeoutSignal,
  discoverFilesWithGlob,
  readGitStatusPorcelainV2,
  scanPlaceholders,
} from '../plugins/sdd-quality-loop/scripts/v2/run-sdd-gate.mjs';
import {
  acquireTaskLockHandle,
  computeLockWindow,
  getLockStatus,
} from '../plugins/sdd-quality-loop/scripts/v2/task-lock.mjs';
import {
  summarizeMetricsWithSqlite,
} from '../plugins/sdd-quality-loop/scripts/v2/factory-metrics.mjs';

const THIS_DIR = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(THIS_DIR, '..');

function makeTempDir(prefix) {
  return fs.mkdtempSync(path.join(os.tmpdir(), `sdd-node26-${prefix}-`));
}

// ---------------------------------------------------------------------------
// Phase 0: Node 26.13+ CI / engines, TS 7.0 typecheck, Profiler, Benchmark
// ---------------------------------------------------------------------------

test('AC-001: CI workflows pin Node 26.13.0 and MCP packages declare engines.node >=26.13.0', () => {
  for (const wf of [
    '.github/workflows/test.yml',
    '.github/workflows/sdd-guardrails.yml',
    '.github/workflows/release.yml',
  ]) {
    const content = fs.readFileSync(path.join(REPO_ROOT, wf), 'utf8');
    assert.match(content, /node-version:\s*["']26\.13\.0["']/, `${wf} must pin node-version 26.13.0`);
    assert.doesNotMatch(content, /node-version:\s*["']20["']/, `${wf} must not retain node-version 20`);
  }

  for (const pkgRel of [
    'mcp/sdd-forge-mcp/package.json',
    'mcp/ci-mcp/package.json',
    'mcp/local-env-mcp/package.json',
  ]) {
    const pkg = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, pkgRel), 'utf8'));
    assert.equal(pkg.engines?.node, '>=26.13.0', `${pkgRel} engines.node mismatch`);
  }

  const localEnvPkg = JSON.parse(
    fs.readFileSync(path.join(REPO_ROOT, 'mcp/local-env-mcp/package.json'), 'utf8'),
  );
  assert.match(localEnvPkg.description, /DEPRECATED/i, 'local-env-mcp must be clearly marked deprecated');
});

test('AC-002: root tsconfig.json enables erasableSyntaxOnly and passes TS 7.0 (tsgo) typecheck', () => {
  const tsconfig = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, 'tsconfig.json'), 'utf8'));
  assert.equal(tsconfig.compilerOptions.erasableSyntaxOnly, true);
  assert.equal(tsconfig.compilerOptions.allowImportingTsExtensions, true);
  assert.equal(tsconfig.compilerOptions.verbatimModuleSyntax, true);
  assert.equal(tsconfig.compilerOptions.noEmit, true);

  const tscBin = path.join(REPO_ROOT, 'mcp/sdd-forge-mcp/node_modules/.bin/tsc');
  assert.ok(fs.existsSync(tscBin), 'TS 7.0 tsc binary must exist in mcp/sdd-forge-mcp/node_modules/.bin/tsc');
  const res = spawnSync(tscBin, ['--noEmit', '-p', path.join(REPO_ROOT, 'tsconfig.json')], {
    cwd: REPO_ROOT,
    encoding: 'utf8',
    shell: process.platform === 'win32',
  });
  assert.equal(res.status, 0, `TS 7.0 typecheck failed:\n${res.stdout}\n${res.stderr}`);
});

test('AC-003: diagnostics_channel profiler captures startup/scan/exec and bench-runtime.ts runs', () => {
  resetProfileEvents();
  const dispose = attachProfileCollector();
  try {
    recordStartup('unit-test', { version: '2.1.5' });
    const scanValue = profilePhase('scan', 'placeholders', () => 42, { fileCount: 3 });
    const execValue = profilePhase('exec', 'cmd', () => 'ok', { commandCount: 1 });
    assert.equal(scanValue, 42);
    assert.equal(execValue, 'ok');
  } finally {
    dispose();
  }

  const phases = getProfileEvents().map((e) => e.phase);
  assert.ok(phases.includes('startup'));
  assert.ok(phases.includes('scan'));
  assert.ok(phases.includes('exec'));

  const bench = spawnSync(
    process.execPath,
    [path.join(REPO_ROOT, 'scripts/bench-runtime.ts'), '--iterations', '2', '--json'],
    { cwd: REPO_ROOT, encoding: 'utf8', timeout: 30_000 },
  );
  assert.equal(bench.status, 0, `bench-runtime.ts failed:\n${bench.stderr}`);
  const parsed = JSON.parse(bench.stdout);
  assert.equal(parsed.schema, 'sdd-runtime-benchmark/v1');
  assert.ok(Array.isArray(parsed.startup) && parsed.startup.length >= 3);
  assert.ok(parsed.hash.oneShotMs >= 0);
  assert.ok(parsed.glob.fileCount >= 1);
});

// ---------------------------------------------------------------------------
// Phase 1: 2-stage portable Compile Cache, --warmup, sdd-doctor, Hooks
// ---------------------------------------------------------------------------

test('AC-004/005/006: --warmup entrypoints, portable compile cache, sdd-doctor rebuild, and hooks env', () => {
  const warmupTargets = [
    'plugins/sdd-quality-loop/scripts/v2/sdd-soft-guard.mjs',
    'plugins/sdd-quality-loop/scripts/v2/run-sdd-gate.mjs',
    'plugins/sdd-quality-loop/scripts/v2/render-decision-view.mjs',
    'plugins/sdd-quality-loop/scripts/v2/sdd-doctor.mjs',
    'mcp/sdd-forge-mcp/dist/index.js',
    'mcp/ci-mcp/dist/index.js',
  ];
  for (const rel of warmupTargets) {
    const res = spawnSync(process.execPath, [path.join(REPO_ROOT, rel), '--warmup'], {
      cwd: REPO_ROOT,
      encoding: 'utf8',
      timeout: 15_000,
    });
    assert.equal(res.status, 0, `--warmup failed for ${rel}: ${res.stderr}`);
    assert.equal(res.stdout.trim(), '', `--warmup must emit no stdout for ${rel}`);
  }

  const tmpCacheDir = makeTempDir('compile-cache');
  try {
    const warmResult = warmCompileCache({ installRoot: REPO_ROOT, cacheDir: tmpCacheDir });
    assert.equal(warmResult.ok, true, `warmCompileCache failed: ${JSON.stringify(warmResult)}`);
    assert.ok(warmResult.warmed.length >= 4);
    const inspected = inspectCompileCache(tmpCacheDir);
    assert.equal(inspected.exists, true);
    assert.ok(inspected.fileCount > 0, 'compile cache directory must contain generated cache files');

    const doctorRebuild = spawnSync(
      process.execPath,
      [
        path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/sdd-doctor.mjs'),
        '--rebuild-cache',
        '--cache-dir',
        tmpCacheDir,
        '--json',
      ],
      { cwd: REPO_ROOT, encoding: 'utf8', timeout: 30_000 },
    );
    assert.equal(doctorRebuild.status, 0, `sdd-doctor --rebuild-cache failed: ${doctorRebuild.stderr}`);
    const rebuildPayload = JSON.parse(doctorRebuild.stdout);
    assert.equal(rebuildPayload.ok, true);
    assert.ok(rebuildPayload.fileCount > 0);

    const doctorReport = spawnSync(
      process.execPath,
      [
        path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/sdd-doctor.mjs'),
        '--root',
        REPO_ROOT,
        '--json',
      ],
      { cwd: REPO_ROOT, encoding: 'utf8', timeout: 30_000 },
    );
    assert.equal(doctorReport.status, 0, `sdd-doctor --json failed: ${doctorReport.stderr}`);
    const doctorPayload = JSON.parse(doctorReport.stdout);
    assert.ok(
      doctorPayload.findings.some((f) => f.category === 'runtime'),
      'sdd-doctor must emit runtime diagnostic findings',
    );
    assert.ok(
      doctorPayload.findings.some((f) => f.category === 'git-config'),
      'sdd-doctor must emit git-config diagnostic findings',
    );
  } finally {
    fs.rmSync(tmpCacheDir, { recursive: true, force: true });
  }

  const claudeHooks = JSON.parse(
    fs.readFileSync(path.join(REPO_ROOT, 'plugins/sdd-quality-loop/hooks/claude-hooks.json'), 'utf8'),
  );
  const hookList = Object.values(claudeHooks.hooks).flat().flatMap((g) => g.hooks || []);
  assert.ok(hookList.length > 0);
  for (const h of hookList) {
    assert.equal(h.command, 'node');
    assert.equal(h.env?.NODE_COMPILE_CACHE_PORTABLE, '1');
    assert.equal(h.env?.NODE_COMPILE_CACHE_READONLY, '1');
    assert.ok(typeof h.env?.NODE_COMPILE_CACHE === 'string' && h.env.NODE_COMPILE_CACHE.length > 0);
  }

  const codexHooks = JSON.parse(
    fs.readFileSync(path.join(REPO_ROOT, 'plugins/sdd-quality-loop/hooks/codex-hooks.json'), 'utf8'),
  );
  const codexList = Object.values(codexHooks.hooks).flat().flatMap((g) => g.hooks || []);
  assert.ok(codexList.length > 0);
  for (const h of codexList) {
    assert.match(h.command, /NODE_COMPILE_CACHE_PORTABLE=1/);
    assert.match(h.command, /NODE_COMPILE_CACHE_READONLY=1/);
    assert.match(h.command_windows, /NODE_COMPILE_CACHE_PORTABLE:'1'/);
    assert.match(h.command_windows, /NODE_COMPILE_CACHE_READONLY:'1'/);
  }
});

// ---------------------------------------------------------------------------
// Phase 2: Fast primitives, SQLite scan cache, Task-lock using, Metrics SQLite
// ---------------------------------------------------------------------------

test('AC-007: fast Node built-in primitives (crypto.hash, RegExp.escape, fs.promises.glob, AbortSignal.timeout)', async () => {
  const sample = 'sdd-forge Node.js 26.13+ 日本語 payload';
  const expected = crypto.createHash('sha256').update(sample, 'utf8').digest('hex');
  assert.equal(sha256Text(sample), expected);

  const metaChars = 'a.b*c+d?^$()[]{}|\\/';
  const escaped = escapeRegExp(metaChars);
  assert.equal(new RegExp(`^${escaped}$`).test(metaChars), true);
  assert.equal(new RegExp(`^${escaped}$`).test('axb'), false);

  const signal = createTimeoutSignal(5000);
  assert.equal(signal instanceof AbortSignal, true);
  assert.equal(signal.aborted, false);

  const globbed = await discoverFilesWithGlob(REPO_ROOT, ['specs/node26-ts7-mcpv2-optimization/*.md']);
  assert.ok(globbed.includes('specs/node26-ts7-mcpv2-optimization/requirements.md'));
  assert.ok(globbed.includes('specs/node26-ts7-mcpv2-optimization/design.md'));

  const tmpRepo = makeTempDir('git-v2');
  try {
    execFileSync('git', ['init', '-q'], { cwd: tmpRepo });
    fs.writeFileSync(path.join(tmpRepo, 'hello.txt'), 'world\n', 'utf8');
    const changed = readGitStatusPorcelainV2(tmpRepo);
    assert.ok(changed.some((e) => e.path === 'hello.txt' && e.kind === 'untracked'));
  } finally {
    fs.rmSync(tmpRepo, { recursive: true, force: true });
  }
});

test('AC-008: node:sqlite incremental scan cache persists, hits on unchanged file, and invalidates on edit', () => {
  const tmpRoot = makeTempDir('scan-cache');
  try {
    fs.mkdirSync(path.join(tmpRoot, 'src'), { recursive: true });
    const filePath = path.join(tmpRoot, 'src', 'app.js');
    fs.writeFileSync(filePath, 'export const answer = 42;\n', 'utf8');

    const cache1 = openScanCache(tmpRoot);
    try {
      assert.equal(cache1.stats().persistent, true);
      const first = scanPlaceholders(tmpRoot, ['src/app.js'], cache1);
      assert.equal(first.passed, true);
      assert.equal(cache1.stats().hits, 0);
      assert.equal(cache1.stats().misses, 1);

      const second = scanPlaceholders(tmpRoot, ['src/app.js'], cache1);
      assert.equal(second.passed, true);
      assert.equal(cache1.stats().hits, 1);

      // Modify file -> cache must invalidate and detect the placeholder marker
      fs.writeFileSync(filePath, 'export function bad() {\n  // ' + 'TO' + 'DO: broken\n  return 0;\n}\n', 'utf8');
      const future = new Date(Date.now() + 5000);
      fs.utimesSync(filePath, future, future);

      const third = scanPlaceholders(tmpRoot, ['src/app.js'], cache1);
      assert.equal(third.passed, false);
      assert.equal(cache1.stats().hits, 1);
      assert.equal(cache1.stats().misses, 2);
      assert.ok(third.findings.length >= 1);
    } finally {
      cache1.close();
    }

    assert.ok(fs.existsSync(path.join(tmpRoot, '.sdd', 'scan-cache.sqlite')));
  } finally {
    fs.rmSync(tmpRoot, { recursive: true, force: true });
  }
});

test('AC-009: task-lock Symbol.dispose handle & computeLockWindow + factory-metrics SQLite summary', () => {
  const tmpRoot = makeTempDir('lock-metrics');
  try {
    const win = computeLockWindow(60);
    assert.match(win.acquiredAt, /^\d{4}-\d{2}-\d{2}T/);
    assert.match(win.expiresAt, /^\d{4}-\d{2}-\d{2}T/);
    assert.ok(Date.parse(win.expiresAt) > Date.parse(win.acquiredAt));

    const handle = acquireTaskLockHandle({
      feature: 'demo',
      taskId: 'T-001',
      owner: 'agent-1',
      projectRoot: tmpRoot,
    });
    assert.equal(handle.acquired, true);
    assert.equal(getLockStatus({ feature: 'demo', taskId: 'T-001', projectRoot: tmpRoot }).locked, true);
    handle[Symbol.dispose]();
    assert.equal(getLockStatus({ feature: 'demo', taskId: 'T-001', projectRoot: tmpRoot }).locked, false);

    // Verify SQLite in-memory aggregation over factory-metrics records
    const summary = summarizeMetricsWithSqlite([
      { verdict: 'PASS', totalDurationMs: 100, sensorFindingCount: 0, placeholderFindingCount: 0 },
      { verdict: 'FAIL', totalDurationMs: 400, sensorFindingCount: 2, placeholderFindingCount: 1 },
      { kind: 'attribution', rootCausePhase: 'design' },
      { verdict: 'PASS', totalDurationMs: 200, sensorFindingCount: 0, placeholderFindingCount: 0 },
    ]);
    assert.equal(summary.engine, 'node:sqlite');
    assert.equal(summary.total, 3);
    assert.equal(summary.pass, 2);
    assert.equal(summary.fail, 1);
    assert.equal(summary.rootCauseBreakdown.design, 1);
    assert.equal(summary.p95DurationMs, 400);
  } finally {
    fs.rmSync(tmpRoot, { recursive: true, force: true });
  }
});

// ---------------------------------------------------------------------------
// Phase 2: Buildless .ts Parity Tests (AC-010, AC-011)
// ---------------------------------------------------------------------------

test('AC-010/011 Parity 1: generate-sbom.ts matches generate-sbom.py CycloneDX output', () => {
  const tmpDir = makeTempDir('sbom-parity');
  try {
    const pyOut = path.join(tmpDir, 'py.cdx.json');
    const tsOut = path.join(tmpDir, 'ts.cdx.json');

    const pyRes = spawnSync(
      'python3',
      [path.join(REPO_ROOT, '.github/scripts/generate-sbom.py'), '--version', '2.1.5', '--output', pyOut],
      { cwd: REPO_ROOT, encoding: 'utf8' },
    );
    assert.equal(pyRes.status, 0, `generate-sbom.py failed: ${pyRes.stderr}`);

    const tsRes = spawnSync(
      process.execPath,
      [path.join(REPO_ROOT, '.github/scripts/generate-sbom.ts'), '--version', '2.1.5', '--output', tsOut],
      { cwd: REPO_ROOT, encoding: 'utf8' },
    );
    assert.equal(tsRes.status, 0, `generate-sbom.ts failed: ${tsRes.stderr}`);

    const pySbom = JSON.parse(fs.readFileSync(pyOut, 'utf8'));
    const tsSbom = JSON.parse(fs.readFileSync(tsOut, 'utf8'));

    assert.equal(tsSbom.bomFormat, pySbom.bomFormat);
    assert.equal(tsSbom.specVersion, pySbom.specVersion);
    assert.deepEqual(tsSbom.metadata.component, pySbom.metadata.component);
    assert.deepEqual(tsSbom.components, pySbom.components);
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
});

test('AC-010/011 Parity 2: validate-path.ts matches validate_path.py with byte-identical diagnostics', async () => {
  const { validateEvidencePath } = await import('../plugins/sdd-quality-loop/scripts/validate-path.ts');
  const tmpRoot = makeTempDir('validate-path');
  try {
    fs.mkdirSync(path.join(tmpRoot, 'evidence'), { recursive: true });
    fs.writeFileSync(path.join(tmpRoot, 'evidence', 'ok.txt'), 'pass\n', 'utf8');
    fs.writeFileSync(path.join(tmpRoot, 'evidence', 'empty.txt'), '', 'utf8');

    const pyDir = path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts');
    const cases = [
      'evidence/ok.txt',
      'evidence/empty.txt',
      'evidence/missing.txt',
      '../escape.txt',
      '/etc/passwd',
      'C:\\Windows\\win.ini',
      '',
    ];

    const pyCode = [
      'import json, sys',
      `sys.path.insert(0, ${JSON.stringify(pyDir)})`,
      'from validate_path import validate_evidence_path',
      `root = ${JSON.stringify(tmpRoot)}`,
      `cases = ${JSON.stringify(cases)}`,
      'out = []',
      'for raw in cases:',
      '    failures = []',
      '    ok = validate_evidence_path("check evidence", raw, root, failures)',
      '    out.append({"raw": raw, "ok": ok, "failures": failures})',
      'print(json.dumps(out))',
    ].join('\n');

    const pyRes = spawnSync('python3', ['-c', pyCode], { encoding: 'utf8' });
    assert.equal(pyRes.status, 0, `python validate_path runner failed: ${pyRes.stderr}`);
    const pyResults = JSON.parse(pyRes.stdout);

    for (const pyCase of pyResults) {
      const tsFailures = [];
      const tsOk = validateEvidencePath('check evidence', pyCase.raw, tmpRoot, tsFailures);
      assert.equal(tsOk, pyCase.ok, `ok mismatch for ${JSON.stringify(pyCase.raw)}`);
      assert.deepEqual(tsFailures, pyCase.failures, `diagnostic mismatch for ${JSON.stringify(pyCase.raw)}`);
    }
  } finally {
    fs.rmSync(tmpRoot, { recursive: true, force: true });
  }
});

test('AC-010/011 Parity 3: check-contract.ts matches check-contract.py on pass & fail contracts', () => {
  const tmpRoot = makeTempDir('check-contract');
  try {
    const pyScript = path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/check-contract.py');
    const tsScript = path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/check-contract.ts');

    fs.mkdirSync(path.join(tmpRoot, 'specs/demo/verification'), { recursive: true });
    fs.writeFileSync(path.join(tmpRoot, 'specs/demo/evidence.txt'), 'ok\n', 'utf8');

    const baseChecks = ['lint', 'typecheck', 'unit-tests', 'build', 'placeholder-scan', 'task-state-check'].map((id) => ({
      id,
      required: true,
      passes: true,
      evidence: 'specs/demo/evidence.txt',
    }));

    const passContract = path.join(tmpRoot, 'specs/demo/verification/T-001.contract.json');
    fs.writeFileSync(
      passContract,
      JSON.stringify({
        task_id: 'T-001',
        risk: 'low',
        required_workflow: 'standard',
        checks: baseChecks,
      }),
      'utf8',
    );
    const pyPass = spawnSync('python3', [pyScript, passContract, tmpRoot], { cwd: tmpRoot, encoding: 'utf8' });
    const tsPass = spawnSync(process.execPath, [tsScript, passContract, tmpRoot], { cwd: tmpRoot, encoding: 'utf8' });
    assert.equal(pyPass.status, 0, `pyPass failed: ${pyPass.stdout} ${pyPass.stderr}`);
    assert.equal(tsPass.status, pyPass.status, `tsPass failed: ${tsPass.stdout} ${tsPass.stderr}`);

    const failContract = path.join(tmpRoot, 'specs/demo/verification/T-002.contract.json');
    fs.writeFileSync(
      failContract,
      JSON.stringify({
        task_id: 'T-002',
        risk: 'low',
        required_workflow: 'standard',
        checks: baseChecks.map((c, idx) => (idx === 0 ? { ...c, passes: false } : c)),
      }),
      'utf8',
    );
    const pyFail = spawnSync('python3', [pyScript, failContract, tmpRoot], { cwd: tmpRoot, encoding: 'utf8' });
    const tsFail = spawnSync(process.execPath, [tsScript, failContract, tmpRoot], { cwd: tmpRoot, encoding: 'utf8' });
    assert.equal(pyFail.status, 1);
    assert.equal(tsFail.status, pyFail.status);
  } finally {
    fs.rmSync(tmpRoot, { recursive: true, force: true });
  }
});

test('AC-010/011 Parity 4: validate-concept-test.ts matches validate-concept-test.py', () => {
  const tmpRoot = makeTempDir('concept-parity');
  try {
    const pyScript = path.join(REPO_ROOT, 'plugins/sdd-domain/scripts/validate-concept-test.py');
    const tsScript = path.join(REPO_ROOT, 'plugins/sdd-domain/scripts/validate-concept-test.ts');

    // Case 1: project with no domain/ -> SKIP (exit 0) on both
    const pySkip = spawnSync('python3', [pyScript, '--root', tmpRoot, '--feature', 'demo'], { encoding: 'utf8' });
    const tsSkip = spawnSync(process.execPath, [tsScript, '--root', tmpRoot, '--feature', 'demo'], { encoding: 'utf8' });
    assert.equal(pySkip.status, 0, `pySkip failed: ${pySkip.stdout} ${pySkip.stderr}`);
    assert.equal(tsSkip.status, pySkip.status, `tsSkip failed: ${tsSkip.stdout} ${tsSkip.stderr}`);
    assert.equal(tsSkip.stdout.trim(), pySkip.stdout.trim());

    // Case 2: --require-v2 with missing domain -> BLOCK (exit 1) on both
    const pyReq = spawnSync(
      'python3',
      [pyScript, '--root', tmpRoot, '--feature', 'demo', '--require-v2'],
      { encoding: 'utf8' },
    );
    const tsReq = spawnSync(
      process.execPath,
      [tsScript, '--root', tmpRoot, '--feature', 'demo', '--require-v2'],
      { encoding: 'utf8' },
    );
    assert.equal(pyReq.status, 1);
    assert.equal(tsReq.status, pyReq.status);

    // Case 3: --probe-v1 json/md parity
    const v1Sample = JSON.stringify({ schema: 'concept-test/v1', feature: 'demo' });
    const pyProbe = spawnSync('python3', [pyScript, '--probe-v1', 'json'], { input: v1Sample, encoding: 'utf8' });
    const tsProbe = spawnSync(process.execPath, [tsScript, '--probe-v1', 'json'], { input: v1Sample, encoding: 'utf8' });
    assert.equal(pyProbe.status, 0);
    assert.equal(tsProbe.status, 0);
    assert.equal(tsProbe.stdout.trim(), pyProbe.stdout.trim());
  } finally {
    fs.rmSync(tmpRoot, { recursive: true, force: true });
  }
});

test('AC-010/011 Parity 5: render-agent-frontmatter.ts --check matches render-agent-frontmatter.sh --check', () => {
  const shRes = spawnSync('bash', [path.join(REPO_ROOT, 'render-agent-frontmatter.sh'), '--check'], {
    cwd: REPO_ROOT,
    encoding: 'utf8',
  });
  const tsRes = spawnSync(
    process.execPath,
    [path.join(REPO_ROOT, 'scripts/render-agent-frontmatter.ts'), '--check'],
    { cwd: REPO_ROOT, encoding: 'utf8' },
  );
  assert.equal(shRes.status, 0, `render-agent-frontmatter.sh failed: ${shRes.stderr}`);
  assert.equal(tsRes.status, 0, `render-agent-frontmatter.ts failed: ${tsRes.stderr}`);
});

// ---------------------------------------------------------------------------
// Phase 3: MCP SDK v2 Migration & --permission Security Boundaries (AC-012..016)
// ---------------------------------------------------------------------------

test('AC-012/013/014: MCP packages use @modelcontextprotocol/server v2 with cacheHints and pass stdio handshake', async () => {
  for (const pkgName of ['sdd-forge-mcp', 'ci-mcp']) {
    const pkg = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, 'mcp', pkgName, 'package.json'), 'utf8'));
    assert.ok(
      typeof pkg.dependencies?.['@modelcontextprotocol/server'] === 'string' &&
        pkg.dependencies['@modelcontextprotocol/server'].startsWith('^2.'),
      `${pkgName} must depend on @modelcontextprotocol/server ^2.x`,
    );
    assert.equal(pkg.dependencies?.['@modelcontextprotocol/sdk'], undefined, `${pkgName} must not depend on v1 sdk`);

    const serverSrc = fs.readFileSync(path.join(REPO_ROOT, 'mcp', pkgName, 'src/server.ts'), 'utf8');
    assert.match(serverSrc, /cacheHints:/, `${pkgName}/src/server.ts must configure MCP v2 cacheHints`);
  }

  // Real stdio JSON-RPC initialize + tools/list handshake on bundled sdd-forge-mcp/dist/index.js
  const child = spawn(
    process.execPath,
    [path.join(REPO_ROOT, 'mcp/sdd-forge-mcp/dist/index.js'), '--root', REPO_ROOT],
    { stdio: ['pipe', 'pipe', 'pipe'] },
  );

  try {
    const responses = [];
    let buffer = '';
    const waitForCount = (count) =>
      new Promise((resolve, reject) => {
        const timer = setTimeout(() => reject(new Error(`Timed out waiting for ${count} JSON-RPC responses`)), 10_000);
        const onData = (chunk) => {
          buffer += chunk.toString('utf8');
          const lines = buffer.split('\n');
          buffer = lines.pop() ?? '';
          for (const line of lines) {
            if (!line.trim()) continue;
            responses.push(JSON.parse(line));
          }
          if (responses.length >= count) {
            clearTimeout(timer);
            child.stdout.off('data', onData);
            resolve();
          }
        };
        child.stdout.on('data', onData);
      });

    const initMsg = {
      jsonrpc: '2.0',
      id: 1,
      method: 'initialize',
      params: {
        protocolVersion: '2025-11-25',
        capabilities: {},
        clientInfo: { name: 'node26-test', version: '1.0.0' },
      },
    };
    const listMsg = {
      jsonrpc: '2.0',
      id: 2,
      method: 'tools/list',
      params: {},
    };
    child.stdin.write(`${JSON.stringify(initMsg)}\n`);
    await waitForCount(1);
    child.stdin.write(`${JSON.stringify({ jsonrpc: '2.0', method: 'notifications/initialized' })}\n`);
    child.stdin.write(`${JSON.stringify(listMsg)}\n`);
    await waitForCount(2);

    const initResp = responses.find((r) => r.id === 1);
    const listResp = responses.find((r) => r.id === 2);
    assert.equal(initResp?.result?.serverInfo?.name, 'sdd-forge-mcp');
    const toolNames = (listResp?.result?.tools ?? []).map((t) => t.name).sort();
    assert.deepEqual(toolNames, [
      'sdd_dashboard_snapshot',
      'sdd_feature_state',
      'sdd_gate_audit',
      'sdd_project_overview',
    ]);
  } finally {
    child.stdin.end();
    child.kill();
  }
});

test('AC-015/016: role Node config profiles and real --permission security boundary enforcement', () => {
  for (const rel of [
    'plugins/sdd-quality-loop/config/readonly.node.json',
    'plugins/sdd-quality-loop/config/hook.node.json',
  ]) {
    const cfg = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, rel), 'utf8'));
    assert.equal(cfg.nodeOptions?.permission, true, `${rel} must enable permission`);
    assert.equal(
      cfg.nodeOptions?.['disallow-code-generation-from-strings'],
      true,
      `${rel} must disallow code generation from strings`,
    );
    assert.equal(cfg.nodeOptions?.['disable-proto'], 'throw', `${rel} must set disable-proto=throw`);
  }

  const securityFlags = [
    '--permission',
    `--allow-fs-read=${REPO_ROOT}`,
    '--disallow-code-generation-from-strings',
    '--disable-proto=throw',
  ];

  // Positive 1: sdd-doctor runs cleanly under strict read-only --permission
  const doctorRes = spawnSync(
    process.execPath,
    [
      ...securityFlags,
      path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/sdd-doctor.mjs'),
      '--root',
      REPO_ROOT,
      '--json',
    ],
    { cwd: REPO_ROOT, encoding: 'utf8', timeout: 15_000 },
  );
  assert.equal(doctorRes.status, 0, `sdd-doctor failed under --permission: ${doctorRes.stderr}`);
  const doctorJson = JSON.parse(doctorRes.stdout);
  assert.equal(doctorJson.schema, 'sdd-doctor/v1');

  // Positive 2: sdd-forge-mcp --warmup runs cleanly under strict read-only --permission
  const mcpWarmup = spawnSync(
    process.execPath,
    [...securityFlags, path.join(REPO_ROOT, 'mcp/sdd-forge-mcp/dist/index.js'), '--warmup'],
    { cwd: REPO_ROOT, encoding: 'utf8', timeout: 15_000 },
  );
  assert.equal(mcpWarmup.status, 0, `sdd-forge-mcp --warmup failed under --permission: ${mcpWarmup.stderr}`);

  // Negative 1: unauthorized filesystem write must fail with ERR_ACCESS_DENIED
  const writeAttempt = spawnSync(
    process.execPath,
    [
      ...securityFlags,
      '-e',
      `import('node:fs').then(fs => fs.writeFileSync(${JSON.stringify(path.join(os.tmpdir(), 'sdd-denied.txt'))}, 'x'))`,
    ],
    { cwd: REPO_ROOT, encoding: 'utf8' },
  );
  assert.notEqual(writeAttempt.status, 0);
  assert.match(writeAttempt.stderr, /ERR_ACCESS_DENIED/);

  // Negative 2: unauthorized child_process spawn must fail with ERR_ACCESS_DENIED
  const spawnAttempt = spawnSync(
    process.execPath,
    [
      ...securityFlags,
      '-e',
      `import('node:child_process').then(cp => cp.execFileSync(process.execPath, ['-v']))`,
    ],
    { cwd: REPO_ROOT, encoding: 'utf8' },
  );
  assert.notEqual(spawnAttempt.status, 0);
  assert.match(spawnAttempt.stderr, /ERR_ACCESS_DENIED/);

  // Negative 3: eval / Function code generation must fail with EvalError
  const evalAttempt = spawnSync(
    process.execPath,
    [...securityFlags, '-e', `eval('1 + 1')`],
    { cwd: REPO_ROOT, encoding: 'utf8' },
  );
  assert.notEqual(evalAttempt.status, 0);
  assert.match(evalAttempt.stderr, /EvalError|Code generation from strings disallowed/);

  // Negative 4: __proto__ access must throw TypeError under --disable-proto=throw
  const protoAttempt = spawnSync(
    process.execPath,
    [...securityFlags, '-e', `const x = {}; void x.__proto__;`],
    { cwd: REPO_ROOT, encoding: 'utf8' },
  );
  assert.notEqual(protoAttempt.status, 0);
  assert.match(protoAttempt.stderr, /TypeError|__proto__/);
});
