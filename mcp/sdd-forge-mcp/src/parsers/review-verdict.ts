/**
 * The one reading of an independent quality-gate report's verdict, shared by
 * the gate audit and the Done-evidence check (#835).
 *
 * Only `PASS` passes. `FAIL`, `NEEDS_WORK` (the evaluator's vocabulary) and
 * `BLOCKED` fail, and any failing line wins over a passing one. Lines inside
 * fenced code blocks are examples, not verdicts, and are ignored.
 */
export type ReviewVerdict = "PASS" | "FAIL" | "UNKNOWN";

const VERDICT_LINE =
  /^[ \t>*-]*(?:\*\*)?VERDICT(?:\*\*)?[ \t]*:[ \t]*(?:\*\*)?(PASS|FAIL|NEEDS_WORK|BLOCKED)(?:\*\*)?\b/i;

export function parseReviewReportVerdict(contents: string): ReviewVerdict {
  let sawPass = false;
  let sawFail = false;
  let activeFence: string | null = null;
  for (const line of contents.replace(/\r\n/g, "\n").split("\n")) {
    const trimmed = line.trimStart();
    if (activeFence !== null) {
      if (trimmed.startsWith(activeFence)) activeFence = null;
      continue;
    }
    const fence = /^(`{3,}|~{3,})/.exec(trimmed);
    if (fence) {
      activeFence = fence[1] ?? "```";
      continue;
    }
    const verdict = VERDICT_LINE.exec(line)?.[1]?.toUpperCase();
    if (verdict === undefined) continue;
    if (verdict === "PASS") sawPass = true;
    else sawFail = true;
  }
  if (sawFail) return "FAIL";
  return sawPass ? "PASS" : "UNKNOWN";
}
