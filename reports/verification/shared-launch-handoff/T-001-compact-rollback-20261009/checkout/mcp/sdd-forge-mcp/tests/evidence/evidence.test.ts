/**
 * AC-014: every evidence tool's response, called through a real MCP
 * client/server pair (SDK InMemoryTransport), must validate against
 * contracts/sdd-forge-mcp-tools.v1.schema.json and carry the expected `kind`
 * / field values for both real repository data (sdd-forge-refactor) and
 * synthetic fixtures (missing/mismatch/unsafe-path cases).
 *
 * `evidence_find_missing`'s Done-requirement set is verified to agree with
 * `get_task_state`'s (check-task-state.sh-equivalent) Done verdict: a real
 * Done task with no `done-evidence-*`/`done-contract-*`/
 * `done-quality-gate-*` failures must have an empty `missing` array here,
 * and a synthetic task with none of the three artifacts must have `missing`
 * equal to `required`.
 *
 * REQ-004 (issue #132) changes the SHAPE of that agreement and this header
 * records the change rather than leaving the old wording to rot: a
 * `reports/quality-gate` directory scan that FAILS now routes
 * `quality-gate-report-pass` to the new `undeterminable` array instead of
 * `missing`, while `parsers/task-validation.ts` is deliberately left
 * unchanged (BL-003) and still reports `done-quality-gate-report-missing` for
 * that same task. The parity assertion below is therefore written over the
 * UNION `missing ∪ undeterminable`; see the scope note on the parity test for
 * why the `missing`-only form is unsatisfiable by construction.
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import { chmodSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { makeTempSddRoot, writeFile, type TempSddRoot } from "../test-helpers.js";
import {
  connectFixture,
  getEnvelopeValidator,
  makeRealRepoRoot,
  parseEnvelope,
  seedDemoFixture,
  sha256Of,
  type EvidenceToolsFixture,
} from "./test-helpers.js";
import { buildServer } from "../../src/server.js";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { InMemoryTransport } from "@modelcontextprotocol/sdk/inMemory.js";
import { parseTaskState } from "../../src/parsers/tasks.js";
import { parseVerificationContract } from "../../src/parsers/evidence.js";

// --- evidence_get_bundle ----------------------------------------------------

test("evidence_get_bundle: real data, schema-valid, echoes sdd-forge-refactor T-001's bundle fields", async () => {
  const root = makeRealRepoRoot();
  const server = buildServer(root);
  const client = new Client({ name: "test-client", version: "0.0.0" });
  const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();
  await Promise.all([server.connect(serverTransport), client.connect(clientTransport)]);
  try {
    const result = await client.callTool({
      name: "evidence_get_bundle",
      arguments: { feature: "sdd-forge-refactor", taskId: "T-001" },
    });
    const envelope = parseEnvelope(result as never);
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));

    assert.equal((envelope as { ok: boolean }).ok, true);
    const data = (
      envelope as { ok: true; data: { kind: string; feature: string; taskId: string; bundle: Record<string, unknown> } }
    ).data;
    assert.equal(data.kind, "evidence-bundle");
    assert.equal(data.feature, "sdd-forge-refactor");
    assert.equal(data.taskId, "T-001");
    assert.equal(data.bundle.task_id, "T-001");
    assert.equal(data.bundle.risk, "low");
    assert.ok(Array.isArray(data.bundle.artifacts));
  } finally {
    await client.close();
    await server.close();
  }
});

test("evidence_get_bundle: synthetic, echoes signature value without verifying it", async () => {
  const tempRoot = seedDemoFixture("evidence-get-bundle-signature");
  const fixture = await connectFixture(tempRoot);
  try {
    writeFile(
      fixture.tempRoot.dir,
      "specs/demo/verification/T-009.evidence.json",
      JSON.stringify({
        task_id: "T-009",
        feature: "demo",
        risk: "critical",
        required_workflow: "tdd",
        signature: { alg: "hmac-sha256", value: "deadbeef" },
      }),
    );
    const result = await fixture.client.callTool({
      name: "evidence_get_bundle",
      arguments: { feature: "demo", taskId: "T-009" },
    });
    const envelope = parseEnvelope(result as never);
    assert.ok(getEnvelopeValidator()(envelope));
    assert.equal((envelope as { ok: boolean }).ok, true);
    const data = (envelope as { ok: true; data: { bundle: { signature?: unknown } } }).data;
    assert.deepEqual(data.bundle.signature, { alg: "hmac-sha256", value: "deadbeef" });
  } finally {
    await fixture.cleanup();
  }
});

test("evidence_get_bundle: not-found for a task with no evidence.json", async () => {
  const tempRoot = seedDemoFixture("evidence-get-bundle-not-found");
  const fixture = await connectFixture(tempRoot);
  try {
    const result = await fixture.client.callTool({
      name: "evidence_get_bundle",
      arguments: { feature: "demo", taskId: "T-002" },
    });
    const envelope = parseEnvelope(result as never);
    assert.ok(getEnvelopeValidator()(envelope));
    assert.equal((envelope as { ok: boolean }).ok, false);
    assert.equal((envelope as { ok: false; error: { code: string } }).error.code, "not-found");
  } finally {
    await fixture.cleanup();
  }
});

test("evidence_get_bundle: invalid-input for a malformed taskId", async () => {
  const tempRoot = seedDemoFixture("evidence-get-bundle-invalid-taskid");
  const fixture = await connectFixture(tempRoot);
  try {
    const result = await fixture.client.callTool({
      name: "evidence_get_bundle",
      arguments: { feature: "demo", taskId: "not-a-task-id" },
    });
    const envelope = parseEnvelope(result as never);
    assert.ok(getEnvelopeValidator()(envelope));
    assert.equal((envelope as { ok: boolean }).ok, false);
    assert.equal((envelope as { ok: false; error: { code: string } }).error.code, "invalid-input");
  } finally {
    await fixture.cleanup();
  }
});

// --- evidence_validate_paths -------------------------------------------------

test("evidence_validate_paths: real data, all sdd-forge-refactor T-001 artifacts are safe and exist", async () => {
  const root = makeRealRepoRoot();
  const server = buildServer(root);
  const client = new Client({ name: "test-client", version: "0.0.0" });
  const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();
  await Promise.all([server.connect(serverTransport), client.connect(clientTransport)]);
  try {
    const result = await client.callTool({
      name: "evidence_validate_paths",
      arguments: { feature: "sdd-forge-refactor", taskId: "T-001" },
    });
    const envelope = parseEnvelope(result as never);
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));
    assert.equal((envelope as { ok: boolean }).ok, true);
    const data = (
      envelope as { ok: true; data: { kind: string; results: Array<{ path: string; safe: boolean; exists: boolean }> } }
    ).data;
    assert.equal(data.kind, "evidence-paths");
    assert.ok(data.results.length >= 1);
    for (const entry of data.results) {
      assert.equal(entry.safe, true, `expected ${entry.path} to be safe`);
      assert.equal(entry.exists, true, `expected ${entry.path} to exist`);
    }
  } finally {
    await client.close();
    await server.close();
  }
});

test("evidence_validate_paths: synthetic, flags a traversal artifact path as unsafe", async () => {
  const tempRoot = seedDemoFixture("evidence-validate-paths-unsafe");
  const fixture = await connectFixture(tempRoot);
  try {
    writeFile(
      fixture.tempRoot.dir,
      "specs/demo/verification/T-020.evidence.json",
      JSON.stringify({
        task_id: "T-020",
        feature: "demo",
        risk: "low",
        required_workflow: "tdd",
        artifacts: [
          { path: "../../etc/passwd", sha256: "0".repeat(64) },
          { path: "/etc/passwd", sha256: "0".repeat(64) },
          { path: "specs/demo/investigation.md", sha256: sha256Of("# Investigation: demo\n\nBody.\n") },
          { path: "specs/demo/verification/T-020.nope.json", sha256: "0".repeat(64) },
        ],
      }),
    );

    const result = await fixture.client.callTool({
      name: "evidence_validate_paths",
      arguments: { feature: "demo", taskId: "T-020" },
    });
    const envelope = parseEnvelope(result as never);
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));
    assert.equal((envelope as { ok: boolean }).ok, true);
    const data = (
      envelope as {
        ok: true;
        data: { results: Array<{ path: string; safe: boolean; exists: boolean; reason?: string }> };
      }
    ).data;

    const traversal = data.results.find((r) => r.path === "../../etc/passwd");
    assert.ok(traversal !== undefined && traversal.safe === false && traversal.exists === false);
    assert.ok(typeof traversal?.reason === "string" && traversal.reason.length > 0);

    const absolute = data.results.find((r) => r.path === "/etc/passwd");
    assert.ok(absolute !== undefined && absolute.safe === false && absolute.exists === false);

    const safeAndPresent = data.results.find((r) => r.path === "specs/demo/investigation.md");
    assert.ok(safeAndPresent !== undefined && safeAndPresent.safe === true && safeAndPresent.exists === true);

    const safeButMissing = data.results.find((r) => r.path === "specs/demo/verification/T-020.nope.json");
    assert.ok(safeButMissing !== undefined && safeButMissing.safe === true && safeButMissing.exists === false);
  } finally {
    await fixture.cleanup();
  }
});

// --- evidence_find_missing ---------------------------------------------------

/** The one requirement whose check is a DIRECTORY SCAN and can therefore be undeterminable. */
const QUALITY_GATE_REQUIREMENT = "quality-gate-report-pass";

