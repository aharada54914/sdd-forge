/**
 * Traceability table extraction — `specs/<feature>/traceability.md`.
 *
 * Section heading text varies per feature (e.g. sdd-forge-refactor uses
 * "## REQ → Task (実装対応)" while sdd-forge-mcp uses "## REQ → Task"), so
 * this module never matches on heading text. Instead it scans every markdown
 * table in the file and classifies each one by its header row's column
 * names, extracting three specific table shapes when present:
 *
 * - REQ -> Task: a `REQ-ID` column and a `Task-ID` column, no `AC-ID` column.
 * - AC -> REQ: an `AC-ID` column and a `REQ-ID` column, no `TEST-ID` column.
 * - AC -> TEST -> Task: `AC-ID`, `TEST-ID`, and `Task-ID` columns together.
 *
 * A feature's traceability.md may have zero, one, or several tables of a
 * given shape (e.g. sdd-forge-refactor has no AC -> TEST -> Task table at
 * all) — an absent shape simply yields an empty array, not an error. Any
 * matched table whose column names are present but whose row values are
 * empty/missing where a matched column expects an ID is `cannot-parse` with
 * the 1-based line number of the offending row.
 *
 * Design.md "Data Plan": `traceability.md -> traceability.ts`.
 */

import { err, ok, type Result } from "../envelope.js";
import { guardedRead } from "../path-guard.js";
import type { SddRoot } from "../root.js";

/** One row of the "REQ -> Task" table. */
export interface ReqToTaskRow {
  reqId: string;
  taskIds: string[];
}

/** One row of the "AC -> REQ" table. */
export interface AcToReqRow {
  acId: string;
  reqIds: string[];
}

/** One row of the "AC -> TEST -> Task" table. */
export interface AcToTestToTaskRow {
  acId: string;
  testId: string;
  taskIds: string[];
  target?: string;
}

export interface TraceabilityData {
  reqToTask: ReqToTaskRow[];
  acToReq: AcToReqRow[];
  acToTestToTask: AcToTestToTaskRow[];
}

function traceabilityRelPath(feature: string): string {
  return `specs/${feature}/traceability.md`;
}

/**
 * Splits file contents into lines without introducing a spurious trailing
 * empty line, and strips a trailing CR (CRLF tolerance) — matching the
 * convention already used by `agents-md.ts` / `tasks.ts`.
 */
function splitLines(contents: string): string[] {
  const normalized = contents.endsWith("\n") ? contents.slice(0, -1) : contents;
  if (normalized.length === 0) {
    return [];
  }
  return normalized.split("\n").map((line) => (line.endsWith("\r") ? line.slice(0, -1) : line));
}

/** True for a markdown table delimiter row, e.g. `|---|:---:|---|`. */
function isDelimiterRow(line: string): boolean {
  const trimmed = line.trim();
  if (!trimmed.startsWith("|")) {
    return false;
  }
  const cells = splitRowCells(trimmed);
  return cells.length > 0 && cells.every((cell) => /^:?-+:?$/.test(cell.trim()));
}

/** Splits a `| a | b | c |`-shaped line into trimmed cell strings. */
function splitRowCells(line: string): string[] {
  const trimmed = line.trim();
  const withoutEdges = trimmed.replace(/^\|/, "").replace(/\|$/, "");
  return withoutEdges.split("|").map((cell) => cell.trim());
}

/** Splits a cell value like `T-001, T-002` into trimmed, non-empty tokens. */
function splitIdList(cell: string): string[] {
  return cell
    .split(",")
    .map((token) => token.trim())
    .filter((token) => token.length > 0);
}

interface RawTable {
  /** Header column names, in order, as they appeared in the header row. */
  columns: string[];
  /** 1-based line number of the header row (for error reporting). */
  headerLineNumber: number;
  /** Data rows: each is `{ cells, lineNumber }`, in file order. */
  rows: Array<{ cells: string[]; lineNumber: number }>;
}

/** Finds every markdown table (header + delimiter + 0-or-more data rows) in `lines`. */
function findTables(lines: string[]): RawTable[] {
  const tables: RawTable[] = [];
  let i = 0;
  while (i < lines.length) {
    const line = lines[i];
    if (line === undefined || !line.trim().startsWith("|")) {
      i += 1;
      continue;
    }
    const nextLine = lines[i + 1];
    if (nextLine === undefined || !isDelimiterRow(nextLine)) {
      i += 1;
      continue;
    }

    const columns = splitRowCells(line);
    const headerLineNumber = i + 1;
    const rows: RawTable["rows"] = [];
    let j = i + 2;
    while (j < lines.length) {
      const rowLine = lines[j];
      if (rowLine === undefined || !rowLine.trim().startsWith("|")) {
        break;
      }
      rows.push({ cells: splitRowCells(rowLine), lineNumber: j + 1 });
      j += 1;
    }

    tables.push({ columns, headerLineNumber, rows });
    i = j;
  }
  return tables;
}

