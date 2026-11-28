import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';

import { inspectCompileCache, warmupCompileCache } from '../plugins/sdd-quality-loop/scripts/v2/compile-cache.mjs';
import { summarizeMetricsWithSqlite } from '../plugins/sdd-quality-loop/scripts/v2/factory-metrics.mjs';
import {
  collectFilesWithGlob,
  readGitBlobsBatch,
  readGitStatusPorcelainV2,
  scanPlaceholdersAsync,
} from '../plugins/sdd-quality-loop/scripts/v2/run-sdd-gate.mjs';
import { CHANNELS, profilePhase, recordStartup, subscribeProfile } from '../plugins/sdd-quality-loop/scripts/v2/runtime-profile.mjs';
import { openScanCache } from '../plugins/sdd-quality-loop/scripts/v2/scan-cache.mjs';
import { collectRuntimeDiagnostics, runDoctor } from '../plugins/sdd-quality-loop/scripts/v2/sdd-doctor.mjs';
import { acquireTaskLockHandle, epochMsToIso, getLockStatus, nowEpochMs, parseIsoEpochMs } from '../plugins/sdd-quality-loop/scripts/v2/task-lock.mjs';
import { escapeRegExp, sha256Text } from '../plugins/sdd-quality-loop/scripts/v2/v2-pure-lib.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..');

function detectConfigFileFlag() {
  const help = spawnSync(process.execPath, ['--help'], { encoding: 'utf8' }).stdout || '';
  if (/(^|\s)--config-file=/.test(help)) return '--config-file';
  return '--experimental-config-file';
}

