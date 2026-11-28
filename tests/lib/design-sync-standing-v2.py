#!/usr/bin/env python3
"""v2 checks shared by design-sync-standing-consent.tests.{sh,ps1} (T-010, 2026-11-28).

v2 rewrote design-sync-loop step 3 in Japanese, so the v1 English section
anchors no longer exist. Each check pairs the v2 wording that states the
behaviour with the executable resolver test that proves it
(tests/design-sync-policy.tests.py). Prints one `PASS <label>` or
`FAIL <label>` line per check; exits 0 even when a check fails, so both
twins tally the same lines.
"""
import importlib.util
import io
import re
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DSL = (ROOT / "plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md").read_text(encoding="utf-8")
AGENTS = (ROOT / "AGENTS.md").read_text(encoding="utf-8")


def flat(text):
    return " ".join(text.split())


def section(text, start, end):
    lines, out, inside = text.splitlines(), [], False
    for line in lines:
        if inside and re.search(end, line) and not re.search(start, line):
            break
        if re.search(start, line):
            inside = True
        if inside:
            out.append(line)
    return flat("\n".join(out))


STEP3 = section(DSL, r"^3\. \*\*Resolve Egress Consent", r"^4\. \*\*")
SETTINGS = section(AGENTS, r"^## Project Settings$", r"^## ")
SCOPES = {"step3": STEP3, "dsl": flat(DSL), "settings": SETTINGS}

spec = importlib.util.spec_from_file_location("design_sync_policy_tests", ROOT / "tests/design-sync-policy.tests.py")
policy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(policy)


def behaviour(*names):
    suite = unittest.TestSuite(policy.PolicyTests(name) for name in names)
    return unittest.TextTestRunner(stream=io.StringIO(), verbosity=0).run(suite).wasSuccessful()


AUDIT = "`Egress-Consent-Scope`）・対象（`Egress-Consent-Subject`）・有効期限（`Egress-Consent-Expiry`）"
# The three Q08 fields are written by the agent from the record table; the
# resolver itself emits feature/session/destination, decision, setting, party.
STANDING_EXPIRY = "`standing` は設定が `standing` 以外に変わるか撤回されるまで"
OFF_EXPIRY = "`off` の禁止は設定が変わるまで"
PER_FEATURE_EXPIRY = "`per-feature` は同意したセッションの終了時"
UNPROMPTED_SUBJECT = "確認を示さない `standing` と `off` は、記録時に送信予定だったファイルの相対パス一覧を記録する"
CHECKS = [
    ("TEST-007 the three regimes mean the same with or without the design tool (AC-006, executable)", [],
     ["test_off_routes_without_upload", "test_off_and_setting_changes_override_previous_grants"]),
    ("TEST-009 the standing write goes to the Design-Source of specs/<feature>/design.md (AC-008)",
     [("step3", "`(feature, destination)` 初回のみ `Egress-Consent: granted`"),
      ("step3", "`specs/<feature>/design.md` の `Design-Source` に")], ["test_standing_first_audit_is_granted"]),
    ("TEST-010 the first-occurrence write is scoped to (feature, destination), not the feature alone (AC-009)",
     [("step3", "`(feature, destination)` 初回のみ")], ["test_standing_audits_once_per_feature_and_destination"]),
    ("TEST-011 a different destination for an already-recorded feature triggers a fresh one-time write (AC-030)", [],
     ["test_standing_audits_once_per_feature_and_destination", "test_destination_change_checks_its_own_grant"]),
    ("TEST-013 under off the resolved outcome is always the manual fallback without upload (AC-011)",
     [("step3", "`off`: アップロードせず手動フォールバック")],
     ["test_off_routes_without_upload", "test_off_and_setting_changes_override_previous_grants"]),
    ("TEST-017 off's forbiddance is persistent and distinct from a one-time decline (AC-013)",
     [("step3", "一度の辞退は今回限りで、継続的な禁止 `not-permitted` を記録せず、設定も `off` に変更しない")],
     ["test_decline_is_distinct_from_prohibition", "test_scope_egress_prohibition_is_persisted"]),
    ("TEST-018 the forbiddance holds on every host, in AGENTS.md and in the loop's off branch (AC-014)",
     [("settings", "forbid the upload on every host"), ("step3", "`off`: アップロードせず手動フォールバック")],
     ["test_off_routes_without_upload"]),
    ("TEST-038 standing's party names the setting, never a fabricated per-occurrence identity (AC-019)",
     [("step3", "返された `party`（`Egress-Consent-Party`）")], ["test_standing_audits_once_per_feature_and_destination"]),
    ("TEST-039 off's party names the setting, never a fabricated per-occurrence identity (AC-019)",
     [("step3", "返された `party`（`Egress-Consent-Party`）")], ["test_off_audit_names_the_setting"]),
    ("TEST-040 a standing grant's record instruction names scope, subject and expiry valid across sessions (Q08, AC-029)",
     [("step3", AUDIT), ("dsl", STANDING_EXPIRY), ("dsl", UNPROMPTED_SUBJECT)], ["test_standing_first_audit_is_granted"]),
    ("TEST-041 a per-feature grant's record instruction names scope, subject and session expiry (Q08, AC-029)",
     [("step3", AUDIT), ("dsl", PER_FEATURE_EXPIRY)], ["test_subsequent_uploads_reuse_current_grant"]),
    ("TEST-042 a mid-session withdrawal's record instruction names scope, subject and expiry (Q08, AC-029)",
     [("step3", AUDIT), ("step3", "`withdrawn` として `Design-Source` に追記")], ["test_withdrawn_consent_needs_fresh_grant"]),
    ("TEST-043 an off-driven not-permitted record instruction names scope, subject and persistent expiry (Q08, AC-029)",
     [("step3", AUDIT), ("step3", "`Egress-Consent: not-permitted`"), ("dsl", OFF_EXPIRY), ("dsl", UNPROMPTED_SUBJECT)], ["test_off_records_the_outcome"]),
    ("TEST-044 the setting is re-read at every resolution, never cached (AC-020, executable oracle)",
     [("dsl", "毎回、現在の設定、機能・セッション・送信先、既存の判断記録を使う"),
      ("step3", "毎回 `AGENTS.md` の `ds_upload_consent`")], ["test_off_and_setting_changes_override_previous_grants"]),
    ("TEST-045 a record's own setting never overrides the currently configured setting (AC-021, executable)", [],
     ["test_off_record_does_not_override_new_per_feature_setting", "test_off_and_setting_changes_override_previous_grants"]),
]

for label, needles, tests in CHECKS:
    ok = all(flat(needle) in SCOPES[scope] for scope, needle in needles) and (not tests or behaviour(*tests))
    print(("PASS " if ok else "FAIL ") + label)
