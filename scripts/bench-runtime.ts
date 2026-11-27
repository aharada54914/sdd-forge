#!/usr/bin/env node
/**
 * bench-runtime.ts — Zero-dependency erasable TypeScript runtime benchmark suite.
 *
 * Measures:
 *   1. Cold vs Warm (Portable Read-only Compile Cache) startup for sdd-soft-guard,
 *      sdd-doctor, and run-sdd-gate.
 *   2. One-shot crypto.hash('sha256') vs streaming crypto.createHash('sha256').
 *   3. Async fs.promises.glob scan over repository scripts.
 *
 * Usage:
 *   node scripts/bench-runtime.ts [--iterations <n>] [--json]
 */
import { spawnSync } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { performance } from 'node:perf_hooks';
import { fileURLToPath } from 'node:url';

interface TimingStats {
  runs: number;
  medianMs: number;
  p95Ms: number;
  meanMs: number;
}

interface StartupComparison {
  entry: string;
  cold: TimingStats;
  warm: TimingStats;
  speedupRatio: number;
}

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(SCRIPT_DIR, '..');

function summarize(samples: readonly number[]): TimingStats {
  const sorted = [...samples].sort((a, b) => a - b);
  const runs = sorted.length;
  const sum = sorted.reduce((acc, n) => acc + n, 0);
  const median = sorted[Math.floor(runs / 2)] ?? 0;
  const p95 = sorted[Math.min(runs - 1, Math.floor(runs * 0.95))] ?? 0;
  return {
    runs,
    medianMs: Number(median.toFixed(3)),
    p95Ms: Number(p95.toFixed(3)),
    meanMs: Number((sum / Math.max(1, runs)).toFixed(3)),
  };
}

function measureSpawn(entryRel: string, iterations: number, env: NodeJS.ProcessEnv): TimingStats {
  const scriptPath = path.join(REPO_ROOT, entryRel);
  const samples: number[] = [];
  for (let i = 0; i < iterations; i += 1) {
    const start = performance.now();
    const res = spawnSync(process.execPath, [scriptPath, '--warmup'], {
      cwd: REPO_ROOT,
      env,
      stdio: 'ignore',
      timeout: 30000,
    });
    if (res.status !== 0) {
      throw new Error(`Benchmark target failed (${entryRel}): exit=${res.status}`);
    }
    samples.push(performance.now() - start);
  }
  return summarize(samples);
}

function benchmarkHash(rounds: number): { oneShotMs: number; streamingMs: number; speedupRatio: number } {
  const payload = 'REQ-001: verify spec contract hashing performance.\n'.repeat(64);
  const startStream = performance.now();
  for (let i = 0; i < rounds; i += 1) {
    crypto.createHash('sha256').update(payload, 'utf8').digest('hex');
  }
  const streamingMs = performance.now() - startStream;

  const startOneShot = performance.now();
  for (let i = 0; i < rounds; i += 1) {
    crypto.hash('sha256', payload, 'hex');
  }
  const oneShotMs = performance.now() - startOneShot;

  return {
    oneShotMs: Number(oneShotMs.toFixed(3)),
    streamingMs: Number(streamingMs.toFixed(3)),
    speedupRatio: Number((streamingMs / Math.max(0.001, oneShotMs)).toFixed(2)),
  };
}

async function benchmarkGlob(): Promise<{ fileCount: number; durationMs: number }> {
  const start = performance.now();
  let fileCount = 0;
  for await (const _entry of fs.promises.glob('plugins/**/*.mjs', { cwd: REPO_ROOT })) {
    fileCount += 1;
  }
  return {
    fileCount,
    durationMs: Number((performance.now() - start).toFixed(3)),
  };
}

function parseArgs(argv: readonly string[]): { iterations: number; json: boolean } {
  let iterations = 5;
  let json = false;
  for (let i = 0; i < argv.length; i += 1) {
    if (argv[i] === '--iterations' && argv[i + 1]) {
      iterations = Math.max(1, Number(argv[++i]) || 5);
    } else if (argv[i] === '--json') {
      json = true;
    }
  }
  return { iterations, json };
}

async function main(): Promise<void> {
  const { iterations, json } = parseArgs(process.argv.slice(2));
  const cacheDir = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-bench-cache-'));
  try {
    const entries = [
      'plugins/sdd-quality-loop/scripts/v2/sdd-soft-guard.mjs',
      'plugins/sdd-quality-loop/scripts/v2/sdd-doctor.mjs',
      'plugins/sdd-quality-loop/scripts/v2/run-sdd-gate.mjs',
    ];
    const warmSetupEnv: NodeJS.ProcessEnv = {
      ...process.env,
      NODE_COMPILE_CACHE: cacheDir,
      NODE_COMPILE_CACHE_PORTABLE: '1',
    };
    delete warmSetupEnv.NODE_DISABLE_COMPILE_CACHE;
    delete warmSetupEnv.NODE_COMPILE_CACHE_READONLY;

    for (const rel of entries) {
      spawnSync(process.execPath, [path.join(REPO_ROOT, rel), '--warmup'], {
        cwd: REPO_ROOT,
        env: warmSetupEnv,
        stdio: 'ignore',
      });
    }

    const coldEnv: NodeJS.ProcessEnv = { ...process.env, NODE_DISABLE_COMPILE_CACHE: '1' };
    delete coldEnv.NODE_COMPILE_CACHE;
    const warmEnv: NodeJS.ProcessEnv = {
      ...process.env,
      NODE_COMPILE_CACHE: cacheDir,
      NODE_COMPILE_CACHE_PORTABLE: '1',
      NODE_COMPILE_CACHE_READONLY: '1',
    };
    delete warmEnv.NODE_DISABLE_COMPILE_CACHE;

    const startup: StartupComparison[] = entries.map((entry) => {
      const cold = measureSpawn(entry, iterations, coldEnv);
      const warm = measureSpawn(entry, iterations, warmEnv);
      return {
        entry,
        cold,
        warm,
        speedupRatio: Number((cold.medianMs / Math.max(0.001, warm.medianMs)).toFixed(2)),
      };
    });

    const hash = benchmarkHash(2000);
    const glob = await benchmarkGlob();
    const report = {
      schema: 'sdd-runtime-benchmark/v1',
      recordedAt: new Date().toISOString(),
      nodeVersion: process.versions.node,
      platform: process.platform,
      arch: process.arch,
      iterations,
      startup,
      hash,
      glob,
    };

    if (json) {
      process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
    } else {
      process.stdout.write(`SDD Forge Runtime Benchmark (Node ${report.nodeVersion}, ${report.platform}/${report.arch})\n`);
      for (const s of startup) {
        process.stdout.write(
          `  ${path.basename(s.entry)}: cold=${s.cold.medianMs}ms warm=${s.warm.medianMs}ms (${s.speedupRatio}x)\n`,
        );
      }
      process.stdout.write(`  sha256 (2000x): createHash=${hash.streamingMs}ms crypto.hash=${hash.oneShotMs}ms (${hash.speedupRatio}x)\n`);
      process.stdout.write(`  fs.promises.glob: ${glob.fileCount} files in ${glob.durationMs}ms\n`);
    }
  } finally {
    fs.rmSync(cacheDir, { recursive: true, force: true });
  }
}

await main();
