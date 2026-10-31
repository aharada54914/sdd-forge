/**
 * Shared spec-artifact header extraction, used by both `get_spec_status`
 * (tools/core.ts) and the next-command mapping (next-command.ts) so the two
 * never drift on how a `<Key>: <value>` review-status header is located.
 */

/**
 * Extracts a `<Key>: <value>` header line's value from the leading metadata
 * block of a spec artifact: everything after the title line (line 1) and
 * before the first second-level-or-deeper markdown header (`## ...`).
 * Spec artifacts in this repository vary in whether a blank line separates
 * the title from the metadata lines (e.g. requirements.md has one, design.md
 * does not), so blank lines within this block are skipped rather than
 * treated as a terminator.
 */
export function extractHeaderValue(contents: string, key: string): string | undefined {
  const lines = contents.split("\n");
  const pattern = new RegExp(`^${key}:\\s*(.+?)\\s*$`);
  for (let i = 1; i < lines.length; i += 1) {
    const line = lines[i];
    if (line === undefined) {
      break;
    }
    if (/^#{1,6}\s/.test(line)) {
      break;
    }
    if (line.trim().length === 0) {
      continue;
    }
    const match = pattern.exec(line);
    if (match?.[1] !== undefined) {
      return match[1];
    }
  }
  return undefined;
}
