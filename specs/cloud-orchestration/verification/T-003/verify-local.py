"""Scoped local checks with exact commands, real exits and synthetic/live labels."""

from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import py_compile
import subprocess

root = Path(__file__).resolve().parents[4]
evidence = root / "specs/cloud-orchestration/verification/T-003"
scratch = Path("/tmp/cloud-T-003-01a14d65")
quality_python = "/tmp/cloud-quality-python/bin/python"
sources = [
    "plugins/sdd-quality-loop/scripts/cloud_authorization.py",
    "tests/cloud-orchestration-execution.tests.py",
    "templates/cloud/iam/trusted-policy.example.py",
    "specs/cloud-orchestration/verification/T-003/coverage-runner.py",
    "specs/cloud-orchestration/verification/T-003/rollback-test.py",
    "specs/cloud-orchestration/verification/T-003/verify-local.py",
]
checks = []
for name, argv in [
    (
        "lint",
        [
            quality_python,
            "-m",
            "ruff",
            "check",
            "--config",
            "tests/shared-launch-python/pyproject.toml",
            *sources,
        ],
    ),
    (
        "typecheck",
        [
            quality_python,
            "-m",
            "mypy",
            "--config-file",
            "tests/shared-launch-python/pyproject.toml",
            "--cache-dir",
            str(scratch / "mypy"),
            *sources,
        ],
    ),
    ("green", ["python3", "-B", "tests/cloud-orchestration-execution.tests.py"]),
    ("regression", ["python3", "-B", "tests/cloud-orchestration-contracts.tests.py"]),
    (
        "manifest-validation-final",
        [
            "bash",
            "plugins/sdd-implementation/scripts/validate-task-input-manifest.sh",
            "--manifest",
            "specs/cloud-orchestration/verification/T-003/task-input-manifest.json",
            "--snapshot-root",
            str(scratch / "inputs"),
            "--expected-task",
            "T-003",
        ],
    ),
    (
        "supplemental-manifest-validation",
        [
            "bash",
            "plugins/sdd-implementation/scripts/validate-task-input-manifest.sh",
            "--manifest",
            "specs/cloud-orchestration/verification/T-003/supplemental-api-input-manifest.json",
            "--snapshot-root",
            str(scratch / "inputs"),
            "--expected-task",
            "T-003",
        ],
    ),
]:
    started = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    result = subprocess.run(argv, cwd=root, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False)
    (evidence / (name + ".log")).write_bytes(result.stdout)
    checks.append(
        dict(
            name=name,
            command=argv,
            exit_code=result.returncode,
            started_at=started,
            log="specs/cloud-orchestration/verification/T-003/" + name + ".log",
        )
    )
for index, path in enumerate(sources):
    py_compile.compile(str(root / path), cfile=str(scratch / f"build-{index}.pyc"), doraise=True)
(evidence / "build.log").write_text(
    "py_compile.compile(..., doraise=True) on all six new Python source/evidence files; bytecode under task scratch only.\nEXIT: 0\nSyntax build only; separate mypy check recorded.\n"
)
(evidence / "checks.json").write_text(
    json.dumps(
        dict(
            classification="deterministic local fixtures and local static checks; no live API calls",
            checks=checks,
            sources={p: hashlib.sha256((root / p).read_bytes()).hexdigest() for p in sources},
        ),
        indent=2,
    )
    + "\n"
)
for check in checks:
    print(check["name"], check["exit_code"])
raise SystemExit(1 if any(c["exit_code"] for c in checks) else 0)
