import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import { syncBuiltinESMExports } from "node:module";
import { parseTaskState } from "../../src/parsers/tasks.js";
import { listActiveSpecs } from "../../src/tools/core.js";
import { makeTempSddRoot, writeFile } from "../test-helpers.js";

function tasks(): string {
  return ["Done", "Done", "Implementation Complete", "Implementation Complete"]
    .map((status, i) => `## T-00${i + 1}\nApproval: Approved\nStatus: ${status}\nRisk: low\n`).join("\n");
}

for (const boundary of ["parseTaskState", "listActiveSpecs"]) {
  test(`${boundary}: report reads are bounded by files, not completed tasks`, (t) => {
    const fixture = makeTempSddRoot("report-reuse");
    t.after(fixture.cleanup);
    writeFile(fixture.dir, "AGENTS.md", "## Active Spec Directories\n\n- `specs/one/`\n- `specs/two/`\n");
    for (const feature of ["one", "two"]) writeFile(fixture.dir, `specs/${feature}/tasks.md`, tasks());
    for (const dir of ["quality-gate", "implementation"]) {
      writeFile(fixture.dir, `reports/${dir}/all.md`, "T-001 T-002 T-003 T-004\nVERDICT: PASS\n");
    }
    const original = fs.readFileSync;
    const reads: string[] = [];
    t.mock.method(fs, "readFileSync", (...args: Parameters<typeof fs.readFileSync>) => {
      reads.push(String(args[0]).replaceAll("\\", "/"));
      return Reflect.apply(original, fs, args);
    });
    syncBuiltinESMExports();
    t.after(() => { t.mock.restoreAll(); syncBuiltinESMExports(); });
    if (boundary === "parseTaskState") {
      const result = parseTaskState(fixture.root, "one", "specs/one/tasks.md");
      assert.ok(result.ok);
      assert.equal(result.data.tasks.length, 4);
      assert.deepEqual(result.data.failures.map(f => f.rule), [
        "done-evidence-missing", "done-contract-missing", "done-evidence-missing", "done-contract-missing",
      ]);
    } else {
      assert.deepEqual(listActiveSpecs(fixture.root), { ok: true, data: { kind: "active-specs", specs: [
        { feature: "one", path: "specs/one/", hasApprovedPlannedOrInProgress: false },
        { feature: "two", path: "specs/two/", hasApprovedPlannedOrInProgress: false },
      ] } });
    }
    for (const dir of ["quality-gate", "implementation"]) {
      assert.equal(reads.filter(p => p.endsWith(`/reports/${dir}/all.md`)).length, 1, dir);
    }
  });
}

import {
  anyFileContaining, anyFileContainingWithDiagnostics, createReportLookup,
  hasAnyFileMentioning, hasQualityGateVerdictPass,
} from "../../src/parsers/report-lookup.js";
import { join } from "node:path";

const qualityDir = "reports/quality-gate";

