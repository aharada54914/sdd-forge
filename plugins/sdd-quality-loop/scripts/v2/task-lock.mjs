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
 *   node task-lock.mjs acquire --feature <slug> --owner <id> [--task <T-NNN>] [--root <dir>] [--ttl <sec>] [--break-stale]
 *   node task-lock.mjs release --feature <slug> [--task <T-NNN>] [--root <dir>] [--owner <id>] [--force]
 *   node task-lock.mjs status  --feature <slug> [--task <T-NNN>] [--root <dir>]
 *
 * A lock with an explicit owner belongs to that owner (a ship run, a CI job)
 * until its TTL expires: the CLI process that wrote it exits at once, so its
 * pid says nothing about the holder (#815). The same owner may acquire again,
 * which renews the TTL. Without an owner, the lock is tied to the calling
 * process, which only makes sense through the in-process API.
 */
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { assertValidFeatureName, resolveExplicitOrAutoRoot, isMainModule } from './guardrails-lib.mjs';

const DEFAULT_TTL_SECONDS = 1800;

/**
 * Temporal-first time helpers (ADR-0055): uses standard `Temporal.Now.instant()`
 * and `Temporal.Instant.from()` when available (Node.js 26+), with deterministic
 * `Date` fallback on Node 24/25.
 */
export function nowEpochMs() {
  if (globalThis.Temporal?.Now?.instant) {
    return globalThis.Temporal.Now.instant().epochMilliseconds;
  }
  return Date.now();
}

export function epochMsToIso(ms) {
  if (globalThis.Temporal?.Instant?.fromEpochMilliseconds) {
    return globalThis.Temporal.Instant.fromEpochMilliseconds(Math.trunc(ms)).toString();
  }
  return new Date(ms).toISOString();
}

export function parseIsoEpochMs(iso) {
  if (!iso || typeof iso !== 'string') return Number.NaN;
  if (globalThis.Temporal?.Instant?.from) {
    try {
      return globalThis.Temporal.Instant.from(iso).epochMilliseconds;
    } catch {
      // fall back to Date.parse for non-strict ISO variants
    }
  }
  return Date.parse(iso);
}

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

// Renewal never rewrites the lock file (that would open a moment with no lock,
// or overwrite a lock someone else took). It writes a lease next to it, bound
// to the lock's owner and acquiredAt; a lease for any other lock is ignored.
function leasePath(lockPath) {
  return `${lockPath}.lease`;
}

function withLease(record, lockPath) {
  if (!record || typeof record !== 'object') return record;
  const lease = readLockRecord(leasePath(lockPath));
  if (!lease || lease.owner !== record.owner || lease.acquiredAt !== record.acquiredAt) return record;
  const leaseMs = Date.parse(lease.expiresAt || '');
  const ownMs = Date.parse(record.expiresAt || '');
  if (!Number.isFinite(leaseMs) || (Number.isFinite(ownMs) && ownMs >= leaseMs)) return record;
  return { ...record, expiresAt: lease.expiresAt, renewedAt: lease.renewedAt };
}

function removeQuietly(p) {
  try {
    fs.unlinkSync(p);
  } catch {
    // already gone
  }
}

function evaluateStale(record, nowMs = nowEpochMs()) {
  if (!record || typeof record !== 'object') {
    return { stale: true, reason: 'corrupt-lock-file' };
  }
  const expiresMs = parseIsoEpochMs(record.expiresAt || '');
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
  const record = withLease(readLockRecord(lockPath), lockPath);
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
  const nowMs = nowEpochMs();
  const record = {
    schema: 'sdd-task-lock/v1',
    feature,
    taskId: taskId ? taskId.toUpperCase() : null,
    owner: owner || `${os.hostname()}:${process.pid}`,
    pid: owner ? null : process.pid,
    hostname: os.hostname(),
    acquiredAt: epochMsToIso(nowMs),
    expiresAt: epochMsToIso(nowMs + ttl * 1000),
  };

  for (let attempt = 0; attempt < 2; attempt += 1) {
    try {
      // The lock appears with its content already written (temp file, then a
      // hard link that fails if the lock exists), so a racing --break-stale
      // never reads an empty file and takes it for a corrupt, stale lock.
      const tmpPath = `${lockPath}.new.${process.pid}.${Date.now()}.${Math.random().toString(16).slice(2, 8)}`;
      fs.writeFileSync(tmpPath, `${JSON.stringify(record, null, 2)}\n`, { encoding: 'utf8', mode: 0o600, flag: 'wx' });
      try {
        try {
          fs.linkSync(tmpPath, lockPath);
        } catch (linkErr) {
          // Volumes without hard links (FAT/exFAT, some network shares): fall
          // back to an exclusive create; a racer may briefly see it empty.
          if (!linkErr || !['EPERM', 'ENOTSUP', 'ENOSYS', 'EXDEV'].includes(linkErr.code)) throw linkErr;
          const fd = fs.openSync(lockPath, 'wx', 0o600);
          try {
            fs.writeFileSync(fd, `${JSON.stringify(record, null, 2)}\n`, 'utf8');
          } finally {
            fs.closeSync(fd);
          }
        }
      } finally {
        removeQuietly(tmpPath);
      }
      return { acquired: true, lockPath, record };
    } catch (err) {
      if (!err || err.code !== 'EEXIST') throw err;
      const existing = withLease(readLockRecord(lockPath), lockPath);
      const { stale, reason } = evaluateStale(existing);
      // The holder renews its own lock, also after its TTL ran out; the claim
      // in renewLock fails if someone else reclaimed it meanwhile.
      if (owner && existing && existing.owner === owner) {
        const renewed = renewLock(lockPath, existing, record);
        if (renewed) return renewed;
        continue; // the lock vanished (released meanwhile): try to create it
      }
      if (stale && breakStale && attempt === 0) {
        const claimPath = `${lockPath}.reclaim.${process.pid}.${Date.now()}.${Math.random().toString(16).slice(2, 8)}`;
        try {
          fs.renameSync(lockPath, claimPath);
        } catch {
          // Another process already reclaimed or replaced the lock; fail closed.
          continue;
        }
        const claimed = withLease(readLockRecord(claimPath), lockPath);
        const claimedEval = evaluateStale(claimed);
        if (claimedEval.stale) {
          try {
            fs.unlinkSync(claimPath);
          } catch {
            // ignore cleanup error
          }
          continue;
        }
        // A fresh active lock replaced the stale one just before our rename — restore without clobbering a 3rd racer.
        try {
          fs.linkSync(claimPath, lockPath);
        } catch {
          // Another racer already acquired lockPath; do not overwrite it.
        }
        try {
          fs.unlinkSync(claimPath);
        } catch {
          // ignore
        }
        return {
          acquired: false,
          lockPath,
          stale: false,
          staleReason: 'active',
          existing: claimed,
          message: `Active lock held by ${claimed?.owner || 'unknown'} until ${claimed?.expiresAt || 'unknown'}. Fail-closed to prevent concurrent write collision.`,
        };
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

// Re-entry by the holder: write a lease for this exact lock (owner +
// acquiredAt), then check the lock file still is that lock. The lock file is
// never moved or rewritten, so there is no moment without a lock and no lock
// of another owner can be overwritten. Returns null when the lock vanished
// (released meanwhile), so the caller can try to create it.
function renewLock(lockPath, existing, fresh) {
  const lease = {
    schema: 'sdd-task-lock-lease/v1',
    owner: existing.owner,
    acquiredAt: existing.acquiredAt,
    renewedAt: fresh.acquiredAt,
    expiresAt: fresh.expiresAt,
  };
  const tmpPath = `${leasePath(lockPath)}.${process.pid}.${Date.now()}.${Math.random().toString(16).slice(2, 8)}`;
  fs.writeFileSync(tmpPath, `${JSON.stringify(lease, null, 2)}\n`, { encoding: 'utf8', mode: 0o600, flag: 'wx' });
  try {
    fs.renameSync(tmpPath, leasePath(lockPath));
  } catch (err) {
    removeQuietly(tmpPath);
    throw err;
  }
  const current = readLockRecord(lockPath);
  if (current && current.owner === existing.owner && current.acquiredAt === existing.acquiredAt) {
    return { acquired: true, reentrant: true, lockPath, record: withLease(current, lockPath) };
  }
  // The lock changed hands (or was released) after it was read: withdraw the
  // lease so nothing is left behind; it never applied to another lock anyway.
  const leftover = readLockRecord(leasePath(lockPath));
  if (leftover && leftover.owner === lease.owner && leftover.acquiredAt === lease.acquiredAt) removeQuietly(leasePath(lockPath));
  if (!current) return null;
  return {
    acquired: false,
    lockPath,
    stale: false,
    existing: current,
    message: `Lock changed while renewing; now held by ${current.owner || 'unknown'}.`,
  };
}

export function releaseLock({ feature, taskId = null, projectRoot = null, owner = null, force = false }) {
  const root = resolveExplicitOrAutoRoot(projectRoot);
  const name = lockFileName(feature, taskId);
  const lockPath = path.join(root, '.sdd', 'locks', name);
  if (!fs.existsSync(lockPath)) {
    return { released: true, existed: false, lockPath };
  }
  const existing = readLockRecord(lockPath);
  if (!force && existing?.owner && (!owner || existing.owner !== owner)) {
    return {
      released: false,
      existed: true,
      lockPath,
      existing,
      message: owner
        ? `Lock is owned by '${existing.owner}', not '${owner}'. Pass --force to override.`
        : `Lock is owned by '${existing.owner}'. Pass matching --owner or --force to release.`,
    };
  }
  fs.unlinkSync(lockPath);
  removeQuietly(leasePath(lockPath));
  return { released: true, existed: true, lockPath };
}

/**
 * Disposable lock handle for TC39 Explicit Resource Management (`using` / `await using`, ADR-0055).
 * Automatically releases the acquired lock when leaving scope.
 */
export function acquireTaskLockHandle(options) {
  const res = acquireLock(options);
  let disposed = false;
  const release = () => {
    if (disposed || !res.acquired) return { released: false, alreadyDisposed: disposed };
    disposed = true;
    return releaseLock({
      feature: options.feature,
      taskId: options.taskId ?? null,
      projectRoot: options.projectRoot ?? null,
      owner: res.record?.owner ?? options.owner ?? null,
    });
  };
  return {
    ...res,
    release,
    [Symbol.dispose]() {
      release();
    },
    async [Symbol.asyncDispose]() {
      release();
    },
  };
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

const isMain = isMainModule(import.meta.url, 'task-lock.mjs');

if (isMain) {
  const opts = parseArgs(process.argv.slice(2));
  if (!['acquire', 'release', 'status'].includes(opts.cmd) || !opts.feature) {
    process.stderr.write(
      'Usage: node task-lock.mjs <acquire|release|status> --feature <slug> [--task <T-NNN>] [--root <dir>] [--owner <id>] [--ttl <sec>] [--break-stale] [--force]\n'
        + '       acquire requires --owner <id>.\n',
    );
    process.exit(2);
  }
  if (opts.cmd === 'acquire' && !opts.owner) {
    process.stderr.write(
      'task-lock: acquire needs --owner <id> (for example the ship run id). This process exits right away, so a lock tied to it would be stale at once.\n',
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
