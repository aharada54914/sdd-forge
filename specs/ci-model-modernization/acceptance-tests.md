# Acceptance tests: CI efficiency and current model selection

## Acceptance Criteria

### CI workstream

| AC | Requirement | Observable outcome |
|---|---|---|
| AC-001 | REQ-001 | Complete revision-bound change input; all linked TEST branches below pass or explicitly retain full/pending behavior as specified. |
| AC-002 | REQ-002 | Trusted conservative planning; all linked TEST branches below pass or explicitly retain full/pending behavior as specified. |
| AC-003 | REQ-003 | Dependency-aware selection; all linked TEST branches below pass or explicitly retain full/pending behavior as specified. |
| AC-004 | REQ-004 | Stable required contexts; all linked TEST branches below pass or explicitly retain full/pending behavior as specified. |
| AC-005 | REQ-005 | Evidence-based aggregation; all linked TEST branches below pass or explicitly retain full/pending behavior as specified. |
| AC-006 | REQ-006 | Full verification escape hatch; all linked TEST branches below pass or explicitly retain full/pending behavior as specified. |
| AC-007 | REQ-007 | Safe dependency caching; all linked TEST branches below pass or explicitly retain full/pending behavior as specified. |
| AC-008 | REQ-008 | Measured parallel execution; all linked TEST branches below pass or explicitly retain full/pending behavior as specified. |
| AC-009 | REQ-009 | Rollout and measurable results; all linked TEST branches below pass or explicitly retain full/pending behavior as specified. |
| AC-010 | REQ-010 | Documentation and release delivery; all linked TEST branches below pass or explicitly retain full/pending behavior as specified. |

### Model workstream

| AC | Requirement | Test branches |
|---|---|---|
| AC-011 | REQ-011 | TEST-079 through TEST-082, TEST-138–TEST-143 |
| AC-012 | REQ-012 | TEST-083 through TEST-088 |
| AC-013 | REQ-013 | TEST-089 through TEST-093, TEST-150–TEST-151 |
| AC-014 | REQ-014 | TEST-094 through TEST-099, TEST-147–TEST-149, TEST-152–TEST-162 |
| AC-015 | REQ-015 | TEST-100 through TEST-104, TEST-131 |
| AC-016 | REQ-016 | TEST-105 through TEST-110, TEST-132/TEST-133 |
| AC-017 | REQ-017 | TEST-111 through TEST-115 |
| AC-018 | REQ-018 | TEST-116 through TEST-121, TEST-134–TEST-137, TEST-144–TEST-146 |
| AC-019 | REQ-019 | TEST-122 through TEST-127 |
| AC-020 | REQ-020 | TEST-128 through TEST-130 |

## Test Matrix

### CI workstream