test("snapshot matches legacy whole words, all matching reports, order and diagnostics", (t) => {
  const fixture = makeTempSddRoot("report-matches");
  t.after(fixture.cleanup);
  writeFile(fixture.dir, `${qualityDir}/a.md`, "T-001\nVERDICT: FAIL");
  writeFile(fixture.dir, `${qualityDir}/b.md`, "T-0010 T-001_extra xT-001 T-001-tail\nVERDICT: PASS");
  writeFile(fixture.dir, `${qualityDir}/c.md`, "(T-001)\nVERDICT: PASS");
  writeFile(fixture.dir, `${qualityDir}/nested/d.md`, "T-002\nVERDICT: FAIL");
  writeFile(fixture.dir, `${qualityDir}/huge.md`, "T-099\nVERDICT: PASS\n" + "x".repeat(2 * 1024 * 1024));
  writeFile(fixture.dir, `${qualityDir}/.env/hidden.md`, "T-099\nVERDICT: PASS");
  const lookup = createReportLookup();
  for (const dir of [qualityDir, "reports/missing", "../outside", "src", `${qualityDir}/a.md`]) {
    for (const id of ["T-001", "T-002", "T-099"]) {
      assert.deepEqual(lookup.anyFileContainingWithDiagnostics(fixture.root, dir, id),
        anyFileContainingWithDiagnostics(fixture.root, dir, id));
      assert.deepEqual(lookup.anyFileContainingWithDiagnostics(fixture.root, dir, id).matches, anyFileContaining(fixture.root, dir, id));
      assert.equal(lookup.hasAnyFileMentioning(fixture.root, dir, id), hasAnyFileMentioning(fixture.root, dir, id));
      assert.equal(lookup.hasQualityGateVerdictPass(fixture.root, dir, id), hasQualityGateVerdictPass(fixture.root, dir, id));
    }
  }
  assert.deepEqual(lookup.anyFileContainingWithDiagnostics(fixture.root, qualityDir, "T-001").matches, [`${qualityDir}/a.md`, `${qualityDir}/c.md`]);
  assert.equal(lookup.hasQualityGateVerdictPass(fixture.root, qualityDir, "T-001"), true);
  assert.equal(lookup.hasQualityGateVerdictPass(fixture.root, qualityDir, "T-002"), false);
  assert.equal(lookup.hasAnyFileMentioning(fixture.root, qualityDir, "T-099"), false);
  const result = lookup.anyFileContainingWithDiagnostics(fixture.root, qualityDir, "T-001");
  assert.ok(result.errors.some(e => e.reason === "Path matches a denylisted file."));
  result.matches.length = 0; result.errors.length = 0;
  assert.equal(lookup.anyFileContainingWithDiagnostics(fixture.root, qualityDir, "T-001").matches.length, 2);
  assert.ok(lookup.anyFileContainingWithDiagnostics(fixture.root, qualityDir, "T-001").errors.length > 0);
});

test("partial listing and file-read failures keep legacy diagnostics and readable matches", (t) => {
  const fixture = makeTempSddRoot("report-errors");
  t.after(fixture.cleanup);
  writeFile(fixture.dir, `${qualityDir}/good.md`, "T-001\nVERDICT: FAIL");
  const denied = writeFile(fixture.dir, `${qualityDir}/unreadable.md`, "T-001\nVERDICT: PASS");
  writeFile(fixture.dir, `${qualityDir}/nested/hidden.md`, "T-002\nVERDICT: PASS");
  const read = fs.readFileSync, list = fs.readdirSync;
  t.mock.method(fs, "readFileSync", (...args: Parameters<typeof fs.readFileSync>) => {
    if (String(args[0]) === denied) throw new Error("fixture read denied");
    return Reflect.apply(read, fs, args);
  });
  t.mock.method(fs, "readdirSync", (...args: Parameters<typeof fs.readdirSync>) => {
    if (String(args[0]) === join(fixture.root.path, qualityDir, "nested")) throw new Error("fixture listing denied");
    return Reflect.apply(list, fs, args);
  });
  syncBuiltinESMExports();
  t.after(() => { t.mock.restoreAll(); syncBuiltinESMExports(); });
  const lookup = createReportLookup();
  const legacy = anyFileContainingWithDiagnostics(fixture.root, qualityDir, "T-001");
  assert.deepEqual(legacy, { matches: [`${qualityDir}/good.md`], errors: [
    { path: `${qualityDir}/nested`, reason: "fixture listing denied" },
  ] });
  assert.deepEqual(lookup.anyFileContainingWithDiagnostics(fixture.root, qualityDir, "T-001"), legacy);
  assert.equal(lookup.hasQualityGateVerdictPass(fixture.root, qualityDir, "T-001"), false);
});

