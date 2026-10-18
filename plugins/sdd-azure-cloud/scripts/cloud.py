"""Azure local CLI. No provider transport, credentials, or write authority.

Installed callers may explicitly select the trusted shared scripts directory with
CLOUD_SHARED_RUNTIME_ROOT. Otherwise use the repository/sibling-plugin layout.
Never resolve runtime modules from the deployment workspace or Python search path.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import secrets
import stat
import subprocess
import sys
from typing import Any


def load_contracts():
    directory = Path(os.environ.get("CLOUD_SHARED_RUNTIME_ROOT", str(
        Path(__file__).resolve().parents[2] / "sdd-quality-loop/scripts")))
    path = directory / "cloud_contracts.py"
    if not directory.is_absolute() or path.resolve() != path or not path.is_file():
        raise ValueError("SHARED_RUNTIME_UNAVAILABLE")
    sys.path.insert(0, str(directory))
    spec = importlib.util.spec_from_file_location("cloud_contracts", path)
    if spec is None or spec.loader is None:
        raise ValueError("SHARED_RUNTIME_UNAVAILABLE")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


try:
    c = load_contracts()
except (ValueError, OSError, ImportError):
    if __name__ != "__main__":
        raise
    print(json.dumps(dict(schema="cloud-input-error/v1", error_code="SHARED_RUNTIME_UNAVAILABLE",
                          message="Install the trusted shared runtime before retrying.", field="runtime")))
    sys.exit(2)


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def encode(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, ensure_ascii=True) + "\n").encode()


def decode(data: bytes) -> Any:
    c._require(len(data) <= c.MAX_BYTES, "ARTIFACT_TOO_LARGE")

    def pairs(items):
        result = {}
        for key, value in items:
            c._require(key not in result, "DUPLICATE_KEY")
            result[key] = value
        return result

    def number(_):
        raise c.ContractError("INVALID_NUMBER")

    try:
        return json.loads(data.decode("utf-8"), object_pairs_hook=pairs,
                          parse_constant=number, parse_float=number)
    except (ValueError, UnicodeError, RecursionError):
        raise c.ContractError("INVALID_JSON") from None


def read_bytes(root: Path, path: str) -> bytes:
    """Read an untrusted request/inventory without following links or special files."""
    with c._parent(root, path) as (fd, name):
        handle = os.open(name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=fd)
        with os.fdopen(handle, "rb") as stream:
            before = os.fstat(stream.fileno())
            c._require(stat.S_ISREG(before.st_mode) and before.st_nlink == 1, "UNSAFE_FILE")
            c._require(before.st_size <= c.MAX_BYTES, "ARTIFACT_TOO_LARGE")
            data = stream.read(c.MAX_BYTES + 1)
            after = os.fstat(stream.fileno())
            c._require((before.st_size, before.st_mtime_ns, before.st_ctime_ns) ==
                       (after.st_size, after.st_mtime_ns, after.st_ctime_ns), "INPUT_DRIFT")
            return data


def safe_publication(data: bytes) -> bool:
    # Closed local outputs contain identifiers/digests, not arbitrary provider text.
    # Reject credential-like content even in otherwise valid owner-supplied strings.
    data = data.replace(b'"disablePasswordAuthentication": true', b'')
    return not re.search(rb'(?i)(private[ _-]?key|-----BEGIN|bearer\s|password|access[ _-]?token|client[ _-]?secret|secret[ _-]?canary)', data)


def publish_json(root: Path, path: str, value: Any) -> dict[str, str]:
    """Exclusive publication of provider JSON not registered as a shared artifact."""
    return publish_bytes(root, path, encode(value))


def publish_bytes(root: Path, path: str, data: bytes) -> dict[str, str]:
    """Preserve actual compiler bytes; never normalize a compiled artifact."""
    decode(data)
    c._require(safe_publication(data), "SECRET_SCAN_FAILED")
    with c._parent(root, path) as (fd, name):
        temp = ".azure-" + secrets.token_hex(16)
        out = os.open(temp, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600, dir_fd=fd)
        try:
            with os.fdopen(out, "wb") as stream:
                stream.write(data)
                stream.flush()
                os.fsync(stream.fileno())
            os.link(temp, name, src_dir_fd=fd, dst_dir_fd=fd, follow_symlinks=False)
            os.fsync(fd)
        finally:
            os.unlink(temp, dir_fd=fd)
    return dict(path=path, sha256=digest(data))


def canonical_argument(root: Path, arg: str) -> str:
    if arg.startswith(str(root) + "/"):
        arg = arg[len(str(root)) + 1:]
    c._path(arg)
    return arg


def output_path(root: Path, request: dict, output: str) -> str:
    relative = canonical_argument(root, output)
    directory = request["local_context"]["evidence_directory"]
    c._require(relative.startswith(directory + "/"), "OUTPUT_OUTSIDE_EVIDENCE")
    with c._parent(root, relative) as (fd, name):
        try:
            os.stat(name, dir_fd=fd, follow_symlinks=False)
        except FileNotFoundError:
            return relative
    raise c.ContractError("OUTPUT_EXISTS")


def detect_owner(root: Path, request: dict, files: list[str]) -> dict:
    ownership = c.read_artifact(root, request["local_context"]["ownership"], "cloud-ownership/v1")
    selected = ownership["owners"]
    c._require(len(selected) == 1 and request["owner"] is not None, "OWNER_SELECTION_REQUIRED")
    detected = {o["owner"] for o in selected}
    for path in files:
        name = Path(path).name.lower()
        if name.endswith((".tf", ".tf.json", ".tfstate", ".tfstate.backup")) or name == ".terraform.lock.hcl" or ".terraform" in Path(path).parts:
            detected.add("terraform")
        elif name in ("azure.yaml", "azure.yml"):
            detected.add("azd")
        elif name == "cdk.json" or name == "cdk.context.json":
            detected.add("cdk")
        elif name.endswith((".bicep", ".bicepparam")):
            detected.add("bicep")
        elif name.endswith((".json", ".yaml", ".yml")):
            data = read_bytes(root, path)
            try:
                document = decode(data)
            except c.ContractError:
                if name.endswith(".json"):
                    raise
                if b"AWS::Serverless" in data:
                    detected.add("sam")
                elif b"AWSTemplateFormatVersion" in data or re.search(rb'(?m)(?:^|["\s])Resources["\s]*:', data):
                    detected.add("cloudformation")
                else:
                    # Unknown YAML cannot establish an exclusive Bicep owner.
                    raise c.ContractError("OWNER_UNRESOLVED") from None
            else:
                if type(document) is dict:
                    transforms = document.get("Transform", [])
                    transforms = transforms if type(transforms) is list else [transforms]
                    if any(type(value) is str and value.startswith("AWS::Serverless") for value in transforms):
                        detected.add("sam")
                    elif "Resources" in document or "AWSTemplateFormatVersion" in document:
                        detected.add("cloudformation")
    c._require(len(detected) == 1, "OWNER_CONFLICT")
    c._require(detected == {"bicep"}, "OWNER_UNSUPPORTED")
    c._require(request["owner"] == "bicep" and request["route"] in (None, "azure-bicep"), "OWNER_MISMATCH")
    c._require(any(p.endswith(".bicep") for p in files), "SOURCE_REQUIRED")
    config = decode(c.read_verified(root, request["local_context"]["provider_config"]))
    c._require(type(config) is dict and config.get("schema") == "azure-local-config/v1", "PROVIDER_CONFIG_REQUIRED")
    c._require(config.get("import_resources") is False, "IMPORT_UNSUPPORTED")
    from azure_local import configuration
    try:
        configuration(config, discovery=True)
    except c.ContractError:
        raise c.ContractError("LOCAL_POLICY_DENIED") from None
    return ownership


def envelope(request: dict, phase: str, request_hash: str, *, error: str | None = None,
             evidence: str | None = None) -> dict:
    value = dict(schema="cloud-operation-result/v1",
                 **{k: request[k] for k in ("run_id", "unit_id", "provider")},
                 operation=phase, state="BLOCKED" if error else {
                     "route": "ROUTED", "plan": "PLANNED", "validate": "LOCAL_VALIDATED"}[phase],
                 result="BLOCKED" if error else "PASS", error_code=error,
                 message=("Local prerequisite failed; correct the named error before retrying."
                          if error else "Local check only; no cloud validation or authorization."),
                 input_manifest_sha256=request_hash, evidence_manifest_path=evidence)
    c.parse_artifact(encode(value), "cloud-operation-result/v1")
    return value


class Parser(argparse.ArgumentParser):
    def error(self, message):
        raise c.ContractError("INVALID_ARGUMENT")


def run(argv: list[str], *, executor=None) -> dict:
    parser = Parser(add_help=False, allow_abbrev=False)
    parser.add_argument("operation", choices=c.OPERATIONS)
    parser.add_argument("--request", required=True)
    parser.add_argument("--output", required=True)
    try:
        args = parser.parse_args(argv)
        # Absolute request paths permit an identity-free error even without a root.
        # All successful operations subsequently require the explicit workspace.
        if args.request.startswith("/"):
            data = read_bytes(Path("/"), args.request[1:])
        else:
            data = read_bytes(c.workspace_root(), args.request)
        request = c.parse_artifact(data, "cloud-run-request/v1")
    except c.ContractError as exc:
        return c.input_error(str(exc), "request")
    except (OSError, ValueError):
        return c.input_error("INVALID_INPUT", "request")
    request_hash = digest(data)
    try:
        c._require(request["provider"] == "azure", "PROVIDER_MISMATCH")
        if args.operation in ("observe", "verify"):
            c._require(executor is not None, "TRUSTED_COLLECTOR_REQUIRED")
            root = c.workspace_root()
            request_path = canonical_argument(root, args.request)
            c._require(executor.root == root and executor.request_ref ==
                       dict(path=request_path, sha256=request_hash), "EXECUTOR_BINDING_MISMATCH")
            output = output_path(root, request, args.output)
            return executor.observe(output, args.operation)
        if executor is not None and args.operation in ("prepare", "apply", "reconcile"):
            root = c.workspace_root()
            request_path = canonical_argument(root, args.request)
            c._require(executor.root == root and executor.request_ref ==
                       dict(path=request_path, sha256=request_hash), "EXECUTOR_BINDING_MISMATCH")
            output = output_path(root, request, args.output)
            if args.operation == "prepare":
                return executor.prepare(output)
            directory = request["local_context"]["evidence_directory"]
            if args.operation == "apply":
                c._require(executor.preview_ref is not None, "PREVIEW_REQUIRED")
                return executor.apply(executor.preview_ref, output)
            path = directory + "/deployment-submission.json"
            with c._parent(root, path) as (fd, name):
                try:
                    os.stat(name, dir_fd=fd, follow_symlinks=False)
                except FileNotFoundError:
                    path = directory + "/intent-fence.json"
            journal = read_bytes(root, path)
            return executor.reconcile(dict(path=path, sha256=digest(journal)), output)
        if args.operation not in ("route", "plan", "validate"):
            raise c.ContractError("OPERATION_UNIMPLEMENTED")
        root = c.workspace_root()
        request_path = canonical_argument(root, args.request)
        c._require(read_bytes(root, request_path) == data, "INPUT_DRIFT")
        files = c.verify_local_context(root, request)
        output = output_path(root, request, args.output)
        ownership = detect_owner(root, request, files)
        manifest_path = output + ".manifest.json"
        output_path(root, request, manifest_path)
        extra = {}
        if args.operation != "route":
            from azure_local import prepare_local
            extra = prepare_local(root, request, files, args.operation,
                                  dict(path=request_path, sha256=request_hash))
        c._require(read_bytes(root, request_path) == data, "INPUT_DRIFT")
        manifest = dict(schema="azure-local-evidence/v1", operation=args.operation,
                        run_id=request["run_id"], unit_id=request["unit_id"],
                        request=dict(path=request_path, sha256=request_hash), owner="bicep", route="azure-bicep",
                        existing_resources=ownership["existing_resources"],
                        inventory=[dict(path=p, sha256=digest(read_bytes(root, p))) for p in files],
                        classification="local", cloud_validated=False, **extra)
        publish_json(root, manifest_path, manifest)
        result = envelope(request, args.operation, request_hash, evidence=manifest_path)
        c.publish_artifact(root, output, encode(result), scan=safe_publication)
        return result
    except c.ContractError as exc:
        return envelope(request, args.operation, request_hash, error=str(exc))
    except RecursionError:
        return envelope(request, args.operation, request_hash, error="NESTING_LIMIT")
    except (OSError, ValueError, KeyError, TypeError, TimeoutError, subprocess.TimeoutExpired):
        return envelope(request, args.operation, request_hash, error="LOCAL_INPUT_UNAVAILABLE")


if __name__ == "__main__":
    sys.modules["cloud"] = sys.modules[__name__]
    result = run(sys.argv[1:])
    sys.stdout.buffer.write(encode(result))
    sys.exit(c.exit_code(result))