| Test ID | AC | Scenario | Assertion |
|---|---|---|---|
| TEST-001 | AC-001 | add/delete | A fixture adds and removes paths; both appear exactly once in the selected-impact input. |
| TEST-002 | AC-001 | rename | A rename with content changes selects consumers of both old and new paths. |
| TEST-003 | AC-001 | type/case | Separate type-change and case-only fixtures retain both relevant paths and match case-sensitive rules. |
| TEST-004 | AC-001 | large diff | A fixture with 3,001 changed files includes the final relevant path without truncation. |
| TEST-005 | AC-001 | revision binding | Wrong base/head/tested merge or missing Git objects never produces an affected plan. |
| TEST-006 | AC-001 | fork and unusual paths | Fork head identity and paths with spaces, tabs/newlines or command-like text are treated as data. |
| TEST-007 | AC-002 | trusted base | PR-controlled planner or rules cannot authorize omission; absence of base support takes full. |
| TEST-008 | AC-002 | shared files | Separate planner/catalog/workflow/installer/contract/authorization fixtures each produce full. |
| TEST-009 | AC-002 | unknown/empty/invalid | Separate unknown-path, empty-diff and malformed-input fixtures each produce full or explicit blocked execution, never affected success. |
| TEST-010 | AC-002 | shadow compatibility | Existing v1 shadow/compare tests retain exact semantics including observed misses. |
| TEST-011 | AC-003 | union/closure | Combined independent changes and a transitive consumer chain include the full required union. |
| TEST-012 | AC-003 | fixture/generated | A shared fixture or generator input selects its consuming suites. |
| TEST-013 | AC-003 | document boundary | SKILL.md, AGENTS.md, human-copy and contract-bound evidence changes cannot use a general docs skip. |
| TEST-014 | AC-003 | omission mutation | Removing a required dependency or omission reason makes validation fail. |
| TEST-015 | AC-003 | unproven category | A category without valid comparison evidence stays full. |
| TEST-016 | AC-004 | native names | A small-change hosted PR emits all four exact required contexts and actually runs each native wrapper. |
| TEST-017 | AC-004 | optional omission | A proven unrelated heavy group is skipped with a plan reason while related checks execute. |
| TEST-018 | AC-004 | trigger integrity | Structural checks reject workflow path filters or missing existing events that could leave a required context pending. |
| TEST-019 | AC-005 | positive proof | A valid same-run plan plus actual job/step/OS results and required runner receipts passes. |
| TEST-020 | AC-005 | failure/cancel/skip | Separate selected failure, cancellation and unexpected skip fixtures fail aggregation. |
| TEST-021 | AC-005 | missing/malformed | Separate absent plan, malformed plan, missing receipt and empty success fixtures fail. |
| TEST-022 | AC-005 | identity/mutation | Separate old revision, wrong run, changed hash, duplicate identity and wrong native OS fixtures fail. |
| TEST-023 | AC-005 | rerun | Partial reruns bind each latest completed job observation to the same run/head and preserve failed prior attempts as history. |
| TEST-024 | AC-005 | A9 activation | Both existing active-success and inactive-skipped branches preserve their conditions; mismatched activation/result fails. |
| TEST-025 | AC-006 | full events | Separate main, merge_group, release-validation and manual fixtures choose full. |
| TEST-026 | AC-006 | force full | Force-full restores complete execution; missing/invalid settings cannot enable affected mode. |
| TEST-027 | AC-006 | full parity | Before/after full invocation inventories and executed native results retain every required suite, argument and OS obligation. |
| TEST-028 | AC-007 | cache identity | Changing OS/runtime/lockfile/tool digest invalidates the matching dependency cache. |
| TEST-029 | AC-007 | cache recovery | Miss and corrupted artifact cases safely reacquire or fail; neither creates a test PASS. |
| TEST-030 | AC-007 | cache trust | Structural/negative tests reject source/verdict/credential caches and PR writes to trusted shared cache scope. |
| TEST-031 | AC-008 | partition parity | Independent partitions form the exact required multiset of suite/OS obligations without loss. |
| TEST-032 | AC-008 | concurrency | Same PR newer commit cancels its predecessor; different fork PRs and main/merge/release have distinct non-cancelling groups. |
| TEST-033 | AC-008 | bounded retry | Acquisition retry stops at its bound and records attempts; a failed test is not retried into an erased success. |
| TEST-034 | AC-009 | category comparison | Separate docs/configuration, MCP, cloud and shared representative changes produce full-versus-selected observations; only proven categories activate. |
| TEST-035 | AC-009 | hosted/fixture distinction | Evidence labels hosted PR/native/full/manual runs and local merge_group fixtures accurately; unavailable actual merge_group is explicitly pending. |
| TEST-036 | AC-009 | measurement | Reports include exact revision, selected/omitted counts, measured wall/job time and known cache hits without unmeasured percentage claims. |
| TEST-037 | AC-010 | operator docs | Current README and verification/release/contributor docs explain selection, fixed contexts, full switch and failure recovery with valid links. |
| TEST-038 | AC-010 | release | An immutable new annotated version tag points to the exact full-local/full-hosted tested commit; old tag IDs remain unchanged. |
| TEST-039 | AC-001 | case-only rename | Case-only rename retains the old and new paths under case-sensitive classification. |
| TEST-040 | AC-001 | missing base | Missing base object produces full with a recorded reason. |
| TEST-041 | AC-001 | wrong head | A mismatched PR head cannot produce an affected plan. |
| TEST-042 | AC-001 | wrong merge | A tested merge with unexpected parents cannot produce an affected plan. |
| TEST-043 | AC-001 | unusual paths | Spaces, tabs/newlines and shell-shaped strings remain literal NUL-delimited path data. |
| TEST-044 | AC-002 | catalog change | A catalog change forces full. |
| TEST-045 | AC-002 | workflow change | A workflow change forces full. |
| TEST-046 | AC-002 | installer change | An installer change forces full. |
| TEST-047 | AC-002 | contract change | A contract change forces full. |
| TEST-048 | AC-002 | authorization change | An authorization change forces full. |
| TEST-049 | AC-002 | empty diff | An empty change list takes full. |
| TEST-050 | AC-002 | malformed input | Malformed planning input never enables affected execution. |
| TEST-051 | AC-003 | generator input | A generator input change includes its generated-output consumers. |
| TEST-052 | AC-003 | AGENTS input | An AGENTS.md change does not enter a generic documentation skip. |
| TEST-053 | AC-003 | human-copy input | A human-copy change does not enter a generic documentation skip. |
| TEST-054 | AC-003 | evidence input | A contract-bound evidence change does not enter a generic documentation skip. |
| TEST-055 | AC-005 | cancelled selected work | A cancelled selected job fails aggregation. |
| TEST-056 | AC-005 | unexpected selected skip | An unexpectedly skipped selected step fails aggregation. |
| TEST-057 | AC-005 | malformed plan | A malformed plan fails aggregation. |
| TEST-058 | AC-005 | missing receipt | A selected runner without its receipt fails aggregation. |
| TEST-059 | AC-005 | empty success | An empty success-shaped result fails aggregation. |
| TEST-060 | AC-005 | wrong run | A result from another run fails aggregation. |
| TEST-061 | AC-005 | changed hash | Changed plan/catalog/workflow hash fails aggregation. |
| TEST-062 | AC-005 | duplicate identity | Duplicate or ambiguous job identity fails aggregation. |
| TEST-063 | AC-005 | wrong OS | Results from a different native OS do not satisfy the required obligation. |
| TEST-064 | AC-006 | merge_group full | A merge_group event selects full. |
| TEST-065 | AC-006 | release full | Release validation requires full. |
| TEST-066 | AC-006 | manual full | Manual execution defaults to full. |
| TEST-067 | AC-007 | runtime cache key | A runtime version change invalidates the dependency cache key. |
| TEST-068 | AC-007 | lock cache key | A lockfile change invalidates the dependency cache key. |
| TEST-069 | AC-007 | tool digest cache key | A pinned tool digest change invalidates the tool cache key. |
| TEST-070 | AC-007 | corrupt cache | A corrupted cache is reacquired or rejected before execution. |
| TEST-071 | AC-008 | different PR concurrency | Two fork PRs with the same branch name do not share a cancelling group. |
| TEST-072 | AC-008 | main concurrency | Main runs have non-cancelling run-specific groups. |
| TEST-073 | AC-008 | merge concurrency | Merge runs have non-cancelling run-specific groups. |
| TEST-074 | AC-008 | release concurrency | Release runs have non-cancelling run-specific groups. |
| TEST-075 | AC-009 | MCP comparison | MCP selection activates only after complete source/dependency/full-result comparison. |
| TEST-076 | AC-009 | cloud comparison | Cloud selection activates only after complete source/dependency/full-result comparison. |
| TEST-077 | AC-009 | shared comparison | Shared changes remain full and their complete result is recorded. |
| TEST-078 | AC-001 | API head versus tested merge | A valid PR head distinct from its verified tested merge passes identity binding; substituting either identity fails. |

