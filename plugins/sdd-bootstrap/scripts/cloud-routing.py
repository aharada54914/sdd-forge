"""Internal bootstrap seam: forward an explicit request to one installed entry.

plugin-root is trusted host installation metadata, never deployment input. This
helper neither interprets the run request nor grants cloud write authority.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
from typing import NoReturn


class InvalidRoute(ValueError):
    pass


class Parser(argparse.ArgumentParser):
    def error(self, message: str) -> NoReturn:
        raise InvalidRoute("INVALID_ARGUMENTS")


def run(argv: list[str]) -> int:
    try:
        parser = Parser(add_help=False, allow_abbrev=False)
        parser.add_argument("--provider", required=True, choices=("azure", "aws"))
        parser.add_argument("--plugin-root", required=True, type=Path)
        parser.add_argument("operation", choices=("route", "plan", "validate", "prepare", "apply", "reconcile", "observe", "verify"))
        parser.add_argument("--request", required=True)
        parser.add_argument("--output", required=True)
        args = parser.parse_args(argv)
        root = args.plugin_root
        if not root.is_absolute() or root.resolve() != root:
            raise InvalidRoute("INSTALLED_PLUGIN_REQUIRED")
        manifest = json.loads((root / ".codex-plugin/plugin.json").read_bytes())
        if manifest.get("name") != "sdd-" + args.provider + "-cloud":
            raise InvalidRoute("PROVIDER_MISMATCH")
        cli = root / "scripts/cloud.py"
        runtime = root / "runtime/scripts"
        for path in [cli, *(runtime / name for name in (
                "cloud_contracts.py", "cloud_authorization.py", "cloud_verification.py", "cloud_dependencies.py"))]:
            if not path.is_file() or path.resolve() != path:
                raise InvalidRoute("INSTALLED_RUNTIME_REQUIRED")
        env = dict(os.environ, CLOUD_SHARED_RUNTIME_ROOT=str(runtime))
        # No shell, alternate writer, request rewriting or approval translation.
        return subprocess.run([sys.executable, "-B", str(cli), args.operation,
                               "--request", args.request, "--output", args.output], env=env, check=False).returncode
    except (InvalidRoute, OSError, ValueError, AttributeError):
        print(json.dumps(dict(schema="cloud-input-error/v1", error_code="CLOUD_ROUTE_BLOCKED",
                              message="Select one installed cloud provider and a canonical request; no cloud operation was authorized.",
                              field="route")))
        return 2


if __name__ == "__main__":
    raise SystemExit(run(sys.argv[1:]))
