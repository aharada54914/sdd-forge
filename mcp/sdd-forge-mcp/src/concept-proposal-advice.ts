import { createHash } from "node:crypto";
import { isDeepStrictEqual } from "node:util";
import { conceptStopAction, recordedConceptStop, retiredV1Action } from "./concept-gate-advice.js";
import { isJsonObject, type JsonObject } from "./parsers/json-object.js";
import { guardedRead, resolveGuarded } from "./path-guard.js";
import type { SddRoot } from "./root.js";

interface ProposalAdvice {
  action: { phase: "blocked" | "bootstrap"; command: string; rationale: string };
  decision?: "DEFER" | "REJECT";
}

function readObject(text: string): JsonObject | undefined {
  try {
    const value: unknown = JSON.parse(text);
    return isJsonObject(value) ? value : undefined;
  } catch {
    return undefined;
  }
}

function markdownObject(text: string): JsonObject | undefined {
  const blocks = [...text.matchAll(/^```json\r?\n([\s\S]*?)^```[ \t]*\r?$/gm)];
  const body = blocks[0]?.[1];
  return blocks.length === 1 && body !== undefined ? readObject(body) : undefined;
}

function blocked(command: string, rationale: string): ProposalAdvice {
  return { action: { phase: "blocked", command, rationale } };
}