### Model workstream

| Test | AC | Scenario | Assertion |
|---|---|---|---|
| TEST-079 | AC-011 | ordinary roles | Each implementation/investigation/spec/design/task/evaluator role resolves from the shared policy. |
| TEST-080 | AC-011 | role floor | An available lightweight model cannot satisfy a stronger evaluator floor. |
| TEST-081 | AC-011 | risk escalation | Existing risk and repeated-failure escalation remain enforced. |
| TEST-082 | AC-011 | cross-model consent | Model selection cannot enable external panelist sends without their existing consent. |
| TEST-083 | AC-012 | Codex pages | All model/list pages are read before a complete availability snapshot is reported. |
| TEST-084 | AC-012 | pagination failure | A failed later page is incomplete, not a complete candidate list. |
| TEST-085 | AC-012 | host identity | A different account/provider/CLI snapshot is not reused. |
| TEST-086 | AC-012 | no discovery | Unsupported discovery produces an actionable unverified status. |
| TEST-087 | AC-012 | stale discovery | A stale snapshot cannot establish fresh availability. |
| TEST-088 | AC-012 | no implicit inference | Read-only discovery does not start a model turn. |
| TEST-089 | AC-013 | successor | A verified eligible successor supersedes its older family member in latest-compatible mode. |
| TEST-090 | AC-013 | unknown model | A new unknown ID is recorded as an update candidate and is not silently adopted. |
| TEST-091 | AC-013 | misleading name | Lexically larger or numerically newer-looking names do not bypass eligibility. |
| TEST-092 | AC-013 | deprecated | A retired or ineligible model is excluded from ordinary selection. |
| TEST-093 | AC-013 | capability intersection | Host support and registry capability requirements both apply. |
| TEST-094 | AC-014 | explicit pinned | A valid explicit pinned ID wins over ordinary current selection. |
| TEST-095 | AC-014 | role env | Role-specific environment selection reaches the actual launcher. |
| TEST-096 | AC-014 | agent precedence | Generated agent model cannot silently override the resolved requested model. |
| TEST-097 | AC-014 | invalid policy | Unknown or mis-cased policy values fail visibly. |
| TEST-098 | AC-014 | injection | Whitespace/flag/separator-shaped IDs never reach a subprocess argument as executable code. |
| TEST-099 | AC-014 | organization allowlist | An override does not grant an unavailable organization model. |
| TEST-100 | AC-015 | record identity | Requested/resolved/reported model and effort are bound to run/session and catalog observation. |
| TEST-101 | AC-015 | resume same model | A resumed attempt retains its original resolved selection. |
| TEST-102 | AC-015 | resume changed model | A model change requires a new recorded attempt. |
| TEST-103 | AC-015 | fixed comparison | A model comparison uses the same fixture/prompt/judge/budget and records changed model only. |
| TEST-104 | AC-015 | fixed skill evaluation | A skill comparison keeps model/settings fixed and varies only the skill. |
| TEST-105 | AC-016 | no compatible model | No compatible current candidate yields a typed blocked result. |
| TEST-106 | AC-016 | access loss | Access failure cannot silently select an older model. |
| TEST-107 | AC-016 | unknown actual ID | A host that cannot report required actual identity cannot pass that audit gate. |
| TEST-108 | AC-016 | actual mismatch | Unexpected fallback or returned model mismatch fails pinned verification. |
| TEST-109 | AC-016 | budget unknown | A configured budget with unknown incompatible pricing units is not treated as zero cost. |
| TEST-110 | AC-016 | older pinned label | An explicitly accepted older pinned run is marked pinned, not latest. |
| TEST-111 | AC-017 | existing schedule | Weekly/manual workflow remains a single maintenance path. |
| TEST-112 | AC-017 | fetch failure | Official-source retrieval failure is visible without claiming a fresh catalog. |
| TEST-113 | AC-017 | dedupe | Repeated candidate detection does not create duplicate notifications. |
| TEST-114 | AC-017 | untrusted source | Instruction-like fetched text is never executed or copied verbatim into runtime configuration. |
| TEST-115 | AC-017 | adoption boundary | Discovery alone never auto-merges or overwrites trusted catalog metadata. |
| TEST-116 | AC-018 | Codex installed path | A real installed Codex invocation receives and reports the resolved model. |
| TEST-117 | AC-018 | Claude transport | Launcher and launch validator agree on policy while retaining read-only/context restrictions. |
| TEST-118 | AC-018 | Copilot precedence | Supported Copilot path validates actual agent/flag precedence rather than assuming env wins. |
| TEST-119 | AC-018 | Gemini panelist | Existing Gemini default follows verified policy or explicit unavailable behavior with consent unchanged. |
| TEST-120 | AC-018 | comment-only mutation | Changing reference comments without changing a stale launch fails integration validation. |
| TEST-121 | AC-018 | identity reservation | Reviewer context is reserved before substantive model execution, unchanged by selection. |
| TEST-122 | AC-019 | v1 compatibility | Supported v1 inputs retain their documented compatibility behavior. |
| TEST-123 | AC-019 | v2 compatibility | Supported v2 registry and explicit effort inputs remain validated. |
| TEST-124 | AC-019 | PowerShell parity | Bash/PowerShell resolve and reject corresponding positive/negative cases identically. |
| TEST-125 | AC-019 | effort independence | Latest-model mode does not enable max/ultra or extra agents automatically. |
| TEST-126 | AC-019 | historic evidence | Frozen prior model records retain their original bytes. |
| TEST-127 | AC-019 | native proof distinction | Fixtures and real model/host evaluations are labelled separately. |
| TEST-128 | AC-020 | documentation | README/capability/maintenance/launcher/installation docs describe actual supported behavior and limitations. |
| TEST-129 | AC-020 | freshness source | Current metadata names its source/date without claiming permanent availability. |
| TEST-130 | AC-020 | release tag | A new immutable tag targets the exact required tested final commit and prior tags remain unchanged. |
| TEST-131 | AC-015 | configured versus actual identity | Codex Thread.model is recorded only as configured/resolved; no actual per-turn ID is invented from it. |
| TEST-132 | AC-016 | scoped reroute | A matching thread/turn model/rerouted event records changed ID and invalidates a pinned unchanged-model claim; an unrelated thread event cannot alter this run. |
| TEST-133 | AC-016 | telemetry unavailable | A gate requiring actual execution-ID proof stops when unsupported; an ordinary permitted run records actual ID unverified and makes no actual-ID proof claim. |
| TEST-134 | AC-018 | domain review entry | Both domain reviewer roles use the managed policy while preserving independent contexts and Copilot restrictions. |
| TEST-135 | AC-018 | workflow auditors | Both workflow auditor roles use the managed policy without inheriting implementation context. |
| TEST-136 | AC-018 | diagnosis entry | Diagnosis resolves its role policy without silently retaining a fixed Sonnet-only default. |
| TEST-137 | AC-018 | self-improvement entry | Existing scheduled/manual self-improvement passes the validated policy selection to its action; no new schedule, secret, actual issue-send test or automatic merge is introduced. |

