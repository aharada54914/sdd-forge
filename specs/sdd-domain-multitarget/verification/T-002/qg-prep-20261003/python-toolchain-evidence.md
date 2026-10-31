# T-002 Python lint and typecheck evidence (owner side, 2026-10-03)

The changed production Python validator is
`plugins/sdd-quality-loop/scripts/validate-capability-registry.py`. Its local
import, `registry_discovery.py`, is included in lint and followed by mypy.
These are pinned tool versions, run from the repository root via `rtk proxy`.

| Check | Command | Exit | Observed output |
|---|---|---:|---|
| lint | `rtk proxy uvx --from ruff==0.13.3 ruff check plugins/sdd-quality-loop/scripts/validate-capability-registry.py plugins/sdd-quality-loop/scripts/registry_discovery.py` | 0 | `All checks passed!` |
| typecheck | `rtk proxy uvx --from mypy==1.18.2 mypy --strict plugins/sdd-quality-loop/scripts/validate-capability-registry.py` | 0 | `Success: no issues found in 1 source file` |
| focused behavioral regression | `rtk proxy python3 -B specs/sdd-domain-multitarget/verification/T-002/contract-boundaries.tests.py --repo-root . -q` | 0 | `Ran 28 tests in 0.024s`; `OK` |
| imported helper regression | `rtk proxy bash tests/registry-discovery.tests.sh` | 0 | `pass=21 fail=0` |

The mypy invocation uses `--strict` with default import following. It checks
the imported `registry_discovery.py` as well as the named validator; it does
not use an import-suppression flag. The changes add annotations without
relaxing type rules. JSON input remains dynamically typed at the `json.load`
boundary, represented by `Any` in the annotations.

The project has a real current-tree distribution assembly path:
`install.sh --source-directory <worktree> --install-root <isolated-temp-root>
--target FilesOnly --skip-plugin-install --skip-agent-install --skip-mcp`.
`install.sh:961-986` takes Git-tracked names but reads their **working-tree
bytes**, then assembles an installed plugin tree; FilesOnly does not register
CLI plugins. The two changed Python files are tracked. The first isolated
assembly succeeded (exit 0), and `cmp` verified both installed bytes against
the then-current source. Installed hashes were
`6628b9b04f6988701fab8a765e4297dd81920748980d1a6bfc1434150845d2ab`
for the validator and
`3c556f022741831cc169b50dfc0b05685bbbf0c087d90706052b65e9ae4225c9`
for the helper. The temporary install root was removed by its trap. This
assembly predates the subsequent Python-compatibility annotation change and
must **not** be attributed to the current bytes.

The current source hashes after that change are
`4794ef81888e83a4d45f37a680ab65436cd1ca97e1d01c59acf8a22dae898788`
and `ea08dbd141b24f4685fd9211b4454d782e5ea80e081e0a59d89ee7f7fe5282ea`
respectively. The attempt to assemble and execute the validator from a fresh
installed tree using these bytes was denied **before command execution** by
the PreToolUse hook. Thus there is no new assembly or installed-runtime result
for the current bytes; `build` is still unverified. The exact denied command:

```sh
rtk proxy bash -c 'set -euo pipefail; stage_root="$(mktemp -d "${TMPDIR:-/tmp}/sdd-t002-build.XXXXXX")"; trap '\''rm -rf "$stage_root"'\'' EXIT; ./install.sh --source-directory "$PWD" --install-root "$stage_root/installed" --target FilesOnly --skip-plugin-install --skip-agent-install --skip-mcp; cmp plugins/sdd-quality-loop/scripts/validate-capability-registry.py "$stage_root/installed/plugins/sdd-quality-loop/scripts/validate-capability-registry.py"; cmp plugins/sdd-quality-loop/scripts/registry_discovery.py "$stage_root/installed/plugins/sdd-quality-loop/scripts/registry_discovery.py"; python3 -B "$stage_root/installed/plugins/sdd-quality-loop/scripts/validate-capability-registry.py" --registry "$stage_root/installed/contracts/capability-registry.json" --repo-root "$stage_root/installed"; shasum -a 256 "$stage_root/installed/plugins/sdd-quality-loop/scripts/validate-capability-registry.py" "$stage_root/installed/plugins/sdd-quality-loop/scripts/registry_discovery.py"; echo "T-002 installed payload assembly, parity, and validator execution: PASS"'
```

