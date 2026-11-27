#!/usr/bin/env python3
"""Check the actual upload snapshot against the latest human scan override."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import tempfile


def digest(value):
    encoded = json.dumps(value, ensure_ascii=True, separators=(",", ":"), sort_keys=True)
    return hashlib.sha256(encoded.encode("ascii")).hexdigest()


def raise_error(error):
    raise error


def linked(path):
    info = path.lstat()
    return stat.S_ISLNK(info.st_mode) or bool(getattr(info, "st_file_attributes", 0) & stat.FILE_ATTRIBUTE_REPARSE_POINT)


def snapshot(source, stage):
    if linked(source) or not source.is_dir() or source.resolve() in stage.resolve().parents:
        raise ValueError("expected a separate upload directory")
    manifest = {}
    for directory, subdirs, files in os.walk(source, onerror=raise_error):
        for name in subdirs + files:
            path = Path(directory) / name
            if linked(path) or any(ord(c) < 32 for c in name):
                raise ValueError("unsupported upload path")
        for name in files:
            path = Path(directory) / name
            if not stat.S_ISREG(path.stat().st_mode):
                raise ValueError("expected regular upload files")
            relative = path.relative_to(source)
            target = stage / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            checksum = hashlib.sha256()
            with path.open("rb") as original, target.open("xb") as output:
                for chunk in iter(lambda: original.read(1024 * 1024), b""):
                    output.write(chunk)
                    checksum.update(chunk)
            manifest[relative.as_posix()] = checksum.hexdigest()
    if not manifest:
        raise ValueError("empty upload")
    return manifest


def scan(stage, runtime, manifest):
    script = Path(__file__).resolve().with_name("design-sync-scan." + runtime)
    command = ["sh"] if runtime == "sh" else ["pwsh", "-NoProfile", "-File"]
    result = subprocess.run([*command, str(script), str(stage)], capture_output=True, encoding="utf-8")
    lines = result.stdout.splitlines()
    if result.stderr or result.returncode not in (0, 1):
        raise ValueError("scanner failed")
    if result.returncode == 0 and lines == ["Design-Sync Scan passed (0 findings)."]:
        return []
    header = re.fullmatch(r"Design-Sync Scan FAILED \(([1-9][0-9]*) finding\(s\)\):", lines[0]) if lines else None
    if result.returncode != 1 or not header:
        raise ValueError("unrecognized scan result")
    count = int(header[1])
    rows = [line for line in lines[1:] if line.startswith(" - ")]
    if len(rows) != count:
        raise ValueError("incomplete scan findings")
    findings = []
    for row in rows:
        match = re.fullmatch(r" - (placeholder|secret|PII) +(.+):([1-9][0-9]*): (.+)", row)
        if not match:
            raise ValueError("unrecognized finding")
        category, filename, number, display = match.groups()
        relative = Path(filename).relative_to(stage).as_posix()
        if relative not in manifest or (category != "placeholder" and display != "[REDACTED]"):
            raise ValueError("unexpected finding")
        findings.append([relative, int(number), category, display])
    return sorted(findings)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("runtime", choices=("sh", "ps1"))
    parser.add_argument("payload", type=Path)
    args = parser.parse_args()
    stage = None
    keep_stage = False
    try:
        request = json.load(sys.stdin)
        if not isinstance(request, dict):
            raise ValueError("expected scan context")
        scope = {}
        for key in ("feature", "session", "service", "destination_id"):
            value = request.get(key)
            if not isinstance(value, str) or not value.strip():
                raise ValueError("missing " + key)
            scope[key] = value
        stage = Path(tempfile.mkdtemp(prefix="design-sync-send-")).resolve()
        manifest = snapshot(args.payload, stage)
        findings = scan(stage, args.runtime, manifest)
        result = {"action": "clean", "scan_at": datetime.now(timezone.utc).isoformat()}
        if findings:
            identity = dict(scope, schema="design-sync-override/v1",
                            payload_sha256=digest(manifest), findings_sha256=digest(findings))
            previous = request.get("latest_override")
            reuse = (isinstance(previous, dict) and set(previous) == {"decision", "party", "identity"}
                     and previous["decision"] == "granted"
                     and isinstance(previous.get("party"), str) and bool(previous["party"].strip())
                     and previous.get("identity") == identity)
            result.update(action="reuse" if reuse else "review", identity=identity, findings=findings)
        if result["action"] != "review":
            result["upload_directory"] = str(stage)
        print(json.dumps(result))
        keep_stage = "upload_directory" in result
        return 0 if keep_stage else 1
    except (OSError, ValueError):
        print("design-sync: could not verify the planned upload and scan", file=sys.stderr)
        return 2
    finally:
        if stage is not None and not keep_stage:
            shutil.rmtree(stage)


if __name__ == "__main__":
    sys.exit(main())
