import { isJsonObject } from "./parsers/json-object.js";
import { guardedRead } from "./path-guard.js";
import type { SddRoot } from "./root.js";

type Stop = "BLOCK" | "DEFER" | "REJECT";
interface BlockedAction {
  phase: "blocked";
  command: string;
  rationale: string;
}

// Shared by the audit and guidance readers. A copied report is not this task's result.
export function parseTaskExecution(contents: string, feature: string, taskId: string) {
  const report: unknown = JSON.parse(contents);
  if (isJsonObject(report) && report.schema === "sdd-gate-execution/v1" && report.feature === feature &&
      typeof report.taskId === "string" && report.taskId.toUpperCase() === taskId.toUpperCase()) {
    return report;
  }
  return undefined;
}

// The validator's and the gate's diagnostic for a retired v1 record starts with this text.
const V1_RETIRED = "concept-test: BLOCK: concept-test/v1 records are no longer supported";
// run-sdd-gate.mjs adds this when only the Git index holds the v1 record.
const V1_INDEX_NOTE = "The Git index still holds the v1 record";
// The gate's stop for a retired v1 approval left without its record.
const LEFTOVER_APPROVAL = /^concept-test: BLOCK: leftover specs\/[^\s]+\/concept-test\.approval\.json from a retired v1 record/;
const LEFTOVER_INDEX_NOTE = "The Git index still holds it";

/** Only v1 wrote concept-test.approval.json; a copy left behind stops every gate run. */
export function leftoverApprovalAction(feature: string, observation: string): BlockedAction {
  const approval = `specs/${feature}/concept-test.approval.json`;
  return {
    phase: "blocked", command: `human: delete the leftover ${approval}`,
    rationale: `${observation} ${approval} は廃止された concept-test/v1 の承認ファイルです。削除してください。Concept Test の記録がある場合は、削除後に配布版の validate-concept-test.sh（PowerShell は .ps1）を --root . --feature ${feature} --require-v2 で再検証し、CONTINUE を確認後に品質ゲートを再実行してください。記録がない場合は、削除後にそのまま品質ゲートを再実行してください。`,
  };
}

/** Owner decision 2026-11-26: v1 records are retired and must be recreated as v2. */
export function retiredV1Action(feature: string, observation: string): BlockedAction {
  const prefix = `specs/${feature}/concept-test`;
  return {
    phase: "blocked", command: `human: recreate the Concept Test proposal for ${feature} as concept-test/v2`,
    // A leftover approval stops every v2 run, so it is deleted before recreating.
    rationale: `${observation} concept-test/v1 の記録は廃止されました。まず残った ${prefix}.approval.json を削除し、その後 Concept Test をもう一度実行して concept-test/v2 の提案として作り直してください。domain/ のないプロジェクトでは Concept Test を実行しないため、v1 の ${prefix}.md・${prefix}.json・${prefix}.approval.json を削除してください。作り直した後は配布版の validate-concept-test.sh（PowerShell は .ps1）を --root . --feature ${feature} --require-v2 で再検証し、CONTINUE を確認後に品質ゲートを再実行してください。domain/ のないプロジェクトでは、削除後に品質ゲートを再実行してください。`,
  };
}

