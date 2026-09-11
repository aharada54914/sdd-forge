import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { Ajv } from "ajv";

// Compiled tests live under mcp/sdd-forge-mcp/dist-test/tests/.
const schema = JSON.parse(readFileSync(new URL("../../../../contracts/cross-critique.v1.schema.json", import.meta.url), "utf8"));
const validate = new Ajv({ strict: false, validateFormats: false }).compile(schema);
const citation = { path: "src/example.ts", line_start: 1, claim: "Concrete supporting evidence" };
function verdict() {
  return {
    target_finding_id: "A-1", critic_role: "reviewer-b", verdict: "SUPPORT",
    basis: { kind: "code_evidence", citations: [citation] },
    scope: { assessment: "in_scope", related_requirements: ["REQ-001"] },
  };
}
function accepts(record: unknown) {
  return validate({ schema_version: "cross-critique.v1", round_id: "round-1",
    status: "complete", created_at: "2026-09-11T00:00:00Z", verdicts: [record] });
}

test("cross critique accepts a supported finding", () => assert.equal(accepts(verdict()), true));
test("severity change requires proposed severity", () => {
  assert.equal(accepts({ ...verdict(), verdict: "PROPOSE-SEVERITY-CHANGE" }), false);
  assert.equal(accepts({ ...verdict(), verdict: "PROPOSE-SEVERITY-CHANGE", proposed_severity: "Minor" }), true);
});
for (const kind of ["code_evidence", "spec_evidence"]) {
  test(`${kind} requires citations even for SUPPORT`, () => {
    assert.equal(accepts({ ...verdict(), basis: { kind } }), false);
    assert.equal(accepts({ ...verdict(), basis: { kind, citations: [citation] } }), true);
  });
}
for (const field of ["related_requirements", "related_acceptance_tests", "related_tasks"]) {
  test(`in_scope requires nonempty ${field}`, () => {
    for (const refs of [[], [""], ["   "]]) {
      assert.equal(accepts({ ...verdict(), scope: { assessment: "in_scope", [field]: refs } }), false);
    }
    assert.equal(accepts({ ...verdict(), scope: { assessment: "in_scope", [field]: ["REF-001"] } }), true);
  });
}
test("concerns remain allowed for support but cannot reject findings", () => {
  const record = { ...verdict(), basis: { kind: "concern" }, scope: { assessment: "unclear" } };
  assert.equal(accepts(record), true);
  assert.equal(accepts({ ...record, verdict: "PROPOSE-REJECT" }), false);
});
