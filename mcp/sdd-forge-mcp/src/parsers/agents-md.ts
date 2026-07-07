/**
 * AGENTS.md parser — extracts the `## Active Spec Directories` list and the
 * `## Required Workflow` numbered steps.
 *
 * Canonical shapes: contracts/sdd-forge-mcp-tools.v1.schema.json
 * `activeSpecsData` (the `specs` array entries' `feature` + `path`), plus
 * design.md "Data Plan" (`AGENTS.md ## Active Spec Directories` ->
 * agents-md.ts). `get_next_sdd_command`'s phase mapping (T-010) consumes the
 * `Required Workflow` step text later; this module only extracts it.
 *
 * Never fabricates a value: a missing section is `cannot-determine` (the
 * information the caller asked for does not exist in this document, as
 * opposed to existing but being unparsable), and a malformed section is
 * `cannot-parse` with a line number.
 */

import { err, ok, type Result } from "../envelope.js";
import { guardedRead } from "../path-guard.js";
import type { SddRoot } from "../root.js";

const AGENTS_MD_PATH = "AGENTS.md";

const ACTIVE_SPEC_DIRECTORIES_HEADER = "## Active Spec Directories";
const REQUIRED_WORKFLOW_HEADER = "## Required Workflow";

/** One entry parsed from the `## Active Spec Directories` bullet list. */
export interface ActiveSpecDirectory {
  feature: string;
  path: string;
}

/** A single numbered step extracted from the `## Required Workflow` section. */
export interface RequiredWorkflowStep {
  step: number;
  text: string;
}

/**
 * Splits file contents into lines the same way the tasks.md parser does: a
 * trailing newline does not produce a spurious empty final line, and a
 * trailing CR is stripped so CRLF-encoded AGENTS.md parses identically.
 */
function splitLines(contents: string): string[] {
  const normalized = contents.endsWith("\n") ? contents.slice(0, -1) : contents;
  if (normalized.length === 0) {
    return [];
  }
  return normalized.split("\n").map((line) => (line.endsWith("\r") ? line.slice(0, -1) : line));
}

/** True for any second-level-or-shallower markdown header line (`#`, `##`, ...). */
function isAnyHeaderLine(line: string): boolean {
  return /^#{1,6}\s/.test(line);
}

/**
 * Returns the lines strictly between a `## <headerText>` line and the next
 * header line of any level (or end of file), or `undefined` if the header is
 * not present at all.
 */
function extractSection(
  lines: string[],
  headerText: string,
): { sectionLines: string[]; headerLineNumber: number } | undefined {
  const headerIndex = lines.findIndex((line) => line.trim() === headerText);
  if (headerIndex === -1) {
    return undefined;
  }
  const sectionLines: string[] = [];
  for (let i = headerIndex + 1; i < lines.length; i += 1) {
    const line = lines[i];
    if (line === undefined) {
      break;
    }
    if (isAnyHeaderLine(line)) {
      break;
    }
    sectionLines.push(line);
  }
  return { sectionLines, headerLineNumber: headerIndex + 1 };
}

/** Matches a bullet line like `` - `specs/<feature>/` `` (feature name only, trailing slash required). */
const SPEC_BULLET_PATTERN = /^- `specs\/([^`/]+)\/`$/;

/**
 * Parses the `## Active Spec Directories` section of AGENTS.md into a list of
 * `{ feature, path }` entries.
 *
 * - Section absent entirely -> `cannot-determine` (nothing to report, as
 *   opposed to a malformed report).
 * - Section present but a non-blank, non-bullet, non-comment line does not
 *   match the expected `` - `specs/<feature>/` `` shape -> `cannot-parse`
 *   with the offending line number.
 */
export function parseActiveSpecDirectories(root: SddRoot): Result<ActiveSpecDirectory[]> {
  const fileResult = guardedRead(root, AGENTS_MD_PATH);
  if (!fileResult.ok) {
    return fileResult;
  }

  const lines = splitLines(fileResult.data.contents);
  const section = extractSection(lines, ACTIVE_SPEC_DIRECTORIES_HEADER);
  if (section === undefined) {
    return err(
      "cannot-determine",
      `AGENTS.md has no "${ACTIVE_SPEC_DIRECTORIES_HEADER}" section.`,
      { file: AGENTS_MD_PATH, rule: "active-spec-directories-section-missing" },
    );
  }

  const specs: ActiveSpecDirectory[] = [];
  for (let i = 0; i < section.sectionLines.length; i += 1) {
    const line = section.sectionLines[i];
    if (line === undefined) {
      continue;
    }
    const trimmed = line.trim();
    if (trimmed.length === 0) {
      continue;
    }
    // Free-text lead-in sentences (e.g. "Update this list whenever...") are
    // allowed before the bullet list; only lines that look like a bullet
    // (start with `-`) are held to the strict `specs/<feature>/` shape.
    if (!trimmed.startsWith("-")) {
      continue;
    }
    const match = SPEC_BULLET_PATTERN.exec(trimmed);
    if (match?.[1] === undefined) {
      return err(
        "cannot-parse",
        `Malformed Active Spec Directories bullet: expected "- \`specs/<feature>/\`".`,
        {
          file: AGENTS_MD_PATH,
          line: section.headerLineNumber + 1 + i,
          rule: "active-spec-directories-bullet-shape",
        },
      );
    }
    specs.push({ feature: match[1], path: `specs/${match[1]}/` });
  }

  return ok(specs);
}

/** Matches a numbered step line like `1. Use ...` at the start of a line. */
const NUMBERED_STEP_PATTERN = /^(\d+)\.\s+(.*)$/;

/**
 * Parses the `## Required Workflow` section of AGENTS.md into an ordered list
 * of numbered steps.
 *
 * - Section absent entirely -> `cannot-determine`.
 * - Section present but contains no numbered steps at all -> `cannot-parse`
 *   (a workflow section that names no steps is malformed, not merely empty).
 */
export function parseRequiredWorkflow(root: SddRoot): Result<RequiredWorkflowStep[]> {
  const fileResult = guardedRead(root, AGENTS_MD_PATH);
  if (!fileResult.ok) {
    return fileResult;
  }

  const lines = splitLines(fileResult.data.contents);
  const section = extractSection(lines, REQUIRED_WORKFLOW_HEADER);
  if (section === undefined) {
    return err(
      "cannot-determine",
      `AGENTS.md has no "${REQUIRED_WORKFLOW_HEADER}" section.`,
      { file: AGENTS_MD_PATH, rule: "required-workflow-section-missing" },
    );
  }

  const steps: RequiredWorkflowStep[] = [];
  for (const line of section.sectionLines) {
    const trimmed = line.trim();
    if (trimmed.length === 0) {
      continue;
    }
    const match = NUMBERED_STEP_PATTERN.exec(trimmed);
    if (match?.[1] !== undefined && match[2] !== undefined) {
      steps.push({ step: Number.parseInt(match[1], 10), text: match[2] });
    }
  }

  if (steps.length === 0) {
    return err(
      "cannot-parse",
      `"${REQUIRED_WORKFLOW_HEADER}" section contains no numbered steps.`,
      {
        file: AGENTS_MD_PATH,
        line: section.headerLineNumber,
        rule: "required-workflow-no-steps",
      },
    );
  }

  return ok(steps);
}
