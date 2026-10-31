# A7 T-004 F2 expected-template rendering repair

Run ID: a7-t004-f2-rendering-repair-20261014
Task Attempt Count: 3

Owner: `/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge`.
HEAD: `25813ee4baf8ae8fff344a6c979da61fbd23d2c7`, detached, existing dirty
changes preserved. High-risk existing T-004, followed by the separately approved
T-012 collection/refresh. Parent explicitly authorized this continuation.
No Git publication, frozen spec change, ledger reservation or formal gate.

## Trusted F2 values fixed before new collection

- `<feature>` = `team-coffee-orders`
- `<タスク名>` = `注文登録を実装する`

These are fixture inputs, not values extracted from actual output. Only these
two known placeholders in EXPECTED lite templates are substituted. Actual
response content remains unchanged. Fixed heading text, level and order remain
strictly compared. Templates and corpus schema remain unchanged. Historical
corpus and prior raw responses will be preserved before the sanctioned refresh.

## Preflight: evidence fields and failing mismatch tests

| Persisted or compared field | Governing counterpart | Failing mismatch case |
| --- | --- | --- |
| expected F2 feature/task heading values | fixed values above; template placeholders | wrong feature and wrong task name |
| required heading text | unchanged lite template fixed text | renamed Scope heading |
| heading level and order | design.md:979-985 / exact template order | changed level, exchanged Scope/Done When |
| Status/Approval field names | unchanged tasks-lite.md:4-5 | missing Status |
| new corpus content/provenance | preserved raw response and T-012 write route | dry-run refuses mismatch without changing historical corpus |

YAML diagnostic failures remain open and will not be labeled repaired by this
work. Regression controls are synthetic and are not live response evidence.

## TDD and independent diff review

Before implementation, `f2-rendering-regression-20261014.sh sh` and `ps1`
each returned exit 1, 6 passed / 1 failed: the valid rendered control was
rejected with `structural mismatch`. After the expected-only rendering and
pre-write status-name comparison, the initial seven cases passed in both.
The expanded case-sensitivity/placeholder/Approval suite then passed 11/0
in both runtimes, exit 0, with corpus hashes unchanged.

Fresh-context `f2_rendering_diff_review` independently reran both expanded
drivers: 11/0 each, and returned scoped PASS with no finding. It verified
expected-only literal substitution, strict fixed text/level/order, and
case-sensitive PowerShell behavior. This is not a formal gate or approval
of the entire pre-existing dirty diff. `bash -n` and scoped `git diff --check`
also exited 0. YAML remains unresolved.

## Separate fresh response

`fresh_f2_fixed_inputs` was given the fixed values above, a synthetic in-memory
coffee-order scenario (no personal data/payment/auth/external services/storage),
F2 environment declaration, and only the current lite skill and templates as
source inputs. It did not read historical corpus or prior reviewer outputs.
This is a live model response, not installed-product-hook or physical-fixture
execution. Exact runtime model identity is unavailable and recorded as such.

The complete first raw response is preserved as
`verification/T-004/f2-fixed-input-response-20261014-attempt1.json` under this
feature. The Bash dry-run returned exit 1, `required output paths/count differ`:
the model used `specs/team-coffee-orders/` prefixes instead of feature-relative
artifact paths. The collector then returned a complete second response changing
only those three path values, preserved as `...-attempt2.json`. No coordinator
content repair was substituted for a model response. Both actual dry-runs
accepted attempt 2, including malformed-input/no-write self-checks; the PS
reordered-artifact self-check also passed. All returned exit 0.

The original corpus was copied byte-for-byte into
`verification/T-004/f2-historical-before-refresh-20261014.json`, SHA-256
`4fe2eff3b2842f5e1228db5f06f99188756e8800608620ef0dfb662fd29b7b88`, before
any actual refresh. Earlier raw responses and reports remain intact.

## YAML implementation feasibility without new dependencies

Repository search found no reusable native YAML parser in Bash, jq or
PowerShell. `plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.sh:1-6`
and `.ps1:1-8` are Python dispatchers, not native implementations. Their
1,069-line Python master explicitly defines a restricted subset at lines 2-40:
nested block maps/sequences and typed scalars, but no non-empty flow collections,
block scalars, anchors/aliases, non-core tags or directives. It cannot directly
satisfy the A7 dependency/runtime prohibition or the unrestricted YAML wording.
Its existing tests (710 Bash / 803 PowerShell lines) are useful case material,
not proof that a translated/new parser meets A7's broader contract.

Two concrete options retain the no-new-dependency constraint:

1. Keep broader YAML acceptance and implement a native parser plus cross-runtime
   conformance tests. Reuse selected test cases and parsing concepts, not the
   Python execution dependency. This is not a two-line correction: at least
   indentation/block and flow parsing, quoted/multiline scalar handling,
   type resolution, tags/aliases and error/parity behavior must be designed
   and tested. The YAML version/schema and treatment of non-string mapping
   keys still need an explicit interpretation because the frozen A7 design
   does not select them. No reliable elapsed-time estimate is established.
2. Explicitly approve and rebind an A7 supported profile (version, allowed
   maps/sequences/scalars, type resolution, unsupported constructs and hard
   failure semantics), then implement only that profile using existing
   runtimes. A flat-scalar-only profile is a specification change, not already
   authorized by the parser's fail-closed obligation. The independent scope
   review confirmed this distinction.

No partial parser is installed or counted as complete. The available shared
parser is not silently imported, and dependency relaxation is not proposed.

## Independent content review and sanctioned refresh

The fresh-context reviewer returned scoped content PASS before the write:
attempt 2 changed only three artifact paths from attempt 1; content and
metadata were unchanged; expected headings, Status/Approval fields, and
scenario content were present. The reviewer confirmed the historical backup
hash above. File inspection cannot independently establish the collector's
runtime model identity or prove its unread history; those provenance limits
remain explicit rather than being converted into a formal gate PASS.

Executed from the owner checkout, with `rtk proxy` and non-login shell:

```sh
rtk proxy env SDD_LIVE_MODEL_NAME=codex-fresh-context-model-id-unavailable bash tests/structural-compatibility-live-refresh.tests.sh --state F2 --fixture specs/epic-195-a7-compatibility/verification/T-004/f2-fixed-input-response-20261014-attempt2.json
```

Exit 0: `PASS: refreshed F2 corpus entry`. The resulting corpus and preserved
raw attempt 2 are byte-identical, SHA-256
`21b4275c6eb498a533cf07cdc92fed64cf93e79bfc22f73c5ab426e9cc79dcfe`.
An independent `jq` whole-document equality check also returned true, exit 0.
The historical backup still has SHA-256 `4fe2eff3b2842f5e1228db5f06f99188756e8800608620ef0dfb662fd29b7b88`.

After refresh, `activation-regression-20261004.sh sh` passed 77/0 and
`activation-regression-20261004.sh ps1` passed 84/0, both exit 0, with F3
active. F5/F6 remain the two allowlisted dependency SKIPs, not executed
behavioral PASSes. `check-workflow-state.sh --feature epic-195-a7-compatibility`
returned `workflow-state: ok`; `check-traceability.sh
specs/epic-195-a7-compatibility/traceability.json . require-evidence` passed
7 links, both exit 0. Scoped `git diff --check` returned exit 0.

These checks do not close the eight YAML diagnostic violations, old quality
ticket, or T-004. No formal ledger, frozen implementation Outputs, task state,
or prior declaration was updated. Native product-hook execution, exact-final
HEAD CI, formal quality-gate admission and Done remain unclaimed.

## Reviewed implementation hashes

| Path | SHA-256 |
| --- | --- |
| `tests/structural-compatibility.tests.sh` | `2039826286ebb863c58cdf4a2e2ffa248aed95c765587e1d7c7a51a5970d2e1e` |
| `tests/structural-compatibility.tests.ps1` | `9fb808bf0f204a61a311af11a8215be967b5a9fc5689f13f8f0cc8f9dbbd0712` |
| `tests/structural-compatibility-live-refresh.tests.sh` | `66b6358e665bed2417a1fb3ce783dafe2b342552cc2657a6c84c213a359ef052` |
| `tests/structural-compatibility-live-refresh.tests.ps1` | `b971ec98124351e84e8e7123e95ef7534754bcc660544afeea72e7025a56785e` |

The post-refresh Bash and PowerShell activation mutation drivers each returned
exit 0, 5 killed / 0 survived. They mutate disposable copies only; the current
and historical corpora are not altered by these drivers. Exact commands:

```sh
rtk proxy bash specs/epic-195-a7-compatibility/verification/T-004/activation-mutation-20261004.sh sh
rtk proxy bash specs/epic-195-a7-compatibility/verification/T-004/activation-mutation-20261004.sh ps1
```

The next unresolved authoritative task remains T-004 (`tasks.md:555-561`),
specifically YAML semantic parsing/hard failure (`design.md:963-985`), not
another F2 replacement. T-013 remains Planned and T-011 remains the sole CI
registration owner (`tasks.md:1521-1564,1874-1912`). This continuation does not
change their lifecycle or dependencies.
