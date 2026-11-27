# CI 配備に依存する14検査

所有者は次の14メソッドの移行を個別に承認した。行番号は移行前の cd51b921c に対応する。plan は tests/verification-ci-plan.tests.py、ci は tests/verification-ci.tests.py を示す。

| 移行前のスイート・行 | メソッド名 | 残す判定 | 当時の配備で照合する内容 |
|---|---|---|---|
| plan:374 | test_current_native_windows_and_coding_standard_obligations_are_retained | Windows 2022のpowershell/pwshの2行、profileとの完全一致、receipt・plan検証、coding-standardsの1行を照合 | 現行CIで旧名の2ジョブと上記profileを呼ぶ |
| plan:393 | test_current_readme_candidate_without_evidence_never_omits_work | README変更で根拠未確定のカテゴリは全obligationを選ぶ。空のevidenceとunproven-category理由も照合 | 現行CIがこのv1 plannerを通してREADMEを分類する |
| plan:404 | test_cancelable_native_wrapper_keeps_workload_without_assuming_execution | 2種類の条件でcoverageと計画が不変、実行実績を推定しない。非対応3条件は拒否。旧集約のalways()を照合 | 現行に旧testジョブと旧required-checks定義がある |
| plan:421 | test_control_verifier_is_not_its_own_completed_workload | 4制御stepをworkloadから分離し、3ホストを照合。単独集約と名前変更時の挙動、4改変の拒否も維持 | 現行集約がcheckout・parser・plan取得・収集・照合の旧構成である |
| plan:1403 | test_runtime_and_installers_agree_on_node26_floor | 当時の対象ジョブが26.13.0に固定され、3 MCPが>=26.13.0かつ型定義^26であることを個別に照合 | 全現行ジョブおよび3 MCPのランタイム下限が26.13.0。現行3 MCPは>=20.0.0、ADR-0052:73 |
| plan:1416 | test_live_workload_and_a9_inventory_survives_preparation | prepared verifier導入前後のworkload同一、旧A9両ジョブ不変、4制御のcommand SHAと3ホストを照合 | 現行に旧A9二段階・ci-plan・3ホストの旧test jobが配備されている |
| ci:351 | test_live_receipt_uploads_bind_current_job_names_and_actual_output_paths | receipt必須ケースごとにjob/matrix、run/attempt別artifact名、upload action pin、欠落時失敗、always条件、実際のreceiptパスを照合 | 現行5ジョブがv1のreceipt生成・uploadをする |
| ci:380 | test_current_workflow_all_receipt_callers_match_existing_profiles | 22 obligations、14種類のstep、SQL 4ジョブのsuite、caller/profileの対応を照合 | 現行CIがこれら22 obligationsを同じprofileから実行する |
| ci:1593 | test_T003_actual_planner_body_keeps_non_pr_and_manual_full | 4イベントすべてfull/event-full。各実行のrun ID・attempt・SHA・artifact名・全出力も検証 | 現行workflowに当時のdispatcherがあり4イベントがそこを通る |
| ci:1600 | test_T003_actual_pr_body_executes_trusted_planner_and_propagates_force_full | PRのsubject側sentinelは実行されず、5種類のforce値で期待のfull・理由・trusted baseを照合 | 現行PRがv1 dispatcherとforce-full変数を使う |
| ci:1615 | test_T003_actual_first_adoption_without_base_planner_stays_full | baseにplannerがない初回導入でfull/base-planner-unavailable | 現行PRでv1 plannerの初回導入フォールバックを実行する |
| ci:1628 | test_RT016_present_released_shadow_planner_uses_full_adoption_fallback | 当時の5968 byte shadow版のSHAを照合。これがbaseにあるときfull/base-planner-unavailableとbase SHAを検証 | 現行PRで旧shadow版からの移行dispatcherが動く |
| ci:1647 | test_RT016_subject_origin_sentinel_detects_wrong_dispatch | 間違った参照へ切り替えた既存負対照はexit96・出力なし、同じsubjectを正しいbase経路で実行するとfull | 現行PRでv1 dispatcherがtrusted plannerを選ぶ |
| ci:1662 | test_RT016_actual_pr_body_binds_api_head_and_distinct_tested_merge | 分岐したbase/headと実mergeを作り、API HEAD・tested merge・PR head・baseを独立に照合 | 現行PRがv1 dispatcherから4つの識別値を持つplanを出す |

履歴基準は e2110862fef5af5a2c4c9a1d25f2e0ec429791c4。6ファイルの生バイトと独立に列挙した424パスをテストで照合する。現行側では5ジョブ、各マトリクス、集約の成功1件・失敗状態15件、3つの MCP の Node 20 下限を実際のワークフローや配布マニフェストに対して検査する。集約の16入力はローカルで実行したワークフロー本文への入力である。
