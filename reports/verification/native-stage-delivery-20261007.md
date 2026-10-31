# Isolated native stage delivery — 2026-10-07

Diagnostic only. Disposable fixtures use synthetic predecessor evidence and their
own ledgers; no production reservation, review verdict adoption, task-state change,
installation, publication or merge was performed. Claude Sonnet was used.

Driver: `tests/unified-launch-native.py`, SHA-256
`25f3c3d2f992f94257f0ec015b0ad1f82f6d7187132d06c55c15f2523da81d67`.
Commands: `rtk proxy python3 -B tests/unified-launch-native.py --run-native`
with `--task-role a`, `--task-role b`, `--impl-role a`, or `--impl-role b`.

All fixture paths below are under
`/private/var/folders/7z/hjmz6jdj4wb40srf64sl368w0000gn/T/`.
Each retains `precheck.stdout`, `precheck.stderr`, `launch.stdout`,
`launch.stderr`, `launch-source-hashes.json`, and stage-specific launch artifacts.

| Route | Fixture | Result |
|---|---|---|
| Task B | `loop-fixture.4fWj5i` | Exit 0, `DELIVERY_OK`; synthetic predecessor evidence, not a formal verdict |
| Task A initial | `loop-fixture.392wI9` | Exit 1, strict reviewer JSON parse rejected Markdown fences |
| Task A authorized additional attempt | `loop-fixture.00bRhO` | Exit 1, same Markdown-fenced reviewer result rejected |
| Impl A | `loop-fixture.JkkSGG` | Exit 1, `impl Bash outside exact launch commands` |
| Impl B | `loop-fixture.9XxQuV` | Exit 1, `impl Bash outside exact launch commands` |

Task B delivery session: `bd9af86f-6bca-47c1-a936-1fc516e62b76`.
Prompt SHA-256: `956641c94da01c516a04e570c6539491e7b7ae22be058f7c6f4d8dcd8e665fb9`.
Transcript SHA-256: `aab960f07c04e50e6281989df18878011820d9f26753ae6b7eb3f90fe5bee912`.
Wrapper SHA-256: `f4bdf7e75505dedc2720d2dd9f4122799b3de660a08d76da6ac068526ab7a58a`.

Latest Task A session: `8898a888-0b33-4c86-80e0-0603438bf06d`.
Its `wrapper.json` is valid JSON with `is_error: false`, `subtype: success`, but
`result` starts with a Markdown JSON fence. The strict reviewer-result parse
correctly refuses it; wrapper success is not delivery success. The existing prompt
already requests only canonical JSON without Markdown. No parser relaxation or
further retry was performed.

Impl sessions: A `2e3b249b-a5c1-4665-8ca8-032670d7981e`,
B `e86bfdfe-4e1c-4ba8-8064-0d1dfcbb1d2e`. After hashing inputs and receipt,
both attempted `rtk proxy test -d domain; echo "exit=$?"`; A additionally tried
`rtk proxy test -d domain`. These are outside the exact admitted commands and
postflight correctly stops. The fixture has no active `domain` directory.
Domain SKIP determination still conflicts with manifest-only command access;
the source owner was notified. Rejected attempts were not hidden or counted PASS.

## Source pins

Latest Task A and the initial failed Impl runs:

- launcher: `e9bb0ce28c99beed8218e57eddc426673cb57af75d0c3640779326dc3da695b9`
- transport: `e7b529222cec9665c89c31b36e3765d6d968edcb710305dce0c1c342e4b0c273`
- probe: `b0da9d9cd9557417ddabbd94e27d7826ba6f2050b3d4e3ff5532c38b9cb9868e`

Successful Task B used earlier pins, not the above latest source:

- launcher: `6d78077259a90d7902909748f5eb2999218cdac6704ee26d509949099f0c3aa0`
- transport: `6ffd5057f5185cf664767659f6253818c4b586e4f1ce1b193b0b66254f9aba29`
- probe: `b0da9d9cd9557417ddabbd94e27d7826ba6f2050b3d4e3ff5532c38b9cb9868e`

No native process remains running. Quality native delivery was not run.
Production review, CI and native Windows/Linux verification are not established
by these macOS fixture runs.

## Impl conditional-input repair: additional isolated deliveries

After the independently reviewed conditional-state prompt repair, each Impl role
was executed once in a new fixture. The exact-command allowlist and strict
postflight validation remained enabled. An initial command omitted the required
`--run-native` option and exited at argument parsing; it created no native run.