/** The unchanged 3-name baseline vocabulary of `required` (evidence.ts:201). */
const BASELINE_REQUIREMENTS = ["evidence-bundle", "quality-gate-report-pass", "verification-contract"];

interface EvidenceMissingShape {
  kind: string;
  feature: string;
  taskId: string;
  required: string[];
  present: string[];
  missing: string[];
  undeterminable: string[];
}

/** Calls `evidence_find_missing` on the `demo` fixture feature and returns its ajv-validated ok data. */
async function callFindMissing(fixture: EvidenceToolsFixture, taskId: string): Promise<EvidenceMissingShape> {
  const result = await fixture.client.callTool({
    name: "evidence_find_missing",
    arguments: { feature: "demo", taskId },
  });
  const envelope = parseEnvelope(result as never);
  assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));
  assert.equal((envelope as { ok: boolean }).ok, true);
  return (envelope as { ok: true; data: EvidenceMissingShape }).data;
}

/**
 * requirements.md Field Definitions (`undeterminable`): "Every entry in
 * `required` lands in EXACTLY ONE of `present`/`missing`/`undeterminable`."
 *
 * Asserted as a genuine PARTITION — covering AND pairwise-disjoint — rather
 * than as three independent membership checks, which would miss both an
 * overlap (an entry double-reported) and a drop (an entry in no bucket).
 */
function assertPartitionsRequired(
  data: Pick<EvidenceMissingShape, "required" | "present" | "missing" | "undeterminable">,
  label: string,
): void {
  const union = [...data.present, ...data.missing, ...data.undeterminable];

  // (1) COVERING, counted as a multiset: the concatenation is a permutation of
  //     `required`. A dropped entry shortens it; a stray entry lengthens it.
  assert.deepEqual(
    [...union].sort(),
    [...data.required].sort(),
    `${label}: present ∪ missing ∪ undeterminable must be exactly \`required\`, got ${JSON.stringify(data)}`,
  );

  // (2) NO DUPLICATE anywhere across the three arrays. Together with (1) this
  //     is exactly "exactly one of", since (1) already forbids omissions.
  assert.equal(
    new Set(union).size,
    union.length,
    `${label}: a requirement is reported more than once across present/missing/undeterminable: ${JSON.stringify(data)}`,
  );

  // (3) Pairwise disjointness named directly as well, so the invariant is
  //     readable at the failure site instead of being inferred from (1)+(2).
  const pairs: Array<[string, string[], string, string[]]> = [
    ["present", data.present, "missing", data.missing],
    ["present", data.present, "undeterminable", data.undeterminable],
    ["missing", data.missing, "undeterminable", data.undeterminable],
  ];
  for (const [aName, a, bName, b] of pairs) {
    const overlap = a.filter((entry) => b.includes(entry));
    assert.deepEqual(overlap, [], `${label}: ${aName} and ${bName} overlap on ${JSON.stringify(overlap)}`);
  }

  // (4) `required` itself is unaffected by REQ-004 (AC-007's "with `required`
  //     unaffected"): the same 3 baseline names, no more and no fewer.
  assert.deepEqual([...data.required].sort(), [...BASELINE_REQUIREMENTS].sort(), `${label}: \`required\` changed`);
}

/**
 * TEST-007's scan-failure fixture, in a form portable to every OS in the 3-OS
 * `mcp-tests` matrix (no permission bits, no symlink privilege required).
 *
 * `reports/quality-gate` is replaced by a REGULAR FILE whose contents are the
 * very `VERDICT: PASS` report text a successful scan would have matched. The
 * path therefore exists and is readable, and the case is unambiguously "the
 * directory scan could not be performed" rather than "no quality-gate report
 * was ever produced" — `resolveGuardedDirectory` rejects it with
 * `Path is not a directory: reports/quality-gate`, which
 * `listGuardedFilesWithDiagnostics` reports as one `errors[]` entry
 * (design.md Test Strategy item 4: "a removed directory referenced via a raw
 * `resolveGuardedDirectory` failure path").
 */
