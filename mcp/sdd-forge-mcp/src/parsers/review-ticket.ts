/**
 * Review ticket parser — reads `docs/review-tickets/RT-*.yml` files and
 * converts them into the `reviewTicketsData` entry shape from
 * `contracts/sdd-forge-mcp-tools.v1.schema.json` (ticketId, status, severity,
 * type, feature, task, summary, file).
 *
 * Design.md "Data Plan": `docs/review-tickets/RT-*.yml` -> review-ticket.ts.
 * `ticket_id` must match `^RT-[0-9]{8}-[0-9]{3}$` (the contract's pattern);
 * YAML parse failures and missing required fields (`ticket_id`, `status`,
 * `severity`) are reported as `cannot-parse` with the offending file (and
 * line, when js-yaml supplies one) rather than guessed at.
 */

import { load, YAMLException } from "js-yaml";
import { err, ok, type ErrorInfo, type Result } from "../envelope.js";
import { guardedRead, listGuardedFiles } from "../path-guard.js";
import type { SddRoot } from "../root.js";

const REVIEW_TICKETS_DIR = "docs/review-tickets";
const TICKET_ID_PATTERN = /^RT-[0-9]{8}-[0-9]{3}$/;

/** `reviewTicketsData.tickets[]` entry shape (contracts v1). */
export interface ReviewTicketEntry {
  ticketId: string;
  status: string;
  severity: string;
  type?: string;
  feature?: string;
  task?: string;
  summary?: string;
  file: string;
}

interface RawReviewTicketTarget {
  feature?: unknown;
  task?: unknown;
}

interface RawReviewTicket {
  ticket_id?: unknown;
  status?: unknown;
  severity?: unknown;
  type?: unknown;
  summary?: unknown;
  target?: RawReviewTicketTarget;
}

/** Returns `value` if it is a non-empty string, else `undefined`. */
function asNonEmptyString(value: unknown): string | undefined {
  return typeof value === "string" && value.length > 0 ? value : undefined;
}

/**
 * Parses a single `docs/review-tickets/RT-*.yml` file into a
 * `ReviewTicketEntry`.
 *
 * Failure modes (all `cannot-parse`, all carrying `file` and, where
 * available, `line`):
 * - the path-guard read itself fails (propagated unchanged, e.g. `not-found`);
 * - the YAML does not parse (js-yaml `YAMLException`, `line` from its mark);
 * - the document is not a mapping, or is missing `ticket_id`, `status`, or
 *   `severity`;
 * - `ticket_id` does not match `^RT-[0-9]{8}-[0-9]{3}$`.
 */
export function parseReviewTicket(root: SddRoot, relFilePath: string): Result<ReviewTicketEntry> {
  const fileResult = guardedRead(root, relFilePath);
  if (!fileResult.ok) {
    return fileResult;
  }

  let parsed: unknown;
  try {
    parsed = load(fileResult.data.contents);
  } catch (error) {
    const line = error instanceof YAMLException ? error.mark?.line : undefined;
    return err("cannot-parse", `Review ticket is not valid YAML: ${relFilePath}`, {
      file: relFilePath,
      ...(line !== undefined ? { line: line + 1 } : {}),
      rule: "yaml-syntax",
    });
  }

  if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) {
    return err("cannot-parse", `Review ticket is not a YAML mapping: ${relFilePath}`, {
      file: relFilePath,
      rule: "not-a-mapping",
    });
  }

  const raw = parsed as RawReviewTicket;
  const ticketId = asNonEmptyString(raw.ticket_id);
  const status = asNonEmptyString(raw.status);
  const severity = asNonEmptyString(raw.severity);

  const missing: string[] = [];
  if (ticketId === undefined) missing.push("ticket_id");
  if (status === undefined) missing.push("status");
  if (severity === undefined) missing.push("severity");
  if (ticketId === undefined || status === undefined || severity === undefined) {
    return err(
      "cannot-parse",
      `Review ticket is missing required field(s): ${missing.join(", ")} (${relFilePath})`,
      { file: relFilePath, rule: "missing-required-field" },
    );
  }

  if (!TICKET_ID_PATTERN.test(ticketId)) {
    return err(
      "cannot-parse",
      `Review ticket ticket_id does not match RT-YYYYMMDD-NNN: ${ticketId} (${relFilePath})`,
      { file: relFilePath, rule: "ticket-id-shape" },
    );
  }

  const entry: ReviewTicketEntry = {
    ticketId,
    status,
    severity,
    file: relFilePath,
  };
  const type = asNonEmptyString(raw.type);
  if (type !== undefined) entry.type = type;
  const feature = asNonEmptyString(raw.target?.feature);
  if (feature !== undefined) entry.feature = feature;
  const task = asNonEmptyString(raw.target?.task);
  if (task !== undefined) entry.task = task;
  const summary = asNonEmptyString(raw.summary);
  if (summary !== undefined) entry.summary = summary;

  return ok(entry);
}

/** One review ticket file that failed to parse, alongside its error. */
export interface ReviewTicketFailure {
  file: string;
  error: ErrorInfo;
}

/** Aggregate result of scanning every `RT-*.yml` file under a directory. */
export interface ReviewTicketsScan {
  tickets: ReviewTicketEntry[];
  failures: ReviewTicketFailure[];
}

/**
 * Walks `relDir` (default `docs/review-tickets`) via `listGuardedFiles`,
 * parses every `RT-*.yml` file found (non-`.yml` files, e.g. `.gitkeep`, are
 * ignored), and returns the successfully parsed entries alongside any
 * per-file parse failures. Never throws and never guesses a value for a
 * file that failed to parse — that file's failure is reported instead of
 * being silently dropped.
 */
export function listReviewTickets(
  root: SddRoot,
  relDir: string = REVIEW_TICKETS_DIR,
): ReviewTicketsScan {
  const tickets: ReviewTicketEntry[] = [];
  const failures: ReviewTicketFailure[] = [];

  for (const relFilePath of listGuardedFiles(root, relDir)) {
    if (!relFilePath.endsWith(".yml") && !relFilePath.endsWith(".yaml")) {
      continue;
    }
    const result = parseReviewTicket(root, relFilePath);
    if (result.ok) {
      tickets.push(result.data);
    } else {
      failures.push({ file: relFilePath, error: result.error });
    }
  }

  return { tickets, failures };
}
