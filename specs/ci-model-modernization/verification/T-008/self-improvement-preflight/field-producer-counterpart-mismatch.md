# Self-improvement SDK boundary preflight

Maintained action pin: 1d6de8cb0c237e7c15e9e1bdf973826ebae490cc; exact public bytes and failed lookup receipts: ../self-improvement-current-source/receipt.json. Older source inspection is design history, not the current authority. Current native install default is 2.1.296; custom executable skips install. Settings merge, plugin install and prompt preparation precede SDK query. ANTHROPIC_MODEL takes precedence over parsed --model. SDK custom executable must preserve stream stdin/stdout/stderr, argv, signals and native exit status.

| Persisted field / producer | Actual consumer counterpart | Mismatch / failure before work |
| --- | --- | --- |
| controls.json + raw SHA / unchanged prepare + T007 | unchanged validate_launch_controls at SDK executable boundary | raw controls/request/registry/observation/adoption drift, wrong role/host/run/session, stale observation |
| selection resolved native_id / unchanged policy selector | actual SDK argv --model and captured environment | missing/duplicate/different model; known user/project/local/managed cap or environment override |
| resolved effort / unchanged selector | actual SDK argv --effort and final action-mutated settings | missing/duplicate/different effort; known settings/env conflict |
| bound session / unchanged bind_selection | actual SDK --session-id | absent/duplicate/different session; resume/continue/fallback not admitted |
| native executable raw SHA / action-prepare explicit canonical executable | immediately-before-exec held file digest and harmless help/version | altered executable, observation version mismatch, missing native flags |
| adapter raw SHA / action-prepare | generated executable wrapper checks before invoking adapter | adapter changes before SDK allocation |
| wrapper argv / maintained workflow preparation | public path_to_claude_code_executable | removing forwarding fails invocation oracle |
| native stream / SDK | os.execve original argv with inherited stdin/stdout/stderr | exact raw echo and nonzero exit fixture tests; no managed JSON on stdout |

Request and registry paths must be supplied from nonsecret repository variables and refer to canonical checked-out inputs. No availability producer exists in this workflow: missing/stale/invalid evidence stops with typed failure; no refresh, available IDs, scope or timestamps are manufactured. The controlled local action-sequence fixture supplies its existing verified-configuration observations unchanged and is not an actual GitHub Action run. Existing action schedules, credentials, permissions, 75 turns, allowed tools, MCP/settings/hooks and PR/Issue safeguards remain active. No provider, actual model identity, applied effort or adoption claim follows from recording.

Tests are additive to all existing test method ASTs. Both real installers exercise the wrapper where relevant. No formal independent QA or T008 closure is claimed.
