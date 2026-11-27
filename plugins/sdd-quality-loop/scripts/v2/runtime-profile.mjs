#!/usr/bin/env node
/**
 * runtime-profile.mjs — Zero-overhead 3-phase profiler over node:diagnostics_channel.
 *
 * Channels:
 *   - sdd-forge:startup  (process / module startup checkpoints)
 *   - sdd-forge:scan     (file discovery, hashing, placeholder / sensor scans)
 *   - sdd-forge:exec     (external command / git / validator subprocess executions)
 *
 * Zero external dependencies. When no subscriber is attached (`SDD_PROFILE` unset),
 * channel checks short-circuit without allocating event payloads.
 */
import diagnosticsChannel from 'node:diagnostics_channel';
import { performance } from 'node:perf_hooks';

export const CHANNELS = Object.freeze({
  startup: diagnosticsChannel.channel('sdd-forge:startup'),
  scan: diagnosticsChannel.channel('sdd-forge:scan'),
  exec: diagnosticsChannel.channel('sdd-forge:exec'),
});

const PROFILE_EVENTS = [];
let subscriberAttached = false;

export function attachProfileCollector(sink = null) {
  if (subscriberAttached) return () => {};
  const handlers = new Map();
  for (const [phase, channel] of Object.entries(CHANNELS)) {
    const handler = (message) => {
      const event = { phase, ...message };
      PROFILE_EVENTS.push(event);
      if (typeof sink === 'function') sink(event);
    };
    channel.subscribe(handler);
    handlers.set(channel, handler);
  }
  subscriberAttached = true;
  return () => {
    for (const [channel, handler] of handlers.entries()) {
      channel.unsubscribe(handler);
    }
    subscriberAttached = false;
  };
}

export function getProfileEvents() {
  return [...PROFILE_EVENTS];
}

export function resetProfileEvents() {
  PROFILE_EVENTS.length = 0;
}

export function recordStartup(component, detail = {}) {
  const ch = CHANNELS.startup;
  if (!ch.hasSubscribers) return;
  ch.publish({
    component,
    durationMs: Number(performance.now().toFixed(3)),
    nodeVersion: process.versions.node,
    compileCache: process.env.NODE_COMPILE_CACHE || null,
    ...detail,
  });
}

export function profilePhase(phase, label, fn, meta = {}) {
  const ch = CHANNELS[phase];
  if (!ch || !ch.hasSubscribers) return fn();
  const started = performance.now();
  try {
    const value = fn();
    if (value && typeof value.then === 'function') {
      return value.then(
        (resolved) => {
          ch.publish({ label, durationMs: Number((performance.now() - started).toFixed(3)), ok: true, ...meta });
          return resolved;
        },
        (err) => {
          ch.publish({
            label,
            durationMs: Number((performance.now() - started).toFixed(3)),
            ok: false,
            error: err instanceof Error ? err.message : String(err),
            ...meta,
          });
          throw err;
        },
      );
    }
    ch.publish({ label, durationMs: Number((performance.now() - started).toFixed(3)), ok: true, ...meta });
    return value;
  } catch (err) {
    ch.publish({
      label,
      durationMs: Number((performance.now() - started).toFixed(3)),
      ok: false,
      error: err instanceof Error ? err.message : String(err),
      ...meta,
    });
    throw err;
  }
}

if (process.env.SDD_PROFILE === '1') {
  attachProfileCollector();
  process.once('beforeExit', () => {
    const totals = { startup: 0, scan: 0, exec: 0 };
    for (const ev of PROFILE_EVENTS) {
      if (typeof ev.durationMs === 'number' && ev.phase in totals) {
        totals[ev.phase] = Number((totals[ev.phase] + ev.durationMs).toFixed(3));
      }
    }
    process.stderr.write(
      `${JSON.stringify({ schema: 'sdd-runtime-profile/v1', totalsMs: totals, events: PROFILE_EVENTS })}\n`,
    );
  });
}
