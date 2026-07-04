# ADR-0003: MCP サーバーはバンドル済み dist/ をコミットして配布し、installer が登録まで行う

## Status

Accepted

## Context

sdd-forge リポジトリは純シェル/Markdown 構成で Node.js ビルド基盤を持たず、
installer（install.sh / install.ps1）は Git 追跡ファイルのコピーとプラグイン
登録のみを行う設計である（bash 3.2 互換制約あり）。TypeScript 製 MCP サーバー
（ADR-0002）の配布には、(a) 利用側でのビルド、(b) npm publish、(c) ビルド済み
成果物のコミット、の選択肢がある。

## Decision

1. 依存を含めて esbuild で単一ファイル `mcp/sdd-forge-mcp/dist/index.js` に
   バンドルし、リポジトリにコミットする。利用時要件は Node.js >= 20 のみ
   （`npm install` 不要・オフライン導入可）。
2. CI に dist-parity 検証を常設する: `src/` から再ビルドしてコミット済み
   `dist/` と一致しなければ fail（ビルド漏れ・手編集・改ざんを検出）。
3. installer はデフォルトで MCP を配置し、Claude Code（`claude mcp add`）と
   Codex への登録まで自動で行う。`--skip-mcp` で配置・登録とも除外、
   `--mcp <list>` で選択導入。uninstall は登録解除と配置除去を行う。
   Node >= 20 が無い環境では警告して MCP 部分のみスキップする。

## Alternatives considered

- **install 時に npm ci + build**: 利用側に npm・ネットワークを要求し、
  bash 3.2 互換 installer が複雑化する。導入失敗モードが増えるため却下。
- **npm レジストリへ publish**: バージョン同期と公開運用のコストが増え、
  リポジトリ内 spec / golden test との一体性が薄れるため却下（将来必要に
  なれば別 ADR で再検討）。
- **配置のみ・登録は手動**: 既存 installer がプラグイン登録まで自動で行う
  精神と不整合。登録忘れによる「導入したのに使えない」状態を避けるため却下。
  （local-env-mcp の「install 実行機能を持たせない」方針は別 feature の話で
  あり、本 installer 自身の責務拡張とは矛盾しない。）

## Consequences

- 利用者は installer 一発で MCP が使える状態になり、rollback も uninstall
  一発で完了する。
- dist/ の diff は PR レビューで実質読めないため、dist-parity CI が唯一の
  真正性保証となる。dist の手編集禁止を AGENTS.md Rules に追記する。
- バンドルに含める依存は MIT 系ライセンスに限定し、package-lock.json で
  固定する（SBOM 管理）。
- リポジトリサイズが成果物分（約 1 MB 想定、上限 1.5 MB）増加する。
