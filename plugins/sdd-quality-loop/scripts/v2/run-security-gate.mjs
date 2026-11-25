#!/usr/bin/env node
/**
 * run-security-gate.mjs — Fixed-Allowlist Security Gate with Secret Masking & Slopsquatting Detection (ADR-0054 T-007).
 *
 * Security invariants (REQ-009 / SELF-REQ-004 / AC-008):
 *   - Only adapters in `VALID_SECURITY_ADAPTERS` may execute.
 *   - Arbitrary `command` / `shell` keys in `guardrails.yaml` are rejected with exit code 2.
 *   - External binaries are invoked via `execFileSync(..., { shell: false })` and `.cmd`/`.bat`
 *     wrappers are strictly rejected (Windows CVE-2024-27980 safe).
 *   - All detected secrets are masked before output; raw secret values never appear in stdout/logs.
 *   - CI, strict mode and high-risk paths fail closed when an enabled adapter cannot complete.
 *
 * Exit codes:
 *   0 — PASS (or shadow/warn/off mode)
 *   1 — Strict mode security finding detected
 *   2 — Tool / config / unallowed adapter / CI missing binary error
 */
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';
import {
  VALID_SECURITY_ADAPTERS,
  isMainModule,
  sanitizeRelPath,
  globToRegExp,
  createFsReadonlyIo,
  resolveExplicitOrAutoRoot,
  validateGuardrailsFile,
} from './guardrails-lib.mjs';

const IGNORED_DIRS = new Set(['.git', 'node_modules', 'dist', 'dist-test', 'build', '.next', '.worktrees']);
const SCANNABLE_EXT_RE = /\.(?:m?js|cjs|tsx?|py|sh|ps1|ya?ml|json|env|toml|ini|conf|md)$/i;
const WINDOWS_WRAPPER_RE = /\.(?:cmd|bat)$/i;

const SECRET_RULES = [
  { id: 'aws-access-key', re: /\bAKIA[0-9A-Z]{16}\b/g, message: 'AWS Access Key ID らしきトークンが検出されました' },
  { id: 'github-pat', re: /\bgh[pousr]_[A-Za-z0-9]{36}\b/g, message: 'GitHub Personal Access Token らしき文字列が検出されました' },
  { id: 'generic-sk-token', re: /\bsk-[A-Za-z0-9_-]{24,}\b/g, message: 'API Secret Key (sk-...) らしき文字列が検出されました' },
  { id: 'private-key-pem', re: /-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----/g, message: '秘密鍵 (PEM ヘッダ) が検出されました' },
  { id: 'slack-token', re: /\bxox[baprs]-[0-9A-Za-z-]{10,}\b/g, message: 'Slack トークンらしき文字列が検出されました' },
];

const POPULAR_PACKAGES = [
  'express', 'lodash', 'react', 'typescript', 'axios', 'zod', 'esbuild',
  'vitest', 'eslint', 'prettier', 'chalk', 'commander', 'dotenv',
  'requests', 'numpy', 'pandas', 'pydantic', 'fastapi', 'pytest', 'flask', 'django',
];

export function maskSecret(raw) {
  const s = String(raw || '');
  if (s.length <= 8) return '****';
  return `${s.slice(0, 4)}****${s.slice(-2)}`;
}

function maskEvidence(value) {
  return SECRET_RULES.reduce((masked, rule) => masked.replace(new RegExp(rule.re), maskSecret), value);
}

export function levenshtein(a, b) {
  const m = a.length;
  const n = b.length;
  const dp = Array.from({ length: m + 1 }, () => new Array(n + 1).fill(0));
  for (let i = 0; i <= m; i += 1) dp[i][0] = i;
  for (let j = 0; j <= n; j += 1) dp[0][j] = j;
  for (let i = 1; i <= m; i += 1) {
    for (let j = 1; j <= n; j += 1) {
      const cost = a[i - 1] === b[j - 1] ? 0 : 1;
      dp[i][j] = Math.min(dp[i - 1][j] + 1, dp[i][j - 1] + 1, dp[i - 1][j - 1] + cost);
    }
  }
  return dp[m][n];
}

