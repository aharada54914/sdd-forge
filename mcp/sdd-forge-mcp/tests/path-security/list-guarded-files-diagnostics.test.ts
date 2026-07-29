/**
 * AC-005 / AC-006 (REQ-003, issue #132): `path-guard.ts` gains
 * `listGuardedFilesWithDiagnostics`, which reports WHY a directory scan failed
 * — a guard denial, a top-level `readdirSync` failure, or a mid-walk
 * `readdirSync`/`statSync` failure — instead of collapsing all three into the
 * same `[]` that a genuinely empty, successfully-read directory returns. The
 * existing `listGuardedFiles` keeps its exact signature and exact behaviour
 * (BL-003) as a thin wrapper.
 *
 * Co-located with `denylist.test.ts` / `traversal-and-symlink.test.ts` because
 * that pair already owns `path-guard.ts`'s allowlist/denylist/traversal
 * coverage (design.md Design Decisions fixes this file's path).
 *
 * security-spec.md Boundary B3's STRIDE row names the hazard these cases exist
 * to catch: "a naive refactor moves the `isAllowlisted`/`isDenylisted` checks
 * inside the new `try`/`catch`, causing a denylist rejection to be silently
 * reinterpreted as a mere I/O error rather than a hard deny." Every
 * guard-validation sub-case below is therefore built on a directory that is
 * REAL, READABLE and NON-EMPTY, and asserts `files` is empty AND that no entry
 * name from inside it appears anywhere in the result — assertions a swallowed
 * guard check could not satisfy, because the walk would have listed the
 * directory before the error was recorded.
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import { chmodSync, mkdirSync, readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import {
  listGuardedFiles,
  listGuardedFilesWithDiagnostics,
} from "../../src/path-guard.js";
import type { SddRoot } from "../../src/root.js";
import { makeTempSddRoot, makeSymlink, writeFile } from "../test-helpers.js";
import { findSddForgeRepoRoot, makeRealRepoRoot } from "../parsers-state/test-helpers.js";

const DENYLISTED_DIR_BASENAME = ".env";
const SECRET_MARKER = "top-secret-contents-do-not-leak";

/**
 * AC-006 / BL-003 leg: the legacy function's output must equal the new
 * function's `files`, compared element by element (order-sensitive, string
 * identity) rather than only as an unordered set.
 */
function assertWrapperIdentical(
  root: SddRoot,
  relDir: string,
  label: string,
): string[] {
  const legacy = listGuardedFiles(root, relDir);
  const withDiagnostics = listGuardedFilesWithDiagnostics(root, relDir);
  assert.equal(
    legacy.length,
    withDiagnostics.files.length,
    `${label}: listGuardedFiles returned ${legacy.length} paths, listGuardedFilesWithDiagnostics().files returned ${withDiagnostics.files.length}`,
  );
  for (let i = 0; i < legacy.length; i += 1) {
    assert.equal(
      legacy[i],
      withDiagnostics.files[i],
      `${label}: element ${i} differs between listGuardedFiles and listGuardedFilesWithDiagnostics().files`,
    );
  }
  assert.deepEqual(legacy, withDiagnostics.files, label);
  return legacy;
}

// ---------------------------------------------------------------------------
// TEST-005 (AC-005) — the three named sub-cases, reported individually and
// distinguishable by errors.length.
// ---------------------------------------------------------------------------

test("TEST-005 sub-case (a) (AC-005): a genuinely empty, readable allowlisted directory returns { files: [], errors: [] }", () => {
  const { root, cleanup } = makeTempSddRoot("lgfd-empty-readable");
  try {
    mkdirSync(join(root.path, "reports", "quality-gate"), { recursive: true });

    const result = listGuardedFilesWithDiagnostics(root, "reports/quality-gate");

    assert.deepEqual(result.files, []);
    assert.deepEqual(result.errors, []);
    // Sub-case (a) is the errors.length === 0 case; (b) and (c) are >= 1.
    assert.equal(result.errors.length, 0);
    assertWrapperIdentical(root, "reports/quality-gate", "sub-case (a)");
  } finally {
    cleanup();
  }
});

test("TEST-005 sub-case (b1) (AC-005): a relDir that does not exist returns files: [] plus the not-found guard reason", () => {
  const { root, cleanup } = makeTempSddRoot("lgfd-not-found");
  try {
    const result = listGuardedFilesWithDiagnostics(root, "reports/no-such-dir");

    assert.deepEqual(result.files, []);
    assert.equal(result.errors.length, 1);
    assert.equal(result.errors[0]?.path, "reports/no-such-dir");
    assert.equal(
      result.errors[0]?.reason,
      "Path does not exist: reports/no-such-dir",
      "the errors[] entry must carry resolveGuardedDirectory's own denial message",
    );
    assertWrapperIdentical(root, "reports/no-such-dir", "sub-case (b1)");
  } finally {
    cleanup();
  }
});

