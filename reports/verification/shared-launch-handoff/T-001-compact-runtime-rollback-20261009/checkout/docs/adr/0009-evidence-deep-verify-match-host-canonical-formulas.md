# ADR-0009 evidence_deep_verify は host スクリプトの正準式を再発明せず逐語一致で再実装する

## Status

Proposed(人間承認待ち — 判定整合性に関わる決定)

## Context

evidence_deep_verify は証拠バンドルの不変条件を in-process で再計算・突合する。同じ不変条件は
既に host スクリプト `plugins/sdd-quality-loop/scripts/generate-evidence-bundle.sh` /
`check-evidence-bundle.sh` が定義・検証している:

- **正準 artifacts ダイジェスト**(`evidence_canonical`): 各成果物を `path + "\x00" + sha256
  (小文字)` としてソートし、`\n` 連結して SHA-256。
- **spec_revision**(`compute_spec_revision`): `specs/<feature>/{requirements,design,
  acceptance-tests}.md` をこの順(存在するもののみ)で連結したバイト列の SHA-256。1 つも
  無ければ `""`。
- **git_commit 40-hex ルール**: `^[0-9a-f]{40}$`。

これらの式を MCP 側で独自に再設計すると、空白正規化・改行・ソート順・小文字化・ファイル順・
found_any の扱いといった細部で host と乖離し、同一バンドルに対し MCP と host が異なる判定を
下しうる。証拠検証は「複数実装が同じ結論に至る」ことに価値があり、乖離は誤った Done 判断に直結する。

## Decision

1. deep-verify は上記正準式を**再発明せず**、host スクリプトから**逐語**で移植する。式の全文は
   design.md「API / Contract Plan」の正準式節に引用し、実装はこれを唯一の参照元とする。
2. 実装は既存の同型実装(`parsers/evidence-bundle.ts` の `sha256OfGuardedFile` /
   `normalizeRelPath`、path-guard)を再利用し、ハッシュ・正規化のばらつきを避ける。
3. **agreement-with-host-script** をゴールデンテストで担保する: リポジトリにコミット済みの実
   バンドル群に対し、deep-verify の per-artifact match/mismatch・artifactsDigest・spec_revision・
   git 40-hex 形状・task_id/feature クロスバインド判定が `check-evidence-bundle.sh` の対応判定と
   一致することを検証する(署名 HMAC 検証と git HEAD/祖先検証は ADR-0008 により除外)。
4. host スクリプトの式が将来変更された場合、design.md の引用とゴールデンを同一 PR で更新し、
   乖離を CI(ゴールデン不一致)で検出する。

## Consequences

- MCP と host が同一の完全性判定(署名・git 祖先を除く)を返すため、どちらで検証しても結論が
  一致し、二重検証の信頼性が上がる。
- host スクリプトの式変更が deep-verify のゴールデンを破ることで、意図しない片側だけの変更を
  CI が検出する(整合性の常時保証)。
- 逐語移植のため MCP 側で「より良い」正規化を独自導入することは禁止する。改良は host 側の式変更
  として行い、両者同時に更新する(本 ADR の制約)。