| Route | Fixture | Session UUID | Observed result |
|---|---|---|---|
| Impl A | `loop-fixture.n2jlGC` | `a870023c-759b-487b-9851-50e4ae10e499` | Exit 0, `DELIVERY_OK` |
| Impl B | `loop-fixture.9CNf3K` | `1d99983c-d12d-466a-a571-49ca89463c8e` | Exit 0, `DELIVERY_OK` |

Commands were the driver command above with `--impl-role a` and `--impl-role b`.
Both fixture source manifests record these exact pins:

- launcher: `b00103cab4814d2ea45913df8dc5e340938ad603abbeb2e351f4e5fc3eaeda14`
- transport: `efa1f67b88f43047baf747c2af81d013c2cd53df341e9176a88f70acf5c30a3e`
- probe: `b0da9d9cd9557417ddabbd94e27d7826ba6f2050b3d4e3ff5532c38b9cb9868e`

Impl A delivery hashes:

- prompt (9,972 bytes): `4d18d1e700015b84604fa199c7f69c80abe0f209439cd194d4239ddb6b9fafa7`
- transcript: `aa6e7ba7c7861c72e84f37e468b9fb69d1ba9c2902a2b974da57a596aaac84ae`
- wrapper: `02a9d57c67ba3985b0d5a22048900d3f720a437250d73a54cd56e18a1cb683be`

Impl B delivery hashes:

- prompt (10,715 bytes): `5eb707935f124895c6430f6b291f383e87f7d8b97cc23cd2d65345861f959ebe`
- transcript: `19a8d80feb5d285f3b76154e370ddd6e6b4d3c89fdb6c847d9650fd5c9d80ff9`
- wrapper: `ab58af644ee54decc42c39b6e2481f1d208eb529d7120214ce89303d4a62bd2b`

Both drivers completed with `IMPL_NATIVE_DELIVERY_VERIFIED; predecessor fixtures
synthetic; no verdict adoption`. These results prove isolated macOS native
transport, not production review approval, CI, or Windows/Linux execution.
The initial failures above are retained. No Task A or Quality retry was performed
in this repair verification, and no native process remains running.

## Subsequent task and quality native delivery

All three isolated macOS Claude Sonnet executions exited 0 with DELIVERY_OK.
This supersedes the preceding pending-retry statement, not the retained failures.

| Route | Fixture basename | Session | Result |
|---|---|---|---|
| task A | loop-fixture.iZh3Iq | 2cc4a2ff-7ce7-40ac-b007-cbfad63876e8 | TASK_NATIVE_DELIVERY_VERIFIED |
| task B | loop-fixture.pxyxYg | ee257a2d-c2c7-43aa-977d-966a04a4a390 | TASK_NATIVE_DELIVERY_VERIFIED |
| quality | sdd-quality-native-rknc6j7b | e7ec274b-b0e7-452f-8211-66798684cbfa | QUALITY_SYNTHETIC_DELIVERY_VERIFIED |

Each fixture retains launch-source-hashes.json. Shared launcher hash:
`a9f1edb8d397cc4eaf3b8d65e749605a8230d33e03cd03638508dd0b6687cc6d`;
transport validator: `05c721b494144d6add63ac570728fdefbca2a29c8f204d0ea123c13d20fa931f`.
Task A probe: `38d55ce60c167433afed7e469724b78df953071f1d44be371bd0260d3cc0d9fe`;
task B and quality probe: `f471ea52f0f6c85be0ad674731c83a2475da287a9038d12ab5fdd797ce6dbf2f`.

Transcript hashes, respectively:
`c288c957b4c19cfd03e068c6c6db7d7a5765869cea34e0b775e08a4e454e9c54`,
`10ab5b5729d92b0114db7b28a4756b9930b9df1b0f879ce6eea44d0246f9f90e`,
`f964e1a8253180cc34c85514e246ca2b5c6f3ed29191c433767b829b9c546893`.

Task predecessors are synthetic. Quality used an isolated diagnostic Sonnet role,
not the canonical Opus evaluator. No verdict was adopted and source role/ledger
unchanged assertions passed. Formal quality model-contract resolution, applicable
CI and other operating systems remain unverified.

The first quality attempt (sdd-quality-native-yj2n08xd) failed before reservation:
probe scratch incorrectly required reports/verification. The shared probe now
uses the already-read ledger parent; focused regression and independent review
passed. The failed fixture retains only its synthetic initial ledger record.

## JSON review structured-output repair preflight

