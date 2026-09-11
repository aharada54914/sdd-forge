import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { Ajv } from "ajv";
import { load } from "js-yaml";

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

test("evaluation accepts unavailable duration without treating it as zero", () => {
  const root = new URL("../../../../", import.meta.url);
  const contract = JSON.parse(readFileSync(new URL("contracts/adversarial-review-evaluation.v1.schema.json", root), "utf8"));
  const check = new Ajv({ strict: false, validateFormats: false }).compile(contract);
  const record = JSON.parse(readFileSync(new URL("reports/adversarial-review/feat-adversarial-review-enhancements/evaluation.json", root), "utf8"));
  assert.equal(check(record), true, "historical record remains valid");
  for (const duration of [null, 0, 1234]) {
    assert.equal(check({ ...record, duration_ms: duration }), true, JSON.stringify(check.errors));
  }
  for (const duration of [-1, 0.5, "unknown", "0", false]) {
    assert.equal(check({ ...record, duration_ms: duration }), false);
  }
});

test("cross critique accepts a supported finding", () => assert.equal(accepts(verdict()), true));
test("evaluation distinguishes measured tokens from unavailable telemetry", () => {
  const root = new URL("../../../../", import.meta.url);
  const contract = JSON.parse(readFileSync(new URL("contracts/adversarial-review-evaluation.v1.schema.json", root), "utf8"));
  const check = new Ajv({ strict: false, validateFormats: false }).compile(contract);
  const record = JSON.parse(readFileSync(new URL("reports/adversarial-review/feat-adversarial-review-enhancements/evaluation.json", root), "utf8"));
  assert.equal(check(record), true, "do not fabricate telemetry for historical records");
  for (const token_usage of [
    { total_tokens: null, unavailable_reason: "Host does not expose token telemetry" },
    { total_tokens: 0, source: "provider usage response" },
    { total_tokens: 1234, source: "provider usage response" },
  ]) assert.equal(check({ ...record, token_usage }), true, JSON.stringify(check.errors));
  for (const token_usage of [
    {}, { total_tokens: null }, { total_tokens: null, unavailable_reason: " " },
    { total_tokens: null, source: "provider" }, { total_tokens: 12 },
    { total_tokens: 12, source: " " }, { total_tokens: -1, source: "provider" },
    { total_tokens: 1.5, source: "provider" }, { total_tokens: "12", source: "provider" },
    { total_tokens: 0, unavailable_reason: "not exposed" },
    { total_tokens: 12, source: "provider", unavailable_reason: "not exposed" },
  ]) assert.equal(check({ ...record, token_usage }), false, JSON.stringify(token_usage));
});
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
for (const [field, prefix] of [
  ["related_requirements", "REQ"], ["related_acceptance_tests", "AC"], ["related_tasks", "T"],
]) {
  test(`in_scope requires nonempty ${field}`, () => {
    for (const refs of [[], [""], ["   "]]) {
      assert.equal(accepts({ ...verdict(), scope: { assessment: "in_scope", [field]: refs } }), false);
    }
    assert.equal(accepts({ ...verdict(), scope: { assessment: "in_scope", [field]: [`${prefix}-001`] } }), true);
  });
  test(`${field} rejects unrelated or malformed identifiers`, () => {
    for (const assessment of ["in_scope", "out_of_scope", "unclear"]) {
      for (const id of ["REF-001", `${prefix.toLowerCase()}-001`, `${prefix}-`,
        ` ${prefix}-001`, `${prefix}-001 `, `${prefix}-001\n`, `${prefix}-one two`]) {
        assert.equal(accepts({ ...verdict(), scope: { assessment, [field]: [id] } }), false,
          `${assessment}: ${JSON.stringify(id)}`);
      }
      assert.equal(accepts({ ...verdict(), scope: { assessment, [field]: [`${prefix}-001a`] } }), true);
    }
  });
}
test("concerns remain allowed for support but cannot reject findings", () => {
  const record = { ...verdict(), basis: { kind: "concern" }, scope: { assessment: "unclear" } };
  assert.equal(accepts(record), true);
  assert.equal(accepts({ ...record, verdict: "PROPOSE-REJECT" }), false);
});

test("filled report template conforms to its metadata contract", () => {
  const root = new URL("../../../../", import.meta.url);
  const contract = JSON.parse(readFileSync(new URL("contracts/adversarial-review-report.v1.schema.json", root), "utf8"));
  const check = new Ajv({ strict: false, validateFormats: false }).compile(contract);
  const template = readFileSync(new URL("skills/adversarial-review/templates/report-template.md", root), "utf8");
  const block = template.match(/```yaml\n([\s\S]*?)\n```/);
  assert.ok(block, "metadata YAML block must exist");
  const values: Record<string, string> = {
    MERGE_BASE_SHA: "a".repeat(40), HEAD_SHA: "b".repeat(40),
    DIFF_SHA256: "c".repeat(64), ISO8601_UTC: "2026-09-11T00:00:00Z",
    SKILL_GIT_SHA_OR_DESCRIBE: "d".repeat(40), RUN_ID_A: "reviewer-a-001", RUN_ID_B: "reviewer-b-001",
  };
  const rendered = block[1].replace(/\{\{([A-Z0-9_]+)\}\}/g, (_, key: string) => {
    assert.ok(Object.hasOwn(values, key), `unknown placeholder: ${key}`);
    return JSON.stringify(values[key]);
  });
  const metadata = load(rendered);
  assert.equal(check(metadata), true, JSON.stringify(check.errors));
  assert.equal(check({ ...(metadata as Record<string, unknown>), reviewer_run_ids: [
    { reviewer_a: values.RUN_ID_A }, { reviewer_b: values.RUN_ID_B },
  ] }), false, "legacy array shape must remain rejected");
});