function seedScanFailureFixture(prefix: string): TempSddRoot {
  const tempRoot = seedDemoFixture(prefix);
  const qgPath = join(tempRoot.dir, "reports", "quality-gate");
  rmSync(qgPath, { recursive: true, force: true });
  writeFileSync(
    qgPath,
    ["# Quality Gate — T-001", "", "Task ID: T-001", "", "VERDICT: PASS", ""].join("\n"),
    "utf-8",
  );
  return tempRoot;
}

test("evidence_find_missing: real data, sdd-forge-refactor T-001 (Done) has nothing missing", async () => {
  const root = makeRealRepoRoot();
  const server = buildServer(root);
  const client = new Client({ name: "test-client", version: "0.0.0" });
  const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();
  await Promise.all([server.connect(serverTransport), client.connect(clientTransport)]);
  try {
    const result = await client.callTool({
      name: "evidence_find_missing",
      arguments: { feature: "sdd-forge-refactor", taskId: "T-001" },
    });
    const envelope = parseEnvelope(result as never);
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));
    assert.equal((envelope as { ok: boolean }).ok, true);
    const data = (
      envelope as {
        ok: true;
        data: { kind: string; required: string[]; present: string[]; missing: string[]; undeterminable: string[] };
      }
    ).data;
    assert.equal(data.kind, "evidence-missing");
    assert.deepEqual(data.missing, []);
    assert.deepEqual([...data.present].sort(), [...data.required].sort());
    // AC-012 leg (REQ-004): this pre-existing shape assertion is extended to
    // the new field. The real repository's reports/quality-gate scans
    // successfully, so nothing is undeterminable here.
    assert.deepEqual(data.undeterminable, []);
  } finally {
    await client.close();
    await server.close();
  }
});

test("evidence_find_missing: synthetic Done task with a fully valid bundle has nothing missing, matching get_task_state's Done verdict", async () => {
  const tempRoot = seedDemoFixture("evidence-find-missing-done-parity");
  const fixture = await connectFixture(tempRoot);
  try {
    const result = await fixture.client.callTool({
      name: "evidence_find_missing",
      arguments: { feature: "demo", taskId: "T-001" },
    });
    const envelope = parseEnvelope(result as never);
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));
    assert.equal((envelope as { ok: boolean }).ok, true);
    const data = (
      envelope as {
        ok: true;
        data: { required: string[]; present: string[]; missing: string[]; undeterminable: string[] };
      }
    ).data;
    assert.deepEqual(data.missing, []);
    assert.deepEqual([...data.present].sort(), [...data.required].sort());
    // AC-012 leg (REQ-004): the scan succeeds for this fixture, so the new
    // field is empty and the ORIGINAL `missing`-only parity below still holds
    // exactly (design.md "Parity Impact of REQ-004", scan-succeeded case).
    assert.deepEqual(data.undeterminable, []);

    // Cross-check against get_task_state's shell-equivalent Done verdict:
    // this fixture's T-001 evidence bundle has a fully matching artifact
    // manifest, so it must have no done-evidence-*/done-contract-*/
    // done-quality-gate-* failure either, confirming find_missing's
    // presence-only requirements agree with check-task-state.sh's Done
    // requirements for the "everything present" case.
    const taskStateResult = parseTaskState(fixture.root, "demo", "specs/demo/tasks.md");
    assert.equal(taskStateResult.ok, true);
    if (taskStateResult.ok) {
      const doneFailures = taskStateResult.data.failures.filter(
        (f) => f.taskId === "T-001" && f.rule.startsWith("done-"),
      );
      assert.deepEqual(doneFailures, []);
      assert.equal(taskStateResult.data.verdict, "pass");
    }
  } finally {
    await fixture.cleanup();
  }
});

test("evidence_find_missing: synthetic, a task with no verification artifacts has every requirement missing", async () => {
  const tempRoot = seedDemoFixture("evidence-find-missing-all-missing");
  const fixture = await connectFixture(tempRoot);
  try {
    const result = await fixture.client.callTool({
      name: "evidence_find_missing",
      arguments: { feature: "demo", taskId: "T-002" },
    });
    const envelope = parseEnvelope(result as never);
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));
    assert.equal((envelope as { ok: boolean }).ok, true);
    const data = (
      envelope as {
        ok: true;
        data: { required: string[]; present: string[]; missing: string[]; undeterminable: string[] };
      }
    ).data;
    assert.deepEqual(data.present, []);
    assert.deepEqual([...data.missing].sort(), [...data.required].sort());

    // TEST-008 (AC-008; security-spec.md B4's named negative regression).
    // The two assertions above and the fixture itself are UNMODIFIED — the
    // lines below are appended. This is the genuinely-empty-but-READABLE scan
    // (`reports/quality-gate` exists and holds demo-T-001.md; it simply
    // mentions no T-002), which REQ-004 must NOT reclassify: the requirement
    // stays in `missing` and `undeterminable` stays empty.
    assert.ok(
      data.missing.includes("quality-gate-report-pass"),
      "a successfully-read directory that contains no report for this task must stay in `missing`, never move to `undeterminable`",
    );
    assert.deepEqual(data.undeterminable, []);
    assertPartitionsRequired(data, "TEST-008 no-artifacts fixture");
  } finally {
    await fixture.cleanup();
  }
});

test("evidence_find_missing: synthetic, a task whose quality-gate report lacks VERDICT: PASS is missing that requirement only", async () => {
  const tempRoot = seedDemoFixture("evidence-find-missing-no-pass-verdict");
  const fixture = await connectFixture(tempRoot);
  try {
    writeFile(
      fixture.tempRoot.dir,
      "specs/demo/verification/T-030.evidence.json",
      JSON.stringify({ task_id: "T-030", feature: "demo", risk: "low", required_workflow: "tdd" }),
    );
    writeFile(
      fixture.tempRoot.dir,
      "specs/demo/verification/T-030.contract.json",
      JSON.stringify({ task_id: "T-030", risk: "low", checks: [] }),
    );
    writeFile(
      fixture.tempRoot.dir,
      "reports/quality-gate/demo-T-030.md",
      ["# Quality Gate — T-030", "", "Task ID: T-030", "", "VERDICT: FAIL", ""].join("\n"),
    );

    const result = await fixture.client.callTool({
      name: "evidence_find_missing",
      arguments: { feature: "demo", taskId: "T-030" },
    });
    const envelope = parseEnvelope(result as never);
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));
    assert.equal((envelope as { ok: boolean }).ok, true);
    const data = (
      envelope as {
        ok: true;
        data: { required: string[]; present: string[]; missing: string[]; undeterminable: string[] };
      }
    ).data;
    assert.deepEqual(data.missing, ["quality-gate-report-pass"]);
    assert.deepEqual([...data.present].sort(), ["evidence-bundle", "verification-contract"]);
    // AC-012 leg (REQ-004): a report that IS found but carries VERDICT: FAIL
    // is a successful scan with an unsatisfied requirement — `missing`, never
    // `undeterminable` (requirements.md OQ-3 fixes this direction too).
    assert.deepEqual(data.undeterminable, []);
    assertPartitionsRequired(data, "no-pass-verdict fixture");
  } finally {
    await fixture.cleanup();
  }
});

