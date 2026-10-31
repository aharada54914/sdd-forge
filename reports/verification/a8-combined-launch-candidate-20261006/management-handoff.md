# Management repair authority and application handoff

Recorded 2026-10-06. This is a non-frozen management record, not a product review verdict, task approval or release decision. Preserve scope.md and results.md as the preparation-stage history.

## Existing human authority

The human explicitly requested repair of the protected reviewer contract and its live launch, alignment of required inputs with prechecks/validators, and repair of missing reviewer hash-calculation capability. The conversation includes:

- 「レビュー役に必要なハッシュ計算手段が許可ツールに含まれていないなら直しなよ」
- 「保護対象のレビュー契約修復、実ホスト検証、#380の定期実行証拠待ちを解決してよ」
- 「必須入力と事前検査・検証器が一致するようにして」
- 「全部承認する 追加で何回でもレビュー、限定修正して良い」

These authorize a bounded shared launch-contract management repair, rather than expansion of A8 T-004's test-only Planned Files. The combined change separates caller run identity from a real allocated host session, specifies delivery only after ordinary admission, and adds exact-command digest calculation of admitted inputs. It does not waive independent identities, required inputs, reservations, review findings, native checks, or existing task lifecycle. Do not infer authorization to install a control baseline or broaden shell permissions.

Owner: /Users/jrmag/.codex/worktrees/a8-release-sync-oct01/sdd-forge
Pinned HEAD: 495c88d67af44530687ecea3ce9fb0a90a336539
Risk: high/protected. Eight targets and all pre/post hashes remain exactly pins.json.
Patch: 37a711d5131e29f3ecdafaac983c2593f3559146cba5abc671473358a56027ea
Helper: 4267df606fff069eddd3174192cf38e3f935293e92ce1f9094a45077a38fd554

## Independent preparation verification

The independent boundary_postapply_review agent checked combined patch composition, seven unchanged component postimages, helper pins/constants, and reran all ten disposable helper cases. No concrete Major finding was reported. This was a bounded artifact/helper verification, not a formal SDD gate. Real hook refusal and partial-I/O failure injection were not tested. The parent reran the owner helper --check successfully after that review; original files were not applied.

Use docs/development-policy.md's reviewed, hash-pinned management-repair route, not a routine-work exemption. Existing human authority is sufficient to request the sanctioned human application; it is not sufficient evidence to launch a formal review before its normal requirements pass. Preparation-only APPLY_READY:false in results.md records the earlier unresolved authority check and must not be read as a release verdict.

## Required human operation

Run the unchanged helper in a terminal, with no concurrent writes to this checkout:

```sh
rtk proxy python3 -B /Users/jrmag/.codex/worktrees/a8-release-sync-oct01/sdd-forge/reports/verification/a8-combined-launch-candidate-20261006/human_apply.py --apply
```

Type `APPLY A8 COMBINED CONTRACT` when prompted. On any mismatch/refusal, stop and return the output; do not alter pins, bypass a hook or force the patch.

## Separate remaining gates

After application: verify original-path regressions; test actual exact-command and inherited-permission boundaries plus fresh idle host-session allocation and input delivery; rebind changed contract inputs and obtain the required independent formal review through ordinary admission. Do not reserve an identity until prerequisites succeed. Keep all previous attempts. New digest calculation is POSIX-only/fail-closed on Windows; no Windows native claim is made. CI, integration, control-baseline promotion and A8 completion remain unverified.
