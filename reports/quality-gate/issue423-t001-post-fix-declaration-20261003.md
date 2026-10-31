# Issue 423 T-001 post-fix artifact declaration — 2026-10-03

This is a non-frozen declaration for the approved RT-20261003-001 repair. It is not a quality-gate report, independent evaluation, verdict, or Done decision. The prior NEEDS_WORK report and frozen implementation report remain unchanged.

The paths and SHA-256 values below are the only post-fix artifacts this declaration authorizes for a subsequent evaluator manifest. The declaration itself is a hash-pinned source, not an evaluator input. The Copilot launch source shows a real `copilot -p` consumer invocation, not a bootstrap-specific invocation.

## Post-Fix Artifacts

| Path | SHA-256 |
|---|---|
| `specs/sdd-domain-multitarget/verification/T-001/consumer-inventory.json` | `cb35d7f551fa0221ec68f3df44681f4f77fc0e6e9077fc3c4b9c86dd90674d18` |
| `specs/sdd-domain-multitarget/verification/T-001/consumer-inventory.tests.py` | `c190fb3ce31d357396a5417a0096d9236c0d212754a151722e2ff46f45581c2f` |
| `specs/sdd-domain-multitarget/verification/T-001/RT-20261003-001-repair.md` | `e1e3ba2e03495c84610b530168b7efe1194e64b223a69b17fefa5e8a32fc5280` |
| `plugins/sdd-bootstrap/skills/bootstrap/SKILL.md` | `252ea8af1726a7684747d2db512c775928db4bc2f1405125aff4f789385fda25` |
| `tests/cross-runtime-handoff.tests.sh` | `a9f88f78fd59f61ea904a9bff27fec058bf59d25a38a0831598631e4ff295256` |
| `plugins/sdd-quality-loop/.codex-plugin/plugin.json` | `d957210bf8057abae2ad16472e1d6c36a46ceccd3a4ee2a4133f0126dd60d011` |
| `plugins/sdd-quality-loop/.claude-plugin/plugin.json` | `132ffb6eb6e23f1a4d772f76065ecd9cb299370e0ed4bc4bb9d38ae3d8ba66b9` |
| `plugins/sdd-quality-loop/.plugin/plugin.json` | `ae3dc271a5b56f88efb97949f6e2d66cfc906b3e5813bf1bcec9597e863ec099` |
| `plugins/sdd-quality-loop/hooks/hooks.json` | `ae679756447145cd053e09dc1d29c1f6078d64935d95ca5d301ef2d2141f9501` |
| `plugins/sdd-quality-loop/hooks/claude-hooks.json` | `09c76c5dcd5d19d706530786b4728ff4e98e0d96c4d0e82c07bbb1a586c9ea5d` |
| `plugins/sdd-quality-loop/hooks/copilot-hooks.json` | `6e105f0c5526645564fe5fc60c7f8255fa4daba1f7bb63eb08e198ac69fde2a4` |
| `plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py` | `d9277ca516fa79b6ef459e0d0505375624a0a9279c32390758a96650985d0064` |

These declarations do not establish native host activation or CI success. Recheck the live hashes and the declaration's own hash immediately before a fresh evaluator launch.