test("TEST-007 (AC-007): a FAILED reports/quality-gate directory scan puts quality-gate-report-pass in undeterminable and in NEITHER present NOR missing", async () => {
  const tempRoot = seedScanFailureFixture("evidence-find-missing-scan-failure");
  const fixture = await connectFixture(tempRoot);
  try {
    const data = await callFindMissing(fixture, "T-001");

    assert.deepEqual(
      data.undeterminable,
      [QUALITY_GATE_REQUIREMENT],
      "a directory-scan failure must land in `undeterminable`",
    );
    assert.ok(
      !data.missing.includes(QUALITY_GATE_REQUIREMENT),
      "REQ-004/OQ-3: a scan failure must NEVER be reported as `missing` — that is the exact conflation issue #132 reports",
    );
    assert.ok(
      !data.present.includes(QUALITY_GATE_REQUIREMENT),
      "a scan failure must not be reported as satisfied either",
    );

    // `required` is unaffected, and the three arrays partition it.
    assertPartitionsRequired(data, "TEST-007 (a) not-a-directory");

    // The other two requirements are single-file `guardedExists` checks with
    // no directory-listing step, so the scan failure leaves them alone
    // (design.md `evidence_find_missing` section, Out of Scope item 3).
    assert.deepEqual([...data.present].sort(), ["evidence-bundle", "verification-contract"]);
    assert.deepEqual(data.missing, []);
  } finally {
    await fixture.cleanup();
  }
});

test("TEST-007 (AC-007): an UNREADABLE reports/quality-gate directory that really holds a VERDICT: PASS report is undeterminable, not missing", async (t) => {
  if (process.platform === "win32") {
    t.skip(
      "SKIP REASON: mode 0o000 does not deny directory listing on Windows/NTFS, so a readdirSync failure cannot be constructed there. The portable variant of this sub-case is the not-a-directory TEST-007 case above, which runs on every OS in the 3-OS matrix.",
    );
    return;
  }
  if (typeof process.getuid === "function" && process.getuid() === 0) {
    t.skip(
      "SKIP REASON: running as uid 0 — POSIX permission bits do not deny root, so mode 0o000 cannot produce a readdirSync failure. The not-a-directory TEST-007 case above still covers the scan-failure route.",
    );
    return;
  }

  const tempRoot = seedDemoFixture("evidence-find-missing-scan-unreadable");
  const fixture = await connectFixture(tempRoot);
  const qgDir = join(tempRoot.dir, "reports", "quality-gate");
  try {
    // The fixture's own reports/quality-gate/demo-T-001.md (VERDICT: PASS,
    // mentioning T-001) is left in place and only the directory is made
    // unreadable. This is the sharpest form of issue #132's defect: the
    // evidence EXISTS and a working scan would have reported `present`, so
    // reporting `missing` here would be an outright false negative.
    chmodSync(qgDir, 0o000);

    const data = await callFindMissing(fixture, "T-001");

    assert.deepEqual(data.undeterminable, [QUALITY_GATE_REQUIREMENT]);
    assert.ok(
      !data.missing.includes(QUALITY_GATE_REQUIREMENT),
      "an unreadable directory holding a real passing report must never be reported as missing evidence",
    );
    assert.ok(!data.present.includes(QUALITY_GATE_REQUIREMENT));
    assertPartitionsRequired(data, "TEST-007 (b) unreadable-directory");
  } finally {
    try {
      chmodSync(qgDir, 0o755);
    } catch {
      // Best effort: the fixture is mktemp-scoped and removed immediately below.
    }
    await fixture.cleanup();
  }
});

test("TEST-007/TEST-008 (design.md Test Strategy 4(b)): evidenceFindMissing/parseTaskState parity holds over `missing ∪ undeterminable` on both fixtures", async () => {
  // SCOPE, stated explicitly because the broader phrasing of this invariant is
  // NOT universally true and must not be silently over-claimed:
  //
  //   * over TEST-007's and TEST-008's OWN two fixtures, and
  //   * within each, over the tasks whose Status is `Done`.
  //
  // The Done restriction is structural, not a convenience: the right-hand side
  // `done-quality-gate-report-missing` is produced ONLY by `validateDoneEvidence`
  // (`task-validation.ts`), which is called only for `Status: Done` tasks
  // (`task-validation.ts:75-77`), so a non-Done task can never satisfy it no
  // matter what `evidence_find_missing` returns. `evidence.ts:16-19`'s own
  // prose scopes the invariant the same way ("the tasks whose `Status: Done`
  // transition `parseTaskState` already accepts"). The non-Done tasks are
  // therefore checked below for that structural reason rather than skipped.
  //
  // The fixture restriction is likewise real: a PARTIAL-success scan (errors[]
  // non-empty AND matches non-empty) would put the requirement in
  // `undeterminable` while the unchanged `anyFileContaining` still returns
  // matches and so reports no failure — breaking the biconditional. Neither
  // fixture below has that shape (each scan either wholly fails or wholly
  // succeeds), which is why the assertion is satisfiable here.
  const cases: Array<{ label: string; tempRoot: TempSddRoot }> = [
    { label: "TEST-007 scan-failure fixture", tempRoot: seedScanFailureFixture("evidence-parity-scan-failure") },
    { label: "TEST-008 no-artifacts fixture", tempRoot: seedDemoFixture("evidence-parity-no-artifacts") },
  ];

  for (const { label, tempRoot } of cases) {
    const fixture = await connectFixture(tempRoot);
    try {
      const state = parseTaskState(fixture.root, "demo", "specs/demo/tasks.md");
      assert.equal(state.ok, true, `${label}: parseTaskState must parse the fixture's tasks.md`);
      if (!state.ok) {
        continue;
      }

      const doneTasks = state.data.tasks.filter((task) => task.status === "Done");
      assert.ok(doneTasks.length > 0, `${label}: fixture must contain a Done task, else the parity check is vacuous`);

      for (const task of doneTasks) {
        const data = await callFindMissing(fixture, task.id);
        assertPartitionsRequired(data, `${label} / ${task.id}`);

        const inUnion =
          data.missing.includes(QUALITY_GATE_REQUIREMENT) || data.undeterminable.includes(QUALITY_GATE_REQUIREMENT);
        const parserReportsFailure = state.data.failures.some(
          (failure) => failure.taskId === task.id && failure.rule === "done-quality-gate-report-missing",
        );

        assert.equal(
          inUnion,
          parserReportsFailure,
          `${label} / ${task.id}: parity broke — in (missing ∪ undeterminable)=${inUnion}, parseTaskState done-quality-gate-report-missing=${parserReportsFailure}; data=${JSON.stringify(data)}`,
        );
      }

      // The non-Done tasks: asserted rather than skipped, so the scope note
      // above is backed by a check. `validateDoneEvidence` never runs for them,
      // so they emit no `done-` failure at all even when
      // `evidence_find_missing` (which is deliberately Status-independent)
      // reports every requirement for them.
      for (const task of state.data.tasks.filter((entry) => entry.status !== "Done")) {
        const doneRules: string[] = state.data.failures
          .filter((failure) => failure.taskId === task.id && failure.rule.startsWith("done-"))
          .map((failure) => failure.rule);
        assert.deepEqual(
          doneRules,
          [],
          `${label} / ${task.id}: a non-Done task must produce no done-* failure, which is why the parity is Done-scoped`,
        );
      }
    } finally {
      await fixture.cleanup();
    }
  }
});

