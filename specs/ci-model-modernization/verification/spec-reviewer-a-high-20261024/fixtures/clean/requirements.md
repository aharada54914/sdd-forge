# workshop-enrollment 要件
Spec-Review-Status: Pending
## Goal
G-01: 社内ワークショップの開催予定を一覧でき、受講者が定員内で申込でき、管理者の明示承認後にのみ受講者名簿を外部講師へ公開できる。

## Non-goals
- NG-01: 支払い、キャンセル待ち、申込の取消、承認の取消、リマインダー通知、繰り返し開催は扱わない。 ワークショップの作成・削除・更新と存在しない id の要求は対象外で、対象 id はすべて事前に用意されたものとする。
- NG-02: 実データと実在の外部サービスは使わない。外部公開先は合成のスタブ宛先 `roster-outbox` のみとする。

## Constraints
- CON-001: 日時はすべてタイムゾーンオフセット付き ISO 8601（例 `2026-11-02T10:00:00+09:00`）で受け付け、UTC で保存する。オフセットのない入力や実在しない日時は `400 INVALID_DATETIME` で拒否する。 `from` と `to` は両方必須で、欠落も同じ `400 INVALID_DATETIME` とする。
- CON-002: 役割は既存の `member` と `admin` のみで、`admin` は `member` の全権限を持つ。未認証の要求は既存基盤が `401` で拒否する。
- CON-003: 名簿の外部公開は取り消せないため、対象ワークショップについて `admin` が明示的に承認を記録するまで、`roster-outbox` には何も送信しない。 承認記録は開催開始日時以降に限り可能で、開始前は `409 NOT_STARTED` で状態不変とする。申込は開始日時以降閉じるため、承認対象の申込集合は以後変化しない。

## Requirements
- REQ-001 (一覧): `GET /workshops?from=&to=` は開始日時が `from` 以上 `to` 以下（両端を含む）のワークショップを`200` の JSON 配列として開始日時昇順（同時刻は id 昇順）で返す。該当なしは空配列を返す。各要素は最低限 `id`、`title`、`start_at`（UTC）、`capacity`、`remaining_seats` を含み、id と title は文字列、capacity と remaining_seats は非負整数とし、remaining_seats は capacity から確定申込数を引いた数である。他の項目の追加は設計に委ねる。`from` > `to` は `400 INVALID_RANGE`。最大200件のデータで p95 応答時間 500ms 以下。
- REQ-002 (申込): `member` は `POST /workshops/{id}/enrollments` で自分自身を申込む。成功時 `201` を返し `remaining_seats` を1減らす。定員到達後の申込は `409 FULL`、同一 member の重複申込は `409 DUPLICATE`、開始日時以降の申込は `409 CLOSED` を返し、いずれも状態を変えない。同時申込でも確定申込数は `capacity` を超えない。 判定順は開始日時、重複、定員の順とし、1回の判定と登録を不可分に行う。
- REQ-003 (名簿公開): `admin` が `POST /workshops/{id}/roster-approval` で承認を記録した後に限り、`POST /workshops/{id}/roster-publication` は名簿（受講者の表示名のみ）を `roster-outbox` に1回送信し `202` を返す。未承認時は `409 APPROVAL_REQUIRED`、公開済みの再要求は `409 ALREADY_PUBLISHED` を返し、いずれも何も送信しない。承認記録と公開要求はいずれも `admin` のみが行え、`member` からの要求は `403 FORBIDDEN`。 承認記録の成功は `204` とし、同じ対象への再承認も状態を変えず `204` とする。認証・役割の拒否を時刻や公開状態の判定より先に行う。
- REQ-004 (ログ): 申込・承認記録・公開要求の各操作は、操作種別・対象 id・結果コードを含む1行を `audit.log` に追記する。
