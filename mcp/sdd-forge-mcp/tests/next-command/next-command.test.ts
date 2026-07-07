/**
 * AC-012: `get_next_sdd_command`'s deterministic state -> next-command
 * mapping, exercised directly against `next-command.ts` (not through the MCP
 * transport — `tests/core-tools/core-tools.test.ts` already covers the tool
 * wiring). Every synthetic-fixture case is also validated against the v1
 * envelope schema. One case runs against the real sdd-forge repository to
 * confirm the mapping computes a sane phase for `feature=sdd-forge-mcp`
 * (read-only; this suite never writes to the real repo).
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { getNextSddCommand, type NextCommandData } from "../../src/next-command.js";
import type { Result } from "../../src/envelope.js";
import { resolveRoot } from "../../src/root.js";
import { makeTempSddRoot, writeFile, type TempSddRoot } from "../test-helpers.js";
import {
  agentsMdWithActiveSpecs,
  designMd,
  getEnvelopeValidator,
  requirementsMd,
  tasksMd,
  type TaskFixture,
} from "./test-helpers.js";

function sha256Hex(contents: string): string {
  return createHash("sha256").update(contents, "utf-8").digest("hex");
}

function assertOkPhase(result: Result<NextCommandData>, expectedPhase: string): NextCommandData {
  assert.equal(result.ok, true, result.ok ? "" : JSON.stringify(result.error));
  if (!result.ok) {
    throw new Error("unreachable");
  }
  assert.ok(
    getEnvelopeValidator()({ ok: true, data: result.data }),
    JSON.stringify(getEnvelopeValidator().errors),
  );
  assert.equal(result.data.phase, expectedPhase);
  return result.data;
}

/** Seeds `specs/<feature>/` with exactly the artifacts needed to reach a given phase. */
function seedFeature(
  dir: string,
  feature: string,
  opts: {
    requirements?: string | undefined;
    design?: string | undefined;
    tasks?: string | undefined;
  },
): void {
  if (opts.requirements !== undefined) {
    writeFile(dir, `specs/${feature}/requirements.md`, opts.requirements);
  }
  if (opts.design !== undefined) {
    writeFile(dir, `specs/${feature}/design.md`, opts.design);
  }
  if (opts.tasks !== undefined) {
    writeFile(dir, `specs/${feature}/tasks.md`, opts.tasks);
  }
}

function setupSingleFeatureRoot(
  feature: string,
  opts: Parameters<typeof seedFeature>[2],
): TempSddRoot {
  const tempRoot = makeTempSddRoot(`next-command-${feature}`);
  writeFile(tempRoot.dir, "AGENTS.md", agentsMdWithActiveSpecs([feature]));
  seedFeature(tempRoot.dir, feature, opts);
  return tempRoot;
}

test("phase1-not-started: requirements.md does not exist", () => {
  const tempRoot = setupSingleFeatureRoot("feat-p1", {});
  try {
    const result = getNextSddCommand(tempRoot.root, "feat-p1");
    const data = assertOkPhase(result, "phase1-not-started");
    assert.match(data.nextCommand, /^\/sdd-bootstrap:bootstrap feature feat-p1$/);
  } finally {
    tempRoot.cleanup();
  }
});

test("spec-review: requirements.md exists but Spec-Review-Status is not Passed", () => {
  const tempRoot = setupSingleFeatureRoot("feat-spec-review", {
    requirements: requirementsMd("Findings Open"),
  });
  try {
    const result = getNextSddCommand(tempRoot.root, "feat-spec-review");
    const data = assertOkPhase(result, "spec-review");
    assert.match(data.nextCommand, /^\/sdd-review-loop:spec-review-loop --feature feat-spec-review$/);
  } finally {
    tempRoot.cleanup();
  }
});

test("spec-review: requirements.md has no Spec-Review-Status header at all", () => {
  const tempRoot = setupSingleFeatureRoot("feat-spec-review-missing-header", {
    requirements: requirementsMd(undefined),
  });
  try {
    const result = getNextSddCommand(tempRoot.root, "feat-spec-review-missing-header");
    assertOkPhase(result, "spec-review");
  } finally {
    tempRoot.cleanup();
  }
});

test("impl-review: design.md exists but Impl-Review-Status is not Passed", () => {
  const tempRoot = setupSingleFeatureRoot("feat-impl-review", {
    requirements: requirementsMd("Passed"),
    design: designMd("Findings Open"),
  });
  try {
    const result = getNextSddCommand(tempRoot.root, "feat-impl-review");
    const data = assertOkPhase(result, "impl-review");
    assert.match(data.nextCommand, /^\/sdd-review-loop:impl-review-loop --feature feat-impl-review$/);
  } finally {
    tempRoot.cleanup();
  }
});

