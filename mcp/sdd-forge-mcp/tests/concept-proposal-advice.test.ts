import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { test, type TestContext } from "node:test";
import { conceptAdvice, conceptProposalAdvice } from "../src/concept-proposal-advice.js";
import { makeTempSddRoot, writeFile } from "./test-helpers.js";

function fixture(t: TestContext) {
  const { root, dir, cleanup } = makeTempSddRoot("concept-advice");
  t.after(cleanup);
  const prefix = "specs/orders/concept-test";
  const seed = "Order a book.\n";
  const digest = (value: string) => createHash("sha256").update(value).digest("hex");
  const write = (suffix: string, contents: string) => writeFile(dir, prefix + suffix, contents);
  const advise = (bootstrap = false) => conceptProposalAdvice(root, "orders", bootstrap);
  function propose(classification: string, version = "concept-test/v2") {
    write("-seed.md", seed);
    const document = {
      schema: version, feature: "orders", proposal: classification, rationale: "Compare the order concept.",
      distinctions: [{ concepts: ["order"], judgment: "same", confirmed: true }],
      inputs: [
        { path: "domain/domain-contract.json", sha256: "0".repeat(64) },
        { path: prefix + "-seed.md", sha256: digest(seed) },
      ],
    };
    const json = JSON.stringify(document, null, 2) + "\r\n";
    const md = "# 提案\r\n\r\n```json\r\n" + json + "```\r\n";
    write(".json", json);
    write(".md", md);
    function decide(decision: string, overrides = {}) {
      write(".decision.json", JSON.stringify({
        schema: "concept-test-decision/v1", feature: "orders", decision,
        proposal_json_sha256: digest(json), proposal_md_sha256: digest(md), ...overrides,
      }));
    }
    return { document, json, md, decide };
  }
  const task = { id: "T-001", status: "Implementation Complete" };
  function recordGate(status: "BLOCK" | "DEFER" | "REJECT", error?: string) {
    writeFile(dir, "reports/quality-gate/orders-T-001.execution.json", JSON.stringify({
      schema: "sdd-gate-execution/v1", feature: "orders", taskId: task.id, verdict: "FAIL",
      checks: { conceptTest: { passed: false, status, error } },
    }));
  }
  const afterGate = () => conceptAdvice(root, "orders", [task], false);
  return { dir, propose, write, advise, recordGate, afterGate };
}

test("an unrelated project has no Concept Test advice", t => {
  const f = fixture(t);
  assert.equal(f.advise(true), undefined);
  assert.equal(f.advise(false), undefined);
});

test("a feature seed resumes the bootstrap interview only before the specification is ready", t => {
  const f = fixture(t);
  f.write("-seed.md", "Order a book.\n");
  assert.equal(f.advise(true)?.action.command, "human: resume the original /sdd-bootstrap:bootstrap conversation for orders");
  assert.match(f.advise(true)?.action.rationale ?? "", /元のモード・入力元/);
  assert.equal(f.advise(false), undefined);
});

for (const classification of ["NEW_CONCEPT_CANDIDATE", "RESPONSIBILITY_CONFLICT", "REQUIRES_HUMAN_DECISION"]) {
  test(`missing judgment for ${classification} requests an operator choice`, t => {
    const f = fixture(t);
    f.propose(classification);
    for (const bootstrap of [true, false]) {
      const advice = f.advise(bootstrap);
      const action = advice?.action;
      assert.equal(advice?.decision, undefined);
      assert.equal(action?.phase, "blocked");
      assert.match(action.command, /--feature orders --confirm/);
    }
  });
}

for (const [decision, expected] of [
  ["defer-to-domain-update", "validate"],
  ["rejected", "human: stop work on the rejected proposal for orders"],
  ["proceed", undefined],
] as const) {
  test(`a decision matching both current files routes ${decision}`, t => {
    const f = fixture(t);
    f.propose("NEW_CONCEPT_CANDIDATE").decide(decision);
    for (const bootstrap of [true, false]) {
      const advice = f.advise(bootstrap);
      const action = advice?.action;
      if (expected === undefined) {
        if (bootstrap) {
          assert.equal(action?.phase, "bootstrap");
          assert.match(action.command, /resume the original .*bootstrap conversation for orders/);
        } else {
          assert.equal(action, undefined);
        }
      } else {
        assert.equal(advice?.decision, decision === "rejected" ? "REJECT" : "DEFER");
        assert.ok(action);
        if (decision === "defer-to-domain-update") {
          assert.match(action.command, /validate-concept-test.*--feature orders --require-v2/);
          assert.match(action.rationale, /更新済み|更新後/);
          assert.match(action.rationale, /未更新|まだ更新/);
        } else {
          assert.equal(action.command, expected);
        }
        assert.match(action.rationale, /specs\/orders\/concept-test\.decision\.json/);
      }
    }
  });
}

