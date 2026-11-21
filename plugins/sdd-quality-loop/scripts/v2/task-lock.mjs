#!/usr/bin/env node
/**
 * task-lock.mjs — Execution control harness for SDD Forge v2.1 (Software Factory F-2).
 *
 * Provides atomic, fail-closed mutual-exclusion locks under `.sdd/locks/` to prevent
 * duplicate concurrent runs or conflicting parallel writes on the same feature/task.
 *
 * Zero external dependencies — Node.js >= 20 LTS built-in modules only.
 *
 * Usage:
 *   node task-lock.mjs acquire --feature <slug> [--task <T-NNN>] [--root <dir>] [--owner <id>] [--ttl <sec>] [--break-stale]
 *   node task-lock.mjs release --feature <slug> [--task <T-NNN>] [--root <dir>] [--owner <id>] [--force]
 *   node task-lock.mjs status  --feature <slug> [--task <T-NNN>] [--root <dir>]
 */
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { assertValidFeatureName, resolveExplicitOrAutoRoot } from './guardrails-lib.mjs';

const DEFAULT_TTL_SECONDS = 1800;

function lockFileName(feature, taskId) {
  assertValidFeatureName(feature);
  if (taskId) {
    if (!/^T-[A-Za-z0-9._-]+$/i.test(taskId)) {
      throw new Error(`Invalid task ID: ${taskId}`);
    }
    return `${feature}--${taskId.toUpperCase()}.lock`;
  }
  return `${feature}.lock`;
}

function isProcessAlive(pid) {
  if (!Number.isInteger(pid) || pid <= 0) return false;
  try {
    process.kill(pid, 0);
    return true;
  } catch (err) {
    return err && err.code === 'EPERM';
  }
}

function readLockRecord(lockPath) {
  try {
    return JSON.parse(fs.readFileSync(lockPath, 'utf8'));
  } catch {
    return null;
  }
}

function evaluateStale(record, nowMs = Date.now()) {
  if (!record || typeof record !== 'object') {
    return { stale: true, reason: 'corrupt-lock-file' };
  }
  const expiresMs = Date.parse(record.expiresAt || '');
  if (Number.isFinite(expiresMs) && nowMs > expiresMs) {
    return { stale: true, reason: 'ttl-expired' };
  }
  if (record.hostname === os.hostname() && Number.isInteger(record.pid) && !isProcessAlive(record.pid)) {
    return { stale: true, reason: 'pid-not-running' };
  }
  return { stale: false, reason: 'active' };
}

export function getLockStatus({ feature, taskId = null, projectRoot = null }) {
  const root = resolveExplicitOrAutoRoot(projectRoot);
  const name = lockFileName(feature, taskId);
  const lockPath = path.join(root, '.sdd', 'locks', name);
  if (!fs.existsSync(lockPath)) {
    return { locked: false, stale: false, lockPath, record: null };
  }
  const record = readLockRecord(lockPath);
  const { stale, reason } = evaluateStale(record);
  return { locked: true, stale, staleReason: reason, lockPath, record };
}

export function acquireLock({
  feature,
  taskId = null,
  projectRoot = null,
  owner = null,
  ttlSeconds = DEFAULT_TTL_SECONDS,
  breakStale = false,
}) {
  const root = resolveExplicitOrAutoRoot(projectRoot);
  const locksDir = path.join(root, '.sdd', 'locks');
  fs.mkdirSync(locksDir, { recursive: true });
  const name = lockFileName(feature, taskId);
  const lockPath = path.join(locksDir, name);

  const ttl = Number.isFinite(ttlSeconds) && ttlSeconds > 0 ? Math.min(ttlSeconds, 86400) : DEFAULT_TTL_SECONDS;
  const now = new Date();
  const record = {
    schema: 'sdd-task-lock/v1',
    feature,
    taskId: taskId ? taskId.toUpperCase() : null,
    owner: owner || `${os.hostname()}:${process.pid}`,
    pid: process.pid,
    hostname: os.hostname(),
    acquiredAt: now.toISOString(),
    expiresAt: new Date(now.getTime() + ttl * 1000).toISOString(),
  };

  for (let attempt = 0; attempt < 2; attempt += 1) {
    try {
      const fd = fs.openSync(lockPath, 'wx', 0o600);
      try {
        fs.writeFileSync(fd, `${JSON.stringify(record, null, 2)}\n`, 'utf8');
      } finally {
        fs.closeSync(fd);
      }
      return { acquired: true, lockPath, record };
    } catch (err) {
      if (!err || err.code !== 'EEXIST') throw err;
      const existing = readLockRecord(lockPath);
      const { stale, reason } = evaluateStale(existing);
      if (stale && breakStale && attempt === 0) {
        try {
          fs.unlinkSync(lockPath);
          continue;
        } catch {
          // Another process may have replaced it; fall through to fail-closed.
        }
      }
      return {
        acquired: false,
        lockPath,
        stale,
        staleReason: reason,
        existing,
        message: stale
          ? `Stale lock exists (${reason}). Re-run with --break-stale after verifying no worker is active.`
          : `Active lock held by ${existing?.owner || 'unknown'} until ${existing?.expiresAt || 'unknown'}. Fail-closed to prevent concurrent write collision.`,
      };
    }
  }
  return { acquired: false, lockPath, stale: false, message: 'Lock contention.' };
}