export function resolveSafeExternalCommand(adapter, projectRoot, binaryOverride = null) {
  if (!VALID_SECURITY_ADAPTERS.has(adapter)) {
    throw new Error(`Unallowed security adapter: ${adapter}`);
  }
  const rules = fileURLToPath(new URL('../../rules/security.yml', import.meta.url));
  const commands = {
    semgrep: ['scan', '--config', rules, '--error', '--strict', '--metrics=off', '--quiet', projectRoot],
    gitleaks: ['dir', '--redact=100', '--exit-code=42', projectRoot],
    trufflehog: ['filesystem', '--fail', '--no-verification', '--no-update', '--fail-on-scan-errors', projectRoot],
    socket: ['scan', 'create', '--report', '--json', '--no-interactive', projectRoot],
    codeql: ['database', 'create', '--language=javascript-typescript', '--build-mode=none', `--source-root=${projectRoot}`],
  };
  if (!Object.hasOwn(commands, adapter)) return null;
  const spec = { bin: binaryOverride || adapter, args: commands[adapter] };
  if (WINDOWS_WRAPPER_RE.test(spec.bin)) {
    throw new Error(`Refusing to execute Windows batch wrapper (.cmd/.bat) without shell: ${spec.bin}`);
  }
  return { bin: spec.bin, args: spec.args, options: { shell: false, encoding: 'utf8', cwd: projectRoot } };
}

function collectFiles(root, relDir = '', out = []) {
  const absDir = relDir ? path.join(root, ...relDir.split('/')) : root;
  const entries = fs.readdirSync(absDir, { withFileTypes: true });
  for (const entry of entries) {
    if (IGNORED_DIRS.has(entry.name)) continue;
    const childRel = relDir ? `${relDir}/${entry.name}` : entry.name;
    if (entry.isDirectory()) {
      collectFiles(root, childRel, out);
    } else if (entry.isFile()) {
      out.push(childRel);
    }
  }
  return out;
}

export function scanSecretsInFiles(root, relFiles, onUnreadable = () => {}) {
  const findings = [];
  const io = createFsReadonlyIo(root);
  for (const rel of relFiles) {
    if (!SCANNABLE_EXT_RE.test(rel)) continue;
    const text = io.readText(rel);
    if (text == null) {
      // A changed-file list includes deletions. Every remaining scan target must be readable.
      try {
        if (sanitizeRelPath(rel) && !fs.lstatSync(path.join(root, rel), { throwIfNoEntry: false })) continue;
      } catch {
        // A failed stat cannot establish that the target was deleted.
      }
      onUnreadable();
      continue;
    }
    const lines = text.split(/\r?\n/);
    for (let idx = 0; idx < lines.length; idx += 1) {
      const line = lines[idx];
      for (const rule of SECRET_RULES) {
        rule.re.lastIndex = 0;
        let m;
        while ((m = rule.re.exec(line)) !== null) {
          findings.push({
            adapter: 'builtin-secret-pattern',
            rule: rule.id,
            severity: 'high',
            path: maskEvidence(rel),
            line: idx + 1,
            masked_match: maskSecret(m[0]),
            message: rule.message,
          });
        }
      }
    }
  }
  return findings;
}

export function scanSlopsquatting(root, files = collectFiles(root)) {
  const findings = [];
  const io = createFsReadonlyIo(root);
  for (const rel of files.filter(f => path.posix.basename(f) === 'package.json')) {
    const raw = io.readText(rel);
    if (raw == null) throw new Error('UNREADABLE_MANIFEST');
    const pkg = JSON.parse(raw);
    const dependencies = { ...pkg.dependencies, ...pkg.devDependencies, ...pkg.optionalDependencies, ...pkg.peerDependencies };
    for (const [name, version] of Object.entries(dependencies)) {
      const lower = name.toLowerCase();
      const similar = !POPULAR_PACKAGES.includes(lower) && POPULAR_PACKAGES.find(
        p => Math.abs(lower.length - p.length) <= 1 && levenshtein(lower, p) <= 1,
      );
      if (similar) findings.push({
        adapter: 'builtin-slopsquatting', rule: 'suspected-typosquat-package', severity: 'high', path: maskEvidence(rel),
        line: 1, masked_match: maskEvidence(name), message: `依存パッケージ名が ${similar} に酷似しています`,
      });
      if (/^http:\/\//i.test(version)) findings.push({
        adapter: 'builtin-slopsquatting', rule: 'insecure-http-dependency', severity: 'high', path: maskEvidence(rel),
        line: 1, masked_match: 'http://…', message: '依存パッケージが非暗号化 HTTP URL を使用しています',
      });
    }
  }
  return findings;
}

