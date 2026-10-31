# Issue 423 T-002 Done When evidence audit — 2026-10-05

Preparation-only owner-side audit and focused regression, not an independent evaluator result or quality-gate verdict. No reservation, protected apply, historical report overwrite, task change, Git operation or publication was performed. Existing dirty sources were preserved. The standard package compile generated local `mcp/ci-mcp/dist-test` output; no product-source edit was made.

## Done When / acceptance mapping

The scope is `specs/sdd-domain-multitarget/tasks.md:33-50` (Approved, Implementation Complete), AC-002 / TEST-002 and AC-012 / TEST-012 (`acceptance-tests.md:14,35`). Later T-006 host conformance/release completion is not deemed satisfied by T-002 checks.

| T-002 obligation | Evidence available to candidate44 | Limit / current action |
|---|---|---|
| Five ownership/non-ownership boundaries | `contract-boundaries.tests.py:67-105` checks Core, Registry, Provider Binding, Host Adapter and optional UI ownership against schemas/design. Existing 28-test result is recorded in `qg-prep-20261003/current-build-and-checks.md:11`. | Host/UI rows are declaration checks, not host activation or UI-provider execution. This matches the boundary-fixture task, not broader host conformance. |
| Neutral capabilities and Provider Binding IDs in Project Context | The same suite's `:156-267` exercises allowed context fields/IDs and rejects provider fields throughout nested context/projection objects; `:273-361` checks actual Registry neutrality and mutation fixtures. Schemas, validator/helper, provider-term list and fixture are admitted. | The original report's older validator hash is superseded only through the explicit post-fix declaration. No silent replacement of historical evidence. |
| Read-only ci-mcp; no Core write/API dependency | `:413-461` checks tool registrations, method/import mutations and Core dependency strings. Both ci-mcp source files and Core contracts are in candidate44. | The report explicitly limits this to static checks. This turn adds a targeted current runtime no-write probe and whole-source read-only static scan, recorded separately below. |
| Provider-specific mismatch fixtures fail | Context root/component/characteristics/remaining objects (`:161-204`), projection (`:244-269`), nested Registry predicates (`:309-332`) and Registry extra fields (`:345-361`) are negative assertions with positive controls. | Existing 28-method execution is one run, not three runs for unit/acceptance/regression. Its unchanged hashes alone do not constitute a new test execution. |

## Targeted behavioral gap closed locally

The admitted implementation report describes ci-mcp coverage as static and says the broader runtime suite was not rerun. To supplement that scope without unnecessary full-suite repetition, the existing package script (`mcp/ci-mcp/package.json:13`) compiled current TypeScript, then only the three relevant no-write/read-only tests ran:

1. `rtk proxy npm run test:compile` — exit 0.
2. `rtk proxy node --test dist-test/tests/no-write/no-write-behavior.test.js dist-test/tests/no-write/input-schema-fields.test.js dist-test/tests/readonly/static-check.test.js` — exit 0; 34 tests passed, 0 failed, 0 skipped.

Cwd was the owner checkout's `mcp/ci-mcp`, `login=false`. Full observed output and post-run hashes for nine production sources, five test/support files, package/lock/config and unchanged candidate are saved in `reports/verification/issue423-t002-ci-readonly-current-20261005.log`, SHA-256 `5e3e1a68560659a236ff3de10173f45107b05d7f3186db13e90b8caacd314778`.

The 34 checks comprise 20 behavioral cases (five tools × action/method/body/command), one probe-list check, three input-schema checks, seven current-source static checks and three scanner regression cases. Runtime tests inject fake fetch functions and a fixed synthetic environment; they require invalid-input and zero JSON/text fetch calls (`tests/no-write/no-write-behavior.test.ts:93-108`). No real credentials or API request is needed. The behavioral probe covers four fields, not every spelling in the ten-entry helper denylist; no broader exhaustive dynamic claim is made. The source scan covers filesystem/process/eval/write-HTTP boundaries and fixed GET/host checks (`tests/readonly/static-check.test.ts:116-206`). This is not all 148 historical runtime tests, CI, native Windows, or installed-host verification.

## Installer evidence is separate

The five installer additions to candidate44 are `install.sh`, `tests/install.tests.sh`, and the scope/impact/recheck notes. The current source hashes match their recorded 43-test run. That suite covers the changed successful EXIT-trap behavior, lock cleanup and real registration-failure tree retention; fixture payload starts from HEAD, not the entire dirty owner tree (`reports/verification/issue423-t002-installer-impact-20261004.md:12-26`). It was not rerun this turn.

The human FilesOnly receipt proves exact validator/helper installed-byte parity and installed validator 9 checks only (`qg-prep-20261003/current-build-and-checks.md:20`). It used the earlier installer, skipped host registration and is not a new whole-checkout distribution receipt. Current installer regression does not enlarge that receipt's scope. Conversely, the EXIT-trap-only delta does not by itself invalidate the unchanged T-002 payload proof or require another human assembly before ownership-boundary evaluation. The human-only runner was not executed or replaced.

## Candidate readiness and remaining admission work

Candidate44 remains at SHA-256 `374901a0b6b282c2d232fa98da96c365cbce400cdb2b46d9e542c31db3069598`. Its prior machine check recorded 39 old inputs retained, 21 common declaration rows, five added installer inputs, 44 unique inputs and 46 matching current hashes including declaration/predecessor. No new hash conflict or missing member in that declared set was identified.

There is a concrete limit, not an implicit admission: candidate44 does **not** include this audit, the new test log, the runtime test sources or `src/tools/actions.ts` and the other runtime support sources. An evaluator restricted to candidate44 cannot rerun these new behavioral tests or consume their result from an unbound prompt. If the coordinator chooses to present this supplemental evidence, create a further non-frozen declaration/candidate with exact hashes for the required new evidence and sources; retain candidate44. Do not treat these new observations as already accepted formal evidence. The existing candidate is sufficient to present its narrower declared static/fixture evidence; its eventual sufficiency remains the independent evaluator's decision.

Manifest-filename binding still requires the existing three-file human-only apply and subsequent prescribed regression. Formal caller/precheck, actual identity/receipt, complete delivery, independent evaluation and Done remain pending. This audit neither waives those gates nor requests repeat authorization.