describe('ADR-0055: Node.js 26.13+, TypeScript 7.0 & MCP SDK v2 unified optimization', () => {
  it('AC-001: CI workflows and MCP packages target Node.js 26.13.0+', () => {
    for (const rel of [
      '.github/workflows/test.yml',
      '.github/workflows/release.yml',
      '.github/workflows/sdd-guardrails.yml',
    ]) {
      const text = fs.readFileSync(path.join(REPO_ROOT, rel), 'utf8');
      const versions = [...text.matchAll(/node-version:\s*["']?([^"'\s#]+)["']?/g)].map((m) => m[1]);
      assert.ok(versions.length > 0, `${rel} must declare node-version`);
      for (const v of versions) {
        assert.equal(v, '26.13.0', `${rel} has unexpected node-version: ${v}`);
      }
    }
    for (const pkg of ['sdd-forge-mcp', 'ci-mcp', 'local-env-mcp']) {
      const json = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, 'mcp', pkg, 'package.json'), 'utf8'));
      assert.equal(json.engines?.node, '>=26.13.0', `mcp/${pkg}/package.json engines.node mismatch`);
    }
    const localEnvPkg = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, 'mcp/local-env-mcp/package.json'), 'utf8'));
    assert.match(localEnvPkg.description, /DEPRECATED/i);
  });

  it('AC-002: root tsconfig.json enables TS 7.0 erasableSyntaxOnly + noEmit + strict and passes typecheck', () => {
    const cfg = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, 'tsconfig.json'), 'utf8'));
    assert.equal(cfg.compilerOptions.erasableSyntaxOnly, true);
    assert.equal(cfg.compilerOptions.noEmit, true);
    assert.equal(cfg.compilerOptions.strict, true);
    assert.equal(cfg.compilerOptions.allowImportingTsExtensions, true);

    const testYml = fs.readFileSync(path.join(REPO_ROOT, '.github/workflows/test.yml'), 'utf8');
    assert.match(testYml, /tsc --noEmit -p tsconfig\.json/);

    const tscBin = path.join(
      REPO_ROOT,
      'mcp/sdd-forge-mcp/node_modules/.bin',
      process.platform === 'win32' ? 'tsc.cmd' : 'tsc',
    );
    if (fs.existsSync(tscBin)) {
      const res = spawnSync(tscBin, ['--noEmit', '-p', path.join(REPO_ROOT, 'tsconfig.json')], {
        cwd: REPO_ROOT,
        encoding: 'utf8',
      });
      assert.equal(res.status, 0, `TS 7.0 typecheck failed:\n${res.stdout}\n${res.stderr}`);
    }
  });

  it('AC-003: runtime-profile.mjs publishes to all 3 diagnostics_channel channels', () => {
    const events = [];
    const unsubscribe = subscribeProfile((msg, ch) => events.push({ ch, msg }));
    try {
      recordStartup('test-unit');
      const v1 = profilePhase('scan', 'unit-scan', () => 42);
      const v2 = profilePhase('exec', 'unit-exec', () => 'ok');
      assert.equal(v1, 42);
      assert.equal(v2, 'ok');
    } finally {
      unsubscribe();
    }
    const seen = new Set(events.map((e) => e.ch));
    assert.equal(seen.has(CHANNELS.startup), true);
    assert.equal(seen.has(CHANNELS.scan), true);
    assert.equal(seen.has(CHANNELS.exec), true);
  });

  it('AC-004: bench-runtime.ts emits benchmark JSON and test.yml isolates coverage with NODE_DISABLE_COMPILE_CACHE=1', () => {
    const testYml = fs.readFileSync(path.join(REPO_ROOT, '.github/workflows/test.yml'), 'utf8');
    assert.match(testYml, /NODE_DISABLE_COMPILE_CACHE=1/);
    assert.match(testYml, /scripts\/bench-runtime\.ts/);

    const res = spawnSync(process.execPath, [path.join(REPO_ROOT, 'scripts/bench-runtime.ts'), '--iterations', '1', '--json'], {
      cwd: REPO_ROOT,
      encoding: 'utf8',
    });
    assert.equal(res.status, 0, `bench-runtime.ts failed:\n${res.stderr}`);
    const report = JSON.parse(res.stdout);
    assert.equal(report.schema, 'sdd-runtime-bench/v1');
    assert.equal(report.startup.length, 3);
    assert.ok(report.sha256.cryptoHashMs >= 0);
    assert.ok(report.globScan.fileCount > 0);
  });

  it('AC-005 & AC-006: two-stage portable Compile Cache warmup, installers, payload, and all 4 hook manifests', () => {
    const tmpCache = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-cc-test-'));
    try {
      const summary = warmupCompileCache({ root: REPO_ROOT, cacheDir: tmpCache });
      assert.equal(summary.ok, true, JSON.stringify(summary.results, null, 2));
      const info = inspectCompileCache(tmpCache);
      assert.equal(info.exists, true);
      assert.ok(info.fileCount > 0, 'compile-cache warmup must produce cache entries');
    } finally {
      fs.rmSync(tmpCache, { recursive: true, force: true });
    }

    const payload = fs.readFileSync(path.join(REPO_ROOT, 'install-payload.txt'), 'utf8');
    assert.match(payload, /^\.sdd-compile-cache\/$/m);
    assert.match(payload, /^scripts\/render-agent-frontmatter\.ts$/m);

    const releaseYml = fs.readFileSync(path.join(REPO_ROOT, '.github/workflows/release.yml'), 'utf8');
    assert.match(releaseYml, /compile-cache\.mjs/);
    assert.match(releaseYml, /node \.github\/scripts\/generate-sbom\.ts/);
    assert.doesNotMatch(releaseYml, /generate-sbom\.py/);

    const installSh = fs.readFileSync(path.join(REPO_ROOT, 'install.sh'), 'utf8');
    const installPs1 = fs.readFileSync(path.join(REPO_ROOT, 'install.ps1'), 'utf8');
    assert.match(installSh, /compile-cache\.mjs/);
    assert.match(installPs1, /compile-cache\.mjs/);

    for (const rel of [
      'plugins/sdd-quality-loop/hooks/claude-hooks.json',
      'plugins/sdd-quality-loop/hooks/codex-hooks.json',
      'plugins/sdd-quality-loop/hooks/copilot-hooks.json',
      'plugins/sdd-quality-loop/gemini/hooks/hooks.json',
    ]) {
      const raw = fs.readFileSync(path.join(REPO_ROOT, rel), 'utf8');
      assert.match(raw, /NODE_COMPILE_CACHE/);
      assert.match(raw, /NODE_COMPILE_CACHE_PORTABLE/);
      assert.match(raw, /NODE_COMPILE_CACHE_READONLY/);
      assert.match(raw, /--config-file=/);
      assert.match(raw, /hook\.node\.json/);
      assert.match(raw, /--disallow-code-generation-from-strings/);
      assert.match(raw, /--env-file-if-exists=\.sdd\/env/);
    }
  });

  it('AC-007: sdd-doctor --rebuild-cache and runtime/cache/git diagnostics keep summary.ng === 0', () => {
    const tmpCache = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-doctor-cache-'));
    try {
      const res = spawnSync(
        process.execPath,
        [
          path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/sdd-doctor.mjs'),
          '--root',
          REPO_ROOT,
          '--rebuild-cache',
          '--cache-dir',
          tmpCache,
          '--json',
        ],
        { cwd: REPO_ROOT, encoding: 'utf8' },
      );
      assert.equal(res.status, 0, res.stderr);
      const rebuilt = JSON.parse(res.stdout);
      assert.equal(rebuilt.ok, true);
      assert.ok(rebuilt.inspection.fileCount > 0);

      const diag = collectRuntimeDiagnostics(REPO_ROOT, { nodeVersion: '24.13.0', cacheDir: path.join(tmpCache, 'missing') });
      assert.ok(diag.findings.some((f) => f.category === 'runtime-node-version'));
      assert.ok(diag.findings.some((f) => f.category === 'compile-cache'));

      const report = runDoctor({ root: REPO_ROOT });
      assert.equal(report.summary.ng, 0, JSON.stringify(report.findings, null, 2));
      assert.ok(report.runtime && typeof report.runtime.nodeVersion === 'string');
    } finally {
      fs.rmSync(tmpCache, { recursive: true, force: true });
    }
  });

  it('AC-008: v2-readonly-core.ts stays pure (zero fs/env/writes) and is imported directly by sdd-forge-mcp', () => {
    const coreTsPath = path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/v2-readonly-core.ts');
    const src = fs.readFileSync(coreTsPath, 'utf8');
    const stripped = src.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/.*$/gm, '');
    assert.doesNotMatch(stripped, /from\s+['"]node:fs['"]/);
    assert.doesNotMatch(stripped, /\bprocess\.env\b/);
    assert.doesNotMatch(stripped, /\bwriteFileSync\b|\bappendFileSync\b|\bmkdirSync\b|\brmSync\b/);

    for (const rel of [
      'mcp/sdd-forge-mcp/src/next-command.ts',
      'mcp/sdd-forge-mcp/src/pre-approval-review.ts',
      'mcp/sdd-forge-mcp/src/tools/core.ts',
      'mcp/sdd-forge-mcp/src/tools/v2.ts',
    ]) {
      const mcpSrc = fs.readFileSync(path.join(REPO_ROOT, rel), 'utf8');
      assert.match(mcpSrc, /v2-readonly-core\.ts['"]/);
    }
  });

  it('AC-009: v2-pure-lib sha256Text and escapeRegExp match native primitives', () => {
    const expected = crypto.createHash('sha256').update('hello\nworld', 'utf8').digest('hex');
    assert.equal(sha256Text('hello\r\nworld'), expected);
    const re = new RegExp(`^${escapeRegExp('a.b+c*(d)?[e]{1}$')}$`);
    assert.equal(re.test('a.b+c*(d)?[e]{1}$'), true);
    assert.equal(re.test('axb+c*(d)?[e]{1}$'), false);
  });

  it('AC-010 & AC-011: SQLite scan cache, fs.promises.glob, git porcelain=v2 & cat-file --batch, and node validate-concept-test.ts', async () => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-gate-p2-'));
    try {
      execFileSync('git', ['init', '-q'], { cwd: tmp });
      execFileSync('git', ['config', 'user.name', 'Test'], { cwd: tmp });
      execFileSync('git', ['config', 'user.email', 'test@example.invalid'], { cwd: tmp });
      fs.mkdirSync(path.join(tmp, 'src'), { recursive: true });
      const marker = ['T', 'O', 'D', 'O'].join('');
      fs.writeFileSync(path.join(tmp, 'src/clean.js'), 'export const x = 1;\n', 'utf8');
      fs.writeFileSync(path.join(tmp, 'src/dirty.js'), `// ${marker}: fix me\nexport const y = 2;\n`, 'utf8');
      execFileSync('git', ['add', 'src/clean.js'], { cwd: tmp });
      execFileSync('git', ['commit', '-qm', 'init'], { cwd: tmp });
      fs.writeFileSync(path.join(tmp, 'src/clean.js'), 'export const x = 2;\n', 'utf8');

      // git status --porcelain=v2 -z
      const changed = readGitStatusPorcelainV2(tmp);
      assert.ok(changed.includes('src/clean.js'));
      assert.ok(changed.includes('src/dirty.js'));

      // git cat-file --batch
      const oid = execFileSync('git', ['rev-parse', 'HEAD:src/clean.js'], { cwd: tmp, encoding: 'utf8' }).trim();
      const blobs = readGitBlobsBatch(tmp, [oid]);
      assert.equal(blobs.get(oid), 'export const x = 1;\n');

      // fs.promises.glob
      const globbed = await collectFilesWithGlob(tmp, ['src/*.js']);
      assert.deepEqual(globbed, ['src/clean.js', 'src/dirty.js']);

      // SQLite incremental scan cache + async bounded scanner
      const cache = openScanCache(tmp);
      try {
        assert.equal(cache.mode, 'sqlite-file');
        const first = await scanPlaceholdersAsync(tmp, ['src/clean.js', 'src/dirty.js'], { scanCache: cache });
        assert.equal(first.passed, false);
        assert.equal(first.findings.length, 1);
        const stat = fs.statSync(path.join(tmp, 'src/dirty.js'));
        const hit = cache.get('src/dirty.js', 'placeholders:v1', stat.mtimeMs, stat.size);
        assert.ok(Array.isArray(hit) && hit.length === 1);
      } finally {
        cache.close();
      }

      // run-sdd-gate invokes validate-concept-test.ts via node (no pwsh/sh)
      const gateSrc = fs.readFileSync(path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/run-sdd-gate.mjs'), 'utf8');
      assert.match(gateSrc, /validate-concept-test\.ts/);
      assert.doesNotMatch(gateSrc, /validate-concept-test\.\$\{win/);
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
    }
  });

  it('AC-012: task-lock Symbol.dispose handle & Temporal helpers + factory-metrics SQLite p95', () => {
    const now = nowEpochMs();
    const iso = epochMsToIso(now);
    assert.ok(Math.abs(parseIsoEpochMs(iso) - now) <= 1000);

    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-lock-dispose-'));
    try {
      const handle = acquireTaskLockHandle({ feature: 'demo', taskId: 'T-001', projectRoot: tmp, owner: 'unit-test' });
      assert.equal(handle.acquired, true);
      assert.equal(getLockStatus({ feature: 'demo', taskId: 'T-001', projectRoot: tmp }).locked, true);
      handle[Symbol.dispose]();
      assert.equal(getLockStatus({ feature: 'demo', taskId: 'T-001', projectRoot: tmp }).locked, false);
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
    }

    const runs = Array.from({ length: 20 }, (_, i) => ({
      verdict: i % 4 === 0 ? 'FAIL' : 'PASS',
      commandDurationMs: (i + 1) * 100,
      sensorFindingCount: 1,
      placeholderFindingCount: 0,
    }));
    const agg = summarizeMetricsWithSqlite(runs);
    assert.equal(agg.engine, 'sqlite');
    assert.equal(agg.total, 20);
    assert.equal(agg.pass, 15);
    assert.equal(agg.fail, 5);
    assert.equal(agg.p95DurationMs, 2000);
    assert.equal(agg.sensorFindingsTotal, 20);
  });

  it('AC-013: all 5 zero-dependency buildless .ts ports run directly on Node.js', () => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-ts-ports-'));
    try {
      // 1. validate-path.ts
      fs.mkdirSync(path.join(tmp, 'specs/demo'), { recursive: true });
      fs.writeFileSync(path.join(tmp, 'specs/demo/tasks.md'), '# Tasks\n', 'utf8');
      const vpOk = spawnSync(
        process.execPath,
        [path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/validate-path.ts'), '--root', tmp, 'specs/demo/tasks.md'],
        { encoding: 'utf8' },
      );
      assert.equal(vpOk.status, 0, vpOk.stderr);
      const vpBad = spawnSync(
        process.execPath,
        [path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/validate-path.ts'), '--root', tmp, '../escape.txt'],
        { encoding: 'utf8' },
      );
      assert.notEqual(vpBad.status, 0);

      // 2. generate-sbom.ts
      const sbomOut = path.join(tmp, 'sbom.cdx.json');
      const sbomRes = spawnSync(
        process.execPath,
        [
          path.join(REPO_ROOT, '.github/scripts/generate-sbom.ts'),
          '--source-root',
          REPO_ROOT,
          '--version=v2.1.5',
          '--repo',
          'aharada54914/sdd-forge',
          '--output',
          sbomOut,
        ],
        { encoding: 'utf8' },
      );
      assert.equal(sbomRes.status, 0, sbomRes.stderr);
      const sbom = JSON.parse(fs.readFileSync(sbomOut, 'utf8'));
      assert.equal(sbom.bomFormat, 'CycloneDX');

      // 3. check-contract.ts
      const contractRes = spawnSync(
        process.execPath,
        [path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/check-contract.ts'), '--help'],
        { encoding: 'utf8' },
      );
      assert.ok([0, 2].includes(contractRes.status));

      // 4. validate-concept-test.ts (SKIP when no domain/)
      const ctRes = spawnSync(
        process.execPath,
        [
          path.join(REPO_ROOT, 'plugins/sdd-domain/scripts/validate-concept-test.ts'),
          '--root',
          tmp,
          '--feature',
          'demo',
        ],
        { encoding: 'utf8' },
      );
      assert.equal(ctRes.status, 0, ctRes.stderr);
      assert.equal(ctRes.stdout.trim(), 'SKIP');

      // 5. render-agent-frontmatter.ts
      const renderRes = spawnSync(
        process.execPath,
        [path.join(REPO_ROOT, 'scripts/render-agent-frontmatter.ts'), '--help'],
        { encoding: 'utf8' },
      );
      assert.ok([0, 2].includes(renderRes.status));
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
    }
  });

  it('AC-014 & AC-015: MCP SDK v2 migration, cacheHints, --warmup, and direct shared/diagnostics-core.ts', () => {
    for (const pkg of ['sdd-forge-mcp', 'ci-mcp']) {
      const json = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, 'mcp', pkg, 'package.json'), 'utf8'));
      assert.ok(json.dependencies['@modelcontextprotocol/server']?.startsWith('^2.4'), `mcp/${pkg} must use SDK v2 server`);
      assert.equal(json.dependencies['@modelcontextprotocol/sdk'], undefined, `mcp/${pkg} must not depend on SDK v1`);
      const serverTs = fs.readFileSync(path.join(REPO_ROOT, 'mcp', pkg, 'src/server.ts'), 'utf8');
      assert.match(serverTs, /cacheHints/);
      const warmRes = spawnSync(process.execPath, [path.join(REPO_ROOT, 'mcp', pkg, 'dist/index.js'), '--warmup'], {
        encoding: 'utf8',
      });
      assert.equal(warmRes.status, 0, `mcp/${pkg} --warmup failed: ${warmRes.stderr}`);
    }

    assert.equal(fs.existsSync(path.join(REPO_ROOT, 'mcp/shared/sync-diagnostics.py')), false);
    assert.equal(fs.existsSync(path.join(REPO_ROOT, 'mcp/ci-mcp/src/diagnostics-core.ts')), false);
    assert.equal(fs.existsSync(path.join(REPO_ROOT, 'mcp/local-env-mcp/src/diagnostics-core.ts')), false);
    const sharedDiag = fs.readFileSync(path.join(REPO_ROOT, 'mcp/shared/diagnostics-core.ts'), 'utf8');
    assert.match(sharedDiag, /RegExp/);
  });

  it('AC-016: role permission config files boot cleanly on Node and enforce real read-only / hook-write / no-exec boundaries', () => {
    const flag = detectConfigFileFlag();
    const readonlyCfg = path.join(REPO_ROOT, 'plugins/sdd-quality-loop/config/readonly.node.json');
    const hookCfg = path.join(REPO_ROOT, 'plugins/sdd-quality-loop/config/hook.node.json');

    // 1. readonly.node.json allows sdd-doctor.mjs read-only run
    const doctorRes = spawnSync(
      process.execPath,
      [
        `${flag}=${readonlyCfg}`,
        '--disallow-code-generation-from-strings',
        '--env-file-if-exists=.sdd/env',
        path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/sdd-doctor.mjs'),
        '--root',
        REPO_ROOT,
        '--json',
      ],
      { cwd: REPO_ROOT, encoding: 'utf8' },
    );
    assert.equal(doctorRes.status, 0, `readonly sdd-doctor failed:\n${doctorRes.stderr}`);
    const parsedDoctor = JSON.parse(doctorRes.stdout);
    assert.equal(parsedDoctor.summary.ng, 0);

    // 2. readonly.node.json denies fs write & child_process & eval
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-perm-test-'));
    try {
      const denyWrite = spawnSync(
        process.execPath,
        [
          `${flag}=${readonlyCfg}`,
          '--disallow-code-generation-from-strings',
          '-e',
          `import fs from "node:fs"; fs.writeFileSync(${JSON.stringify(path.join(tmp, 'blocked.txt'))}, "x");`,
        ],
        { cwd: tmp, encoding: 'utf8' },
      );
      assert.notEqual(denyWrite.status, 0);
      assert.match(denyWrite.stderr, /ERR_ACCESS_DENIED/);

      const denyExec = spawnSync(
        process.execPath,
        [
          `${flag}=${readonlyCfg}`,
          '--disallow-code-generation-from-strings',
          '-e',
          'import { spawnSync } from "node:child_process"; spawnSync(process.execPath, ["-v"]);',
        ],
        { cwd: tmp, encoding: 'utf8' },
      );
      assert.notEqual(denyExec.status, 0);
      assert.match(denyExec.stderr, /ERR_ACCESS_DENIED/);

      const denyEval = spawnSync(
        process.execPath,
        [`${flag}=${readonlyCfg}`, '--disallow-code-generation-from-strings', '-e', 'eval("1+1")'],
        { cwd: tmp, encoding: 'utf8' },
      );
      assert.notEqual(denyEval.status, 0);
      assert.match(denyEval.stderr, /Code generation from strings disallowed/);

      // 3. hook.node.json allows writing .sdd/drift-events.jsonl while denying writes elsewhere & child_process
      fs.mkdirSync(path.join(tmp, '.sdd'), { recursive: true });
      const allowDrift = spawnSync(
        process.execPath,
        [
          `${flag}=${hookCfg}`,
          '--disallow-code-generation-from-strings',
          '-e',
          'import fs from "node:fs"; fs.appendFileSync(".sdd/drift-events.jsonl", "{\\"ok\\":true}\\n");',
        ],
        { cwd: tmp, encoding: 'utf8' },
      );
      assert.equal(allowDrift.status, 0, allowDrift.stderr);

      const denyOther = spawnSync(
        process.execPath,
        [
          `${flag}=${hookCfg}`,
          '--disallow-code-generation-from-strings',
          '-e',
          'import fs from "node:fs"; fs.writeFileSync("other.txt", "nope");',
        ],
        { cwd: tmp, encoding: 'utf8' },
      );
      assert.notEqual(denyOther.status, 0);
      assert.match(denyOther.stderr, /ERR_ACCESS_DENIED/);
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
    }
  });

  it('AC-017: retired legacy wrappers and py-dispatch scripts are removed', () => {
    const retired = [
      '.github/scripts/generate-sbom.py',
      'render-agent-frontmatter.sh',
      'render-agent-frontmatter.ps1',
      'mcp/shared/sync-diagnostics.py',
      'mcp/ci-mcp/src/diagnostics-core.ts',
      'mcp/local-env-mcp/src/diagnostics-core.ts',
      'plugins/sdd-quality-loop/scripts/validate_path.py',
      'plugins/sdd-quality-loop/scripts/check-contract.py',
      'plugins/sdd-quality-loop/scripts/check-contract.sh',
      'plugins/sdd-quality-loop/scripts/check-contract.ps1',
      'plugins/sdd-domain/scripts/validate-concept-test.sh',
      'plugins/sdd-domain/scripts/validate-concept-test.ps1',
      'plugins/sdd-quality-loop/scripts/lib/py-dispatch.sh',
      'plugins/sdd-quality-loop/scripts/lib/py-dispatch.ps1',
    ];
    for (const rel of retired) {
      assert.equal(fs.existsSync(path.join(REPO_ROOT, rel)), false, `${rel} must be removed in Phase 3`);
    }
  });
});
