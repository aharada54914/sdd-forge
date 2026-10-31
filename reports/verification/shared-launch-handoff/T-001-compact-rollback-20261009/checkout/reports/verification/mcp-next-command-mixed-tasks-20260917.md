# MCP Next-Command Routing for Mixed Task States Verification Report

- Date: 2026-09-17
- Branch: `codex/t002-failure-diagnostics`
- Target Issue / Defect: PR #400 CI failure on `mcp-tests` across all 3 operating systems (`unexpected phase for live repo: cannot-determine`)
- Worktree: `/Users/jrmag/sdd-forge`

## 1. Problem Diagnosis

When `specs/<feature>/tasks.md` contains Approved tasks that are in a mix of `Implementation Complete` and `Done` states with none `Planned`, `In Progress`, or `Blocked` (as is the case for `specs/sdd-forge-mcp/tasks.md` where T-002 is `Implementation Complete` and T-001/T-003..T-011 are `Done`), `getNextSddCommand` previously fell through lines 96-125 of `mcp/sdd-forge-mcp/src/next-command.ts` to return `cannot-determine`.

Per SDD workflow (`plugins/sdd-ship/skills/ship/SKILL.md` Step 4 Quality Gate Loop lines 294-332 and AGENTS.md Step 7), when all active tasks have finished implementation and one or more tasks are at `Implementation Complete`, the required next action is to run the quality gate for the first `Implementation Complete` task in document order.

## 2. Changes Implemented

1. **Production Code (`mcp/sdd-forge-mcp/src/next-command.ts`)**:
   - Updated `phaseFromTasks` to check for tasks with status `Implementation Complete`.
   - When present, resolves phase to `"quality-gate"`.
   - When all approved tasks are `Implementation Complete`, targets `/sdd-quality-loop:quality-gate specs/${feature}/tasks.md`.
   - When a mix of `Done` and `Implementation Complete` tasks exists, targets the first `Implementation Complete` task in document order: `/sdd-quality-loop:quality-gate specs/${feature}/tasks.md#${firstImplComplete.id}`.

2. **Regression Test (`mcp/sdd-forge-mcp/tests/next-command/next-command.test.ts`)**:
   - Added synthetic test `"quality-gate: mixed Done and Implementation Complete tasks target the first Implementation Complete task in document order"`.
   - Verifies that a feature containing T-001 (Done), T-002 (Implementation Complete), and T-003 (Implementation Complete) routes to `phase: "quality-gate"` with `nextCommand: "/sdd-quality-loop:quality-gate specs/feat-quality-gate-mixed/tasks.md#T-002"`.

3. **Built Bundle (`mcp/sdd-forge-mcp/dist/index.js`)**:
   - Re-bundled using `npm run build` (`esbuild`).

## 3. Local Verification Results

In `mcp/sdd-forge-mcp`:
- `npm run typecheck`: Passed (exit 0).
- `npm run build`: Passed (exit 0).
- `npm test`: Passed (252 passing tests, 0 failures, 0 skips, exit 0).
- Tested live repository resolution: `"real repository: feature=sdd-forge-mcp resolves to a schema-valid, non-cannot-determine phase"` passed successfully.

## 4. Unrelated State Preservation

- All dirty and untracked files across the repository were strictly preserved.
- No git commits, pushes, merges, PR creations, issue closures, or review verdict changes were performed.