- Issue/task: A7 shared non-TTY launch; latest spec native diagnostic returned Markdown-fenced JSON while an impl-A diagnostic delivered successfully. This section records a proposed bounded repair, not a review verdict; prior failed and successful observations above remain unchanged.
- Owner checkout: A7 T-005 intake worktree; HEAD `25813ee4baf8ae8fff344a6c979da61fbd23d2c7`. The checkout is dirty with existing untracked shared launcher/transport/probe/tests and modified unrelated files. Preserve them; only transport, probe, dedicated structured-output test and this non-frozen report are owned for this repair.
- Risk: high/protected review transport. Affected contracts are per-stage CLI profile, caller-pinned session policy, exact native tool sequence, raw JSON result and `structured_output` equality. Task-specific normalized hash/receipt handling and quality plaintext evaluator behavior must remain unchanged.
- Required validation: focused command/policy/probe/formal/postflight positive and negative tests for spec, impl and task; quality unchanged negative; existing shared transport/launcher regressions; syntax; independent diff review, then separate isolated native diagnosis by the main owner. No reservation, native launch, installation or publication in this repair.

## JSON review structured-output repair result (candidate, not native proof)

The failed spec fixture `sdd-unified-native-aopr71o7` (session
`aa9db352-be48-48b6-a9d1-3c7521e1bd0f`) remains failed: its wrapper returned
Markdown-fenced JSON, so strict raw JSON parsing stopped delivery. The later
impl-A fixture `loop-fixture.BfBQtV` (session
`dc0ebf52-1f55-4447-9c22-85abd8310cd7`) remains DELIVERY_OK under its
then-current source. Neither observation is relabelled as proof for this edit.

The shared new-launch caller and probe both derive tools from `agent_tools(stage)`
and invoke `claude_command`; the candidate requires the output-only
`StructuredOutput` tool and `--json-schema` for spec, impl and task, while quality
remains plaintext. The session-local policy admits only this named output tool;
Read/Bash exact permissions and task hash/receipt normalization were not broadened.
Strict formal delivery and the probe require a final successful matching tool
result after ordered hashes, and strict postflight still parses raw JSON without
fence stripping and requires equality with `structured_output`. The historical
spec default (`strict=False`) prompt/receipt path remains covered by the existing
regression. Old no-output-tool test fixtures were updated to the new-launch
profile; no legacy-profile fallback was added to production launch.

Local results on the dirty owner checkout: structured-output 11/11,
non-TTY contract 12/12, unified-launch-order 7/7, unified-task-launch 9/9,
quality transport 7/7; Python syntax compilation succeeded. Source/test SHA-256:
transport `b2bc36343a439af1fc46174234b60bedaa84430ef4dc758740d8b500186e0320`,
probe `62e152c41df522ab1cd981d089f10167bcc2c64522ebc1a453bce0b73f57b636`,
structured-output test `5b0f1f3ac86032df0128ed49b71daea3147dacd5e7bb8654c17839e3e3320a16`,
existing contract test `f8c421b905bca8a7d889203dc349a2c9d82570c28a2d93cd1a434b47a204592a`.
Independent diff review, current-head CI and native spec/impl delivery under
these pins remain pending; no ledger reservation or formal review was run here.

## Subsequent isolated delivery and transport correction

The preceding pending statement describes that checkpoint, not the results below.
Independent diff review of its four pins found zero Critical/Major findings and
independently reran all 46 focused tests successfully. The original-path
`tests/review-context-boundary.tests.sh` completed with exit 0, including the
reported 116/0 investigation-input and 84/0 link-boundary checks.

Under that structured-output candidate, spec delivery succeeded in
`sdd-unified-native-i2uiiag9`, session `b534f098-83bb-45cb-9a93-eeb4f9be4f21`
(transcript `d61ec7d1b38ad7e86834412f47532e5aa4adeeb554150ae227f6a53c2a94bddc`).
Task-A delivery succeeded in `loop-fixture.OKQFs0`, session
`f3a5c5ea-d925-41bb-8b61-2a89e7cec634`
(transcript `8d6ca5828fe23e932b1e600931299b9ef900f8009cba1291f1c843586e8aa889`).
These are isolated delivery results; task predecessors are synthetic and no
production verdict was adopted.

Impl-A session `70c709c3-8408-4df3-935b-a7972305386e` in
`loop-fixture.zgqWVb` failed transport validation. Its first prompt matched all
9,972 bytes; the CLI then inserted its fixed `isMeta: true` structured-output
enforcement notification. The one-user-string assertion wrongly rejected this
internal notification. Preserve this failure; it is not a successful launch.