export function releaseLock({ feature, taskId = null, projectRoot = null, owner = null, force = false }) {
  const root = resolveExplicitOrAutoRoot(projectRoot);
  const name = lockFileName(feature, taskId);
  const lockPath = path.join(root, '.sdd', 'locks', name);
  if (!fs.existsSync(lockPath)) {
    return { released: true, existed: false, lockPath };
  }
  const existing = readLockRecord(lockPath);
  if (!force && owner && existing?.owner && existing.owner !== owner) {
    return {
      released: false,
      existed: true,
      lockPath,
      existing,
      message: `Lock is owned by '${existing.owner}', not '${owner}'. Pass --force to override.`,
    };
  }
  fs.unlinkSync(lockPath);
  return { released: true, existed: true, lockPath };
}

function parseArgs(argv) {
  const cmd = argv[0] || '';
  const opts = {
    cmd,
    feature: null,
    taskId: null,
    root: null,
    owner: null,
    ttl: DEFAULT_TTL_SECONDS,
    breakStale: false,
    force: false,
  };
  for (let i = 1; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === '--feature' && argv[i + 1]) opts.feature = argv[++i];
    else if (a === '--task' && argv[i + 1]) opts.taskId = argv[++i];
    else if (a === '--root' && argv[i + 1]) opts.root = argv[++i];
    else if (a === '--owner' && argv[i + 1]) opts.owner = argv[++i];
    else if (a === '--ttl' && argv[i + 1]) opts.ttl = Number(argv[++i]);
    else if (a === '--break-stale') opts.breakStale = true;
    else if (a === '--force') opts.force = true;
  }
  return opts;
}

const isMain =
  process.argv[1] &&
  path.basename(process.argv[1]) === 'task-lock.mjs' &&
  pathToFileURL(path.resolve(process.argv[1])).href === import.meta.url;

if (isMain) {
  const opts = parseArgs(process.argv.slice(2));
  if (!['acquire', 'release', 'status'].includes(opts.cmd) || !opts.feature) {
    process.stderr.write(
      'Usage: node task-lock.mjs <acquire|release|status> --feature <slug> [--task <T-NNN>] [--root <dir>] [--owner <id>] [--ttl <sec>] [--break-stale] [--force]\n',
    );
    process.exit(2);
  }
  try {
    if (opts.cmd === 'status') {
      const res = getLockStatus({ feature: opts.feature, taskId: opts.taskId, projectRoot: opts.root });
      process.stdout.write(`${JSON.stringify(res, null, 2)}\n`);
      process.exit(0);
    }
    if (opts.cmd === 'acquire') {
      const res = acquireLock({
        feature: opts.feature,
        taskId: opts.taskId,
        projectRoot: opts.root,
        owner: opts.owner,
        ttlSeconds: opts.ttl,
        breakStale: opts.breakStale,
      });
      process.stdout.write(`${JSON.stringify(res, null, 2)}\n`);
      process.exit(res.acquired ? 0 : 1);
    }
    const res = releaseLock({
      feature: opts.feature,
      taskId: opts.taskId,
      projectRoot: opts.root,
      owner: opts.owner,
      force: opts.force,
    });
    process.stdout.write(`${JSON.stringify(res, null, 2)}\n`);
    process.exit(res.released ? 0 : 1);
  } catch (err) {
    process.stderr.write(`task-lock error: ${err.message}\n`);
    process.exit(2);
  }
}
