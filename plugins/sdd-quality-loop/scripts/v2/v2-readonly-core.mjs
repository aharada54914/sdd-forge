#!/usr/bin/env node
/**
 * Compatibility re-export shim for `v2-readonly-core.ts` (ADR-0055).
 * Canonical implementation lives in `v2-readonly-core.ts` (erasable TS 7.0,
 * zero external dependencies, zero `node:fs` / `process.env` / write APIs).
 */
export * from './v2-readonly-core.ts';
