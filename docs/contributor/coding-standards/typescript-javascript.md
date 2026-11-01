# TypeScript / JavaScript

Apply [common rules](common.md), especially CS-001, CS-003, CS-004, CS-006, CS-008, CS-018, CS-021, CS-022, CS-023.

Preserve strict and noUncheckedIndexedAccess, build/typecheck/test entrypoints. Decode external values with the existing runtime parser before narrowing unknown; an assertion cannot validate JSON. Await promises and own rejection/cancellation; async forEach does not await work. Use bounded parallelism only for independent effects. Prefer textContent and URL APIs. Node spawn arguments do not validate executable paths, option injection or Windows shell wrappers.

For each affected boundary, keep a hostile input, ordinary input and relevant platform control. Intentional negative fixtures remain classified and reviewed; blanket test-directory exclusions are not valid. Executed commands, versions, scope and not-run results belong in the audit evidence, not in an assumed tool capability claim.