const NATIVE_HEADERS = new Set(['7f454c46', 'feedface', 'cefaedfe', 'feedfacf', 'cffaedfe', 'cafebabe', 'bebafeca', 'cafebabf', 'bfbafeca']);

function isNative(real) {
  fs.accessSync(real, fs.constants.X_OK);
  const fd = fs.openSync(real, 'r');
  try {
    const signature = Buffer.alloc(4);
    fs.readSync(fd, signature, 0, 4, 0);
    return signature.subarray(0, 2).toString('ascii') === 'MZ' || NATIVE_HEADERS.has(signature.toString('hex'));
  } finally {
    fs.closeSync(fd);
  }
}

function installedBinary(adapter, root) {
  const project = fs.realpathSync(root);
  function outsideProject(file) {
    const rel = path.relative(project, file);
    return rel === '..' || rel.startsWith('..' + path.sep) || path.isAbsolute(rel);
  }
  for (const dir of (process.env.PATH || '').split(path.delimiter).filter(path.isAbsolute)) {
    const names = process.platform === 'win32' ? [adapter + '.exe'] : [adapter];
    // The official CodeQL distribution may expose only a shell/batch launcher.
    // Use its distribution path to locate the bundled JVM; never execute the launcher.
    if (adapter === 'codeql' && process.platform === 'win32') names.push('codeql.cmd');
    if (adapter === 'socket') names.push('node_modules/@socketsecurity/cli/bin/cli.js');
    for (const name of names) {
      try {
        const real = fs.realpathSync(path.join(dir, name));
        if (!outsideProject(real) || !fs.statSync(real).isFile()) continue;
        if (adapter === 'codeql') {
          const distro = path.dirname(real);
          const platform = { darwin: 'osx64', win32: 'win64', linux: process.arch === 'arm64' ? 'linux-arm64' : 'linux64' }[process.platform];
          const runtime = platform === 'osx64' && process.arch === 'arm64' ? 'java-aarch64' : 'java';
          const java = platform && path.join(distro, 'tools', platform, runtime, 'bin', process.platform === 'win32' ? 'java.exe' : 'java');
          const jar = path.join(distro, 'tools', 'codeql.jar');
          if (java && fs.existsSync(java) && fs.existsSync(jar) && outsideProject(fs.realpathSync(java)) &&
              outsideProject(fs.realpathSync(jar)) && isNative(java)) {
            return { bin: java, prefix: ['--add-modules', 'jdk.unsupported', '--enable-native-access=ALL-UNNAMED', '-cp', jar, 'com.semmle.cli2.CodeQL'],
              env: { CODEQL_DIST: distro, CODEQL_PLATFORM: platform } };
          }
        }
        if (WINDOWS_WRAPPER_RE.test(real)) continue;
        if (/\.(?:js|mjs|cjs)$/i.test(real)) return { bin: process.execPath, prefix: [real] };
        if (isNative(real)) return { bin: real, prefix: [] };
        // pip/uv install the Semgrep console script beside its venv interpreter.
        // Preserve the venv path, run in isolated mode, and never dispatch a shell.
        if (adapter === 'semgrep' && process.platform !== 'win32') {
          const interpreter = path.join(path.dirname(real), 'python3');
          if (outsideProject(fs.realpathSync(interpreter)) && isNative(interpreter)) {
            return { bin: interpreter, prefix: ['-I', real] };
          }
        }
      } catch {
        // Try the next installed copy.
      }
    }
  }
  return null;
}

function defaultExternalRunner(cmdSpec) {
  const installed = installedBinary(cmdSpec.bin, cmdSpec.options.cwd);
  if (!installed) return { unavailable: true };
  try {
    const stdout = execFileSync(installed.bin, [...installed.prefix, ...cmdSpec.args], {
      ...cmdSpec.options, env: { ...process.env, ...installed.env }, stdio: ['ignore', 'pipe', 'pipe'],
      timeout: cmdSpec.bin === 'codeql' ? 15 * 60_000 : 120_000, maxBuffer: 8 * 1024 * 1024,
    });
    return { status: 0, stdout };
  } catch (err) {
    return { status: err.status, stdout: err.stdout, unavailable: err.code === 'ENOENT' };
  }
}

