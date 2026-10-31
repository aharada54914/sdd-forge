# A8 native boundary and AC-016 diagnostic — 2026-10-06

Owner: `/Users/jrmag/.codex/worktrees/a8-release-sync-oct01/sdd-forge`; HEAD `495c88d67af44530687ecea3ce9fb0a90a336539` (detached). This record is diagnostic evidence, not a formal SDD verdict, task transition, installed-host proof or CI result. Earlier verdicts and reservations are unchanged.

## Native pre-dispatch permission check

With ordinary Claude Sonnet `dontAsk` settings, `--allowedTools Bash(rtk proxy pwd)` and no bypass flags, the ECC Fact-Forcing Gate denied the first `rtk proxy pwd` request. After the command purpose and facts were provided as requested by that gate, the same command ran. In that same session, a changed chained request, `rtk proxy pwd; rtk proxy pwd`, also ran despite the exact-command allowlist. The native session was `b57c7a9b-1a09-4735-b1e2-9dea9a391b6b`; no SDD guard or host settings were disabled or edited. This proves that the effective permission policy does not yet reject chained commands as required by `plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md` under “Required spec reviewer digest capability.” The ECC first-request denial and the later overly broad effective permission are separate observations.

No fresh A8 reviewer identity was reserved and no formal reviewer was dispatched. The missing negative permission boundary remains a pre-reservation stop; a fixture or an independent diagnostic review cannot replace it. The exact source of the inherited effective allowance had not yet been isolated at this point; see the follow-up below. Neither a settings rewrite nor an alternate executor was attempted.

### Follow-up: session-local narrowing

The current Claude CLI documents `--allowedTools` as additive, not an exclusive allowlist. The user and local settings contain existing broad Bash allow rules; an isolated `--disallowedTools 'Bash(rtk proxy pwd; *)'` session still executed the chained command after the ordinary ECC fact gate. Thus that deny pattern is not a proven boundary here. This follow-up does not modify global settings.

An additive `--settings` PreToolUse Bash hook using `reports/verification/a8-exact-bash-hook-20261006.mjs` compares the complete Bash `tool_input.command` byte-for-byte with one caller-pinned command and denies every mismatch. Direct hook tests passed one positive, seven changed-command negatives (argv, path, `--reserve`, redirection, substitution, chain, pipeline), and three malformed-input negatives. A native Claude Sonnet `dontAsk` session (`93dfa5a5-7616-4efb-b336-402a45f87f9a`) kept the existing ECC fact gate: its first negative call was denied by ECC, then the same chained command was denied by the additive A8 hook after truthful fact presentation, while the single allowed `rtk proxy pwd` executed. No denied operation was retried through another executor.

This is proof for the diagnostic `pwd` command only, not the final digest-calculator invocation. The fuller native negative matrix was attempted in a new session but returned Claude HTTP 429 session limit, with reset reported for 21:50 Asia/Tokyo; no additional negative result can be claimed. Before formal allocation, the actual fixed manifest/receipt calculator command, hook bytes, settings overlay and full negative matrix still need exact pinning and native confirmation. No identity was reserved.

## AC-016 amendment

The ten-document AC-016 appendices were already present when inspected. Nine current documents matched pinned preimage plus appendix; `requirements.md` additionally had the legitimate status normalization `Spec-Review-Status: Passed` to `Pending`. No second application was made. The amended design requires `live-host-verification-record/v2` to carry exactly five signed `consumer_inventory` entries and rejects missing, duplicate, unknown, mismatched or malformed entries before discharge. The corresponding acceptance, task, traceability, layer and ADR text was checked for the same contract.

`rtk proxy python3 -B reports/verification/a8-ac016-minimal-contract-tests-20261006.py` passed 7/7 tests with 90 negative candidate mutations rejected. The test also confirmed that the original v1 validator can discharge a record without this inventory (RED), and verified the append-only document pins. The candidate test was repaired only to reconstruct its pinned pre-application fixture from the already-applied current documents. `rtk proxy git diff --check` passed.

