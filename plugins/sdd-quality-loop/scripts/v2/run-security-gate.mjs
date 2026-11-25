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
 *   - In CI (`--ci` or `CI=true`) + `strict` mode, missing enabled external adapters fail closed (exit 2).
 *
 * Exit codes:
 *   0 — PASS (or shadow/warn/off mode)
 *   1 — Strict mode security finding detected
 *   2 — Tool / config / unallowed adapter / CI missing binary error
 */
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import {
  VALID_SECURITY_ADAPTERS,
  isMainModule,
  normalizeRelPath,
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
  const map = {
    semgrep: { bin: binaryOverride || 'semgrep', args: ['scan', '--json', '--quiet', projectRoot] },
    gitleaks: { bin: binaryOverride || 'gitleaks', args: ['detect', '--source', projectRoot, '--no-git', '--report-format', 'json'] },
    trufflehog: { bin: binaryOverride || 'trufflehog', args: ['filesystem', '--json', projectRoot] },
    codeql: { bin: binaryOverride || 'codeql', args: ['version'] },
    socket: { bin: binaryOverride || 'socket', args: ['--version'] },
  };
  const spec = map[adapter];
  if (!spec) return null;
  if (WINDOWS_WRAPPER_RE.test(spec.bin)) {
    throw new Error(`Refusing to execute Windows batch wrapper (.cmd/.bat) without shell: ${spec.bin}`);
  }
  return { bin: spec.bin, args: spec.args, options: { shell: false, encoding: 'utf8' } };
}

function collectFiles(root, relDir = '', out = [], maxFiles = 1500) {
  if (out.length >= maxFiles) return out;
  const absDir = relDir ? path.join(root, ...relDir.split('/')) : root;
  let entries;
  try {
    entries = fs.readdirSync(absDir, { withFileTypes: true });
  } catch {
    return out;
  }
  for (const entry of entries) {
    if (out.length >= maxFiles) break;
    if (IGNORED_DIRS.has(entry.name)) continue;
    const childRel = relDir ? `${relDir}/${entry.name}` : entry.name;
    if (entry.isDirectory()) {
      collectFiles(root, childRel, out, maxFiles);
    } else if (entry.isFile() && SCANNABLE_EXT_RE.test(entry.name)) {
      out.push(childRel);
    }
  }
  return out;
}

