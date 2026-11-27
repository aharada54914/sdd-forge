# RT-015 による設計参照の訂正

- **Verdict**: PASS
- **Review Mode**: dual-parallel
- **Highest Risk Tier**: high
- **Checked At**: 2026-11-26T07:38:52.768147+00:00

対象コミットは `d1c723a4d9fe055ff6951bb28403c41fc0230fab`。所有者は2026-11-26に、テスト廃止承認マニフェストの所有規則が置かれたパスの訂正を承認した。このレビューはその訂正を対象とする。

| 観点 | 判定 | 照合結果 |
|---|---|---|
| P1 要件・境界条件 | PASS | REQ-010、SELF-REQ-006 と AC-009 の承認条件は従来どおり。 |
| P2 設計 | PASS | 設計第3節の参照先は T-002 のスコープおよび実ファイルと一致する。 |
| P3 タスク・検証 | PASS | T-002 のスコープ、依存、公開 CLI の検証コマンドは同一。タスク計画に承認日と理由がある。 |
| P4 認可 | PASS | ルートの CODEOWNERS 14行目にマニフェストと所有者が明記されている。Git ツリー内で他の CODEOWNERS は存在しない。 |
| P5 移行 | PASS | 差分は設計の参照先と承認記録の2ファイルに限られる。 |
| P6 未決事項・ドメイン | PASS | 訂正による未決事項、ドメイン・UI の変更はない。 |

A（P1・P3・P6）のホストIDは `01a216c9-1efb-7f23-b4dc-fcc7bbaaec16`。B（P2・P4・P5）は `01a216c9-5f23-7a80-96f0-d4af3d1f4de5`。両者は固定コミットを独立に照合した。GitHub 側の必須レビュー設定は本レビューの対象外。

| 固定版の入力 | SHA-256 |
|---|---|
| `specs/verification-first-factory/requirements.md` | `46365063daf64e00cdaa901db86257a790cc1d6cce6cac66a6c0fbcf23513f6c` |
| `specs/verification-first-factory/design.md` | `1417486b01a43e1ec85e7f71712be6328e113746646d826428b0f50ad58ac7a4` |
| `specs/verification-first-factory/tasks.md` | `2eadbe6c041677a1816535e5499c3bb94e1ff1e8c794bc44368d0ff6cf3d4703` |
| `CODEOWNERS` | `da1bbc91a4bf360b76da648ea886afd2d6e610a7bc7a31a784e78df05e41f73c` |
