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

import { mkdirSync, writeFileSync } from "node:fs";
import { dirname } from "node:path";
import {
  extractOwnFailureMessages,
  findRepoRoot,
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

function main(): void {
  const repoRoot = findRepoRoot();

  for (const feature of GOLDEN_FEATURES) {
    const { exitCode, combinedOutput } = runCheckTaskState(repoRoot, feature);
    const fixture: RecordedFixture = {
      feature,
      exitCode,
      fileNotFound: shellReportsFileNotFound(combinedOutput),
      ownFailureMessages: extractOwnFailureMessages(combinedOutput),
    };

    const outPath = fixturePathFor(feature);
    mkdirSync(dirname(outPath), { recursive: true });
    writeFileSync(outPath, `${JSON.stringify(fixture, null, 2)}\n`, "utf-8");
    process.stdout.write(`Recorded ${feature} -> ${outPath} (exit ${exitCode})\n`);
  }
}

main();
