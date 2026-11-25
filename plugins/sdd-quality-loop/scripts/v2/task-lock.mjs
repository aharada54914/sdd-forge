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
import { randomUUID } from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { assertValidFeatureName, resolveExplicitOrAutoRoot, isMainModule } from './guardrails-lib.mjs';

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
    return err?.code !== 'ESRCH';
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
  const record = withLease(readLockRecord(lockPath), lockPath);
  const { stale, reason } = evaluateStale(record);
  return { locked: true, stale, staleReason: reason, lockPath, record };
}

// Publish a unique intent before inspecting other writers. Two overlapping
// writers cannot both see an empty set of peers: the later publication sees
// the earlier intent until its operation finishes. A crashed local process's
// intent has a unique name, so cleaning it can never unlink a successor's.
function withLockMutation(lockPath, busy, operation) {
  // A directory per lock also preserves the filesystem's own case folding.
  // Keep the empty directory between calls so a new entrant always sees the
  // same namespace, including when release and acquire overlap.
  const dir = path.join(path.dirname(lockPath), '..', 'lock-mutations', path.basename(lockPath));
  fs.mkdirSync(dir, { recursive: true });
  const host = Buffer.from(os.hostname()).toString('base64url');
  const self = `${host}.${process.pid}.${randomUUID()}`;
  const intent = path.join(dir, self);
  let peerPath;
  for (let attempt = 0; attempt < 4; attempt++) {
    fs.writeFileSync(intent, '', { flag: 'wx', mode: 0o600 });
    try {
      let contended = false;
      for (const name of fs.readdirSync(dir)) {
        if (name === self) continue;
        const [otherHost, pid] = name.split('.');
        peerPath = path.join(dir, name);
        if (otherHost === host && Number(pid) === process.pid) return { ...busy, peerIntent: peerPath };
        if (otherHost === host && /^[1-9][0-9]*$/.test(pid) && !isProcessAlive(Number(pid))) {
          removeQuietly(path.join(dir, name));
          continue;
        }
        contended = true;
        break;
      }
      if (!contended) return operation();
    } finally {
      fs.unlinkSync(intent);
    }
    if (attempt < 3) Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 4 + Math.random() * 8);
  }
  return { ...busy, peerIntent: peerPath };
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
  const lockPath = path.join(locksDir, lockFileName(feature, taskId));
  const busy = { acquired: false, lockPath, stale: false, message: 'Lock contention. Retry after the current lock operation.' };
  return withLockMutation(lockPath, busy, () => {
    const ttl = Number.isFinite(ttlSeconds) && ttlSeconds > 0 ? Math.min(ttlSeconds, 86400) : DEFAULT_TTL_SECONDS;
    const now = new Date();
    const record = {
      schema: 'sdd-task-lock/v1',
      feature,
      taskId: taskId ? taskId.toUpperCase() : null,
      owner: owner || `${os.hostname()}:${process.pid}`,
      pid: owner ? null : process.pid,
      hostname: os.hostname(),
      acquiredAt: now.toISOString(),
      expiresAt: new Date(now.getTime() + ttl * 1000).toISOString(),
    };

    if (fs.existsSync(lockPath)) {
      const existing = withLease(readLockRecord(lockPath), lockPath);
      if (owner && existing?.owner === owner) return renewLock(lockPath, existing, record) || busy;
      const { stale, reason } = evaluateStale(existing);
      if (!stale || !breakStale) {
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
      removeQuietly(leasePath(lockPath));
    }
    // Readers see the whole new record, even during stale replacement and on
    // filesystems without hard links. All mutators use the intent protocol.
    const tmpPath = `${lockPath}.new.${randomUUID()}`;
    try {
      fs.writeFileSync(tmpPath, `${JSON.stringify(record, null, 2)}\n`, { encoding: 'utf8', mode: 0o600, flag: 'wx' });
      fs.renameSync(tmpPath, lockPath);
    } finally {
      removeQuietly(tmpPath);
    }
    return { acquired: true, lockPath, record };
  });
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
  const busy = { released: false, existed: true, lockPath, message: 'Lock contention. Retry after the current lock operation.' };
  return withLockMutation(lockPath, busy, () => {
    if (!fs.existsSync(lockPath)) return { released: true, existed: false, lockPath };
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
  });
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