test("TEST-007 (design.md Test Strategy 4(b)): the scan-failure asymmetry is pinned — undeterminable yes, missing no, task-validation.ts still reporting the failure", async () => {
  const tempRoot = seedScanFailureFixture("evidence-parity-asymmetry");
  const fixture = await connectFixture(tempRoot);
  try {
    const data = await callFindMissing(fixture, "T-001");
    const state = parseTaskState(fixture.root, "demo", "specs/demo/tasks.md");
    assert.equal(state.ok, true);
    if (!state.ok) {
      return;
    }

    const parserReportsFailure = state.data.failures.some(
      (failure) => failure.taskId === "T-001" && failure.rule === "done-quality-gate-report-missing",
    );

    assert.ok(data.undeterminable.includes(QUALITY_GATE_REQUIREMENT), "left side: the requirement is undeterminable");
    assert.ok(!data.missing.includes(QUALITY_GATE_REQUIREMENT), "left side: the requirement is NOT missing");
    assert.ok(
      parserReportsFailure,
      "right side: `parsers/task-validation.ts` is deliberately UNCHANGED (BL-003), so it must STILL report done-quality-gate-report-missing for the scan-failure task",
    );

    // Therefore the `missing`-ONLY form of the parity invariant is FALSE for
    // this fixture. Pinned as an executable assertion rather than left as
    // prose, so a future revision cannot reintroduce the unsatisfiable form
    // (design.md: "Writing this assertion over `missing` alone would be
    // unsatisfiable by construction") without a failing test.
    const missingOnlyParityHolds = data.missing.includes(QUALITY_GATE_REQUIREMENT) === parserReportsFailure;
    assert.equal(
      missingOnlyParityHolds,
      false,
      "the `missing`-only parity form must be FALSE here; if it ever holds, REQ-004's routing has been undone",
    );
  } finally {
    await fixture.cleanup();
  }
});

test("TEST-009 leg (AC-009): the v1 contract requires undeterminable on evidenceMissingData, and all 3 of this feature's new fields are simultaneously required", () => {
  const schemaPath = join(makeRealRepoRoot().path, "contracts", "sdd-forge-mcp-tools.v1.schema.json");
  const schema = JSON.parse(readFileSync(schemaPath, "utf-8")) as {
    $id: string;
    $defs: Record<
      string,
      {
        additionalProperties: boolean;
        required: string[];
        properties: Record<string, { type?: string; items?: { type?: string; additionalProperties?: boolean } }>;
      }
    >;
  };

  // The contract stays v1 — no new schema file, no $id bump.
  assert.equal(schema.$id, "https://sdd-forge.dev/contracts/sdd-forge-mcp-tools.v1.schema.json");

  const missingDef = schema.$defs.evidenceMissingData;
  assert.ok(missingDef, "$defs.evidenceMissingData is absent");
  assert.equal(missingDef.additionalProperties, false);
  assert.deepEqual(missingDef.required, [
    "kind",
    "feature",
    "taskId",
    "required",
    "present",
    "missing",
    "undeterminable",
  ]);
  assert.equal(missingDef.properties.undeterminable?.type, "array");
  assert.equal(missingDef.properties.undeterminable?.items?.type, "string");

  // This is the LAST schema-touching task of the chain, so all 3 of the
  // feature's new fields must be required AT THE SAME TIME (T-004's Done When,
  // completing AC-009). Each nested-object item shape keeps
  // additionalProperties: false; `undeterminable`'s items are plain strings and
  // so have no nested object to constrain.
  assert.ok(schema.$defs.traceabilityComparisonData.required.includes("unreadableContracts"));
  assert.equal(schema.$defs.traceabilityComparisonData.additionalProperties, false);
  assert.equal(
    schema.$defs.traceabilityComparisonData.properties.unreadableContracts?.items?.additionalProperties,
    false,
  );
  assert.ok(schema.$defs.evidenceDeepVerifyData.required.includes("hostRequiredChecks"));
  assert.equal(schema.$defs.evidenceDeepVerifyData.additionalProperties, false);
  assert.equal(schema.$defs.evidenceDeepVerifyData.properties.hostRequiredChecks?.items?.additionalProperties, false);

  // The real ajv validator is the authority on required-ness: an otherwise
  // well-formed ok envelope that OMITS the field must FAIL, and the same
  // envelope WITH it must pass.
  const validate = getEnvelopeValidator();
  const withField = {
    ok: true,
    data: {
      kind: "evidence-missing",
      feature: "demo",
      taskId: "T-001",
      required: [...BASELINE_REQUIREMENTS],
      present: ["evidence-bundle", "verification-contract"],
      missing: [],
      undeterminable: [QUALITY_GATE_REQUIREMENT],
    },
  };
  assert.ok(validate(withField), JSON.stringify(validate.errors));

  const withoutField = { ok: true, data: { ...withField.data } } as { ok: true; data: Record<string, unknown> };
  delete withoutField.data.undeterminable;
  assert.equal(
    validate(withoutField),
    false,
    "an evidence-missing envelope omitting `undeterminable` must FAIL validation once the field is required",
  );
});

// --- evidence_summarize_contract_checks --------------------------------------

test("evidence_summarize_contract_checks: real data, sdd-forge-refactor T-001's placeholder-scan check summarizes correctly", async () => {
  const root = makeRealRepoRoot();
  const server = buildServer(root);
  const client = new Client({ name: "test-client", version: "0.0.0" });
  const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();
  await Promise.all([server.connect(serverTransport), client.connect(clientTransport)]);
  try {
    const result = await client.callTool({
      name: "evidence_summarize_contract_checks",
      arguments: { feature: "sdd-forge-refactor", taskId: "T-001" },
    });
    const envelope = parseEnvelope(result as never);
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));
    assert.equal((envelope as { ok: boolean }).ok, true);
    const data = (
      envelope as {
        ok: true;
        data: {
          kind: string;
          checks: Array<{ id: string; required: boolean; passes: boolean; requirementIds?: string[] }>;
        };
      }
    ).data;
    assert.equal(data.kind, "contract-checks");
    const placeholderScan = data.checks.find((c) => c.id === "placeholder-scan");
    assert.ok(placeholderScan !== undefined);
    assert.equal(placeholderScan?.required, true);
    assert.equal(placeholderScan?.passes, true);
    assert.ok(placeholderScan?.requirementIds?.includes("REQ-001"));
  } finally {
    await client.close();
    await server.close();
  }
});

