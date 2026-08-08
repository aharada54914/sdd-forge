# Investigation: epic-136-phase4-mcp

| Field | Value |
|-------|-------|
| Feature | epic-136-phase4-mcp (MCP evidence/path-guard 診断性ギャップ) |
| Mode | feature (additive; existing read-only MCP tools gain explicit diagnostic fields) |
| Date | 2026-07-29 |
| Investigator | coder (read-only survey, worktree `feature/epic-136-phase4`) |

Source: GitHub issues `#131`, `#132` (children of epic `#136`, Phase 4), against
`feature/epic-136-phase4` @ `ddf3ec33`. Read-only survey with `file:line`
evidence, every line re-confirmed directly against the worktree's live files
at investigation time (WFI-013 discipline) — no line number below is carried
forward unverified from the task brief. All paths are repository-relative
unless given as absolute.

## Scope

Two still-open, narrowly-scoped Phase 4 issues sharing one theme: **MCP
tools that cannot read/verify something must say so explicitly, instead of
reporting the same output shape they would for "there is genuinely nothing
here."**

1. **#131** (Finding A-5 / B-13) — `evidenceCompareToTraceability` silently
   skips a task whose verification contract is unreadable, while
   `evidenceDeepVerify` reports the identical condition as a `mismatch`; and
   `evidence_deep_verify`'s "signature/git-ancestry not verified" caveat is
   nested two levels deep, easy to miss despite the response already
   carrying `verified: false` fields.
2. **#132** (Finding B-12) — `listGuardedFiles` returns `[]` both when a
   directory is genuinely empty and when it could not be read at all
   (guard denial or a `readdirSync`/`statSync` failure), so every consumer
   built on it inherits the same "empty ambiguous with unreadable" gap.

Both issues are labeled `enhancement`, `OPEN` (confirmed via `gh issue view
131/132 --json state`), and are classified by epic `#136`'s own body as
"ランタイム非依存（共有スクリプト・MCP 内部・CI・docs）" — no
Claude-Code-vs-Codex runtime-parity section applies to either (issue `#136`
body, "ランタイム対応" list, third bullet, which names `#131, #132`
explicitly alongside `#112, #113, #114, #115, #120, #121, #126, #133,
#135`).

## Summary