// These are display hints about feature-local artifacts. Only the shipped validator
// checks the domain inputs, validates a proposal and admits a human decision.
export function conceptProposalAdvice(root: SddRoot, feature: string, inBootstrap: boolean, stopped?: ReturnType<typeof recordedConceptStop>): ProposalAdvice | undefined {
  if (!/^[a-z0-9][a-z0-9-]*$/.test(feature)) return undefined;
  const prefix = `specs/${feature}/concept-test`;
  const jsonPath = `${prefix}.json`;
  const mdPath = `${prefix}.md`;
  const decisionPath = `${prefix}.decision.json`;
  const seedPath = `${prefix}-seed.md`;
  const resume = `human: resume the original /sdd-bootstrap:bootstrap conversation for ${feature}`;
  const validate = `validate-concept-test.sh --root . --feature ${feature} --require-v2`;
  const inspect = (source: string, reason: string) => blocked(
    `human: run the installed ${validate}`,
    `${reason} 対象は ${source} です。プロジェクトで配布版の検証器（PowerShell は .ps1）を実行し、診断に沿って提案と証跡を確認してください。`,
  );

  // A gate execution records neither proposal hash. Verify again when its recorded
  // refusal or missing decision no longer describes the feature-local evidence.
  function continuation(): ProposalAdvice | undefined {
    if (stopped) {
      // A recorded v1 retirement is stale once the record was migrated to v2.
      if (stopped.status === "BLOCK" && !stopped.missingDecision && !stopped.retiredV1) return undefined;
      return blocked(
        `human: run the installed ${validate}`,
        `${stopped.path} の前回判定は ${stopped.status} です。現在の提案・判断を配布版の検証器（PowerShell は .ps1）で再検証し、CONTINUE なら品質ゲートを再実行してください。`,
      );
    }
    if (!inBootstrap) return undefined;
    return {
      action: {
        phase: "bootstrap",
        command: resume,
        rationale: `配布版の ${validate}（PowerShell は .ps1）で CONTINUE を確認したら、${feature} の元のbootstrap対話を再開してください。起動し直す場合は元のモード・入力元・対象featureを指定し、${seedPath} の要件原文を引き継いでください。`,
      },
    };
  }
  const json = guardedRead(root, jsonPath);
  const markdown = guardedRead(root, mdPath);
  const receipt = guardedRead(root, decisionPath);
  const noDecision = !receipt.ok && receipt.error.details?.rule === "exists";
  // The validator refuses a v1 record before any other check, so advise the migration first.
  const retired = (source: string) => ({ action: retiredV1Action(feature, `${source} は concept-test/v1 の記録です。`) });
  if (!json.ok) {
    const missing = json.error.details?.rule === "exists";
    if (missing && markdown.ok && markdownObject(markdown.data.contents)?.schema === "concept-test/v1") return retired(mdPath);
    if (!missing || !noDecision) {
      return inspect(jsonPath, "提案のJSONを読み取れません。");
    }
    if (markdown.ok || markdown.error.details?.rule !== "exists") {
      return inspect(jsonPath, "Markdownに対応する提案のJSONを読み取れません。");
    }
    // No record is left (a project without domain/ deleted its v1 files). Only the gate
    // can see a v1 record still held by the Git index, so keep its own advice then.
    if (stopped?.retiredV1 === "working-tree") {
      return blocked(
        `human: re-run the quality gate for ${feature}`,
        `${stopped.path} の前回判定は廃止された concept-test/v1 の記録による BLOCK です。${prefix} の記録は現在ありません。品質ゲートを再実行してください。`,
      );
    }
    if (inBootstrap && resolveGuarded(root, seedPath).ok) {
      return blocked(
        resume,
        `${seedPath} に元の要件があり、Concept Testの提案はまだありません。元の対話で未回答の問いを確認し、要件原文を保って既存概念との区別を回答してください。起動し直す場合は元のモード・入力元・対象featureを指定してください。`,
      );
    }
    return undefined;
  }

  const proposal = readObject(json.data.contents);
  if (proposal?.schema === "concept-test/v1") return retired(jsonPath);
  if (proposal?.schema !== "concept-test/v2" || proposal.feature !== feature) {
    return inspect(jsonPath, "提案の形式・対象を確認できません。");
  }
  if (!markdown.ok) return inspect(mdPath, "提案のMarkdownを読み取れません。");
  if (!isDeepStrictEqual(markdownObject(markdown.data.contents), proposal)) {
    return inspect(mdPath, "Markdownに記載された提案とJSONファイルの内容が一致しません。");
  }
  const legacy = resolveGuarded(root, `${prefix}.approval.json`);
  if (legacy.ok || legacy.error.details?.rule !== "exists") {
    return inspect(jsonPath, "v2提案と旧署名記録の組み合わせを確認してください。");
  }
  switch (proposal.proposal) {
    case "FITS_EXISTING_CONCEPTS":
      return noDecision ? continuation() : inspect(decisionPath, "FITS提案と判断記録の組み合わせを確認してください。");
    case "NEW_CONCEPT_CANDIDATE":
    case "RESPONSIBILITY_CONFLICT":
    case "REQUIRES_HUMAN_DECISION":
      break;
    default:
      return inspect(jsonPath, "提案の分類を確認できません。");
  }

  if (noDecision) {
    return blocked(
      `human: run the installed validate-concept-test.sh --root . --feature ${feature} --confirm`,
      `${jsonPath} はNon-FITS提案で、${decisionPath} はまだありません。本人が別端末で配布版の検証器（PowerShell は .ps1）を実行し、提示された対象・根拠・区別を確認して判断してください。検証器が提案の不備を報告した場合は先に修復してください。`,
    );
  }
  if (!receipt.ok) return inspect(decisionPath, "判断記録を読み取れません。");
  const decision = readObject(receipt.data.contents);
  if (decision?.schema !== "concept-test-decision/v1" || decision.feature !== feature) {
    return inspect(decisionPath, "判断記録の形式・対象を確認できません。");
  }
  if (decision.proposal_json_sha256 !== createHash("sha256").update(json.data.contents).digest("hex") ||
      decision.proposal_md_sha256 !== createHash("sha256").update(markdown.data.contents).digest("hex")) {
    return inspect(decisionPath, "記録されたSHA-256が現在の提案と一致しません。更新した提案を確認し、必要に応じて本人が別端末で --confirm を実行してください。");
  }
  switch (decision.decision) {
    case "defer-to-domain-update": return { action: conceptStopAction(feature, "DEFER", decisionPath), decision: "DEFER" };
    case "rejected": return { action: conceptStopAction(feature, "REJECT", decisionPath), decision: "REJECT" };
    case "proceed": return continuation();
    default: return inspect(decisionPath, "記録された判断を確認できません。");
  }
}

/** Current human decisions take precedence over the previous gate observation.
 * For other cases the gate can diagnose failures that the MCP reader cannot observe.
 */
export function conceptAdvice(root: SddRoot, feature: string, tasks: readonly { id: string; status: string }[], inBootstrap: boolean) {
  if (!inBootstrap && tasks.every(task => task.status === "Done")) return;
  const stop = recordedConceptStop(root, feature, tasks);
  const proposal = conceptProposalAdvice(root, feature, inBootstrap, stop);
  if (proposal?.decision && stop) {
    // Report both observations. A decision bound to the current proposal does not
    // prove that the runtime and domain inputs now validate.
    return { ...proposal.action, rationale: `${proposal.action.rationale} 前回の品質ゲート（${stop.path}）の判定は ${stop.status} です。現在の入力に対する検証結果と合わせて確認してください。` };
  }
  if (proposal && (!stop || proposal.decision || stop.status !== "BLOCK" || stop.missingDecision || stop.retiredV1)) {
    return proposal.action;
  }
  return stop?.action;
}
