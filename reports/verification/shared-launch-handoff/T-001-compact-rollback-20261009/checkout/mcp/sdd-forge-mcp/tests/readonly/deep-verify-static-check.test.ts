/**
 * TEST-014 / AC-014 (B2/B3 static read-only + no-exec boundary, REQ-011 /
 * REQ-008 / ADR-0008): the deep-verify implementation
 * (`src/tools/evidence.ts`) must contain, by source inspection, ZERO:
 *   - filesystem write / mutate API references,
 *   - subprocess entry points (`child_process` / spawn / exec / fork),
 *   - network entry points (http/https/net/dgram/tls, `fetch`, sockets),
 *   - dynamic code execution (`eval` / `new Function`),
 *   - signing-key acquisition references (`SDD_EVIDENCE_KEY[_FILE]`,
 *     `evidence-key`, `~/.sdd`, `homedir`, `process.env`),
 *   - direct (un-guarded) filesystem read APIs — every disk read must go
 *     through path-guard (`guardedRead` / `resolveGuarded` / `guardedExists`).
 *
 * This complements the whole-src fs-write check in `static-check.test.ts` by
 * pinning the full read-only / no-exec / no-key posture of the specific file
 * that carries the deep-verify logic. Enforced by source-text inspection with
 * no side effects.
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

function findPackageRoot(startDir: string): string {
  let dir = startDir;
  for (let i = 0; i < 10; i += 1) {
    if (existsSync(join(dir, "package.json"))) {
      return dir;
    }
    const parent = dirname(dir);
    if (parent === dir) {
      break;
    }
    dir = parent;
  }
  throw new Error(`Could not locate package root above ${startDir}`);
}

const THIS_FILE_DIR = dirname(fileURLToPath(import.meta.url));
const DEEP_VERIFY_SOURCE = join(
  findPackageRoot(THIS_FILE_DIR),
  "src",
  "tools",
  "evidence.ts",
);

/**
 * Strips `//` and block/JSDoc comments so the check inspects executable code
 * only, not prose that merely discusses filesystem/signature concepts (e.g. a
 * doc comment explaining "no signing key is read"). Best-effort (no
 * string-literal awareness); sufficient here because the deep-verify source
 * has no string content resembling a comment delimiter.
 */
function stripComments(source: string): string {
  return source
    .replace(/\/\*[\s\S]*?\*\//g, "")
    .replace(/\/\/.*$/gm, "");
}

/** fs write / mutate API names that must never appear (mirrors static-check). */
const FS_WRITE_APIS = [
  "writeFile",
  "writeFileSync",
  "appendFile",
  "appendFileSync",
  "mkdir",
  "mkdirSync",
  "rm",
  "rmSync",
  "rmdir",
  "rmdirSync",
  "unlink",
  "unlinkSync",
  "rename",
  "renameSync",
  "chmod",
  "chmodSync",
  "chown",
  "chownSync",
  "truncate",
  "truncateSync",
  "symlink",
  "symlinkSync",
  "link",
  "linkSync",
  "copyFile",
  "copyFileSync",
  "createWriteStream",
  "utimes",
  "utimesSync",
  "openSync",
  "writev",
  "writevSync",
];

/**
 * Direct filesystem READ APIs. These are legitimate only inside path-guard;
 * the deep-verify tool must reach the disk exclusively through the guarded
 * helpers, so their appearance here would mean a read bypassed the choke point.
 */
const DIRECT_FS_READ_APIS = [
  "readFileSync",
  "readFile",
  "readdirSync",
  "readdir",
  "realpathSync",
  "realpath",
  "createReadStream",
  "statSync",
  "lstatSync",
];

interface CheckGroup {
  label: string;
  patterns: RegExp[];
}

const CHECK_GROUPS: CheckGroup[] = [
  {
    label: "filesystem write API",
    patterns: FS_WRITE_APIS.map((name) => new RegExp(`\\b${name}\\b`)),
  },
  {
    label: "direct (un-guarded) filesystem read API",
    patterns: DIRECT_FS_READ_APIS.map((name) => new RegExp(`\\b${name}\\b`)),
  },
  {
    label: "subprocess entry point",
    patterns: [
      /\bchild_process\b/,
      /\bspawnSync?\b/,
      /\bexecSync\b/,
      /\bexecFileSync?\b/,
      /\bfork\s*\(/,
    ],
  },
  {
    label: "network entry point",
    patterns: [
      /from\s+["']node:(http|https|net|dgram|tls|http2)["']/,
      /require\(\s*["'](node:)?(http|https|net|dgram|tls|http2)["']/,
      /\bfetch\s*\(/,
      /\bXMLHttpRequest\b/,
      /\bWebSocket\b/,
      /\bcreateConnection\b/,
    ],
  },
  {
    label: "dynamic code execution",
    patterns: [/\beval\s*\(/, /\bnew\s+Function\s*\(/],
  },
  {
    label: "signing-key acquisition reference",
    patterns: [
      /SDD_EVIDENCE_KEY/,
      /SDD_EVIDENCE_SIGSTORE/,
      /evidence-key/,
      /\bhomedir\b/,
      /\bprocess\.env\b/,
      /\.sdd\b/,
    ],
  },
];

test("src/tools/evidence.ts has zero write/subprocess/network/eval/key-read references", () => {
  const code = stripComments(readFileSync(DEEP_VERIFY_SOURCE, "utf-8"));
  const violations: string[] = [];
  for (const group of CHECK_GROUPS) {
    for (const pattern of group.patterns) {
      if (pattern.test(code)) {
        violations.push(`${group.label}: matched /${pattern.source}/`);
      }
    }
  }
  assert.deepEqual(
    violations,
    [],
    `read-only / no-exec / no-key violation(s) in src/tools/evidence.ts:\n${violations.join("\n")}`,
  );
});

test("src/tools/evidence.ts reaches the disk only through path-guard's guarded helpers", () => {
  const code = stripComments(readFileSync(DEEP_VERIFY_SOURCE, "utf-8"));
  // Positive control: the tool must import at least one guarded read helper,
  // proving its disk access is routed through the path-guard choke point.
  const importsGuardedHelper =
    /from\s+["']\.\.\/path-guard\.js["']/.test(code) &&
    /\b(guardedRead|resolveGuarded|guardedExists)\b/.test(code);
  assert.equal(
    importsGuardedHelper,
    true,
    "expected src/tools/evidence.ts to import guarded read helpers from ../path-guard.js",
  );
});
