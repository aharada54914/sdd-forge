# T-011 CI dispatch correction

Run ID: work-agent:root:ci_dispatch_fix
Task Attempt Count: 1

Scope: bounded continuation of T-011 CI rollout readiness. This report does not mark T-011 Done or assert independent quality acceptance, hosted execution, model adoption or release success.

GitHub run 39597029062 at e6bc5f5a had zero jobs. actionlint 1.7.7 reproduced three forbidden `runner` context references in job-level `env` for the MCP jobs. The exact failure and before hashes are retained in preflight.json and actionlint-before.log/json. The before state passed the existing 44 catalog tests, demonstrating the missing acceptance-context check.

A real Claude Code coding invocation configured Sonnet/medium produced the narrow candidate; it completed successfully without a rate-limit rejection. This is coding assistance, not model-adoption or backend identity evidence. No raw provider envelope, account, authentication or allocation data is distributed here.

The three existing Node-runtime steps now write `npm_config_cache=$RUNNER_TEMP/npm-cache` to GITHUB_ENV before cache restore and npm commands. The invalid job-level mappings are removed. Cache paths, version/event/PR/lock keys, job/step conditions and every other step are unchanged (semantic-scope.json). No dependency or new step was added.

## Tests-first chronology

The new regression was applied before the workflow change. It failed in all three MCP job subtests. Test-only commit 61e831b5f15ae24a985f77539a6f83446d14063e precedes the product application (test-first-commit.json, product-apply.json). All existing test-method ASTs were preserved. The regression also rejects missing/mismatched/late bindings and a mismatched cache consumer path.

## Actual verification

- Catalog 45 tests PASS, zero skips, using the mandated PowerShell wrapper. Initial baseline44 with default PATH skipped its PowerShell branch; that original observation is retained, and baseline44-pwsh.log records the corrected zero-skip baseline.
- Planner 54 tests PASS; CI wiring PASS; actionlint PASS with zero diagnostics; Ruff and mypy PASS. Exact commands/exits/timestamps are in checks.json.
- Actual Bash execution of all three binding steps and `npm config get cache` PASS with a temporary path containing spaces; Node-version output is retained. This is Linux proof, not native Windows/macOS proof (runtime-binding.json).
- Disposable rollback baseline44 → candidate45 → reverted44 → restored focused regression all PASS. Exact hashes and unchanged root sources are retained in rollback.json. The temporary source copy was removed.

## Limits and next verification

The workflow still requires actual GitHub acceptance and all required hosted checks after push. Windows/macOS runtime behavior must be observed in that hosted run. No force-full policy, category activation, secrets, external protection, main branch or tags were changed. Parent owns final integration, independent implementation quality review and release.
