# Human-apply helper preparation — UNRELEASED

3原本への限定適用案を準備しただけで、owner原本へのhelper実行はしていない。独立candidate review PASS前はreleaseしない。`human-apply.py` は `RELEASE_READY=False` により `--apply-human` も拒否する。既定は検査のみ。docs/development-policy.md:35-38のsanctioned scope/hash-bound pathと genuine human operation 要件を維持し、ガード拒否後の別executor・write pathへのretryを禁止。

既存a20 receipt / a19 inventory helperのhash固定・通常git apply・backup/readback方式を再利用。patch hash、exact3target headers、candidate全hash、source全hashを適用前照合。symlink/ancestor aliasを拒否。全原本backupのhashを確認後、全pinを再確認し、`rtk proxy git apply --check` / `git apply` を正規経路で行い全readbackを検証。全3fileが既適用hashなら安全no-op、一部既適用は拒否する。検査失敗・適用失敗時は停止、backupを残して自動retry/rollbackしない。

`rtk proxy env PYTHONDONTWRITEBYTECODE=1 python3 reports/verification/a7-attempt21-recovery-candidate-20261006/human-apply.tests.py` はtempfixtureのみでexit0、9件PASS：検査only、正常3file適用＋既適用no-op、未release拒否、patch hash不一致、candidate hash不一致、source hash不一致、一部適用拒否、symlink拒否、backup途中不一致拒否。fixtureだけでrelease flagをTrueへ差し替え、owner helper flagはFalseのまま。fixture backupはtempディレクトリに保存され、ownerデータを含まない。

helper SHA256 `d08ad6871ffec78d7f83ded1ff85375abe13caf9571004072b83324c357e2bfc`。
tests SHA256 `8902c546cc0748bf2d8829ef9e3b35032d80c34d0c9e591dcb2df128d1a9f4f4`。
適用patch SHA256 `bc99b48a357ac3209a20242ce06facc6bb09fa2bf620ca43f99a85480e78834c`。
原本3hashはmajor1-repair.md記録から不変。元ソース・承認・予約・ledger・tasks・判定を変更していない。正式適用・native/CI・quality gateは未実施。release可否は主担当の独立review確認へ引継ぐ。
