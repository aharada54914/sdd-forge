#!/usr/bin/env python3
"""Exercise the shipped UI provider decision boundary without network access."""
import json
from pathlib import Path
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

    def test_decline_is_transient_and_grant_is_audited(self):
        declined = self.resolve(request(response="decline"))
        self.assertEqual(declined["action"], "manual")
        self.assertIsNone(declined["audit"])
        self.assertEqual(self.resolve(request())["action"], "prompt")
        granted = self.resolve(request(response="grant", party="fixture-operator"))
        self.assertEqual(granted["action"], "proceed")
        self.assertEqual(granted["audit"]["party"], "fixture-operator")
        self.assertEqual(granted["audit"]["setting"], "per-feature")

    def test_invalid_input_never_authorizes_provider(self):
        for change in ({"ui_app": "false"}, {"provider_available": 1}, {"records": {}},
                       {"records": [{"decision": "granted"}]}, {"destination": ""},
                       {"schema": "other"}, {"response": "grant"}, {"setting": []}):
            with self.subTest(change=change):
                result = subprocess.run([sys.executable, "-B", str(SCRIPT)],
                    input=json.dumps(request(**change)), text=True, capture_output=True, check=False)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, "")

    def test_full_lite_and_provider_skill_wire_the_shipped_helper(self):
        for relative in ("plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md",
                         "plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md",
                         "plugins/sdd-lite/skills/lite-spec/SKILL.md"):
            text = (ROOT / relative).read_text()
            self.assertIn("resolve-design-sync.py", text)
        skill = (ROOT / "plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md").read_text()
        self.assertIn("design-sync-request/v1", skill)
        self.assertIn("before every provider operation", skill)
        self.assertIn("proceed does not authorize an upload", skill)


if __name__ == "__main__":
    unittest.main(verbosity=2)
