# RT-20260908-004: lexical candidate checkpoint

Date: 2026-09-09
Status: incomplete patch data; NOT ready for human application.

Companion checkpoint: `rt004-precheck-generation-candidate-20260909.md`.
Bash precheck generation/verification candidate SHA-256:
`31af58442668921a310a705e57d1c3438bb5fa120b999bb30c4e369db83ccb72`.
That partial companion is also unapplied and unexecuted; downstream work below
is not complete. Earlier checkpoints are preserved as historical observations.

Candidate: `adr-runtime-lexical-candidate-20260909.patch`
Initial lexical-only SHA-256: `f3536aba0724a63815364183f977a4d0123b731b8cbae907299906e634e01778`
Previous path-check candidate SHA-256: `a1196293fe17ca30f02dd945cf20b0c19b97cce2aa94ddcfb09d441bf580a0d2`
Previous Unix-type candidate SHA-256: `0ffaae73c59f3fee109e6dceba1c51ff63a54485f624bddeff8eb638d65bc12f`
Previous binding-helper candidate SHA-256: `ad4949296e6b8d93e8bb93e560892f1ffd281b6f8a808877ccb23fe3cc1e9674`
Current admission-call-site candidate SHA-256: `ebbb6f890c72ae6f375608d26cb764d3639435be7dba4f79b4f1bde0e7a5cb1c`

The candidate now includes Bash and PowerShell restricted declaration lexers.
No protected runtime file was edited or copied for execution. This is neither
an independent review verdict nor a quality-gate result.

## Primary source review

The two slices follow the approved single-line, maximal-delimiter-run grammar,
with matching fence state, indentation exclusion and odd-backslash escape
rules. PowerShell uses explicit case-sensitive comparisons, ordinal set/sort,
and byte-preserving decoding so automatic BOM removal does not silently change
the fence grammar relative to the C-locale Bash parser.

No Critical defect was identified in this source inspection of the two helper
bodies. This does not approve the overall repair: both helpers are unused.

Warnings and completion requirements:

1. Connect the helpers to complete-set admission, with explicit rejection of
   every extraction/read failure. Bash's actual caller sets `set -euo pipefail`
   at `validate-review-context-set.sh:3`; PowerShell sets Stop at
   `validate-review-context-set.ps1:12`. Those settings alone do not prove a
   future conditional caller handles a failed extraction correctly.
2. Add shared fixture assertions for BOM/non-ASCII bytes and final line-ending
   boundaries before claiming cross-runtime equivalence. Byte-preserving decode
   is a source-level design choice, not measured parity evidence.
3. Finish raw-path/case/symlink checks, precheck generation and verification,
   contract binding, persisted/task-stage validation, and next-round semantics
   specified by the approved plan. A lexer alone grants no safe ADR authority.

## Tester handoff

No candidate execution, syntax check or application check was performed. Do not
extract and execute these protected-validator slices as a workaround for the
recorded protection denial. The prior unchanged-runtime baseline remains
84 passed / 64 failed across 148 admission cases, as recorded in
`rt004-lexer-boundaries-20260909.md`; none are results for this candidate.

The final package still needs actual consumer regressions and native mandatory
CI after authorized human application, as well as formal independent review.
Do not ask the human to apply this partial patch. Keep the ticket open and
preserve historical failures. No commit, push, merge or task-state change.

## Path-check slice and primary review follow-up

Added component-by-component actual-entry spelling checks to both candidate
runtimes. Bash checks directory access, symlinks and final `-f`/`-r`.
PowerShell uses ordinal entry-name comparison, rejects ReparsePoint attributes
at every component and checks parent-directory/final-file shape. Its future
hash/read caller must propagate access failures rather than accepting an empty
result. These helpers, like the lexers, are not connected yet.

Primary review disposition: NEEDS_WORK for the package; not a formal verdict.
Do not equate FileInfo/Leaf/Device checks to proven POSIX regular-file exclusion.
Special-file rejection (including FIFO without attempting a potentially blocking
content read) needs a demonstrated solution. Bash `-L` is also not yet evidence
that all relevant Windows reparse points are rejected. These are unresolved
cross-platform authorization risks, not accepted limitations or a scope waiver.
Require corresponding negative tests before approving the completed package.

