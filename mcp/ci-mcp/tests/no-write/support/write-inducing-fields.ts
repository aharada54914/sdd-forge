/**
 * Shared denylist of write-inducing field names (REQ-003) used by both
 * T-006's static schema check (input-schema-fields.test.ts) and its
 * behavioral probe (no-write-behavior.test.ts), so the two halves of AC-006
 * stay in lockstep: any field name this list forbids from appearing in a
 * tool's input SHAPE is also exercised as a rejected extra field at
 * runtime.
 */
export const WRITE_INDUCING_FIELD_NAMES: ReadonlySet<string> = new Set([
  "action",
  "method",
  "body",
  "command",
  "cmd",
  "payload",
  "args",
  "exec",
  "operation",
  "verb",
]);
