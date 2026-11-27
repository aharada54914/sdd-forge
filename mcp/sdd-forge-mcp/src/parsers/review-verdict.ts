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

export type PerspectiveId = "G1" | "G2" | "G3" | "G4" | "G5";
export type PerspectiveOutcome =
  | "PASS"
  | "NA_WITH_REASON"
  | "NA_WITHOUT_REASON"
  | "FAIL"
  | "INVALID"
  | "MISSING";

export interface IndependentReviewEvaluation {
  complete: boolean;
  perspectives: Record<PerspectiveId, PerspectiveOutcome>;
}

const PERSPECTIVE_IDS: readonly PerspectiveId[] = ["G1", "G2", "G3", "G4", "G5"];
const TEMPLATE_PLACEHOLDER_RE =
  /\bPASS\s*[|/]\s*FAIL\b|\bFAIL\s*[|/]\s*PASS\b|<\s*(?:理由|reason|根拠|evidence|status|判定|要記入)[^>]*>|\b(?:TBD|TODO)\b/i;
const PERSPECTIVE_LINE_RE =
  /^[ \t]*(?:[-*+]|\d+\.|#{2,6})?[ \t]*(?:\*\*)?(G[1-5])(?:\*\*)?(?:[ \t]*[（(][^）)\r\n]*[）)])?[ \t]*(?:\*\*)?[ \t]*[:：—–-][ \t]*(.*)$/;
const STATUS_TOKEN_RE = /^(?:\*\*)?(PASS|FAIL|NEEDS_WORK|BLOCKED|N\/A)(?:\*\*)?(?=$|[\s(（:：—–\-.,;]|$)/i;

function hasSubstantiveNaReason(afterNa: string): boolean {
  const cleaned = afterNa
    .replace(/^[ \t()（）[\]:：—–\-|*_`]+|[ \t()（）[\]:：—–\-|*_`]+$/g, "")
    .replace(/[()（）[\]:：—–\-|*_`]+/g, " ")
    .trim();
  if (!cleaned) return false;
  if (/^(?:n\/?a|none|null|なし|無し|未記入|不明)$/i.test(cleaned)) return false;
  // Require at least 2 meaningful word/Japanese characters as a concrete rationale.
  const meaningful = cleaned.match(/[A-Za-z0-9\u3040-\u30FF\u3400-\u9FFF]/g);
  return (meaningful?.length ?? 0) >= 2;
}

function classifyPerspectiveValue(id: PerspectiveId, rawValue: string): PerspectiveOutcome {
  const value = rawValue.trim();
  if (!value || TEMPLATE_PLACEHOLDER_RE.test(value)) return "INVALID";
  const lead = STATUS_TOKEN_RE.exec(value);
  if (!lead) return "INVALID";
  const token = (lead[1] ?? "").toUpperCase();
  const rest = value.slice(lead[0].length);
  if (token === "FAIL" || token === "NEEDS_WORK" || token === "BLOCKED") return "FAIL";
  if (token === "PASS") return "PASS";
  if (token === "N/A") {
    if (id === "G1") return "INVALID";
    return hasSubstantiveNaReason(rest) ? "NA_WITH_REASON" : "NA_WITHOUT_REASON";
  }
  return "INVALID";
}

function parseTablePerspectiveRow(line: string): { id: PerspectiveId; value: string } | null {
  const trimmed = line.trim();
  if (!trimmed.startsWith("|")) return null;
  const cells = trimmed
    .replace(/^\|/, "")
    .replace(/\|$/, "")
    .split("|")
    .map((c) => c.trim());
  if (cells.length < 2) return null;
  // Skip markdown table separator rows
  if (cells.every((c) => /^:?-+:?$/.test(c))) return null;
  const first = (cells[0] ?? "").replace(/[*_`]/g, "").trim();
  const idMatch = /^(G[1-5])(?=$|[\s(（:：])/i.exec(first);
  if (!idMatch) return null;
  const id = idMatch[1]!.toUpperCase() as PerspectiveId;
  const restCells = cells.slice(1);
  // Find the cell that begins with a status token; combine remaining cells as rationale.
  const statusIdx = restCells.findIndex((c) => STATUS_TOKEN_RE.test(c.replace(/^[`*_]+|[`*_]+$/g, "").trim()));
  if (statusIdx === -1) {
    return { id, value: restCells.join(" — ") };
  }
  const statusCell = restCells[statusIdx]!.replace(/^[`*_]+|[`*_]+$/g, "").trim();
  const extraRationale = restCells
    .slice(statusIdx + 1)
    .map((c) => c.trim())
    .filter(Boolean)
    .join(" ");
  const value = extraRationale ? `${statusCell} ${extraRationale}` : statusCell;
  return { id, value };
}

/**
 * Verify that an independent quality-gate report records concrete, non-placeholder
 * evaluations for all five canonical perspectives (G1-G5) outside code fences and
 * block quotes (V-06).
 */
export function evaluateIndependentReviewPerspectives(contents: string): IndependentReviewEvaluation {
  const found = new Map<PerspectiveId, PerspectiveOutcome[]>();
  for (const id of PERSPECTIVE_IDS) found.set(id, []);

  let activeFence: string | null = null;
  for (const line of contents.replace(/\r\n/g, "\n").split("\n")) {
    const trimmed = line.trimStart();
    const fence = /^(`{3,}|~{3,})/.exec(trimmed);
    if (activeFence !== null) {
      if (trimmed.startsWith(activeFence)) activeFence = null;
      continue;
    }
    if (fence) {
      activeFence = fence[1] ?? "```";
      continue;
    }
    if (trimmed.startsWith(">")) continue;

    const tableRow = parseTablePerspectiveRow(line);
    if (tableRow) {
      found.get(tableRow.id)!.push(classifyPerspectiveValue(tableRow.id, tableRow.value));
      continue;
    }
    const lineMatch = PERSPECTIVE_LINE_RE.exec(line);
    if (lineMatch) {
      const id = lineMatch[1]!.toUpperCase() as PerspectiveId;
      found.get(id)!.push(classifyPerspectiveValue(id, lineMatch[2] ?? ""));
    }
  }

  const perspectives = {} as Record<PerspectiveId, PerspectiveOutcome>;
  let complete = true;
  for (const id of PERSPECTIVE_IDS) {
    const outcomes = found.get(id)!;
    if (outcomes.length === 0) {
      perspectives[id] = "MISSING";
      complete = false;
    } else if (outcomes.includes("FAIL")) {
      perspectives[id] = "FAIL";
      complete = false;
    } else if (outcomes.includes("INVALID")) {
      perspectives[id] = "INVALID";
      complete = false;
    } else if (outcomes.includes("NA_WITHOUT_REASON")) {
      perspectives[id] = "NA_WITHOUT_REASON";
      complete = false;
    } else {
      // Every recorded entry for this perspective is PASS or NA_WITH_REASON.
      perspectives[id] = outcomes[outcomes.length - 1]!;
    }
  }
  return { complete, perspectives };
}

export function isIndependentReviewComplete(contents: string): boolean {
  return evaluateIndependentReviewPerspectives(contents).complete;
}