An independent, read-only Claude Sonnet diagnostic review (session `df7f1ce8-7f69-46b8-a8a4-4ee2dc67bef5`, no permission denials, no Bash or editing) found no Major/Critical defect in the AC-016 amendment and judged the prior Reviewer B DESIGN-WITHIN-SCOPE Major addressed at design level. This is not a formal review gate. Its review did not read the final paragraphs of `ux-spec.md` and `frontend-spec.md`; no completeness claim is made for those paragraphs.

The production `validate-live-host-proof.py` still accepts v1 only. T-005 remains Planned, and T-001/T-002 prerequisites and live native proof remain outstanding. No implementation, quality-gate PASS, CI, commit, push, PR, installed-baseline promotion or task Done claim follows from this record.

## Native continuation after the 21:50 JST quota reset

Scope before work: A8 owner checkout and detached HEAD remain as above; the worktree has extensive pre-existing dirty product/spec/ledger changes. This continuation changes only two untracked diagnostic settings overlays and this report. The affected boundary is the high-risk spec reviewer digest permission contract in `plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md`. Required validation is a normal Sonnet host positive/negative matrix, with existing ECC, approval, sandbox and global settings retained. No other owner's files or ledger records are edited here.

An ordinary `claude -p --model sonnet --tools '' --permission-mode dontAsk` call returned `READY` in session `490eded0-cb29-44e6-84d2-5456406ac02e`; the earlier 429 had cleared. No bypass flag or settings-source exclusion was used.

For the diagnostic `rtk proxy pwd` command, the additive settings overlay `a8-native-exact-pwd-settings-20261006.json` used the existing exact-command hook. In native Sonnet session `fd83f085-2607-4347-9672-2460e9a3c544`, the normal ECC fact gate first denied a changed command; after its requested facts were stated truthfully, the hook denied seven distinct Bash requests: appended `--reserve`, extra argv, different command/path, stdout redirection, command substitution, semicolon chaining and a pipeline. Each appears in the CLI's `permission_denials` list. The exact positive `rtk proxy pwd` executed and returned this owner worktree path. This session did not reserve identity or modify settings outside the additive overlay.

The actual proposed Reviewer A calculator command was pinned as:

```text
rtk proxy bash plugins/sdd-quality-loop/scripts/validate-review-context-set.sh reports/review-context/a8-spec-attempt4-round1-spec-reviewer-a.json /Users/jrmag/.codex/worktrees/a8-release-sync-oct01/sdd-forge --reviewer-receipt reports/review-context/a8-spec-attempt4-round1-spec-reviewer-a.json.receipt.txt
```

The additive `a8-native-exact-calculator-settings-20261006.json` pins precisely that complete Bash command. In native Sonnet session `fd3c2181-40cd-409d-a7da-bedc649be168`, the normal ECC gate first denied an extra-argv attempt; after the requested facts were stated, the A8 hook denied the same changed command. The exact positive reached Bash with no permission denial, then the calculator exited 1 with `REVIEWER_DIGEST_ERROR` because the future manifest/receipt do not exist. This is host permission proof and fail-closed missing-input behavior, not a successful digest. Six further distinct commands (different manifest path, appended `--reserve`, redirection, substitution, semicolon chaining, pipeline) were denied by the A8 hook; all six are in the CLI's `permission_denials` list. Together with the first extra-argv denial, the proposed calculator has seven native changed-command negatives and one native positive admission. No denied command was retried through another executor.

Pinned SHA-256 values at this observation: exact hook `56086cf4c45d2375ab4642abdd669138b415c95bcfc6a3aeb2571e6e1e4c79fc`; diagnostic pwd overlay `d85a418015aa1648fe5619d77839919c0b65ba418d7ef13056dc1a8ea701d0b0`; proposed calculator overlay `1e4f1004047692a000cc4f8ca2fb3a546010e7c4e474abc0df2ae4a413b760f5`; calculator entrypoint `96cda1dde7dda85bd1fa16891f471fd8b3297b29c244bb22a4a040f6b33ca696`; calculation module `08785f133567ed2fc24084332819f75d56e94e0afb6dfb33fa3b5cc2a2866b1b`.

The proposed manifest path and receipt sidecar are not yet created. The candidate launcher, role definitions and amended specification still need the applicable formal admission/review; actual reviewer identity allocation, reservation, digest success, host identity correspondence, independent reviewer verdict and exact-final-head CI remain unverified. These diagnostics do not advance a formal task status.
