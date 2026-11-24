/**
 * SDD Forge MCP v2 tools — Single Source of Truth (ADR-0052).
 *
 * Thin read-only transport adapters backed directly by the pure read-only
 * `plugins/sdd-quality-loop/scripts/v2/v2-readonly-core.mjs` engine with a
 * `path-guard.ts`-enforced IO facade (`createGuardedIo(root)`).
 *
 * Security invariants:
 *   - Zero direct `node:fs` calls; every read/stat/list flows through `path-guard.ts`.
 *   - Never calls `findProjectRoot()` or reads `CLAUDE_PROJECT_DIR`/`SDD_PROJECT_ROOT`.
 *   - Never leaks absolute host paths (`root.path`) in returned error envelopes.
 *   - Fail-closed gate auditing on corrupt/missing baselines, FAIL verdicts, or
 *     unresolved `Risk: high` provisional Open Questions.
 */

import { err, ok, type Result } from "../envelope.js";
import { parseActiveSpecDirectories } from "../parsers/agents-md.js";
import { isExecutionCoverageComplete } from "../parsers/report-lookup.js";
import { parseReviewReportVerdict } from "../parsers/review-verdict.js";
import {
  createGuardedIo,
  guardedDirExists,
  guardedExists,
  guardedRead,
  listGuardedDirectEntries,
} from "../path-guard.js";
import { isSddRoot, type SddRoot } from "../root.js";
import {
  analyzeTraceabilityCore,
  buildDecisionViewDataCore,
  checkSpecDriftCore,
  diffEvidenceInputs,
  isApprovedValue,
  renderDecisionViewMarkdown,
  runDoctorCore,
  taskEvidenceInputs,
} from "../../../../plugins/sdd-quality-loop/scripts/v2/v2-readonly-core.mjs";

const FEATURE_RE = /^[A-Za-z0-9._-]+$/;
const TASK_ID_RE = /^T-[A-Za-z0-9._-]+$/;

export type RiskTier = "low" | "standard" | "high";
export type DriftStatus =
  | "CLEAN"
  | "AMENDED"
  | "UNDECLARED_DRIFT"
  | "UNVERIFIABLE"
  | "UNBASELINED"
  | "BASELINE_ERROR";
export type ExecutionDriftStatus = DriftStatus | "SKIPPED";
export type DoctorStatus = "CLEAN" | "WARN" | "NG";

interface V2TaskSummary {
  id: string;
  title: string;
  risk: string;
  approval: string;
  status: string;
}

interface V2OpenQuestion {
  id: string;
  confirmed: boolean;
  impactedTasks: string[];
}

function toRiskTier(value: string): RiskTier {
  if (value === "high" || value === "critical") return "high";
  if (value === "low") return "low";
  return "standard";
}

function toDriftStatus(value: string): DriftStatus {
  if (
    value === "CLEAN" ||
    value === "AMENDED" ||
    value === "UNDECLARED_DRIFT" ||
    value === "UNVERIFIABLE" ||
    value === "BASELINE_ERROR"
  ) {
    return value;
  }
  return "UNBASELINED";
}

function toExecutionDriftStatus(value: unknown): ExecutionDriftStatus | undefined {
  if (
    value === "CLEAN" ||
    value === "AMENDED" ||
    value === "UNDECLARED_DRIFT" ||
    value === "UNVERIFIABLE" ||
    value === "UNBASELINED" ||
    value === "SKIPPED" ||
    value === "BASELINE_ERROR"
  ) {
    return value;
  }
  return undefined;
}

function toDoctorStatus(value: string): DoctorStatus {
  return value === "NG" || value === "WARN" ? value : "CLEAN";
}

export type NextPhase =
  | "bootstrap"
  | "spec-check"
  | "approval-gate"
  | "implementation"
  | "sdd-gate"
  | "blocked"
  | "done";

export interface NextAction {
  phase: NextPhase;
  command: string;
  rationale: string;
}

export interface ProjectOverviewFeature {
  feature: string;
  highestRisk: RiskTier;
  taskCounts: {
    total: number;
    approved: number;
    inProgress: number;
    implComplete: number;
    done: number;
    blocked: number;
  };
  driftStatus: DriftStatus;
  nextAction: NextAction;
}

