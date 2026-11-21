/**
 * SDD Forge MCP v2 tools — Single Source of Truth (ADR-0052).
 *
 * Thin read-only transport adapters backed directly by the canonical
 * `plugins/sdd-quality-loop/scripts/v2/*.mjs` modules. Never duplicates
 * markdown/task/drift parsers and never accepts a `root` tool parameter.
 */

import fs from "node:fs";
import path from "node:path";
import { err, ok, type Result } from "../envelope.js";
import { parseActiveSpecDirectories } from "../parsers/agents-md.js";
import { guardedExists, guardedRead } from "../path-guard.js";
import { isSddRoot, type SddRoot } from "../root.js";
import { checkSpecDrift } from "../../../../plugins/sdd-quality-loop/scripts/v2/check-spec-drift.mjs";
import { analyzeTraceability } from "../../../../plugins/sdd-quality-loop/scripts/v2/check-traceability.mjs";
import {
  buildDecisionViewData,
  renderDecisionViewMarkdown,
} from "../../../../plugins/sdd-quality-loop/scripts/v2/render-decision-view.mjs";
import { runDoctor } from "../../../../plugins/sdd-quality-loop/scripts/v2/sdd-doctor.mjs";

const FEATURE_RE = /^[A-Za-z0-9._-]+$/;
const TASK_ID_RE = /^T-[0-9]+$/;

export type RiskTier = "low" | "standard" | "high";
export type DriftStatus = "CLEAN" | "AMENDED" | "UNDECLARED_DRIFT" | "UNBASELINED";
export type DoctorStatus = "CLEAN" | "WARN" | "NG";

interface V2TaskSummary {
  id: string;
  title: string;
  risk: string;
  approval: string;
  status: string;
}

function toRiskTier(value: string): RiskTier {
  return value === "high" || value === "standard" || value === "low" ? value : "standard";
}

function toDriftStatus(value: string): DriftStatus {
  if (value === "CLEAN" || value === "AMENDED" || value === "UNDECLARED_DRIFT") {
    return value;
  }
  return "UNBASELINED";
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
    specDriftStatus?: DriftStatus;
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

function validateFeatureName(feature: string): Result<string> {
  if (typeof feature !== "string" || !FEATURE_RE.test(feature) || feature === "." || feature === "..") {
    return err("invalid-input", "Feature must match ^[A-Za-z0-9._-]+$ without path separators.");
  }
  return ok(feature);
}

function validateTaskId(taskId: string): Result<string> {
  if (typeof taskId !== "string" || !TASK_ID_RE.test(taskId)) {
    return err("invalid-input", "taskId must match ^T-[0-9]+$.");
  }
  return ok(taskId);
}

function isApprovedValue(approval: string): boolean {
  return /^Approved(?:\s+\([^)]+\))?$/i.test(approval.trim());
}