Read-only inspection also confirms the existing authorization checks occur
before current per-entry filesystem checks (`validate-review-context-set.sh`
manifest loop and `.ps1:515-548`). The new complete-set validation must inspect
the pinned precheck/design safely before parsing them, even when the invocation
omits every ADR; adding only a per-ADR path branch would be insufficient.

Patch text hunk counts were checked without applying or executing candidate
code: old/new counts are 1/80 and 1/103. Initially miscounted headers were
corrected. This is patch-data structure inspection, not a syntax, applicability,
runtime, regression or parity test. No old baseline was rerun unchanged.

Fresh GitHub query: all seven open PR heads equal those in the prior checkpoint;
no CheckRun is live. PR400 has no failed CheckRuns but unresolved formal review;
PR245 has no Actions evidence. The other five PRs retain failed CheckRuns.
No unchanged CI run was restarted and no merge or issue closure was performed.

## POSIX special-file metadata follow-up

Read-only diagnostics on macOS / PowerShell 7.6.2 (all exit 0) observed:

| Actual path | .NET type | Attributes | Leaf | UnixStat.ItemType |
| --- | --- | --- | --- | --- |
| `/dev/null` | FileInfo | Normal | true | CharacterDevice |
| `/Users/jrmag/sdd-forge/README.md` | FileInfo | Normal | true | File |
| `/Users/jrmag/sdd-forge/docs` | DirectoryInfo | Directory | false | Directory |

Commands used `Get-Item -LiteralPath ... -Force`, `Test-Path -PathType Leaf`
and metadata projections only. A separate `Get-ChildItem -LiteralPath /dev
-Force` lookup with ordinal name equality also returned a non-null UnixStat
property and CharacterDevice for null. No special-file contents were opened.
These observations disprove the previous FileInfo/Device/Leaf exclusion, not
merely indicate a hypothetical gap.

