#!/usr/bin/env python3
"""Independent real-gate measurement; never changes product or approval state."""

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import time
from unittest.mock import patch

FILES = [
    "plugins/sdd-quality-loop/scripts/check-workflow-state.sh",
    "plugins/sdd-quality-loop/scripts/workflow-state-session.py",
    "plugins/sdd-bootstrap/scripts/project-skill.py",
    "plugins/sdd-bootstrap/scripts/project-skill-process.py",
    "plugins/sdd-quality-loop/scripts/validate-project-skill.py",
    "contracts/workflow-state-registry.schema.json",
]


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def pins(root):
    return {name: sha((root / name).read_bytes()) for name in FILES}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--source-root", type=Path, required=True)
    p.add_argument("--registry", type=Path, required=True)
    p.add_argument("--mode", choices=["baseline", "batch"], required=True)
    p.add_argument("--requests", type=int, default=2)
    p.add_argument("--output", type=Path, required=True)
    args = p.parse_args()
    root = args.source_root.resolve()
    registry = args.registry.resolve()
    args.output.mkdir(parents=True, exist_ok=False)
    before = pins(root)
    spec = importlib.util.spec_from_file_location(
        "measured_workflow_session", root / FILES[1]
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    events = []
    probes = []
    actual = module.runner()

    def save(kind, argv, result, elapsed):
        number = len(events) + len(probes)
        row = {
            "kind": kind,
            "argv": [str(x) for x in argv],
            "exit_code": result[0],
            "reason": result[3],
            "cleanup": result[4],
            "elapsed_ns": elapsed,
        }
        for name, raw in [("stdout", result[1]), ("stderr", result[2])]:
            path = args.output / (str(number) + "." + name)
            path.write_bytes(raw)
            row[name] = {"path": path.name, "sha256": sha(raw)}
        (
            events if kind in ("ordinary-full-scan", "sealed-full-scan") else probes
        ).append(row)

    def execute(argv, *pos, **kw):
        command = argv[argv.index("--") + 1 :]
        kind = (
            "sealed-full-scan"
            if command[:2] == ["/usr/bin/bash", str(module.GATE)]
            else "runtime-probe"
        )
        start = time.monotonic_ns()
        result = actual(argv, *pos, **kw)
        save(kind, argv, result, time.monotonic_ns() - start)
        return result

    def cold():
        argv = ["/usr/bin/bash", str(module.GATE), "--registry", str(registry)]
        start = time.monotonic_ns()
        r = subprocess.run(
            argv,
            capture_output=True,
            timeout=300,
            env=dict(os.environ, **module.ENVIRONMENT),
        )
        save(
            "ordinary-full-scan",
            argv,
            (r.returncode, r.stdout, r.stderr, None, True),
            time.monotonic_ns() - start,
        )

    start = time.monotonic_ns()
    batch = None
    reason = None
    batch_ns = None
    if args.mode == "baseline":
        for _ in range(args.requests):
            cold()
    else:
        began = time.monotonic_ns()
        try:
            with patch.object(module, "runner", return_value=execute):
                batch = module.batch(
                    registry, ["request-" + str(n) for n in range(args.requests)]
                )
        except (OSError, ValueError, subprocess.SubprocessError) as exc:
            reason = str(exc)
        batch_ns = time.monotonic_ns() - began
        if reason:
            for _ in range(args.requests):
                cold()
    total_ns = time.monotonic_ns() - start
    after = pins(root)
    row = {
        "mode": args.mode,
        "registry": str(registry),
        "requests": args.requests,
        "source_before": before,
        "source_after": after,
        "source_stable": before == after,
        "receipt_reusable": before == after and batch is not None and batch["complete"],
        "batch_status": "cold-required" if reason else "completed" if batch else None,
        "cold_reason": reason,
        "total_ns": total_ns,
        "batch_ns": batch_ns,
        "batch": batch,
        "events": events,
        "runtime_probes": probes,
        "actual_full_scan_count": len(events),
        "sealed_full_scan_count": sum(x["kind"] == "sealed-full-scan" for x in events),
        "fallback_full_scan_count": sum(
            x["kind"] == "ordinary-full-scan" for x in events
        )
        if reason
        else 0,
        "reused_count": sum(not x["executed"] for x in batch["results"])
        if batch
        else 0,
    }
    execution_ns = sum(
        x["elapsed_ns"] for x in events if x["kind"] == "sealed-full-scan"
    ) + sum(x["elapsed_ns"] for x in probes)
    row["capture_seal_key_revalidation_other_ns"] = (
        None if batch_ns is None else batch_ns - execution_ns
    )
    (args.output / "result.json").write_text(json.dumps(row, indent=2) + "\n")
    print(
        json.dumps(
            {
                k: row[k]
                for k in [
                    "source_stable",
                    "batch_status",
                    "cold_reason",
                    "total_ns",
                    "actual_full_scan_count",
                    "reused_count",
                ]
            }
        )
    )
    if before != after:
        raise SystemExit(3)


if __name__ == "__main__":
    main()
