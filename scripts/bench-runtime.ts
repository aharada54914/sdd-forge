#!/usr/bin/env node
/**
 * Buildless TypeScript runtime benchmark suite for SDD Forge (ADR-0055).
 *
 * Measures:
 *   1. Cold startup (`NODE_DISABLE_COMPILE_CACHE=1`) vs Warm startup
 *      (`NODE_COMPILE_CACHE` + `NODE_COMPILE_CACHE_PORTABLE=1` + `NODE_COMPILE_CACHE_READONLY=1`)
 *      for `sdd-soft-guard.mjs`, `sdd-doctor.mjs`, and `run-sdd-gate.mjs`.
 *   2. SHA-256 hashing (`crypto.createHash` vs one-shot `crypto.hash`).
 *   3. Async filesystem scan via `fs.promises.glob`.
 *
 * Compatible with direct execution (`node scripts/bench-runtime.ts --iterations 3 --json`)
 * and Node 26 `--bench` runner hooks.
 */
import { spawnSync } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { performance } from 'node:perf_hooks';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..');

export interface StartupBenchEntry {
  target: string;
  coldMs: number;
  warmMs: number;
  speedup: number;
}

export interface RuntimeBenchReport {
  schema: 'sdd-runtime-bench/v1';
  nodeVersion: string;
  platform: string;
  arch: string;
  iterations: number;
  startup: StartupBenchEntry[];
  sha256: {
    samples: number;
    createHashMs: number;
    cryptoHashMs: number;
    speedup: number;
  };
  globScan: {
    fileCount: number;
    durationMs: number;
  };
}

function median(values: number[]): number {
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid];
}

function measureSpawn(scriptRel: string, envOverrides: Record<string, string | undefined>, iterations: number): number {
  const scriptAbs = path.join(REPO_ROOT, scriptRel);
  const env: NodeJS.ProcessEnv = { ...process.env };
  delete env.NODE_COMPILE_CACHE;
  delete env.NODE_COMPILE_CACHE_PORTABLE;
  delete env.NODE_COMPILE_CACHE_READONLY;
  delete env.NODE_DISABLE_COMPILE_CACHE;
  for (const [k, v] of Object.entries(envOverrides)) {
    if (v === undefined) delete env[k];
    else env[k] = v;
  }

  const samples: number[] = [];
  for (let i = 0; i < iterations; i += 1) {
    const t0 = performance.now();
    const res = spawnSync(process.execPath, [scriptAbs, '--warmup'], {
      cwd: REPO_ROOT,
      env,
      stdio: ['ignore', 'ignore', 'pipe'],
      encoding: 'utf8',
    });
    const dt = performance.now() - t0;
    if (res.status !== 0) {
      throw new Error(`Benchmark target ${scriptRel} exited ${res.status}: ${res.stderr}`);
    }
    samples.push(dt);
  }
  return Number(median(samples).toFixed(3));
}

