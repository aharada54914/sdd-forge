#!/usr/bin/env node
/**
 * Zero-overhead 3-channel runtime profiler built on `node:diagnostics_channel` (ADR-0055).
 *
 * Channels:
 *   - `sdd-forge:startup` — process / entrypoint cold vs warm startup latency
 *   - `sdd-forge:scan`    — filesystem traversal, hashing, and placeholder scanning
 *   - `sdd-forge:exec`    — external subprocess invocations (git, tests, validators)
 *
 * When `channel.hasSubscribers === false`, helpers execute the wrapped callback
 * directly with no allocation or timing overhead.
 */
import diagnosticsChannel from 'node:diagnostics_channel';
import { performance } from 'node:perf_hooks';

export const CHANNELS = Object.freeze({
  startup: 'sdd-forge:startup',
  scan: 'sdd-forge:scan',
  exec: 'sdd-forge:exec',
});

const startupChannel = diagnosticsChannel.channel(CHANNELS.startup);
const scanChannel = diagnosticsChannel.channel(CHANNELS.scan);
const execChannel = diagnosticsChannel.channel(CHANNELS.exec);

const CHANNEL_MAP = new Map([
  ['startup', startupChannel],
  ['scan', scanChannel],
  ['exec', execChannel],
  [CHANNELS.startup, startupChannel],
  [CHANNELS.scan, scanChannel],
  [CHANNELS.exec, execChannel],
]);

function resolveChannel(phase) {
  return CHANNEL_MAP.get(phase) ?? scanChannel;
}

export function getProfileChannel(phase) {
  return resolveChannel(phase);
}

export function recordStartup(component, extra = {}) {
  if (!startupChannel.hasSubscribers) return null;
  const payload = {
    channel: CHANNELS.startup,
    component: String(component || 'unknown'),
    uptimeMs: Number((process.uptime() * 1000).toFixed(3)),
    nodeVersion: process.version,
    compileCache: Boolean(process.env.NODE_COMPILE_CACHE),
    compileCachePortable: process.env.NODE_COMPILE_CACHE_PORTABLE === '1',
    compileCacheReadonly: process.env.NODE_COMPILE_CACHE_READONLY === '1',
    ...extra,
  };
  startupChannel.publish(payload);
  return payload;
}

export function profilePhase(phase, label, fn, meta = {}) {
  const ch = resolveChannel(phase);
  if (!ch.hasSubscribers) {
    return fn();
  }
  const t0 = performance.now();
  let ok = true;
  let errorMessage = null;
  try {
    return fn();
  } catch (err) {
    ok = false;
    errorMessage = err instanceof Error ? err.message : String(err);
    throw err;
  } finally {
    const durationMs = Number((performance.now() - t0).toFixed(3));
    ch.publish({
      channel: ch.name,
      label: String(label || 'unnamed'),
      durationMs,
      ok,
      ...(errorMessage ? { error: errorMessage } : {}),
      ...meta,
    });
  }
}

export async function profilePhaseAsync(phase, label, fn, meta = {}) {
  const ch = resolveChannel(phase);
  if (!ch.hasSubscribers) {
    return fn();
  }
  const t0 = performance.now();
  let ok = true;
  let errorMessage = null;
  try {
    return await fn();
  } catch (err) {
    ok = false;
    errorMessage = err instanceof Error ? err.message : String(err);
    throw err;
  } finally {
    const durationMs = Number((performance.now() - t0).toFixed(3));
    ch.publish({
      channel: ch.name,
      label: String(label || 'unnamed'),
      durationMs,
      ok,
      ...(errorMessage ? { error: errorMessage } : {}),
      ...meta,
    });
  }
}

export function subscribeProfile(handler) {
  const unsubs = [];
  for (const ch of [startupChannel, scanChannel, execChannel]) {
    const wrapped = (message) => handler(message, ch.name);
    ch.subscribe(wrapped);
    unsubs.push(() => ch.unsubscribe(wrapped));
  }
  return () => {
    for (const u of unsubs) u();
  };
}