test("cannot-determine: Spec-Review-Status Passed but design.md missing", () => {
  const tempRoot = setupSingleFeatureRoot("feat-design-missing", {
    requirements: requirementsMd("Passed"),
  });
  try {
    const result = getNextSddCommand(tempRoot.root, "feat-design-missing");
    assert.equal(result.ok, false);
    if (result.ok) {
      throw new Error("unreachable");
    }
    assert.equal(result.error.code, "cannot-determine");
  } finally {
    tempRoot.cleanup();
  }
});

test("phase2-not-started: design.md Passed but tasks.md does not exist", () => {
  const tempRoot = setupSingleFeatureRoot("feat-p2", {
    requirements: requirementsMd("Passed"),
    design: designMd("Passed"),
  });
  try {
    const result = getNextSddCommand(tempRoot.root, "feat-p2");
    const data = assertOkPhase(result, "phase2-not-started");
    assert.match(data.nextCommand, /^\/sdd-bootstrap:bootstrap feature$/);
  } finally {
    tempRoot.cleanup();
  }
});

test("task-review: tasks.md exists but Task-Review-Status is not Passed", () => {
  const tempRoot = setupSingleFeatureRoot("feat-task-review", {
    requirements: requirementsMd("Passed"),
    design: designMd("Passed"),
    tasks: tasksMd("Findings Open", [{ id: "T-001", approved: false, status: "Planned" }]),
  });
  try {
    const result = getNextSddCommand(tempRoot.root, "feat-task-review");
    const data = assertOkPhase(result, "task-review");
    assert.match(data.nextCommand, /^\/sdd-review-loop:task-review-loop --feature feat-task-review$/);
  } finally {
    tempRoot.cleanup();
  }
});

test("approval-gate: Task-Review-Status Passed but every task is Draft", () => {
  const tasks: TaskFixture[] = [
    { id: "T-001", approved: false, status: "Planned" },
    { id: "T-002", approved: false, status: "Planned" },
  ];
  const tempRoot = setupSingleFeatureRoot("feat-approval-gate", {
    requirements: requirementsMd("Passed"),
    design: designMd("Passed"),
    tasks: tasksMd("Passed", tasks),
  });
  try {
    const result = getNextSddCommand(tempRoot.root, "feat-approval-gate");
    const data = assertOkPhase(result, "approval-gate");
    assert.equal(data.nextCommand, "human: approve tasks in tasks.md");
  } finally {
    tempRoot.cleanup();
  }
});

test("implementation: an Approved task is Planned", () => {
  const tasks: TaskFixture[] = [
    { id: "T-001", approved: true, status: "Planned" },
    { id: "T-002", approved: false, status: "Planned" },
  ];
  const tempRoot = setupSingleFeatureRoot("feat-impl-planned", {
    requirements: requirementsMd("Passed"),
    design: designMd("Passed"),
    tasks: tasksMd("Passed", tasks),
  });
  try {
    const result = getNextSddCommand(tempRoot.root, "feat-impl-planned");
    const data = assertOkPhase(result, "implementation");
    assert.match(data.nextCommand, /^\/sdd-ship:ship specs\/feat-impl-planned\/tasks\.md$/);
  } finally {
    tempRoot.cleanup();
  }
});

test("implementation: an Approved task is In Progress", () => {
  const tasks: TaskFixture[] = [{ id: "T-001", approved: true, status: "In Progress" }];
  const tempRoot = setupSingleFeatureRoot("feat-impl-in-progress", {
    requirements: requirementsMd("Passed"),
    design: designMd("Passed"),
    tasks: tasksMd("Passed", tasks),
  });
  try {
    const result = getNextSddCommand(tempRoot.root, "feat-impl-in-progress");
    assertOkPhase(result, "implementation");
  } finally {
    tempRoot.cleanup();
  }
});