export function scanSecretsInFiles(root, relFiles) {
  const findings = [];
  for (const rel of relFiles) {
    const abs = path.join(root, ...rel.split('/'));
    if (!fs.existsSync(abs)) continue;
    let text;
    try {
      const st = fs.statSync(abs);
      if (!st.isFile() || st.size > 2 * 1024 * 1024) continue;
      text = fs.readFileSync(abs, 'utf8');
    } catch {
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
            path: rel,
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

export function scanSlopsquatting(root) {
  const findings = [];
  const pkgPath = path.join(root, 'package.json');
  if (fs.existsSync(pkgPath)) {
    try {
      const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
      const allDeps = {
        ...(pkg.dependencies || {}),
        ...(pkg.devDependencies || {}),
      };
      for (const [depName, ver] of Object.entries(allDeps)) {
        const lower = depName.toLowerCase();
        if (POPULAR_PACKAGES.includes(lower)) continue;
        for (const pop of POPULAR_PACKAGES) {
          if (Math.abs(lower.length - pop.length) <= 1 && levenshtein(lower, pop) <= 1) {
            findings.push({
              adapter: 'builtin-slopsquatting',
              rule: 'suspected-typosquat-package',
              severity: 'high',
              path: 'package.json',
              line: 1,
              masked_match: depName,
              message: `パッケージ "${depName}" は人気パッケージ "${pop}" のタイポスクワット/Slopsquatting の可能性があります`,
            });
            break;
          }
        }
        if (/^http:\/\//i.test(String(ver || ''))) {
          findings.push({
            adapter: 'builtin-slopsquatting',
            rule: 'insecure-http-dependency',
            severity: 'high',
            path: 'package.json',
            line: 1,
            masked_match: `${depName}@http://...`,
            message: `パッケージ "${depName}" が非暗号化 HTTP URL から参照されています`,
          });
        }
      }
    } catch {
      // ignore malformed package.json here
    }
  }
  return findings;
}

function defaultExternalRunner(cmdSpec) {
  try {
    const stdout = execFileSync(cmdSpec.bin, cmdSpec.args, {
      ...cmdSpec.options,
      stdio: ['ignore', 'pipe', 'pipe'],
      timeout: 30000,
    });
    return { status: 0, stdout: String(stdout || ''), stderr: '' };
  } catch (err) {
    if (err && err.code === 'ENOENT') {
      return { status: 127, unavailable: true, stdout: '', stderr: String(err.message || '') };
    }
    return {
      status: typeof err?.status === 'number' ? err.status : 1,
      stdout: String(err?.stdout || ''),
      stderr: String(err?.stderr || err?.message || ''),
    };
  }
}

export function runSecurityGate({
  projectRoot = null,
  files = null,
  adapters = null,
  mode = null,
  ci = Boolean(process.env.CI),
  externalRunner = defaultExternalRunner,
} = {}) {
  const root = resolveExplicitOrAutoRoot(projectRoot);
  const validation = validateGuardrailsFile(root);
  const secErrors = validation.errors.filter((e) => e.path.startsWith('security_audit'));
  if (secErrors.length > 0) {
    return {
      schema: 'sdd-security-gate/v1',
      status: 'TOOL_ERROR',
      exitCode: 2,
      errors: secErrors,
      findings: [],
    };
  }

  const saCfg = validation.config.security_audit || {};
  const effectiveMode = mode || (saCfg.enabled ? saCfg.mode : 'shadow');
  const requestedAdapters = Array.isArray(adapters) && adapters.length > 0 ? adapters : saCfg.enabled_adapters || [];

  for (const ad of requestedAdapters) {
    if (!VALID_SECURITY_ADAPTERS.has(ad)) {
      return {
        schema: 'sdd-security-gate/v1',
        status: 'TOOL_ERROR',
        exitCode: 2,
        errors: [{ code: 'UNALLOWED_SECURITY_ADAPTER', message: `未許可のセキュリティアダプタ: ${ad}` }],
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

  const targetFiles =
    Array.isArray(files) && files.length > 0
      ? files.map((f) => normalizeRelPath(f)).filter(Boolean)
      : collectFiles(root);

  const findings = [];
  const warnings = [];
  const adaptersRun = [];

  for (const ad of requestedAdapters) {
    adaptersRun.push(ad);
    if (ad === 'builtin-secret-pattern') {
      findings.push(...scanSecretsInFiles(root, targetFiles));
    } else if (ad === 'builtin-slopsquatting') {
      findings.push(...scanSlopsquatting(root));
    } else {
      const cmdSpec = resolveSafeExternalCommand(ad, root);
      const res = externalRunner(cmdSpec);
      if (res.unavailable) {
        if (ci && effectiveMode === 'strict') {
          return {
            schema: 'sdd-security-gate/v1',
            mode: effectiveMode,
            status: 'TOOL_ERROR',
            exitCode: 2,
            adaptersRun,
            errors: [{ code: 'CI_ADAPTER_UNAVAILABLE', message: `CI strict モードで必須アダプタ ${ad} が利用不可です` }],
            findings,
          };
        }
        warnings.push(`外部アダプタ ${ad} が見つかりませんでした（ローカル/shadow のため継続）`);
      } else if (res.status !== 0) {
        findings.push({
          adapter: ad,
          rule: `${ad}-finding`,
          severity: 'high',
          path: '.',
          line: 1,
          masked_match: `${ad} exit=${res.status}`,
          message: `外部アダプタ ${ad} がセキュリティ問題を検出しました`,
        });
      }
    }
  }

  const status = findings.length > 0 ? (effectiveMode === 'strict' ? 'FAIL' : 'WARN') : 'PASS';
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
  const opts = { root: null, files: null, adapters: null, mode: null, ci: Boolean(process.env.CI) };
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