test("TEST-005 sub-case (b2) (AC-005, security-spec B3): a READABLE, NON-EMPTY directory outside the allowlist is denied BEFORE any walk-level readdirSync", () => {
  const { root, cleanup } = makeTempSddRoot("lgfd-outside-allowlist");
  try {
    // The denied fixture: real, readable, and holding two files a walk would
    // certainly return if it ever ran.
    writeFile(root.path, "plugins/some-plugin/script.sh", "#!/bin/sh\necho hi\n");
    writeFile(root.path, "plugins/some-plugin/nested/notes.md", "notes\n");

    // Positive control of the SAME shape under an allowlisted parent, so that
    // `files: []` below cannot be an artefact of an unwalkable fixture: the
    // walk demonstrably lists exactly this layout when the guard permits it.
    writeFile(root.path, "reports/control-plugin/script.sh", "#!/bin/sh\necho hi\n");
    writeFile(root.path, "reports/control-plugin/nested/notes.md", "notes\n");
    const control = listGuardedFilesWithDiagnostics(root, "reports/control-plugin");
    assert.deepEqual(control.files.slice().sort(), [
      "reports/control-plugin/nested/notes.md",
      "reports/control-plugin/script.sh",
    ]);
    assert.deepEqual(control.errors, []);

    const denied = listGuardedFilesWithDiagnostics(root, "plugins/some-plugin");

    assert.deepEqual(
      denied.files,
      [],
      "the allowlist check must short-circuit before the walk; a non-empty files[] here means the walk ran on a denied path",
    );
    assert.equal(denied.errors.length, 1);
    assert.equal(denied.errors[0]?.path, "plugins/some-plugin");
    assert.equal(
      denied.errors[0]?.reason,
      "Path is outside the allowlisted directories.",
      "the reason must be the guard's own hard-deny message, not a swallowed I/O error",
    );
    // A denial reinterpreted as an I/O error would carry an errno code here.
    assert.doesNotMatch(denied.errors[0]?.reason ?? "", /ENOENT|EACCES|EPERM|ENOTDIR/);
    // No entry name from inside the denied directory may appear anywhere in
    // the result — it could only get there via a walk that must not have run.
    const serialized = JSON.stringify(denied);
    assert.ok(!serialized.includes("script.sh"), serialized);
    assert.ok(!serialized.includes("notes.md"), serialized);

    assertWrapperIdentical(root, "plugins/some-plugin", "sub-case (b2)");
  } finally {
    cleanup();
  }
});

test("TEST-005 sub-case (b3) (AC-005, security-spec B3): a denylisted directory reached through an allowlisted parent is denied BEFORE any walk-level readdirSync", () => {
  const { root, cleanup } = makeTempSddRoot("lgfd-denylisted-dir");
  try {
    // `reports/` IS allowlisted, so this fixture isolates the DENYLIST leg
    // specifically: only isDenylisted can reject it, and only if that check
    // still runs before the walk.
    writeFile(root.path, `reports/${DENYLISTED_DIR_BASENAME}/leak.txt`, SECRET_MARKER);

    const denied = listGuardedFilesWithDiagnostics(
      root,
      `reports/${DENYLISTED_DIR_BASENAME}`,
    );

    assert.deepEqual(
      denied.files,
      [],
      "a denylist rejection must be a hard deny, never a walk whose failure is recorded afterwards",
    );
    assert.equal(denied.errors.length, 1);
    assert.equal(denied.errors[0]?.path, `reports/${DENYLISTED_DIR_BASENAME}`);
    assert.equal(denied.errors[0]?.reason, "Path matches a denylisted file.");
    assert.doesNotMatch(denied.errors[0]?.reason ?? "", /ENOENT|EACCES|EPERM|ENOTDIR/);

    const serialized = JSON.stringify(denied);
    assert.ok(!serialized.includes("leak.txt"), serialized);
    assert.ok(!serialized.includes(SECRET_MARKER), serialized);

    assertWrapperIdentical(root, `reports/${DENYLISTED_DIR_BASENAME}`, "sub-case (b3)");
  } finally {
    cleanup();
  }
});

