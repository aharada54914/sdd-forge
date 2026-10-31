# Requirements: epic-136-phase2-gates

Spec-Review-Status: Passed
Source Issues: https://github.com/aharada54914/sdd-forge/issues/117,
https://github.com/aharada54914/sdd-forge/issues/118,
https://github.com/aharada54914/sdd-forge/issues/119,
https://github.com/aharada54914/sdd-forge/issues/121,
https://github.com/aharada54914/sdd-forge/issues/122
Epic: https://github.com/aharada54914/sdd-forge/issues/136 (Phase 2)

## Overview

Complete the Phase 2 consistency and security work in Epic #136. The work
corrects cross-runtime false denials without weakening write protection,
removes a timing-leaking PowerShell signature comparison, extracts duplicated
PowerShell path validation, prevents a risky task from selecting the lite
track even with `--lite`, and makes guard constants generated from one
protected canonical data source.

The verified Phase 1 guard prerequisite branch
`feature/epic-136-phase1-guards` is a required baseline: its #109/#110 guard
parity and CWD resolution are incorporated before this feature starts.

## Target Users

- Maintainers and agents operating the deterministic guard through Codex,
  Claude Code, GitHub Copilot, or the PowerShell fallback.
- Windows PowerShell 5.1 operators who use signed `SDD_SUDO` tokens.
- Authors of small internal changes who need a deterministic escalation before
  lite SDD omits full review and traceability artifacts.
- CI reviewers who need generated guard modules to be reproducible and stale
  generated files to fail the build.

## Problems