The bounded correction admits that exact notification once, only for strict
JSON stages after the original prompt and all required hashes, with no pending
tool, and before StructuredOutput. Ordinary additional user input, unknown or
false meta flags, early/late/duplicate notifications, quality and legacy use
remain rejected. New positive cases failed against the prior validator and
passed after repair. The same 46 focused tests passed; independent inspection
and rerun found zero Critical/Major findings. This is independent diff review,
not a formal SDD verdict.

Current corrected pins: transport
`5916111102b464772b15b21d405962b2027c2287583165ccb9dad0eaddfc642f`;
structured-output test
`20315c7d2ef9e6fed9066136991bf4e304dbe5381ec25d5e715ba94bc9b64a5b`.
Native delivery under these new pins remains pending. Canonical quality model
selection (Opus role versus Sonnet-only authority), aggregate conditional-input
selection, hosted CI and verified baseline promotion remain separate unresolved
conditions. No installation, publication or production ledger change is claimed.

## Ordered-command prompt repair

The next Impl-A diagnostic (`loop-fixture.AOhG7B`, launch
`079ccbf6-a6b0-46e9-8e3e-af98b72d0677`) exited 1: required hash successes
arrived in order `[10,0,1,2,3,4,5,6,7,8,9,11]`, not `0..11`.
This was a real ordering violation, not a false validator rejection. The prompt
displayed the two control commands before its ordering instruction. No result
from this diagnostic is adopted as a formal verdict.

The strict prompt now lists every exact command in execution order:
admitted inputs, boundary, input digest, receipt digest. Legacy spec prompts and
permission/ordering checks are unchanged. The new prompt regression failed
before the repair and passed afterward. Independent review verified the pins,
found zero Critical/Major findings, and reran structured-output 12, contract 12,
order 7, task 9 and quality 7 tests successfully (47 total).

Pinned transport: `149bd3b91fc0da8e06a23a6ddc9c8d7bfded6f78466db6a87f0b9129e8c63022`.
Pinned structured-output test: `400145e9558ebfb0dede55f09c25d631c3646fd92857de4a921401f605315208`.
Native delivery is being checked separately; this diff review is not formal
review, production reservation, CI or baseline promotion.

The pinned Impl-A isolated run completed with exit 0 in `loop-fixture.D9qv64`:
`DELIVERY_OK`, session `8952e9ab-b975-4f85-b187-5adbcbb127a4`, prompt 10,929
bytes (`d52086f515b45306c558231d0dd74fe11cbcba91cb4121810915494024a66bf5`),
transcript `caacf82715754c8cf59ac1de8bd9ede3cab28c72a10f2d0b601dfe72860498be`,
wrapper `998e1cbb73a498a1f1ca79b262bd00f9247af9a84a49e80f9e6494a78df01948`.
The actual launcher completed its preflight/reservation/delivery path against
the isolated ledger. Predecessor fixtures were synthetic; no production verdict
was adopted.

Impl-B completed with exit 0 in `loop-fixture.aE5f8T`, session
`bad98a45-fb37-48ac-b14b-fc82dc8b8d17`: `DELIVERY_OK`, prompt
`2d56705ec944c429b7c07c49d25557065396c6cf084079abb1faee708ab871f7`,
transcript `214d4f5d956625174ea1a24939938feed2b0e607e9a324f2ddfb306d7aa8e873`,
wrapper `02bfea7322347ab5bc1e74eea0729648a0ab804ff0966a6b39b3e467515d8ba7`.
Task-B completed with exit 0 in `loop-fixture.Of6KU3`, session
`a701762f-2ae7-4884-a32f-c5694ed12dbc`: `DELIVERY_OK`, prompt
`50dc6f73cef4acff7e9abc5e5b0972e7aba61de5a1b462812480ebc25bbe52d0`,
transcript `fdcba8c83d5dff3ddfe8e70e83dc193c339907019514ae57cf5badf6cb9f0be3`,
wrapper `4a74bcab3abf8c839c106368b3b51ea083683790db0d860194f60a0162b81bf4`.
Both used the pinned transport above and isolated ledgers with synthetic
predecessor fixtures. Neither result is adopted as a formal review verdict.