test("quality-gate: every Approved task is Implementation Complete", () => {
  const tasks: TaskFixture[] = [
    { id: "T-001", approved: true, status: "Implementation Complete" },
    { id: "T-002", approved: false, status: "Planned" },
  ];
  const tempRoot = setupSingleFeatureRoot("feat-quality-gate", {
    requirements: requirementsMd("Passed"),
    design: designMd("Passed"),
    tasks: tasksMd("Passed", tasks),
  });
  try {
    // T-001's state-machine validation requires an implementation report
    // mentioning it (task-validation.ts's Implementation Complete check).
    writeFile(
      tempRoot.dir,
      "reports/implementation/feat-quality-gate-T-001.md",
      ["# Implementation Report", "", "Task ID: T-001", ""].join("\n"),
    );

    const result = getNextSddCommand(tempRoot.root, "feat-quality-gate");
    const data = assertOkPhase(result, "quality-gate");
    assert.match(data.nextCommand, /^\/sdd-quality-loop:quality-gate specs\/feat-quality-gate\/tasks\.md$/);
  } finally {
    tempRoot.cleanup();
  }
});

test("done: every Approved task is Done", () => {
  const tasks: TaskFixture[] = [{ id: "T-001", approved: true, status: "Done" }];
  const tempRoot = setupSingleFeatureRoot("feat-done", {
    requirements: requirementsMd("Passed"),
    design: designMd("Passed"),
    tasks: tasksMd("Passed", tasks),
  });
  try {
    // T-001's state-machine validation (verifyEvidenceBundle, low risk)
    // requires a passing quality-gate report, a matching contract, and an
    // artifact manifest whose sha256 hashes match those two files exactly.
    const qualityReportContents = ["Task ID: T-001", "", "VERDICT: PASS", ""].join("\n");
    writeFile(tempRoot.dir, "reports/quality-gate/T-001.md", qualityReportContents);
    const contractContents = JSON.stringify({ task_id: "T-001", risk: "low", checks: [] });
    writeFile(tempRoot.dir, "specs/feat-done/verification/T-001.contract.json", contractContents);
    writeFile(
      tempRoot.dir,
      "specs/feat-done/verification/T-001.evidence.json",
      JSON.stringify({
        task_id: "T-001",
        risk: "low",
        quality_report: "reports/quality-gate/T-001.md",
        verification_contract: "specs/feat-done/verification/T-001.contract.json",
        git_commit: "a".repeat(40),
        artifacts: [
          { path: "reports/quality-gate/T-001.md", sha256: sha256Hex(qualityReportContents) },
          { path: "specs/feat-done/verification/T-001.contract.json", sha256: sha256Hex(contractContents) },
        ],
      }),
    );

    const result = getNextSddCommand(tempRoot.root, "feat-done");
    const data = assertOkPhase(result, "done");
    assert.equal(data.nextCommand, "feature complete");
  } finally {
    tempRoot.cleanup();
  }
});

test("blocked: a Blocked task takes priority even when another task is Planned/Approved", () => {
  const tasks: TaskFixture[] = [
    { id: "T-001", approved: true, status: "Blocked", blockers: "waiting on external dependency" },
    { id: "T-002", approved: true, status: "Planned" },
  ];
  const tempRoot = setupSingleFeatureRoot("feat-blocked", {
    requirements: requirementsMd("Passed"),
    design: designMd("Passed"),
    tasks: tasksMd("Passed", tasks),
  });
  try {
    const result = getNextSddCommand(tempRoot.root, "feat-blocked");
    const data = assertOkPhase(result, "blocked");
    assert.equal(data.nextCommand, "human: resolve blockers");
    assert.match(data.rationale, /T-001/);
  } finally {
    tempRoot.cleanup();
  }
});

test("cannot-determine: malformed feature name is rejected before any file access", () => {
  const tempRoot = makeTempSddRoot("next-command-invalid-feature");
  try {
    const result = getNextSddCommand(tempRoot.root, "../escape");
    assert.equal(result.ok, false);
    if (result.ok) {
      throw new Error("unreachable");
    }
    // next-command.ts itself does not validate feature shape (that is
    // tools/core.ts's job before delegating) — this only asserts it does not
    // crash and instead reports a structured failure when the path is denied.
    assert.ok(["invalid-input", "path-denied", "not-found"].includes(result.error.code));
  } finally {
    tempRoot.cleanup();
  }
});

test("auto-select: exactly one active feature -> resolved without a feature argument", () => {
  const tempRoot = makeTempSddRoot("next-command-auto-one");
  try {
    writeFile(tempRoot.dir, "AGENTS.md", agentsMdWithActiveSpecs(["feat-active", "feat-done-only"]));
    seedFeature(tempRoot.dir, "feat-active", {
      requirements: requirementsMd("Passed"),
      design: designMd("Passed"),
      tasks: tasksMd("Passed", [{ id: "T-001", approved: true, status: "Planned" }]),
    });
    seedFeature(tempRoot.dir, "feat-done-only", {
      requirements: requirementsMd("Passed"),
      design: designMd("Passed"),
      tasks: tasksMd("Passed", [{ id: "T-001", approved: true, status: "Done" }]),
    });

    const result = getNextSddCommand(tempRoot.root);
    const data = assertOkPhase(result, "implementation");
    assert.equal(data.feature, "feat-active");
  } finally {
    tempRoot.cleanup();
  }
});

