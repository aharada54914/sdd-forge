# RT004 strict JSON admission: bounded implementation plan

Status: implementation design, not a formal PASS or application instruction.

## Current evidence

Original-path test `tests/impl-review-adr-inputs.tests.sh --admission-json-only`
on the stationary-case-corrected validators returned 20 passed / 32 failed
(session 21506, exit 1; recorded in rt004-stationary-case-handoff-20260911.md).
Failing negatives mutate only the fixture ledger. These are malformed-input
admission failures, not proof of hostile file replacement.

## Existing implementation that can be reused

`plugins/sdd-quality-loop/scripts/check-workflow-state.sh:37` defines
`workflow_adr_json_members`. Its raw token walk retains duplicate decoded keys
per object, whereas ordinary jq object parsing loses them. Copy that specific
pure validation algorithm into the admission validator; do not source or run
the entire workflow script. Preserve its independent object-key sets so the
same key in distinct nested objects remains valid. A separate whole-object
parse must reject scalar and array roots. Raw UTF-8 validation must precede jq,
which otherwise may replace malformed bytes.

The PowerShell consumer already has a raw lexical implementation at
`plugins/sdd-quality-loop/scripts/check-workflow-state.ps1:1036`, but a shorter
alternative is strict UTF8Encoding decoding, JsonDocument.Parse of a single
document, and a recursive enumeration of object properties with a fresh
StringComparer.Ordinal HashSet per object. JsonDocument lifetime must enclose
all traversal and end in finally. Confirm compatibility with the repository's
supported PowerShell/.NET versions before selecting this alternative. Do not
convert to a hashtable before duplicate inspection.

## Placement and boundaries

Apply only to impl admission. In the existing manifest input loop, retain
authorization, exact component, link and regular-file checks before reading.
For the selected precheck entry, reject malformed UTF-8, multiple documents,
non-object roots and duplicate decoded members before any ledger write. For
the feature design entry, reject malformed UTF-8. Preserve BOM acceptance.
Use bounded, content-free diagnostics; do not echo JSON or design bytes.

Prefer private captured bytes for hashing and interpretation, and do not claim
that a pathname lexical check satisfies ADR0034 held-handle acquisition. A
first incremental parser correction may not make that claim; the ticket stays
open until acquisition and all consumers satisfy the full contract. Do not
apply the unfinished large runtime candidate merely to obtain its parser.

## Required checks before application

- Independent security/contract scrutiny of the concrete diff.
- Existing 52 JSON cases, with all 32 previous failures becoming rejections
  before synthetic-ledger mutation; preserve all 20 current positives/negatives.
- Existing 60 path cases, including normal files, hardlinks and case aliases.
- Add parser edge coverage if not already present: trailing comma, incomplete
  object, comments, same key in sibling objects, decoded escaped-key equality,
  and different-case keys remaining distinct.
- Validate original files only after authorized human application if the guard
  denies edits. No candidate executable copied under another name.
- Native Windows and downstream consumers remain separate mandatory evidence;
  macOS PowerShell and these local tests do not satisfy them.

No test expectations, historical review records, approval states, mandatory
CI checks or task completion states are changed by this plan.

## Concrete candidates, not ready for human application

- `rt004-json-bash-candidate-20260911.patch`: 58 added lines, SHA-256
  `34f8887c48b47928a4be8c286295841a9cb734f8546b6094e0bc6a19bd1acb10`.
  Reuses the existing raw jq member walker with its function name changed;
  adds strict iconv UTF-8 validation and a slurped single-object root check.
- `rt004-json-pwsh-candidate-20260911.patch`: 48 added lines, SHA-256
  `d03b126db37e51efdef354007f4335e9724f337fb09228e530b42cbd281d8e25`.
  Uses strict UTF-8 decoding and JsonDocument property traversal with ordinal
  per-object name sets, preserving one initial BOM.

At initial creation both `git apply --check` commands exited 0. Neither candidate was applied or
executed. The PowerShell parser's default nesting limit needs compatibility
review. Both candidates still leave pathname rereads for hashing/downstream
parsing; they do not yet satisfy same-captured-bytes acquisition. Independent
review was requested from `rt004_check_contract_review` with those limitations
explicitly disclosed. Do not infer 32 repaired tests from patch applicability.

## PowerShell candidate revision after independent review

The initial PowerShell hash above identifies the superseded candidate, not
the current revision. The independent reviewer found a compatibility defect:
JsonDocument's default nesting allowance differed from the existing parser.
The revised candidate explicitly sets MaxDepth to 1024. Boundary behavior
still requires tests; equal numeric settings alone do not prove parity.

The revision hashes the captured raw contentBytes, including any BOM, and
retains the validated precheck text for the subsequent round-consistency parse.
Other stages retain their existing file-hash and precheck-read paths. This
removes those impl-precheck pathname rereads but does not provide atomic
initial acquisition. Bash remains unchanged and incomplete.

After correcting unified-diff hunk counts and context, `git apply --check`
exited 0 on the revised PowerShell candidate. No production application,
candidate execution, regression success or formal PASS is claimed. The
updated data-only diff was returned to the same independent reviewer.

## Capture follow-up

The reviewer found no new confirmed Critical/Major in the PowerShell revision,
but requested proof that the saved precheck text is initialized before use.
The original source selects the first matching precheck at lines 520–523 and
617–619 using the same path expression; the intervening manifest loop verifies
every entry. The candidate now additionally initializes the saved text to null
and explicitly refuses null before interpretation, rather than depending on
implicit variable state. Patch applicability remains successful.