Independent read-only caller audit found no Claude nonTTY bypass in spec,
impl, task or quality skill launch instructions. Ordinary-host paths remain
separate. The launcher checks inputs, canonical preview, live CLI permissions,
dependency/pin stability and argv parity before its single reservation call.
The audit also confirmed ten Python regression suites and PowerShell hash
normalization registration in local runners and CI. Hosted CI was not run.
Aggregate selection semantics and the canonical quality-role model remain
unresolved; these successes do not waive either contract decision.

## Current-pin regression and Task-A rejection

The ten registered Python suites completed with exit 0: freeze 2, impl contract
12, launch order 7, task launch 9, structured output 12, quality transport 7,
spec input verification 2, conditional inputs 14, downstream manifest 2 and
conditional history 2 (69 test methods). The PowerShell shared-normalization
suite also completed with exit 0, including CRLF, case and invalid inputs.

Task-A session `be7d5e87-2e1c-47de-86ec-21781f0b0919` in retained isolated
fixture `loop-fixture.UMOdoW` stopped with exit 1:
`LAUNCH_STOPPED: impl hash commands were not serialized`.
The real CLI permission probe passed, but the formal transcript issued hash
index 11 before receiving index 10's result (zero-based transcript rows 167,
168 and 173). Independent read-only inspection confirmed this was overlapping
hash execution, not a Read/hash collision. The prompt already required waiting
for each result. The rejection is valid; no validator or permission was relaxed.
The failed fixture and reservation remain intact; no verdict was adopted.
One fresh isolated retry completed with exit 0 in `loop-fixture.ejcv4h`:
`TASK_NATIVE_DELIVERY_VERIFIED`, session `5afb28e0-6312-43d1-9357-0d794c25959b`,
prompt 13,832 bytes, SHA-256
`cd3d0af4797be812a7512372cb15d2d776ef554f58260edb8049c0feb4309036`,
transcript `8b58544133c920e32869a1841db8d2fa9563d9c937d9e8f86810c5475f156ec7`,
wrapper `9841b34dc61855bfc3cbb6407f49966b497e7e39bdad24795d9187cc97b14a79`.
The strict ordering check was unchanged. This proves isolated delivery under the
current pins, not model determinism or adoption of synthetic predecessor verdicts.

The follow-up independent end-to-end diff review found no new Critical/Major
findings. It checked all four nonTTY callers, shared diagnostic/formal argv and
exact permissions, input/dependency checks, native probe, pin rechecks, preview
comparison, the single reservation and strict postflight. It confirmed the
transport hash above and that the probe preserves the invocation and ledger.
This development review did not execute another native session or adopt a formal
verdict; hosted CI and known contract decisions remain separate.

### Current-pin quality delivery (2026-10-07 JST)

`tests/unified-launch-native.py --run-native --quality` exited 0 in
`sdd-quality-native-vjp9e_am`, session `25596079-66c9-49cb-91f9-21a21bc9e44e`.
The common launcher returned `DELIVERY_OK` and the driver confirmed
`QUALITY_SYNTHETIC_DELIVERY_VERIFIED`. Prompt: 9,299 bytes,
SHA-256 `a0ad325e203ab13710fa83ba61a58bbbb3f3c6785d52294888a700995fe38b8a`;
transcript `f8b5f7135a05494bc4ac9e35f048a7d82352c24e75407fe183c506441f7b08a8`;
wrapper `404f59d2a325259b549c77645ce04ca5bddfd462a5376eacda2e66e632ffa10b`.
The fixture asserts that the canonical evaluator role and production identity
ledger remain byte-identical. Only the disposable fixture uses Sonnet instead
of the canonical Opus role. This verifies the real shared transport path, not
canonical model admission, formal quality acceptance, CI or issue completion.

### Current-pin spec delivery (2026-10-07 JST)

`tests/unified-launch-native.py --run-native` exited 0 in
`sdd-unified-native-du70l39r`, session `abbf6129-28e6-4494-a810-e06b438c5b97`.
The shared launcher returned `DELIVERY_OK`; the fixture ledger contains two
records and the driver returned `NATIVE_DELIVERY_VERIFIED`. Prompt: 7,712 bytes,
SHA-256 `f7cc06213de0fd43e380bd5525ce947fb64bf679c63c89b64d0232801845edf0`;
transcript `9c6b9c71ca5b80f07d3629f0ef27899912b64604be21846a49ceee8c1480786f`;
wrapper `78a20f6b33545a53608a5f0282e94143aee932cad747ef6281203b51a5f1f9e8`.
This replaces reliance on the earlier transport pin for spec delivery coverage.
No fixture verdict was adopted into a production review or task state.