- The shared guard tokenizer treats an escaped read-only pattern as unknown and
  a harmless stderr redirect as a write, denying legitimate inspection. It can
  lead operators to avoid the guard rather than trust its real denials (#117).
- The PowerShell fallback compares an HMAC hex string with `-ne`, whose
  duration can depend on the first different character (#118).
- `check-contract.ps1` repeats evidence-path safety checks for ordinary, red,
  and green evidence, so security fixes can drift across the three sites
  (#119).
- Lite selection is based only on flags/profile. A task involving auth,
  tokens, MCP, external APIs, secrets, or GitHub Actions can choose `--lite`
  and evade the full workflow (#121).
- The Python, JavaScript, and PowerShell guards duplicate the protected-path
  and shell-classification invariants. Manual parallel edits have already
  caused parity regressions (#122).

## Goals

- REQ-001: In the Python, JavaScript, and PowerShell guard twins, permit a
  genuinely read-only command containing a literal backslash inside a balanced
  quoted regular expression (for example `grep -n "R-10\\|R-11" <path>`) or
  a stderr-only redirect such as `2>&1`; also permit read-only inspection
  (`ls`, `cat`, `find`) of a protected path. Unquoted backslash escapes that
  alter token boundaries, unclosed quotes, a redirect mixed with an unresolved
  target, and every ambiguous command remain denied. An actual write to a
  protected target remains denied. Decisions must remain cross-runtime equal.
  (Issue #117)
- REQ-002: In `sdd-hook-guard.ps1`, validate the supplied `sig` as exactly
  64 hexadecimal characters, decode both expected and supplied HMACs to 32
  bytes, and perform a full byte-wise XOR accumulation before deciding. The
  helper must not use `CryptographicOperations.FixedTimeEquals`, which is not
  available in Windows PowerShell 5.1. Invalid signatures, malformed tokens,
  and any XOR difference must fail closed without leaking token material.
  (Issue #118; human decision 2026-07-13)
- REQ-003: Replace all three inline evidence-path validators in
  `check-contract.ps1` with one internal helper that receives the field label,
  path, and repository root and returns a structured validity/failure result.
  Preserve byte-for-byte-equivalent failure wording for `evidence`,
  `red_evidence`, and `green_evidence`, including POSIX absolute, Windows/UNC
  absolute, unresolvable, traversal, and missing-file failures. Before the
  refactor, capture reviewed golden fixtures containing complete stdout/stderr
  and exit status for every field-by-case pair; after the refactor, TEST-005
  and TEST-006 compare those fixtures exactly after LF normalization. (Issue
  #119)
- REQ-004: Define one deterministic risk-upgrade policy specified in the
  [Risk-upgrade policy contract](#risk-upgrade-policy-contract). If the
  requested source or task-scoped metadata concerns authentication/
  authorization, credentials or access tokens, MCP, an external/third-party
  API, a secret, or GitHub Actions, lite specification creation must stop
  before writing a lite spec and ship must force the **full** track. This
  escalation takes precedence over `--lite`; an incomplete lite feature then
  fails closed with a bootstrap instruction instead of silently running lite.
  (Issue #121; human decision 2026-07-13)
- REQ-005: Store the minimal common guard invariants in one protected,
  versioned canonical data file and generate deterministic native modules for
  Python, JavaScript, PowerShell, and the shell dispatcher. Runtime guards
  must import/source only their generated native module and must not parse the
  canonical data at runtime. A build-time generator `--check` mode must
  compare every generated module with its expected output and CI must fail
  closed on any difference. The canonical data, generator, generated modules,
  and human-copy procedure itself must be R-10 protected. The complete
  protected candidate set is the normative inventory in
  [Protected Phase 2 target inventory](#protected-phase-2-target-inventory).
  The Windows human-copy runner must read its canonical authority, manifest,
  and every staged source through no-follow handles anchored at an opened
  repository root; hash and later copy each source from the same held handle;
  and publish each verified temporary file by a destination-parent-handle-
  relative atomic rename. It must never overwrite a live target by following
  its path, symbolic link, reparse point, or hard-link alias. Unsupported
  Windows, filesystem, PowerShell language mode, or native API conditions fail
  before the first live replacement. TEST-013 must also inject a rename-phase
  failure after a fixed inventory index in an isolated fixture-only instrumented
  runner, prove the resulting live state is exactly the new candidate prefix
  followed by the recorded previous suffix, and apply a reviewed complete
  rollback batch that restores every pre-install digest and passes post-install
  verification. (Issue #122; human decisions 2026-07-13 and 2026-07-14)

## Risk-upgrade policy contract

The policy is deterministic, local, ASCII-case-insensitive, and does no remote
issue retrieval. The checker decodes UTF-8 source text, rejects NUL or invalid
UTF-8, converts CRLF/CR to LF, and applies the ordered trigger matrix below to
word/token boundaries. The first matching ID is the primary diagnostic; all
matching IDs are emitted in this same order. A policy match prints
`full-required: <primary-id>; triggers=<comma-separated-ids>` and returns exit
10. No match prints `lite-eligible` and returns 0. Missing, unreadable, or
malformed input prints `risk-upgrade: input unavailable` and returns exit 2.

| Order | ID | Normalized lexical rule | Exclusion / boundary |
|---:|---|---|---|
| 1 | `AUTH_BOUNDARY` | `auth`, `authentication`, `authorization`, `oauth`, or `oidc` as whole tokens | No substring match (`author`, `oauthless`). |
| 2 | `TOKEN_CREDENTIAL` | `token` or `tokens` as a whole token, or `credential`/`credentials`, `password`/`passwords`, `private key`/`private keys` | An occurrence wholly inside `design token` or `design tokens` is removed before matching; any other token still matches. |
| 3 | `MCP` | `mcp` as a whole token | No substring match (`mcpish`). |
| 4 | `EXTERNAL_API` | `external api`/`external apis` or `third-party API(s)` / `third party API(s)` with whitespace/hyphen normalization | `API design` alone never matches because an external/third-party qualifier is required. |
| 5 | `SECRET` | `secret` or `secrets` as a whole token | No substring match (`secretion`). |
| 6 | `GITHUB_ACTIONS` | `github actions` with one or more normalized whitespace characters | No substring match (`github-actionable`). |

For `lite-spec`, the input is the full user-supplied requirement/source body
resolved before any file is created. An opaque URL without readable source text
is input-unavailable and therefore stops the lite flow. For `ship`, the input
is the selected task's complete `## T-NNN` block followed by that feature's
`requirements.md`; both files are mandatory whenever lite could otherwise be
selected. If one is absent or unreadable, the selected task is full-required
with an input-unavailable diagnostic. `--full` remains valid without scanning;
every default/profile/`--lite` route invokes the checker before lite selection.

## Protected Phase 2 target inventory

The canonical `phase2_human_copy_targets` array contains this exact normalized,
unique, repository-relative set. No manifest entry may omit, add, or duplicate
a target. It is also generated into the R-10 protected suffix table before the
human-copy run completes:

1. `plugins/sdd-quality-loop/scripts/sdd-hook-guard.py`
2. `plugins/sdd-quality-loop/scripts/sdd-hook-guard.js`
3. `plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1`
4. `plugins/sdd-quality-loop/scripts/sdd-hook-guard.sh`
5. `plugins/sdd-quality-loop/scripts/check-contract.ps1`
6. `plugins/sdd-lite/references/risk-upgrade-policy.md`
7. `plugins/sdd-lite/scripts/check-risk-upgrade.sh`
8. `plugins/sdd-lite/scripts/check-risk-upgrade.ps1`
9. `plugins/sdd-lite/skills/lite-spec/SKILL.md`
10. `plugins/sdd-ship/skills/ship/SKILL.md`
11. `plugins/sdd-quality-loop/references/guard-invariants.json`
12. `plugins/sdd-quality-loop/scripts/generate-guard-invariants.py`
13. `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py`
14. `plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.js`
15. `plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.ps1`
16. `plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.sh`
17. `.github/workflows/test.yml`
18. `specs/epic-136-phase2-gates/human-copy/apply-protected-files.ps1`

`MANIFEST.sha256` is deliberately not an R-10 live target: it is a disposable,
human-reviewed batch input next to staged candidates and is never copied into a
live enforcement path. The immutable R-10 copy runner validates the current
batch manifest against the canonical allowlist, but an agent may prepare a new
candidate manifest for human inspection. The manifest cannot add, omit, or
remap live targets because the runner derives the allowed set and paths from
the protected canonical data.

## Non-goals

- Building a full shell interpreter or allowing unclassifiable command text.
- Changing the signed-token format, its 24-hour TTL limit, or key handling.
- Treating all uses of the words `token` or `API` as risky; the policy uses the
  exact documented phrases and exclusions.
- Loading JSON or another mutable data source during a guard decision.
- Bypassing R-10 protection or replacing the human copy authority with sudo.

## User Stories

- As an operator, I can run a grep with an escaped expression and redirect
  stderr without a false denial, while a write to the same protected file is
  still denied.
- As a PowerShell 5.1 operator, I know that a forged sudo signature is checked
  without early character comparison.
- As a lite-task author, I am automatically placed on the full track when the
  task crosses a security or external-system boundary, even if `--lite` was
  requested.
- As a maintainer, I edit one canonical guard-invariants document, generate
  native modules, and rely on CI to reject stale or hand-edited output.

## Acceptance Criteria

See [acceptance-tests.md](acceptance-tests.md). Each criterion is tied to a
deterministic suite and a saved quality-gate report before it may be marked
Done.

## Roles and Permissions

| Role | Permission | Constraint |
|---|---|---|
| Agent | Stage tests, specifications, generator, and human-copy candidates | Cannot write protected live enforcement-chain files. |
| Human maintainer | Verify hashes and copy staged protected files | Must run the supplied copy script and named suites. |
| CI | Regenerate in check-only mode | Fails on any generated-diff or failed test. |

## Main Workflows

1. A maintainer stages a protected source candidate under `human-copy/`, runs
   the manifest verifier, and uses the PS5.1-compatible anchored-copy runner.
   The runner opens the repository root, canonical authority, manifest,
   sources, and destination parents without following reparse points; prepares
   and hashes every same-directory temporary file before any live replacement;
   atomically replaces live directory entries in inventory order; and then
   runs focused tests.
2. The generator reads canonical data only during build/test time, writes each
   native module deterministically, and `--check` detects stale output without
   mutating the worktree.
3. Ship scans policy text before selecting a track. A risk match wins over
   `--lite`, selects full, and validates full-track artifacts.

## Edge Cases

- A backslash in a read-only regex is permitted only after the command is
  conclusively classified as read-only; ambiguous escapes remain denied.
- `2>&1` is not a write target, while `>` or `>>` to a protected path remains
  a denial.
- A non-hex, short, long, or mixed invalid signature never reaches byte
  comparison and returns inactive.
- An absent generated module, malformed canonical data, unsupported schema
  version, or generator error fails check mode.
- A policy hit with missing full artifacts fails before implementation; it
  never falls back to lite.
- A pre-existing target reparse point is rejected. A hard-linked target is
  replaced as a directory entry, so another hard-link name outside the target
  inventory remains byte-for-byte unchanged.
- A source or destination-parent rename/delete/substitution attempt after
  validation fails while the runner retains non-delete-sharing handles. A
  native API, Add-Type, local-drive, or supported-filesystem check failure
  exits before any live target is replaced.

## Security Boundaries

| Trust Boundary | Auth/Authz Requirement | PII / Data Classification | Regulatory Constraints |
|---|---|---|---|
| Agent shell payload to guard | R-10 deny-by-default and cross-runtime parity | Integrity-critical internal source | None |
| `SDD_SUDO` token to PowerShell verifier | HMAC-SHA256; full XOR comparison after shape validation | Restricted ephemeral credential | None |
| Canonical invariant data to generated runtime module | Human-copy authority plus deterministic generator and CI diff check; root-handle-relative no-follow reads and atomic entry replacement | Integrity-critical internal source | None |
| Lite request to ship selection | Risk-upgrade policy before flag/profile selection | Internal task metadata | None |

## Assumptions

- The generator can use Python at build/test time; Python is already the
  primary dispatcher runtime and no dependency is introduced.
- `sdd-hook-guard.sh` is a dispatcher, not a guard evaluator; its generated
  module is sourced for schema/provenance parity, while Python/JS/PS consume
  the decision constants.
- The user-approved `sdd-sudo` session is an approval bypass only; deterministic
  review, test, and quality gates remain mandatory.
- The protected-copy runner is executed only by Windows PowerShell 5.1 in Full
  Language mode on a local drive and a filesystem accepted by its native
  capability preflight. The reviewed minimum is NTFS; every other condition is
  rejected before live replacement.

## Open Questions

None. The user selected the PowerShell algorithm, forced full escalation, and
the generated-module architecture on 2026-07-13, then authorized the
root-handle-relative no-follow copy architecture on 2026-07-14.

## Risks

- Incorrectly relaxing tokenization could turn a false-denial fix into a write
  bypass. Cross-runtime positive and negative corpus tests are required.
- A generator that is not itself protected would make the canonical data model
  cosmetic. It is included in the generated protected suffix set.
- Broad policy matching could disrupt ordinary lite work. Exact fixtures and
  documented negative cases constrain it.
- Windows native handle semantics and structure layout are security-critical.
  Static API-contract tests, hard-link and namespace-substitution tests, and an
  independent security review constrain the embedded C# implementation.
- The 18 live entry renames are individually atomic, not transactionally atomic
  as a batch. All sources and temporary outputs are verified before the first
  rename; a rename-time OS failure can leave an installed inventory prefix and
  requires the documented reviewed complete rollback batch. An isolated
  fixture injects that failure after a fixed index, verifies the exact
  prefix/suffix digest state, then proves the rollback restores all 18 recorded
  pre-install digests and post-install verification.
