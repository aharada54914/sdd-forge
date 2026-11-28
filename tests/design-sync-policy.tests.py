#!/usr/bin/env python3
"""Exercise the shipped UI provider decision boundary without network access."""
import json
from pathlib import Path
import re
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "plugins/sdd-bootstrap/scripts/resolve-design-sync.py"


def request(**updates):
    value = {
        "schema": "design-sync-request/v1", "operation": "upload", "ui_app": True, "ds_profile": "custom",
        "capability_resolved": True, "provider_available": True,
        "egress_permitted": True, "feature": "example", "session": "session-1",
        "destination": "project-1", "setting": "per-feature", "records": [],
    }
    value.update(updates)
    return value


def record(**updates):
    value = {"feature": "example", "session": "session-1", "destination": "project-1",
             "decision": "granted", "setting": "per-feature"}
    value.update(updates)
    return value


class PolicyTests(unittest.TestCase):
    def resolve(self, data):
        result = subprocess.run([sys.executable, "-B", str(SCRIPT)],
            input=json.dumps(data), text=True, capture_output=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def consent_step(self, text=None):
        if text is None:
            skill = ROOT / "plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md"
            text = skill.read_text(encoding="utf-8")
        section = re.search(r"(?ms)^## 3\. Mockup & Egress Consent Loop\b(.*?)(?=^## |\Z)", text)
        self.assertIsNotNone(section, "missing mockup and consent loop")
        step = re.search(r"(?ms)^3\. \*\*Resolve Egress Consent\*\*:(.*?)(?=^\d+\. |\Z)", section[1])
        self.assertIsNotNone(step, "missing egress consent step")
        return step[1].expandtabs(4)

    def consent_branch(self, setting, text=None):
        # Continuation text belongs to a policy only while indented beyond its bullet.
        bullets = re.findall(
            rf"(?m)^( *)- `{re.escape(setting)}`: *([^\n]*(?:\n\1 +(?!- )\S[^\n]*)*)",
            self.consent_step(text))
        self.assertEqual(len(bullets), 1, f"expected one {setting} branch in the consent step")
        return " ".join(bullets[0][1].split())

    def assert_scope_prompt(self, rule):
        self.assertRegex(rule, r"当該\s*`\(feature,\s*session\)`\s*で未同意なら、[^。]*"
                               r"人間の\s*明示同意を得てから\s*`push`")

    def first_upload_disclosure(self, text=None):
        branch = self.consent_branch("per-feature", text)
        self.assert_scope_prompt(branch)
        rule = "".join(branch.split())
        prompt = re.search(r"次の文面は、判定結果の`provider`が`claude-design`で、実際の送信先が`claude\.ai/design`の場合に限る。"
                           r"判定器が`prompt`を返したときだけ、〈機能名〉と〈プロジェクト名〉を実際の名前に置き換え、"
                           r"次の文面で利用者に同意を求める。"
                           r"「([^「」]+)この範囲で送信してよいですか？」", rule)
        self.assertIsNotNone(prompt, "missing operator-facing first-upload prompt")
        return prompt[1]

    def test_disclosure_payload(self):
        prompt = self.first_upload_disclosure()
        self.assertIn("〈機能名〉の要件、受入条件、デザイントークンを反映した"
                      "HTMLモックアップを送信します。", prompt)
        self.assertIn("モックアップには未公開の製品仕様、画面の文言、ブランド情報などの"
                      "機密情報が含まれる場合があります。", prompt)

    def test_disclosure_destination(self):
        self.assertIn("送信先は外部サービス`claude.ai/design`の、手順1のPullで選んだ"
                      "プロジェクト〈プロジェクト名〉です。", self.first_upload_disclosure())

    def test_disclosure_retention(self):
        self.assertIn("送信した内容はサービス側に保持される可能性があり、"
                      "このリポジトリではその保持や削除を制御できません。", self.first_upload_disclosure())

    def assert_disclosed_scope(self, prompt):
        self.assertIn("同意の範囲は、このセッション中に〈機能名〉のモックアップを"
                      "〈プロジェクト名〉へ送ることです。", prompt)

    def test_disclosure_repeated_uploads(self):
        prompt = self.first_upload_disclosure()
        self.assert_disclosed_scope(prompt)
        self.assertIn("同意が有効な間、この範囲での2回目以降の送信時には改めて確認しません。", prompt)

    def test_disclosure_regenerated_mockups(self):
        prompt = self.first_upload_disclosure()
        self.assert_disclosed_scope(prompt)
        self.assertIn("今後この範囲で再生成するモックアップの送信も含みます。", prompt)

    def test_disclosure_operator_authority(self):
        self.assertIn("同意すると、この内容を外部へ送る権限がご自身にあると表明したことになります。"
                      "このツールではその権限を検証しません。", self.first_upload_disclosure())

    def test_only_material_shown_in_the_first_upload_question_counts(self):
        heading = "## 3. Mockup & Egress Consent Loop\n3. **Resolve Egress Consent**:\n"
        branch = "   - `per-feature`: 当該 `(feature, session)` で未同意なら、人間の明示同意を得てから `push` する。\n"
        quote = ("     次の文面は、判定結果の `provider` が `claude-design` で、実際の送信先が `claude.ai/design` の場合に限る。\n"
                 "     判定器が `prompt` を返したときだけ、〈機能名〉と〈プロジェクト名〉を実際の名前に置き換え、"
                 "次の文面で利用者に同意を求める。\n"
                 "     「HTML を送信します。この範囲で送信してよいですか？」\n")
        retention_note = "     サービス側に保持される可能性があります。\n"
        self.assertNotIn("保持", self.first_upload_disclosure(heading + branch + quote + retention_note))
        with self.assertRaisesRegex(AssertionError, "missing operator-facing"):
            self.first_upload_disclosure(heading + branch + "   - `standing`: 設定の説明。\n" + quote)
        with self.assertRaisesRegex(AssertionError, "missing operator-facing"):
            self.first_upload_disclosure(heading + branch + quote.replace("`claude-design`", "`other-provider`"))

    def test_subsequent_uploads_reuse_current_grant(self):
        rule = self.consent_branch("per-feature")
        self.assertIn("機能・セッション・送信先がすべて同じで、前回の同意が有効なら、"
                      "2回目以降のアップロードは再同意を求めず送信前検査に進む。", "".join(rule.split()))

        self.assertEqual(self.resolve(request())["action"], "prompt")
        first = self.resolve(request(response="grant", party="fixture-operator"))
        self.assertEqual(first["action"], "proceed")
        self.assertEqual(first["audit"]["decision"], "granted")
        records = [first["audit"]]
        for upload in (2, 3):
            with self.subTest(upload=upload):
                result = self.resolve(request(records=records))
                self.assertEqual(result["action"], "proceed")
                self.assertIsNone(result["audit"])

        for changes in ({"setting": "off"}, {"egress_permitted": False},
                        {"capability_resolved": False}, {"provider_available": False}):
            with self.subTest(changes=changes):
                self.assertEqual(self.resolve(request(records=records, **changes))["action"], "manual")

    def test_different_feature_or_session_requires_consent(self):
        self.assert_scope_prompt(self.consent_branch("per-feature"))
        grant = record()
        self.assertEqual(self.resolve(request(records=[grant]))["action"], "proceed")
        for coordinate in ("feature", "session"):
            with self.subTest(coordinate=coordinate):
                decision = self.resolve(request(records=[grant], **{coordinate: "other"}))
                self.assertEqual(decision["action"], "prompt")

    def test_scope_prompt_markdown_continuations(self):
        heading = "## 3. Mockup & Egress Consent Loop\n3. **Resolve Egress Consent**:\n"
        bullet = "   - `per-feature`: 当該  `(feature, session)` で未同意なら、\n"
        prompt = "人間の明示同意を得てから  `push` する。"
        wrapped = self.consent_branch("per-feature", heading + bullet + "     " + prompt)
        self.assert_scope_prompt(wrapped)
        for sibling in ("   " + prompt, "   - `standing`: " + prompt):
            with self.subTest(sibling=sibling):
                rule = self.consent_branch("per-feature", heading + bullet + sibling)
                with self.assertRaises(AssertionError):
                    self.assert_scope_prompt(rule)

    def test_standing_skips_confirmation(self):
        self.assertIn("プロンプト不要で続行", self.consent_branch("standing"))
        for records in ([], [record(setting="standing")]):
            with self.subTest(records=records):
                self.assertEqual(self.resolve(request(setting="standing", records=records))["action"], "proceed")

    def test_standing_first_audit_is_granted(self):
        self.assertIn("`Egress-Consent: granted`", self.consent_branch("standing"))
        first = self.resolve(request(setting="standing"))["audit"]
        self.assertEqual(first["decision"], "granted")
        self.assertIsNone(self.resolve(request(setting="standing", records=[first]))["audit"])

    def test_off_routes_without_upload(self):
        self.assertIn("アップロードせず手動フォールバック", self.consent_branch("off"))
        for available in (False, True):
            result = self.resolve(request(setting="off", records=[record()], provider_available=available))
            with self.subTest(provider_available=available):
                self.assertEqual(result["action"], "manual")

    def test_off_records_the_outcome(self):
        # Match the outcome among the listed fields governed by the recording instruction.
        self.assertRegex(self.consent_branch("off"),
                         r"`Egress-Consent: [^`]+`(?:[\s,、]*`[^`]+`)*\s*を記録(?:する|します)?(?=\W|$)")
        data = request(setting="off")
        audit = self.resolve(data)["audit"]
        self.assertIsInstance(audit, dict)
        self.assertEqual(audit["decision"], "not-permitted")
        for coordinate in ("feature", "session", "destination"):
            self.assertEqual(audit[coordinate], data[coordinate])

    def test_off_audit_names_the_setting(self):
        self.assertIn("`Ds-Upload-Consent-Setting: off`", self.consent_branch("off"))
        audit = self.resolve(request(setting="off"))["audit"]
        self.assertEqual(audit["setting"], "off")
        # off has no live per-occurrence human: the party names the setting, never a person (AC-019).
        self.assertEqual(audit["party"], "ds_upload_consent: off")

    def test_default_unknown_and_case_variants_require_consent(self):
        for setting in (None, "per-feature", "unknown", "Standing", "OFF", ""):
            with self.subTest(setting=setting):
                data = request(setting=setting)
                if setting is None:
                    del data["setting"]
                self.assertEqual(self.resolve(data)["action"], "prompt")

    def test_pull_is_separate_from_upload_consent(self):
        for setting in ("off", "standing", "per-feature"):
            result = self.resolve(request(operation="pull", setting=setting))
            self.assertEqual(result["action"], "proceed")
            self.assertIsNone(result["audit"])
            self.assertEqual(self.resolve(request(operation="pull", setting=setting,
                                                 provider_available=False))["action"], "manual")

    def test_pull_respects_egress_policy_without_upload_consent(self):
        result = self.resolve(request(operation="pull", setting="standing", egress_permitted=False))
        self.assertEqual(result["action"], "manual")
        self.assertIsNone(result["audit"])

    def test_exact_scope_and_latest_decision(self):
        self.assertEqual(self.resolve(request(records=[record()]))["action"], "proceed")
        for change in ({"feature": "other"}, {"session": "ended"}, {"destination": "other"},
                       {"decision": "withdrawn"}, {"setting": "standing"}):
            with self.subTest(change=change):
                self.assertEqual(self.resolve(request(records=[record(**change)]))["action"], "prompt")
        for decision, action in (("withdrawn", "prompt"), ("not-permitted", "manual")):
            self.assertEqual(self.resolve(request(records=[record(), record(decision=decision)]))["action"], action)

    def test_standing_audits_once_per_feature_and_destination(self):
        first = self.resolve(request(setting="standing"))
        self.assertEqual(first["action"], "proceed")
        self.assertEqual(first["audit"]["decision"], "granted")
        self.assertEqual(first["audit"]["party"], "ds_upload_consent: standing")
        for change, expected in (({}, None), ({"session": "ended"}, None),
                                 ({"destination": "other"}, "granted"), ({"feature": "other"}, "granted")):
            result = self.resolve(request(setting="standing", records=[record(setting="standing", **change)]))
            self.assertEqual(result["audit"]["decision"] if result["audit"] else None, expected)

    def test_off_and_setting_changes_override_previous_grants(self):
        data = request(setting="standing")
        self.assertEqual(self.resolve(data)["action"], "proceed")
        data.update(setting="off", records=[record(), record(setting="standing")])
        for available in (True, False):
            data["provider_available"] = available
            result = self.resolve(data)
            self.assertEqual(result["action"], "manual")
            self.assertEqual(result["audit"]["decision"], "not-permitted")
            self.assertEqual(result["audit"]["setting"], "off")
        data.update(setting="per-feature", provider_available=True, records=[record(setting="standing")])
        self.assertEqual(self.resolve(data)["action"], "prompt")

    def test_off_record_does_not_override_new_per_feature_setting(self):
        data = request(records=[record(decision="not-permitted", setting="off")])
        self.assertEqual(self.resolve(data)["action"], "prompt")
        data.update(response="grant", party="fixture-operator")
        self.assertEqual(self.resolve(data)["action"], "proceed")

    def test_scope_egress_prohibition_is_persisted(self):
        result = self.resolve(request(egress_permitted=False))
        self.assertEqual(result["action"], "manual")
        self.assertEqual(result["audit"]["decision"], "not-permitted")
        self.assertEqual(result["audit"]["party"], "egress policy")
        retry = self.resolve(request(records=[result["audit"]], response="grant", party="fixture-operator"))
        self.assertEqual(retry["action"], "manual")
        standing = self.resolve(request(records=[result["audit"]], setting="standing"))
        self.assertEqual(standing["action"], "manual")

    def test_local_routes_do_not_call_fake_provider(self):
        # The adapter spy observes the decision consumer, not a real provider session.
        calls = []
        cases = [request(ui_app=False), request(ds_profile="none"),
                 request(capability_resolved=False), request(egress_permitted=False),
                 request(response="decline"), request(setting="off")]
        cases += [request(provider_available=False, setting=s) for s in ("standing", "off", "per-feature")]
        cases += [request(setting=s) for s in (None, "unknown")]
        for data in cases:
            result = self.resolve(data)
            if result["action"] == "proceed":
                calls.append(data["destination"])
            self.assertIn(result["action"], ("skip", "manual", "prompt"))
        self.assertEqual(calls, [])

    def test_decline_stops_current_upload(self):
        self.assertIn("拒否時はアップロードせず手動フォールバック。", self.consent_branch("per-feature"))
        self.assertEqual(self.resolve(request(response="decline"))["action"], "manual")

    def test_retry_after_decline_prompts_again(self):
        self.assertIn("辞退後、他の送信条件を満たす次の同一範囲のアップロードは `prompt` となり、改めて同意を求める。",
                      self.consent_branch("per-feature"))
        declined = self.resolve(request(response="decline"))
        history = [declined["audit"]] if declined["audit"] else []
        self.assertEqual(self.resolve(request(records=history))["action"], "prompt")

    def test_decline_is_distinct_from_prohibition(self):
        self.assertIn("一度の辞退は今回限りで、継続的な禁止 `not-permitted` を記録せず、設定も `off` に変更しない。",
                      self.consent_branch("per-feature"))
        self.assertIsNone(self.resolve(request(response="decline"))["audit"])
        for policy in ({"egress_permitted": False}, {"setting": "off"}):
            with self.subTest(policy=policy):
                denied = self.resolve(request(response="decline", **policy))
                self.assertEqual(denied["action"], "manual")
                self.assertEqual(denied["audit"]["decision"], "not-permitted")
                self.assertEqual(denied["audit"]["setting"], policy.get("setting", "per-feature"))
                retry = self.resolve(request(records=[denied["audit"]], setting=denied["audit"]["setting"],
                                             response="grant", party="fixture-operator"))
                self.assertEqual(retry["action"], "manual")

    def test_consent_binds_selected_project(self):
        prompt = self.first_upload_disclosure()
        self.assertIn("手順1のPullで選んだプロジェクト〈プロジェクト名〉", prompt)
        self.assert_disclosed_scope(prompt)
        self.assertIn("実際の送信先が `claude.ai/design` の `claude-design` に限り、"
                      "手順1で選んだプロジェクトの ID を `Egress-Destination` として `Design-Source` に残す。",
                      self.consent_branch("per-feature"))
        destination = json.dumps(["claude.ai/design", "selected-project"])
        granted = self.resolve(request(destination=destination, response="grant", party="fixture-operator"))
        self.assertEqual(granted["action"], "proceed")
        self.assertEqual(granted["audit"]["destination"], destination)
        self.assertEqual(granted["audit"]["party"], "fixture-operator")
        self.assertEqual(granted["audit"]["setting"], "per-feature")

    def test_destination_change_checks_its_own_grant(self):
        self.assertIn("送信先を変えた場合、元のプロジェクトの同意は引き継がない。"
                      "新しい送信先に有効な同意がなく、他の送信条件を満たす場合は、送信前に改めて同意を求める。",
                      self.consent_branch("per-feature"))
        common_rule = self.consent_step().partition("\n   - ")[0]
        self.assertIn("判定用の `destination` は実サービスと対象 ID の組を一意に識別する文字列とし、"
                      "同じ組には毎回同じ値を使う。", common_rule)
        self.assertIn("過去の `records` も、記録時の実サービスと対象 ID から同じ表記に揃える。"
                      "送信先を特定できない過去の同意は使わず、撤回や禁止が今回の送信先に適用されるか不明な場合は"
                      "手動フォールバックとする。", common_rule)
        # The resolver accepts an opaque string. Two services can issue the same local ID.
        native = {"provider": "claude-design", "destination": json.dumps(["claude.ai/design", "project-1"])}
        grant = self.resolve(request(**native, response="grant", party="fixture-operator"))["audit"]
        self.assertEqual(self.resolve(request(**native, records=[grant]))["action"], "proceed")
        for provider, service, target in (("claude-design", "claude.ai/design", "project-2"),
                                          ("example-adapter", "design.example", "project-1")):
            with self.subTest(service=service, target=target):
                data = request(provider=provider, destination=json.dumps([service, target]), records=[grant],
                               provider_capabilities={"push_mockup": True})
                self.assertEqual(self.resolve(data)["action"], "prompt")

    def test_operator_can_withdraw_during_session(self):
        self.assertIn("利用者はセッション中でも同意を撤回できる。"
                      "撤回を受けたら、同じ機能・セッション・送信先の判断を `withdrawn` として "
                      "`Design-Source` に追記し、次の判定では `records` の末尾に渡す。",
                      self.consent_branch("per-feature"))
        # A withdrawal in one project leaves the other project's active grant usable.
        grant = self.resolve(request(response="grant", party="fixture-operator"))["audit"]
        other = self.resolve(request(destination="other-project", response="grant", party="fixture-operator"))["audit"]
        history = [grant, other, dict(grant, decision="withdrawn")]
        self.assertEqual(self.resolve(request(records=history))["action"], "prompt")
        self.assertEqual(self.resolve(request(records=history, destination="other-project"))["action"], "proceed")

    def test_withdrawn_consent_needs_fresh_grant(self):
        self.assertIn("撤回後、他の送信条件を満たす次の同一範囲のアップロードは `prompt` となり、改めて同意を求める。",
                      self.consent_branch("per-feature"))
        grant = self.resolve(request(response="grant", party="fixture-operator"))["audit"]
        history = [grant, dict(grant, decision="withdrawn")]
        self.assertEqual(self.resolve(request(records=history))["action"], "prompt")
        renewed = self.resolve(request(records=history, response="grant", party="fixture-operator"))
        self.assertEqual(renewed["action"], "proceed")
        self.assertEqual(renewed["audit"]["decision"], "granted")
        self.assertEqual(self.resolve(request(records=history + [renewed["audit"]]))["action"], "proceed")

    def test_invalid_input_never_authorizes_provider(self):
        for change in ({"ui_app": "false"}, {"provider_available": 1}, {"records": {}},
                       {"records": [{"decision": "granted"}]}, {"destination": ""},
                       {"schema": "other"}, {"response": "grant"}, {"setting": []}):
            with self.subTest(change=change):
                result = subprocess.run([sys.executable, "-B", str(SCRIPT)],
                    input=json.dumps(request(**change)), text=True, capture_output=True, check=False)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, "")

    def test_alternative_provider_never_reports_claude_design_connected(self):
        alt = self.resolve(request(
            operation="pull",
            provider="pencil-mcp",
            provider_capabilities={"pull_tokens": True, "push_mockup": True, "provider_review": False},
        ))
        self.assertEqual(alt["action"], "proceed")
        self.assertEqual(alt["provider"], "pencil-mcp")
        self.assertFalse(alt["claude_design_connected"])
        self.assertEqual(alt["round_trip_mode"], "alternative-adapter")
        self.assertEqual(alt["capability_gaps"], ["provider_review"])

        native = self.resolve(request(operation="pull", provider="claude-design"))
        self.assertTrue(native["claude_design_connected"])
        self.assertEqual(native["round_trip_mode"], "native-sync")
        self.assertEqual(native["capability_gaps"], [])

        unavailable = self.resolve(request(operation="pull", provider="claude-design", provider_available=False))
        self.assertFalse(unavailable["claude_design_connected"])
        self.assertEqual(unavailable["round_trip_mode"], "manual")

    def test_design_sync_receipt_validator_enforces_provider_and_sqlite_gates(self):
        import tempfile
        validator = ROOT / "plugins/sdd-bootstrap/scripts/validate-design-sync-receipt.py"
        valid_alt = {
            "schema": "design-sync-receipt/v1",
            "feature": "task-board",
            "track": "full+sqlite",
            "provider": "pencil-mcp",
            "provider_available": True,
            "claude_design_connected": False,
            "round_trip_mode": "alternative-adapter",
            "capability_gaps": ["claude-design-native-review"],
            "project_id": "board.pen",
            "design_version": "v2",
            "tokens_pull_receipt": "specs/task-board/mockups/tokens.json",
            "mockup_review_receipt": "specs/task-board/mockups/review.json",
            "req_ac_mappings": ["REQ-001/AC-001"],
            "ui_diff_ref": "git:abc1234",
            "before_screenshot": "specs/task-board/mockups/before.png",
            "after_screenshot": "specs/task-board/mockups/after.png",
            "egress_scan": "clean",
            "ui_tests_passed": True,
            "sqlite_restart_persistence_passed": True,
        }
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "receipt.json"
            path.write_text(json.dumps(valid_alt), encoding="utf-8")
            ok = subprocess.run([sys.executable, "-B", str(validator), str(path)], capture_output=True, text=True)
            self.assertEqual(ok.returncode, 0, ok.stderr)
            self.assertFalse(json.loads(ok.stdout)["claude_design_connected"])

            # Alternative provider claiming Claude Design success must fail.
            spoofed = dict(valid_alt, claude_design_connected=True)
            path.write_text(json.dumps(spoofed), encoding="utf-8")
            bad_spoof = subprocess.run([sys.executable, "-B", str(validator), str(path)], capture_output=True, text=True)
            self.assertEqual(bad_spoof.returncode, 1)

            # Manual/skip/unavailable must fail.
            manual = dict(valid_alt, round_trip_mode="manual", provider_available=False)
            path.write_text(json.dumps(manual), encoding="utf-8")
            bad_manual = subprocess.run([sys.executable, "-B", str(validator), str(path)], capture_output=True, text=True)
            self.assertEqual(bad_manual.returncode, 1)

            # full+sqlite without restart persistence pass must fail.
            no_sqlite = dict(valid_alt, sqlite_restart_persistence_passed=False)
            path.write_text(json.dumps(no_sqlite), encoding="utf-8")
            bad_sqlite = subprocess.run([sys.executable, "-B", str(validator), str(path)], capture_output=True, text=True)
            self.assertEqual(bad_sqlite.returncode, 1)

    def test_core_delegates_provider_operations_to_the_shipped_resolver(self):
        bootstrap = ROOT / "plugins/sdd-bootstrap"
        entry = (bootstrap / "skills/bootstrap/SKILL.md").read_text(encoding="utf-8")
        self.assertIn("design-sync-loop", entry)
        loop = bootstrap / "skills/design-sync-loop"
        skill = (loop / "SKILL.md").read_text(encoding="utf-8")
        step = skill.split("## 3.", 1)[1].split("1. **Pull**", 1)[0]
        resolver = "../../scripts/resolve-design-sync.py"
        self.assertTrue((loop / resolver).is_file())
        for marker in (resolver, "design-sync-request/v1", "operation: pull",
                       "operation: upload", "prompt", "skip", "manual"):
            with self.subTest(marker=marker):
                self.assertIn(marker, step)
        self.assertIn("`pull` の許可をアップロードに流用しない", step)


if __name__ == "__main__":
    unittest.main(verbosity=2)
