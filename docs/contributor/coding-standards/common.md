# Common coding rules

Each example is schematic and original to this repository. Apply the language notes and actual API contracts. Sources are [canonical research metadata](research/records/research-evidence.json); source limitations are in the [map](research/map.md). Tool names below are mappings, not claims that those optional rules are installed or executed.

<a id="cs-001"></a>

## CS-001: Shell source is not a data channel

- Purpose: Shell source is not a data channel; prevent the failure described by the application condition.
- Surface: bash,powershell,python,javascript. Apply when: External values reach a command interpreter.
- Severity: critical. Detection: data-flow. Tool mapping: ShellCheck SC2086/SC2294; Ruff S602 if enabled.
- Fix and reason: Use argument arrays and validate the executable/option grammar; PowerShell uses & $exe @args; Python uses subprocess.run(argv, check=True).
- Exception / normal control: Fixed shell programs with independently passed data can be legitimate; arrays do not neutralize option injection or Windows bat/cmd parsing.
- Evidence: SRC-008,SRC-009. Owner: #688 shell/CI; #689 Python; #690 TS/JS.

Bad (intentional non-executable counterexample):

```text
eval "tool $value"
```

Good (adapt to the actual API):

```text
args=(tool "$value"); "${args[@]}"
```

<a id="cs-002"></a>

## CS-002: Keep embedded programs literal

- Purpose: Keep embedded programs literal; prevent the failure described by the application condition.
- Surface: bash,powershell,python,javascript. Apply when: A shell here-document, here-string or -c builds another language program.
- Severity: critical. Detection: data-flow. Tool mapping: ShellCheck SC2086 covers only part.
- Fix and reason: Quote the here-document delimiter and pass arguments, stdin or environment as data; PowerShell single-quoted here-strings serve the same boundary.
- Exception / normal control: Static source generation with a real parser/serializer and reviewed grammar may be justified; ordinary display substitution is allowed.
- Evidence: SRC-008,SRC-009. Owner: #688 shell/CI; #689 Python; #690 TS/JS.

Bad (intentional non-executable counterexample):

```text
python -c "print('$value')"
```

Good (adapt to the actual API):

```text
VALUE="$value" python -c 'import os; print(os.environ["VALUE"])'
```

<a id="cs-003"></a>

## CS-003: Bind SQL data

- Purpose: Bind SQL data; prevent the failure described by the application condition.
- Surface: python,typescript,javascript,powershell. Apply when: External data enters a SQL expression.
- Severity: critical. Detection: data-flow. Tool mapping: No universal checker; driver-specific review.
- Fix and reason: Use driver parameters; allowlist identifiers separately because table names usually cannot be parameters.
- Exception / normal control: Static migrations and fixed query text are normal; varying business queries need not be merged.
- Evidence: SRC-003. Owner: #688 shell/CI; #689 Python; #690 TS/JS.

Bad (intentional non-executable counterexample):

```text
db.execute("SELECT * FROM item WHERE name = '" + name + "'")
```

Good (adapt to the actual API):

```text
db.execute("SELECT * FROM item WHERE name = ?", (name,))
```

<a id="cs-004"></a>

## CS-004: Serialize structured values

- Purpose: Serialize structured values; prevent the failure described by the application condition.
- Surface: all. Apply when: Values are written as JSON or YAML consumed by another tool.
- Severity: major. Detection: data-flow. Tool mapping: Ruff/ESLint syntax checks only.
- Fix and reason: Use json/jq --arg, ConvertTo-Json or an existing YAML serializer; validate the consumer schema.
- Exception / normal control: Literal fixture documents and fixed schemas are valid; serializers do not establish schema correctness.
- Evidence: SRC-012. Owner: #688 shell/CI; #689 Python; #690 TS/JS.

Bad (intentional non-executable counterexample):

```text
payload = '{"name":"' + name + '"}'
```

Good (adapt to the actual API):

```text
payload = json.dumps({"name": name})
```

<a id="cs-005"></a>

## CS-005: Pass Actions expressions through data

- Purpose: Pass Actions expressions through data; prevent the failure described by the application condition.
- Surface: workflow,bash,powershell. Apply when: An Actions context expression reaches run source.
- Severity: critical. Detection: machine. Tool mapping: Actions structural scan; actionlint when available.
- Fix and reason: Use env or action inputs and quote at the receiving shell boundary.
- Exception / normal control: Expression use in if, with and env is normal; review trusted finite constants explicitly rather than blanket allowlisting run.
- Evidence: SRC-008. Owner: #688 shell/CI; #689 Python; #690 TS/JS.

