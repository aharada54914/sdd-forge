# ADR review-input correction — implementation plan

Ticket: RT-20260908-004
Status: bounded independent plan re-review PASS; implementation application blocked by protection hook; not implemented
Authorization: user explicitly approved protected review-contract and validator scope on 2026-09-08.

## Cause and boundary

The implementation-review admission allowlist has no ADR branch
(`plugins/sdd-quality-loop/scripts/validate-review-context-set.sh:146`).
The persisted predecessor allowlist is independent
(`plugins/sdd-review-loop/scripts/lib/review-precheck-common.sh:113`).
Changing admission alone therefore cannot repair the review chain.
The invocation schema also has an exact key set
(`plugins/sdd-quality-loop/scripts/validate-review-context-set.sh:243`):
avoid adding a new invocation field or changing historical ledger hashing.
The precheck already pins design bytes and the reviewers already receive the
precheck as a hashed manifest entry. Use those existing bindings.

## Proposed representation

New implementation prechecks and contracts carry `adr_inputs`, an array of
objects with exactly `path` and `sha256`. Sort by ASCII path; reject duplicate
paths, non-string values, extra keys, and non-lowercase 64-hex hashes.
An empty array means that this review has no admitted ADR input.
Keep the current outer schemas and explicitly document this optional extension.
Historical files with the field absent use their existing rules; they never
gain permission to read an ADR. Null and malformed fields are not absence.

The design is the authority, not the caller's list. For this extension define
an intentionally narrow declaration grammar: a single-backtick inline literal
whose entire content matches `^docs/adr/[0-9]{4}-[a-z0-9][a-z0-9-]*\.md$`.
Collect every such reference, deduplicate repeated references in prose, and
require the resulting set to equal `adr_inputs[].path`. This supports the
current design's literal reference at design.md:111 without editing frozen
design bytes. Other Markdown links, relative paths, ADR identifiers alone,
and code-fence examples do not authorize reads. The implementation must have
explicit fixtures for fence exclusion, escaping, CRLF, and inline delimiters;
do not use a substring match that admits embedded or malformed paths.
Unsupported reference syntax is reported as not admitted, not as proof that
the ADR does not exist. Reviewers cannot silently interpret it as ADR-PRESENT.

The parser is a restricted line-oriented lexer, not general Markdown:
normalize CRLF only for lexical analysis (never for file hashing); track fences
opened by 0–3 spaces followed by at least three identical backticks or tildes;
close only with the same character at least as many times and whitespace-only
trailing text. Ignore all fenced lines. Outside fences ignore lines indented
by four spaces or any leading tab. Scan maximal backtick runs; an odd number
of immediately preceding backslashes escapes a run. A span closes only at an
unescaped run of equal length on that same line; runs of another length do not
close it. Only length-one spans can declare a path; do not recursively scan
length-two-or-longer spans. An unclosed span declares nothing after its opener
on that line. No multiline, HTML, link-target, or Markdown entity decoding.
Both runtimes must consume one common fixture table with expected path sets,
including longer-span pseudo-references, both fence characters, indentation,
odd/even backslash escaping, unmatched delimiters and malformed suffixes.

Every path must be repository-relative, case-exact, a readable regular file,
and have no symlink/reparse-point component. Verify actual directory entry
spelling even on case-insensitive filesystems. Reject absolute paths, traversal,
backslashes, alternate data streams, and missing files before reading content.
ADR content is input data, never a command or permission instruction.
Apply these restrictions to raw ADR manifest paths before any legacy absolute
path relocation or backslash normalization. In PowerShell inspect ReparsePoint
attributes on every component (not only LinkType), and compare directory-entry
names using Ordinal equality.

## Consumer sequence

1. Precheck generation derives the complete set from the exact design bytes,
   hashes the files, records `adr_inputs`, and includes deterministic ADR
   serialization in `input_sha256` when the extension is present. Generation
   and verification use the same ordering/serialization in Bash and PowerShell.
2. `--verify-inputs` verifies design first, re-derives the set, checks every
   path and hash, and rejects modifications before reviewer launch.
3. Invocation validation permits ADRs only for impl-reviewer-a/b. Locate exactly
   one canonical current-round precheck in the invocation's existing manifest;
   validate that precheck's pinned hash, feature and attempt/round path identity,
   and its design hash against the invocation's exact design entry and disk.
   Require all ADR entries to equal the verified precheck set, even when the
   caller omitted all ADR entries. Preserve all existing summary and ledger
   checks. No new invocation key is necessary.
