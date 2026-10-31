## High-risk Preflight

Persisted before candidate edits; negative executions were NOT RUN: the intact baseline exposed a missing required input before implementation. No preflight-mismatch.json was created.

| Persisted field / claim | Counterpart | Failing mismatch test |
|---|---|---|
| Protected six entrypoints / TEST-011a-f | canonical inventory and native guard decisions | Remove one entry from a disposable projection, then require write denial and read allowance; protected-write assertion must fail specifically, not fixture setup |
| Canonical membership / TEST-012a | generator BASELINE_SUFFIXES union | Append canonical-only entry; --check must exit 1 with exact-union diagnostic |
| Generator membership / TEST-012b | canonical protected_gate_suffixes | Append generator-only entry; --check must exit 1 with exact-union diagnostic |
| Four projection hashes / TEST-012c | generator expected_outputs | Mutate each projection separately; --check must exit 1 naming that stale projection |
| Unrelated membership and keys / TEST-012d | admitted before bytes, eight existing additions | Mutated unrelated membership must fail equality/hash assertions; final six production inventory files must retain admitted hashes |
| CI transport registration / TEST-013 | actual admitted .github/workflows/test.yml executable run line | Remove quality-nontty-transport command in disposable copy; registration assertion must fail while generator --check still succeeds |
| Run/session/agent/task/attempt/isolation | manifest and launch instruction | Alter identity in a disposable record; exact equality assertion fails |
| spec_revision, input/source/test/output SHA-256 | admitted bytes, manifest and actual output files | Alter a digest; recomputed digest equality assertion fails |
| Command/cwd/exit/stdout/stderr and TEST mapping | captured subprocess results and acceptance-tests.md | Wrong expected exit fails result assertion; TEST mapping covers 011a-f, 012a-d, 013 |

Registration already exists. All RED in this attempt is explicitly isolated mutation RED, not original production RED. RT-20261009-001 T001-only exception is not used. Status transitions, independent review and formal quality gate remain parent-owned.
