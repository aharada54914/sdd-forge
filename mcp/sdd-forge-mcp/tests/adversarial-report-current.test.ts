import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync, execFileSync } from "node:child_process";
import { createHash } from "node:crypto";

test("report currentness rejects changed head, base, diff, and report bytes", () => {
  const repo = mkdtempSync(join(tmpdir(), "ar-current-"));
  const cli = fileURLToPath(new URL("../../scripts/check-adversarial-report.mjs", import.meta.url));
  const git = (...args: string[]) => execFileSync("git", ["-C", repo, ...args]);
  const hash = (bytes: string | Buffer) => createHash("sha256").update(bytes).digest("hex");
  try {
    git("init", "-b", "main");
    git("config", "user.name", "Report Test");
    git("config", "user.email", "report-test@example.invalid");
    git("commit", "--allow-empty", "-m", "base");
    const base = git("rev-parse", "HEAD").toString().trim();
    git("checkout", "-b", "feature");
    writeFileSync(join(repo, "change.txt"), "change\n");
    writeFileSync(join(repo, "change.bin"), Buffer.from([0, 1, 2, 255]));
    git("add", "change.txt", "change.bin");
    git("commit", "-m", "feature");
    const head = git("rev-parse", "HEAD").toString().trim();
    const metadata = { schema_version: "adversarial-review-report.v1", merge_base_sha: base,
      head_sha: head, diff_sha256: hash(git("diff", "--binary", "--no-ext-diff", "--no-textconv", `${base}..${head}`)),
      created_at: "2026-09-11T00:00:00Z", skill_version: head,
      reviewer_run_ids: { reviewer_a: "run-a", reviewer_b: "run-b" } };
    const render = (value: unknown) => `# Review\n\n\`\`\`yaml\n${JSON.stringify(value)}\n\`\`\`\n`;
    const original = render(metadata);
    // Host diff drivers must not change the bytes bound by the review.
    writeFileSync(join(repo, ".git", "info", "attributes"), "change.txt diff=unavailable-driver\n");
    git("config", "diff.unavailable-driver.textconv", "sdd-fixture-missing-textconv");
    git("config", "diff.external", "sdd-fixture-missing-external-diff");
    const report = join(repo, "report.md");
    const run = (expected = hash(original)) => spawnSync(process.execPath, [cli,
      "--repo", repo, "--report", report, "--base", "main", "--report-sha256", expected], { encoding: "utf8" });
    const rejected = (reason: string, expected = hash(original)) => {
      const result = run(expected);
      assert.equal(result.status, 1, result.stderr);
      assert.deepEqual(JSON.parse(result.stdout), { status: "not-current", reason });
    };
    writeFileSync(report, original);
    const result = run();
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(JSON.parse(result.stdout), { status: "current", head_sha: head,
      merge_base_sha: base, report_sha256: hash(original) });
    for (const created_at of ["2024-02-29T00:00:00Z", "2026-09-11T09:00:00+09:00"]) {
      const changed = render({ ...metadata, created_at });
      writeFileSync(report, changed);
      const validDate = run(hash(changed));
      assert.equal(validDate.status, 0, validDate.stderr);
      assert.equal(JSON.parse(validDate.stdout).status, "current");
    }
    for (const changedMetadata of [
      { ...metadata, token: "fixture-only-not-a-real-token" },
      { ...metadata, reviewer_run_ids: { reviewer_a: "run-a" } },
      { ...metadata, schema_version: "unknown-version" },
      ...["nonsense", "2026-02-30T00:00:00Z", "2026-09-11", "2026-09-11T00:00:00"].map(
        created_at => ({ ...metadata, created_at })),
    ]) {
      const changed = render(changedMetadata);
      writeFileSync(report, changed);
      rejected("invalid-metadata", hash(changed));
    }
    writeFileSync(report, original + "changed body\n");
    rejected("report-digest-mismatch");
    for (const field of ["head_sha", "merge_base_sha", "diff_sha256"]) {
      const changed = render({ ...metadata, [field]: "0".repeat(field === "diff_sha256" ? 64 : 40) });
      writeFileSync(report, changed);
      rejected(({ head_sha: "head-mismatch", merge_base_sha: "merge-base-mismatch",
        diff_sha256: "diff-digest-mismatch" } as Record<string, string>)[field], hash(changed));
    }
    writeFileSync(report, original);
    git("commit", "--allow-empty", "-m", "new head");
    rejected("head-mismatch");
    git("checkout", "--detach", head);
    git("branch", "-f", "main", head);
    rejected("merge-base-mismatch");
  } finally {
    rmSync(repo, { recursive: true, force: true });
  }
});

