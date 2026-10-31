# A8 existing guard regression recheck

Command: `rtk proxy bash tests/guards.tests.sh`

Result: **135 passed, 0 failed; exit 0** on the local macOS host.
This ran the existing suite, not the unapplied Copilot patch adapter or its
safety-regression candidate. It does not establish native Copilot activation,
Node 14 compatibility, Windows behavior, formal review, CI or merge readiness.

Source hashes read immediately after execution:

| File | SHA-256 |
|---|---|
| `plugins/sdd-quality-loop/scripts/sdd-hook-guard.py` | `dd791f28d1f247c404197e3dbcc2960a664b18f4bc324fc1b967fbc4ee03e448` |
| `plugins/sdd-quality-loop/scripts/sdd-hook-guard.js` | `fa3cc8cad5661f8fbc6ee313fd8982762392adb3f08dd2ed13c736f985ccab0f` |
| `tests/guards.tests.sh` | `24e2cec71468b681f190e40ded7c3fb3dc2114c6a538b541a0483f6118f84377` |

Static inspection of the unapplied safety regression patch shows its new
`a8_patch_case` invokes both backends in default `exit` mode. The existing
helpers also support `copilot` mode, but the proposed cases do not yet assert
the native camelCase envelope or its JSON permission decision. Reuse those
helpers once actual hook stdin is established; exit-only checks must not be
reported as native adapter parity.