## UI Integration Checklist

### CI workstream

No graphical UI. Contributor entry is an ordinary pull request; operator entry is manual full verification and the documented force-full setting. TEST-016 verifies hosted required-context reachability; TEST-026 verifies full-mode recovery.

### Model workstream

No graphical frontend. Existing implementation/review commands are the entry points; the installed-host test verifies reachability through a real supported entry. Hosts not available for native validation remain explicitly unverified.

## Verification Scope

Deterministic fixtures prove selection and rejection branches. They do not establish hosted job execution, branch protection or a real merge queue. Actual hosted evidence and exact local full results are required for release. A missing real merge_group event remains an explicit external validation limitation; its local full-policy tests still must pass. No live Azure/AWS deployment is part of this feature.

## Model Evaluation Boundary

Define a rubric and fixed budget before collecting candidate outputs. Judge artifacts and test results, not model self-identification or self-reported success. Model-list metadata alone cannot establish behavior quality. Do not turn inability to test another provider into a fabricated pass.


## Expanded role and input branches

| Test ID | AC | Scenario | Assertion |
|---|---|---|---|
| TEST-138 | AC-011 | implementation role | The managed implementer resolves its role from the shared policy and launches its selected model. |
| TEST-139 | AC-011 | investigation role | The managed investigator resolves its own role floor and current candidate. |
| TEST-140 | AC-011 | specification-review role | Both fresh specification-review invocations consume their bound role selection. |
| TEST-141 | AC-011 | design-review role | Both design-review invocations use the policy and paired launch/validation contract. |
| TEST-142 | AC-011 | task-review role | Both task-review invocations preserve their role selection and independent reservation. |
| TEST-143 | AC-011 | quality-evaluator role | The evaluator applies its host-specific minimum tier and records the selected model. |
| TEST-144 | AC-018 | domain reviewer B | The B domain-review path consumes policy selection independently of reviewer A; TEST-134 covers A. |
| TEST-145 | AC-018 | workflow auditor B | The B workflow-auditor path consumes policy selection independently; TEST-135 covers A. |
| TEST-146 | AC-018 | manual self-improvement | Manual self-improvement uses the same policy-bound action input as the scheduled branch in TEST-137. |
| TEST-147 | AC-014 | pinned without ID | A pinned policy without an explicit resolvable ID fails visibly before launch. |
| TEST-148 | AC-014 | flag-shaped ID | A leading flag-shaped model ID is rejected before subprocess launch; TEST-098 covers whitespace. |
| TEST-149 | AC-014 | separator-shaped ID | A separator-shaped model ID is rejected before subprocess launch; TEST-098 covers whitespace. |
| TEST-150 | AC-013 | native ID mapping | A registry provider-qualified ID resolves only through its explicit native-host mapping; missing/ambiguous mapping blocks, without blind prefix stripping. |
| TEST-151 | AC-013 | unverified successor notice | With a still-current verified candidate and an unknown successor, selection explicitly identifies the latest-verified choice and update candidate; a historical-only catalog cannot silently substitute an older model. |