Both issues' own file:line citations are confirmed accurate against the
current worktree. The core behavioral inconsistency issue #131 (A-5) names —
`evidenceCompareToTraceability` silently `continue`s past an unreadable
contract while `evidenceDeepVerify` reports the same condition as a
`mismatch` — is real and independently reproducible by inspection (INV-001,
INV-002). Issue #132's (B-12) `listGuardedFiles` empty-vs-unreadable
ambiguity is likewise confirmed (INV-004) and has exactly three production
call sites (INV-005), one of which (`evidenceFindMissing`) folds the
ambiguity into a `missing` list a caller might read as "no report was ever
produced" when the true cause could be "the reports directory itself could
not be listed" (INV-006). A genuinely new finding, not named by either issue
or the task brief: **the other two `listGuardedFiles` call sites
(`listQualityReports`, `listReviewTickets`) feed MCP tool response shapes
(`qualityGateSummaryData`, `reviewTicketsData`) that are documented, by their
own existing code comments, to carry no `failures` array at all** — a
broader, pre-existing, and already-accepted design choice that this
investigation treats as a scope boundary rather than a defect to fix here
(INV-015; see requirements.md Non-goals). Both issues' proposed-change text
matches the task brief's OQ framing closely: #131 proposes new
`unreadableContracts`/`skippedContracts`-shaped fields plus promoting
`evidence_deep_verify`'s nested notes to a top-level `hostRequiredChecks`
warning (with an explicit "critical tasks must have host-side verification
pass" policy note); #132 proposes a new `listGuardedFilesWithDiagnostics`
function that keeps the existing `listGuardedFiles` signature intact for
compatibility. Every file this feature is expected to touch
(`src/tools/evidence.ts`, `src/path-guard.ts`, `src/parsers/report-lookup.ts`,
`tests/*`, `dist/index.js`, `contracts/*.schema.json`) is confirmed absent
from `PROTECTED_GATE_SUFFIXES` — no human-copy staging is required for any
of them (INV-011).

---

## Findings

### Stream A — #131 (evidence.ts: unreadable-contract inconsistency + deep-verify host-deferred caveat)

#### INV-001: `evidenceCompareToTraceability` silently skips a task with no readable verification contract

**File**: `mcp/sdd-forge-mcp/src/tools/evidence.ts:361-378`

```ts
361  const declaredReqIds = new Set(traceability.reqToTask.map((row) => row.reqId));
362  for (const taskId of knownTaskIds) {
363    const contractResult = parseVerificationContract(root, feature, taskId);
364    if (!contractResult.ok) {
365      continue; // no readable contract for this task -- nothing to cross-check
366    }
367    for (const check of contractResult.data.checks) {
```

Any `parseVerificationContract` failure — file missing, unreadable, invalid
JSON, wrong `task_id`, malformed `checks` (the exact failure taxonomy in
INV-013 below) — is swallowed by the `continue` at line 365 with no trace in
the tool's response. The `mismatches`/`matches` counters (lines 380-385) are
computed only from checks that were actually read; a task whose contract
could not be read contributes nothing to either counter, which is
indistinguishable in the response from "this task's contract had zero
`requirementIds`-bearing checks."

#### INV-002: `evidenceDeepVerify`'s `verifyContractBinding` reports the identical condition as an explicit `mismatch`

**File**: `mcp/sdd-forge-mcp/src/tools/evidence.ts:606-644` (function),
specifically `:615-617`

```ts
606  function verifyContractBinding(
607    root: SddRoot,
608    bundle: EvidenceBundle,
609  ): CrossBindingInvariant {
610    const subject = "verification_contract";
611    const contractPath = String(bundle.verification_contract ?? "").trim();
612    if (contractPath.length === 0) {
613      return { subject, status: "mismatch", detail: "verification_contract path is missing" };
614    }
615    const read = guardedRead(root, contractPath);
616    if (!read.ok) {
617      return { subject, status: "mismatch", detail: `verification_contract unreadable: ${read.error.message}` };
618    }
```

An unreadable `verification_contract` here becomes a named `crossBindings`
entry with `status: "mismatch"`, which — per the verdict formula at
`evidence.ts:777` (`verdict: failures.length === 0 ? "pass" : "fail"`, fed by
the `for (const binding of crossBindings)` loop at `:767-771`) — flips the
overall tool verdict to `"fail"` and adds a line to `failures[]`.

#### INV-003: The two tools' behavior for the same root condition is confirmed inconsistent

Given the identical underlying condition (a task's `T-NNN.contract.json` is
missing or unparsable), `evidenceCompareToTraceability` produces **no
visible signal at all** (INV-001) while `evidenceDeepVerify` produces **a
verdict-flipping failure** (INV-002). This is issue #131's Finding A-5,
confirmed by direct inspection rather than assumed from the issue's own
prose.

#### INV-004: No existing test exercises `evidenceCompareToTraceability`'s unreadable-contract path

**File**: `mcp/sdd-forge-mcp/tests/evidence/evidence.test.ts` (560 lines,
full-file `grep -n "^test("`)

The `evidence_compare_to_traceability` test block (lines 412-524) has 4
cases: real-data consistency (:414), a synthetic REQ→Task nonexistent-task
mismatch (:440), a synthetic contract-`requirementId`-not-declared mismatch
(:463), and `traceability.md` itself missing (:504, whole-tool `not-found`).
None of the four constructs a Done task whose OWN `T-NNN.contract.json` is
missing/unparsable while `traceability.md`/`tasks.md` remain readable — the
exact per-task `continue` branch at `evidence.ts:365` has zero direct test
coverage today. (This mirrors `evidenceSummarizeContractChecks`'s malformed-
contract case at `evidence.test.ts:394-410`, which tests the SAME
`parseVerificationContract` failure but through a different tool that does
not silently swallow it.)

#### INV-005: `evidenceDeepVerify`'s host-deferred caveats already exist, but only nested two levels deep

**File**: `mcp/sdd-forge-mcp/src/tools/evidence.ts:430-465` (interfaces),
`:583-600` (`verifyGitCommit`), `:679-689` (`echoSignature`)

```ts
430  export interface GitCommitInvariant {
431    value: string;
432    shapeValid: boolean;
433    ancestryVerified: false;
434    reason: string;
435  }
...
450  export interface DeepVerifySignature {
451    present: boolean;
452    alg?: string;
453    verified: false;
454    note: string;
455  }
```

Both `gitCommit.ancestryVerified` (nested at
`data.invariants.gitCommit.ancestryVerified`) and `signature.verified`
(nested at `data.signature.verified`) are always the literal `false`, each
with its own explanatory `reason`/`note` string (`:596-598`, `:683-684`) —
the information issue #131's B-13 asks to surface already exists, but a
consumer reading only the top-level `verdict` field (the field most likely
to be read in isolation) has no signal that two specific concerns were never
verified at all, only that they didn't fail the ones actually checked. This
is a readability/discoverability gap, not a missing-data gap — confirmed by
inspection, corroborating issue #131's own framing ("設計通りだが名称が強く
誤解リスク; 既に verified:false+note はある").

#### INV-006: Issue #131's own proposed-change text (verbatim)

**Source**: `gh issue view 131 --json body`

> `evidenceCompareToTraceability` のレスポンスに
> `skippedContracts`/`unreadableContracts` を追加し『検証不能』を明示。
> `evidence_deep_verify` は nested note を top-level の `hostRequiredChecks`
> warning に格上げし、署名/ancestry 未検証を前面化(critical は host 側通過
> を必須とする方針も記載)。

This names two candidate field names for the same concept
(`skippedContracts`/`unreadableContracts`) rather than committing to one —
resolved in design.md's Design Decisions (a single field, to avoid two
overlapping arrays describing the identical set of tasks, per this project's
DRY convention).