The Bash candidate now allocates an impl-only private directory using a
mktemp template ending in XXXXXX. Allocation failure stops admission. The
design/precheck captures feed the UTF-8 checks, JSON checks, raw hash, and
subsequent precheck consistency check. EXIT cleanup handles early failures;
normal cleanup occurs before the original ledger-reservation trap is installed.
Non-impl paths keep their existing behavior. This is content capture, not
safe held-parent acquisition, and does not claim defense against replacement
at initial open or same-identity processes modifying private temporary files.

Both updated patches passed `git apply --check` and were submitted for
independent delta review. No production files or tests were changed in this
follow-up, and the previously measured JSON result remains 20 passed/32 failed.
Remaining work includes review of the capture lifecycle, regression fixtures
for parser limits and allocation/read failure, authorized protected application,
actual original-path test execution, and the ticket's wider consumer checks.

## Bash capture revision: temporary files removed

The independent reviewer classified the temporary-file capture as Major for
same-bytes protection: a process with the same UID can replace the capture
between lexical checking and hashing. The previous capture-follow-up section
is historical and is superseded here, not evidence of acceptance.

The current Bash candidate removes that temporary directory and all cleanup
code. It holds base64-encoded input in a shell variable and decodes that fixed
value into each content checker and SHA256 consumer. Encoding is necessary
because raw Bash variables cannot preserve NUL bytes and command substitution
strips trailing newlines. The precheck has its own retained encoded value for
round consistency; design iteration does not replace that value. The original
pathname is still opened without held-parent acquisition, so that separate
requirement remains unresolved. Non-impl content is still read from its path.

The host's `/usr/bin/base64 -d` decoded a simple valid sample successfully;
this is only a utility compatibility probe, not execution of the candidate or
proof of all supported platforms. `git apply --check` of the new Bash patch
exited 0. The replacement was sent for independent review. No test count or
ticket status has changed.

## Final limited static-review disposition

Independent reviewer `rt004_check_contract_review` found the temporary capture
replacement Major resolved by the Base64 revision and no new confirmed
Critical/Major for stationary JSON validation. Its further recommendation to
reject an uncaptured precheck in the parent shell, not only inside process
substitution, is included. The original sha256_text function streams stdin
directly into sha256sum or shasum -a 256 without transforming the input.

Current candidate identities (both pass a combined git apply --check):

- Bash: `5f3e84b4009ceb67e20d68efb35d7e7246bb5999114b72872ceb20af29de59d5`.
- PowerShell: `3e2956d1912030bf28006a93d0f5a413349e01a0245c700be259ba82608bb723`.

The final four-line parent-shell check was sent for confirmation. These are
incremental strict-input fixes, not a PASS of the broader acquisition contract.
After protected human application, the assistant must execute the original
JSON and path regression drivers. Keep historical 20/32 and 60/0 evidence;
do not replace those results with predicted outcomes.

## Human application and original-path regression results

Human application backup: `/tmp/sdd-rt004-json.glcvgV`. Combined reverse
patch check exited 0, confirming both reviewed patches are present. The final
parent-shell guard was independently confirmed with no additional required fix.

Observed current hashes:

- validate-review-context-set.sh:
  `978368b883231a02817b948c784b938b28d1c313e7420521939d52ec77a759e7`
- validate-review-context-set.ps1:
  `af3537e3b54ed6b9a85d79cdac19c995f8f6d504f874d5a031a8e42c8cdb0438`
- unchanged tests/impl-review-adr-inputs.tests.sh:
  `ba009da41ae2d6f6216c751e846eb0a2d00163f83aa5e01bb787c70fb61628c2`

Assistant executed the original test driver, not a copied candidate:

- `rtk proxy bash tests/impl-review-adr-inputs.tests.sh --admission-json-only`:
  session 54779, exit 0, `ADR admission: passed=52 failed=0`.
- `rtk proxy bash tests/impl-review-adr-inputs.tests.sh --admission-path-only`:
  session 73853, exit 0, `ADR admission: passed=60 failed=0`.

Both runtimes and both impl reviewer roles executed, without reported skips.
The previous JSON 20/32 baseline is retained above; all 32 former failing
negatives now pass. Legacy, BOM, distinct nested-key, normal-file and hardlink
positives remain successful. These runs are macOS Bash and macOS PowerShell,
not native Windows. Parser-depth boundary additions, initial-open acquisition,
broader downstream consumers and formal ticket verification remain incomplete.
No CI dispatch, commit, push, merge, issue closure or formal PASS was performed.

GitHub read-only refresh in the same turn found 11 open PRs and no queued or
in-progress check runs. PR400 has 25 successful CheckRuns; PR405/403/245
conflict and have no CheckRuns. Remaining PR success/failure counts are
404=21/4, 402=21/4, 401=21/4, 394=23/2, 390=23/2, 381=15/11,
371=21/4. StatusContext entries are not counted as CI CheckRuns.

## Broader regression follow-up

Original-path `rtk proxy bash tests/impl-review-adr-inputs.tests.sh
--workflow-only`, session 81049, exited 0 with
`ADR workflow history: passed=140 failed=0`. Both Bash and macOS PowerShell
executed, including persisted-history and PowerShell observation fixtures.
This does not establish native Windows or atomic initial-open acquisition.

`rtk proxy bash tests/review-context-boundary.tests.sh` exited 1 at its
documentation citation check: the reference to validate-review-context-set.sh
line 245 no longer points to the review-context-invocation/v2 schema check.
The later functional fixtures in that driver were not reached. Documentation
citations and their test anchor table need synchronized current-code references;
the assertion must not be removed or counted as passed. No formal PASS,
commit, push, CI dispatch or main integration has occurred.