test("root identity isolates snapshots even when directory names and task IDs coincide", (t) => {
  const a = makeTempSddRoot("report-root-a"), b = makeTempSddRoot("report-root-b");
  t.after(a.cleanup); t.after(b.cleanup);
  writeFile(a.dir, `${qualityDir}/report.md`, "T-001\nVERDICT: PASS");
  writeFile(b.dir, `${qualityDir}/report.md`, "T-002\nVERDICT: FAIL");
  const lookup = createReportLookup();
  assert.equal(lookup.hasQualityGateVerdictPass(a.root, qualityDir, "T-001"), true);
  assert.equal(lookup.hasAnyFileMentioning(b.root, qualityDir, "T-001"), false);
  assert.equal(lookup.hasAnyFileMentioning(b.root, qualityDir, "T-002"), true);
  assert.equal(lookup.hasQualityGateVerdictPass(b.root, qualityDir, "T-002"), false);
});

test("new parser requests see changed, replaced, deleted and denied reports, never stale PASS", (t) => {
  const fixture = makeTempSddRoot("report-freshness");
  t.after(fixture.cleanup);
  writeFile(fixture.dir, "specs/one/tasks.md", tasks());
  const report = writeFile(fixture.dir, `${qualityDir}/report.md`, "T-001 T-002\nVERDICT: PASS");
  const impl = writeFile(fixture.dir, "reports/implementation/report.md", "T-003 T-004");
  const read = () => {
    const result = parseTaskState(fixture.root, "one", "specs/one/tasks.md");
    assert.ok(result.ok);
    return result.data.failures;
  };
  const reportFailures = () => read().filter(f => f.rule.includes("quality-gate") || f.rule === "impl-complete-report-missing");
  assert.deepEqual(reportFailures(), []);
  fs.writeFileSync(report, "T-001 T-002\nVERDICT: FAIL");
  assert.deepEqual(reportFailures().map(f => f.rule), ["done-quality-gate-verdict-fail", "done-quality-gate-verdict-fail"]);
  fs.unlinkSync(report);
  fs.renameSync(writeFile(fixture.dir, `${qualityDir}/replacement.md`, "T-0010\nVERDICT: PASS"), report);
  assert.deepEqual(reportFailures().map(f => f.rule), ["done-quality-gate-report-missing", "done-quality-gate-report-missing"]);
  fs.unlinkSync(report); fs.unlinkSync(impl);
  assert.equal(reportFailures().length, 4);
  writeFile(fixture.dir, `${qualityDir}/.env/report.md`, "T-001 T-002\nVERDICT: PASS");
  assert.equal(reportFailures().length, 4);
  writeFile(fixture.dir, `${qualityDir}/report.md`, "T-001 T-002\nVERDICT: PASS");
  writeFile(fixture.dir, "reports/implementation/report.md", "T-003 T-004");
  assert.deepEqual(reportFailures(), []);
  const contract = "specs/one/verification/T-001.contract.json";
  writeFile(fixture.dir, contract, '{"task_id":"T-001","risk":"low"}');
  assert.ok(!read().some(f => f.taskId === "T-001" && f.rule.includes("contract")));
  writeFile(fixture.dir, contract, '{"task_id":"T-002","risk":"low"}');
  assert.ok(read().some(f => f.rule === "done-contract-task-id-mismatch"));
  writeFile(fixture.dir, contract, '{"task_id":"T-001","risk":"high"}');
  assert.ok(read().some(f => f.rule === "contract-risk-mismatch"));
  writeFile(fixture.dir, "specs/one/verification/T-001.evidence.json", "{}");
  assert.ok(read().some(f => f.rule === "done-evidence-invalid"));
});

