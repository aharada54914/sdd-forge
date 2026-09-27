# Acceptance Tests: sdd-domain-concept-test

Status: Draft — review not run

| AC | Requirement | TEST | Concrete assertion |
|---|---|---|---|
| AC-001 | REQ-001 | TEST-001 | FITS fixtureのmd/jsonに同じfeature・根拠・FITS提案を記録する |
| AC-002 | REQ-001/003 | TEST-002 | NEW_CONCEPT_CANDIDATE記録でdecision欠如なら機械ゲートBLOCK |
| AC-003 | REQ-001/003 | TEST-003 | RESPONSIBILITY_CONFLICT記録でdecision欠如ならBLOCK |
| AC-004 | REQ-001/003 | TEST-004 | REQUIRES_HUMAN_DECISION記録でdecision欠如ならBLOCK |
| AC-005 | REQ-003 | TEST-005 | v2対象でJSON不存在ならBLOCK |
| AC-006 | REQ-003 | TEST-006 | FITSの有効記録は非FITS用decisionなしで証跡ゲート通過 |
| AC-007 | REQ-003 | TEST-007 | NEW_CONCEPT_CANDIDATE + proceedで証跡ゲート通過 |
| AC-007 | REQ-003 | TEST-015 | NEW_CONCEPT_CANDIDATE + defer-to-domain-updateで証跡ゲート通過 |
| AC-007 | REQ-003 | TEST-016 | NEW_CONCEPT_CANDIDATE + rejectedで証跡ゲート通過 |
| AC-007 | REQ-003 | TEST-017 | RESPONSIBILITY_CONFLICT + proceedで証跡ゲート通過 |
| AC-007 | REQ-003 | TEST-018 | RESPONSIBILITY_CONFLICT + defer-to-domain-updateで証跡ゲート通過 |
| AC-007 | REQ-003 | TEST-019 | RESPONSIBILITY_CONFLICT + rejectedで証跡ゲート通過 |
| AC-007 | REQ-003 | TEST-020 | REQUIRES_HUMAN_DECISION + proceedで証跡ゲート通過 |
| AC-007 | REQ-003 | TEST-021 | REQUIRES_HUMAN_DECISION + defer-to-domain-updateで証跡ゲート通過 |
| AC-007 | REQ-003/004 | TEST-022 | REQUIRES_HUMAN_DECISION + rejectedで証跡妥当性検査成功、bootstrap停止、domain-sync/後続生成呼出0 |
| AC-008 | REQ-002 | TEST-008 | same提案は人間確認前に確定扱いしない |
| AC-008 | REQ-002 | TEST-023 | different提案は人間確認前に確定扱いしない |
| AC-008 | REQ-002 | TEST-024 | undecided提案は人間確認前に確定扱いしない |
| AC-009 | REQ-002 | TEST-009 | 未来だけの根拠を候補扱いとし、domain/全ファイルhash不変 |
| AC-010 | REQ-004 | TEST-010 | domain/不在の生成出力と従来skipが不変 |
| AC-011 | REQ-004 | TEST-011 | v2 fullのbootstrapがConcept Test→domain-sync順に到達する |
| AC-012 | REQ-005 | TEST-012 | mdを予約manifestへ収録し、md欠落を拒否 |
| AC-012 | REQ-005 | TEST-025 | jsonを予約manifestへ収録し、json欠落を拒否 |
| AC-012 | REQ-005 | TEST-026 | mdの記録hashと実入力のhash差分を拒否 |
| AC-012 | REQ-005 | TEST-027 | jsonの記録hashと実入力のhash差分を拒否 |
| AC-013 | REQ-006 | TEST-013 | 三runtime manifestとrelease surfaceのskill可視性が一致 |
| AC-014 | REQ-003 | TEST-014 | 壊れたJSONを拒否 |
| AC-014 | REQ-003 | TEST-028 | unknown verdictを拒否 |
| AC-014 | REQ-003 | TEST-029 | unknown decisionを拒否 |
| AC-015 | REQ-003 | TEST-030 | sidecar不存在はBLOCK |
| AC-015 | REQ-003 | TEST-031 | 署名改ざんはBLOCK |
| AC-015 | REQ-003 | TEST-032 | 署名鍵不存在はBLOCK、skipしない |
| AC-015 | REQ-003 | TEST-033 | 未登録承認者は正しい署名でもBLOCK |
| AC-015 | REQ-003 | TEST-034 | decision文字列のみ、署名付き本人証跡なしはBLOCK |
| AC-016 | REQ-003/004 | TEST-035 | 読取入力を1byte変更するとBLOCK、再提案・再人間承認前に続行しない |
| AC-016 | REQ-003 | TEST-036 | 読取入力不存在はBLOCK |
| AC-016 | REQ-003 | TEST-037 | md/jsonのdecision不一致はBLOCK |
| AC-017 | REQ-004 | TEST-038 | NEW_CONCEPT_CANDIDATE + 有効署名proceedでdomain-sync→生成の順に続行 |
| AC-017 | REQ-004 | TEST-039 | NEW_CONCEPT_CANDIDATE + 有効署名defer-to-domain-updateは保留、両呼出0 |
| AC-017 | REQ-004 | TEST-040 | NEW_CONCEPT_CANDIDATE + 有効署名rejectedは停止、両呼出0 |
| AC-017 | REQ-004 | TEST-041 | RESPONSIBILITY_CONFLICT + 有効署名proceedでdomain-sync→生成の順に続行 |
| AC-017 | REQ-004 | TEST-042 | RESPONSIBILITY_CONFLICT + 有効署名defer-to-domain-updateは保留、両呼出0 |
| AC-017 | REQ-004 | TEST-043 | RESPONSIBILITY_CONFLICT + 有効署名rejectedは停止、両呼出0 |
| AC-017 | REQ-004 | TEST-044 | REQUIRES_HUMAN_DECISION + 有効署名proceedでdomain-sync→生成の順に続行 |
| AC-017 | REQ-004 | TEST-045 | REQUIRES_HUMAN_DECISION + 有効署名defer-to-domain-updateは保留、両呼出0 |
| AC-017 | REQ-004 | TEST-046 | FITS有効記録は非FITS用decisionなしでdomain-sync→生成の順に続行 |
| AC-018 | REQ-005 | TEST-047 | 後続レビューmanifestは入口と同じmd/json/sidecarと全入力path+sha256を収録 |
| AC-018 | REQ-005 | TEST-048 | 後続レビュー時のsidecar差替えは予約hash不一致で拒否 |
| AC-018 | REQ-005 | TEST-049 | 後続レビュー時の読取入力差替えは予約hash不一致で拒否 |
| AC-018 | REQ-005 | TEST-050 | 必須sidecarがmanifestから欠落すれば拒否 |

## UI Integration Checklist

- AC-011: shell到達点は既存bootstrap intake。GUI変更なし。利用可能条件はv2/full、証跡生成前の人間確認要件はREQ-002/003。
- OQ-001/002はrequirements.mdの2026-09-28 owner決定で解決済み。TEST-002〜004および007/015〜022の非FITS positive fixtureは有効署名付き本人証跡を備える。証跡妥当性成功と後続続行を区別する。全9結果はTEST-038〜045/022、FITS続行はTEST-046。
- この表は実行予定の具体assertionであり、実行済みテストやPASS証跡ではない。
