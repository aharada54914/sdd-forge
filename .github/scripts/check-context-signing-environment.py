#!/usr/bin/env python3
"""Fail closed on observable prerequisites for the one-shot Context signer.

Configuration inspection is not proof of secret custody or of a human review.
GitHub's protected environment is the external approval boundary.
"""
import json
import os
import sys
import urllib.error
import urllib.request

REPOSITORY = 'aharada54914/sdd-forge'
OWNER = 'aharada54914'
ENVIRONMENT = 'context-approval'


def read_api(path, *, absent_ok=False):
    request = urllib.request.Request(
        'https://api.github.com/' + path,
        headers={'Authorization': 'Bearer ' + os.environ['GH_TOKEN'],
                 'Accept': 'application/vnd.github+json',
                 'X-GitHub-Api-Version': '2022-11-28'})
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        if absent_ok and error.code == 404:
            return None
        raise ValueError('GitHub prerequisite metadata unavailable') from None


def validate_configuration(environment, policies):
    if not isinstance(environment, dict) or not isinstance(policies, dict):
        raise ValueError('GitHub prerequisite metadata must be objects')
    if environment.get('name') != ENVIRONMENT:
        raise ValueError('wrong environment')
    if environment.get('can_admins_bypass') is not False:
        raise ValueError('administrator bypass must be disabled')
    branch_policy = environment.get('deployment_branch_policy')
    if (not isinstance(branch_policy, dict)
            or set(branch_policy) != {'protected_branches', 'custom_branch_policies'}
            or branch_policy['protected_branches'] is not False
            or branch_policy['custom_branch_policies'] is not True):
        raise ValueError('custom main-only deployment policy required')
    rules = environment.get('protection_rules', [])
    if not isinstance(rules, list) or any(not isinstance(rule, dict) for rule in rules):
        raise ValueError('protection rules must be objects')
    reviewer_rules = [rule for rule in rules if rule.get('type') == 'required_reviewers']
    if len(reviewer_rules) != 1:
        raise ValueError('required owner review required')
    reviewers = reviewer_rules[0].get('reviewers', [])
    if (not isinstance(reviewers, list) or len(reviewers) != 1
            or not isinstance(reviewers[0], dict) or reviewers[0].get('type') != 'User'
            or not isinstance(reviewers[0].get('reviewer'), dict)
            or reviewers[0]['reviewer'].get('login') != OWNER):
        raise ValueError('exact real owner reviewer required')
    branches = policies.get('branch_policies', [])
    if (type(policies.get('total_count')) is not int or policies['total_count'] != 1
            or not isinstance(branches, list) or len(branches) != 1
            or not isinstance(branches[0], dict)
            or branches[0].get('name') != 'main' or branches[0].get('type') != 'branch'):
        raise ValueError('exact main branch deployment rule required')


def main():
    if (os.environ.get('GITHUB_EVENT_NAME') != 'workflow_dispatch'
            or os.environ.get('GITHUB_REF') != 'refs/heads/main'
            or os.environ.get('GITHUB_REPOSITORY') != REPOSITORY):
        raise ValueError('only manual dispatch on repository main is supported')
    prefix = 'repos/' + REPOSITORY
    env_path = prefix + '/environments/' + ENVIRONMENT
    validate_configuration(read_api(env_path), read_api(env_path + '/deployment-branch-policies'))
    for path in ('sdd/project-context.yaml', 'sdd/project-context.approval.json',
                 'sdd/.approved-context/project-context.approved.yaml'):
        if read_api(prefix + '/contents/' + path + '?ref=main', absent_ok=True) is not None:
            raise ValueError('bootstrap refused: live or partial Context publication exists')
    print('Context signer prerequisites verified; secret custody and human review remain external.')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, KeyError, TypeError, OSError, json.JSONDecodeError):
        print('CONTEXT_SIGNER_PREREQUISITE_FAILED', file=sys.stderr)
        sys.exit(1)
