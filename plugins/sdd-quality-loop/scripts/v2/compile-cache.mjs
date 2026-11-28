#!/usr/bin/env node
/**
 * Two-Stage Hybrid Portable Compile Cache builder & inspector (ADR-0055).
 *
 * Stage 1 (release.yml): pre-generates portable cache with reference Node 26.13.0
 * into `.sdd-compile-cache/` (included in `install-payload.txt`).
 * Stage 2 (install.sh / install.ps1): runs `--warmup` with the user's own `node`
 * inside staging immediately before atomic swap so the very first PreToolUse
 * hook invocation hits the cache in read-only mode.
 */
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DEFAULT_ROOT = path.resolve(__dirname, '../../../..');

export const WARMUP_TARGETS = Object.freeze([
  { rel: 'plugins/sdd-quality-loop/scripts/v2/sdd-soft-guard.mjs', args: ['--warmup'], required: true },
  { rel: 'plugins/sdd-quality-loop/scripts/v2/run-sdd-gate.mjs', args: ['--warmup'], required: true },
  { rel: 'plugins/sdd-quality-loop/scripts/v2/render-decision-view.mjs', args: ['--warmup'], required: true },
  { rel: 'plugins/sdd-quality-loop/scripts/v2/sdd-doctor.mjs', args: ['--warmup'], required: true },
  { rel: 'mcp/sdd-forge-mcp/dist/index.js', args: ['--warmup'], required: false },
  { rel: 'mcp/ci-mcp/dist/index.js', args: ['--warmup'], required: false },
]);

function countFilesAndBytes(dir) {
  if (!fs.existsSync(dir)) return { files: 0, bytes: 0, subdirs: [] };
  let files = 0;
  let bytes = 0;
  const subdirs = [];
  const stack = [{ p: dir, depth: 0 }];
  while (stack.length > 0) {
    const { p, depth } = stack.pop();
    let entries;
    try {
      entries = fs.readdirSync(p, { withFileTypes: true });
    } catch {
      continue;
    }
    for (const entry of entries) {
      const full = path.join(p, entry.name);
      if (entry.isDirectory()) {
        if (depth === 0) subdirs.push(entry.name);
        stack.push({ p: full, depth: depth + 1 });
      } else if (entry.isFile()) {
        files += 1;
        try {
          bytes += fs.statSync(full).size;
        } catch {
          // ignore transient file stat failure
        }
      }
    }
  }
  return { files, bytes, subdirs: subdirs.sort() };
}

export function inspectCompileCache(cacheDir) {
  const resolved = path.resolve(cacheDir);
  const exists = fs.existsSync(resolved);
  const stats = exists ? countFilesAndBytes(resolved) : { files: 0, bytes: 0, subdirs: [] };
  return {
    cacheDir: resolved,
    exists,
    fileCount: stats.files,
    totalBytes: stats.bytes,
    versionBuckets: stats.subdirs,
    nodeVersion: process.version,
  };
}

export function warmupCompileCache({
  root = DEFAULT_ROOT,
  cacheDir = null,
  targets = WARMUP_TARGETS,
  nodePath = process.execPath,
  timeoutMs = 30000,
} = {}) {
  const resolvedRoot = path.resolve(root);
  const resolvedCache = path.resolve(cacheDir || path.join(resolvedRoot, '.sdd-compile-cache'));
  fs.mkdirSync(resolvedCache, { recursive: true });

  const env = { ...process.env };
  delete env.NODE_DISABLE_COMPILE_CACHE;
  delete env.NODE_COMPILE_CACHE_READONLY;
  env.NODE_COMPILE_CACHE = resolvedCache;
  env.NODE_COMPILE_CACHE_PORTABLE = '1';

  const results = [];
  for (const target of targets) {
    const absTarget = path.join(resolvedRoot, target.rel);
    if (!fs.existsSync(absTarget)) {
      results.push({
        target: target.rel,
        status: target.required ? 'missing-required' : 'skipped',
        exitCode: target.required ? 2 : 0,
      });
      continue;
    }
    const res = spawnSync(nodePath, [absTarget, ...(target.args || ['--warmup'])], {
      cwd: resolvedRoot,
      env,
      encoding: 'utf8',
      timeout: timeoutMs,
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    results.push({
      target: target.rel,
      status: res.status === 0 ? 'ok' : 'failed',
      exitCode: res.status ?? 1,
      stderr: (res.stderr || '').trim().slice(0, 400),
    });
  }

  const inspection = inspectCompileCache(resolvedCache);
  const ok = results.every((r) => r.status === 'ok' || r.status === 'skipped');
  return {
    ok,
    root: resolvedRoot,
    cacheDir: resolvedCache,
    nodeVersion: process.version,
    results,
    inspection,
  };
}

function parseArgs(argv) {
  const opts = { warmup: false, inspect: false, root: DEFAULT_ROOT, cacheDir: null, json: false };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--warmup') opts.warmup = true;
    else if (arg === '--inspect') opts.inspect = true;
    else if (arg === '--json') opts.json = true;
    else if (arg === '--root' && argv[i + 1]) opts.root = path.resolve(argv[++i]);
    else if (arg === '--cache-dir' && argv[i + 1]) opts.cacheDir = path.resolve(argv[++i]);
  }
  return opts;
}

const isDirectMain =
  process.argv[1] &&
  path.resolve(process.argv[1]) === path.resolve(fileURLToPath(import.meta.url));

if (isDirectMain) {
  const opts = parseArgs(process.argv.slice(2));
  if (opts.inspect && !opts.warmup) {
    const info = inspectCompileCache(opts.cacheDir || path.join(opts.root, '.sdd-compile-cache'));
    process.stdout.write(`${JSON.stringify(info, null, 2)}\n`);
    process.exit(info.exists && info.fileCount > 0 ? 0 : 1);
  }
  const summary = warmupCompileCache({ root: opts.root, cacheDir: opts.cacheDir });
  if (opts.json) {
    process.stdout.write(`${JSON.stringify(summary, null, 2)}\n`);
  } else {
    process.stdout.write(
      `compile-cache warmup (${summary.nodeVersion}): ${summary.inspection.fileCount} files (${summary.inspection.totalBytes} bytes) at ${summary.cacheDir}\n`,
    );
  }
  process.exit(summary.ok ? 0 : 1);
}
