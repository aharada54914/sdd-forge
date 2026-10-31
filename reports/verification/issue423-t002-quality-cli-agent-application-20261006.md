# T-002 CLI contract application

The user authorized direct agent application on 2026-10-06 and reported that SDD Forge was uninstalled. No hook refusal occurred during this application; this does not establish hook absence on every host.

- Owner: issue423-approved-recovery/sdd-forge
- HEAD: `3b5c38f08c98f8740d69a7c24ff7ff4a06c56ed9`
- Target: `plugins/sdd-quality-loop/skills/quality-gate/SKILL.md`
- Before SHA-256: `d0326f3617f0bf6de6ba7f99d7edc2388c79a6731866328133cff7bb1815b722`
- Patch SHA-256: `d912562f629b87fd9eb9d5502df460adbd25a5d44094544fc52a932de8eaf5bd`
- Actual after SHA-256: `6660633020ad990d1a23689e7499676b12aeab5bd0f6aea88b11ad8acb59ed7e`
- Original backup: `/tmp/issue423-quality-cli-agent-backup.zbAHO4/SKILL.md` (before hash verified).

Applied using apply_patch. A read-only Python comparison reconstructed the unique old/new hunk from the pinned patch, applied it in memory to the backup, and asserted byte-for-byte equality with the target. Result: EXACT_PATCH_BYTES_OK. Reverse git apply --check and target git diff --check both exited 0. Existing unrelated differences remain intact.

The previous helper's expected postimage hash is incorrect: its `patch --output=-` pipeline includes the `patching file ...` status line in stdout. That combined stream is not the target file. Do not use its expected-after value as artifact evidence or rerun its apply mode on the already-applied target.

Memory correction was recorded at the user's explicit request. This application is not a formal evaluator verdict, native child model/effort proof, CI success, or task completion. No reservation, task-state change, commit, push, or merge was performed.
