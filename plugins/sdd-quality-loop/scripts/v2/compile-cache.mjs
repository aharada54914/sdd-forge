#!/usr/bin/env node
/**
 * compile-cache.mjs — Two-stage hybrid portable Node.js Compile Cache builder.
 *
 * Pre-generates portable V8 bytecode cache under `.sdd-compile-cache/` by
 * running `--warmup` against primary CLI/hook/MCP entrypoints with:
 *   NODE_COMPILE_CACHE=<cacheDir>
 *   NODE_COMPILE_CACHE_PORTABLE=1
 *
 * Usage:
 *   node compile-cache.mjs --root <install-or-repo-root> [--cache-dir <dir>] [--json]
 */
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { isMainModule } from './guardrails-lib.mjs';

export const DEFAULT_WARMUP_TARGETS = Object.freeze([
  'plugins/sdd-quality-loop/scripts/v2/sdd-soft-guard.mjs',
  'plugins/sdd-quality-loop/scripts/v2/run-sdd-gate.mjs',
  'plugins/sdd-quality-loop/scripts/v2/sdd-doctor.mjs',
  'plugins/sdd-quality-loop/scripts/v2/render-decision-view.mjs',
  'mcp/sdd-forge-mcp/dist/index.js',
]);

function countFilesRecursive(dir) {
  if (!fs.existsSync(dir)) return 0;
  let total = 0;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) total += countFilesRecursive(full);
    else if (entry.isFile()) total += 1;
  }
  return total;
}

export function inspectCompileCache(cacheDir) {
  const exists = Boolean(cacheDir) && fs.existsSync(cacheDir);
  const fileCount = exists ? countFilesRecursive(cacheDir) : 0;
  return {
    cacheDir,
    exists,
    fileCount,
    portableEnv: process.env.NODE_COMPILE_CACHE_PORTABLE === '1',
    readonlyEnv: process.env.NODE_COMPILE_CACHE_READONLY === '1',
    disabledEnv: process.env.NODE_DISABLE_COMPILE_CACHE === '1',
    nodeVersion: process.versions.node,
  };
}

export function warmCompileCache({
  installRoot,
  cacheDir = null,
  nodeBinary = process.execPath,
  targets = DEFAULT_WARMUP_TARGETS,
} = {}) {
  const root = path.resolve(installRoot || process.cwd());
  const resolvedCache = path.resolve(cacheDir || path.join(root, '.sdd-compile-cache'));
  fs.mkdirSync(resolvedCache, { recursive: true });

  const env = { ...process.env };
  delete env.NODE_DISABLE_COMPILE_CACHE;
  delete env.NODE_COMPILE_CACHE_READONLY;
  env.NODE_COMPILE_CACHE = resolvedCache;
  env.NODE_COMPILE_CACHE_PORTABLE = '1';

  const warmed = [];
  const skipped = [];
  const failed = [];

  for (const rel of targets) {
    const targetPath = path.join(root, rel);
    if (!fs.existsSync(targetPath)) {
      skipped.push(rel);
      continue;
    }
    const res = spawnSync(nodeBinary, [targetPath, '--warmup'], {
      cwd: root,
      env,
      encoding: 'utf8',
      timeout: 30000,
    });
    if (res.status === 0 && !res.error) {
      warmed.push(rel);
    } else {
      failed.push({
        target: rel,
        status: res.status,
        error: (res.error?.message || res.stderr || 'warmup failed').trim().slice(0, 300),
      });
    }
  }

  return {
    ok: failed.length === 0,
    nodeVersion: process.versions.node,
    cacheDir: resolvedCache,
    fileCount: countFilesRecursive(resolvedCache),
    warmed,
    skipped,
    failed,
  };
}

function parseArgs(argv) {
  const opts = { root: null, cacheDir: null, json: false };
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === '--root' && argv[i + 1]) opts.root = argv[++i];
    else if (a === '--cache-dir' && argv[i + 1]) opts.cacheDir = argv[++i];
    else if (a === '--json') opts.json = true;
  }
  return opts;
}

if (isMainModule(import.meta.url, 'compile-cache.mjs')) {
  const opts = parseArgs(process.argv.slice(2));
  const result = warmCompileCache({ installRoot: opts.root || process.cwd(), cacheDir: opts.cacheDir });
  if (opts.json) {
    process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  } else {
    process.stdout.write(
      `Compile cache warmed at ${result.cacheDir} (${result.fileCount} files; warmed=${result.warmed.length}, skipped=${result.skipped.length}, failed=${result.failed.length})\n`,
    );
  }
  process.exit(result.ok ? 0 : 1);
}
