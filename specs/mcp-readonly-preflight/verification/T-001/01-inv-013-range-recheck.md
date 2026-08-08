# T-001 — INV-013 fresh range re-verification (before edit)

Per `tasks.md` T-001 Done-When item 1 and INV-013: the insertion point is
re-verified fresh against the *current* `bootstrap/SKILL.md` and the
*current* `tests/workflow-documentation.tests.sh:65-68` `sed` range at
implementation start, not assumed from `tasks.md`'s own line numbers.

Run before any edit to `bootstrap/SKILL.md` in this session.

```
$ grep -n '^## Preconditions$\|^## Routing$' plugins/sdd-bootstrap/skills/bootstrap/SKILL.md
54:## Preconditions
66:## Routing

$ grep -n "sed -n" tests/workflow-documentation.tests.sh
34:  section="$(sed -n "/^### ${start} /,/^### ${end} /p" "$workflow_guide")"
66:run_full="$(sed -n '/^### `feature` .*full track)/,/^### Lite track/p' "$run_skill")"

$ grep -n '^### `feature`\|^### Lite track' plugins/sdd-bootstrap/skills/bootstrap/SKILL.md
88:### `feature` / `bugfix` / `refactor` / `project` modes (full track)
124:### Lite track (`--lite` or `spec_profile: lite`)
```

## Conclusion

- `## Preconditions` starts at line 54; its body ends at line 64; line 65 is
  a blank separator line; `## Routing` starts at line 66.
- `tests/workflow-documentation.tests.sh:66` extracts the inclusive range
  bounded by the literal headings ``### `feature` / `bugfix` / `refactor` /
  `project` modes (full track)`` (line 88) and ```### Lite track``` (line
  124) — both strictly inside `## Routing`'s body.
- The planned insertion point (a new `##`-level section placed between the
  blank line 65 and the `## Routing` heading at line 66) is therefore
  confirmed, **today, freshly**, to sit entirely outside lines 88-124. It
  cannot be captured by the `sed -n '/^### `feature`.../,/^### Lite
  track/p'` extraction regardless of how many lines the new section adds,
  because the new section's own content contains no `###`-level heading
  matching either bound, and it is inserted strictly before line 88's
  heading exists in the file (all subsequent headings, including 88 and
  124, shift downward by the same fixed offset, preserving their relative
  order and the range's `### `feature`... / ### Lite track` boundary
  markers verbatim).
- This matches `tasks.md`'s own citation (`:60-70`) exactly — no drift was
  found. No re-derivation of the insertion point was necessary.
