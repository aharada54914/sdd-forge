# Native Codex review transport verification

The product launcher now supports unmanaged spec/impl/task reviewer A/B and the quality evaluator. It allocates an idle native thread, validates the canonical input set, reserves the real host identity, and only then starts the model. It preserves the existing role and stage adoption gates. A completed transport emits a candidate; it never promotes workflow status by itself.

## Native evidence

- `spec-transport/`: genuine native spec reviewer `01a1b5be-183c-7692-81f4-e7af8040198f`, PASS candidate. The root was a copied full project with a copied ledger, explicitly an integration fixture rather than proof of a separate full workflow. The fixture regenerated its spec precheck against current calibration. This first successful trial preceded the final narrowing of the runtime grant from the CLI directory to the exact executable; the final native permission suite and quality trial exercise the narrower grant.
- `quality-transport/`: genuine native evaluator `01a1b5cb-4f70-7ba2-a997-1927e541118e`, PASS candidate, 11 hash-pinned inputs. It observed the admitted files and actually reran the two Python acceptance assertions inside the read-only native projection. Implementation IDs are explicitly synthetic fixture labels, not a claimed native implementation. The fixture copies a test ledger. This is transport integration, not the UI/full-workflow completion result.
- Native `command/exec` probes establish admitted read success, outside-file read denial, read-only write denial, and denied network socket creation without starting a model turn. The thread and turn explicitly select the same named profile. The host event observations and the raw source event SHA-256 are saved beside each candidate.
- Final independent security review fixed output `..` traversal, narrowed the runtime grant to the exact CLI executable, and bound observed relative reads to the native event's actual absolute cwd. The independent reviewer reran all 17 tests including real native probes, with no remaining blocker in this scope.

## Commands and results

From the repository, with the installed PowerShell shim and RTK on PATH:

```sh
export PATH=/workspace/.tools/rtk/0.51.0:/workspace/.tools/sdd-forge-dev/bin:$PATH
SDD_TEST_CODEX_PERMISSIONS=1 python3 tests/codex-review-launcher.tests.py
python3 tests/quality-nontty-transport.tests.py
python3 tests/host-review-preflight.tests.py
python3 tests/fixed-review-launch.tests.py
python3 tests/unified-launch-order.tests.py
python3 tests/unified-task-launch.tests.py
python3 tests/verification-catalog.tests.py
python3 plugins/sdd-quality-loop/scripts/generate-guard-invariants.py --check
git diff --check
```

Results: native transport 17/17 (including real native permission probes, zero skips); shared quality transport 24 tests with one existing platform skip; host preflight 21/21; fixed launch 50/50; unified launch order 9/9; task launch 9/9; catalog 15 tests with one existing skip. Generated guards and whitespace checks passed. The new suite is registered in the verification catalog, and the launcher is included in generated protected entrypoints.

Native CLI shape (use a fresh output directory and the externally computed template hash):

```sh
CODEX_HOME=/workspace/.tools/sdd-forge-dev/codex-verify python3 -I -B \
  plugins/sdd-review-loop/scripts/launch-codex-review.py \
  "$project" "$project/template.json" --manifest-sha256 "$template_sha" \
  --output "$project/reports/new-native-run" --timeout 600
```

The current real fixtures remain under `/workspace/.tools/sdd-forge-dev/verification-workspace/native-launcher-integration` and `native-evaluator-smoke`. The included preparation script documents the tiny evaluator fixture; it is not a general application generator. Two initial fixture attempts correctly stopped for a missing implementation Scratch Root and a missing pinned implementation task manifest. Their consumed/unused identities were not reset. The report was then explicitly completed as a synthetic transport fixture, preserving the canonical binding requirements.

## Limits

This native route currently requires Linux, a compatible Codex app-server with named permissions, and the probe runtime tools. Minimal platform runtime reads and the exact CLI executable are trusted; other project files, network, writes and external connectors are excluded. Model/account configuration remains the host's. Outer host permission to run and authenticate a nested native server is separate from the strict reviewer profile; a workspace-write outer CLI may prevent host-state initialization and must not be mistaken for a reviewer-policy failure.

The quality route reuses canonical implementation-manifest and scratch-history admission and the existing plaintext result contract. Observing one admitted-file read is the existing minimum delivery condition, not proof that every requirement was substantively reviewed. Normal canonical workflow validators must still adopt the candidate, and the evaluator must disclose tests it could not run. Runtime inspection probes and copied fixture results do not certify arbitrary applications or replace the parallel normal full/SQLite sessions.