test("TEST-005 sub-case (c1) (AC-005): a mid-walk statSync failure is reported while every readable sibling is still collected", (t) => {
  const { root, cleanup } = makeTempSddRoot("lgfd-midwalk-stat");
  try {
    writeFile(root.path, "reports/scan/a-sib.md", "a\n");
    writeFile(root.path, "reports/scan/z-sib.md", "z\n");

    const scanDir = join(root.path, "reports", "scan");
    try {
      // statSync follows symlinks, so a dangling link throws ENOENT mid-walk.
      // Same fixture technique as traversal-and-symlink.test.ts.
      makeSymlink(join(scanDir, "no-such-target"), join(scanDir, "m-dangling"));
    } catch (error) {
      t.skip(
        `SKIP REASON: this host refused to create a symlink (${
          error instanceof Error ? error.message : String(error)
        }); an unprivileged Windows runner without Developer Mode cannot build the dangling-symlink fixture. The order-independent variant of this sub-case is TEST-005 (c2).`,
      );
      return;
    }

    // Captured before the call so the assertions below can speak about the
    // order this specific run's filesystem actually produced.
    const observedOrder = readdirSync(scanDir);
    const result = listGuardedFilesWithDiagnostics(root, "reports/scan");

    assert.deepEqual(
      result.files.slice().sort(),
      ["reports/scan/a-sib.md", "reports/scan/z-sib.md"],
      "the walk must CONTINUE past a per-entry statSync failure, dropping no sibling (requirements.md Edge Cases)",
    );
    assert.equal(result.errors.length, 1, JSON.stringify(result.errors));
    assert.equal(result.errors[0]?.path, "reports/scan/m-dangling");
    assert.match(result.errors[0]?.reason ?? "", /ENOENT|no such file/i);

    // Every sibling this run's readdirSync order placed AFTER the failing
    // entry is still collected, i.e. the loop `continue`d rather than aborting.
    const failIndex = observedOrder.indexOf("m-dangling");
    assert.ok(failIndex >= 0, `m-dangling missing from readdirSync order ${JSON.stringify(observedOrder)}`);
    for (const name of observedOrder.slice(failIndex + 1)) {
      if (!name.endsWith(".md")) {
        continue;
      }
      assert.ok(
        result.files.includes(`reports/scan/${name}`),
        `sibling ${name}, which this run's readdirSync order placed AFTER the failing entry (${JSON.stringify(observedOrder)}), must still be collected`,
      );
    }

    assertWrapperIdentical(root, "reports/scan", "sub-case (c1)");
  } finally {
    cleanup();
  }
});

test("TEST-005 sub-case (c2) (AC-005): a mid-walk readdirSync failure is reported while siblings both before and after it are still collected", (t) => {
  if (process.platform === "win32") {
    t.skip(
      "SKIP REASON: mode 0o000 does not deny directory listing on Windows/NTFS, so this fixture cannot construct a readdirSync failure there. The portable statSync variant of this sub-case is TEST-005 (c1), which runs on every OS.",
    );
    return;
  }
  if (typeof process.getuid === "function" && process.getuid() === 0) {
    t.skip(
      "SKIP REASON: running as uid 0 — POSIX permission bits do not deny root, so mode 0o000 cannot produce a readdirSync failure. TEST-005 (c1) still covers the mid-walk failure path.",
    );
    return;
  }

  const { root, cleanup } = makeTempSddRoot("lgfd-midwalk-readdir");
  const lockedDir = join(root.path, "reports", "perm", "locked");
  try {
    // The failing entry is a SUBDIRECTORY, so the walk's `return` exits only
    // that recursion level. Both a plain-file sibling and a directory sibling
    // are therefore collected regardless of the host's readdirSync ordering —
    // this sub-case's "before AND after" proof does not depend on entry order.
    writeFile(root.path, "reports/perm/top.md", "top\n");
    writeFile(root.path, "reports/perm/other/z.md", "z\n");
    writeFile(root.path, "reports/perm/locked/hidden.md", "hidden\n");
    chmodSync(lockedDir, 0o000);

    const result = listGuardedFilesWithDiagnostics(root, "reports/perm");

    assert.deepEqual(result.files.slice().sort(), [
      "reports/perm/other/z.md",
      "reports/perm/top.md",
    ]);
    assert.ok(
      !result.files.includes("reports/perm/locked/hidden.md"),
      "the unreadable subdirectory's contents must not appear in files[]",
    );
    assert.equal(result.errors.length, 1, JSON.stringify(result.errors));
    assert.equal(result.errors[0]?.path, "reports/perm/locked");
    assert.match(result.errors[0]?.reason ?? "", /EACCES|EPERM|permission denied/i);

    assertWrapperIdentical(root, "reports/perm", "sub-case (c2)");
  } finally {
    try {
      chmodSync(lockedDir, 0o755);
    } catch {
      // Best effort: the fixture is under mktemp and is removed next anyway.
    }
    cleanup();
  }
});

