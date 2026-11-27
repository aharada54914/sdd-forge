#!/usr/bin/env node
/**
 * validate-path.ts — Shared path-validation utility for SDD gate scripts (ADR-0055).
 *
 * Buildless, zero-dependency TypeScript 7.0 (`erasableSyntaxOnly: true`) port of
 * `validate_path.py` with byte-identical diagnostic strings.
 */
import fs from 'node:fs';
import path from 'node:path';

export function validateEvidencePath(
  label: string,
  rawPath: unknown,
  root: string,
  failures: string[],
): boolean {
  const initialCount = failures.length;

  if (rawPath !== null && rawPath !== undefined && typeof rawPath !== 'string') {
    failures.push(`${label} must be a string`);
    return false;
  }
  const trimmed = typeof rawPath === 'string' ? rawPath.trim() : '';
  if (!trimmed) {
    failures.push(`${label} is missing or empty`);
    return false;
  }

  // Reject absolute POSIX paths
  if (trimmed.startsWith('/')) {
    failures.push(`${label} is an absolute path: ${rawPath}`);
    return false;
  }

  // Reject Windows drive paths (C:\...) and UNC (\\...)
  if ((trimmed.length >= 2 && trimmed[1] === ':') || trimmed.startsWith('\\\\')) {
    failures.push(`${label} is an absolute path: ${rawPath}`);
    return false;
  }

  let absRoot: string;
  let resolved: string;
  try {
    const resolvedRoot = path.resolve(root);
    absRoot = fs.existsSync(resolvedRoot) ? fs.realpathSync(resolvedRoot) : resolvedRoot;
    const candidate = path.resolve(absRoot, trimmed);
    resolved = fs.existsSync(candidate) ? fs.realpathSync(candidate) : candidate;
  } catch {
    failures.push(`${label} path could not be resolved: ${rawPath}`);
    return false;
  }

  if (!resolved.startsWith(absRoot + path.sep) && resolved !== absRoot) {
    failures.push(`${label} path escapes repo root: ${rawPath}`);
    return false;
  }

  if (!fs.existsSync(resolved)) {
    failures.push(`${label} file missing: ${rawPath}`);
  } else {
    const st = fs.statSync(resolved);
    if (!st.isFile()) {
      failures.push(`${label} is not a regular file: ${rawPath}`);
    } else if (st.size === 0) {
      failures.push(`${label} file is empty: ${rawPath}`);
    }
  }

  return failures.length === initialCount;
}