export async function runRuntimeBenchmark(iterations = 3): Promise<RuntimeBenchReport> {
  const targets = [
    'plugins/sdd-quality-loop/scripts/v2/sdd-soft-guard.mjs',
    'plugins/sdd-quality-loop/scripts/v2/sdd-doctor.mjs',
    'plugins/sdd-quality-loop/scripts/v2/run-sdd-gate.mjs',
  ];

  const tempCache = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-bench-cache-'));
  try {
    // Pre-generate portable compile cache
    for (const rel of targets) {
      const res = spawnSync(process.execPath, [path.join(REPO_ROOT, rel), '--warmup'], {
        cwd: REPO_ROOT,
        env: {
          ...process.env,
          NODE_COMPILE_CACHE: tempCache,
          NODE_COMPILE_CACHE_PORTABLE: '1',
          NODE_DISABLE_COMPILE_CACHE: undefined,
          NODE_COMPILE_CACHE_READONLY: undefined,
        },
        stdio: ['ignore', 'ignore', 'pipe'],
        encoding: 'utf8',
      });
      if (res.status !== 0) {
        throw new Error(`Warmup failed for ${rel}: ${res.stderr}`);
      }
    }

    const startup: StartupBenchEntry[] = [];
    for (const rel of targets) {
      const coldMs = measureSpawn(rel, { NODE_DISABLE_COMPILE_CACHE: '1' }, iterations);
      const warmMs = measureSpawn(
        rel,
        {
          NODE_COMPILE_CACHE: tempCache,
          NODE_COMPILE_CACHE_PORTABLE: '1',
          NODE_COMPILE_CACHE_READONLY: '1',
        },
        iterations,
      );
      startup.push({
        target: rel,
        coldMs,
        warmMs,
        speedup: warmMs > 0 ? Number((coldMs / warmMs).toFixed(2)) : 1,
      });
    }

    // SHA-256 micro-benchmark
    const payload = '# Spec\n'.repeat(256);
    const hashIterations = 2000;
    const tCreate0 = performance.now();
    for (let i = 0; i < hashIterations; i += 1) {
      crypto.createHash('sha256').update(payload, 'utf8').digest('hex');
    }
    const createHashMs = Number((performance.now() - tCreate0).toFixed(3));

    const tOneShot0 = performance.now();
    const hasOneShot = typeof crypto.hash === 'function';
    for (let i = 0; i < hashIterations; i += 1) {
      if (hasOneShot) {
        crypto.hash('sha256', payload, 'hex');
      } else {
        crypto.createHash('sha256').update(payload, 'utf8').digest('hex');
      }
    }
    const cryptoHashMs = Number((performance.now() - tOneShot0).toFixed(3));

    // fs.promises.glob scan benchmark
    const tGlob0 = performance.now();
    const matched: string[] = [];
    for await (const entry of fs.promises.glob('plugins/sdd-quality-loop/scripts/v2/*.{mjs,ts}', {
      cwd: REPO_ROOT,
    })) {
      matched.push(entry);
    }
    const globDurationMs = Number((performance.now() - tGlob0).toFixed(3));

    return {
      schema: 'sdd-runtime-bench/v1',
      nodeVersion: process.version,
      platform: process.platform,
      arch: process.arch,
      iterations,
      startup,
      sha256: {
        samples: hashIterations,
        createHashMs,
        cryptoHashMs,
        speedup: cryptoHashMs > 0 ? Number((createHashMs / cryptoHashMs).toFixed(2)) : 1,
      },
      globScan: {
        fileCount: matched.length,
        durationMs: globDurationMs,
      },
    };
  } finally {
    fs.rmSync(tempCache, { recursive: true, force: true });
  }
}

const isDirectMain =
  process.argv[1] &&
  path.resolve(process.argv[1]) === path.resolve(fileURLToPath(import.meta.url));

if (isDirectMain) {
  const argv = process.argv.slice(2);
  let iterations = 3;
  let asJson = false;
  for (let i = 0; i < argv.length; i += 1) {
    if (argv[i] === '--iterations' && argv[i + 1]) {
      iterations = Math.max(1, Number.parseInt(argv[++i], 10) || 3);
    } else if (argv[i] === '--json') {
      asJson = true;
    }
  }
  const report = await runRuntimeBenchmark(iterations);
  if (asJson) {
    process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
  } else {
    process.stdout.write(`SDD Forge Runtime Benchmark (${report.nodeVersion} ${report.platform}/${report.arch}, n=${report.iterations})\n`);
    for (const s of report.startup) {
      process.stdout.write(`  ${s.target}: cold=${s.coldMs}ms warm=${s.warmMs}ms (${s.speedup}x)\n`);
    }
    process.stdout.write(
      `  sha256 (${report.sha256.samples}x): createHash=${report.sha256.createHashMs}ms crypto.hash=${report.sha256.cryptoHashMs}ms (${report.sha256.speedup}x)\n`,
    );
    process.stdout.write(
      `  fs.promises.glob: ${report.globScan.fileCount} files in ${report.globScan.durationMs}ms\n`,
    );
  }
}
