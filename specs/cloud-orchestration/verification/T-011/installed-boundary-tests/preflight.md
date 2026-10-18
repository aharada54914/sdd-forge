# T-011 Attempt 3 preflight — before regression edits

Scope: RT-20261018-CLOUD-BOOTSTRAP-PATH-TESTS only. Existing checks are correct;
this repair changes tests, not production. Initial bytes and input manifest were
captured before writing the sensitivity harness or changing the selected suite.

| Persisted field / claim | Counterpart | Executable mismatch check |
|---|---|---|
| Installed root admission, exact exit 2, schema/error_code/field | cloud-routing.py run(), cloud-input-error.schema.json; AC-011/012 | sensitivity.py: physical-path-policy mutant removes both overlapping physical guards; selected suite must kill it through a no-delegation assertion |
| CLI and all four shared modules: regular physical files before delegation | cloud-routing.py runtime loop; installed provider runtime | sensitivity.py: runtime-presence mutant retains physical checks but removes is_file; selected suite must kill it before subprocess execution |
| No delegation, unchanged request bytes, no output/evidence | same complete arguments and matched installed route controls, approved no-write boundary | new installed cases spy at actual installed helper subprocess.run (positive control must call once); missing/linked files must never reach spy; exact bytes and workspace inventory unchanged |
| Model/run/session/agent/tier/cost/isolation and input hashes | launcher-supplied identity, manifest schema and preserved initial snapshot | preflight-mismatches.log: mutate task_id, isolation and input hash independently; existing validator must reject each |
| Output SHA-256, spec_revision, reported test exits/counts | actual files, eight raw spec files, actual unittest and verification receipt | sensitivity.py asserts control succeeds, zero errors (no setup/import Red), every mutant has semantic assertion failures; final output hash checker independently compares each row; rollback restores initial test bytes and reproduces sensitivity failure |

Physical guards overlap: removing the early root check alone can still reject
relative or symlinked roots via runtime resolve()!=path. Only the bounded semantic
mutant removing BOTH physical checks measures lost physical-path policy. Presence
and physical policy are independent variants. Missing/non-directory roots remain
rejected by manifest I/O; no invented special root guard or synthetic expected kill.

Before adding cases: run unmodified BootstrapInstalled against production and both
mutants; preserve the real caller assertion failure, and commit the harness plus
baseline. This is coverage Red, not pre-production-implementation Red. After cases:
unchanged production passes; each mutant must fail at intended delegation boundary,
not source absence, import, setup or command-argument failure. No model relaunch,
cloud operation, task status change, ticket closure or independent verdict.

Reuse installer fixture and stdlib importlib/contextlib/unittest.mock. Symlink
creation failures are explicit per-case skips; Linux evidence is not native Windows
or macOS proof. Rollback changes only tests in a disposable checkout. Existing
native2, prior all-six and guard results are not rerun or relabeled as this attempt.
