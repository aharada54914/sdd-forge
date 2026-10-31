#!/usr/bin/env python3
"""Bounded Unix candidate experiment; identities are not implementation evidence."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import stat
import subprocess
import tempfile
import time

p = argparse.ArgumentParser()
p.add_argument("builder")
p.add_argument("--race", action="store_true")
p.add_argument("--output", required=True)
a = p.parse_args()
builder = Path(a.builder).resolve()
work = Path(tempfile.mkdtemp(prefix="fixture-", dir=Path(a.output).parent))
repo = work / "repo"
repo.mkdir()
cases = {"run": 0o755, "group.txt": 0o750, "owner": 0o700,
         "all": 0o777, "plain.sh": 0o644, "private": 0o600,
         "special": 0o7755}
body = b"#!/bin/sh\nprintf 'executed\\n'\n"
for name, mode in cases.items():
    f = repo / name
    f.write_bytes(body)
    f.chmod(mode)
manifest = work / "manifest.json"
manifest.write_text(json.dumps({"allowed_inputs": [
    {"path": name, "sha256": hashlib.sha256(body).hexdigest()} for name in cases]}))

def command(dest):
    if builder.suffix == ".ps1":
        return ["pwsh", "-NoLogo", "-NoProfile", "-File", str(builder),
                "-Manifest", str(manifest), "-RepoRoot", str(repo), "-SnapshotRoot", str(dest)]
    return ["bash", str(builder), "--manifest", str(manifest), "--repo-root", str(repo),
            "--snapshot-root", str(dest)]

results = []
def check(name, ok, detail=""):
    results.append({"case": name, "pass": bool(ok), "detail": detail})

dest = work / "snapshot"
cp = subprocess.run(command(dest), capture_output=True, text=True)
check("builder", cp.returncode == 0, cp.stdout + cp.stderr)
if cp.returncode == 0:
    for name, mode in cases.items():
        actual = stat.S_IMODE((dest / name).stat().st_mode)
        check("mode:" + name, actual == (0o444 | (mode & 0o111)), oct(actual))
        check("source-unchanged:" + name, stat.S_IMODE((repo / name).stat().st_mode) == mode
              and (repo / name).read_bytes() == body)
    try:
        run = subprocess.run([str(dest / "run")], capture_output=True, text=True)
        check("direct-executable", run.returncode == 0 and run.stdout == "executed\n")
    except PermissionError as e:
        check("direct-executable", False, str(e))
    try:
        subprocess.run([str(dest / "plain.sh")], check=True, capture_output=True)
        check("direct-nonexecutable-denied", False)
    except PermissionError:
        check("direct-nonexecutable-denied", True)
    check("nonprivileged", os.geteuid() != 0, str(os.geteuid()))
    for action in ["write", "create", "delete"]:
        try:
            if action == "write":
                with (dest / "private").open("ab") as stream:
                    stream.write(b"unexpected")
            elif action == "create":
                (dest / "unexpected").write_text("unexpected")
            else:
                (dest / "private").unlink()
            check("readonly:" + action, False)
        except PermissionError:
            check("readonly:" + action, True)
    check("directory-mode", stat.S_IMODE(dest.stat().st_mode) == 0o555)

if a.race:
    barrier = work / "copy-barrier"
    barrier.mkdir()
    race_dest = work / "race-snapshot"
    env = dict(os.environ, SDD_TEST_SNAPSHOT_COPY_BARRIER_DIR=str(barrier))
    process = subprocess.Popen(command(race_dest), env=env, stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE, text=True)
    deadline = time.monotonic() + 8
    while not (barrier / "ready").exists() and process.poll() is None and time.monotonic() < deadline:
        time.sleep(0.01)
    ready = (barrier / "ready").exists()
    check("copy-barrier", ready)
    if ready:
        (repo / "run").chmod(0o644)
        (barrier / "continue").touch()
    out, err = process.communicate(timeout=15)
    check("mode-only-change-rejected", ready and process.returncode != 0
          and "TASK_INPUT_HASH" in out + err and not race_dest.exists(), out + err)
    check("race-temp-cleaned", not list(work.glob(".task-snapshot-*")))

record = {"builder": str(builder), "uid": os.geteuid(), "fixture_root": str(work),
          "results": results, "pass": all(r["pass"] for r in results)}
Path(a.output).write_text(json.dumps(record, indent=2) + "\n")
print(json.dumps(record, indent=2))
raise SystemExit(0 if record["pass"] else 1)
