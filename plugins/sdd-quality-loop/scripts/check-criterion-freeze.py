#!/usr/bin/env python3
"""WFI-045: refuse a commit that edits frozen criterion prose alongside code.

A reviewed tasks.md (Task-Review-Status: Passed) carries two kinds of content:
lifecycle fields the implementation legitimately writes (Status, Approval,
Task-Review-Status, Second Approval, Done-When checkboxes) and criterion prose
that the task review froze. An implementation commit may write the former. If
it also rewrites the latter, the implementation is redefining its own success
criterion -- the RT-20260821-018 maneuver.

This check reads COMMIT COMPOSITION, not artifact bytes: a commit that touches
anything outside specs/ AND rewrites frozen criterion prose fails. Criterion
changes are legitimate; they must travel as a specs-only commit (the staged
frozen-document route) so they get reviewed on their own.

Environment: COMMIT (default HEAD), ROOT (default .).
Exit 0 = ok, 1 = criterion-prose edit in a mixed commit, 2 = usage/runtime error.
"""
import os
import re
import subprocess
import sys

COMMIT = os.environ.get("COMMIT") or "HEAD"
ROOT = os.environ.get("ROOT") or "."

TASKS_PATH = re.compile(r"^specs/[^/]+/tasks\.md$")
TASK_HEADING = re.compile(r"^## (T-[0-9]{3})\b")
FROZEN_MARK = re.compile(r"^Task-Review-Status:[ \t]*Passed[ \t]*\r?$", re.M)


def git(*args, allow_fail=False):
    proc = subprocess.run(
        ["git", "-C", ROOT] + list(args),
        capture_output=True, text=True,
    )
    if proc.returncode != 0:
        if allow_fail:
            return None
        sys.stderr.write(
            "check-criterion-freeze: git %s failed: %s\n"
            % (" ".join(args), proc.stderr.strip())
        )
        sys.exit(2)
    return proc.stdout


def normalize(text):
    """Rewrite every lifecycle field to a canonical value.

    Mirrors validate-review-context-set.sh's tasks_normalized_hash recipe
    (WFI-025) and additionally canonicalizes Done-When checkboxes, which are
    lifecycle state too. What survives normalization is criterion prose.
    """
    out = []
    for line in text.splitlines():
        stripped = line.rstrip("\r")
        if stripped.startswith("Second Approval:"):
            continue
        if stripped.startswith("Task-Review-Status:"):
            out.append("Task-Review-Status: Pending")
            continue
        if stripped.startswith("Approval:"):
            out.append("Approval: Draft")
            continue
        if stripped.startswith("Status:"):
            out.append("Status: Planned")
            continue
        out.append(re.sub(r"^(\s*)- \[[ xX]\]", r"\1- [ ]", stripped))
    return out


def split_blocks(lines):
    """Map T-NNN -> block lines. Content before the first task heading is
    collected under the empty key so preamble edits are still reported."""
    blocks = {}
    current = ""
    blocks[current] = []
    for line in lines:
        match = TASK_HEADING.match(line)
        if match:
            current = match.group(1)
            blocks.setdefault(current, [])
        blocks[current].append(line)
    return blocks


def main():
    if git("rev-parse", "--verify", "--quiet", COMMIT + "^{commit}",
           allow_fail=True) is None:
        sys.stderr.write(
            "check-criterion-freeze: not a commit: %s\n" % COMMIT)
        return 2

    # Resolve before abbreviating so an abbreviated or symbolic ref prints the
    # same 12 characters the PowerShell twin prints.
    short = (git("rev-parse", COMMIT) or COMMIT).strip()[:12]

    parents = (git("rev-list", "--parents", "-n", "1", COMMIT) or "").split()
    if len(parents) < 2:
        print("check-criterion-freeze: %s has no parent; nothing to compare"
              % short)
        return 0
    parent = parents[1]  # first parent: a merge is judged against its base

    changed = [p for p in (git("diff", "--name-only", parent, COMMIT) or
                           "").splitlines() if p]
    if not changed:
        print("check-criterion-freeze: %s changes no files" % short)
        return 0

    outside = [p for p in changed if not p.startswith("specs/")]
    if not outside:
        print("check-criterion-freeze: %s is specs-only; criterion edits are "
              "reviewable on their own" % short)
        return 0

    tasks_files = [p for p in changed if TASKS_PATH.match(p)]
    if not tasks_files:
        print("check-criterion-freeze: %s touches no reviewed tasks.md"
              % short)
        return 0

    violations = []
    for path in tasks_files:
        after = git("show", "%s:%s" % (COMMIT, path), allow_fail=True)
        before = git("show", "%s:%s" % (parent, path), allow_fail=True)
        if after is None or before is None:
            continue  # added or deleted in this commit: nothing frozen to compare
        if not FROZEN_MARK.search(after):
            continue  # not review-frozen yet

        before_blocks = split_blocks(normalize(before))
        after_blocks = split_blocks(normalize(after))
        for key in sorted(set(before_blocks) | set(after_blocks)):
            if before_blocks.get(key) != after_blocks.get(key):
                violations.append((path, key or "(file preamble)"))

    if violations:
        sys.stderr.write(
            "check-criterion-freeze: commit %s changes %d file(s) outside "
            "specs/ AND rewrites frozen criterion prose:\n"
            % (short, len(outside))
        )
        for path, key in violations:
            sys.stderr.write("  - %s: %s\n" % (path, key))
        sys.stderr.write(
            "Lifecycle edits (Status, Approval, Second Approval, "
            "Task-Review-Status, Done-When checkboxes) are permitted here; "
            "criterion prose must travel as a specs-only commit.\n"
        )
        return 1

    print("check-criterion-freeze: %s keeps frozen criterion prose intact "
          "(%d reviewed tasks.md checked)" % (short, len(tasks_files)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
