// Read-only currentness check. The expected report digest comes from the review
// receipt/PR metadata, never from hashing the report again at verification time.
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { parseArgs } from "node:util";
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { load } from "js-yaml";
import { Ajv } from "ajv";

try {
  const { values } = parseArgs({ options: Object.fromEntries(
    ["repo", "report", "base", "report-sha256"].map(name => [name, { type: "string" }])) });
  if (Object.values(values).some(value => !value) || Object.keys(values).length !== 4 ||
      !/^[0-9a-f]{64}$/.test(values["report-sha256"])) throw new Error("invalid-arguments");
  const repo = resolve(values.repo);
  const git = (...args) => execFileSync("git", ["-C", repo, ...args],
    { maxBuffer: 64 * 1024 * 1024, timeout: 30000, stdio: ["ignore", "pipe", "pipe"] });
  const hash = bytes => createHash("sha256").update(bytes).digest("hex");
  const report = readFileSync(resolve(repo, values.report));
  if (hash(report) !== values["report-sha256"]) throw new Error("report-digest-mismatch");
  const block = report.toString("utf8").match(/```yaml\r?\n([\s\S]*?)\r?\n```/);
  if (!block) throw new Error("missing-metadata");
  const metadata = load(block[1]);
  const schema = JSON.parse(readFileSync(new URL("../../../contracts/adversarial-review-report.v1.schema.json", import.meta.url), "utf8"));
  const validate = new Ajv({ strict: false, validateFormats: false }).compile(schema);
  if (!validate(metadata)) throw new Error("invalid-metadata");
  const head = git("rev-parse", "--verify", "HEAD^{commit}").toString().trim();
  const baseTip = git("rev-parse", "--verify", "--end-of-options", `${values.base}^{commit}`).toString().trim();
  const base = git("merge-base", head, baseTip).toString().trim();
  if (metadata.head_sha !== head) throw new Error("head-mismatch");
  if (metadata.merge_base_sha !== base) throw new Error("merge-base-mismatch");
  const diff = git("diff", "--no-ext-diff", "--no-textconv", `${base}..${head}`);
  if (metadata.diff_sha256 !== hash(diff)) throw new Error("diff-digest-mismatch");
  process.stdout.write(JSON.stringify({ status: "current", head_sha: head, merge_base_sha: base,
    report_sha256: values["report-sha256"] }) + "\n");
} catch (error) {
  const known = ["invalid-arguments", "report-digest-mismatch", "missing-metadata", "invalid-metadata",
    "head-mismatch", "merge-base-mismatch", "diff-digest-mismatch"];
  const reason = known.includes(error.message) ? error.message : "verification-error";
  process.stdout.write(JSON.stringify({ status: "not-current", reason }) + "\n");
  process.exitCode = 1;
}