function codeqlScan(cmd, runner) {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-codeql-'));
  try {
    const db = path.join(tmp, 'db');
    const sarif = path.join(tmp, 'results.sarif');
    const created = runner({ ...cmd, args: [...cmd.args, db] });
    if (created.unavailable) return 'unavailable';
    if (created.status !== 0) return 'error';
    const analyzed = runner({ ...cmd, args: ['database', 'analyze', db, 'codeql/javascript-queries:codeql-suites/javascript-security-extended.qls',
      '--format=sarifv2.1.0', `--output=${sarif}`] });
    if (analyzed.status !== 0) return 'error';
    const report = JSON.parse(fs.readFileSync(sarif, 'utf8'));
    if (report.version !== '2.1.0' || !Array.isArray(report.runs) || !report.runs.length ||
        !report.runs.every(r => Array.isArray(r.results) && r.invocations?.every(i => i.executionSuccessful !== false) !== false)) return 'error';
    return report.runs.some(r => r.results.length) ? 'finding' : 'clean';
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
}

function scanExternal(adapter, root, runner) {
  const cmd = resolveSafeExternalCommand(adapter, root);
  try {
    if (adapter === 'codeql') return codeqlScan(cmd, runner);
    const result = runner(cmd);
    if (result.unavailable) return 'unavailable';
    if (adapter === 'socket') {
      const report = JSON.parse(result.stdout);
      // Socket CLI wraps completed reports in { ok: true, data }. Preserve flat reports from earlier adapters.
      const wrapped = Object.hasOwn(report, 'ok') || Object.hasOwn(report, 'data');
      if (wrapped && report.ok !== true) return 'error';
      const healthy = wrapped ? report.data?.healthy : report.healthy;
      if (result.status === 0 && healthy === true) return 'clean';
      if (result.status === 1 && healthy === false) return 'finding';
      return 'error';
    }
    if (result.status === 0) return 'clean';
    const findingCode = { semgrep: 1, gitleaks: 42, trufflehog: 183 };
    return result.status === findingCode[adapter] ? 'finding' : 'error';
  } catch {
    // Tool output may contain raw credentials; publish only the status below.
    return 'error';
  }
}

export function runSecurityGate({
  projectRoot = null,
  files = null,
  adapters = null,
  mode = null,
  ci = ['true', '1'].includes(process.env.CI),
  externalRunner = defaultExternalRunner,
} = {}) {
  const root = resolveExplicitOrAutoRoot(projectRoot);
  const validation = validateGuardrailsFile(root);
  const secErrors = validation.errors.filter((e) => e.path.startsWith('security_audit') || e.path.startsWith('risk_defaults') || e.code === 'PARSE_ERROR');
  if (secErrors.length > 0) {
    return {
      schema: 'sdd-security-gate/v1',
      status: 'TOOL_ERROR',
      exitCode: 2,
      errors: secErrors.map(({ code }) => ({ code, message: '無効なセキュリティ設定です' })),
      findings: [],
    };
  }

  const saCfg = validation.config.security_audit || {};
  const effectiveMode = mode ?? (saCfg.enabled ? saCfg.mode : 'off');
  if (!['off', 'warn', 'shadow', 'strict'].includes(effectiveMode)) {
    return { schema: 'sdd-security-gate/v1', status: 'TOOL_ERROR', exitCode: 2, errors: [{ code: 'INVALID_MODE' }], findings: [] };
  }
  const requestedAdapters = Array.isArray(adapters) && adapters.length > 0 ? adapters : saCfg.enabled_adapters || [];

  for (const ad of requestedAdapters) {
    if (!VALID_SECURITY_ADAPTERS.has(ad)) {
      return {
        schema: 'sdd-security-gate/v1',
        status: 'TOOL_ERROR',
        exitCode: 2,
        errors: [{ code: 'UNALLOWED_SECURITY_ADAPTER', message: '未許可のセキュリティアダプタです' }],
        findings: [],
      };
    }
  }

  if (effectiveMode === 'off') {
    return {
      schema: 'sdd-security-gate/v1',
      mode: 'off',
      status: 'SKIPPED',
      exitCode: 0,
      adaptersRun: [],
      findings: [],
      warnings: [],
    };
  }

  let targetFiles;
  try {
    targetFiles = files == null ? collectFiles(root) : files.map(sanitizeRelPath);
  } catch {
    // An incomplete inventory cannot establish that all high-risk paths were scanned.
    return { schema: 'sdd-security-gate/v1', mode: effectiveMode, status: 'TOOL_ERROR', exitCode: 2,
      adaptersRun: [], errors: [{ code: 'UNREADABLE_SCAN_INPUT' }], findings: [], warnings: [] };
  }
  if (targetFiles.some(file => file === null)) {
    return { schema: 'sdd-security-gate/v1', status: 'TOOL_ERROR', exitCode: 2, errors: [{ code: 'INVALID_PATH' }], findings: [] };
  }
  const patterns = validation.config.risk_defaults.high_risk_paths.map(globToRegExp);
  const highRisk = targetFiles.some(file => patterns.some(p => p.test(file)));
  const failClosed = effectiveMode === 'strict' || ci || highRisk;
  const findings = [];
  const warnings = [];
  const adaptersRun = [];

  for (const ad of requestedAdapters) {
    adaptersRun.push(ad);
    if (ad === 'builtin-secret-pattern') {
      let unreadable = false;
      findings.push(...scanSecretsInFiles(root, targetFiles, () => { unreadable = true; }));
      if (unreadable) {
        const code = 'UNREADABLE_SCAN_INPUT';
        if (failClosed) return { schema: 'sdd-security-gate/v1', mode: effectiveMode, status: 'TOOL_ERROR', exitCode: 2,
          adaptersRun, errors: [{ code }], findings, warnings };
        warnings.push(code);
      }
    } else if (ad === 'builtin-slopsquatting') {
      try {
        findings.push(...scanSlopsquatting(root, targetFiles));
      } catch {
        const code = 'UNREADABLE_MANIFEST';
        if (failClosed) return { schema: 'sdd-security-gate/v1', mode: effectiveMode, status: 'TOOL_ERROR', exitCode: 2,
          adaptersRun, errors: [{ code }], findings, warnings };
        warnings.push(code);
      }
    } else {
      const outcome = scanExternal(ad, root, externalRunner);
      if (outcome === 'unavailable' || outcome === 'error') {
        const code = outcome === 'unavailable' ? 'ADAPTER_UNAVAILABLE' : 'ADAPTER_ERROR';
        const message = `${ad}: ${code}`;
        if (failClosed) {
          const missingOnHighRiskPath = highRisk && outcome === 'unavailable';
          return { schema: 'sdd-security-gate/v1', mode: effectiveMode, status: missingOnHighRiskPath ? 'FAIL' : 'TOOL_ERROR', exitCode: missingOnHighRiskPath ? 1 : 2,
            adaptersRun, errors: [{ code, message }], findings, warnings };
        }
        warnings.push(message);
      } else if (outcome === 'finding') {
        findings.push({
          adapter: ad,
          rule: `${ad}-finding`,
          severity: 'high',
          path: '.',
          line: 1,
          masked_match: '****',
          message: `外部アダプタ ${ad} がセキュリティ問題を検出しました`,
        });
      }
    }
  }

  const status = findings.length > 0 && failClosed ? 'FAIL' : findings.length || warnings.length ? 'WARN' : 'PASS';
  return {
    schema: 'sdd-security-gate/v1',
    mode: effectiveMode,
    status,
    exitCode: status === 'FAIL' ? 1 : 0,
    adaptersRun,
    findings,
    warnings,
  };
}

function parseArgs(argv) {
  const opts = { root: null, files: null, adapters: null, mode: null, ci: ['true', '1'].includes(process.env.CI) };
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === '--root' && argv[i + 1]) opts.root = argv[++i];
    else if (a === '--files' && argv[i + 1]) opts.files = argv[++i].split(',').map((s) => s.trim()).filter(Boolean);
    else if (a === '--adapters' && argv[i + 1]) opts.adapters = argv[++i].split(',').map((s) => s.trim()).filter(Boolean);
    else if (a === '--mode' && argv[i + 1]) opts.mode = argv[++i];
    else if (a === '--ci') opts.ci = true;
  }
  return opts;
}

if (isMainModule(import.meta.url, 'run-security-gate.mjs')) {
  const opts = parseArgs(process.argv.slice(2));
  const report = runSecurityGate({
    projectRoot: opts.root || process.cwd(),
    files: opts.files,
    adapters: opts.adapters,
    mode: opts.mode,
    ci: opts.ci,
  });
  process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
  process.exit(report.exitCode);
}