test("evidence_summarize_contract_checks: synthetic, converts waiverReason and requirementIds", async () => {
  const tempRoot = seedDemoFixture("evidence-summarize-contract-checks");
  const fixture = await connectFixture(tempRoot);
  try {
    const result = await fixture.client.callTool({
      name: "evidence_summarize_contract_checks",
      arguments: { feature: "demo", taskId: "T-001" },
    });
    const envelope = parseEnvelope(result as never);
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));
    assert.equal((envelope as { ok: boolean }).ok, true);
    const data = (
      envelope as { ok: true; data: { checks: Array<{ id: string; requirementIds?: string[] }> } }
    ).data;
    assert.deepEqual(
      data.checks.map((c) => c.id),
      ["unit-tests"],
    );
    assert.deepEqual(data.checks[0]?.requirementIds, ["REQ-001"]);
  } finally {
    await fixture.cleanup();
  }
});

test("evidence_summarize_contract_checks: cannot-parse for a malformed contract.json", async () => {
  const tempRoot = seedDemoFixture("evidence-summarize-contract-checks-broken");
  const fixture = await connectFixture(tempRoot);
  try {
    writeFile(fixture.tempRoot.dir, "specs/demo/verification/T-040.contract.json", "{ not valid json");
    const result = await fixture.client.callTool({
      name: "evidence_summarize_contract_checks",
      arguments: { feature: "demo", taskId: "T-040" },
    });
    const envelope = parseEnvelope(result as never);
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));
    assert.equal((envelope as { ok: boolean }).ok, false);
    assert.equal((envelope as { ok: false; error: { code: string } }).error.code, "cannot-parse");
  } finally {
    await fixture.cleanup();
  }
});

// --- evidence_compare_to_traceability -----------------------------------------

test("evidence_compare_to_traceability: real data, sdd-forge-mcp's traceability.md is fully consistent with tasks.md", async () => {
  const root = makeRealRepoRoot();
  const server = buildServer(root);
  const client = new Client({ name: "test-client", version: "0.0.0" });
  const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();
  await Promise.all([server.connect(serverTransport), client.connect(clientTransport)]);
  try {
    const result = await client.callTool({
      name: "evidence_compare_to_traceability",
      arguments: { feature: "sdd-forge-mcp" },
    });
    const envelope = parseEnvelope(result as never);
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));
    assert.equal((envelope as { ok: boolean }).ok, true);
    const data = (
      envelope as {
        ok: true;
        data: {
          kind: string;
          matches: number;
          mismatches: Array<{ subject: string }>;
          unreadableContracts: Array<{ taskId: string; reason: string }>;
        };
      }
    ).data;
    assert.equal(data.kind, "traceability-comparison");
    assert.ok(data.matches > 0);
    assert.deepEqual(data.mismatches, []);
    // AC-012: this pre-existing suite now also asserts the new field. Every
    // task in specs/sdd-forge-mcp/tasks.md has a readable contract.json, so
    // the real-repository response carries an empty unreadableContracts.
    assert.deepEqual(data.unreadableContracts, []);
  } finally {
    await client.close();
    await server.close();
  }
});

test("evidence_compare_to_traceability: synthetic, flags a REQ -> Task row referencing a nonexistent task", async () => {
  const tempRoot = seedDemoFixture("evidence-compare-to-traceability-mismatch");
  const fixture = await connectFixture(tempRoot);
  try {
    const result = await fixture.client.callTool({
      name: "evidence_compare_to_traceability",
      arguments: { feature: "demo" },
    });
    const envelope = parseEnvelope(result as never);
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));
    assert.equal((envelope as { ok: boolean }).ok, true);
    const data = (
      envelope as {
        ok: true;
        data: {
          matches: number;
          mismatches: Array<{ subject: string; issue: string }>;
          unreadableContracts: Array<{ taskId: string; reason: string }>;
        };
      }
    ).data;
    assert.equal(data.mismatches.length, 1);
    assert.match(data.mismatches[0]?.subject ?? "", /REQ-002/);
    assert.match(data.mismatches[0]?.issue ?? "", /T-099/);
    assert.ok(data.matches >= 1);
    // AC-012: the demo fixture's T-002 is Planned with no contract.json at
    // all, so the new field names exactly that task (AC-017: not filtered to
    // Done tasks).
    assert.deepEqual(
      data.unreadableContracts.map((entry) => entry.taskId),
      ["T-002"],
    );
  } finally {
    await fixture.cleanup();
  }
});

test("evidence_compare_to_traceability: synthetic, flags a contract requirementId traceability.md never declares", async () => {
  const tempRoot = seedDemoFixture("evidence-compare-to-traceability-contract-mismatch");
  const fixture = await connectFixture(tempRoot);
  try {
    writeFile(
      fixture.tempRoot.dir,
      "specs/demo/verification/T-001.contract.json",
      JSON.stringify({
        task_id: "T-001",
        feature: "demo",
        risk: "low",
        required_workflow: "tdd",
        checks: [
          {
            id: "unit-tests",
            required: true,
            passes: true,
            requirement_ids: ["REQ-001", "REQ-999"],
          },
        ],
      }),
    );

    const result = await fixture.client.callTool({
      name: "evidence_compare_to_traceability",
      arguments: { feature: "demo" },
    });
    const envelope = parseEnvelope(result as never);
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));
    assert.equal((envelope as { ok: boolean }).ok, true);
    const data = (
      envelope as {
        ok: true;
        data: {
          mismatches: Array<{ subject: string; issue: string }>;
          unreadableContracts: Array<{ taskId: string; reason: string }>;
        };
      }
    ).data;
    const contractMismatch = data.mismatches.find((m) => m.subject === "T-001 contract -> REQ-ID");
    assert.ok(contractMismatch !== undefined);
    assert.match(contractMismatch?.issue ?? "", /REQ-999/);
    // AC-012: T-001's contract stays readable here (it is rewritten, not
    // removed), so only the fixture's contract-less T-002 is reported.
    assert.deepEqual(
      data.unreadableContracts.map((entry) => entry.taskId),
      ["T-002"],
    );
  } finally {
    await fixture.cleanup();
  }
});

