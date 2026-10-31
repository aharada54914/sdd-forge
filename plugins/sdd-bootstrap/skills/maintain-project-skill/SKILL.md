---
name: maintain-project-skill
description: Revalidate a project skill against changed source and real execution, preserving user extensions and product expectations.
user-invocable: false
disable-model-invocation: false
---

# Maintain a project skill

Use when a project procedure, route, auth precondition, helper or watched source
changes. Do not schedule this procedure automatically. It never repairs product
code or changes task approval/required verification.

1. Read the existing skill, feature index, source/watch references and previous
   execution receipt. Classify suspected changes as doc drift, harness gap,
   environment unavailable or product regression. Date alone is not staleness.
2. Check every mapped feature against current source and its real entry point.
   Missing index entries are a harness gap. Preserve handwritten extensions and
   unrelated skills. Prepare the smallest diff only inside this skill's closure.
   Never weaken an expected result to match a failing product.
3. Reseal only after reviewing closure changes. Execute every feature file at least
   once through its declared public path. Use the existing harness with fresh data,
   actual effects and owned cleanup. A verified-unreachable or unexecuted mandatory
   path is blocked, not clean. Shared devices have one owner.
4. Run `python3 "<installed-root>/plugins/sdd-bootstrap/scripts/project-skill.py" maintain --root .
   --name verify-app --baseline <prior-receipt.json> --timeout 60` to replay all
   declared checks against explicitly pinned source inputs. The helper reports
   clean/changed/blocked and retains each raw attempt; it does not infer feature
   coverage from check count. If one check aggregates several features, inspect
   its actual per-feature observations. Review source changes separately from
   helper-output changes. Missing prerequisites and product failures need distinct
   diagnoses even though both block completion.
5. After editing a harness, rerun its successful and failure/boundary cases. Report
   exact changed files, all executed/unexecuted features, entry points not reached,
   retained receipts, measured side effects and limitations. Source-only review is
   never a clean maintenance result. Leave the prior evidence unchanged.

A documentation-only v2 procedure remains `blocked / procedure-not-executable`
on maintenance. Source/host-wrapper checks cannot turn it into clean execution
or a passing task check. Preserve its draft status and identify the unexecuted steps.