/** Case/whitespace-insensitive lookup of a column's index by its header name. */
function columnIndex(columns: string[], name: string): number {
  return columns.findIndex((column) => column.trim().toLowerCase() === name.toLowerCase());
}

function hasColumn(columns: string[], name: string): boolean {
  return columnIndex(columns, name) !== -1;
}

const REQ_ID_PATTERN = /^REQ-\d+$/;
const AC_ID_PATTERN = /^AC-\d+$/;
const TEST_ID_PATTERN = /^TEST-\d+$/;

/** Extracts REQ -> Task rows from every table shaped like `REQ-ID | Task-ID [| ...]`. */
function extractReqToTask(tables: RawTable[]): Result<ReqToTaskRow[]> {
  const rows: ReqToTaskRow[] = [];
  for (const table of tables) {
    if (!hasColumn(table.columns, "REQ-ID") || !hasColumn(table.columns, "Task-ID")) {
      continue;
    }
    if (hasColumn(table.columns, "AC-ID")) {
      continue;
    }
    const reqIdIdx = columnIndex(table.columns, "REQ-ID");
    const taskIdIdx = columnIndex(table.columns, "Task-ID");
    for (const row of table.rows) {
      const reqIdCell = row.cells[reqIdIdx];
      const taskIdCell = row.cells[taskIdIdx];
      if (reqIdCell === undefined || taskIdCell === undefined) {
        return err(
          "cannot-parse",
          "REQ -> Task table row is missing a required column.",
          { line: row.lineNumber, rule: "req-to-task-row-shape" },
        );
      }
      const reqIds = splitIdList(reqIdCell);
      const taskIds = splitIdList(taskIdCell);
      if (reqIds.length === 0 || taskIds.length === 0) {
        return err(
          "cannot-parse",
          "REQ -> Task table row has an empty REQ-ID or Task-ID cell.",
          { line: row.lineNumber, rule: "req-to-task-row-empty" },
        );
      }
      for (const reqId of reqIds) {
        if (!REQ_ID_PATTERN.test(reqId)) {
          return err(
            "cannot-parse",
            `REQ -> Task table row has a malformed REQ-ID: ${reqId}`,
            { line: row.lineNumber, rule: "req-to-task-row-req-id-shape" },
          );
        }
        rows.push({ reqId, taskIds });
      }
    }
  }
  return ok(rows);
}

/** Extracts AC -> REQ rows from every table shaped like `AC-ID | REQ-ID [| ...]` without a TEST-ID column. */
function extractAcToReq(tables: RawTable[]): Result<AcToReqRow[]> {
  const rows: AcToReqRow[] = [];
  for (const table of tables) {
    if (!hasColumn(table.columns, "AC-ID") || !hasColumn(table.columns, "REQ-ID")) {
      continue;
    }
    if (hasColumn(table.columns, "TEST-ID")) {
      continue;
    }
    const acIdIdx = columnIndex(table.columns, "AC-ID");
    const reqIdIdx = columnIndex(table.columns, "REQ-ID");
    for (const row of table.rows) {
      const acIdCell = row.cells[acIdIdx];
      const reqIdCell = row.cells[reqIdIdx];
      if (acIdCell === undefined || reqIdCell === undefined) {
        return err(
          "cannot-parse",
          "AC -> REQ table row is missing a required column.",
          { line: row.lineNumber, rule: "ac-to-req-row-shape" },
        );
      }
      const acId = acIdCell.trim();
      const reqIds = splitIdList(reqIdCell);
      if (acId.length === 0 || reqIds.length === 0) {
        return err(
          "cannot-parse",
          "AC -> REQ table row has an empty AC-ID or REQ-ID cell.",
          { line: row.lineNumber, rule: "ac-to-req-row-empty" },
        );
      }
      if (!AC_ID_PATTERN.test(acId)) {
        return err(
          "cannot-parse",
          `AC -> REQ table row has a malformed AC-ID: ${acId}`,
          { line: row.lineNumber, rule: "ac-to-req-row-ac-id-shape" },
        );
      }
      for (const reqId of reqIds) {
        if (!REQ_ID_PATTERN.test(reqId)) {
          return err(
            "cannot-parse",
            `AC -> REQ table row has a malformed REQ-ID: ${reqId}`,
            { line: row.lineNumber, rule: "ac-to-req-row-req-id-shape" },
          );
        }
      }
      rows.push({ acId, reqIds });
    }
  }
  return ok(rows);
}