Bad (intentional non-executable counterexample):

```text
run: echo "${{ github.event.pull_request.title }}"
```

Good (adapt to the actual API):

```text
env: { TITLE: "${{ github.event.pull_request.title }}" }
run: printf '%s\n' "$TITLE"
```

<a id="cs-006"></a>

## CS-006: Escape for the HTML destination

- Purpose: Escape for the HTML destination; prevent the failure described by the application condition.
- Surface: python,typescript,javascript. Apply when: Dynamic text becomes HTML markup.
- Severity: critical. Detection: data-flow. Tool mapping: ESLint no-unsanitized if installed; context review.
- Fix and reason: Use text nodes or the template engine escape API; validate URL attributes separately.
- Exception / normal control: Reviewed trusted static markup is normal; sanitizers require a documented allowed language.
- Evidence: SRC-014. Owner: #688 shell/CI; #689 Python; #690 TS/JS.

Bad (intentional non-executable counterexample):

```text
node.innerHTML = userText
```

Good (adapt to the actual API):

```text
node.textContent = userText
```

<a id="cs-007"></a>

## CS-007: Separate regex syntax and literals

- Purpose: Separate regex syntax and literals; prevent the failure described by the application condition.
- Surface: all. Apply when: User text is used as literal text in a regular expression.
- Severity: major. Detection: data-flow. Tool mapping: Context review; regex tools do not infer intent.
- Fix and reason: Use literal matching first; escape only the literal component and bound deliberately accepted regex execution.
- Exception / normal control: A documented regex input is intentionally syntax, not a literal; allowlisting or execution limits remain necessary.
- Evidence: SRC-011. Owner: #688 shell/CI; #689 Python; #690 TS/JS.

Bad (intentional non-executable counterexample):

```text
re.search(user_text, value)
```

Good (adapt to the actual API):

```text
re.search(re.escape(user_text), value)
```

<a id="cs-008"></a>

## CS-008: Encode URL components independently

- Purpose: Encode URL components independently; prevent the failure described by the application condition.
- Surface: all. Apply when: Untrusted components enter an outbound URL.
- Severity: critical. Detection: data-flow. Tool mapping: Context review; transport tests.
- Fix and reason: Use the standard URL/query APIs; validate scheme, host and redirects at the transport boundary.
- Exception / normal control: A whole URL must not be escaped as a query component; a fixed documented endpoint is normal.
- Evidence: SRC-013. Owner: #688 shell/CI; #689 Python; #690 TS/JS.

Bad (intentional non-executable counterexample):

```text
url = base + "?name=" + name
```

Good (adapt to the actual API):

```text
url = base + "?" + urllib.parse.urlencode({"name": name})
```

<a id="cs-009"></a>

## CS-009: Preserve path and option boundaries

- Purpose: Preserve path and option boundaries; prevent the failure described by the application condition.
- Surface: all. Apply when: External path reaches filesystem or command arguments.
- Severity: critical. Detection: data-flow. Tool mapping: ShellCheck SC2086; context containment review.
- Fix and reason: Quote and use option terminators where supported; validate containment, symlinks and path ownership before mutation.
- Exception / normal control: Some CLIs lack --; use their documented alternative. Absolute application roots and temporary fixture paths are valid.
- Evidence: SRC-009. Owner: #688 shell/CI; #689 Python; #690 TS/JS.

Bad (intentional non-executable counterexample):

```text
rm $path
```

Good (adapt to the actual API):

```text
rm -- "$path"
```

<a id="cs-010"></a>

## CS-010: Keep secrets out of code and logs

- Purpose: Keep secrets out of code and logs; prevent the failure described by the application condition.
- Surface: all. Apply when: Credentials or sensitive values are persisted, displayed or sent.
- Severity: critical. Detection: data-flow. Tool mapping: Secret scanner if available plus data-flow review.
- Fix and reason: Use the existing secret source and shared redaction boundary; rotate any real exposed credential through its owner.
- Exception / normal control: Explicit fake credentials in bounded negative fixtures are normal; a variable named token alone proves no secret.
- Evidence: SRC-003,SRC-008. Owner: #688 shell/CI; #689 Python; #690 TS/JS.

Bad (intentional non-executable counterexample):

```text
logger.info("token=%s", token)
```

