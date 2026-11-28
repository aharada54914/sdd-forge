#!/usr/bin/env node
/**
 * Persistent incremental file-scan cache powered by `node:sqlite` (ADR-0055).
 *
 * Stores scanner findings keyed by `(rel_path, scanner_key)` alongside file
 * `(mtime_ms, size)` in `.sdd/scan-cache.sqlite` so unchanged files skip
 * redundant reads and regex scans across repeated `run-sdd-gate.mjs` runs.
 *
 * Automatically degrades to an in-memory cache or no-op facade when running
 * under `--permission` read-only mode or on read-only filesystems.
 */
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);

let DatabaseSyncCtor = null;
try {
  const sqlite = require('node:sqlite');
  DatabaseSyncCtor = sqlite?.DatabaseSync ?? null;
} catch {
  DatabaseSyncCtor = null;
}

const SCHEMA_SQL = `
CREATE TABLE IF NOT EXISTS file_scan_cache (
  rel_path TEXT NOT NULL,
  scanner_key TEXT NOT NULL,
  mtime_ms REAL NOT NULL,
  size INTEGER NOT NULL,
  result_json TEXT NOT NULL,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (rel_path, scanner_key)
);
`;

function createNullCache(mode = 'disabled') {
  return {
    mode,
    dbPath: null,
    get() {
      return null;
    },
    set() {},
    close() {},
    [Symbol.dispose]() {},
  };
}

export function openScanCache(projectRoot, { inMemory = false, dbPath = null } = {}) {
  if (!DatabaseSyncCtor) {
    return createNullCache('unavailable');
  }

  let targetPath = ':memory:';
  let mode = 'memory';

  if (!inMemory && projectRoot) {
    const resolved = dbPath ? path.resolve(dbPath) : path.join(path.resolve(projectRoot), '.sdd', 'scan-cache.sqlite');
    const canWrite =
      !process.permission || typeof process.permission.has !== 'function'
        ? true
        : process.permission.has('fs.write', resolved);
    if (canWrite) {
      try {
        fs.mkdirSync(path.dirname(resolved), { recursive: true });
        targetPath = resolved;
        mode = 'sqlite-file';
      } catch {
        targetPath = ':memory:';
        mode = 'memory-fallback';
      }
    } else {
      targetPath = ':memory:';
      mode = 'readonly-fallback';
    }
  }

  let db;
  try {
    db = new DatabaseSyncCtor(targetPath);
    if (mode === 'sqlite-file') {
      db.exec('PRAGMA journal_mode = WAL; PRAGMA synchronous = NORMAL;');
    }
    db.exec(SCHEMA_SQL);
  } catch {
    if (targetPath !== ':memory:') {
      try {
        db = new DatabaseSyncCtor(':memory:');
        db.exec(SCHEMA_SQL);
        mode = 'memory-fallback';
        targetPath = ':memory:';
      } catch {
        return createNullCache('error-fallback');
      }
    } else {
      return createNullCache('error-fallback');
    }
  }

  const selectStmt = db.prepare(
    'SELECT mtime_ms, size, result_json FROM file_scan_cache WHERE rel_path = ? AND scanner_key = ?',
  );
  const upsertStmt = db.prepare(`
    INSERT INTO file_scan_cache (rel_path, scanner_key, mtime_ms, size, result_json, updated_at)
    VALUES (?, ?, ?, ?, ?, ?)
    ON CONFLICT(rel_path, scanner_key) DO UPDATE SET
      mtime_ms = excluded.mtime_ms,
      size = excluded.size,
      result_json = excluded.result_json,
      updated_at = excluded.updated_at
  `);

  let closed = false;
  const close = () => {
    if (closed) return;
    closed = true;
    try {
      db.close();
    } catch {
      // ignore close errors
    }
  };

  return {
    mode,
    dbPath: targetPath === ':memory:' ? null : targetPath,
    get(relPath, scannerKey, mtimeMs, size) {
      if (closed) return null;
      try {
        const row = selectStmt.get(String(relPath), String(scannerKey));
        if (!row) return null;
        if (Number(row.mtime_ms) !== Number(mtimeMs) || Number(row.size) !== Number(size)) {
          return null;
        }
        return JSON.parse(String(row.result_json));
      } catch {
        return null;
      }
    },
    set(relPath, scannerKey, mtimeMs, size, value) {
      if (closed) return;
      try {
        upsertStmt.run(
          String(relPath),
          String(scannerKey),
          Number(mtimeMs),
          Number(size),
          JSON.stringify(value),
          Date.now(),
        );
      } catch {
        // non-fatal cache write failure
      }
    },
    close,
    [Symbol.dispose]() {
      close();
    },
  };
}
