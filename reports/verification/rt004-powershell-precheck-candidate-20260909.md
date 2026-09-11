# RT004 PowerShell precheck candidate checkpoint

Status: incomplete, unapplied patch data. Not ready for human application.
Ticket remains open; this is a primary inspection, not independent approval.

Candidate: `adr-precheck-powershell-generation-candidate-20260909.patch`
SHA-256: `096fcc83db40c6cb11155b703a61f4fd00ed6c620ae7dcc89ef0ac66fe0e5030`.

## Work completed in candidate data

- Reused the admission candidate's restricted byte lexer and component checks,
  with local raw canonical-path and root ReparsePoint checks. No new shared
  unprotected helper is introduced.
- Generation checks the design path before hashing, derives all declared ADRs,
  hashes safe files, rechecks design after collection, and records explicit
  empty/single/multiple ADR arrays with path/sha256 key ordering.
- Verification checks safe precheck/design paths, exact array entries, ordinal
  sorted uniqueness, complete declared-set/hash equality and total input hash.
- Existing core/layer and predecessor checks remain. The ADR hash suffix is
  the same proposed `:adr_inputs/v1:` representation as the Bash candidate.

## Primary review and verification limits

Patch generation initially mishandled JavaScript replacement-string dollar
syntax and duplicated source text. Inspection caught it before any application;
replacement was corrected to a callback that preserves literal dollar signs.
Exactly one lexer definition remains. No malformed candidate was executed.

Six patch-data hunk counts/offsets and removed lines were compared against the
PowerShell source read this turn: 1/141, 1/3, 1/34, 1/3, 1/2, 1/1. All matched.
This is data inspection, not applying the patch or parsing/executing PowerShell.
No new regression or native Windows run was performed. No copied protected
validator was executed. Previous baseline test counts remain unchanged.

Overall disposition: NEEDS_WORK. Outstanding risks/requirements:

1. Prove exact Bash/PowerShell serialization, including layer ordering and
   empty/singleton array shape, using actual consumer fixtures after application.
2. Verify malformed and duplicate-key JSON behavior and strict layer shape;
   the existing PowerShell object parser and property lookup need explicit
   negative cases, including casing and null. No general parser parity claimed.
3. Add generator/verify-specific RED and regression fixtures and persisted-field
   mismatch preflight; admission-only fixtures do not meet this requirement.
4. Complete ADR-only next-round handling, saved contract bindings, downstream
   task/workflow consumers and native filesystem tests. Windows Bash reparse
   handling remains unresolved. Metadata checks are not atomic file access.
5. Helpers expand an already large protected consumer beyond the general
   500-line preference. The approved plan forbids adding an unprotected shared
   authorization helper; independent review must consider the bounded duplication.

Only after the complete package passes independent security/contract review
should human application be requested. Existing CI and all formal gates remain
required. No protected runtime, historical verdict, task status, commit, push,
PR state or issue state was changed.