Good (adapt to the actual API):

```text
logger.info("credential configured")
```

<a id="cs-011"></a>

## CS-011: Name policy constants at their owner

- Purpose: Name policy constants at their owner; prevent the failure described by the application condition.
- Surface: all. Apply when: A mutable policy, personal path or environment assumption is repeated.
- Severity: major. Detection: context. Tool mapping: Context/consumer review.
- Fix and reason: Locate configuration and defaults at the existing contract owner; validate supplied values and units.
- Exception / normal control: Schema versions, mathematical constants and scenario-specific fixture values are not magic-number violations.
- Evidence: SRC-004,SRC-006. Owner: #688 shell/CI; #689 Python; #690 TS/JS.

Bad (intentional non-executable counterexample):

```text
timeout = 117  # repeated independently across consumers
```

Good (adapt to the actual API):

```text
timeout = PROCESS_TIMEOUT_SECONDS
```

<a id="cs-012"></a>

## CS-012: Make state ownership visible

- Purpose: Make state ownership visible; prevent the failure described by the application condition.
- Surface: all. Apply when: Shadowed names or globals alter the meaning of inputs across calls.
- Severity: major. Detection: machine. Tool mapping: Ruff F811/F823; PowerShell automatic-variable analysis; ESLint no-shadow if enabled.
- Fix and reason: Pass changing dependencies explicitly; keep local names distinct from shell automatic variables and public inputs.
- Exception / normal control: Immutable module constants and deliberate small local mutations are allowed.
- Evidence: SRC-004. Owner: #688 shell/CI; #689 Python; #690 TS/JS.

Bad (intentional non-executable counterexample):

```text
def parse(value):
    value = global_input
```

Good (adapt to the actual API):

```text
def parse(source_text):
    return decode(source_text)
```

<a id="cs-013"></a>

## CS-013: Reuse infrastructure with a stable contract

- Purpose: Reuse infrastructure with a stable contract; prevent the failure described by the application condition.
- Surface: all. Apply when: Logging, DB connection lifecycle, authentication or resource transport is reimplemented.
- Severity: major. Detection: context. Tool mapping: Design review; no duplication-percentage gate.
- Fix and reason: Verify semantic, error, side-effect, encoding and ordering compatibility; keep business retry, query and workflow decisions with the feature.
- Exception / normal control: Separate providers or security domains may require separate infrastructure. Similar feature logic alone is not a violation.
- Evidence: SRC-006. Owner: #691.

Bad (intentional non-executable counterexample):

```text
feature calls raw transport and duplicates credential redaction
```

Good (adapt to the actual API):

```text
feature calls existing compatible resource client
```

<a id="cs-014"></a>

## CS-014: Keep parser and validation ownership explicit

- Purpose: Keep parser and validation ownership explicit; prevent the failure described by the application condition.
- Surface: all. Apply when: Two consumers claim to interpret the same versioned grammar.
- Severity: major. Detection: context. Tool mapping: Contract and call-site review.
- Fix and reason: Share only the invariant grammar; retain consumer-specific admission/policy layers and test both against the contract.
- Exception / normal control: Strict live admission and tolerant historical reading can legitimately differ; record the divergence rather than force one parser.
- Evidence: SRC-006. Owner: #691.

Bad (intentional non-executable counterexample):

```text
consumer reparses a shared manifest with split(":")
```

Good (adapt to the actual API):

```text
consumer calls the canonical manifest parser
```

<a id="cs-015"></a>

## CS-015: Separate independently changing responsibilities

- Purpose: Separate independently changing responsibilities; prevent the failure described by the application condition.
- Surface: all. Apply when: Nested code mixes admission, interpretation, effects and reporting.
- Severity: minor. Detection: context. Tool mapping: Complexity tools are signals only.
- Fix and reason: Split at real responsibility boundaries; use clear early failure without losing cleanup or checks.
- Exception / normal control: Length/depth alone is a review signal, not a defect; a cohesive parser may remain long.
- Evidence: SRC-001,SRC-004. Owner: #691.

Bad (intentional non-executable counterexample):

```text
validate_write_and_approve_everything(mode, flags)
```

Good (adapt to the actual API):

```text
validate_input(data); persist_validated(data)
```

<a id="cs-016"></a>

## CS-016: Do not add speculative interfaces