export interface ProjectOverviewData {
  kind: "project-overview";
  activeFeatures: ProjectOverviewFeature[];
  doctor?: {
    status: "CLEAN" | "WARN" | "NG";
    ngCount: number;
    warnCount: number;
    driftEventCount: number;
  };
}

export interface FeatureStateData {
  kind: "feature-state";
  feature: string;
  highestRisk: RiskTier;
  files: {
    requirements: boolean;
    design: boolean;
    tasks: boolean;
    baseline: boolean;
  };
  traceability: {
    complete: boolean;
    requirementCount: number;
    acCount: number;
    taskCount: number;
    gapCount: number;
  };
  drift: {
    status: DriftStatus;
    changedFiles: string[];
    amendmentCount: number;
  };
  openQuestions: {
    total: number;
    provisionalCount: number;
    provisionalIds: string[];
  };
  nextAction: NextAction;
  decisionViewMarkdown?: string;
}

export interface GateAuditTaskEntry {
  taskId: string;
  risk: RiskTier;
  approval: string;
  status: string;
  executionArtifact: {
    exists: boolean;
    path?: string;
    verdict?: "PASS" | "FAIL";
    executedAt?: string;
    specDriftStatus?: ExecutionDriftStatus;
    failedCommands?: string[];
    coverageComplete?: boolean;
    specInputsCurrent?: boolean;
    specInputsChanged?: string[];
  };
  reviewReport: {
    exists: boolean;
    path?: string;
    verdict?: "PASS" | "FAIL" | "UNKNOWN";
  };
  readyForDone: boolean;
}

export interface GateAuditData {
  kind: "gate-audit";
  feature: string;
  tasks: GateAuditTaskEntry[];
}

function sanitizeErrorMessage(root: SddRoot, error: unknown): string {
  const raw = error instanceof Error ? error.message : String(error);
  return raw.split(root.path).join("<root>").slice(0, 400);
}

function validateFeatureName(feature: string): Result<string> {
  if (typeof feature !== "string" || !FEATURE_RE.test(feature) || feature === "." || feature === "..") {
    return err("invalid-input", "Feature must match ^[A-Za-z0-9._-]+$ without path separators or dot segments.");
  }
  return ok(feature);
}

function validateTaskId(taskId: string): Result<string> {
  if (typeof taskId !== "string" || !TASK_ID_RE.test(taskId)) {
    return err("invalid-input", "taskId must match ^T-[A-Za-z0-9._-]+$.");
  }
  return ok(taskId);
}


type GuardedIo = ReturnType<typeof createGuardedIo>;

/**
 * Spec inputs that changed since a task's gate run (#831). `undefined` when
 * the run recorded none (before #831) or there is no matching run.
 */
function changedEvidenceInputs(
  io: GuardedIo,
  feature: string,
  taskId: string,
  parsed: Record<string, unknown>,
): string[] | undefined {
  const changed = diffEvidenceInputs(parsed.specInputs, taskEvidenceInputs(io, { feature, taskId })) as string[] | null;
  return changed ?? undefined;
}

/**
 * Done tasks whose gate evidence no longer matches the spec (#832): their
 * recorded inputs changed, or (evidence from before #831, or none) the spec
 * was amended since the baseline, which they cannot be shown to cover.
 */
function staleDoneTasks(io: GuardedIo, root: SddRoot, feature: string, tasks: readonly V2TaskSummary[], driftStatus: DriftStatus): string[] {
  const stale: string[] = [];
  for (const task of tasks) {
    if (task.status !== "Done") continue;
    const read = guardedRead(root, `reports/quality-gate/${feature}-${task.id}.execution.json`);
    let changed: string[] | undefined;
    if (read.ok) {
      try {
        const parsed = JSON.parse(read.data.contents) as Record<string, unknown>;
        if (parsed.feature === feature && typeof parsed.taskId === "string" && parsed.taskId.toUpperCase() === task.id.toUpperCase()) {
          changed = changedEvidenceInputs(io, feature, task.id, parsed);
        }
      } catch {
        changed = undefined;
      }
    }
    if (changed ? changed.length > 0 : driftStatus === "AMENDED") stale.push(task.id);
  }
  return stale;
}

