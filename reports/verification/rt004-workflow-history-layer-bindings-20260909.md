# RT004 historical layer and previous-summary bindings — 2026-09-09

Status: candidate patch DATA only. No protected implementation applied or candidate code executed.

Candidate: reports/verification/adr-workflow-bash-history-candidate-20260909.patch
SHA256: 2ca0f5c7cd7e55b0484a5c683355d1098b3cde5ffe5d7071ce3f2ea9ae142b0f
Original check-workflow-state.sh SHA256 unchanged: 15a4ef0a72c8be78c40b38e692ee7a46d8664d825e61ab99915086dae0f02d1e

## Evidence and change

The prior candidate permitted layer paths and the previous summary path but did not require every precheck layer hash in all four saved manifests, nor reviewer A's previous-summary hash. This matters before check-workflow-state.sh:826 returns for a verified opening.

- impl-review-precheck.sh:89-98 defines complete four-layer precheck pins and live verification; :222-230 emits either the full map or empty legacy map.
- impl-review-loop/SKILL.md:95-106 and :221-228 require reviewer A's previous-round summary and its exclusive role binding.
- impl-review-loop/SKILL.md:124-143 specifies summary check IDs/counts only, without qualitative narrative.
- impl-review-loop/SKILL.md:208-218 requires full-profile layer pins in both reviewer manifests.

The candidate now requires each pinned layer path/hash in contract A/B and actual reviewer A/B output manifests. Existing empty-map legacy/superset semantics remain unchanged; extension-absent rounds still follow their existing path.

For round > 1 it safely opens the canonical previous-round summary, hashes it, binds that hash in both A manifests, checks its round/attempt/count-only schema, and rechecks its path and hash after consumption. It does not read historical ADR contents from the current worktree. The existing role allowlist still prohibits giving the previous summary to B.

Current and prior summaries are checked for the documented eight keys, nonempty distinct check IDs, nonnegative integer counts, and count totals. The current summary additionally remains checked against actual reviewer A outcomes. Prior summary identity/count shape and pinned bytes are validated; this is not a claim of recursively re-reviewing every prior round or authenticating a complete coordinated rewrite of saved evidence.

## Primary review and verification limits

Primary source review: no newly identified Critical issue in these additions. They close missing saved-binding checks, preserve original files, and do not relax ADR authorization or existing checks. Not an independent security review or quality-gate verdict.

Static hunk counts, cumulative offsets and all seven original-source anchors verified: PASS, 372 added lines total. git diff --check: exit 0.

No candidate runtime was executed. Existing actual historical tests remain recorded RED (2 passed / 6 failed); no claim of fixing them until authorized application and real execution. Full positive extended fixtures, PS5.1 workflow parity, native Windows, independent security/contract review, formal re-review and required CI are still pending.

Remaining primary review points: exact producer semantics for terminal integrated verdicts; byte-replacement/race limits; Bash Windows reparse detection; duplicate JSON keys. The summary template guessed during discovery does not exist; the authoritative schema was read directly from the skill instead. No product change was based on that missing file.

No commit, push, merge, task Done, ticket resolution or issue close.