- Purpose: Do not add speculative interfaces; prevent the failure described by the application condition.
- Surface: all. Apply when: An abstraction/configuration exists only for hypothetical consumers.
- Severity: major. Detection: context. Tool mapping: Design review.
- Fix and reason: Prefer existing implementation, standard library and installed dependencies; remove unneeded policy switches.
- Exception / normal control: A required public compatibility boundary or proven invariant can justify an abstraction.
- Evidence: SRC-006. Owner: #691.

Bad (intentional non-executable counterexample):

```text
UniversalManager(mode, provider, allow_everything=True)
```

Good (adapt to the actual API):

```text
one named operation with its required parameters
```

<a id="cs-017"></a>

## CS-017: Remove abandoned paths without hiding failure

- Purpose: Remove abandoned paths without hiding failure; prevent the failure described by the application condition.
- Surface: all. Apply when: Temporary edits, unused dependencies or fallback paths survive their purpose.
- Severity: major. Detection: context. Tool mapping: Ruff F401/F841; ESLint no-unused-vars; context review.
- Fix and reason: Remove unused experiments and dependencies; preserve required compatibility and explicit operational fallback contracts.
- Exception / normal control: Documented offline/degraded behavior may be valid if observable and tested; not every fallback is wrong.
- Evidence: SRC-006,SRC-007. Owner: #691.

Bad (intentional non-executable counterexample):

```text
except Invalid: return success_defaults
```

Good (adapt to the actual API):

```text
except Invalid as error: raise InputError("invalid manifest") from error
```

<a id="cs-018"></a>

## CS-018: Preserve exception meaning

- Purpose: Preserve exception meaning; prevent the failure described by the application condition.
- Surface: all. Apply when: An exception is caught at an application boundary.
- Severity: critical. Detection: data-flow. Tool mapping: Ruff E722; ESLint no-empty; context review.
- Fix and reason: Catch the narrow expected case, retain cause, and fail closed for invalid evidence or failed effects.
- Exception / normal control: Best-effort diagnostics/cleanup may continue with explicit observable failure; broad top-level handling may report and exit nonzero.
- Evidence: SRC-004. Owner: #688 shell/CI; #689 Python; #690 TS/JS.

Bad (intentional non-executable counterexample):

```text
except Exception: pass
```

Good (adapt to the actual API):

```text
except ExpectedMissing: return documented_absence
```

<a id="cs-019"></a>

## CS-019: Propagate process and pipeline status

- Purpose: Propagate process and pipeline status; prevent the failure described by the application condition.
- Surface: bash,powershell,python,typescript,javascript. Apply when: A child/pipeline can fail while the wrapper reports success.
- Severity: critical. Detection: data-flow. Tool mapping: ShellCheck SC2155/SC2181; process regression.
- Fix and reason: Check the exact child status before another command overwrites it; PowerShell native commands require LASTEXITCODE handling; inspect pipeline producers.
- Exception / normal control: Expected nonzero probes need a documented branch; blanket set -e or ErrorActionPreference alone is insufficient.
- Evidence: SRC-009. Owner: #688 shell/CI; #689 Python; #690 TS/JS.

Bad (intentional non-executable counterexample):

```text
tool; echo success
```

Good (adapt to the actual API):

```text
if ! tool; then exit 1; fi
```

<a id="cs-020"></a>

## CS-020: Validate Python boundaries before narrowing

- Purpose: Validate Python boundaries before narrowing; prevent the failure described by the application condition.
- Surface: python. Apply when: Parsed JSON, CLI or external bytes become trusted domain values.
- Severity: major. Detection: context. Tool mapping: Ruff; mypy existing profile; schema tests.
- Fix and reason: Reuse the existing validator; distinguish bool from int where schema does; reject malformed/unknown fields according to contract.
- Exception / normal control: Typed internal values need not be revalidated at every call; Any for opaque third-party internals requires a narrow reviewed boundary.
- Evidence: SRC-003. Owner: #688 shell/CI; #689 Python; #690 TS/JS.

Bad (intentional non-executable counterexample):

```text
count = int(payload.get("count", 0))
```

Good (adapt to the actual API):

```text
count = require_nonnegative_integer(payload, "count")
```

<a id="cs-021"></a>

## CS-021: Narrow TypeScript unknown honestly