function computeNextAction(
  feature: string,
  tasks: readonly V2TaskSummary[],
  specCheckVerdict: string,
  highestRisk: RiskTier,
  hasSpecs: boolean,
  driftStatus: DriftStatus,
  staleDone: readonly string[] = [],
): NextAction {
  if (!hasSpecs || tasks.length === 0) {
    return {
      phase: "bootstrap",
      command: `/sdd-bootstrap:bootstrap feature --feature ${feature}`,
      rationale: `specs/${feature} is missing core SDD specification files or tasks.`,
    };
  }
  if (driftStatus === "UNVERIFIABLE") {
    return {
      phase: "blocked",
      command: `human: check specs/${feature} with check-spec-drift.mjs`,
      rationale: `A spec file in specs/${feature} exists but is over this server's read limit, so drift was not checked (the file is not treated as deleted). Run the local check-spec-drift.mjs CLI, or split the file.`,
    };
  }
  if (driftStatus === "UNDECLARED_DRIFT" || driftStatus === "BASELINE_ERROR") {
    return {
      phase: "blocked",
      command: `human: resolve ${driftStatus} in specs/${feature}`,
      rationale: `specs/${feature} has ${driftStatus}; revert undeclared edits, record a rationale under '## Spec Amendments', or repair .spec-baseline.json.`,
    };
  }
  const blocked = tasks.filter((t) => t.status === "Blocked");
  if (blocked.length > 0) {
    return {
      phase: "blocked",
      command: "human: resolve blockers",
      rationale: `Task(s) ${blocked.map((t) => t.id).join(", ")} are Blocked in specs/${feature}/tasks.md.`,
    };
  }
  const approved = tasks.filter((t) => isApprovedValue(t.approval));
  if (approved.length === 0) {
    if (highestRisk !== "low" && specCheckVerdict === "Not Run") {
      return {
        phase: "spec-check",
        command: `/sdd-bootstrap:bootstrap feature --feature ${feature}`,
        rationale: `Risk: ${highestRisk} feature has no recorded spec-check report yet.`,
      };
    }
    return {
      phase: "approval-gate",
      command: `human: set Approval: Approved in specs/${feature}/tasks.md`,
      rationale: `No task in specs/${feature}/tasks.md is Approved yet.`,
    };
  }
  if (approved.some((t) => t.status === "Planned" || t.status === "In Progress")) {
    return {
      phase: "implementation",
      command: `/sdd-ship:ship specs/${feature}/tasks.md`,
      rationale: `Approved task(s) are Planned or In Progress.`,
    };
  }
  if (approved.some((t) => t.status === "Implementation Complete")) {
    return {
      phase: "sdd-gate",
      command: `/sdd-ship:ship specs/${feature}/tasks.md`,
      rationale: `Approved task(s) are Implementation Complete and awaiting sdd-gate verification.`,
    };
  }
  if (staleDone.length > 0) {
    return {
      phase: "sdd-gate",
      command: `/sdd-ship:ship specs/${feature}/tasks.md#${staleDone[0]}`,
      rationale: `The spec changed after Done task(s) ${staleDone.join(", ")} passed the gate; re-run the gate for each (a failure is reported to a human, who decides whether to reopen the task).`,
    };
  }
  // Only report `done` when ALL tasks in tasks.md are Approved and Done (M-2).
  if (approved.length === tasks.length && approved.every((t) => t.status === "Done")) {
    return {
      phase: "done",
      command: "feature complete",
      rationale: `All tasks in specs/${feature}/tasks.md are Approved and Done.`,
    };
  }
  if (approved.length < tasks.length && approved.every((t) => t.status === "Done")) {
    const unapprovedIds = tasks.filter((t) => !isApprovedValue(t.approval)).map((t) => t.id);
    return {
      phase: "approval-gate",
      command: `human: set Approval: Approved in specs/${feature}/tasks.md`,
      rationale: `Remaining task(s) ${unapprovedIds.join(", ")} are still unapproved.`,
    };
  }
  return {
    phase: "implementation",
    command: `/sdd-ship:ship specs/${feature}/tasks.md`,
    rationale: `Continue SDD Core workflow for specs/${feature}/tasks.md.`,
  };
}

