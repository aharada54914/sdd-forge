# AC-007 の Layer 1 基準

2026-11-26、所有者は上流 v2.1.5 の677行を新しい基準として承認した。v2.1.3 の663行は履歴値として残す。この決定は NFR-002、SELF-REQ-003、SELF-AC-003、AC-007 および設計の前提2に適用する。

`git show 2db182ad2:plugins/sdd-quality-loop/scripts/v2/sdd-soft-guard.mjs` と対象ブランチの同じファイルは677行、SHA-256 はともに `0aaf0786d8161d109dd664bad873330a33507aa97eb053f17e86acef83651399`。このPRのLayer 1差分は0バイト。マージ時も base と candidate の同じファイルを照合する。上限は700行、外部依存は0件、起動時間の上限は200msのままとし、他のゲートの昇格基準は維持する。