Hook result: `Command blocked by PreToolUse hook: SDD決定論ゲート: エージェントはゲートスクリプト・フック設定・テストファイルを書き換えられません。これらのファイルは強制チェーンの一部です。sudo でもバイパスできません。` No alternate execution of the rejected operation was attempted.
Lint, strict typecheck, and the 28+21 regressions were rerun successfully
after the annotation change. The annotations use Python 3.6-compatible
`typing.Dict/List/Optional/Tuple` and no future annotations; this preserves
the repository's documented Python 3.6+ compatibility. This note is not an
independent quality-gate verdict, CI result, or Done decision.

## Protected CI workflow candidate

`.github/workflows/test.yml` is protected by
`plugins/sdd-quality-loop/references/guard-invariants.json`; its current
SHA-256 is `fd086938cdffbdc63ca6caf2c8beb89d29d68210182b5b9f41d71e4abab9064b`.
The proposed job below is for human/protected-path review and has not been
applied. It uses a fresh Linux venv, pinned direct tool versions, and the same
scope as the owner-side checks:

```yaml
  t002-python-toolchain:
    name: T-002 Python lint and typecheck
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - name: Install pinned Python checkers
        run: |
          python3 -m venv "$RUNNER_TEMP/t002-python-checks"
          "$RUNNER_TEMP/t002-python-checks/bin/python" -m pip install --disable-pip-version-check ruff==0.13.3 mypy==1.18.2
      - name: Lint T-002 Python production path and imported helper
        run: |
          "$RUNNER_TEMP/t002-python-checks/bin/ruff" check plugins/sdd-quality-loop/scripts/validate-capability-registry.py plugins/sdd-quality-loop/scripts/registry_discovery.py
      - name: Strict typecheck T-002 Python production path
        run: |
          "$RUNNER_TEMP/t002-python-checks/bin/mypy" --strict plugins/sdd-quality-loop/scripts/validate-capability-registry.py
```

The same protected job can then add a current-checkout distribution assembly
step using the existing `install.sh` FilesOnly route, without pinned source
hashes (CI must compare its own current checkout). Place it after the strict
typecheck step and before the job completes:

```yaml
      - name: Assemble and run T-002 installed plugin payload
        run: |
          ./install.sh --source-directory "$GITHUB_WORKSPACE" --install-root "$RUNNER_TEMP/t002-installed" --target FilesOnly --skip-plugin-install --skip-agent-install --skip-mcp
          cmp plugins/sdd-quality-loop/scripts/validate-capability-registry.py "$RUNNER_TEMP/t002-installed/plugins/sdd-quality-loop/scripts/validate-capability-registry.py"
          cmp plugins/sdd-quality-loop/scripts/registry_discovery.py "$RUNNER_TEMP/t002-installed/plugins/sdd-quality-loop/scripts/registry_discovery.py"
          python3 -B "$RUNNER_TEMP/t002-installed/plugins/sdd-quality-loop/scripts/validate-capability-registry.py" --registry "$RUNNER_TEMP/t002-installed/contracts/capability-registry.json" --repo-root "$RUNNER_TEMP/t002-installed"
```

The existing CI already runs POSIX installer tests at
`.github/workflows/test.yml:401-405` and `registry-discovery.tests.sh` at
line 838; this candidate adds only the two production-source tool checks and
the T-002-specific installed-payload assertion. CI remains unverified until
the protected workflow edit is authorized, applied, and run on the current
head.