for (const format of ["json", "md"] as const) {
  test(`a byte change in the ${format} file invalidates displayed rejection`, t => {
    const f = fixture(t);
    const proposal = f.propose("RESPONSIBILITY_CONFLICT");
    proposal.decide("rejected");
    f.write("." + format, proposal[format].replaceAll("\r\n", "\n"));
    const advice = f.advise();
    assert.equal(advice?.decision, undefined);
    const action = advice?.action;
    assert.match(action?.command ?? "", /--require-v2/);
    assert.match(action?.rationale ?? "", /SHA-256/);
  });
}

test("a decision for a different feature cannot stop work as a rejection", t => {
  const f = fixture(t);
  f.propose("REQUIRES_HUMAN_DECISION").decide("rejected", { feature: "shipping" });
  assert.match(f.advise()?.action.command ?? "", /--require-v2/);
});

test("malformed, unknown and orphaned records refer to validation", t => {
  const f = fixture(t);
  f.write(".decision.json", "{}");
  assert.match(f.advise()?.action.command ?? "", /--require-v2/);
  f.write(".json", "{");
  assert.match(f.advise()?.action.command ?? "", /--require-v2/);
  f.propose("UNKNOWN");
  assert.match(f.advise()?.action.command ?? "", /--require-v2/);
  f.propose("REQUIRES_HUMAN_DECISION").decide("unknown");
  assert.match(f.advise()?.action.command ?? "", /--require-v2/);
});

test("FITS without a decision gives no stop advice and mixed FITS records require inspection", t => {
  const f = fixture(t);
  const fits = f.propose("FITS_EXISTING_CONCEPTS");
  assert.equal(f.advise(false), undefined);
  assert.equal(f.advise(true)?.action.phase, "bootstrap");
  fits.decide("rejected");
  assert.match(f.advise()?.action.command ?? "", /--require-v2/);
});

const RECREATE = "human: recreate the Concept Test proposal for orders as concept-test/v2";

