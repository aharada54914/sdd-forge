/**
 * Records check-task-state.sh's shell output for each golden-tested feature
 * into tests/golden/fixtures/<feature>.expected.json, so tests/golden's
 * fixture-comparison test can run without a POSIX shell available (e.g. on
 * Windows CI). Run via `npm run golden:record`.
 *
 * This script is not part of src/ (it is a one-off recording tool invoked
 * from the command line, never imported by the server) and is the one place
 * outside of tests/ allowed to shell out and write files, mirroring how
 * tests/golden itself is allowed to invoke check-task-state.sh.
 */

import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { buildParityFixtureBase } from "../tests/golden/deep-verify-parity-helpers.js";
import {
  extractOwnFailureMessages,
  findRepoRoot,
  historicalGoldenRoot,
  fixturePathFor,
  runCheckTaskState,
  shellReportsFileNotFound,
  type RecordedFixture,
} from "../tests/golden/shell-runner.js";

const GOLDEN_FEATURES = [
  "bootstrap-interviewer-enhancement",
  "ci-mcp",
  "claude-workflow-compatibility",
  "cross-model-verification",
  "evidence-deep-verify",
  "risk-adaptive-layer",
  "sdd-forge-refactor",
  "sdd-lite",
] as const;

// The final pre-retirement revision used to reproduce all eight shell outputs.
// Recording requires the local Git objects for this revision and the bundles'
// evidence commits. Comparing the committed fixtures has no such dependency.
const HOST_REVISION = "d27ce86824ec293b83c4262ca28490086e22a449";
const SCRIPTS = "plugins/sdd-quality-loop/scripts";

function main(): void {
  const repoRoot = findRepoRoot();
  if (!existsSync(join(repoRoot, ".git"))) {
    throw new Error("Recording historical goldens requires a local checkout with Git history.");
  }
  const fixtureRoot = historicalGoldenRoot(repoRoot, { withHistory: true });
  try {
    const host = join(fixtureRoot.path, "historical-host");
    mkdirSync(host);
    const archive = join(host, "scripts.tar");
    execFileSync("git", ["archive", "--format=tar", "-o", archive, HOST_REVISION, SCRIPTS], { cwd: repoRoot });
    execFileSync("tar", ["-xf", archive, "-C", host]);
    const script = join(host, SCRIPTS, "check-task-state.sh");
    // Validate a known-good Done bundle before a host failure can be
    // mistaken for a legitimate negative result in the feature corpus.
    const control = buildParityFixtureBase("golden-record-control", "golden-parity", "T-900");
    try {
      const output = execFileSync("sh", [join(host, SCRIPTS, "check-evidence-bundle.sh"), control.bundleRel, control.dir],
        { cwd: control.dir, encoding: "utf8" });
      if (!output.includes("Evidence bundle passed for task T-900.")) {
        throw new Error(`Historical host failed its positive control: ${output}`);
      }
    } finally {
      control.tempRoot.cleanup();
    }
    const fixtures: RecordedFixture[] = [];
    for (const feature of GOLDEN_FEATURES) {
      const { exitCode, combinedOutput } = runCheckTaskState(fixtureRoot.path, feature, script);
      const fileNotFound = shellReportsFileNotFound(combinedOutput);
      const ownFailureMessages = extractOwnFailureMessages(combinedOutput);
      const recognized = exitCode === 0 ? combinedOutput.includes("Task state check passed for ")
        : exitCode === 1 && (fileNotFound || ownFailureMessages.length > 0);
      const incompleteHistory = /^ - (git_commit (?:does not exist in repository|is not an ancestor)|git is not available|git verification failed unexpectedly)/m;
      if (!recognized || incompleteHistory.test(combinedOutput)) {
        throw new Error(`Incomplete historical oracle for ${feature}: ${combinedOutput}`);
      }
      fixtures.push({ feature, exitCode, fileNotFound, ownFailureMessages });
    }
    for (const fixture of fixtures) {
      const outPath = fixturePathFor(fixture.feature);
      mkdirSync(dirname(outPath), { recursive: true });
      writeFileSync(outPath, `${JSON.stringify(fixture, null, 2)}\n`, "utf-8");
      process.stdout.write(`Recorded ${fixture.feature} -> ${outPath} (exit ${fixture.exitCode})\n`);
    }
  } finally {
    fixtureRoot.cleanup();
  }
}

main();