### Stream B — #132 (path-guard.ts: `listGuardedFiles` empty-vs-unreadable ambiguity)

#### INV-007: `listGuardedFiles` returns `[]` for both a guard-denied directory and a `readdirSync`/`statSync` failure

**File**: `mcp/sdd-forge-mcp/src/path-guard.ts:261-294`

```ts
261  export function listGuardedFiles(root: SddRoot, relDir: string): string[] {
262    const guardResult = resolveGuardedDirectory(root, relDir);
263    if (!guardResult.ok) {
264      return [];
265    }
266
267    const results: string[] = [];
268    const walk = (absDir: string, relPrefix: string): void => {
269      let entries: string[];
270      try {
271        entries = readdirSync(absDir);
272      } catch {
273        return;
274      }
275      for (const entry of entries) {
276        const absEntryPath = join(absDir, entry);
277        const relEntryPath = relPrefix.length > 0 ? `${relPrefix}/${entry}` : entry;
278        let stats: ReturnType<typeof statSync>;
279        try {
280          stats = statSync(absEntryPath);
281        } catch {
282          continue;
283        }
284        if (stats.isDirectory()) {
285          walk(absEntryPath, relEntryPath);
286        } else if (stats.isFile()) {
287          results.push(relEntryPath);
288        }
289      }
290    };
291
292    walk(guardResult.data.resolvedPath, relDir.replace(/\/+$/, ""));
293    return results;
294  }
```