function assertRecreateAdvice(action: { command: string; rationale: string } | undefined) {
  assert.equal(action?.command, RECREATE);
  assert.match(action.rationale, /concept-test\/v1/);
  assert.match(action.rationale, /specs\/orders\/concept-test\.approval\.json/);
  assert.match(action.rationale, /domain\//);
}

test("a v1 record, signed or not, is advised to be recreated as v2", t => {
  for (const classification of ["FITS_EXISTING_CONCEPTS", "NEW_CONCEPT_CANDIDATE"]) {
    const f = fixture(t);
    f.propose(classification, "concept-test/v1");
    if (classification !== "FITS_EXISTING_CONCEPTS") f.write(".approval.json", "{}");
    for (const bootstrap of [true, false]) assertRecreateAdvice(f.advise(bootstrap)?.action);
  }
});

test("a v2 proposal combined with an old approval does not prompt for another decision", t => {
  const f = fixture(t);
  f.propose("NEW_CONCEPT_CANDIDATE");
  f.write(".approval.json", "{}");
  assert.match(f.advise()?.action.command ?? "", /--require-v2/);
});

test("a Markdown-only v1 record is advised to be recreated, not to re-open the bootstrap seed", t => {
  const f = fixture(t);
  f.write("-seed.md", "Order a book.\n");
  f.write(".md", '```json\n{"schema":"concept-test/v1"}\n```\n');
  for (const bootstrap of [true, false]) assertRecreateAdvice(f.advise(bootstrap)?.action);
});

test("a gate stopped on a retired v1 record advises recreating it", t => {
  const retired = "concept-test: BLOCK: concept-test/v1 records are no longer supported; recreate the proposal as "
    + "concept-test/v2 by running the Concept Test again, then delete any leftover "
    + "specs/orders/concept-test.approval.json. In a project without domain/, where the Concept Test does not run, "
    + "delete specs/orders/concept-test.md, specs/orders/concept-test.json and "
    + "specs/orders/concept-test.approval.json instead";
  for (const [error, staged] of [[retired, false],
    [retired + ". The Git index still holds the v1 record; stage its removal too.", true]] as const) {
    const f = fixture(t);
    f.recordGate("BLOCK", error);
    const advice = f.afterGate();
    assertRecreateAdvice(advice);
    assert.match(advice?.rationale ?? "", /reports\/quality-gate\/orders-T-001\.execution\.json/);
    assert.equal(/インデックス/.test(advice?.rationale ?? ""), staged);
  }
});

test("a Markdown-only v2 proposal needs its companion JSON", t => {
  const f = fixture(t);
  f.write(".md", '```json\n{"schema":"concept-test/v2"}\n```\n');
  assert.match(f.advise()?.action.command ?? "", /--require-v2/);
});

test("a missing or different Markdown proposal does not solicit a human choice", t => {
  const f = fixture(t);
  f.propose("REQUIRES_HUMAN_DECISION");
  for (const md of ["", '```json\n{"schema":"concept-test/v2","feature":"orders","proposal":"FITS_EXISTING_CONCEPTS"}\n```\n']) {
    f.write(".md", md);
    assert.match(f.advise()?.action.command ?? "", /--require-v2/);
  }
});

function markdown(copy: unknown): string {
  return "# 提案\n\n```json\n" + JSON.stringify(copy) + "\n```\n";
}

test("the complete proposal matches with reordered object keys at all levels", t => {
  const f = fixture(t);
  const { document } = f.propose("NEW_CONCEPT_CANDIDATE");
  const copy = {
    inputs: document.inputs.map(({ path, sha256 }) => ({ sha256, path })),
    distinctions: document.distinctions.map(({ concepts, judgment, confirmed }) => ({ confirmed, judgment, concepts })),
    rationale: document.rationale, proposal: document.proposal, feature: document.feature, schema: document.schema,
  };
  f.write(".md", markdown(copy));
  assert.match(f.advise()?.action.command ?? "", /--confirm/);
});

test("rationale, distinctions, input pins, missing or extra fields and array order all participate in the comparison", t => {
  const f = fixture(t);
  const { document } = f.propose("NEW_CONCEPT_CANDIDATE");
  const { rationale, ...withoutRationale } = document;
  for (const copy of [
    { ...document, rationale: rationale + " different" },
    { ...document, distinctions: [{ ...document.distinctions[0], confirmed: false }] },
    { ...document, inputs: document.inputs.map(pin => ({ ...pin, sha256: "9".repeat(64) })) },
    withoutRationale,
    { ...document, extra: true },
    { ...document, inputs: [...document.inputs].reverse() },
  ]) {
    f.write(".md", markdown(copy));
    const advice = f.advise();
    assert.equal(advice?.decision, undefined);
    assert.match(advice?.action.command ?? "", /--require-v2/);
    assert.match(advice?.action.rationale ?? "", /Markdown/);
  }
});

test("a recorded DEFER revalidates with and without a matching local receipt", t => {
  const f = fixture(t);
  f.recordGate("DEFER");
  for (const addReceipt of [false, true]) {
    if (addReceipt) f.propose("RESPONSIBILITY_CONFLICT").decide("defer-to-domain-update");
    const advice = f.afterGate();
    assert.match(advice?.command ?? "", /validate-concept-test.*--require-v2/);
    assert.match(advice?.rationale ?? "", /DEFER/);
    assert.match(advice?.rationale ?? "", /更新済み|更新後/);
    assert.match(advice?.rationale ?? "", /未更新|まだ更新/);
  }
});

test("a new proceed or FITS after an earlier stop routes to validation and gate re-run", t => {
  for (const status of ["BLOCK", "DEFER", "REJECT"] as const) {
    for (const fits of [true, false]) {
      const f = fixture(t);
      f.recordGate(status, status === "BLOCK" ? "concept-test: BLOCK: run --confirm in a separate human-operated terminal" : undefined);
      if (fits) f.propose("FITS_EXISTING_CONCEPTS");
      else f.propose("REQUIRES_HUMAN_DECISION").decide("proceed");
      const advice = f.afterGate();
      assert.match(advice?.command ?? "", /validate-concept-test.*--require-v2/);
      assert.match(advice?.rationale ?? "", /CONTINUE.*品質ゲート/);
    }
  }
});

for (const classification of ["FITS_EXISTING_CONCEPTS", "NEW_CONCEPT_CANDIDATE"]) {
  test(`bootstrap resumes with its original mode and source after CONTINUE for ${classification}`, t => {
    const f = fixture(t);
    const proposal = f.propose(classification);
    if (classification !== "FITS_EXISTING_CONCEPTS") proposal.decide("proceed");
    const action = f.advise(true)?.action;
    assert.equal(action?.phase, "bootstrap");
    assert.match(action.command, /human: resume the original .*bootstrap conversation for orders/);
    assert.match(action.rationale, /--feature orders --require-v2/);
    assert.match(action.rationale, /CONTINUE/);
    assert.match(action.rationale, /元のモード・入力元・対象feature/);
    assert.equal(f.advise(false), undefined);
  });
}

test("an unrelated or inconsistent execution at the expected filename supplies no DDD stop", t => {
  const f = fixture(t);
  const report = {
    schema: "sdd-gate-execution/v1", feature: "orders", taskId: "T-001", verdict: "FAIL",
    checks: { conceptTest: { status: "REJECT", passed: false } },
  };
  for (const contents of [
    "{", JSON.stringify({ ...report, feature: "shipping" }), JSON.stringify({ ...report, taskId: "T-002" }),
    JSON.stringify({ ...report, schema: "unknown" }), JSON.stringify({ ...report, verdict: "PASS" }),
    JSON.stringify({ ...report, checks: { conceptTest: { status: "REJECT", passed: true } } }),
    JSON.stringify({ ...report, checks: { conceptTest: { status: "UNKNOWN", passed: false } } }),
  ]) {
    writeFile(f.dir, "reports/quality-gate/orders-T-001.execution.json", contents);
    assert.equal(f.afterGate(), undefined);
  }
});
