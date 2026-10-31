"""Bounded revalidation; preserve raw output and never modify admitted sources."""
import datetime
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import time

EVIDENCE = Path(__file__).resolve().parent
WORK = EVIDENCE.parents[4]
OUTPUT = WORK.parent
MANIFEST = OUTPUT.parent / "manifest.json"
SNAPSHOT = OUTPUT.parent / "snapshot"
EXPECTED = "a20263eec7b1732c48c837b38e649083c87ab3d2581fd48cc01c5e91006648bd"
COMMANDS = {
    "unified-task-launch": ["python3", "-B", "tests/unified-task-launch.tests.py", "-v"],
    "task-structured-output": ["python3", "-B", "tests/task-structured-output.tests.py", "-v"],
    "quality-nontty-transport": ["python3", "-B", "tests/quality-nontty-transport.tests.py", "-v"],
    "spec-review-verify-inputs": ["python3", "-B", "tests/spec-review-verify-inputs.tests.py", "-v"],
    "host-review-preflight": ["python3", "-B", "tests/host-review-preflight.tests.py", "-v"],
    "unified-launch-order": ["python3", "-B", "tests/unified-launch-order.tests.py", "-v"],
    "review-conditional-inputs": ["python3", "-B", "tests/review-conditional-inputs.tests.py", "-v"],
    "review-context-boundary": ["bash", "tests/review-context-boundary.tests.sh"],
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save(name, value):
    (EVIDENCE / name).write_text(json.dumps(value, indent=2) + "\n")


def timestamp():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def manifest():
    assert digest(MANIFEST) == EXPECTED, "manifest hash mismatch"
    return json.loads(MANIFEST.read_text())


def environment():
    paths = {
        "TMPDIR": OUTPUT / "tmp", "TMP": OUTPUT / "tmp", "TEMP": OUTPUT / "tmp",
        "XDG_CACHE_HOME": OUTPUT / "cache", "XDG_CONFIG_HOME": OUTPUT / "config",
        "XDG_DATA_HOME": OUTPUT / "data", "XDG_STATE_HOME": OUTPUT / "state",
        "DOTNET_CLI_HOME": OUTPUT / "dotnet", "NPM_CONFIG_CACHE": OUTPUT / "npm-cache",
    }
    for path in paths.values():
        path.mkdir(parents=True, exist_ok=True)
    settings = {key: str(value) for key, value in paths.items()}
    settings.update(PYTHONDONTWRITEBYTECODE="1", POWERSHELL_TELEMETRY_OPTOUT="1",
                    DOTNET_CLI_TELEMETRY_OPTOUT="1", GIT_CEILING_DIRECTORIES=str(OUTPUT))
    return dict(os.environ, **settings), settings


def execute(label, command, timeout=600):
    env, settings = environment()
    argv = ["rtk", "proxy"] + command
    started = timestamp()
    clock = time.monotonic()
    timed_out = False
    try:
        result = subprocess.run(argv, cwd=WORK, env=env, stdin=subprocess.DEVNULL,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout)
        stdout, stderr, code = result.stdout, result.stderr, result.returncode
    except subprocess.TimeoutExpired as error:
        stdout, stderr, code = error.stdout or b"", error.stderr or b"", None
        timed_out = True
    (EVIDENCE / (label + ".stdout.log")).write_bytes(stdout)
    (EVIDENCE / (label + ".stderr.log")).write_bytes(stderr)
    record = dict(command=argv, cwd=str(WORK), stdin="DEVNULL", environment_overrides=settings,
                  started_at=started, ended_at=timestamp(), seconds=time.monotonic() - clock,
                  exit_code=code, timed_out=timed_out,
                  stdout=label + ".stdout.log", stderr=label + ".stderr.log")
    save(label + ".json", record)
    print(json.dumps(record), flush=True)
    print((stdout + stderr).decode(errors="replace")[-2500:], flush=True)
    return record


def audit(name, copied):
    records = []
    for entry in manifest()["allowed_inputs"]:
        relative = entry["path"]
        assert not Path(relative).is_absolute() and ".." not in Path(relative).parts
        source = SNAPSHOT / relative
        actual = digest(source)
        assert actual == entry["sha256"], relative
        row = dict(path=relative, expected=entry["sha256"], snapshot_sha256=actual)
        if copied:
            row["work_sha256"] = digest(WORK / relative)
            assert row["work_sha256"] == actual, relative
        records.append(row)
    save(name, dict(manifest_sha256=EXPECTED, checked_at=timestamp(), count=len(records),
                    all_match=True, files=records))


if __name__ == "__main__":
    mode = sys.argv[1]
    if mode == "prepare":
        environment()
        audit("input-hashes-before.json", False)
        for entry in manifest()["allowed_inputs"]:
            target = WORK / entry["path"]
            assert not target.exists(), "refuse overwrite: " + str(target)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(SNAPSHOT / entry["path"], target)
        audit("copied-input-hashes.json", True)
        save("environment.json", dict(observed_at=timestamp(), platform=platform.platform(),
             machine=platform.machine(), python=sys.version, executable=sys.executable))
        for label, command in {
            "version-python": ["python3", "--version"], "version-bash": ["bash", "--version"],
            "version-pwsh": ["pwsh", "-NoLogo", "-NoProfile", "-Command", "$PSVersionTable.PSVersion.ToString()"],
            "version-node": ["node", "--version"], "version-jq": ["jq", "--version"],
            "version-rtk": ["rtk", "--version"], "version-claude": ["claude", "--version"],
        }.items():
            execute(label, command, 30)
    elif mode == "audit":
        audit("input-hashes-after.json", True)
        print("607 snapshot/work files match the pinned manifest")
    else:
        execute(mode, COMMANDS[mode])