- Purpose: Narrow TypeScript unknown honestly; prevent the failure described by the application condition.
- Surface: typescript,javascript. Apply when: External data is converted into a trusted type.
- Severity: major. Detection: machine. Tool mapping: tsc strict/noUncheckedIndexedAccess; typescript-eslint no-explicit-any when enabled.
- Fix and reason: Use existing runtime validation and discriminated unions; replace any/non-null/assertion escapes with actual proof.
- Exception / normal control: A justified library boundary assertion needs a stated invariant and negative control; assertions are not runtime checks.
- Evidence: SRC-004. Owner: #688 shell/CI; #689 Python; #690 TS/JS.

Bad (intentional non-executable counterexample):

```text
const item = JSON.parse(text) as Item
```

Good (adapt to the actual API):

```text
const item = parseItem(JSON.parse(text) as unknown)
```

<a id="cs-022"></a>

## CS-022: Own every asynchronous lifetime

- Purpose: Own every asynchronous lifetime; prevent the failure described by the application condition.
- Surface: python,typescript,javascript,powershell. Apply when: A task or promise outlives its request, failure handler or cleanup.
- Severity: major. Detection: context. Tool mapping: typescript-eslint no-floating-promises/no-misused-promises when enabled.
- Fix and reason: Await owned work; explicitly supervise detached tasks and bounded concurrency; propagate rejection and cancellation.
- Exception / normal control: Independent work can run concurrently; dependent writes must stay ordered. Fire-and-forget needs an explicit owner and error policy.
- Evidence: SRC-009. Owner: #688 shell/CI; #689 Python; #690 TS/JS.

Bad (intentional non-executable counterexample):

```text
items.forEach(async item => await save(item))
```

Good (adapt to the actual API):

```text
await Promise.all(items.map(item => save(item)))
```

<a id="cs-023"></a>

## CS-023: Bound external work and cleanup

- Purpose: Bound external work and cleanup; prevent the failure described by the application condition.
- Surface: all. Apply when: A child/network call can block a user path indefinitely.
- Severity: major. Detection: context. Tool mapping: Process tests and data-flow review.
- Fix and reason: Reuse the existing process/transport supervisor; bound total deadline, response size, child ownership and cleanup.
- Exception / normal control: Long-lived services need explicit lifecycle ownership rather than an arbitrary short timeout. Timeout does not prove descendants are gone.
- Evidence: SRC-009. Owner: #688 shell/CI; #689 Python; #690 TS/JS.

Bad (intentional non-executable counterexample):

```text
subprocess.run(argv)
```

Good (adapt to the actual API):

```text
subprocess.run(argv, timeout=deadline_seconds, check=True)
```

<a id="cs-024"></a>

## CS-024: Retry only a justified operation

- Purpose: Retry only a justified operation; prevent the failure described by the application condition.
- Surface: all. Apply when: Failure causes a repeated side effect or unbounded loop.
- Severity: critical. Detection: context. Tool mapping: Context review; failure-path tests.
- Fix and reason: Classify transient failures, retain total deadline, and use idempotency/compensation owned by the feature.
- Exception / normal control: No retry is valid for non-idempotent mutation; infrastructure cannot invent business success semantics.
- Evidence: SRC-009. Owner: #688 shell/CI; #689 Python; #690 TS/JS.

Bad (intentional non-executable counterexample):

```text
while True: send_payment()
```

Good (adapt to the actual API):

```text
retry_transient_idempotent_request(max_attempts=3)
```

<a id="cs-025"></a>

## CS-025: Compare protocol tokens with required case

- Purpose: Compare protocol tokens with required case; prevent the failure described by the application condition.
- Surface: bash,powershell,python,typescript,javascript. Apply when: Machine tokens or filenames cross runtime/OS boundaries.
- Severity: major. Detection: context. Tool mapping: PowerShell structural checks plus mis-cased negatives.
- Fix and reason: Match the producer contract exactly, including PowerShell operators, switch, Select-String and collection/filter APIs.
- Exception / normal control: Human-facing case-insensitive search is normal; filesystem case behavior must be exercised on the applicable host.
- Evidence: SRC-015. Owner: #688 shell/CI; #689 Python; #690 TS/JS.

Bad (intentional non-executable counterexample):

```text
$status -eq "PASS"
```

Good (adapt to the actual API):

```text
$status -ceq "PASS"
```

<a id="cs-026"></a>

## CS-026: Pin encoding at producer and consumer