test("TEST-005 (AC-005): the three sub-cases are distinguishable by errors.length and never collapse into one another", () => {
  const { root, cleanup } = makeTempSddRoot("lgfd-distinguishable");
  try {
    mkdirSync(join(root.path, "reports", "empty-dir"), { recursive: true });
    writeFile(root.path, "reports/scan/a-sib.md", "a\n");

    const emptyButReadable = listGuardedFilesWithDiagnostics(root, "reports/empty-dir");
    const guardDenied = listGuardedFilesWithDiagnostics(root, "reports/no-such-dir");

    // Before this feature, both of the above were the identical `[]`. The
    // whole point of REQ-003 is that they no longer are.
    assert.deepEqual(listGuardedFiles(root, "reports/empty-dir"), []);
    assert.deepEqual(listGuardedFiles(root, "reports/no-such-dir"), []);
    assert.deepEqual(emptyButReadable.files, guardDenied.files);
    assert.notDeepEqual(
      emptyButReadable.errors,
      guardDenied.errors,
      "an empty-but-readable scan and a failed scan must be distinguishable",
    );
    assert.equal(emptyButReadable.errors.length, 0);
    assert.equal(guardDenied.errors.length, 1);

    // A successful, non-empty scan reports no errors either.
    const populated = listGuardedFilesWithDiagnostics(root, "reports/scan");
    assert.deepEqual(populated.files, ["reports/scan/a-sib.md"]);
    assert.deepEqual(populated.errors, []);
  } finally {
    cleanup();
  }
});

// ---------------------------------------------------------------------------
// TEST-006 (AC-006 / BL-003) — listGuardedFiles' behaviour is unchanged for
// every fixture its 3 existing call sites' own suites already use.
// ---------------------------------------------------------------------------

test("TEST-006 (AC-006): quality-report.ts's own aggregation fixture lists byte-identically through both functions", () => {
  const { root, cleanup } = makeTempSddRoot("lgfd-parity-quality-report");
  try {
    // Byte-for-byte the fixture tests/parsers-state/quality-report.test.ts's
    // "listQualityReports aggregates reports and failures across a directory"
    // case builds.
    writeFile(
      root.path,
      "reports/quality-gate/T-001.md",
      ["Task ID: T-001", "VERDICT: PASS", "Critical: 0", "Major: 0", "Minor: 0", ""].join("\n"),
    );
    writeFile(
      root.path,
      "reports/quality-gate/T-002.md",
      ["Task ID: T-002", "no verdict line at all", ""].join("\n"),
    );
    writeFile(root.path, "reports/quality-gate/.gitkeep", "");

    const files = assertWrapperIdentical(root, "reports/quality-gate", "quality-report fixture");
    // Pinned to a literal, not merely to the new function's own output.
    assert.deepEqual(files.slice().sort(), [
      "reports/quality-gate/.gitkeep",
      "reports/quality-gate/T-001.md",
      "reports/quality-gate/T-002.md",
    ]);
    assert.deepEqual(
      listGuardedFilesWithDiagnostics(root, "reports/quality-gate").errors,
      [],
    );
  } finally {
    cleanup();
  }
});

test("TEST-006 (AC-006): review-ticket.ts's own aggregation fixture lists byte-identically through both functions", () => {
  const { root, cleanup } = makeTempSddRoot("lgfd-parity-review-ticket");
  try {
    // Byte-for-byte the fixture tests/parsers-state/review-ticket.test.ts's
    // "listReviewTickets ignores non-yml files ..." case builds.
    writeFile(root.path, "docs/review-tickets/.gitkeep", "");
    writeFile(
      root.path,
      "docs/review-tickets/RT-20260701-010.yml",
      ["ticket_id: RT-20260701-010", "status: open", "severity: critical", ""].join("\n"),
    );
    writeFile(root.path, "docs/review-tickets/RT-broken.yml", "status: [unterminated\n");

    const files = assertWrapperIdentical(root, "docs/review-tickets", "review-ticket fixture");
    assert.deepEqual(files.slice().sort(), [
      "docs/review-tickets/.gitkeep",
      "docs/review-tickets/RT-20260701-010.yml",
      "docs/review-tickets/RT-broken.yml",
    ]);
  } finally {
    cleanup();
  }
});