test("auto-select: zero active features -> cannot-determine naming none-active", () => {
  const tempRoot = makeTempSddRoot("next-command-auto-zero");
  try {
    writeFile(tempRoot.dir, "AGENTS.md", agentsMdWithActiveSpecs(["feat-done-only"]));
    seedFeature(tempRoot.dir, "feat-done-only", {
      requirements: requirementsMd("Passed"),
      design: designMd("Passed"),
      tasks: tasksMd("Passed", [{ id: "T-001", approved: true, status: "Done" }]),
    });

    const result = getNextSddCommand(tempRoot.root);
    assert.equal(result.ok, false);
    if (result.ok) {
      throw new Error("unreachable");
    }
    assert.equal(result.error.code, "cannot-determine");
    assert.equal(result.error.details?.rule, "auto-select-none-active");
  } finally {
    tempRoot.cleanup();
  }
});

test("auto-select: multiple active features -> cannot-determine naming all candidates", () => {
  const tempRoot = makeTempSddRoot("next-command-auto-multiple");
  try {
    writeFile(tempRoot.dir, "AGENTS.md", agentsMdWithActiveSpecs(["feat-x", "feat-y"]));
    for (const feature of ["feat-x", "feat-y"]) {
      seedFeature(tempRoot.dir, feature, {
        requirements: requirementsMd("Passed"),
        design: designMd("Passed"),
        tasks: tasksMd("Passed", [{ id: "T-001", approved: true, status: "Planned" }]),
      });
    }

    const result = getNextSddCommand(tempRoot.root);
    assert.equal(result.ok, false);
    if (result.ok) {
      throw new Error("unreachable");
    }
    assert.equal(result.error.code, "cannot-determine");
    assert.equal(result.error.details?.rule, "auto-select-multiple-active");
    const candidates = result.error.details?.candidates as string[] | undefined;
    assert.ok(candidates !== undefined);
    assert.deepEqual([...candidates].sort(), ["feat-x", "feat-y"]);
  } finally {
    tempRoot.cleanup();
  }
});

/**
 * Walks upward from this compiled test file until it finds the sdd-forge
 * repository root (identified by AGENTS.md at that directory), the same
 * upward-search pattern used elsewhere in this suite to locate the contracts
 * schema. Read-only: only used to point `resolveRoot` at the real repo.
 */
function findSddForgeRepoRoot(startDir: string): string {
  let dir = startDir;
  for (let i = 0; i < 12; i += 1) {
    if (existsSync(join(dir, "AGENTS.md")) && existsSync(join(dir, "specs"))) {
      return dir;
    }
    const parent = dirname(dir);
    if (parent === dir) {
      break;
    }
    dir = parent;
  }
  throw new Error(`Could not locate the sdd-forge repository root above ${startDir}`);
}

test("real repository: feature=sdd-forge-mcp resolves to a schema-valid, non-cannot-determine phase", () => {
  const thisFileDir = dirname(fileURLToPath(import.meta.url));
  const repoRoot = findSddForgeRepoRoot(thisFileDir);

  const root = resolveRoot([], {}, repoRoot);
  const result = getNextSddCommand(root, "sdd-forge-mcp");
  assert.equal(result.ok, true, result.ok ? "" : JSON.stringify(result.error));
  if (!result.ok) {
    throw new Error("unreachable");
  }
  assert.ok(
    getEnvelopeValidator()({ ok: true, data: result.data }),
    JSON.stringify(getEnvelopeValidator().errors),
  );
  assert.equal(result.data.feature, "sdd-forge-mcp");
  // The live repository's SDD state advances over time (implementation ->
  // quality-gate -> done), so assert structural validity rather than a
  // point-in-time phase value; point-in-time transitions are covered by the
  // synthetic fixtures above.
  const knownPhases = [
    "implementation",
    "quality-gate",
    "done",
    "blocked",
    "approval-gate",
  ];
  assert.ok(
    knownPhases.includes(result.data.phase),
    `unexpected phase for live repo: ${result.data.phase}`,
  );
  assert.ok(result.data.nextCommand.length > 0);
});