The patch data now additionally requires a present, non-null UnixStat and exact
ordinal ItemType `File` on non-Windows hosts. No fallback accepts unknown types.
PowerShell's [Unix platform type definitions](https://raw.githubusercontent.com/PowerShell/PowerShell/master/src/System.Management.Automation/CoreCLR/CorePsPlatform.cs)
distinguish File, CharacterDevice, NamedPipe and Socket. Its
[provider output implementation](https://raw.githubusercontent.com/PowerShell/PowerShell/master/src/System.Management.Automation/namespaces/ProviderBase.cs)
attaches GetLStat metadata and uses null on retrieval failure. These are inspected
upstream master sources, not a claim that their exact bytes match the host build.

Primary source review of the incremental change: no new Critical finding;
short-circuit null checks precede dereferencing, type equality is ordinal, and
content is not read to identify the type. Overall package remains NEEDS_WORK.
Metadata is a point-in-time observation, not protection against subsequent path
replacement. Windows Bash reparse handling remains unresolved.

Tester disposition: candidate NOT executed or applied. Patch-data hunk counts
are now 1/80 and 1/112, both consistent. This is not a runtime test. Required
future consumer tests include regular-file success, device/FIFO/socket rejection
without blocking, missing/null metadata rejection, symlink/reparse rejection,
and access/read failure propagation. Only the metadata controls above have been
observed this turn; do not report those future regressions as passed. Historical
84/64 unchanged-runtime results remain unchanged. Human application is still
premature; no protected runtime, frozen verdict, commit or PR state was changed.

## Complete-set binding helper checkpoint

Patch data now includes Bash `verify_adr_precheck_binding` and PowerShell
`Get-VerifiedAdrPrecheckBinding`. Both restrict use to implementation reviewers,
require exactly one canonical precheck pin, check its raw file hash before
parsing, bind feature/attempt/round to its path, and validate primitive types.
They compare the pinned design hash to the invocation and actual design file,
derive its complete ADR declaration set, require an exact sorted unique precheck
set and matching invocation entries, and verify safe paths and actual ADR hashes.

Primary source review found a PowerShell collection-coercion risk in schema and
feature comparisons; explicit string checks were added before comparison.
Bash command substitutions and file/hash reads explicitly propagate failures.
This is source inspection, not independent approval or measured runtime parity.

The helpers remain **unused**. Admission call-site integration (including when
every ADR is omitted), legacy/extension detection, the other runtime consumers,
and cross-platform filesystem regressions remain unfinished. No existing failure
has been reclassified. Latest actual-runtime baseline is 100 passed / 64 failed
across 164 cases, documented in `rt004-filesystem-boundaries-20260909.md`; those
results are for unchanged validators, not this candidate.

Patch-data hunk counts were checked as 1/139 and 1/189, matching the headers.
The SHA-256 above was recomputed. No candidate application, extraction/execution,
syntax check or applicability test was performed. Package disposition remains
NEEDS_WORK and not ready for human application. No commit, push or merge.

## Admission call-site checkpoint

The candidate now connects the helper calls in both admission implementations;
the preceding "unused" descriptions refer to earlier candidate revisions only.
There is still no live runtime modification. The patch's pre-entry inspection
checks already role-authorized canonical implementation prechecks for extension
presence, after safe-file and pinned-hash checks. An absent extension leaves an
empty additional allowlist; a present null or malformed set goes through the
complete binding verifier and is rejected. Inspection is independent of whether
the invocation contains any ADR entry, so omitting all ADR entries does not
bypass extension validation. Only fully verified exact path/hash pairs may
supplement the existing allowlist. Raw reviewer-report exclusion, later raw hash
checks, summary rules and ledger reservation remain in place.

PowerShell validates raw input entry types, exact keys, canonical paths,
uniqueness and hashes before passing entries to the new helpers. Bash already
validates entry types, keys, hash syntax and uniqueness before this call site.
Both reject prechecks outside the existing feature/role allowlist before reading
their contents. Failed parsing/read/hash operations cannot publish authority.

Primary source review: no new Critical finding in these call-site changes;
overall package remains NEEDS_WORK. Warning: the earlier safe-file inspection
also runs on legacy implementation prechecks. Confirm compatibility with valid
historical evidence after application; do not equate the old acceptance of
malformed or unsafe declaration files with a compatibility requirement. Known
Windows Bash reparse and byte-boundary coverage gaps remain. Seven downstream
runtime consumers and formal independent review are still unfinished.

Patch-data inspection corrected initially inaccurate new hunk headers and
verified all six old/new counts and cumulative new start positions:
Bash 1/139, 3/30, 2/7; PowerShell 1/189, 1/37, 3/5.
This is neither an applicability test nor a candidate execution. Live validator
diffs remain empty. `git diff --check` succeeded. No CI restart, commit, push,
merge, issue closure or frozen-verdict update was performed.

## 2026-09-10 admission JSON-stream regression and independent review

The earlier call-site assertion that omitting every ADR cannot bypass extension
validation was too broad. Independent advisory review of candidate SHA-256
`ebbb6f890c72ae6f375608d26cb764d3639435be7dba4f79b4f1bde0e7a5cb1c`
by `/root/rt004_check_contract_review` found three Major issues: hash-then-reopen
precheck/design reads, duplicate JSON members lost during object conversion,
and a Bash multi-object stream producing a presence string other than exactly
`present`. This is not a formal gate verdict. The reviewer stopped after an
additional source read was denied; PowerShell root reparse handling remains
unconfirmed, not approved.

The original-path test driver now has `--admission-json-only`. It exercises
legacy and explicitly empty ADR bindings alongside two hash-pinned malformed
streams (extension present and absent), for both reviewers in both runtimes.
The streams contain exactly two top-level objects and their actual malformed
bytes are pinned in the invocation, so stale hashes cannot explain rejection.
Negative cases require rejection before identity-ledger mutation.

Measured result: **12 passed / 4 failed, exit 1**. The four failures are Bash
reviewer A/B accepting both streams and changing the synthetic ledger. PowerShell
rejects both streams for both roles. `bash -n` passed. Driver SHA-256:
`fde6c4c488ad108ed84c6fa83aecdffb878cd112ba1136f131150f5e90122e97`.
The earlier full-suite result (249 passed / 64 failed) predates these additional
tests; a new full-suite result has not been measured.

Only patch DATA was changed: Bash presence detection now slurps and requires
exactly one top-level object before choosing present/absent. Current candidate
SHA-256:
`80bda461bf769dd2beaefa00d22c66e4b3c75869e45b14944982f0a370a23f08`.
`git apply --check --unidiff-zero` succeeds; no candidate was applied or executed.
The zero-context flag is necessary for this existing patch format. This static
correction does not resolve the duplicate-member or snapshot/safe-open findings,
and is not GREEN evidence for the live implementation.

Original admission implementations remain unchanged:

- Bash: `04e01b60cac4b8ccda12df069013a6052cd6825a1430256d59ccdf837a3af2f8`
- PowerShell: `832a00cbd9d9516f990411a684c5f671e8b8d5e92cc8f96d0ed9de4828c38187`

Next required work is duplicate-member rejection on the same byte snapshot used
for hashes, presence and declaration extraction, then safe-open/native Windows
verification and independent review of the complete corrected candidate. Do not
request human application of this partial candidate. Keep the ticket open and
all historical FAIL records intact; no commit/push/merge or status promotion.

### Duplicate-member TDD continuation

The next original-path execution of `bash tests/impl-review-adr-inputs.tests.sh
--admission-json-only` completed with **16 passed / 16 failed, exit 1**.
Driver SHA-256 is now
`efebe34093c38f606a25f03c6b0a07a2e66d823ddf26ad4d1aea0ab61e2eac66`.
Added cases preserve raw repeated members rather than round-tripping them through
an object serializer: top-level `adr_inputs`, its Unicode-escaped alias, and a
nested escaped alias. Each malformed input is pinned by its actual SHA-256;
design is empty and the effective ADR array is empty to avoid an unrelated
missing-ADR rejection masking the parser defect. A distinct nested-key positive
control passes for both roles and runtimes.

All twelve duplicate-key negatives incorrectly exit zero and append a synthetic
ledger reservation (three modes times two roles times two runtimes). The four
earlier Bash stream failures remain. All twelve normal controls and the four
PowerShell stream rejections pass. These are expected RED results, not resolved
findings or a product acceptance result. The test session is terminal.

Candidate DATA now incorporates the existing raw-member token/frame checks from
the workflow candidate helpers, with admission-specific names. The checks occur
before extension presence is interpreted; the PowerShell presence conversion
uses the same text that passed that lexical check. Candidate SHA-256:
`8a07f367ae59e9739c9f856b29b620864cd5a2764da10f33f81e13a2b376d285`.
`git apply --check --unidiff-zero` passes. No protected implementation was edited,
no helper was extracted/executed, and no candidate GREEN result is claimed.

Primary review disposition remains NEEDS_WORK: Bash still reopens its input
between raw checking and object parsing, both runtimes still reopen between
hashing and binding interpretation, and design extraction still rereads a path.
The raw check alone is not a race fix. Same-byte snapshot regression and wiring,
safe-open behavior, independent review and native Windows evidence remain
required before human application. Existing full-suite evidence is unchanged.

Live GitHub observation in this continuation: 11 open PRs and no running check
jobs. #400 has no failed checks but is BLOCKED; #245/#403/#405 are DIRTY and
must not be treated as green solely because their status contexts succeeded.
#371/#381/#390/#394/#401/#402/#404 retain failed checks. No unchanged CI was
restarted and no merge or issue closure was performed.

### Admission snapshot and encoding continuation (2026-09-10)

Reconfirmed the human-applied workflow validator hash:
`291ee7531594757d6ebc04c144bb8b35938f7715ae76665c9bdf723df09b1ff5`.
The existing original-path workflow-only 137/0 result remains valid for that
unchanged source. It was not rerun or presented as a new measurement.

Admission candidate DATA now uses a private Bash snapshot lifetime for precheck
and design, and an in-memory PowerShell byte snapshot for each. Hashing,
extension detection, duplicate-member validation, and precheck parsing consume
the same acquired precheck bytes. Design hashing and restricted declaration
extraction likewise consume one acquired byte sequence; PowerShell retains the
byte-oriented Latin-1 projection for parity with Bash's C-locale lexer. Strict
UTF-8 validation occurs before interpretation; a single leading JSON BOM stays
in the hash but is omitted from lexical checking. These are candidate changes,
not executed production fixes. Candidate SHA-256:
`dfabd7fbde89ccf510326bc984ebe0cfbade47e428d67378905a9f632c5dcd67`.
Hunk counts were recomputed and `git apply --check --unidiff-zero` exited 0.
No protected source was applied, extracted or executed under another name.

Added original-path admission fixtures for invalid UTF-8 in the precheck and
design, plus a valid leading JSON BOM control. Pins cover the actual bytes,
and malformed fixtures have no ADR invocation entry to mask the decoding defect
with an unrelated role-unlisted error. The existing ledger preservation
assertion remains required on every rejection.

Command: `rtk proxy bash tests/impl-review-adr-inputs.tests.sh --admission-json-only`
Result: **20 passed / 24 failed, exit 1**, terminal session 92218.
Test driver SHA-256:
`14fff279e53b5c9acb1ba4df37d405ac7e62c3207a47494d6cc468c9def8be0a`.
Both runtimes and both roles accept the two invalid-UTF-8 inputs and mutate the
synthetic ledger (eight new RED cases). All four BOM controls pass. The previous
sixteen negative-case failures remain. Bash syntax validation exited 0.
This is defect reproduction, not a product PASS or a candidate GREEN result.

The admission implementations remain unchanged at
`04e01b60cac4b8ccda12df069013a6052cd6825a1430256d59ccdf837a3af2f8` (Bash) and
`832a00cbd9d9516f990411a684c5f671e8b8d5e92cc8f96d0ed9de4828c38187` (PowerShell).

Primary review: **NEEDS_WORK**, no ticket closure. Snapshot wiring addresses
the identified hash-then-reopen shape statically, but it is not proof of atomic
no-follow opening: directory-entry checks can race the initial content open.
PowerShell root reparse protection, deterministic read-boundary regression,
snapshot cleanup/failure coverage, native Windows evidence, and independent
review of the complete candidate remain pending. Preserve previous FAILs and
reservations. Do not request human application of this partial candidate; do
not commit/push/merge or promote review/task state on this evidence.

### Admission root-object continuation (2026-09-10)

Independent DATA review identified an additional Major: PowerShell's object
conversion can enumerate a one-element JSON array, making a later IDictionary
test insufficient. Added single and nested root-array fixtures before changing
the candidate. Terminal session 52690 ran the original-path command
`rtk proxy bash tests/impl-review-adr-inputs.tests.sh --admission-json-only`:
**20 passed / 32 failed, exit 1**. All eight added combinations (two root-array
shapes, two runtimes, two roles) incorrectly accepted and changed the synthetic
ledger. This is RED evidence only, not candidate execution.

Test driver SHA-256:
`d074a514e59f371e36f0d96d1ba42906f09cc8d421e188612d85a4e2506fd838`.
The DATA PowerShell parser now requires its root value token to be an opening
object brace before consuming or converting it. Bash already requires exactly
one object via its slurp validation. Updated candidate SHA-256:
`0cfa88d533f22b4940bd90626329846411e09e494b92533fdccd80504e2b9ba1`.
Recounted patch hunks; applicability-only `git apply --check --unidiff-zero`
exited 0. Requested bounded independent follow-up on this three-line change.
No protected source application or candidate execution occurred. Initial-open
race, root reparse protection, read-boundary/cleanup tests and native Windows
evidence remain unresolved; the previous NEEDS_WORK decision is unchanged.

Bounded independent follow-up (`rt004_check_contract_review`) confirmed the
root-array Major is statically resolved at this candidate hash: root arrays are
rejected before ConvertFrom-Json, nested member arrays remain valid, and trailing
JSON values remain rejected. This finding closure is DATA-only and does not
constitute candidate GREEN or formal gate PASS. Other reservations remain open.

### Original-path symlink regression coverage (2026-09-10)

Added four fixtures varying only path traversal after raw-byte pins are built:
precheck file symlink, precheck parent symlink, design file symlink, and design
parent symlink. Each uses zero ADR entries so the not-yet-applied ADR allowlist
extension cannot accidentally provide the rejection. The unchanged legacy and
zero-bound controls must still succeed for both roles in both runtimes.

`rtk proxy bash tests/impl-review-adr-inputs.tests.sh --admission-path-only`
completed in session 58222: **24 passed, 0 failed, exit 0**. All 16 negative
cases rejected without changing their synthetic identity ledger; eight controls
succeeded. Full output: `rt004-admission-path-original-20260910.log`.
`bash -n` also exited 0. Test SHA-256:
`ec26f1a3ff490b9a50d84aa4ca3a198f8c3c16eb5d8356c499ba6b422b7482d6`.

Primary test review: no Critical finding in this bounded addition. Targets and
symlinks stay within the fresh fixture directory; pinning precedes the path
mutation; default full-suite enumeration retains all prior cases and adds these
four. The focused selector does not change default checks. These are stationary
symlink tests of existing protection, NOT reproduction of an initial-open race,
NOT repository-root reparse coverage, and NOT native Windows evidence. Since
these tests already pass, no production change is justified by this slice.
The earlier JSON-only 20/32 result remains unresolved, not superseded by 24/0.

External check: PR394 still points to 423edd3b0f9f6710e1de00183e4040fdd8de8ef3.
Run 34023439393 Windows job 101460103174 remains failed (62/2, Gemini
TEST-004(c) iterations 4/5). Targeted error retrieval reconfirms the previously
recorded dependency in pr394-fix-dependency-20260908.md, not a new root cause.
No live job was found to wait on or blindly rerun. No publication or merge.

### Anchored-read design continuation (2026-09-10)

Added `rt004-anchored-read-design-20260910.md` as a proposed, non-frozen
security design addendum. It distinguishes POSIX descriptor acquisition from
Windows handle acquisition and explicitly leaves root bootstrap and exact-case
handle validation unresolved. Existing read/copy helpers are evidence for
reuse principles, not automatically safe drop-in implementations.

Local read-only capability probes found Python 3.14.5 with descriptor-relative
open/listdir and required POSIX flags, and PowerShell 7.6.2 on macOS 26.6.2.
No installation or production edit occurred. The applied workflow-validator
hash remains `291ee7531594757d6ebc04c144bb8b35938f7715ae76665c9bdf723df09b1ff5`;
the unapplied admission candidate remains `0cfa88d533f22b4940bd90626329846411e09e494b92533fdccd80504e2b9ba1`.
Requested a bounded independent architecture/security review from the existing
`rt004_check_contract_review` identity. This is not formal gate admission or
PASS. Previous runtime results retain their original scope; no unchanged test
or failed CI run was blindly repeated.

### Repository-root negative fixture (2026-09-10)

Expanded the original-path focused path suite with `path-link-root` for both
roles and both runtimes. Session 86809 completed with **24 passed, 4 failed,
exit 1**: each new case was accepted and changed only its synthetic test ledger.
The existing 24 cases still pass. See
`rt004-admission-root-link-red-20260910.md` for the test hash and limitations.
This supersedes the previous focused-path aggregate, not the independently
scoped workflow-history or JSON results. It proves stationary root-symlink
acceptance, not an acquisition race or native Windows behavior. Production and
candidate files were not changed; the candidate remains NEEDS_WORK.

### Root cause and common-acquisition decision (2026-09-10)

Original source reads confirmed that Bash resolves the root with `pwd -P`
before descendant validation (lines 22-25); PowerShell's container/Resolve-Path
sequence at lines 170-174 has no root reparse rejection. Root information must
be preserved before these operations, not recovered from the normalized path.

Independent review identified that extension-specific safe acquisition cannot
coexist with a legacy unsafe initial precheck probe. Added proposed
`docs/adr/0034-review-input-acquisition-before-dispatch.md`: common safe precheck
transport, legacy content rules conditional on common JSON framing/ambiguity
requirements, explicit physical-root
compatibility impact, and POSIX/drive/UNC trust anchors. The standing user
design authorization is recorded without claiming formal review PASS. The
reader candidate is unchanged and still requires implementation, independent
review, protected human application and original-path verification.

Fresh GitHub query found the same 11 open PR heads with no live check runs.
There is no confirmed live CI job to wait on. No CI rerun, push, merge or issue
closure occurred. Whole-worktree whitespace validation exited 0 before the new
ADR; it will be repeated after the bounded document review.

The bounded independent ADR review requested one correction: legacy compatibility
must exclude ambiguous JSON that old parsers may have accepted. Applied this
qualification to the ADR and both current non-frozen design/status notes.
Transport restrictions and duplicate-key rejection are explicit compatibility
impacts, not a claim that all old invocations behave identically. No formal gate
verdict was created. Post-edit `git diff --check` exited 0.
