# Fixed plugin native lite workflow — 2026-11-07

**PASS: T-001 Done through independent native lite-gate.** This fresh project used updated installed sdd-forge skills, actual native Codex sessions and active hooks. Original English scope exclusions and historical workflow-only approval sentence remained unchanged: no wording workaround. User explicitly allowed disposable test approval and design adoption fixtures; ordinary human approval is not claimed.

The actual parent-generated ImageGen desktop/mobile reference was read with view_image and adopted through custom design tokens/patterns, then used to implement the Japanese task board. Provider: ImageGen, one-way reference; no Claude connection. See design-reference/task-board.png, design-system/, specs/task-board/design.md and reports/visual-evidence/task-board/.

Actual Chromium UI coverage at 1280px desktop and 390px mobile: empty validation, literal titles, Enter add, keyboard toggle/focus, complete/reopen/delete reload persistence, long-title overflow, no runtime errors; malformed JSON/wrong schema/duplicate IDs; storage read/write/both failures with visible warnings and session usability. Independent reviewer reran all eight scenario groups and inspected fresh desktop/mobile screenshots against the reference.

Final quality report: reports/quality-gate/T-001.md. Exact independent command execution and final task-state exit 0: evidence/independent-review/. Lint/typecheck/build scripts are syntax checks only; no semantic type-analysis or bundling claim.

## Fixed defects exercised

- #727: complete unchanged English source and complete selected task + requirements both returned lite-eligible; no translation or deletion to avoid risk detection. Actual source risk requirements remain enforced by the checker and bounded negative controls.
- #725: quoted native canary evidence saved successfully. A further approval-denial quote branch initially failed, was corrected in the source/helper, independently security-reviewed, then verified natively with a standalone `python3 -I -` quoted writer. Historical refusal bytes were preserved, fresh canary yielded HOOK_ACTIVE, final Done-state check passed, and task hashes before/after matched. See evidence/independent-review/post-fix-confirmation.json and post-fix-supplement.md.
- Security review found and closed non-isolated Python transitive module shadowing and exported-function environment hazards. Thirteen independent controls and all four native guard runtime tests passed; see evidence/security-review.json and security-review.md.

## Sessions and use

Implementer: 01a1b5a1-cb54-73b3-a005-19cfca210a83.
Independent reviewer: 01a1b5a8-f116-7033-ba7d-ab86a3c8894d.
Native invocations used the verify-codex profile with explicit project cwd and danger-full-access on each exec/resume while retaining plugin hook enforcement. Full transcripts are evidence/cli-*.jsonl.

Run `npm run dev` from this directory to serve localhost:4173. The automated suite `npm test` expects that server and uses the installed Chromium. No deployment, commit or push was performed by these app sessions. Servers were stopped by the independent reviewer.
