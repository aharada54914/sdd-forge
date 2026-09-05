import assert from "node:assert/strict";
import fs from "node:fs";
import { createRequire } from "node:module";
import path from "node:path";
import process from "node:process";

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");
const requireFromCiMcp = createRequire(path.join(root, "mcp/ci-mcp/package.json"));
let Ajv;
try {
  Ajv = requireFromCiMcp("ajv/dist/ajv.js");
} catch {
  throw new Error("Ajv is unavailable; run `npm ci --prefix mcp/ci-mcp` first");
}

const load = (relativePath) =>
  JSON.parse(fs.readFileSync(path.join(root, relativePath), "utf8"));
// Draft-07 conditionals routinely require a property declared on an ancestor;
// keep every other strict check while allowing that standard schema shape.
const ajv = new Ajv({
  allErrors: true,
  strict: true,
  strictRequired: false,
  strictTypes: false,
  validateFormats: false,
});
ajv.addKeyword({ keyword: "x-stale-judgement-rules", schemaType: "array" });
const compile = (name) =>
  ajv.compile(load(`contracts/${name}.v1.schema.json`));
const expectValid = (validate, value, label) => {
  assert.equal(validate(value), true, `${label}: ${ajv.errorsText(validate.errors)}`);
};
const expectInvalid = (validate, value, label) => {
  assert.equal(validate(value), false, `${label}: unexpectedly valid`);
};

const crossCritique = compile("cross-critique");
const baseVerdict = {
  target_finding_id: "A-1",
  critic_role: "reviewer-b",
  verdict: "SUPPORT",
  basis: {
    kind: "code_evidence",
    citations: [{ path: "src/example.ts", line_start: 1, line_end: 2, claim: "proves the behavior" }],
  },
  scope: { assessment: "in_scope", related_requirements: ["REQ-1"] },
};
const annex = {
  schema_version: "cross-critique.v1",
  round_id: "example-round",
  status: "complete",
  created_at: "2026-08-31T00:00:00Z",
  verdicts: [baseVerdict],
};
expectValid(crossCritique, annex, "complete annex");
expectInvalid(crossCritique, { ...annex, verdicts: [] }, "complete annex needs verdicts");
expectInvalid(crossCritique, {
  ...annex,
  verdicts: [{ ...baseVerdict, basis: { kind: "code_evidence" } }],
}, "evidence basis needs citations");
expectInvalid(crossCritique, {
  ...annex,
  verdicts: [{ ...baseVerdict, basis: { kind: "concern", citations: baseVerdict.basis.citations } }],
}, "concern cannot masquerade as cited evidence");
expectInvalid(crossCritique, {
  ...annex,
  verdicts: [{ ...baseVerdict, scope: { assessment: "in_scope", related_requirements: [] } }],
}, "in-scope references cannot be empty");
expectInvalid(crossCritique, {
  ...annex,
  verdicts: [{ ...baseVerdict, scope: { assessment: "in_scope", related_tasks: ["task one"] } }],
}, "scope IDs use canonical vocabulary");
expectValid(crossCritique, {
  ...annex,
  status: "unavailable",
  unavailable_reason: "reviewer context lost",
  verdicts: [],
}, "unavailable annex");

const report = compile("adversarial-review-report");
const reportMetadata = {
  schema_version: "adversarial-review-report.v1",
  merge_base_sha: "a".repeat(40),
  head_sha: "b".repeat(40),
  diff_sha256: "c".repeat(64),
  created_at: "2026-08-31T00:00:00Z",
  skill_version: "v1",
  reviewer_run_ids: { reviewer_a: "run-a", reviewer_b: "run-b" },
};
expectValid(report, reportMetadata, "report metadata");
expectInvalid(report, { ...reportMetadata, head_sha: "b".repeat(7) }, "abbreviated SHA");
expectInvalid(report, {
  ...reportMetadata,
  reviewer_run_ids: [{ reviewer_a: "run-a" }, { reviewer_b: "run-b" }],
}, "run IDs must be a mapping");

const historicalReport = fs.readFileSync(
  path.join(root, "reports/adversarial-review/feat-adversarial-review-enhancements/report.md"),
  "utf8",
);
const field = (name) => {
  const match = historicalReport.match(new RegExp(`^\\s*${name}:\\s+(\\S+)\\s*$`, "m"));
  assert.ok(match, `historical report is missing ${name}`);
  return match[1];
};
expectValid(report, {
  schema_version: field("schema_version"),
  merge_base_sha: field("merge_base_sha"),
  head_sha: field("head_sha"),
  diff_sha256: field("diff_sha256"),
  created_at: field("created_at"),
  skill_version: field("skill_version"),
  reviewer_run_ids: {
    reviewer_a: field("reviewer_a"),
    reviewer_b: field("reviewer_b"),
  },
}, "checked-in report metadata");

const evaluation = compile("adversarial-review-evaluation");
const evaluationRecord = load("reports/adversarial-review/feat-adversarial-review-enhancements/evaluation.json");
expectValid(evaluation, evaluationRecord, "checked-in evaluation");
expectInvalid(evaluation, { ...evaluationRecord, reviewer_launch_count: 1 }, "two-reviewer minimum");
expectInvalid(evaluation, {
  ...evaluationRecord,
  phase_r: { ran: true, verified_count: 1 },
}, "completed Phase R needs every outcome count");

const template = fs.readFileSync(
  path.join(root, "skills/adversarial-review/templates/report-template.md"),
  "utf8",
);
assert.match(template, /reviewer_run_ids:\n  reviewer_a:/);
assert.doesNotMatch(template, /reviewer_run_ids:\n  - reviewer_a:/);
assert.match(template, /git diff --binary --no-ext-diff/);

process.stdout.write("adversarial-review contract tests passed\n");
