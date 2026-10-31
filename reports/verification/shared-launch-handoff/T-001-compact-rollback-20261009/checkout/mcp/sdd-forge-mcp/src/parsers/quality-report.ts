/**
 * Quality gate report parser — extracts `Task ID:`, `Feature:`, `VERDICT:`,
 * and `Critical:`/`Major:`/`Minor:` lines from `reports/quality-gate/*.md`
 * into the `qualityGateSummaryData` entry shape from
 * `contracts/sdd-forge-mcp-tools.v1.schema.json` (file, taskId, feature,
 * verdict, critical, major, minor).
 *
 * Real reports vary in shape (some repeat `VERDICT:` in a closing summary
 * block, some omit `Feature:` or the finding-count lines entirely, some omit
 * `VERDICT:` altogether) — this module reads only the *first* occurrence of
 * each line and never fabricates a missing value: a report with no `VERDICT:`
 * line at all is not `cannot-parse` (the file itself is well-formed markdown;
 * it just does not state a verdict) but is reported as a
 * `verdict-not-found` failure alongside the file, so callers can surface it
 * without guessing PASS/FAIL.
 */

import { guardedRead, listGuardedFiles } from "../path-guard.js";
import type { SddRoot } from "../root.js";

const QUALITY_GATE_REPORTS_DIR = "reports/quality-gate";

/** `qualityGateSummaryData.reports[]` entry shape (contracts v1). */
export interface QualityReportEntry {
  file: string;
  taskId?: string;
  feature?: string;
  verdict: string;
  critical?: number;
  major?: number;
  minor?: number;
}

/** A quality-gate report file for which no `VERDICT:` line could be found. */
export interface QualityReportFailure {
  file: string;
  rule: "verdict-not-found" | "unreadable";
  message: string;
}

/** Result of parsing a single quality-gate report file. */
export type QualityReportParseResult =
  | { ok: true; entry: QualityReportEntry }
  | { ok: false; failure: QualityReportFailure };

const TASK_ID_LINE = /^Task ID:\s*(.+?)\s*$/m;
const FEATURE_LINE = /^Feature:\s*(.+?)\s*$/m;
const VERDICT_LINE = /^VERDICT:\s*(.+?)\s*$/m;
const CRITICAL_LINE = /^Critical:\s*(\d+)\s*$/m;
const MAJOR_LINE = /^Major:\s*(\d+)\s*$/m;
const MINOR_LINE = /^Minor:\s*(\d+)\s*$/m;

/**
 * Parses a single `reports/quality-gate/*.md` file. Returns a
 * `QualityReportFailure` (not a `cannot-parse` envelope) when the file reads
 * fine but has no `VERDICT:` line — see module doc for why that case is
 * deliberately not treated as malformed input.
 */
export function parseQualityReport(root: SddRoot, relFilePath: string): QualityReportParseResult {
  const fileResult = guardedRead(root, relFilePath);
  if (!fileResult.ok) {
    return {
      ok: false,
      failure: {
        file: relFilePath,
        rule: "unreadable",
        message: fileResult.error.message,
      },
    };
  }

  const contents = fileResult.data.contents;
  const verdictMatch = VERDICT_LINE.exec(contents);
  if (verdictMatch?.[1] === undefined) {
    return {
      ok: false,
      failure: {
        file: relFilePath,
        rule: "verdict-not-found",
        message: `No "VERDICT:" line found in ${relFilePath}.`,
      },
    };
  }

  const entry: QualityReportEntry = {
    file: relFilePath,
    verdict: verdictMatch[1],
  };

  const taskIdMatch = TASK_ID_LINE.exec(contents);
  if (taskIdMatch?.[1] !== undefined) {
    entry.taskId = taskIdMatch[1];
  }
  const featureMatch = FEATURE_LINE.exec(contents);
  if (featureMatch?.[1] !== undefined) {
    entry.feature = featureMatch[1];
  }
  const criticalMatch = CRITICAL_LINE.exec(contents);
  if (criticalMatch?.[1] !== undefined) {
    entry.critical = Number.parseInt(criticalMatch[1], 10);
  }
  const majorMatch = MAJOR_LINE.exec(contents);
  if (majorMatch?.[1] !== undefined) {
    entry.major = Number.parseInt(majorMatch[1], 10);
  }
  const minorMatch = MINOR_LINE.exec(contents);
  if (minorMatch?.[1] !== undefined) {
    entry.minor = Number.parseInt(minorMatch[1], 10);
  }

  return { ok: true, entry };
}

/** Aggregate result of scanning every `*.md` file under a directory. */
export interface QualityReportsScan {
  reports: QualityReportEntry[];
  failures: QualityReportFailure[];
}

/**
 * Walks `relDir` (default `reports/quality-gate`) via `listGuardedFiles`,
 * parses every `*.md` file found, and returns the successfully parsed
 * entries alongside any per-file failures (see `parseQualityReport`).
 */
export function listQualityReports(
  root: SddRoot,
  relDir: string = QUALITY_GATE_REPORTS_DIR,
): QualityReportsScan {
  const reports: QualityReportEntry[] = [];
  const failures: QualityReportFailure[] = [];

  for (const relFilePath of listGuardedFiles(root, relDir)) {
    if (!relFilePath.endsWith(".md")) {
      continue;
    }
    const result = parseQualityReport(root, relFilePath);
    if (result.ok) {
      reports.push(result.entry);
    } else {
      failures.push(result.failure);
    }
  }

  return { reports, failures };
}