test("new listActiveSpecs requests rescan reports and still validate Done tasks", (t) => {
  const fixture = makeTempSddRoot("report-request");
  t.after(fixture.cleanup);
  writeFile(fixture.dir, "AGENTS.md", "## Active Spec Directories\n\n- `specs/one/`\n");
  writeFile(fixture.dir, "specs/one/tasks.md", tasks());
  const report = writeFile(fixture.dir, `${qualityDir}/report.md`, "T-001 T-002\nVERDICT: PASS");
  const original = fs.readFileSync; let reads = 0;
  t.mock.method(fs, "readFileSync", (...args: Parameters<typeof fs.readFileSync>) => {
    if (String(args[0]) === report) reads++;
    return Reflect.apply(original, fs, args);
  });
  syncBuiltinESMExports();
  t.after(() => { t.mock.restoreAll(); syncBuiltinESMExports(); });
  const first = listActiveSpecs(fixture.root);
  assert.equal(reads, 1);
  fs.writeFileSync(report, "T-001 T-002\nVERDICT: FAIL");
  assert.deepEqual(listActiveSpecs(fixture.root), first);
  assert.equal(reads, 2);
});

test("directory symlink escape is denied identically, including replacement between requests", (t) => {
  const fixture = makeTempSddRoot("report-link"), other = makeTempSddRoot("report-outside");
  t.after(fixture.cleanup); t.after(other.cleanup);
  writeFile(fixture.dir, `${qualityDir}/report.md`, "T-001\nVERDICT: PASS");
  writeFile(other.dir, "reports/report.md", "T-001\nVERDICT: PASS");
  assert.equal(createReportLookup().hasQualityGateVerdictPass(fixture.root, qualityDir, "T-001"), true);
  fs.rmSync(join(fixture.dir, qualityDir), { recursive: true });
  fs.symlinkSync(join(other.dir, "reports"), join(fixture.dir, qualityDir), "junction");
  const result = createReportLookup().anyFileContainingWithDiagnostics(fixture.root, qualityDir, "T-001");
  assert.deepEqual(result, anyFileContainingWithDiagnostics(fixture.root, qualityDir, "T-001"));
  assert.deepEqual(result, { matches: [], errors: [{ path: qualityDir, reason: "Path is outside the allowlisted directories." }] });
});

test("planned-only parses are lazy and perform no report scans", (t) => {
  const fixture = makeTempSddRoot("report-lazy");
  t.after(fixture.cleanup);
  writeFile(fixture.dir, "specs/one/tasks.md", "## T-001\nApproval: Approved\nStatus: Planned\n");
  writeFile(fixture.dir, `${qualityDir}/report.md`, "T-001\nVERDICT: PASS");
  const original = fs.readdirSync; let scans = 0;
  t.mock.method(fs, "readdirSync", (...args: Parameters<typeof fs.readdirSync>) => {
    scans++;
    return Reflect.apply(original, fs, args);
  });
  syncBuiltinESMExports();
  t.after(() => { t.mock.restoreAll(); syncBuiltinESMExports(); });
  const result = parseTaskState(fixture.root, "one", "specs/one/tasks.md");
  assert.ok(result.ok && result.data.verdict === "pass");
  assert.equal(scans, 0);
});

test("read permission failure after a successful request cannot retain PASS", (t) => {
  const fixture = makeTempSddRoot("report-revoked");
  t.after(fixture.cleanup);
  writeFile(fixture.dir, "specs/one/tasks.md", tasks());
  const report = writeFile(fixture.dir, `${qualityDir}/report.md`, "T-001 T-002\nVERDICT: PASS");
  const read = () => {
    const result = parseTaskState(fixture.root, "one", "specs/one/tasks.md");
    assert.ok(result.ok);
    return result.data.failures.filter(f => f.rule.includes("quality-gate"));
  };
  assert.deepEqual(read(), []);
  const original = fs.readFileSync;
  t.mock.method(fs, "readFileSync", (...args: Parameters<typeof fs.readFileSync>) => {
    if (String(args[0]) === report) throw new Error("fixture permission revoked");
    return Reflect.apply(original, fs, args);
  });
  syncBuiltinESMExports();
  t.after(() => { t.mock.restoreAll(); syncBuiltinESMExports(); });
  assert.deepEqual(read().map(f => f.rule), ["done-quality-gate-report-missing", "done-quality-gate-report-missing"]);
  t.mock.restoreAll(); syncBuiltinESMExports();
  assert.deepEqual(read(), []);
});