test("TEST-006 (AC-006): report-lookup.ts's nested reports-directory scan shape lists byte-identically through both functions", () => {
  const { root, cleanup } = makeTempSddRoot("lgfd-parity-report-lookup");
  try {
    // anyFileContaining()'s scan shape: a reports directory with per-feature
    // subdirectories, walked recursively.
    writeFile(root.path, "reports/implementation/demo/T-001.md", "mentions T-001\n");
    writeFile(root.path, "reports/implementation/demo/T-002.md", "mentions T-002\n");
    writeFile(root.path, "reports/implementation/other/T-003.md", "mentions T-003\n");

    const files = assertWrapperIdentical(root, "reports/implementation", "report-lookup fixture");
    assert.deepEqual(files.slice().sort(), [
      "reports/implementation/demo/T-001.md",
      "reports/implementation/demo/T-002.md",
      "reports/implementation/other/T-003.md",
    ]);
  } finally {
    cleanup();
  }
});

test("TEST-006 (AC-006): the real repository directories the 3 call sites scan list byte-identically through both functions", () => {
  const root = makeRealRepoRoot();
  for (const relDir of [
    "reports/quality-gate",
    "docs/review-tickets",
    "reports/implementation",
    "docs/workflow-improvements",
  ]) {
    const files = assertWrapperIdentical(root, relDir, `real repo ${relDir}`);
    assert.ok(files.length >= 1, `expected at least one file under ${relDir}`);
    for (const file of files) {
      assert.ok(file.startsWith(`${relDir}/`), `${file} is not under ${relDir}`);
    }
    assert.deepEqual(listGuardedFilesWithDiagnostics(root, relDir).errors, []);
  }
});

test("TEST-006 (AC-006): every guard-failure class still collapses to [] for the legacy function", () => {
  const { root, cleanup } = makeTempSddRoot("lgfd-parity-failures");
  try {
    writeFile(root.path, "plugins/x/script.sh", "#!/bin/sh\n");
    writeFile(root.path, `reports/${DENYLISTED_DIR_BASENAME}/leak.txt`, SECRET_MARKER);

    const failureClasses: Array<[string, string]> = [
      ["not-found", "reports/nope"],
      ["outside-allowlist", "plugins/x"],
      ["denylisted-basename", `reports/${DENYLISTED_DIR_BASENAME}`],
      ["parent-traversal", "specs/../.."],
      ["absolute-path", "/etc"],
      ["empty-path", ""],
      ["backslash-path", "specs\\x"],
      ["not-a-directory", "AGENTS.md"],
    ];

    for (const [label, relDir] of failureClasses) {
      const legacy = assertWrapperIdentical(root, relDir, `failure class ${label}`);
      assert.deepEqual(legacy, [], `failure class ${label} must still yield [] from listGuardedFiles`);
      const withDiagnostics = listGuardedFilesWithDiagnostics(root, relDir);
      assert.equal(
        withDiagnostics.errors.length,
        1,
        `failure class ${label} must be reported exactly once in errors[]: ${JSON.stringify(withDiagnostics.errors)}`,
      );
      assert.equal(withDiagnostics.errors[0]?.path, relDir);
      assert.ok(
        (withDiagnostics.errors[0]?.reason.length ?? 0) > 0,
        `failure class ${label} must carry a non-empty reason`,
      );
    }
  } finally {
    cleanup();
  }
});

test("TEST-006 (AC-006, BL-003): none of the 3 existing call sites was changed to opt into the diagnostics function", () => {
  const repoRoot = findSddForgeRepoRoot();
  const callSites = [
    "mcp/sdd-forge-mcp/src/parsers/report-lookup.ts",
    "mcp/sdd-forge-mcp/src/parsers/quality-report.ts",
    "mcp/sdd-forge-mcp/src/parsers/review-ticket.ts",
  ];
  for (const relPath of callSites) {
    const source = readFileSync(join(repoRoot, ...relPath.split("/")), "utf-8");
    assert.ok(
      source.includes("listGuardedFiles(root, relDir)"),
      `${relPath} must still call listGuardedFiles(root, relDir) unchanged`,
    );
    assert.ok(
      !source.includes("listGuardedFilesWithDiagnostics"),
      `${relPath} must NOT opt into listGuardedFilesWithDiagnostics in this task (requirements.md Non-goals; T-004 owns report-lookup.ts's opt-in)`,
    );
  }
});
