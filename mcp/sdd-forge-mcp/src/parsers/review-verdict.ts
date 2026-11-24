/**
 * The one reading of an independent quality-gate report's verdict, shared by
 * the gate audit and the Done-evidence check (#835).
 *
 * A report's verdict is its FIRST verdict line: a whole line reading
 * `VERDICT: <value>` (optionally bulleted or bolded), written in upper case,
 * outside a block quote. This matches the report convention of a bare
 * identity block before any prose, and the quality-report parser. Block-quoted
 * round history, rules prose such as `verdict: fail if any Major`, and later
 * drafts do not override it. Lines inside fenced code blocks count only when
 * the report has no other verdict line (a verbatim evaluator block).
 *
 * `PASS` passes. `FAIL`, `NEEDS_WORK` (the evaluator's vocabulary) and
 * `BLOCKED` fail. No verdict line at all is `UNKNOWN`.
 */
export type ReviewVerdict = "PASS" | "FAIL" | "UNKNOWN";

const VERDICT_LINE =
  /^([ \t>*-]*)(?:\*\*)?VERDICT(?:\*\*)?[ \t]*:[ \t]*(?:\*\*)?(PASS|FAIL|NEEDS_WORK|BLOCKED)(?:\*\*)?[ \t]*$/;

export function parseReviewReportVerdict(contents: string): ReviewVerdict {
  let firstPlain: string | undefined;
  let firstFenced: string | undefined;
  let activeFence: string | null = null;
  for (const line of contents.replace(/\r\n/g, "\n").split("\n")) {
    const trimmed = line.trimStart();
    const fence = /^(`{3,}|~{3,})/.exec(trimmed);
    if (activeFence !== null) {
      if (trimmed.startsWith(activeFence)) {
        activeFence = null;
        continue;
      }
    } else if (fence) {
      activeFence = fence[1] ?? "```";
      continue;
    }
    const m = VERDICT_LINE.exec(line);
    if (!m || (m[1] ?? "").includes(">")) continue;
    if (activeFence !== null) firstFenced ??= m[2];
    else {
      firstPlain = m[2];
      break;
    }
  }
  const verdict = firstPlain ?? firstFenced;
  if (verdict === undefined) return "UNKNOWN";
  return verdict === "PASS" ? "PASS" : "FAIL";
}
