# T-008 native human-input preparation

Status: PREPARED / NATIVE UNVERIFIED. This is a prospective non-frozen addendum, not an approval, native acceptance receipt, quality-gate verdict, or Done decision. No signing, publishing, permission relaxation, dispatcher replacement, or new native launch was performed.

## Prepared and verified

- New isolated checkout: `/private/tmp/a7-t008-native-preparation.LN0bu0/repo`, detached at `d64cffcb22b114779202847be33e41700c4ba11f`, cloned locally with `--no-hardlinks`. The original failed-attempt checkout and raw stream remain unchanged.
- Unsigned candidate: `/private/tmp/a7-t008-native-preparation.LN0bu0/candidate/sdd/project-context.yaml`. It is only a proposed isolated test configuration; it has no approver, sidecar, or claimed approval.
- Raw SHA-256: `d10b3d8103ae4c7eb1e66f4cd2858dd179a3fa6fae500bd47aac845f5a8526d3`. A one-entry human-copy manifest is beside the candidate.
- `canonicalize-sdd-yaml.sh --hash-only` returned `sha256:f9084e0ecb07b40003daaf7b3ebf9933043d0c64d2b45462f50744a378db806b` for both the new candidate and the old isolated Context. This proves canonical content equality and parser acceptance, not schema/approval/native success.
- Outer `rtk proxy bash scripts/check-sdd-structure.sh` in the new checkout exited 0, `check-sdd-structure: OK`. It does not replace the native session's own prerequisite check.
- Owner `git diff --name-only HEAD -- plugins scripts contracts` was empty. Thus this checkout includes the current tracked native implementation in those paths; it intentionally excludes unrelated dirty test/report work and does not claim validation of that work.
- `/private/tmp/a7-t008-native-preparation.LN0bu0/approver-registry.yaml.example` is a clearly marked placeholder template outside the live registry and outside the publish candidate. It MUST NOT be published as-is.

## Human-only boundary, not missing generic approval

`plugins/sdd-quality-loop/scripts/generate-approval-sidecar.py:12-16` states: actual signing requires a human or CI principal holding `SDD_CONTEXT_KEY`, and the tool never runs with agent-accessible credentials in an agent-driven workflow. A1 `requirements.md:1923-1945` separately forbids agent signing and direct live registry/sidecar writes and assigns every staged human-copy publication to the human maintainer. Broad task approval does not provide a human signing identity or remove these explicit role restrictions. No key value or key file was inspected.

The remaining input operation therefore requires a real human signer (or an existing approved human/CI workflow). There is no discovered approved automated signing workflow for this isolated input; no workflow or credential was created. Human steps, in order:

1. Review the unsigned Context. If accepted, edit the example using the human's actual registry ID/name and save it as `candidate/sdd/approver-registry.yaml`. Replace placeholders; do not invent an identity. Regenerate `candidate/MANIFEST.sha256` using the raw SHA-256 of both candidate files (two spaces between hash and repo-relative target). If the Context changes, regenerate its hash too.
2. From the new isolated repository root, the human publishes the reviewed input and registry using the existing publisher:

   ```text
   rtk proxy bash plugins/sdd-quality-loop/scripts/apply-human-copy.sh --staging-dir /private/tmp/a7-t008-native-preparation.LN0bu0/candidate --manifest /private/tmp/a7-t008-native-preparation.LN0bu0/candidate/MANIFEST.sha256
   ```

3. With the genuine key available through its normal local mechanism, the human signs. Substitute only the genuine registered ID below; never paste a key into chat or command output. The explicit staging output directory must not already exist.

   ```text
   rtk proxy bash plugins/sdd-quality-loop/scripts/generate-approval-sidecar.sh --schema sdd-project-context-approval/v1 --content sdd/project-context.yaml --approver REAL_REGISTERED_ID --status Approved --live-sidecar sdd/project-context.approval.json --stage-dir sdd/.staging/t008-positive-human-20261004
   rtk proxy bash plugins/sdd-quality-loop/scripts/apply-human-copy.sh --staging-dir sdd/.staging/t008-positive-human-20261004 --manifest sdd/.staging/t008-positive-human-20261004/MANIFEST.sha256
   ```

4. The standard validator must then return `VALID` and exit 0. This read-only validation can be performed by the agent after publication, without printing secrets:

   ```text
   rtk proxy bash plugins/sdd-quality-loop/scripts/validate-approval-sidecar.sh --content sdd/project-context.yaml --sidecar sdd/project-context.approval.json --approver-registry sdd/approver-registry.yaml
   ```

Stop on any refusal; these commands are not permission to route around it. This preparation has not executed steps 1–4 and does not claim the staged Context will pass full approval validation until checked.

## Normal native continuation

The historical refusal remains the normal session's own `bash scripts/check-sdd-structure.sh` request, tool use `toolu_013BjpQZBq68o9d3qDXmQ5V4`. Resume that session from its original checkout with ordinary interactive Claude permissions, not permissive flags:

```text
cd /private/tmp/a7-realhost-spy.nhCxLM/repo
rtk proxy claude --resume c3811461-1e2d-4571-8afc-e1979980b656 --model sonnet --plugin-dir /private/tmp/a7-realhost-spy.nhCxLM/repo/plugins/sdd-bootstrap --plugin-dir /private/tmp/a7-realhost-spy.nhCxLM/repo/plugins/sdd-quality-loop
```

The human must handle the actual permission prompt through Claude's normal mechanism. Do not substitute a renamed command, executor, blanket allowance, or bypass mode. Preserve the original input: the old session's successful permission recovery alone is not positive Context evidence.

After genuine input publication and successful standard validation, a fresh ordinary interactive bootstrap in the new checkout is a separate prospective run, not a reinterpretation of the old one. It must perform its own prerequisite check and hook challenge/canary/verification before track selection. Continue only through the existing entry point `/sdd-bootstrap:bootstrap feature --feature a7-spy-positive`; do not manually invoke the dispatcher to manufacture caller evidence.

The existing PATH-only diagnostic observer still has an explicit-path visibility limitation. `sdd-bootstrap-interviewer/SKILL.md:63-98` requires the real dispatcher once with explicit `--config`, `--target-rev`, and `--feature`. Capture the normal host tool trace and prove that the chosen process observation actually sees the positive call before using negative zero counts. If the host uses an explicit repository path and the PATH observer sees nothing, that is unavailable observation, not zero-call success. No replacement wrapper may be installed at the protected dispatcher path. F1/F3/F4 native acceptance remains unexecuted until the positive observation prerequisite is satisfied.

## Remaining exact conditions

Human-only: real signer identity/registry publication, key-holder signing and publication, and normal host approval of the refused prerequisite command. Agent-continuable afterward: standard approval validation, genuine native handshake/entry-point run, observation validation, then isolated negative cases. Independent unresolved design issue: the frozen A7-to-current-A5 citation drift requires the already documented prospective contract re-binding; this addendum neither edits nor re-binds it.
