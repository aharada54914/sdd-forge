# T002 cycle2 fix: persisted field/counterpart preflight

Actor: work-agent:root:t002_implementation. Local protocol fixtures only; fake gh subprocess + real ZIP + actual aggregate subprocess, no hosted proof. Production unchanged before this preflight and Red.

Input manifest: `specs/ci-model-modernization/verification/T-002/cycle2-fix/task-input-manifest.dependencies.json`, SHA-256 `306ca1193719f03deaabe694f264fffe83b777e2f3943be8feca79da4cc6e831`

The original 90 snapshot bytes and the appended RT013 ticket (91 inputs) were verified independently by SHA-256. Before bytes are retained in the dedicated scratch `before/`, with original source pins in before-state.json. HEAD is not the current baseline.

| Persisted field/boundary | Independent counterpart / positive | Failing mismatch / intended result |
|---|---|---|
| Receipt results[].seconds | Real runner receipt with all revision, source, job, native, step, suite, partition bindings retained; 0, 0.25, 1e308 and finite integer 10**400 are accepted | -(10**400), negative float and bool are typed aggregate FAIL/1; huge positive currently leaks OverflowError rather than PASS |
| Nonfinite receipt seconds raw JSON | Same hash-bound receipt with only numeric token changed; recomputed manifest digest | NaN, Infinity, -Infinity and 1e999 rejected by shared codec, aggregate FAIL/1 without traceback |
| Supported ZIP_LZMA archive | Real supported LZMA receipt ZIP, full collector-to-aggregate PASS | Corrupt LZMA filter-property byte inside valid container must give typed collector error/2 and no collection manifest; currently LZMAError leaks; existing DEFLATE guard retained |
| Raw run/jobs API JSON | Existing valid collector/aggregate control with fake read-only gh transport | Actual 10000-deep JSON run and jobs API responses must produce typed collector error/2; uses passed T001 codec without reimplementation |
| Hash-bound raw run/jobs observations | Recompute exact raw-byte manifest hash, isolating parser boundary | Deep JSON observations produce aggregate FAIL/1; deep mandatory collection produces typed input error/2; no success artifact |
| Explicit aggregate root/observations Path.resolve | Ordinary paths plus supported nonloop symlink directories complete aggregate PASS | Actual self-symlink RuntimeError from both args must normalize at only this resolution boundary to typed error/2, no traceback/output; root classified RT013 |

Initial observations-loop probe used a nonexistent plan and short-circuited on plan reading; it is preserved and receives no defect-detection credit. A subsequent actual probe with readable plan reproduced RuntimeError. Final tests use the complete valid plan and observations. No source change is authorized until root commits actual Red tests. Proposed fixes are narrow integer/float discrimination, specific LZMA decoder exception normalization at archive extraction, and explicit CLI path resolution normalization. No schema, field, limit, auth, workflow, lineage, A9, or other task change.