/** Extracts AC -> TEST -> Task rows from every table with AC-ID, TEST-ID, and Task-ID columns. */
function extractAcToTestToTask(tables: RawTable[]): Result<AcToTestToTaskRow[]> {
  const rows: AcToTestToTaskRow[] = [];
  for (const table of tables) {
    if (
      !hasColumn(table.columns, "AC-ID") ||
      !hasColumn(table.columns, "TEST-ID") ||
      !hasColumn(table.columns, "Task-ID")
    ) {
      continue;
    }
    const acIdIdx = columnIndex(table.columns, "AC-ID");
    const testIdIdx = columnIndex(table.columns, "TEST-ID");
    const taskIdIdx = columnIndex(table.columns, "Task-ID");
    const targetIdx = columnIndex(table.columns, "Test Target");
    for (const row of table.rows) {
      const acIdCell = row.cells[acIdIdx];
      const testIdCell = row.cells[testIdIdx];
      const taskIdCell = row.cells[taskIdIdx];
      if (acIdCell === undefined || testIdCell === undefined || taskIdCell === undefined) {
        return err(
          "cannot-parse",
          "AC -> TEST -> Task table row is missing a required column.",
          { line: row.lineNumber, rule: "ac-to-test-to-task-row-shape" },
        );
      }
      const acId = acIdCell.trim();
      const testId = testIdCell.trim();
      const taskIds = splitIdList(taskIdCell);
      if (acId.length === 0 || testId.length === 0 || taskIds.length === 0) {
        return err(
          "cannot-parse",
          "AC -> TEST -> Task table row has an empty AC-ID, TEST-ID, or Task-ID cell.",
          { line: row.lineNumber, rule: "ac-to-test-to-task-row-empty" },
        );
      }
      if (!AC_ID_PATTERN.test(acId)) {
        return err(
          "cannot-parse",
          `AC -> TEST -> Task table row has a malformed AC-ID: ${acId}`,
          { line: row.lineNumber, rule: "ac-to-test-to-task-row-ac-id-shape" },
        );
      }
      if (!TEST_ID_PATTERN.test(testId)) {
        return err(
          "cannot-parse",
          `AC -> TEST -> Task table row has a malformed TEST-ID: ${testId}`,
          { line: row.lineNumber, rule: "ac-to-test-to-task-row-test-id-shape" },
        );
      }
      const row_: AcToTestToTaskRow = { acId, testId, taskIds };
      const targetCell = targetIdx !== -1 ? row.cells[targetIdx] : undefined;
      if (targetCell !== undefined && targetCell.length > 0) {
        row_.target = targetCell;
      }
      rows.push(row_);
    }
  }
  return ok(rows);
}

/**
 * Reads and parses `specs/<feature>/traceability.md`, extracting REQ -> Task,
 * AC -> REQ, and AC -> TEST -> Task tables (identified by header column
 * names, not section heading text — see module doc).
 *
 * Failure modes:
 * - the path-guard read itself fails (propagated unchanged, e.g. `not-found`);
 * - a matched table's data row is missing a column present in its header, or
 *   has an empty/malformed ID cell where an ID is expected -> `cannot-parse`
 *   with the offending row's 1-based line number.
 *
 * A traceability.md with no tables of a given shape at all (e.g. no
 * AC -> TEST -> Task table) is not an error — that shape's array is simply
 * empty.
 */
export function parseTraceability(root: SddRoot, feature: string): Result<TraceabilityData> {
  const relPath = traceabilityRelPath(feature);
  const fileResult = guardedRead(root, relPath);
  if (!fileResult.ok) {
    return fileResult;
  }

  const lines = splitLines(fileResult.data.contents);
  const tables = findTables(lines);

  const reqToTaskResult = extractReqToTask(tables);
  if (!reqToTaskResult.ok) {
    return err(reqToTaskResult.error.code, reqToTaskResult.error.message, {
      ...reqToTaskResult.error.details,
      file: relPath,
    });
  }

  const acToReqResult = extractAcToReq(tables);
  if (!acToReqResult.ok) {
    return err(acToReqResult.error.code, acToReqResult.error.message, {
      ...acToReqResult.error.details,
      file: relPath,
    });
  }

  const acToTestToTaskResult = extractAcToTestToTask(tables);
  if (!acToTestToTaskResult.ok) {
    return err(acToTestToTaskResult.error.code, acToTestToTaskResult.error.message, {
      ...acToTestToTaskResult.error.details,
      file: relPath,
    });
  }

  return ok({
    reqToTask: reqToTaskResult.data,
    acToReq: acToReqResult.data,
    acToTestToTask: acToTestToTaskResult.data,
  });
}