test("evidence_compare_to_traceability: not-found when traceability.md does not exist", async () => {
  const tempRoot = seedDemoFixture("evidence-compare-to-traceability-not-found");
  const fixture = await connectFixture(tempRoot);
  try {
    // "demo" (the fixture's only feature) has a traceability.md, so a
    // nonexistent feature name reproduces the "no traceability.md" case.
    const result = await fixture.client.callTool({
      name: "evidence_compare_to_traceability",
      arguments: { feature: "no-such-feature" },
    });
    const envelope = parseEnvelope(result as never);
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));
    assert.equal((envelope as { ok: boolean }).ok, false);
    assert.equal((envelope as { ok: false; error: { code: string } }).error.code, "not-found");
  } finally {
    await fixture.cleanup();
  }
});

// --- evidence_compare_to_traceability: unreadableContracts (REQ-001) ---------

/**
 * Seeds a synthetic feature `demo` whose three tasks exercise every branch
 * REQ-001 cares about:
 *
 *  - `T-001` (Done) has a valid, readable `T-001.contract.json` whose single
 *    check cites one REQ-ID traceability.md declares (`REQ-001`) and one it
 *    never declares (`REQ-909`) -- the fixture's ONLY `mismatches` entry.
 *  - `T-002` (Done) has a contract file that exists and is valid JSON but
 *    whose `task_id` names a different task, so `parseVerificationContract`
 *    rejects it with `cannot-parse`. Its checks cite `REQ-888`, a second
 *    undeclared REQ-ID which -- precisely because the contract is
 *    unreadable -- must NEVER reach `mismatches` (TEST-011).
 *  - `T-003` (In Progress) has no contract file at all, so the guarded read
 *    fails with `not-found` (TEST-017: the field is not filtered to `Done`).
 */
function seedUnreadableContractFixture(prefix: string): TempSddRoot {
  const tempRoot = makeTempSddRoot(prefix);
  const dir = tempRoot.dir;

  writeFile(
    dir,
    "AGENTS.md",
    ["# AGENTS", "", "## Active Spec Directories", "", "- `specs/demo/`", ""].join("\n"),
  );

  writeFile(
    dir,
    "specs/demo/tasks.md",
    [
      "# Tasks: demo",
      "",
      ["Task-Review-Status", "Passed"].join(": "),
      "",
      "## T-001",
      "",
      ["Approval", "Approved (alice 2026-01-01T00:00:00Z)"].join(": "),
      "Status: Done",
      "Risk: low",
      "",
      "## T-002",
      "",
      ["Approval", "Approved (alice 2026-01-01T00:00:00Z)"].join(": "),
      "Status: Done",
      "Risk: low",
      "",
      "## T-003",
      "",
      ["Approval", "Approved (alice 2026-01-01T00:00:00Z)"].join(": "),
      "Status: In Progress",
      "Risk: low",
      "",
    ].join("\n"),
  );

  writeFile(
    dir,
    "specs/demo/traceability.md",
    [
      "# Traceability: demo",
      "",
      "## REQ -> Task",
      "",
      "| REQ-ID | Task-ID |",
      "|--------|---------|",
      "| REQ-001 | T-001 |",
      "| REQ-002 | T-002 |",
      "",
      "## AC -> TEST -> Task",
      "",
      "| AC-ID | TEST-ID | Task-ID |",
      "|-------|---------|---------|",
      "| AC-001 | TEST-001 | T-001 |",
      "",
    ].join("\n"),
  );

  writeFile(
    dir,
    "specs/demo/verification/T-001.contract.json",
    JSON.stringify({
      task_id: "T-001",
      feature: "demo",
      risk: "low",
      required_workflow: "tdd",
      checks: [
        {
          id: "unit-tests",
          required: true,
          passes: true,
          requirement_ids: ["REQ-001", "REQ-909"],
        },
      ],
    }),
  );

  // Readable JSON, but bound to the wrong task -> cannot-parse. Its REQ-888
  // reference is deliberately undeclared in traceability.md.
  writeFile(
    dir,
    "specs/demo/verification/T-002.contract.json",
    JSON.stringify({
      task_id: "T-777",
      feature: "demo",
      risk: "low",
      required_workflow: "tdd",
      checks: [
        {
          id: "unit-tests",
          required: true,
          passes: true,
          requirement_ids: ["REQ-888"],
        },
      ],
    }),
  );

  // T-003: no verification/T-003.contract.json is written at all.

  return tempRoot;
}

/** Seeds a feature in which EVERY task's contract is readable (AC-002). */
function seedAllContractsReadableFixture(prefix: string): TempSddRoot {
  const tempRoot = makeTempSddRoot(prefix);
  const dir = tempRoot.dir;

  writeFile(
    dir,
    "AGENTS.md",
    ["# AGENTS", "", "## Active Spec Directories", "", "- `specs/demo/`", ""].join("\n"),
  );

  writeFile(
    dir,
    "specs/demo/tasks.md",
    [
      "# Tasks: demo",
      "",
      ["Task-Review-Status", "Passed"].join(": "),
      "",
      "## T-001",
      "",
      ["Approval", "Approved (alice 2026-01-01T00:00:00Z)"].join(": "),
      "Status: Done",
      "Risk: low",
      "",
      "## T-002",
      "",
      ["Approval", "Approved (alice 2026-01-01T00:00:00Z)"].join(": "),
      "Status: Done",
      "Risk: low",
      "",
    ].join("\n"),
  );

  writeFile(
    dir,
    "specs/demo/traceability.md",
    [
      "# Traceability: demo",
      "",
      "## REQ -> Task",
      "",
      "| REQ-ID | Task-ID |",
      "|--------|---------|",
      "| REQ-001 | T-001 |",
      "| REQ-002 | T-002 |",
      "",
      "## AC -> TEST -> Task",
      "",
      "| AC-ID | TEST-ID | Task-ID |",
      "|-------|---------|---------|",
      "| AC-001 | TEST-001 | T-001 |",
      "",
    ].join("\n"),
  );

  for (const [taskId, reqId] of [
    ["T-001", "REQ-001"],
    ["T-002", "REQ-002"],
  ] as const) {
    writeFile(
      dir,
      `specs/demo/verification/${taskId}.contract.json`,
      JSON.stringify({
        task_id: taskId,
        feature: "demo",
        risk: "low",
        required_workflow: "tdd",
        checks: [{ id: "unit-tests", required: true, passes: true, requirement_ids: [reqId] }],
      }),
    );
  }

  return tempRoot;
}

interface TraceabilityComparisonResponse {
  matches: number;
  mismatches: Array<{ subject: string; issue: string }>;
  unreadableContracts: Array<{ taskId: string; reason: string }>;
}

async function callCompare(fixture: { client: Client }): Promise<TraceabilityComparisonResponse> {
  const result = await fixture.client.callTool({
    name: "evidence_compare_to_traceability",
    arguments: { feature: "demo" },
  });
  const envelope = parseEnvelope(result as never);
  assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));
  assert.equal((envelope as { ok: boolean }).ok, true);
  return (envelope as { ok: true; data: TraceabilityComparisonResponse }).data;
}