export function conceptStopAction(feature: string, status: Stop, source: string, diagnostic?: string): BlockedAction {
  const observation = `${source} の Concept Test の記録は ${status} です。`;
  if (status === "BLOCK" && diagnostic !== undefined && LEFTOVER_APPROVAL.test(diagnostic)) {
    const action = leftoverApprovalAction(feature, observation);
    if (diagnostic.includes(LEFTOVER_INDEX_NOTE)) {
      action.rationale += " Git のインデックスにも残っているため、その削除もステージしてください。";
    }
    return action;
  }
  if (status === "BLOCK" && diagnostic?.startsWith(V1_RETIRED)) {
    const action = retiredV1Action(feature, observation);
    if (diagnostic.includes(V1_INDEX_NOTE)) {
      action.rationale += " Git のインデックスに v1 の記録が残っているため、その削除もステージしてください。";
    }
    return action;
  }
  if (status === "DEFER") return {
    phase: "blocked", command: `human: run the installed validate-concept-test.sh --root . --feature ${feature} --require-v2`,
    rationale: `${observation} まず配布版の検証器（PowerShell は .ps1）で現在の入力を確認してください。現在も DEFER でモデルが未更新なら /sdd-domain:domain-model update を実行し、レビュー・本人の承認・契約の発行を経て提案を更新してください。更新済みなら発行済みの契約から提案を作り直してください。`,
  };
  if (status === "REJECT") return {
    phase: "blocked", command: `human: stop work on the rejected proposal for ${feature}`,
    rationale: `${observation} 記録が指す提案は却下されました。その提案での作業を停止してください。`,
  };

  // A missing packaged script is reported by the shell before the validator can emit its own diagnostic.
  const missingShellScript = /^(?:\/bin\/)?sh: [^\r\n]*\/validate-concept-test\.sh: No such file(?: or directory)?$/m;
  const missingPowerShellScript = /^The argument ['"][^\r\n]*[\\/]validate-concept-test\.ps1['"] is not recognized as the name of a script file\./m;
  if (diagnostic && (diagnostic.includes("VALIDATE_CONCEPT_TEST_RUNTIME_UNAVAILABLE") ||
      missingShellScript.test(diagnostic) || missingPowerShellScript.test(diagnostic))) {
    return {
      phase: "blocked", command: `human: restore the installed Concept Test runtime for ${feature}`,
      rationale: `${observation} 配布された検証器と依存ファイルの配置を確認し、動作する配布版を復旧してください。現在の版別パッケージで復旧できなければ、${source} の診断を添えて配布元に報告し、作業は停止したままにしてください。復旧後に validate-concept-test.sh（PowerShell は .ps1）を --root . --feature ${feature} --require-v2 で再検証し、CONTINUE を確認後に品質ゲートを再実行してください。`,
    };
  }

  let recovery = "checks.conceptTest.error の診断に沿って、検証器の配置・入力・提案・判断記録を確認してください。";
  if (diagnostic === "concept-test: BLOCK: run --confirm in a separate human-operated terminal") {
    recovery = "この実行時点で人の判断が必要でした。対象と提案を確認し、本人が端末で配布版の検証器に --confirm を指定して判断してください。";
  } else if (diagnostic === "concept-test: BLOCK: domain model must be approved" ||
             diagnostic === "concept-test: BLOCK: approved context map must be pinned") {
    recovery = "モデルのレビュー、本人の承認、対応する契約の発行を確認し、その版で提案を更新してください。";
  }
  return {
    phase: "blocked", command: `human: inspect checks.conceptTest.error in ${source}`,
    rationale: `${observation} ${recovery} 対象プロジェクトで配布版の validate-concept-test.sh（PowerShell は .ps1）を --root . --feature ${feature} --require-v2 で再検証し、CONTINUE を確認後に品質ゲートを再実行してください。`,
  };
}

interface GateStop {
  status: Stop;
  path: string;
  missingDecision: boolean;
  /** The stop was the v1 retirement (a v1 record, or its approval left behind), seen in the working tree or only in the Git index. */
  retiredV1?: "working-tree" | "index";
  action: BlockedAction;
}

export function recordedConceptStop(root: SddRoot, feature: string, tasks: readonly { id: string; status: string }[]): GateStop | undefined {
  for (const task of tasks) {
    if (task.status !== "Implementation Complete" && task.status !== "Blocked") continue;
    if (!/^T-[A-Za-z0-9._-]+$/.test(task.id)) continue;
    const path = `reports/quality-gate/${feature}-${task.id}.execution.json`;
    const read = guardedRead(root, path);
    if (!read.ok) continue;
    let report;
    try { report = parseTaskExecution(read.data.contents, feature, task.id); }
    catch { continue; }
    if (report?.verdict !== "FAIL") continue;
    const check = isJsonObject(report.checks) ? report.checks.conceptTest : undefined;
    if (!isJsonObject(check) || check.passed !== false) continue;
    if (check.status === "BLOCK" || check.status === "DEFER" || check.status === "REJECT") {
      const action = conceptStopAction(feature, check.status, path, typeof check.error === "string" ? check.error.trim() : undefined);
      if (check.status !== "BLOCK") {
        action.rationale += " この実行後に提案や判断を更新済みの場合は、対象の Concept Test を再検証し、CONTINUE を確認後に品質ゲートを再実行してください。";
      }
      const error = typeof check.error === "string" ? check.error.trim() : "";
      const leftover = LEFTOVER_APPROVAL.test(error);
      const retiredV1 = check.status !== "BLOCK" || !(leftover || error.startsWith(V1_RETIRED)) ? undefined
        : error.includes(leftover ? LEFTOVER_INDEX_NOTE : V1_INDEX_NOTE) ? "index" as const : "working-tree" as const;
      return {
        status: check.status, path, action, retiredV1,
        missingDecision: error === "concept-test: BLOCK: run --confirm in a separate human-operated terminal",
      };
    }
  }
}
