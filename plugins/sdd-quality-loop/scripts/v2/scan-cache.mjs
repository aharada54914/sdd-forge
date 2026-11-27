#!/usr/bin/env node
/**
 * scan-cache.mjs — Incremental file-scan cache backed by built-in `node:sqlite`.
 *
 * Stores placeholder/sensor scan outputs keyed by (scanner, rel_path, mtime_ms,
 * size_bytes, content_sha256) under `<root>/.sdd/scan-cache.sqlite`.
 *
 * Fail-open / read-only safe: when running under `--permission` without write
 * access or on a read-only filesystem, automatically falls back to an in-memory
 * Map so verification gates never break.
 */
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);

function loadDatabaseSync() {
  try {
    const mod = require('node:sqlite');
    return typeof mod?.DatabaseSync === 'function' ? mod.DatabaseSync : null;
  } catch {
    return null;
  }
}

export function openScanCache(projectRoot, { enabled = true, dbFileName = '.sdd/scan-cache.sqlite' } = {}) {
  const memory = new Map();
  let db = null;
  let persistent = false;
  let hits = 0;
  let misses = 0;

  if (enabled) {
    const DatabaseSync = loadDatabaseSync();
    if (DatabaseSync) {
      try {
        const dbPath = path.join(projectRoot, dbFileName);
        fs.mkdirSync(path.dirname(dbPath), { recursive: true });
        db = new DatabaseSync(dbPath);
        db.exec(`
          PRAGMA journal_mode = WAL;
          CREATE TABLE IF NOT EXISTS file_scan_cache (
            scanner TEXT NOT NULL,
            rel_path TEXT NOT NULL,
            mtime_ms REAL NOT NULL,
            size_bytes INTEGER NOT NULL,
            content_sha256 TEXT NOT NULL,
            result_json TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            PRIMARY KEY (scanner, rel_path)
          );
        `);
        persistent = true;
      } catch {
        db = null;
        persistent = false;
      }
    }
  }

  function get(scanner, relPath, statInfo, contentSha256 = null) {
    if (!enabled || !statInfo) {
      misses += 1;
      return null;
    }
    const key = `${scanner}\0${relPath}`;
    if (db) {
      try {
        const row = db
          .prepare(
            'SELECT mtime_ms, size_bytes, content_sha256, result_json FROM file_scan_cache WHERE scanner = ? AND rel_path = ?',
          )
          .get(scanner, relPath);
        if (
          row &&
          row.mtime_ms === statInfo.mtimeMs &&
          row.size_bytes === statInfo.size &&
          (contentSha256 === null || row.content_sha256 === contentSha256)
        ) {
          hits += 1;
          return JSON.parse(row.result_json);
        }
      } catch {
        // Ignore read error and treat as cache miss.
      }
    } else if (memory.has(key)) {
      const cached = memory.get(key);
      if (
        cached.mtimeMs === statInfo.mtimeMs &&
        cached.size === statInfo.size &&
        (contentSha256 === null || cached.contentSha256 === contentSha256)
      ) {
        hits += 1;
        return cached.result;
      }
    }
    misses += 1;
    return null;
  }

  function set(scanner, relPath, statInfo, contentSha256, result) {
    if (!enabled || !statInfo) return;
    const key = `${scanner}\0${relPath}`;
    if (db) {
      try {
        db.prepare(
          `INSERT INTO file_scan_cache (scanner, rel_path, mtime_ms, size_bytes, content_sha256, result_json, updated_at)
           VALUES (?, ?, ?, ?, ?, ?, ?)
           ON CONFLICT(scanner, rel_path) DO UPDATE SET
             mtime_ms = excluded.mtime_ms,
             size_bytes = excluded.size_bytes,
             content_sha256 = excluded.content_sha256,
             result_json = excluded.result_json,
             updated_at = excluded.updated_at`,
        ).run(
          scanner,
          relPath,
          statInfo.mtimeMs,
          statInfo.size,
          contentSha256 || '',
          JSON.stringify(result),
          new Date().toISOString(),
        );
      } catch {
        // Fallback silently on write error.
      }
    } else {
      memory.set(key, {
        mtimeMs: statInfo.mtimeMs,
        size: statInfo.size,
        contentSha256: contentSha256 || '',
        result,
      });
    }
  }

  function stats() {
    return { enabled, persistent, hits, misses };
  }

  function close() {
    if (db) {
      try {
        db.close();
      } catch {
        // ignore
      }
      db = null;
    }
  }

  return {
    get,
    set,
    stats,
    close,
    [Symbol.dispose]() {
      close();
    },
  };
}
