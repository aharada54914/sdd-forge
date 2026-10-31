# Claude native project-skill observation v3

One actual Claude Code 2.1.316 invocation, source bb2fdaa354c27e519df8df1991c5d7ac43ebcd4d. Dedicated existing OAuth profile; no authentication contents captured. Timeout 120 seconds, requested budget $2; observed 12.603 seconds and $0.0683074. CLI exit 0.

Actual native Skill(verify-app) invocation succeeded. The host read the canonical procedure, executed the documented owner command once, and read the generated observation and stdout. Observation schema project-verification-observation/v3, passed, exit 0; stdout native-v3-owner-check-ok. The original runner-returned observation hash and both log hashes match archived bytes. Original runtime paths/toolchain bytes/stat fingerprints still match.

The prepared evaluator's outside-host passive validation returned runtime-changed: offline comparison isolates the mismatch to inherited environment variables_sha256. Native Bash has a different environment from the outside evaluator. We neither reconstructed undisclosed variables nor bypassed that validation. This is a historical native execution observation, not a fresh outside-host admissible gate result.

Observed deviations: first Read resolved the wrapper's relative canonical reference under .claude and failed; the host recovered to the correct project root. Although the invocation requested only the documented Bash command in allowedTools, a second read-only Bash command read observation/stdout without a permission denial. Therefore the configured permission arguments are not evidence of exact-command isolation. No edits or extra verification executions were observed.

Wrapper absent before generation, present for invocation, and removed afterward; entire temporary fixture removed. These cleanup checks are filesystem checks only. No post-cleanup native skill discovery was executed. This synthetic procedure is not full application acceptance or a human production evaluation.

Evidence intentionally omits authentication, native initialization/account metadata, thinking blocks, and raw session logs. tool-events.json preserves actual tool requests/results; native-result.json preserves final text, cost, and permission result. protocol.json records source hashes and exact requested command/limits. generated-before contains the canonical procedure, manifest, task input, and native projection; owner-reports retains original observation/log/receipt bytes. offline-checks.json records only hash comparisons, never environment values.

## Comparison with the existing host evaluations

Source-comparison.json confirms that the lifecycle canonical fixture, project runner, and validator are byte-identical between requested main b9d3062e and actual evaluated bb2fdaa3. The task uses the same verify-app / smoke / T-001 / run1 / native-v3-owner-check-ok obligations; only native wrapper host and generated temporary absolute paths differ.

The existing Codex README (reports/verification/codex-project-skill-native-20261031/README.md) and Copilot v3 README (reports/verification/copilot-project-skill-v3-native-20261031/README.md) likewise distinguish successful native discovery/invocation/result reading from rejected outside-host validation with variables_sha256 differing. This Claude packet supports the same #602 host-smoke acceptance scope, not #594/#596 validated gate acceptance. The precise differing native environment keys were not captured and are not inferred from the hash.
