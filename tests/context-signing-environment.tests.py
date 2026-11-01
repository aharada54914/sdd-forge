#!/usr/bin/env python3
"""Exercise the signing prerequisite boundary without keys or network access."""
import copy
import importlib.util
import os
from pathlib import Path
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('context_guard', ROOT / '.github/scripts/check-context-signing-environment.py')
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)


class ContextSigningEnvironmentTests(unittest.TestCase):
    def setUp(self):
        self.environment = {
            'name': 'context-approval', 'can_admins_bypass': False,
            'deployment_branch_policy': {'protected_branches': False, 'custom_branch_policies': True},
            'protection_rules': [{'type': 'required_reviewers', 'prevent_self_review': False,
                                  'reviewers': [{'type': 'User', 'reviewer': {'login': 'aharada54914'}}]}],
        }
        self.policies = {'total_count': 1, 'branch_policies': [{'name': 'main', 'type': 'branch'}]}
        self.runtime = {'GITHUB_EVENT_NAME': 'workflow_dispatch', 'GITHUB_REF': 'refs/heads/main',
                        'GITHUB_REPOSITORY': 'aharada54914/sdd-forge', 'GITHUB_ACTOR': 'aharada54914'}

    def test_single_real_owner_can_dispatch_then_review(self):
        guard.validate_configuration(self.environment, self.policies)
        with patch.dict(os.environ, self.runtime), patch.object(guard, 'read_api', side_effect=[self.environment, self.policies, None, None, None]):
            guard.main()

    def test_absent_or_weakened_environment_rejected(self):
        mutations = [lambda e: e.pop('can_admins_bypass'), lambda e: e.update(can_admins_bypass=True),
                     lambda e: e.update(protection_rules=[]), lambda e: e.update(deployment_branch_policy=None),
                     lambda e: e['protection_rules'][0].update(reviewers=[]),
                     lambda e: e['protection_rules'][0]['reviewers'][0]['reviewer'].update(login='someone-else')]
        for mutation in mutations:
            with self.subTest(mutation=mutation):
                environment = copy.deepcopy(self.environment)
                mutation(environment)
                with self.assertRaises((ValueError, TypeError)):
                    guard.validate_configuration(environment, self.policies)

    def test_malformed_api_shapes_and_boolean_counts_rejected(self):
        for malformed in (None, [], 1, "environment"):
            with self.subTest(malformed=malformed), self.assertRaises(ValueError):
                guard.validate_configuration(malformed, self.policies)
            with self.subTest(policies=malformed), self.assertRaises(ValueError):
                guard.validate_configuration(self.environment, malformed)
        mutations = [lambda e: e.update(protection_rules=[None]),
                     lambda e: e['protection_rules'][0].update(reviewers=[None]),
                     lambda e: e['protection_rules'][0]['reviewers'][0].update(reviewer=None),
                     lambda e: e.update(deployment_branch_policy={
                         'protected_branches': 0, 'custom_branch_policies': 1})]
        for mutate in mutations:
            environment = copy.deepcopy(self.environment)
            mutate(environment)
            with self.assertRaises(ValueError):
                guard.validate_configuration(environment, self.policies)
        for policies in ({'total_count': True, 'branch_policies': self.policies['branch_policies']},
                         {'total_count': 1, 'branch_policies': [None]}):
            with self.assertRaises(ValueError):
                guard.validate_configuration(self.environment, policies)

    def test_wildcard_tag_extra_and_unpaginated_rules_rejected(self):
        for policies in ({'total_count': 1, 'branch_policies': [{'name': '*', 'type': 'branch'}]},
                         {'total_count': 1, 'branch_policies': [{'name': 'main', 'type': 'tag'}]},
                         {'total_count': 2, 'branch_policies': [{'name': 'main', 'type': 'branch'}]}):
            with self.subTest(policies=policies), self.assertRaises(ValueError):
                guard.validate_configuration(self.environment, policies)

    def test_other_events_refs_and_repositories_rejected_before_network(self):
        for variable, value in [('GITHUB_EVENT_NAME', 'pull_request'), ('GITHUB_REF', 'refs/heads/work'),
                                ('GITHUB_REPOSITORY', 'someone/sdd-forge')]:
            with patch.dict(os.environ, {**self.runtime, variable: value}), patch.object(guard, 'read_api') as api:
                with self.assertRaises(ValueError):
                    guard.main()
                api.assert_not_called()

    def test_live_approval_and_unreadable_configuration_rejected(self):
        for responses in ([self.environment, self.policies, {'sha': 'existing'}],
                          [self.environment, self.policies, None, {'sha': 'existing'}],
                          [self.environment, self.policies, None, None, {'sha': 'existing'}], ValueError('403')):
            with patch.dict(os.environ, self.runtime), patch.object(guard, 'read_api', side_effect=responses):
                with self.assertRaises(ValueError):
                    guard.main()

    def test_workflow_keeps_pinned_issuer_and_secret_step_boundary(self):
        workflow = (ROOT / '.github/workflows/context-approval.yml').read_text()
        self.assertIn('ref: 555bfb5f15265f622a353a946e3fd6b04ab575de', workflow)
        self.assertIn('a43669c40d374b1411df0ba2f3ed84c4fb05d337c33e850e157f9c612702076a', workflow)
        self.assertIn('environment: context-approval', workflow)
        self.assertIn('needs: prerequisites', workflow)
        self.assertEqual(workflow.count('${{ secrets.SDD_CONTEXT_KEY }}'), 1)
        self.assertIn('include-hidden-files: true', workflow)
        self.assertNotIn('pull_request:', workflow)


if __name__ == '__main__':
    unittest.main()