function computeNextAction(
  feature: string,
  tasks: readonly V2TaskSummary[],
  specCheckVerdict: string,
  highestRisk: RiskTier,
  hasSpecs: boolean,
): NextAction {
  if (!hasSpecs || tasks.length === 0) {
    return {
      phase: "bootstrap",
      command: `/sdd-bootstrap:bootstrap feature --feature ${feature}`,
      rationale: `specs/${feature} is missing core SDD specification files or tasks.`,
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
  if (approved.every((t) => t.status === "Done")) {
    return {
      phase: "done",
      command: "feature complete",
      rationale: `All Approved tasks in specs/${feature}/tasks.md have reached Done.`,
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
    const report = checkSpecDrift({ feature, projectRoot: root.path, baselinePath: undefined });
    return {
      status: toDriftStatus(report.status),
      changedFiles: report.changedFiles,
      amendmentCount: report.amendments.length,
    };
  } catch {
    return { status: "UNBASELINED", changedFiles: [], amendmentCount: 0 };
  }
}

function discoverActiveFeatures(root: SddRoot): string[] {
  const fromAgents = parseActiveSpecDirectories(root);
  if (fromAgents.ok && fromAgents.data.length > 0) {
    return fromAgents.data
      .map((entry) => entry.feature)
      .filter((name) => FEATURE_RE.test(name) && fs.existsSync(path.join(root.path, "specs", name)));
  }
  const specsDir = path.join(root.path, "specs");
  if (!fs.existsSync(specsDir)) return [];
  return fs
    .readdirSync(specsDir, { withFileTypes: true })
    .filter((entry) => entry.isDirectory() && FEATURE_RE.test(entry.name))
    .map((entry) => entry.name)
    .sort();
}

function countDriftEvents(root: SddRoot): number {
  const eventsPath = path.join(root.path, ".sdd", "drift-events.jsonl");
  if (!fs.existsSync(eventsPath)) return 0;
  try {
    const raw = fs.readFileSync(eventsPath, "utf8");
    return raw
      .split(/\r?\n/)
      .map((line) => line.trim())
      .filter((line) => line.length > 0).length;
  } catch {
    return 0;
  }
}

function parseReviewReportVerdict(contents: string): "PASS" | "FAIL" | "UNKNOWN" {
  if (/(?:^|\n)[ \t>*-]*(?:\*\*)?VERDICT(?:\*\*)?[ \t]*:[ \t]*PASS\b/.test(contents)) {
    return "PASS";
  }
  if (/(?:^|\n)[ \t>*-]*(?:\*\*)?VERDICT(?:\*\*)?[ \t]*:[ \t]*FAIL\b/.test(contents)) {
    return "FAIL";
  }
  return "UNKNOWN";
}

export function sddProjectOverview(
  root: SddRoot,
  options: { includeDoctor?: boolean } = {},
): Result<ProjectOverviewData> {
  if (!isSddRoot(root)) {
    return err("not-sdd-root", "Resolved root does not contain AGENTS.md or specs/.");
  }
  const features = discoverActiveFeatures(root);
  const activeFeatures: ProjectOverviewFeature[] = [];

  for (const feature of features) {
    try {
      const dv = buildDecisionViewData({ feature, projectRoot: root.path });
      const drift = readDriftSummary(root, feature);
      const hasSpecs =
        guardedExists(root, `specs/${feature}/requirements.md`) &&
        guardedExists(root, `specs/${feature}/tasks.md`);
      const tasks = dv.tasks;
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
        nextAction: computeNextAction(feature, tasks, dv.specCheckVerdict, highestRisk, hasSpecs),
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
    const doc = runDoctor({ root: root.path });
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

  const featureDir = path.join(root.path, "specs", feature);
  if (!fs.existsSync(featureDir)) {
    return err("not-found", `Feature directory specs/${feature} does not exist.`);
  }

  try {
    const dv = buildDecisionViewData({ feature, projectRoot: root.path });
    const trace = analyzeTraceability({ feature, projectRoot: root.path });
    const drift = readDriftSummary(root, feature);

    const files = {
      requirements: guardedExists(root, `specs/${feature}/requirements.md`),
      design: guardedExists(root, `specs/${feature}/design.md`),
      tasks: guardedExists(root, `specs/${feature}/tasks.md`),
      baseline: guardedExists(root, `specs/${feature}/.spec-baseline.json`),
    };
    const gapCount =
      trace.gaps.orphanReqs.length +
      trace.gaps.unassignedAcs.length +
      trace.gaps.unlinkedAcs.length +
      trace.gaps.brokenReqRefs.length +
      trace.gaps.brokenAcRefs.length;

    const provisionalIds = dv.openQuestions.filter((q) => !q.confirmed).map((q) => q.id);

    const highestRisk = toRiskTier(dv.highestRisk);
    const data: FeatureStateData = {
      kind: "feature-state",
      feature,
      highestRisk,
      files,
      traceability: {
        complete: trace.complete,
        requirementCount: trace.requirements.length,
        acCount: trace.acceptanceCriteria.length,
        taskCount: trace.tasks.length,
        gapCount,
      },
      drift,
      openQuestions: {
        total: dv.openQuestions.length,
        provisionalCount: provisionalIds.length,
        provisionalIds,
      },
      nextAction: computeNextAction(
        feature,
        dv.tasks,
        dv.specCheckVerdict,
        highestRisk,
        files.requirements && files.tasks,
      ),
    };

    if (options.includeDecisionViewMarkdown) {
      data.decisionViewMarkdown = renderDecisionViewMarkdown(dv);
    }

    return ok(data);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return err("cannot-parse", `Failed to inspect feature '${feature}': ${message}`);
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
    filterTaskId = checkedTask.data;
  }

  const featureDir = path.join(root.path, "specs", feature);
  if (!fs.existsSync(featureDir)) {
    return err("not-found", `Feature directory specs/${feature} does not exist.`);
  }

  try {
    const dv = buildDecisionViewData({ feature, projectRoot: root.path });
    const drift = readDriftSummary(root, feature);
    const selectedTasks = filterTaskId
      ? dv.tasks.filter((t) => t.id === filterTaskId)
      : dv.tasks;

    if (filterTaskId && selectedTasks.length === 0) {
      return err("not-found", `Task '${filterTaskId}' not found in specs/${feature}/tasks.md.`);
    }

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
          if (parsed.schema === "sdd-gate-execution/v1") {
            if (parsed.verdict === "PASS" || parsed.verdict === "FAIL") {
              executionArtifact.verdict = parsed.verdict;
            }
            const checks = parsed.checks as Record<string, unknown> | undefined;
            const sd = checks?.specDrift as Record<string, unknown> | undefined;
            if (
              sd?.status === "CLEAN" ||
              sd?.status === "AMENDED" ||
              sd?.status === "UNDECLARED_DRIFT"
            ) {
              executionArtifact.specDriftStatus = sd.status;
            }
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

      const readyForDone =
        isApprovedValue(task.approval) &&
        executionArtifact.verdict === "PASS" &&
        reviewReport.verdict === "PASS" &&
        drift.status !== "UNDECLARED_DRIFT";

      return {
        taskId: task.id,
        risk: toRiskTier(task.risk),
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
    const message = error instanceof Error ? error.message : String(error);
    return err("cannot-parse", `Failed to audit quality gate for '${feature}': ${message}`);
  }
}
