# Issue 423 T-002 evaluator launch preflight — 2026-10-04

Status: preparation only; NOT RESERVED; evaluator NOT LAUNCHED; no quality verdict.

## Verified current state

- The 39 unique entries in `reports/verification/issue423-t002-evaluator-input-candidate-20261004.json` matched current file hashes. Its implementation-manifest and post-fix-declaration pins also matched. This is byte verification, not invocation-schema acceptance.
- Read the owner quality-gate skill and review-context launch boundary. Formal quality-gate must be called through ship and use a fresh isolated evaluator, the live model selector, a canonical invocation, and the real reservation receipt.
- Observed ledger tip: sequence `1195`, record `518f8e2150aace36c470ea659ca931535bb83eaa59e14d834322d79c3f1c9539` (`task` / `task-reviewer-b`). Re-read immediately before a future reservation; this observation is not ledger validation.
- Existing changes and reservations were preserved. No installation, human-only runner, reservation, or evaluator launch was performed.

## Concrete unresolved launch conditions

1. **Implementation-manifest filename contract mismatch.** Candidate pins `handoffs/issue423-t002-recovery-20261003/manifest-archive-input.json`; canonical T-002 report line 72 cites exactly that file. Validator `validate-review-context-set.sh:422` only accepts `^handoffs/[A-Za-z0-9._-]+/manifest[.]json$`. Both manifest files carry the same real recovery run/session, but changing only the candidate to `manifest.json` would fail the exact report citation check at lines 277–282. `verify_implementation_binding` also requires a pinned manifest for new evaluators. Do not silently rename, omit the binding, or substitute a different report. This is a current pre-reservation mismatch, not a request to repeat already-applied repairs. Any resolution must preserve truthful report provenance and its applicable authorization boundary.
2. **Old implementation candidates cannot select the required evaluator tier.** Command below exited 0 but printed `BLOCKED model-tier-unavailable`; it did not select a usable model. Existing file contains only `anthropic/sonnet`, effort `medium`. Registry role default requires `strong` for `sdd-evaluator`. Prepare a genuine available Codex candidate with registry-enumerated model/effort and a grounded cost value; do not infer availability from this old implementation file.
3. **Actual hook refusal during required role/reference read.** Command below was rejected before execution. Do not retry through another executor or transformed command. Role comment drift check and bundled rubric/calibration reads are not claimed complete.

```sh
rtk proxy bash plugins/sdd-implementation/scripts/select-agent-model.sh --risk medium --registry contracts/agent-model-capabilities.v2.json --candidates-file handoffs/issue423-t002-20260928/candidates.json --role sdd-evaluator --host codex-cli --json
```

Output: `BLOCKED model-tier-unavailable` (exit 0).

Rejected command:

```sh
rtk proxy cat plugins/sdd-quality-loop/references/evaluation-rubric.md plugins/sdd-quality-loop/references/quality-gate-calibration.md .codex/agents/sdd-evaluator.toml
```

Exact refusal:

```text
Command blocked by PreToolUse hook: SDD決定論ゲート: developer_instructions の無い Codex エージェントロールファイルの書き込みを拒否しました。.codex/agents/ 配下のファイルは developer_instructions を定義する必要があり、無い場合 Codex は起動時にこれを無視します（'Ignoring malformed agent role definition'）。新規作成せず、同梱の sdd-investigator / sdd-evaluator ロールを使用してください。
[EN] SDD deterministic gate: refusing to write a Codex agent role file without developer_instructions. Files under .codex/agents/ must define developer_instructions or Codex ignores them at startup ('Ignoring malformed agent role definition'). Use the shipped sdd-investigator/sdd-evaluator roles instead of creating new ones.. Command: rtk proxy cat plugins/sdd-quality-loop/references/evaluation-rubric.md plugins/sdd-quality-loop/references/quality-gate-calibration.md .codex/agents/sdd-evaluator.toml
```

## Proposed ordered commands and input conditions (not executed)

Run from this owner checkout, with shell login disabled. Parent coordinates a single reservation owner.

1. Resolve the three conditions above without bypassing protections. Run selector with a real fresh evaluator candidates file:

   `rtk proxy bash plugins/sdd-implementation/scripts/select-agent-model.sh --risk medium --registry contracts/agent-model-capabilities.v2.json --candidates-file <actual-codex-evaluator-candidates.json> --role sdd-evaluator --host codex-cli --json`

2. Obtain actual fresh host-session identity before reservation; never fabricate it or reuse the implementer or a previously reserved evaluator. Allocate an evaluator scratch root distinct from all feature implementation scratch roots and previous evaluator reservations. Build an invocation with exact schema keys from validator lines 393–454: base keys plus `task_id`, `implementation_manifest`, `gate_report_declaration`, and `scratch_root`. Constants: schema `review-context-invocation/v2`, stage `quality`, role `sdd-evaluator`, feature `sdd-domain-multitarget`, task `T-002`, input_mode `file-manifest`, fallback_mode `none`, read_only `true`. Pin current pre-append ledger SHA and tip, current admitted hashes, and the valid implementation binding. The existing preparation JSON is not this invocation.
3. After parent confirms the real invocation path/identity and exclusive reservation ownership:

   `rtk proxy bash plugins/sdd-quality-loop/scripts/validate-review-context-set.sh <actual-invocation.json> /Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge --reserve`

4. Only after actual `REVIEW_CONTEXT_OK`, launch exactly the reserved fresh shipped evaluator using selector-returned validated model/effort. Pass the manifest and the full real receipt; no peer raw review or undeclared reports through prompt prose. Quality records use the scratch-declaration hash extension; evaluator must not rehash the pre-append ledger pin after reservation. No second reservation for the same identity.

The new installer-impact/readiness/preflight reports are not among the original 39 admitted inputs; do not smuggle them into evaluation. Expanding inputs requires the legitimate declaration channel and new hashes, not an implied authorization from this note. Current installer tests and payload equivalence findings are separately documented in `issue423-t002-installer-impact-20261004.md`; they do not decide formal quality, CI, Done, merge, or issue closure.
