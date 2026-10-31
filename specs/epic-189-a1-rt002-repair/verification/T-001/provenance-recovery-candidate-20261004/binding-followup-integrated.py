"""Build and test an isolated integrated overlay; no working source edits."""

import importlib.util
import difflib
import datetime
import hashlib
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile


def replace_once(path, before, after):
    original = path.read_text()
    if original.count(before) != 1:
        raise RuntimeError(f"candidate anchor changed: {path}: count={original.count(before)}")
    path.write_text(original.replace(before, after))


def main():
    if len(sys.argv) not in (2, 3) or (len(sys.argv) == 3 and sys.argv[2] not in ("--emit-patch-only", "--run-binding-only", "--run-binding-before-only")):
        raise SystemExit("usage: binding-followup-integrated.py <#423-reference-repo> [--emit-patch-only|--run-binding-only|--run-binding-before-only]")
    source = pathlib.Path(sys.argv[1]).resolve()
    helper_path = pathlib.Path(__file__).with_name("binding-followup-regression.py")
    spec = importlib.util.spec_from_file_location("binding_regression", helper_path)
    helper = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper)
    with tempfile.TemporaryDirectory(prefix="rt002-binding-integrated-") as directory:
        overlay = pathlib.Path(directory) / "repo"
        overlay.mkdir()
        shutil.copytree(source / "plugins", overlay / "plugins")
        shutil.copytree(source / "tests", overlay / "tests")
        helper.patched_validators(source, overlay)
        old_lines = (source / "plugins/sdd-quality-loop/scripts/validate-review-context-set.sh").read_text().splitlines()
        new_lines = (overlay / "plugins/sdd-quality-loop/scripts/validate-review-context-set.sh").read_text().splitlines()
        line_map = {}
        for match in difflib.SequenceMatcher(a=old_lines, b=new_lines, autojunk=False).get_matching_blocks():
            for offset in range(match.size):
                line_map[match.a + offset + 1] = match.b + offset + 1
        doc = overlay / "plugins/sdd-review-loop/references/review-context-boundary.md"
        doc.write_text(re.sub(
            r"(?<![A-Za-z0-9._-]):(\d+)(?:-(\d+))?",
            lambda m: ":" + str(line_map.get(int(m.group(1)), int(m.group(1))))
            + ("-" + str(line_map.get(int(m.group(2)), int(m.group(2)))) if m.group(2) else ""),
            doc.read_text(),
        ))
        boundary_test = overlay / "tests/review-context-boundary.tests.sh"
        boundary_test.write_text(re.sub(
            r"^:(\d+)(?:-(\d+))?(?= validator )",
            lambda m: ":" + str(line_map.get(int(m.group(1)), int(m.group(1))))
            + ("-" + str(line_map.get(int(m.group(2)), int(m.group(2)))) if m.group(2) else ""),
            boundary_test.read_text(),
            flags=re.MULTILINE,
        ))
        old_py = '''        write_json(implementation_manifest, dict(schema="task-input-manifest/v1", task_id="T-001",
                                                 run_id="worker-run", session_id="worker-session"))
'''
        new_py = '''        requirement = root / "specs/f/requirements.md"
        requirement.parent.mkdir(parents=True)
        requirement.write_text("requirements\\n")
        write_json(implementation_manifest, dict(
            schema="task-input-manifest/v1", task_id="T-001", run_id="worker-run",
            session_id="worker-session", agent_instance_id="worker-agent",
            model_tier="standard", provider="codex", model="codex-general-medium",
            estimated_cost_per_attempt_usd="0.125", cost_estimate_source="fixture-2026-10-04",
            cost_estimate_timestamp="2026-10-04T00:00:00Z", isolation_mode="fresh-agent",
            fallback_reason="", handoff_reload_evidence_hash="",
            allowed_inputs=[dict(path="specs/f/requirements.md", sha256=digest(requirement.read_bytes()))],
            allowed_outputs=["reports/implementation/f/T-001.md"]))
'''
        for name in ("issue311-scratch-isolation.tests.py", "review-scratch-history.tests.py"):
            replace_once(overlay / "tests" / name, old_py, new_py)
        old_sh = '''  jq -n '{schema:"task-input-manifest/v1",task_id:"T-001",run_id:"worker-run",session_id:"worker-session"}' \\
    > "$repository/handoffs/fixture/manifest.json"
'''
        new_sh = '''  local requirement_hash
  requirement_hash="$(sha256 "$repository/specs/f/requirements.md")"
  jq -n --arg req "$requirement_hash" '{
    schema:"task-input-manifest/v1",task_id:"T-001",run_id:"worker-run",session_id:"worker-session",
    agent_instance_id:"worker-agent",model_tier:"standard",provider:"codex",model:"codex-general-medium",
    estimated_cost_per_attempt_usd:"0.125",cost_estimate_source:"fixture-2026-10-04",
    cost_estimate_timestamp:"2026-10-04T00:00:00Z",isolation_mode:"fresh-agent",
    fallback_reason:"",handoff_reload_evidence_hash:"",
    allowed_inputs:[{path:"specs/f/requirements.md",sha256:$req}],
    allowed_outputs:["reports/implementation/f/T-001.md"]}' \\
    > "$repository/handoffs/fixture/manifest.json"
'''
        replace_once(overlay / "tests/review-agent-isolation.tests.sh", old_sh, new_sh)
        old_make = '''    if ! grep -Fq '**Scratch Root**:' "$implementation_report"; then
      printf '%s\\n' '- **Scratch Root**: /tmp/implementation-f' >> "$implementation_report"
    fi
'''
        new_make = '''    if ! grep -Fq '**Scratch Root**:' "$implementation_report"; then
      printf '%s\\n' '- **Scratch Root**: /tmp/implementation-f' >> "$implementation_report"
    fi
    if ! grep -q '^Run ID: ' "$implementation_report"; then
      printf '%s\\n' 'Run ID: worker-run' >> "$implementation_report"
    fi
    if ! grep -Fq -- '- **Run ID**: ' "$implementation_report"; then
      printf '%s\\n' '- **Run ID**: worker-run' >> "$implementation_report"
    fi
    if ! grep -Fq -- '- **Session ID**: ' "$implementation_report"; then
      printf '%s\\n' '- **Session ID**: worker-session' >> "$implementation_report"
    fi
    if ! grep -q '^Input manifest:' "$implementation_report"; then
      printf 'Input manifest: `handoffs/fixture/manifest.json`, SHA-256 `%s`\\n' \\
        "$(sha256 "$repository/handoffs/fixture/manifest.json")" >> "$implementation_report"
    fi
'''
        replace_once(overlay / "tests/review-agent-isolation.tests.sh", old_make, new_make)
        shutil.copy2(pathlib.Path(__file__).with_name("review-implementation-binding.tests.py"),
                     overlay / "tests/review-implementation-binding.tests.py")
        workflow = overlay / ".github/workflows/test.yml"
        workflow.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source / ".github/workflows/test.yml", workflow)
        replace_once(workflow,
                     '        run: python3 tests/issue311-scratch-isolation.tests.py --repo "$GITHUB_WORKSPACE"\n',
                     '        run: python3 tests/issue311-scratch-isolation.tests.py --repo "$GITHUB_WORKSPACE"\n'
                     '      - name: Test evaluator implementation binding (Bash and PowerShell)\n'
                     '        shell: bash\n'
                     '        run: python3 tests/review-implementation-binding.tests.py --repo "$GITHUB_WORKSPACE"\n')
        run_all = overlay / "tests/run-all.sh"
        replace_once(run_all,
                     '  echo "SKIP: issue311-scratch-isolation.tests.py requires python3 and pwsh"\nfi\n',
                     '  echo "SKIP: issue311-scratch-isolation.tests.py requires python3 and pwsh"\nfi\n'
                     '\nif command -v python3 >/dev/null 2>&1 && command -v pwsh >/dev/null 2>&1; then\n'
                     '  echo "==> tests/review-implementation-binding.tests.py"\n'
                     '  if ! python3 tests/review-implementation-binding.tests.py --repo "$ROOT"; then\n'
                     '    echo "FAILED: tests/review-implementation-binding.tests.py"\n'
                     '    failed+=("tests/review-implementation-binding.tests.py")\n'
                     '  fi\n'
                     'else\n'
                     '  echo "SKIP: review-implementation-binding.tests.py requires python3 and pwsh"\n'
                     'fi\n')
        changed = (
            ".github/workflows/test.yml",
            "plugins/sdd-quality-loop/scripts/validate-review-context-set.sh",
            "plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1",
            "plugins/sdd-review-loop/references/review-context-boundary.md",
            "tests/issue311-scratch-isolation.tests.py",
            "tests/review-scratch-history.tests.py",
            "tests/review-agent-isolation.tests.sh",
            "tests/review-context-boundary.tests.sh",
            "tests/run-all.sh",
            "tests/review-implementation-binding.tests.py",
        )
        if len(sys.argv) == 3 and sys.argv[2] == "--emit-patch-only":
            patch = []
            for name in changed:
                old = (source / name).read_text() if (source / name).exists() else ""
                new = (overlay / name).read_text()
                if old == new:
                    raise RuntimeError(f"candidate has no changes: {name}")
                patch.extend(difflib.unified_diff(old.splitlines(keepends=True), new.splitlines(keepends=True),
                                                  fromfile=("a/" + name) if old else "/dev/null",
                                                  tofile="b/" + name))
                print(name, "BEFORE", hashlib.sha256(old.encode()).hexdigest(),
                      "AFTER", hashlib.sha256(new.encode()).hexdigest())
            destination = pathlib.Path(__file__).with_name("binding-followup-integrated.patch")
            destination.write_text("".join(patch))
            print("PATCH", destination, "SHA256", hashlib.sha256(destination.read_bytes()).hexdigest())
            return
        env = dict(os.environ, T005_SOURCE_GIT_ROOT=str(source))
        commands = (
            ["bash", "-n", "plugins/sdd-quality-loop/scripts/validate-review-context-set.sh"],
            ["python3", "tests/issue311-scratch-isolation.tests.py", "--repo", str(overlay)],
            ["python3", "tests/review-scratch-history.tests.py", "--repo", str(overlay)],
            ["bash", "tests/review-agent-isolation.tests.sh"],
            ["bash", "tests/review-context-boundary.tests.sh"],
            ["python3", "tests/review-implementation-binding.tests.py", "--repo", str(overlay)],
        )
        if len(sys.argv) == 3 and sys.argv[2] in ("--run-binding-only", "--run-binding-before-only"):
            commands = commands[-1:]
        if len(sys.argv) == 3 and sys.argv[2] == "--run-binding-before-only":
            for suffix in ("sh", "ps1"):
                name = f"plugins/sdd-quality-loop/scripts/validate-review-context-set.{suffix}"
                shutil.copy2(source / name, overlay / name)
        patch_sha = hashlib.sha256(pathlib.Path(__file__).with_name("binding-followup-integrated.patch").read_bytes()).hexdigest()
        mode = sys.argv[2].removeprefix("--run-") if len(sys.argv) == 3 else "full"
        timestamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
        log_path = pathlib.Path(__file__).with_name(f"binding-followup-{mode}-{timestamp}-{patch_sha[:12]}.log")
        log_lines = ["SOURCE " + str(source), "PATCH_SHA256 " + patch_sha]
        for command in commands:
            result = subprocess.run(command, cwd=overlay, env=env, capture_output=True, text=True, timeout=240)
            print("COMMAND", " ".join(command), "EXIT", result.returncode)
            log_lines.extend(("COMMAND " + " ".join(command), "EXIT " + str(result.returncode),
                              "STDOUT", result.stdout, "STDERR", result.stderr))
            for line in (result.stdout + "\n" + result.stderr).splitlines():
                if line.startswith(("PASS:", "FAIL:", "not ok:")) or "Traceback" in line:
                    print(line)
            if result.returncode:
                log_path.write_text("\n".join(log_lines))
                print("LOG", log_path)
                print("TAIL", "\n".join((result.stdout + "\n" + result.stderr).splitlines()[-12:]))
                raise SystemExit(result.returncode)
        log_path.write_text("\n".join(log_lines))
        print("LOG", log_path)


if __name__ == "__main__":
    main()
