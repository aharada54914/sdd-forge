/**
 * Shared (non-test) helper for the parser test suite. Deliberately not named
 * `*.test.ts` so `node --test`'s glob never picks it up as a test file in its
 * own right — importing a `.test.ts` file from another `.test.ts` file would
 * re-register that file's top-level `test()` calls a second time.
 */

import type { TaskFailure } from "../../src/parsers/tasks.js";

export function findFailure(failures: TaskFailure[], rule: string): TaskFailure | undefined {
  return failures.find((f) => f.rule === rule);
}
