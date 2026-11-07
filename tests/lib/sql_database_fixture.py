"""Test-only Docker lifecycle and evidence for isolated SQL reference cases.

No production DSN or existing container is accepted. This is not a migration
runner: tests invoke the pinned upstream clients and inspect their real effects.
"""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import platform
import re
import secrets
import subprocess
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
LABEL = "sdd.sql.test-run"


class DockerFixture:
    def __init__(self, engine: str, output: Path, inputs: list[Path]):
        if not re.fullmatch(r"[a-z][a-z0-9-]*", engine):
            raise ValueError("invalid fixture engine")
        self.engine = engine
        self.output = Path(output).resolve()
        self.run_id = f"sdd-sql-{engine}-{uuid.uuid4().hex[:12]}"
        self.containers: list[str] = []
        self.pending_containers: list[str] = []
        self.network: str | None = None
        self.secrets: list[str] = []
        self.commands: list[dict] = []
        self.checks: list[dict] = []
        self.images: list[str] = []
        self.versions: dict[str, str] = {}
        self.start = time.monotonic()
        # Keep proxy/registry configuration, but never an inherited daemon selector.
        self.environment = dict(os.environ)
        for name in ("DOCKER_HOST", "DOCKER_CONTEXT", "DOCKER_TLS",
                     "DOCKER_TLS_VERIFY", "DOCKER_CERT_PATH"):
            self.environment.pop(name, None)
        self.input_hashes = {
            str(path.resolve().relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in sorted(set([Path(__file__), *inputs]))
        }
        self.source = subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
        self.dirty = bool(subprocess.check_output(
            ["git", "status", "--porcelain", "--", *self.input_hashes],
            cwd=ROOT, text=True).strip())

    def secret(self) -> str:
        value = "Sdd9!" + secrets.token_hex(20)
        self.secrets.append(value)
        return value

    def redact(self, value: str) -> str:
        for secret in self.secrets:
            value = value.replace(secret, "[REDACTED]")
        return value

    def run(self, argv, *, label=None, input_text=None, extra_env=None,
            expected=0, timeout=120, cwd=None):
        argv = [str(part) for part in argv]
        started = time.monotonic()
        entry = {"label": label or Path(argv[0]).name,
                 "argv": [self.redact(part) for part in argv],
                 "started_ms": round((started - self.start) * 1000),
                 "cwd": str(Path(cwd or ROOT).resolve())}
        env = dict(self.environment)
        env.update(extra_env or {})
        try:
            result = subprocess.run(argv, input=input_text, text=True,
                                    capture_output=True, env=env, cwd=cwd or ROOT,
                                    timeout=timeout, check=False)
            entry.update(returncode=result.returncode,
                         stdout=self.redact(result.stdout)[-6000:],
                         stderr=self.redact(result.stderr)[-6000:])
        except subprocess.TimeoutExpired:
            entry.update(returncode=None, timeout=True)
            raise RuntimeError(f"{entry['label']}: client timeout; server state is unknown") from None
        finally:
            entry["elapsed_ms"] = round((time.monotonic() - started) * 1000)
            self.commands.append(entry)
        if expected is not None and result.returncode != expected:
            raise RuntimeError(self.redact(
                f"{entry['label']}: exit {result.returncode}, expected {expected}\n"
                f"{result.stderr[-2000:]}\n{result.stdout[-2000:]}"))
        return result

    def docker(self, args, **kwargs):
        return self.run(["docker", "--host=unix:///var/run/docker.sock", *args], **kwargs)

    def check(self, name, condition, detail=None):
        self.checks.append({"name": name, "result": "PASS" if condition else "FAIL",
                            "detail": detail})
        if not condition:
            raise AssertionError(f"{name}: {self.redact(str(detail or 'condition failed'))}")
        print(f"PASS {name}", flush=True)

    def create_network(self):
        self.check("Linux x86_64 reference host",
                   platform.system() == "Linux" and platform.machine() in ("x86_64", "amd64"))
        self.docker(["info", "--format", "{{.OSType}}"], label="local Docker readiness")
        name = self.run_id
        self.network = name  # retain the attempted name if the client times out
        result = self.docker(["network", "create", "--internal", "--label",
                              f"{LABEL}={self.run_id}", name], label="create isolated network")
        self.network = result.stdout.strip()
        self.check("owned network ID", bool(re.fullmatch(r"[0-9a-f]{64}", self.network)))
        return self.network

    def pull(self, image):
        self.check("immutable image reference", bool(re.fullmatch(
            r"[a-z0-9./_-]+(?::[A-Za-z0-9_][A-Za-z0-9_.-]{0,127})?@sha256:[0-9a-f]{64}", image)))
        if image not in self.images:
            self.docker(["pull", "--platform", "linux/amd64", image],
                        label="pull pinned image", timeout=300)
            self.images.append(image)

    def start_container(self, image, *, name="db", env=None, command=None,
                        publish=None, mounts=None, memory="1g"):
        if self.network is None:
            raise RuntimeError("create isolated network before containers")
        if not re.fullmatch(r"[a-z][a-z0-9-]*", name):
            raise ValueError("invalid container alias")
        for port in publish or []:
            if not re.fullmatch(r"127\.0\.0\.1::[0-9]{1,5}", port):
                raise ValueError("only random loopback published ports are allowed")
        self.pull(image)
        container_name = f"{self.run_id}-{name}-{uuid.uuid4().hex[:8]}"
        args = ["run", "--detach", "--platform", "linux/amd64", "--name",
                container_name, "--label",
                f"{LABEL}={self.run_id}", "--network", self.network,
                "--network-alias", name, "--memory", memory, "--cpus", "2"]
        for key in env or {}:
            args.extend(["--env", key])
        for port in publish or []:
            args.extend(["--publish", port])
        for mount in mounts or []:
            args.extend(["--mount", mount])
        args.extend([image, *(command or [])])
        self.pending_containers.append(container_name)
        result = self.docker(args, label=f"start {name}", extra_env=env, timeout=60)
        container = result.stdout.strip()
        if not re.fullmatch(r"[0-9a-f]{64}", container):
            raise RuntimeError("Docker did not return an owned container ID")
        self.containers.append(container)
        self.pending_containers.remove(container_name)
        return container

    def flyway(self, image, url, user, password, migrations, operation, options=()):
        container = self.start_container(
            image, name="migration", env={
                "FLYWAY_URL": url, "FLYWAY_USER": user,
                "FLYWAY_PASSWORD": password, "FLYWAY_CLEAN_DISABLED": "true",
                "FLYWAY_CONNECT_RETRIES": "0",
            }, mounts=[f"type=bind,src={Path(migrations).resolve()},dst=/flyway/sql,readonly"],
            command=["-outputType=json", *options, operation])
        result = self.docker(["wait", container], label=f"Flyway {operation} completion", timeout=120)
        logs = self.docker(["logs", container], label=f"Flyway {operation} result")
        # Use the upstream process exit, not the exit status of `docker logs`.
        code = int(result.stdout.strip())
        return subprocess.CompletedProcess(["flyway", operation], code, logs.stdout, logs.stderr)

    def _owned(self, kind, resource):
        result = self.docker([*(["network"] if kind == "network" else []), "inspect", resource],
                             label=f"verify {kind} ownership")
        row = json.loads(result.stdout)[0]
        labels = row.get("Labels", {}) if kind == "network" else row.get("Config", {}).get("Labels", {})
        if labels.get(LABEL) != self.run_id:
            raise RuntimeError(f"refusing cleanup of unowned {kind}")

    def finish(self, error=None):
        cleanup_errors = []
        for pending in self.pending_containers:
            try:
                probe = self.docker(["inspect", pending], expected=None, label="inspect pending create")
                if probe.returncode == 0:
                    self.containers.append(pending)
                elif probe.returncode != 1 or "No such object" not in probe.stderr:
                    cleanup_errors.append("could not determine pending container state")
            except Exception as exc:
                cleanup_errors.append(self.redact(str(exc)))
        for container in reversed(self.containers):
            try:
                self._owned("container", container)
                self.docker(["rm", "--force", "--volumes", container], label="remove owned container")
                absent = self.docker(["inspect", container], expected=None, label="confirm container removed")
                if absent.returncode != 1 or "No such object" not in absent.stderr:
                    raise RuntimeError("could not confirm owned container removal")
            except Exception as exc:
                cleanup_errors.append(self.redact(str(exc)))
        if self.network:
            try:
                self._owned("network", self.network)
                self.docker(["network", "rm", self.network], label="remove owned network")
                absent = self.docker(["network", "ls", "--filter",
                                      f"label={LABEL}={self.run_id}", "--quiet"],
                                     label="confirm network removed")
                if absent.stdout.strip():
                    raise RuntimeError("owned network remains")
            except Exception as exc:
                cleanup_errors.append(self.redact(str(exc)))
        success = (error is None and not cleanup_errors and bool(self.checks)
                   and all(item["result"] == "PASS" for item in self.checks))
        proof = {
            "schema": "sdd-sql-reference-observation/v1", "engine": self.engine,
            "source_revision": self.source, "inputs_dirty": self.dirty,
            "input_sha256": self.input_hashes, "run_id": self.run_id,
            "images": self.images, "versions": self.versions,
            "scope": "isolated synthetic reference DB; not cloud or production acceptance",
            "checks": self.checks, "commands": self.commands,
            "error": self.redact(str(error)) if error else None,
            "cleanup": {"removed": not cleanup_errors, "errors": cleanup_errors},
            "result": "PASS" if success else "FAIL",
        }
        self.output.parent.mkdir(parents=True, exist_ok=True)
        self.output.write_text(self.redact(json.dumps(proof, indent=2, ensure_ascii=False)) + "\n")
        if error is not None:
            print(self.redact(f"Failure: {error}"), flush=True)
        for cleanup_error in cleanup_errors:
            print(f"Cleanup failure: {cleanup_error}", flush=True)
        print(f"{proof['result']}: {self.output}", flush=True)
        return 0 if success else 1