function readDriftSummary(root: SddRoot, feature: string): {
  status: DriftStatus;
  changedFiles: string[];
  amendmentCount: number;
} {
  const baselineRel = `specs/${feature}/.spec-baseline.json`;
  if (!guardedExists(root, baselineRel)) {
    return { status: "UNBASELINED", changedFiles: [], amendmentCount: 0 };
  }
  try {
    const io = createGuardedIo(root);
    const report = checkSpecDriftCore(io, { feature });
    return {
      status: toDriftStatus(report.status),
      changedFiles: report.changedFiles,
      amendmentCount: report.amendments.length,
    };
  } catch {
    // Fail-closed on corrupt/unreadable/unsafe baseline (H-2).
    return { status: "BASELINE_ERROR", changedFiles: [], amendmentCount: 0 };
  }
}

function discoverActiveFeatures(root: SddRoot): string[] {
  const seen = new Set<string>();
  const addIfValid = (name: string): void => {
    if (!validateFeatureName(name).ok) return;
    if (!guardedDirExists(root, `specs/${name}`)) return;
    seen.add(name);
  };

  const fromAgents = parseActiveSpecDirectories(root);
  if (fromAgents.ok && fromAgents.data.length > 0) {
    for (const entry of fromAgents.data) {
      addIfValid(entry.feature);
    }
    return [...seen];
  }

  for (const entry of listGuardedDirectEntries(root, "specs")) {
    if (entry.isDirectory) {
      addIfValid(entry.name);
    }
  }
  return [...seen].sort();
}

function countDriftEvents(root: SddRoot): number {
  const read = guardedRead(root, ".sdd/drift-events.jsonl");
  if (!read.ok) return 0;
  return read.data.contents
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line.length > 0).length;
}

export function sddProjectOverview(
  root: SddRoot,
  options: { includeDoctor?: boolean } = {},
): Result<ProjectOverviewData> {
  if (!isSddRoot(root)) {
    return err("not-sdd-root", "Resolved root does not contain AGENTS.md or specs/.");
  }
  const io = createGuardedIo(root);
  const features = discoverActiveFeatures(root);
  const activeFeatures: ProjectOverviewFeature[] = [];

  for (const feature of features) {
    try {
      const dv = buildDecisionViewDataCore(io, { feature });
      const drift = readDriftSummary(root, feature);
      const hasSpecs =
        guardedExists(root, `specs/${feature}/requirements.md`) &&
        guardedExists(root, `specs/${feature}/tasks.md`);
      const tasks = dv.tasks as V2TaskSummary[];
      const highestRisk = toRiskTier(dv.highestRisk);
      activeFeatures.push({
        feature,
        highestRisk,
        taskCounts: {
          total: tasks.length,
          approved: tasks.filter((t) => isApprovedValue(t.approval)).length,
          inProgress: tasks.filter((t) => t.status === "In Progress").length,
          implComplete: tasks.filter((t) => t.status === "Implementation Complete").length,
          done: tasks.filter((t) => t.status === "Done").length,
          blocked: tasks.filter((t) => t.status === "Blocked").length,
        },
        driftStatus: drift.status,
        nextAction: computeNextAction(
          feature,
          tasks,
          dv.specCheckVerdict,
          highestRisk,
          hasSpecs,
          drift.status,
          staleDoneTasks(io, root, feature, tasks, drift.status),
        ),
      });
    } catch {
      // Skip unreadable/corrupt directory entries rather than aborting overview
    }
  }

  const data: ProjectOverviewData = {
    kind: "project-overview",
    activeFeatures,
  };

  if (options.includeDoctor !== false) {
    const doc = runDoctorCore(io, {
      nodeVersion: process.versions.node,
      rootLabel: null,
      scanExtendedRepo: false,
    });
    data.doctor = {
      status: toDoctorStatus(doc.status),
      ngCount: doc.summary.ng,
      warnCount: doc.summary.warn,
      driftEventCount: countDriftEvents(root),
    };
  }

  return ok(data);
}