| TEST-152 | AC-014 | CLI versus environment and project | Three different valid IDs select the CLI ID, record CLI provenance and never launch either shadowed ID. |
| TEST-153 | AC-014 | environment versus project | With no CLI ID, conflicting valid role environment/project IDs select the environment ID and record its source. |
| TEST-154 | AC-014 | project and default | Without CLI/environment, project role configuration wins; absence of all overrides uses the shipped default. |
| TEST-155 | AC-014 | general model environment | Supplying SDD_MODEL, alone or alongside a valid role-specific model variable, produces an unsupported-configuration error. |
| TEST-156 | AC-014 | policy precedence | Conflicting valid CLI/environment/project policies resolve CLI first, environment second when CLI is absent, then project; record the winning source. |
| TEST-157 | AC-014 | project role policy | A project role policy wins over a different project default policy; absent role policy uses the project default. |
| TEST-158 | AC-014 | explicit ID versus latest policy | An effective explicit model ID plus an explicit latest-compatible policy is rejected regardless of their source tiers. |
| TEST-159 | AC-014 | implicit and explicit pin | An explicit ID with no explicit policy becomes pinned; explicit pinned without an ID is rejected. |
| TEST-160 | AC-014 | malformed shadowed setting | A malformed lower-priority supported model/policy value is rejected even when a higher-priority valid value exists. |
| TEST-161 | AC-014 | native precedence conflict | A higher-precedence native agent model that cannot be safely aligned blocks launch with a typed native-precedence conflict. |
| TEST-162 | AC-014 | matching native setting | An already matching or safely generated matching native model launches the resolved ID and records alignment without changing permission or consent. |
