import { loadGuardrailsConfigFromIo, stripFencedCodeBlocks } from "../../../plugins/sdd-quality-loop/scripts/v2/v2-readonly-core.ts";
import { createGuardedIo, guardedRead } from "./path-guard.js";
import type { SddRoot } from "./root.js";

interface ReviewAction {
  phase: "spec-check";
  command: string;
  rationale: string;
}

function skipReason(root: SddRoot, allLowRisk: boolean): string | undefined {
  const mode = loadGuardrailsConfigFromIo(createGuardedIo(root)).review.pre_impl_check;
  if (mode === "off") return "review.pre_impl_check=off";
  if (mode === "auto" && allLowRisk) return "review.pre_impl_check=auto かつ全タスクが Risk: low";
}

/** Read-only advice, used only when the next task would otherwise need human approval. */
export function beforeTaskApproval(root: SddRoot, feature: string, allLowRisk: boolean): ReviewAction | undefined {
  const path = `reports/spec-check/${feature}.md`;
  const report = guardedRead(root, path);
  const rerun = `/sdd-bootstrap:bootstrap <mode> --feature ${feature} <source>`;
  const inputs = "コマンドの <mode> に元のモード（feature、bugfix、refactor、project）、<source> に元の依頼文または Issue URL を指定して";
  if (!report.ok && report.error.code === "not-found") {
    if (skipReason(root, allLowRisk)) return;
    return {
      phase: "spec-check", command: rerun,
      rationale: `${path} に着工前レビューの記録がありません。今回 --skip-check を明示した場合は人間の承認へ進んでください。それ以外は ${inputs}レビューを実行してください。`,
    };
  }

  // Only the report's own verdict field counts; examples in findings or code are not decisions.
  if (report.ok) {
    const header = stripFencedCodeBlocks(report.data.contents).split(/^##[ \t]/m, 1)[0] ?? "";
    const fields = [...header.matchAll(/^[ \t]*(?:-[ \t]+)?\*\*Verdict\*\*:[ \t]*([^\r\n]*)$/gm)];
    const verdict = fields.length === 1 ? fields[0]?.[1]?.trim() : undefined;
    if (verdict === "PASS" || verdict === "PASS_WITH_NOTES") return;
    if (verdict === "NEEDS_FIX") {
      const fix = `${path} の判定は NEEDS_FIX です。Blockers の指摘に沿って仕様を修正してください。`;
      const skipped = skipReason(root, allLowRisk);
      if (skipped) {
        return {
          phase: "spec-check", command: `human: review ${path}`,
          rationale: `${fix} 現在の設定（${skipped}）では bootstrap がレビューを省略するため、修正後の再レビュー方法を担当者に確認してください。`,
        };
      }
      return {
        phase: "spec-check", command: rerun,
        rationale: `${fix} ${inputs}着工前レビューを再実行してください。`,
      };
    }
  }
  return {
    phase: "spec-check", command: `human: check ${path}`,
    rationale: `${path} の判定を確認できません。着工前レビューの記録と結果を確認してください。`,
  };
}