export function sddFeatureState(
  root: SddRoot,
  rawFeature: string,
  options: { includeDecisionViewMarkdown?: boolean } = {},
): Result<FeatureStateData> {
  if (!isSddRoot(root)) {
    return err("not-sdd-root", "Resolved root does not contain AGENTS.md or specs/.");
  }
  const checked = validateFeatureName(rawFeature);
  if (!checked.ok) return checked;
  const feature = checked.data;

  if (!guardedDirExists(root, `specs/${feature}`)) {
    return err("not-found", `Feature directory specs/${feature} does not exist.`);
  }

  try {
    const io = createGuardedIo(root);
    const files = {
      requirements: guardedExists(root, `specs/${feature}/requirements.md`),
      design: guardedExists(root, `specs/${feature}/design.md`),
      tasks: guardedExists(root, `specs/${feature}/tasks.md`),
      baseline: guardedExists(root, `specs/${feature}/.spec-baseline.json`),
    };

    const dv = buildDecisionViewDataCore(io, { feature });
    const drift = readDriftSummary(root, feature);

    let traceability = {
      complete: false,
      requirementCount: dv.counts.requirements,
      acCount: dv.counts.acceptanceCriteria,
      taskCount: dv.counts.tasksTotal,
      gapCount: 0,
    };
    if (files.requirements && files.tasks) {
      const trace = analyzeTraceabilityCore(io, { feature, checkCodeAndTests: false });
      const gapCount =
        trace.gaps.orphanReqs.length +
        trace.gaps.unassignedAcs.length +
        trace.gaps.unlinkedAcs.length +
        trace.gaps.brokenReqRefs.length +
        trace.gaps.brokenAcRefs.length;
      traceability = {
        complete: trace.complete,
        requirementCount: trace.requirements.length,
        acCount: trace.acceptanceCriteria.length,
        taskCount: trace.tasks.length,
        gapCount,
      };
    }

    const oqs = dv.openQuestions as V2OpenQuestion[];
    const provisionalIds = oqs.filter((q) => !q.confirmed).map((q) => q.id);
    const highestRisk = toRiskTier(dv.highestRisk);
    const data: FeatureStateData = {
      kind: "feature-state",
      feature,
      highestRisk,
      files,
      traceability,
      drift,
      openQuestions: {
        total: oqs.length,
        provisionalCount: provisionalIds.length,
        provisionalIds,
      },
      nextAction: computeNextAction(
        feature,
        dv.tasks as V2TaskSummary[],
        dv.specCheckVerdict,
        highestRisk,
        files.requirements && files.tasks,
        drift.status,
        staleDoneTasks(io, root, feature, dv.tasks as V2TaskSummary[], drift.status),
      ),
    };

    if (options.includeDecisionViewMarkdown) {
      data.decisionViewMarkdown = renderDecisionViewMarkdown(dv);
    }

    return ok(data);
  } catch (error) {
    return err("cannot-parse", `Failed to inspect feature '${feature}': ${sanitizeErrorMessage(root, error)}`);
  }
}

