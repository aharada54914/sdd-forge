# Spec reviewer hash capability repair

Owner: `/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge`
Observed HEAD: `d64cffcb22b114779202847be33e41700c4ba11f`
Scope: spec-reviewer-a/b only, plus focused regression. Existing dirty files preserved. No commit, push, reservation, formal review, or attempt-10 edits.

## Cause and change

Both spec role frontmatters omitted Bash while the review boundary requires independently recomputing file/record SHA256. Existing implementation roles already declare Bash and constrain its use to read-only operations (`plugins/sdd-review-loop/agents/impl-reviewer-a.md:4,16`, reviewer B `:4,17`). The spec fix follows that supported capability form, but restricts it more narrowly to SHA256 of manifest-admitted file bytes and boundary-defined record text. It forbids arbitrary commands, interpreters, substitutions, writes, redirects, network, reservations, unlisted reads and post-reservation ledger rereads. Existing input manifests, identity rules, tool denials and output schemas remain unchanged.

Normal apply_patch accepted both role edits. No protection refusal occurred; no human batch or alternate executor was needed.

## Verification

- RED: `rtk proxy python3 tests/spec-reviewer-hash-capability.tests.py`: both spec-role subtests fail because Bash is absent; hash utility test passes.
- GREEN: same command after repair: 3 tests PASS. Tests cover both roles' capability/boundary declarations, file content and mtime preservation, exact UTF-8/no-final-newline record hashing, and safely quoted metacharacters that remain data in the documented printf/rtk pipeline.
- `rtk proxy bash tests/review-agent-isolation.tests.sh`: exit 0. Sequential authorization/hash-chain checks PASS; nested scratch history Bash + PowerShell: PASS 26, FAIL 0.
- `rtk proxy git diff --check -- plugins/sdd-review-loop/agents/spec-reviewer-a.md plugins/sdd-review-loop/agents/spec-reviewer-b.md tests/spec-reviewer-hash-capability.tests.py`: exit 0.

## Current output pins

| File | SHA256 |
|---|---|
| plugins/sdd-review-loop/agents/spec-reviewer-a.md | b893ea99743fb87ee3ff8c3beba333f6c92931ac1737e4346beaefaf9b0d4e0a |
| plugins/sdd-review-loop/agents/spec-reviewer-b.md | 86b680407c50e582b7b1d7baca5030b66d2df931a7a8b928be52af3ee25ef298 |
| tests/spec-reviewer-hash-capability.tests.py | 44a9d78facb38eabe77dbc9fc919ee6993fb94d7d1a72d13ab29ba41116b96b5 |

## Independent localized code review

Independent agent `/root/a7_hash_role_review` inspected the two role diffs, boundary instructions and focused test source in a fresh context. It reported zero Critical, Major or Minor findings, independently reran the 3 focused tests and isolation suite (26 nested checks, exit 0), checked scoped whitespace and recomputed all three output hashes against this report. This is localized code-review evidence only, not a reserved SDD review or quality-gate verdict. It confirmed the existing manifest, identity, independent-session and no-ledger-reread restrictions remain unchanged.

## Remaining native verification

The restriction is the role's instruction contract, not a newly implemented OS-level command sandbox. These local tests do not prove installed-role refresh, a native launched reviewer's available tools, formal review results, gate PASS or Done. Fresh launch must use the changed role bytes and independently satisfy its existing identity/manifest contract. No source precheck, ledger or task-state change was made by this repair.