4. Integration records the identical `adr_inputs` in the contract. Both reviewer
   manifests must contain that exact set and hashes; no optional one-sided
   membership. Both must pin the same precheck and design associated with it.
5. Persisted-contract checks in the shared precheck library, PowerShell
   prechecks, and workflow-state validators verify the same cross-bindings,
   path safety and current ADR hashes. A task-stage consumer validates the
   predecessor impl contract; it does not authorize ADRs for task reviewers.
   Cross-artifact design pins must agree with each other exactly, but compare
   those pins to disk using the consumer's existing lifecycle-normalized design
   hash rules, not launch-time raw equality. Changing only the permitted
   Pending-to-Passed field must remain valid; editing design body text must not.
   Precheck and contract must either both have the extension or both omit it.
   One-sided removal is an error; if ADR manifest entries survive removal from
   both files, legacy admission rejects them. Existing verified `--opening`
   freshness tolerance remains available only at its existing lifecycle sites:
   it never excuses missing fields, divergent reviewer sets or inconsistent
   saved precheck/contract pins. Current standalone PASS consumption requires
   current raw ADR hashes. Historical NEEDS_WORK agreement does not require
   current ADR bytes to equal bytes deliberately corrected in the next round.
6. Round-to-round validation checks internal prior-contract agreement without
   requiring changed ADR files to retain their old hashes. Current-disk checks
   belong to current-stage consumption, not historical NEEDS_WORK evidence.
   Keep prior failed reports and ledger records byte-for-byte unchanged.
   For an ADR-bound prior round, permit the next round only when the verified
   design or declared ADR path/hash set changed. Preserve the design-only
   progress rule for legacy prior rounds. ADR-only remediation must be able to
   open a new round, while unchanged full inputs remain rejected. The existing
   design-only comparisons are impl-review-precheck.sh:253–257 and .ps1:374.

Do not add a generally writable helper that would become a new unprotected
authorization boundary. Keep changes within the ticket's existing protected
consumers; enumerate all duplicated checks before implementation. Independent
review must consider whether this duplication is acceptably bounded.

## Verification and application order

First review this plan independently for authorization widening, inconsistent
consumers, downgrade behavior, parser ambiguity, and filesystem safety. Resolve
findings before protected implementation application. Then create offline RED
fixtures against real admission/precheck/persisted/task-stage consumers, apply
the smallest approved correction, and rerun the same fixtures.

Positive coverage: both roles, zero and multiple ADRs, repeated design reference,
CRLF, later-round A/B summaries, legacy no-extension evidence unchanged.
Negative coverage: omitted field/hash/member, null/type/extra-key errors, duplicate
manifest path, wrong or mutated hash, changed design, wrong precheck round,
one-sided reviewer inputs, unreferenced ADR, missing file, traversal, absolute
path, backslash/ADS, symlink parent/file, wrong actual filename case, non-impl
role, malformed/escaped/fenced pseudo-reference. Assert rejection before ledger
reservation and preservation of old ledger bytes on each failed invocation.

Run existing boundary, round-2 contract and workflow-state parity suites.
Mac PowerShell execution is not native Windows validation; Windows reparse-point
and case behavior need native Windows evidence before claiming that coverage.
No existing required CI check is removed. If the protection hook denies an edit,
stop that operation and provide a human-applied patch, never a bypass.

## Alternatives and remaining gates

Rejected: broad `docs/adr/*` allowlist (unbounded reads); caller-only manifest
(no design authority); launch-only fix (downstream disagreement); retrofit old
reviews (false provenance); new invocation keys (unnecessary ledger migration).
The narrow syntax trades Markdown flexibility for auditable admission. A later
syntax extension requires explicit tests and review, not heuristic extraction.

This ticket does not resolve PR #400's independent PowerShell descendant cleanup
or BL-005 protection-classification findings. ADR-PRESENT requires a fresh actual
review after the corrected contract is verified; this plan is not PASS evidence.

## Baseline executed before implementation

Command: `rtk proxy bash tests/review-context-boundary.tests.sh`
Result: exit 0; 31 citation anchors and 22 runtime cases (11 each in Bash and
macOS PowerShell) passed. Native Windows was not executed. These are existing
boundary checks, not evidence that ADR admission is fixed.
The round-2 suite was inspected but not run in this dirty worktree because it
temporarily rewrites the shared workflow registry (suite lines 33–47).

The identity ledger hashes identity fields, not input manifests
(`validate-review-context-set.sh:549`). Preserve that limitation explicitly:
this extension proves current cross-artifact consistency, not cryptographic
authenticity against an actor rewriting all historical evidence. No claim that
the ledger independently prevents deleting every ADR binding is justified.
