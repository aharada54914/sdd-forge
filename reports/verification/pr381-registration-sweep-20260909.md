# PR381 registration-consumer sweep

Checkout: /Users/jrmag/.local/share/sdd-forge-pr381-recovery-20260908
Base: 3971c93a5705dc15f86ba56cc62118613e4b19db
Status: diagnosis only; no new test-source changes or gate verdict.

The ongoing complete POSIX run (session 75815; /tmp/pr381-posix-20260909.WaPopD/full.log) fails agent-model-routing, agent-capabilities-v2 and render-agent-frontmatter at registration assertions. The runner actually invoked each suite. A separate read-only `rtk proxy bash tests/run-all.sh --list` returned exit 0 and all three exact paths.

The offending predicates search runner source text, at tests/agent-model-routing.tests.sh:1131, tests/agent-capabilities-v2.tests.sh:305 and tests/render-agent-frontmatter.tests.sh:602. Current tests/run-all.sh reads tests/suite-inventory.posix and exposes --list, so static source membership is not executable registration evidence.

Hypotheses checked: (1) actual inventory omission is contradicted by successful exact-path listing; (2) broken listing is contradicted by exit 0 and execution of the suites; (3) stale source-text expectations are confirmed by those predicates. No repair attempt has been made for these three consumers in this diagnostic step.

Scope sweep: `rtk proxy rg -n 'grep .*RUN_ALL_SH|grep .*run-all\.sh' tests --glob '*.sh'` finds 37 matching lines across 35 files. These are candidate sites requiring individual interpretation, not 35 proven failing suites. Examples include structural-compatibility.tests.sh:256, which expects an indented literal array entry, and component-path-ownership-parity.tests.sh:253, which requires a count of one. Preserve each consumer's uniqueness, PowerShell twin, CI wiring and hash assertions when repairing the POSIX membership predicate; do not replace them with a weaker substring match. Test missing, near-match and failing-list cases, and duplicate membership where uniqueness is required.

Do not edit the candidate or install dependencies during the current full run. Retain the terminal failure list first. Ajv absence is a separate environment prerequisite failure and needs the CI-prescribed dependency installation, not a waived test. Formal review, native CI, commit, push and merge remain pending.