- Purpose: Pin encoding at producer and consumer; prevent the failure described by the application condition.
- Surface: all. Apply when: Files/stdout cross JSON, PowerShell, Python or Node boundaries.
- Severity: major. Detection: context. Tool mapping: Cross-runtime fixture and native OS test.
- Fix and reason: Follow the existing UTF-8/BOM/newline contract and strict consumer; preserve byte hashes of frozen evidence.
- Exception / normal control: A BOM required by a specific external format is legitimate; PS 5.1 and PS 7 defaults differ.
- Evidence: SRC-016. Owner: #688 shell/CI; #689 Python; #690 TS/JS.

Bad (intentional non-executable counterexample):

```text
Set-Content result.json $json
```

Good (adapt to the actual API):

```text
[IO.File]::WriteAllText($path, $json, [Text.UTF8Encoding]::new($false))
```

<a id="cs-027"></a>

## CS-027: Implement the input domain, not fixture names

- Purpose: Implement the input domain, not fixture names; prevent the failure described by the application condition.
- Surface: all. Apply when: Production behavior branches on known test values.
- Severity: major. Detection: context. Tool mapping: Context review and held-out cases.
- Fix and reason: Implement the specified general operation; add an unseen negative and normal case.
- Exception / normal control: Named fixtures, protocol literals and deliberate test doubles are allowed outside production behavior.
- Evidence: SRC-006. Owner: #692.

Bad (intentional non-executable counterexample):

```text
if name == "test_case_7": return 42
```

Good (adapt to the actual API):

```text
return compute_from_contract(name)
```

<a id="cs-028"></a>

## CS-028: Keep the oracle independent

- Purpose: Keep the oracle independent; prevent the failure described by the application condition.
- Surface: all. Apply when: Expected results repeat the same algorithm as the implementation.
- Severity: major. Detection: context. Tool mapping: Review assertion provenance.
- Fix and reason: Use contract examples, independent arithmetic, metamorphic properties or an independent consumer.
- Exception / normal control: Tests may share setup and transport utilities; they must not share the decision being tested.
- Evidence: SRC-002,SRC-005. Owner: #692.

Bad (intentional non-executable counterexample):

```text
expected = implementation_formula(input)
```

Good (adapt to the actual API):

```text
expected = externally_derived_known_result
```

<a id="cs-029"></a>

## CS-029: Label evidence by the boundary actually run

- Purpose: Label evidence by the boundary actually run; prevent the failure described by the application condition.
- Surface: all. Apply when: A result is called live/E2E/native while dependencies are mocked or unrun.
- Severity: critical. Detection: context. Tool mapping: Existing observation/catalog validators plus context review.
- Fix and reason: Record actual entry path, runtime, substitutions, side effects and limitations using the existing evidence collector.
- Exception / normal control: Mocks are useful unit/integration controls; they cannot establish native-host or live-provider behavior.
- Evidence: SRC-002,SRC-005,SRC-010. Owner: #692.

Bad (intentional non-executable counterexample):

```text
mock_service(); report("live passed")
```

Good (adapt to the actual API):

```text
report(kind="mock-integration", live_status="not-run")
```

<a id="cs-030"></a>

## CS-030: Do not weaken acceptance to get green

- Purpose: Do not weaken acceptance to get green; prevent the failure described by the application condition.
- Surface: all. Apply when: A failing assertion/threshold is relaxed without a requirement change.
- Severity: critical. Detection: context. Tool mapping: Diff and acceptance/provenance review.
- Fix and reason: Repair the behavior or correct a demonstrably wrong oracle with evidence; preserve failures, skips and unknown values distinctly.
- Exception / normal control: An approved requirement change can change assertions with traced reasoning; legitimate environment SKIP remains not-run.
- Evidence: SRC-002,SRC-005,SRC-010. Owner: #692.

Bad (intentional non-executable counterexample):

```text
assert observed >= 0  # replaced exact contract assertion
```

Good (adapt to the actual API):

```text
assert observed == contract_expected
```

## Reuse decisions (CS-013 through CS-016)

Record intent, public signature and semantic/error/side-effect/ordering/encoding contract; history and reasons for change; consumers and their present/future requirements; a concrete attempted divergence counterexample; adoption/rejection and rationale; regressions. New APIs have no historical stability evidence. A future unconditional guarantee cannot be proved by finite tests. Unknown divergence means keep upper-level feature behavior separate. Logging mechanics, redaction, DB authentication/pooling/release and resource transport should use compatible shared infrastructure; queries, transactions, event content, business retry and compensation remain feature-owned. No duplicate-line quota can override this boundary.
