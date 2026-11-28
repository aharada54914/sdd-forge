#!/usr/bin/env python3
"""Family tier rules agree with the registry, classify new versions, and enforce role floors."""
import importlib.util
import json
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / 'plugins/sdd-implementation/scripts/model-tier.py'
spec = importlib.util.spec_from_file_location('model_tier', TOOL)
tier = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tier)


class FamilyRules(unittest.TestCase):
    def test_every_current_policy_model_is_classified_to_its_registry_tier(self):
        registry = {m['name']: m['canonical_tier'] for m in
                    json.loads((ROOT / 'contracts/agent-model-capabilities.v2.json').read_text())['models']}
        policy = json.loads((ROOT / 'contracts/model-policy.v1.json').read_text())
        checked = 0
        for model in policy['models']:
            if model['lifecycle'] not in ('current', 'candidate'):
                continue
            for host, native in model['hosts'].items():
                with self.subTest(model=model['id'], host=host):
                    self.assertEqual(tier.classify(native)['tier'], registry[model['id']])
                    checked += 1
        self.assertGreaterEqual(checked, 15)

    def test_new_versions_of_known_families_need_no_registry_edit(self):
        for native, expected in (('claude-haiku-6', 'lightweight'), ('claude-sonnet-6-1', 'standard'),
                                 ('claude-opus-7', 'strong'), ('claude-fable-6-0', 'strong'),
                                 ('gpt-7-luna', 'lightweight'), ('gpt-7.3-terra', 'lightweight'),
                                 ('gpt-7.1-sol', 'standard'), ('gpt-7-astra', 'strong'),
                                 ('gemini-5-flash-lite', 'lightweight'), ('gemini-5.1-flash', 'standard'),
                                 ('gemini-5-hydrogen', 'standard'), ('gemini-5.2-carbon', 'strong')):
            with self.subTest(native=native):
                result = tier.classify(native)
                self.assertEqual((result['tier'], result['source']), (expected, 'family'))

    def test_unknown_or_malformed_ids_are_never_classified(self):
        for native in ('gpt-7-nova', 'claude-poet-1', 'gemini-5-flash-lite-x', 'haiku-sonnet', 'GPT-6-ASTRA'):
            with self.subTest(native=native):
                self.assertEqual(tier.classify(native)['tier'], 'unclassified')
        for bad in ('', 'gpt 6 astra', '../gpt-6-astra', 'x' * 200):
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                tier.classify(bad)

    def test_host_spellings_classify_as_their_family_model(self):
        # Review fix (T-010): canonical names and host spellings of one model.
        for spelling, expected in (('anthropic/opus-5-5', 'strong'), ('claude-opus-5-5[1m]', 'strong'),
                                   ('us.anthropic.claude-opus-5-5-v1:0', 'strong'),
                                   ('claude-opus-4-1@20250805', 'strong'),
                                   ('eu.anthropic.claude-haiku-5-5-v1:0', 'lightweight')):
            with self.subTest(spelling=spelling):
                self.assertEqual(tier.classify(spelling)['tier'], expected)
        # Only the documented spellings are stripped; anything else stays unclassified.
        for other in ('claude-opus-5-5[1m]x', 'claude-opus-5-5@2025', 'xx.openai.claude-opus-5-5', 'CLAUDE-OPUS-5-5'):
            with self.subTest(other=other):
                self.assertEqual(tier.classify(other)['tier'], 'unclassified')
        for bad in ('claude-opus-5-5 [1m]', '../claude-opus-5-5', '/claude-opus-5-5'):
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                tier.classify(bad)

    def test_role_floor_check_cli(self):
        def run(role, model):
            result = subprocess.run([sys.executable, str(TOOL), 'check', '--role', role, '--model', model],
                                    capture_output=True, text=True)
            return result.returncode, json.loads(result.stdout or result.stderr)
        for role, model, code in (('sdd-evaluator', 'claude-opus-5-5', 0), ('sdd-evaluator', 'claude-sonnet-5-5', 3),
                                  ('sdd-evaluator', 'gpt-6.2-sol', 3), ('sdd-evaluator', 'gemini-4-carbon', 0),
                                  ('spec-reviewer', 'claude-haiku-5-5', 3), ('spec-reviewer', 'gpt-6.2-sol', 0),
                                  ('sdd-investigator', 'gpt-6-luna', 0), ('sdd-evaluator', 'gpt-7-nova', 3)):
            with self.subTest(role=role, model=model):
                returncode, verdict = run(role, model)
                self.assertEqual(returncode, code, verdict)
                self.assertEqual(verdict['meets_floor'], code == 0)
        returncode, verdict = run('no-such-role', 'claude-opus-5-5')
        self.assertEqual(returncode, 2)
        self.assertIn('unknown capability role', verdict['error'])

    def test_no_native_id_matches_families_of_different_tiers(self):
        rules = tier.families()
        policy = json.loads((ROOT / 'contracts/model-policy.v1.json').read_text())
        for native in [n for m in policy['models'] for n in m['hosts'].values()]:
            with self.subTest(native=native):
                self.assertLessEqual(len({t for p, t, _, _ in rules if p.fullmatch(native)}), 1)

    def test_plugin_copies_match_the_repository_contracts(self):
        for name in ('model-families.v1.json', 'agent-model-capabilities.v2.json'):
            with self.subTest(name=name):
                self.assertEqual((ROOT / 'plugins/sdd-implementation/contracts' / name).read_bytes(),
                                 (ROOT / 'contracts' / name).read_bytes())


if __name__ == '__main__':
    unittest.main()