Three distinct failure classes all collapse to the same observable output
(`[]`, or a truncated `results` if the failure happens mid-walk on a
subdirectory): (a) `resolveGuardedDirectory` itself fails — `relDir` does
not exist, is outside the allowlist, or matches the denylist (`:262-265`);
(b) the top-level `readdirSync` throws (`:270-274`); (c) a nested
`readdirSync`/`statSync` throws partway through the recursive walk
(`:279-283`, silently `continue`s past that one entry). The function's own
doc comment (`:257-260`) already documents this as intentional ("Returns an
empty array if `relDir` fails path-guard validation or does not exist / is
not a directory — callers that need the failure reason should use
`resolveGuarded` instead") — but no caller today has a "failure reason" path
to use, since none of the 3 consumers (INV-008) calls `resolveGuardedDirectory`
independently.

#### INV-008: Exactly 3 production call sites, all unable to distinguish empty from unreadable

**File**: `mcp/sdd-forge-mcp/src/parsers/report-lookup.ts:30`,
`mcp/sdd-forge-mcp/src/parsers/quality-report.ts:132`,
`mcp/sdd-forge-mcp/src/parsers/review-ticket.ts:160`

```ts
// report-lookup.ts:27-37 (anyFileContaining)
27  export function anyFileContaining(root: SddRoot, relDir: string, pattern: string): string[] {
28    const wordBoundary = new RegExp(`(^|[^A-Za-z0-9_-])${escapeRegExp(pattern)}([^A-Za-z0-9_-]|$)`);
29    const matches: string[] = [];
30    for (const relFilePath of listGuardedFiles(root, relDir)) {
```

```ts
// quality-report.ts:125-135 (listQualityReports)
125  export function listQualityReports(
126    root: SddRoot,
127    relDir: string = QUALITY_GATE_REPORTS_DIR,
128  ): QualityReportsScan {
129    const reports: QualityReportEntry[] = [];
130    const failures: QualityReportFailure[] = [];
131
132    for (const relFilePath of listGuardedFiles(root, relDir)) {
```

```ts
// review-ticket.ts:153-160 (listReviewTickets)
153  export function listReviewTickets(
154    root: SddRoot,
155    relDir: string = REVIEW_TICKETS_DIR,
156  ): ReviewTicketsScan {
157    const tickets: ReviewTicketEntry[] = [];
158    const failures: ReviewTicketFailure[] = [];
159
160    for (const relFilePath of listGuardedFiles(root, relDir)) {
```

Confirmed exhaustive: `grep -rn "listGuardedFiles(" src/` (excluding the
definition itself and `listGuardedFiles`'s own re-export) returns exactly
these 3 call sites; no fourth exists.

#### INV-009: `evidenceFindMissing` is the one call site that folds the ambiguity into an existing Done-transition signal (`missing`)

**File**: `mcp/sdd-forge-mcp/src/tools/evidence.ts:217-221`

```ts
217    const qgMatches = anyFileContaining(root, reportsDir, taskId);
218    if (qgMatches.length > 0 && hasQualityGateVerdictPass(root, reportsDir, taskId)) {
219      present.push(QUALITY_GATE_REPORT_REQUIREMENT);
220    } else {
221      missing.push(QUALITY_GATE_REPORT_REQUIREMENT);
222    }
```

`anyFileContaining` (`report-lookup.ts:27`) is built directly on
`listGuardedFiles`; if `reports/quality-gate` cannot be listed at all (a
guard failure — e.g. someone denylisted the directory — or a `readdirSync`
failure — e.g. a permissions problem on a self-hosted runner), `qgMatches`
is `[]` exactly as it would be for a genuinely empty, freshly-initialized
`reports/quality-gate/` directory, and `QUALITY_GATE_REPORT_REQUIREMENT` is
pushed into `missing` either way. A caller reading `evidenceMissingData`
cannot tell "no quality-gate report was ever produced for this task" (a real
Done-blocking gap) apart from "the MCP server could not even list the
reports directory" (an environment/permissions problem unrelated to whether
the task's own work is complete).

#### INV-010: `listQualityReports`/`listReviewTickets`'s own per-file `failures[]` arrays do NOT cover the directory-level ambiguity — and their consuming MCP tools discard even that per-file signal

**File**: `mcp/sdd-forge-mcp/src/tools/core.ts:213-230` (`ReviewTicketsData`
+ `listReviewTicketsTool`), `:234-248` (`QualityGateSummaryData` +
`getQualityGateSummary`)

```ts
213  export interface ReviewTicketsData {
214    kind: "review-tickets";
215    tickets: ReviewTicketEntry[];
216  }
217
218  /**
219   * `list_review_tickets`: every `docs/review-tickets/RT-*.yml` file that
220   * parses successfully. Files that fail to parse are silently excluded from
221   * the result rather than failing the whole tool — the contract's
222   * `reviewTicketsData` shape carries no `failures` array, so a single
223   * malformed ticket file must not prevent every other ticket from being
224   * listed (see `review-ticket.ts`'s `listReviewTickets` for the underlying
225   * per-file failure detail, which this tool does not surface).
226   */
227  export function listReviewTicketsTool(root: SddRoot): Result<ReviewTicketsData> {
228    const scan = listReviewTickets(root);
229    return ok({ kind: "review-tickets", tickets: scan.tickets });
230  }
```

`listQualityReports`/`listReviewTickets` (`report-lookup.ts`-adjacent
parsers) already collect a per-file `failures[]` array for files that FAILED
TO PARSE after being listed (`quality-report.ts:114-118`,
`review-ticket.ts:133-143`) — but (a) this says nothing about a
DIRECTORY-level `listGuardedFiles` failure (a file that was never even
listed cannot appear in `failures[]` either, since `failures[]` is built by
iterating the SAME possibly-truncated `listGuardedFiles(...)` result,
`quality-report.ts:132`/`review-ticket.ts:160`), and (b) the TOOL-level
wrappers (`listReviewTicketsTool`, `getQualityGateSummary`) discard even the
per-FILE `failures[]` array by design — `core.ts:222`'s own comment states
plainly: "the contract's `reviewTicketsData` shape carries no `failures`
array." Confirmed identically for `qualityGateSummaryData`
(`core.ts:242-243`: "see `list_review_tickets` doc for why: the contract
shape carries no `failures` array").

#### INV-011: `reviewTicketsData`/`qualityGateSummaryData` are ALSO `additionalProperties: false` in the v1 contract — a scope-relevant finding not named by issue #132 or the task brief

**File**: `contracts/sdd-forge-mcp-tools.v1.schema.json:181-207`
(`reviewTicketsData`), `:208-233` (`qualityGateSummaryData`)

```json
181    "reviewTicketsData": {
182      "type": "object",
183      "description": "list_review_tickets / sdd://review-tickets. Parsed from docs/review-tickets/RT-*.yml.",
184      "additionalProperties": false,
185      "required": ["kind", "tickets"],
```
```json
208    "qualityGateSummaryData": {
209      "type": "object",
210      "description": "get_quality_gate_summary / sdd://quality-reports. Extracted VERDICT and finding counts from reports/quality-gate/*.md.",
211      "additionalProperties": false,
212      "required": ["kind", "reports"],
```

If a future change wanted `list_review_tickets`/`get_quality_gate_summary`
to ALSO surface directory-level diagnostics (as issue #132's own
proposed-change text hints — "MCP summary 系ツールは診断版を使用" —
plural, suggesting more than just `evidence_find_missing`), it would need
its OWN additive schema change to these two `additionalProperties: false`
shapes, on top of the already-existing, separately-documented design choice
that these two tools drop even per-file parse failures. This investigation
records the finding but treats broadening `list_review_tickets`/
`get_quality_gate_summary`'s response contracts as **out of scope** for this
feature (requirements.md Non-goals) — see design.md's Design Decisions for
the reasoning (narrow blast radius, matching the epic's own "1 issue = 1
commit" framing, and avoiding two additional `additionalProperties: false`
schema migrations that neither issue's acceptance criteria actually
requires).

#### INV-012: Issue #132's own proposed-change text (verbatim)

**Source**: `gh issue view 132 --json body`

> 既存 API 互換を維持しつつ `listGuardedFilesWithDiagnostics`(files +
> errors)を追加し、MCP summary 系ツールは診断版を使用。

"既存 API 互換を維持" (preserve existing API compatibility) directly
supports OQ-2's option (A) — a new function, existing `listGuardedFiles`
kept as a compatible wrapper — over option (B) (a flag argument, which would
change the existing signature).

### Cross-Cutting: Contract, CI, Test Infrastructure, Protected-File Status

#### INV-013: `parseVerificationContract`'s full failure taxonomy (relevant to REQ-001's `unreadableContracts` field's `reason` text)

**File**: `mcp/sdd-forge-mcp/src/parsers/evidence.ts:176-242`

Five distinct `cannot-parse`-coded failure modes, each with its own
`err(...)` message (all propagate through `Result.error.message`, the exact
string this feature's new `unreadableContracts[].reason` field will carry):
the path-guard read itself fails (`:182-185`, propagated unchanged — e.g.
`not-found`); the file is not valid JSON (`:188-195`, "is not valid JSON");
the file is not a JSON object (`:197-202`, "is not a JSON object");
`task_id` mismatch (`:206-212`); `checks` missing or not an array
(`:214-219`); an individual check entry is malformed (`:222-238`, delegated
to `toChecksSummaryEntry`, `:124-161`).

#### INV-014: `contracts/sdd-forge-mcp-tools.v1.schema.json`'s `$id` and the two directly-affected `$defs` entries

**File**: `contracts/sdd-forge-mcp-tools.v1.schema.json:1-32`
(`$id`/`oneOf`), `:324-346` (`traceabilityComparisonData`), `:347-439`
(`evidenceDeepVerifyData`)

`$id` is `https://sdd-forge.dev/contracts/sdd-forge-mcp-tools.v1.schema.json`
(v1 contract, line 3). `traceabilityComparisonData` (`:324-346`) and
`evidenceDeepVerifyData` (`:347-439`) are BOTH `additionalProperties: false`
with an explicit `required` array (`:328` and `:351` respectively) —
confirmed identical to the task brief's claim; no line-number drift found.
`evidenceMissingData` (the third schema entry REQ-004's `undeterminable`
field will touch) is likewise `additionalProperties: false`, `required:
["kind", "feature", "taskId", "required", "present", "missing"]`
(`:284-297`).

#### INV-015: No test exercises `evidenceCompareToTraceability`'s per-task unreadable-contract branch — closing this gap is this feature's own regression-test obligation

Already covered in detail at INV-004; restated here as the concrete Test
Strategy target (design.md), since it is the one test gap this feature's own
change makes directly observable for the first time — before this feature,
there was no distinguishable OUTPUT to assert against for this branch at
all (a "the assertion has never been possible to make" state, not
"the assertion currently fails," mirroring `epic-136-phase3`'s Stream A
Test Strategy framing for an analogous "previously-unobservable behavior"
case).

#### INV-016: `evidence_deep_verify`'s underlying ADRs remain `Status: Proposed`, but this feature does not depend on their approval

**File**: `docs/adr/0008-evidence-deep-verify-no-signature-crypto.md:3-5`,
`docs/adr/0009-evidence-deep-verify-match-host-canonical-formulas.md:3-5`

Both read `## Status` / `Proposed(人間承認待ち — ...)`. `evidence_deep_verify`
itself is nonetheless already implemented and live in `src/tools/evidence.ts`
(confirmed by direct inspection, INV-005) — unlike `epic-136-phase3`'s
Stream C (which was genuinely blocked on `ADR-0010` reaching `Accepted`
before any code could be written), this feature's `hostRequiredChecks`
change is **purely additive to already-shipped code** and makes no new
signature-verification or git-ancestry-verification claim that would need
ADR-0008/0009's own decisions to be re-litigated — it only re-surfaces
information the existing (already-live) implementation already computes.
Recorded as a non-blocking Assumption (requirements.md), not a Blocker.

#### INV-017: `dist/` is committed and CI enforces rebuild parity

**File**: `.github/workflows/test.yml:385-432` (`mcp-tests` job, read via the
`Read` tool directly — `find`/`grep` against this specific path is denied by
the local hook guard even for read-only shell invocations, so this citation
was captured by reading the file directly rather than shelling out)

3-OS matrix (`windows-latest`, `macos-latest`, `ubuntu-latest`, `:390`);
`npm ci` (`:411`), `npx tsc --noEmit` (`:414`), `npm test` (`:417`) run on
all 3 OSes; dist-parity (`:423-427`, `npm run build` then
`git diff --exit-code -- dist/`) and `npm audit --omit=dev --audit-level=high`
(`:429-431`) run on `ubuntu-latest` only. `package.json`'s `build` script
(`mcp/sdd-forge-mcp/package.json:11`) is
`esbuild src/index.ts --bundle --platform=node --format=esm --outfile=dist/index.js`
— any `src/` change in this feature requires `dist/index.js` to be
regenerated and committed alongside it (ADR-0003).

#### INV-018: None of this feature's expected target files are `PROTECTED_GATE_SUFFIXES`-listed — no human-copy staging needed

**File**: `plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.js:5`
(and the byte-identical `.py`/`.ps1` twins)

Full-tuple `PROTECTED_GATE_SUFFIXES` list re-read directly; confirmed
absent: `mcp/sdd-forge-mcp/src/tools/evidence.ts`,
`mcp/sdd-forge-mcp/src/path-guard.ts`,
`mcp/sdd-forge-mcp/src/parsers/report-lookup.ts`, any file under
`mcp/sdd-forge-mcp/tests/`, `mcp/sdd-forge-mcp/dist/index.js`,
`contracts/sdd-forge-mcp-tools.v1.schema.json`. The list's `tests/`-prefixed
entries (`tests/gates.tests.sh`, `tests/eval.tests.sh`,
`tests/guard-parity.tests.sh`, `tests/constant-parity.tests.sh`) all name
files at the REPOSITORY ROOT `tests/` directory, a different path than the
monorepo-nested `mcp/sdd-forge-mcp/tests/` this feature touches — no suffix
collision either way (exact-suffix matching, per
`epic-136-phase3/investigation.md` INV-024's already-established basis).
`.github/workflows/test.yml` IS protected but is not a target of this
feature (no new CI step, no job-graph change — REQ-005/AC-010 only requires
the EXISTING `mcp-tests` job's steps to keep passing).

#### INV-019: `getEnvelopeValidator()` — the existing ajv strict-mode contract-conformance harness this feature's new fields must pass

**File**: `mcp/sdd-forge-mcp/tests/evidence/test-helpers.ts:73` (definition);
`mcp/sdd-forge-mcp/tests/tools/deep-verify-contract-conformance.test.ts:1-19`
(header doc, precedent usage)

The existing `evidence_deep_verify` contract-conformance suite's own header
doc states the exact mechanism this feature's TEST-IDs must reuse (not a
text-marker check): "The ajv validator (`getEnvelopeValidator`) compiles the
whole envelope schema with `strict: true` and `additionalProperties: false`
throughout, so a response that carries an unexpected field, an out-of-enum
status, or a shape matching no `data.oneOf` branch fails validation." This
is the established, real-parser precedent (not a text-marker) this
feature's own AC/TEST-ID for schema conformance must follow (per this
project's own prior Wave 7 lesson: text-marker checks for document/schema
conformance are insufficient).

#### INV-020: `CHANGELOG.md`'s `## Unreleased` section is currently empty

**File**: `CHANGELOG.md:1-5`

```
1  # Changelog
2
3  ## Unreleased
4
5  ## v1.12.0 (2026-07-28)
```

No prior-feature content to collide with; this feature's eventual
implementation task(s) each add their own entry citing `#131`/`#132`
respectively (requirements.md, matching epic `#136`'s own per-issue
Done-condition text, quoted verbatim at INV-021 below).

#### INV-021: Epic `#136`'s Done-condition text — quoted verbatim, applies to `#131` and `#132`

**File**: GitHub issue `#136` body, section "ドキュメント追従・バージョン
改訂ポリシー — 2026-07-10 追記"

> "全子 issue（#108〜#135, #138〜#140）に共通 Done 条件として適用する: -
> 仕様・挙動・コマンド・契約スキーマ・エージェント定義に影響する変更は、
> **同一 PR で**該当ドキュメントを最新仕様に追従させること（該当分のみ）:
> `README.md` / `USERGUIDE.md` / `docs/workflow-guide.md` /
> `docs/skill-reference.md` / `docs/agent-capability-matrix.md` /
> `PLUGIN-CONTRACTS.md` / `docs/troubleshooting.md` / `docs/contributor/*` -
> `CHANGELOG.md` の `## Unreleased` に issue 番号付きで変更内容を追記 -
> **リリース時のバージョンは `scripts/bump-version.sh` で追番改訂**
> （手動改訂禁止 — v1.9.0 非同期事故の教訓）。semver 目安: fix/test のみ =
> patch、挙動変更を伴う feat = minor"

`USERGUIDE.md:96,98,99` already documents `evidence_find_missing`,
`evidence_compare_to_traceability`, and `evidence_deep_verify` with a
one-line behavior summary each (confirmed present, no `listGuardedFiles`/
`path-guard` mention exists anywhere in `USERGUIDE.md`, `README.md`, or
`docs/` — confirmed by full-repo `grep`). Since this feature changes those 3
tools' response SHAPES (new fields a consumer can now rely on to distinguish
"unreadable"/"undeterminable" from "genuinely empty/clean"), the 3
`USERGUIDE.md` rows are a real, in-scope doc-follow candidate — recorded as
an explicit Acceptance Criterion rather than silently assumed unaffected
(requirements.md AC; matches `epic-136-phase3`'s own AC-023 convention of
recording the expected answer explicitly per stream).

#### INV-022: Epic `#136` classifies `#131`/`#132` as runtime-independent — no dual-runtime (Claude Code/Codex) test matrix applies

**File**: GitHub issue `#136` body, "ランタイム対応 (Claude Code / Codex)"
section, third bullet (quoted at Scope above). Neither issue carries its own
"ランタイム対応" addendum section (confirmed by direct body read, INV-006/
INV-012) — this feature's tests are plain TypeScript `node:test` unit tests,
with no PreToolUse-hook or CLI-runtime dimension to enumerate (unlike
`epic-136-phase3`'s guard-parity streams).

---

## Open Questions

The task brief's own OQ-1..OQ-4 are the governing open questions for this
feature; they are restated and resolved with design rationale in
requirements.md (recorded there, not re-litigated here) and decided
concretely in design.md's Design Decisions. One additional question this
investigation surfaces on its own:

| # | Question | Owner | Blocking |
|---|----------|-------|---------|
| 1 | INV-011 found that `list_review_tickets`/`get_quality_gate_summary` (`reviewTicketsData`/`qualityGateSummaryData`) would need their OWN additive schema changes to surface directory-level diagnostics, on top of an already-existing, separately-documented "no failures array" design choice — issue #132's own text ("MCP summary 系ツールは診断版を使用") plausibly wants this too. Should THIS feature widen its scope to include those two tools, or should that be a follow-on issue? | Human (via design.md Design Decisions, resolved: follow-on, not this feature) | no — resolved with a scope decision in design.md, not left open |

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| `unreadableContracts`/`hostRequiredChecks`/`undeterminable` are implemented as fields that inadvertently change `matches`/`mismatches`/`missing`/`verdict` counting semantics, breaking BL-004/BL-005's preserved-behavior contracts | medium | high | design.md's Data Plan requires each new field to be purely additive — computed alongside, never substituted for, the existing counters; AC-level regression assertions pin the OLD counters' exact values across a fixture that also exercises the new field |
| Widening scope to `list_review_tickets`/`get_quality_gate_summary` (INV-011/OQ-1 above) mid-implementation, expanding two MORE `additionalProperties: false` schemas beyond what either issue's acceptance criteria strictly requires | low-medium | medium | design.md's Design Decisions explicitly scopes this OUT (Non-goals), recording it as a named follow-on rather than an ambiguous "maybe later" |
| A new required schema field is added without the corresponding TypeScript interface/implementation landing in the SAME commit, producing a schema that no real response can validate against (or vice versa) | low | high | REQ-005/AC-009 requires the schema and implementation changes to land together; ajv-based contract-conformance tests (INV-019) fail immediately if they diverge |
| `dist/index.js` is not regenerated after the `src/` edit, so CI's dist-parity check (INV-017) fails | low | medium | AC-010 makes `npm run build` + `git diff --exit-code -- dist/` an explicit Done condition, mirroring `evidence-deep-verify`'s own established Deployment/CI Plan precedent |

## Recommended Next Steps

1. Resolve OQ-1..OQ-4 (task brief) in requirements.md/design.md before task
   decomposition — all four have a clear, evidence-grounded recommended
   answer already (see design.md Design Decisions).
2. Scope `list_review_tickets`/`get_quality_gate_summary` diagnostic
   surfacing (this investigation's own new Open Question) OUT of this
   feature; record it as a candidate follow-on issue in the implementation
   report once this feature lands, rather than silently expanding scope
   mid-implementation.
3. Add the regression test INV-004/INV-015 identifies (`evidence_compare_to_traceability`'s per-task unreadable-contract branch) as this feature's own new test, closing a real, pre-existing coverage gap rather than only testing the NEW field in isolation.
4. Rebuild and commit `dist/index.js` in the same commit as any `src/`
   change (INV-017), and re-verify `PROTECTED_GATE_SUFFIXES` membership
   directly before implementation begins (INV-018), not from this
   snapshot's authoring-time state (WFI-013 discipline).

---

**File paths referenced in this investigation** (all absolute,
repository-relative for evidence):

- `/Users/jrmag/Projects/active/sdd-forge/mcp/sdd-forge-mcp/src/tools/evidence.ts`
- `/Users/jrmag/Projects/active/sdd-forge/mcp/sdd-forge-mcp/src/path-guard.ts`
- `/Users/jrmag/Projects/active/sdd-forge/mcp/sdd-forge-mcp/src/parsers/evidence.ts`
- `/Users/jrmag/Projects/active/sdd-forge/mcp/sdd-forge-mcp/src/parsers/report-lookup.ts`
- `/Users/jrmag/Projects/active/sdd-forge/mcp/sdd-forge-mcp/src/parsers/quality-report.ts`
- `/Users/jrmag/Projects/active/sdd-forge/mcp/sdd-forge-mcp/src/parsers/review-ticket.ts`
- `/Users/jrmag/Projects/active/sdd-forge/mcp/sdd-forge-mcp/src/tools/core.ts`
- `/Users/jrmag/Projects/active/sdd-forge/contracts/sdd-forge-mcp-tools.v1.schema.json`
- `/Users/jrmag/Projects/active/sdd-forge/mcp/sdd-forge-mcp/tests/evidence/evidence.test.ts`
- `/Users/jrmag/Projects/active/sdd-forge/mcp/sdd-forge-mcp/tests/evidence/test-helpers.ts`
- `/Users/jrmag/Projects/active/sdd-forge/mcp/sdd-forge-mcp/tests/tools/deep-verify-contract-conformance.test.ts`
- `/Users/jrmag/Projects/active/sdd-forge/mcp/sdd-forge-mcp/tests/parsers-state/quality-report.test.ts`
- `/Users/jrmag/Projects/active/sdd-forge/mcp/sdd-forge-mcp/package.json`
- `/Users/jrmag/Projects/active/sdd-forge/.github/workflows/test.yml`
- `/Users/jrmag/Projects/active/sdd-forge/plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.js`
- `/Users/jrmag/Projects/active/sdd-forge/docs/adr/0008-evidence-deep-verify-no-signature-crypto.md`
- `/Users/jrmag/Projects/active/sdd-forge/docs/adr/0009-evidence-deep-verify-match-host-canonical-formulas.md`
- `/Users/jrmag/Projects/active/sdd-forge/docs/adr/0003-mcp-dist-bundle-distribution.md`
- `/Users/jrmag/Projects/active/sdd-forge/USERGUIDE.md`
- `/Users/jrmag/Projects/active/sdd-forge/CHANGELOG.md`
