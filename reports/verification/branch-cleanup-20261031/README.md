# Integrated branch cleanup

Deleted the three remote branches recorded in `deleted-refs.json` after checking
each exact tip was an ancestor of main e105d955, had no open PR using it as head
or base, and had no active worktree. The remote deletion succeeded. Their commits
remain reachable from main. Active integration, evidence and release branches
are retained. This adds three deletions to the previously recorded 35.
