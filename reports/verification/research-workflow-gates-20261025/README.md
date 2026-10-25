# Research workflow gate integration checkpoint

Actual Bash and PowerShell checks now activate research-only manifests, accept canonical relocated research inputs and separately bound research ADRs, and require each reviewer to pin the full research closure. Legacy manifests without research do not acquire a dependency on later research packets. Design-declared ADR pins still require canonical relative paths and exact hashes.

- `workflow.txt`: 18 integration tests, including real impl/task prechecks, missing closure members, actual reviewer omission, modified/missing packet, relocated ADR, and legacy records without the design ADR extension.
- `conditional-resolver.txt`: 18 tests. `research-owners.txt`: 7 tests.
- `loops.txt`: 34 passed. The interviewer research section moved after the existing full-profile block; the original anchor digest and ordinal were preserved.
- `adr-regression.txt`: existing ADR history, lexical/path boundaries and downstream regression cases; final downstream segment 32 passed, zero failed/inconclusive. This longer suite overlapped development edits and is corroborative, not an immutable-source receipt.
- `mirrors.txt`: 6 passed, 49 informational pending historical candidates; frozen staged records unchanged.
- `*-red.txt`: reproduced failures before their fixes. These failures are retained as evidence, not current passing results.

`inputs.json` records this checkpoint's source hashes. These local results are not a reusable full-suite PASS or final hosted CI result. Hosted run 40196921354 exposed the interviewer anchor drift fixed here; it did not test this checkpoint.

Independent security review additionally reproduced a remaining NEEDS_WORK recovery defect: after a legitimate design repair, changing only a valid research packet's bytes prevents opening the next round because historical review pins are compared with live inputs. This checkpoint does not claim #609 complete. The follow-up must validate saved failed-review identity and pins without giving them current-input authority, then independently validate fresh inputs for the new review.