test("publishing evidence in a separate repository preserves target currentness", () => {
  const root = mkdtempSync(join(tmpdir(), "ar-publication-"));
  const target = join(root, "target");
  const evidence = join(root, "evidence");
  const cli = fileURLToPath(new URL("../../scripts/check-adversarial-report.mjs", import.meta.url));
  const git = (repo: string, ...args: string[]) => execFileSync("git", ["-C", repo, ...args]);
  const hash = (bytes: string | Buffer) => createHash("sha256").update(bytes).digest("hex");
  try {
    for (const repo of [target, evidence]) {
      mkdirSync(repo);
      git(repo, "init", "-b", "main");
      git(repo, "config", "user.name", "Publication Test");
      git(repo, "config", "user.email", "publication-test@example.invalid");
      git(repo, "commit", "--allow-empty", "-m", "base");
    }
    const base = git(target, "rev-parse", "HEAD").toString().trim();
    git(target, "checkout", "-b", "feature");
    writeFileSync(join(target, "code.txt"), "reviewed change\n");
    git(target, "add", "code.txt");
    git(target, "commit", "-m", "implementation");
    const head = git(target, "rev-parse", "HEAD").toString().trim();
    const reportPath = "reports/adversarial-review/feature/report.md";
    mkdirSync(join(evidence, "reports/adversarial-review/feature"), { recursive: true });
    const report = join(evidence, reportPath);
    const metadata = { schema_version: "adversarial-review-report.v1", merge_base_sha: base,
      head_sha: head, diff_sha256: hash(git(target, "diff", "--binary", "--no-ext-diff", "--no-textconv", `${base}..${head}`)),
      created_at: "2026-09-11T00:00:00Z", skill_version: head,
      reviewer_run_ids: { reviewer_a: "run-a", reviewer_b: "run-b" } };
    const bytes = `# Review\n\n\`\`\`yaml\n${JSON.stringify(metadata)}\n\`\`\`\n`;
    writeFileSync(report, bytes);
    const receipt = hash(bytes);
    git(evidence, "add", reportPath);
    git(evidence, "commit", "-m", "publish evidence");
    const evidenceCommit = git(evidence, "rev-parse", "HEAD").toString().trim();
    assert.equal(git(evidence, "show", `${evidenceCommit}:${reportPath}`).toString(), bytes);
    assert.equal(git(target, "rev-parse", "HEAD").toString().trim(), head);
    assert.equal(git(target, "status", "--porcelain").toString(), "");
    const run = () => spawnSync(process.execPath, [cli, "--repo", target,
      "--report", report, "--base", "main", "--report-sha256", receipt], { encoding: "utf8" });
    const current = run();
    assert.equal(current.status, 0, current.stderr);
    assert.equal(JSON.parse(current.stdout).status, "current");
    // A later receipt-repository commit must not move the reviewed target.
    writeFileSync(join(evidence, "receipt.txt"), receipt);
    git(evidence, "add", "receipt.txt");
    git(evidence, "commit", "-m", "save receipt");
    assert.equal(run().status, 0);
    writeFileSync(report, readFileSync(report, "utf8") + "tampered\n");
    assert.equal(JSON.parse(run().stdout).reason, "report-digest-mismatch");
    writeFileSync(report, bytes);
    // Committing evidence on the target itself is still stale: no exemption.
    writeFileSync(join(target, "report.md"), bytes);
    git(target, "add", "report.md");
    git(target, "commit", "-m", "incorrect evidence publication on target");
    const stale = run();
    assert.equal(stale.status, 1, stale.stderr);
    assert.equal(JSON.parse(stale.stdout).reason, "head-mismatch");
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