test("TEST-001/TEST-011/TEST-017 (AC-001/AC-011/AC-017): unreadableContracts names every task whose contract could not be read, verbatim reason, without disturbing matches/mismatches", async () => {
  const tempRoot = seedUnreadableContractFixture("evidence-compare-unreadable-contracts");
  const fixture = await connectFixture(tempRoot);
  try {
    const data = await callCompare(fixture);

    // TEST-001 / TEST-017: BOTH the Done task with an unparsable contract
    // (T-002) and the non-Done task with no contract at all (T-003) appear.
    // T-001, whose contract IS readable, must not.
    assert.deepEqual(
      [...data.unreadableContracts].map((entry) => entry.taskId).sort(),
      ["T-002", "T-003"],
    );

    // TEST-001: `reason` is asserted EQUAL to the underlying
    // parseVerificationContract failure message -- not merely non-empty --
    // by re-deriving each message from the real parser against the same
    // fixture root, so a re-worded or path-interpolated string fails here
    // (security-spec.md Boundary B1).
    for (const taskId of ["T-002", "T-003"]) {
      const direct = parseVerificationContract(fixture.root, "demo", taskId);
      assert.equal(direct.ok, false, `${taskId}'s contract should not parse in this fixture`);
      const expectedReason = (direct as { ok: false; error: { message: string } }).error.message;
      const entry = data.unreadableContracts.find((candidate) => candidate.taskId === taskId);
      assert.ok(entry !== undefined, `${taskId} should appear in unreadableContracts`);
      assert.equal(entry?.reason, expectedReason);
    }

    // TEST-001: matches/mismatches are regression-pinned to the values this
    // same fixture produced BEFORE the field existed (captured in this
    // task's RED evidence): 5 checks performed (2 REQ -> Task rows, 1
    // AC -> TEST -> Task row, 2 requirementIds on T-001's readable
    // contract), 1 of which mismatches.
    assert.equal(data.matches, 4);
    assert.equal(data.mismatches.length, 1);
    assert.equal(data.mismatches[0]?.subject, "T-001 contract -> REQ-ID");
    assert.match(data.mismatches[0]?.issue ?? "", /REQ-909/);

    // TEST-011 (investigation.md INV-004's previously-untested branch):
    // mismatches/matches reflect ONLY the tasks whose contracts WERE
    // readable. T-002's unreadable contract cites REQ-888, which
    // traceability.md never declares -- had the tool cross-checked it, a
    // second mismatch would exist. It must not.
    assert.equal(
      data.mismatches.some((mismatch) => mismatch.issue.includes("REQ-888")),
      false,
    );
    assert.equal(
      data.mismatches.some((mismatch) => mismatch.subject.startsWith("T-002")),
      false,
    );
  } finally {
    await fixture.cleanup();
  }
});

test("TEST-002 (AC-002): unreadableContracts is present and empty when every task's contract is readable", async () => {
  const tempRoot = seedAllContractsReadableFixture("evidence-compare-all-contracts-readable");
  const fixture = await connectFixture(tempRoot);
  try {
    const data = await callCompare(fixture);
    assert.ok(Array.isArray(data.unreadableContracts));
    assert.deepEqual(data.unreadableContracts, []);
    assert.deepEqual(data.mismatches, []);
    assert.equal(data.matches, 5);
  } finally {
    await fixture.cleanup();
  }
});

test("TEST-009 leg (AC-009): the v1 contract requires unreadableContracts on traceabilityComparisonData and keeps additionalProperties:false and $id", async () => {
  const schemaPath = join(makeRealRepoRoot().path, "contracts", "sdd-forge-mcp-tools.v1.schema.json");
  const schema = JSON.parse(readFileSync(schemaPath, "utf-8")) as {
    $id: string;
    $defs: {
      traceabilityComparisonData: {
        additionalProperties: boolean;
        required: string[];
        properties: {
          unreadableContracts: {
            type: string;
            items: { type: string; additionalProperties: boolean; required: string[] };
          };
        };
      };
    };
  };

  assert.equal(schema.$id, "https://sdd-forge.dev/contracts/sdd-forge-mcp-tools.v1.schema.json");
  const def = schema.$defs.traceabilityComparisonData;
  assert.equal(def.additionalProperties, false);
  assert.deepEqual(def.required, ["kind", "feature", "matches", "mismatches", "unreadableContracts"]);
  assert.equal(def.properties.unreadableContracts.type, "array");
  assert.equal(def.properties.unreadableContracts.items.additionalProperties, false);
  assert.deepEqual(def.properties.unreadableContracts.items.required, ["taskId", "reason"]);

  // The real ajv validator (never a text-marker check) is the authority on
  // the required-ness: an otherwise well-formed ok envelope that OMITS the
  // field must fail, and the same envelope WITH it must pass.
  const validate = getEnvelopeValidator();
  const withoutField = {
    ok: true,
    data: { kind: "traceability-comparison", feature: "demo", matches: 0, mismatches: [] },
  };
  assert.equal(validate(withoutField), false, "an envelope omitting unreadableContracts must fail validation");

  const withField = {
    ok: true,
    data: {
      kind: "traceability-comparison",
      feature: "demo",
      matches: 0,
      mismatches: [],
      unreadableContracts: [{ taskId: "T-002", reason: "some parser message" }],
    },
  };
  assert.ok(validate(withField), JSON.stringify(validate.errors));
});

// --- input validation --------------------------------------------------------

test("every evidence tool rejects a malformed feature argument as invalid-input", async () => {
  const tempRoot = seedDemoFixture("evidence-invalid-feature");
  const fixture = await connectFixture(tempRoot);
  try {
    for (const name of [
      "evidence_get_bundle",
      "evidence_validate_paths",
      "evidence_find_missing",
      "evidence_summarize_contract_checks",
    ]) {
      const result = await fixture.client.callTool({
        name,
        arguments: { feature: "../escape", taskId: "T-001" },
      });
      const envelope = parseEnvelope(result as never);
      assert.ok(getEnvelopeValidator()(envelope), `${name}: ${JSON.stringify(getEnvelopeValidator().errors)}`);
      assert.equal((envelope as { ok: boolean }).ok, false, `${name} should reject ../escape`);
      assert.equal(
        (envelope as { ok: false; error: { code: string } }).error.code,
        "invalid-input",
        `${name} should report invalid-input`,
      );
    }

    const compareResult = await fixture.client.callTool({
      name: "evidence_compare_to_traceability",
      arguments: { feature: "../escape" },
    });
    const compareEnvelope = parseEnvelope(compareResult as never);
    assert.ok(getEnvelopeValidator()(compareEnvelope));
    assert.equal((compareEnvelope as { ok: boolean }).ok, false);
    assert.equal((compareEnvelope as { ok: false; error: { code: string } }).error.code, "invalid-input");
  } finally {
    await fixture.cleanup();
  }
});