export function sddGateAudit(
  root: SddRoot,
  rawFeature: string,
  rawTaskId?: string,
): Result<GateAuditData> {
  if (!isSddRoot(root)) {
    return err("not-sdd-root", "Resolved root does not contain AGENTS.md or specs/.");
  }
  const checkedFeature = validateFeatureName(rawFeature);
  if (!checkedFeature.ok) return checkedFeature;
  const feature = checkedFeature.data;

  let filterTaskId: string | undefined;
  if (rawTaskId !== undefined) {
    const checkedTask = validateTaskId(rawTaskId);
    if (!checkedTask.ok) return checkedTask;
    filterTaskId = checkedTask.data.toUpperCase();
  }

  if (!guardedDirExists(root, `specs/${feature}`)) {
    return err("not-found", `Feature directory specs/${feature} does not exist.`);
  }

  try {
    const io = createGuardedIo(root);
    const dv = buildDecisionViewDataCore(io, { feature });
    const drift = readDriftSummary(root, feature);
    const allTasks = dv.tasks as V2TaskSummary[];
    const selectedTasks = filterTaskId
      ? allTasks.filter((t) => t.id.toUpperCase() === filterTaskId)
      : allTasks;

    if (filterTaskId && selectedTasks.length === 0) {
      return err("not-found", `Task '${filterTaskId}' not found in specs/${feature}/tasks.md.`);
    }

    const allOqs = dv.openQuestions as V2OpenQuestion[];

    const tasks: GateAuditTaskEntry[] = selectedTasks.map((task) => {
      const execRel = `reports/quality-gate/${feature}-${task.id}.execution.json`;
      const mdRel = `reports/quality-gate/${feature}-${task.id}.md`;

      const executionArtifact: GateAuditTaskEntry["executionArtifact"] = { exists: false };
      const execRead = guardedRead(root, execRel);
      if (execRead.ok) {
        executionArtifact.exists = true;
        executionArtifact.path = execRel;
        try {
          const parsed = JSON.parse(execRead.data.contents) as Record<string, unknown>;
          const matchesIdentity =
            parsed.schema === "sdd-gate-execution/v1" &&
            parsed.feature === feature &&
            typeof parsed.taskId === "string" &&
            parsed.taskId.toUpperCase() === task.id.toUpperCase();

          if (matchesIdentity) {
            if (parsed.verdict === "PASS" || parsed.verdict === "FAIL") {
              executionArtifact.verdict = parsed.verdict;
            }
            if (typeof parsed.executedAt === "string") {
              executionArtifact.executedAt = parsed.executedAt;
            }
            const checks = parsed.checks as Record<string, unknown> | undefined;
            const sd = checks?.specDrift as Record<string, unknown> | undefined;
            const sdStatus = toExecutionDriftStatus(sd?.status);
            if (sdStatus) {
              executionArtifact.specDriftStatus = sdStatus;
            }
            executionArtifact.coverageComplete = isExecutionCoverageComplete(parsed);
            const changed = changedEvidenceInputs(io, feature, task.id, parsed);
            if (changed) {
              executionArtifact.specInputsCurrent = changed.length === 0;
              if (changed.length > 0) executionArtifact.specInputsChanged = changed;
            }
            if (Array.isArray(checks?.commands)) {
              const failed = checks.commands
                .filter((c): c is Record<string, unknown> => Boolean(c) && typeof c === "object" && (c as Record<string, unknown>).passed === false)
                .map((c) => String(c.label || c.command || "command"));
              executionArtifact.failedCommands = failed;
            }
          } else {
            executionArtifact.verdict = "FAIL";
          }
        } catch {
          executionArtifact.verdict = "FAIL";
        }
      }

      const reviewReport: GateAuditTaskEntry["reviewReport"] = { exists: false };
      const mdRead = guardedRead(root, mdRel);
      if (mdRead.ok) {
        reviewReport.exists = true;
        reviewReport.path = mdRel;
        reviewReport.verdict = parseReviewReportVerdict(mdRead.data.contents);
      }

      const riskTier = toRiskTier(task.risk);
      const blockingProvisionalOqs =
        riskTier === "high"
          ? allOqs.filter(
              (q) =>
                !q.confirmed &&
                (q.impactedTasks.length === 0 || q.impactedTasks.includes(task.id.toUpperCase())),
            )
          : [];

      const validStatus = task.status === "Implementation Complete" || task.status === "Done";
      const validDrift = drift.status === "CLEAN" || drift.status === "AMENDED";
      // Evidence must cover the current spec: recorded inputs unchanged, or,
      // for runs from before #831, no amendment since the baseline.
      const evidenceCurrent =
        executionArtifact.specInputsCurrent === true ||
        (executionArtifact.specInputsCurrent === undefined && drift.status === "CLEAN");

      const readyForDone =
        isApprovedValue(task.approval) &&
        validStatus &&
        executionArtifact.verdict === "PASS" &&
        executionArtifact.coverageComplete === true &&
        reviewReport.verdict === "PASS" &&
        validDrift &&
        evidenceCurrent &&
        blockingProvisionalOqs.length === 0;

      return {
        taskId: task.id,
        risk: riskTier,
        approval: task.approval,
        status: task.status,
        executionArtifact,
        reviewReport,
        readyForDone,
      };
    });

    return ok({
      kind: "gate-audit",
      feature,
      tasks,
    });
  } catch (error) {
    return err(
      "cannot-parse",
      `Failed to audit quality gate for '${feature}': ${sanitizeErrorMessage(root, error)}`,
    );
  }
}
