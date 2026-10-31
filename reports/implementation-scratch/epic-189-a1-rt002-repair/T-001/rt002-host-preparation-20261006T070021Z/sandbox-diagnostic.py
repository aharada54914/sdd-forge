"""One-shot, model-free app-server command/exec boundary diagnostic; no retries."""
import datetime
import hashlib
import json
import pathlib
import queue
import subprocess
import tempfile
import threading

base = pathlib.Path(__file__).resolve().parent
output = pathlib.Path(tempfile.mkdtemp(prefix="sandbox-output-", dir=base))
outside = pathlib.Path(tempfile.mkdtemp(prefix="rt002-outside-canary-", dir="/private/tmp"))
sealed = base / "snapshot/contracts/task-input-manifest.schema.json"
before = hashlib.sha256(sealed.read_bytes()).hexdigest()
observed = {"started_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
            "kind": "standalone-command-exec-not-thread-or-turn", "output_root": str(output),
            "outside_canary_dir": str(outside), "sealed_sha256_before": before,
            "thread_created": False, "model_called": False, "reservation": False, "events": []}
policy = {"type": "workspaceWrite", "writableRoots": [str(output)],
          "networkAccess": False, "excludeTmpdirEnvVar": True, "excludeSlashTmp": True}
observed["sandbox_policy"] = policy
p = subprocess.Popen(["rtk", "proxy", "codex", "app-server"], cwd=output,
                     stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
received = queue.Queue()
def receive():
    for line in p.stdout:
        try:
            received.put(json.loads(line))
        except json.JSONDecodeError:
            received.put({"non_json": line.rstrip()})
    received.put({"eof": True})
threading.Thread(target=receive, daemon=True).start()
# Drain stderr without exposing config, registration metadata or unrelated host details.
stderr_count = [0]
def drain():
    for line in p.stderr:
        stderr_count[0] += 1
threading.Thread(target=drain, daemon=True).start()
def send(message):
    p.stdin.write(json.dumps(message) + "\n")
    p.stdin.flush()
def request(number, method, params):
    send({"id": number, "method": method, "params": params})
    deadline = __import__("time").monotonic() + 30
    while True:
        remaining = deadline - __import__("time").monotonic()
        if remaining <= 0:
            raise TimeoutError(method)
        item = received.get(timeout=remaining)
        if item.get("id") == number:
            observed["events"].append({"method": method, "response": item})
            return item
        if item.get("eof"):
            raise RuntimeError("app-server EOF")
        if "id" in item and "method" in item:
            raise RuntimeError("unexpected server request; no approval or retry")
try:
    init = request(1, "initialize", {"clientInfo": {"name": "rt002_sandbox_diagnostic", "version": "1"}})
    if "error" in init:
        raise RuntimeError("initialize rejected")
    send({"method": "initialized", "params": {}})
    commands = [
        ("inside-write", ["rtk", "proxy", "/usr/bin/touch", str(output / "inside.canary")]),
        ("sealed-read", ["rtk", "proxy", "/usr/bin/shasum", "-a", "256", str(sealed)]),
        ("outside-write", ["rtk", "proxy", "/usr/bin/touch", str(outside / "outside.canary")]),
    ]
    for number, (label, command) in enumerate(commands, 2):
        response = request(number, "command/exec", {"command": command, "cwd": str(output),
                           "sandboxPolicy": policy, "timeoutMs": 10000, "outputBytesCap": 4096})
        observed["events"][-1]["label"] = label
        if "error" in response or response.get("result", {}).get("exitCode") != 0:
            observed["stopped_on"] = label
            break
except Exception as exc:
    observed["exception"] = type(exc).__name__ + ": " + str(exc)
finally:
    p.stdin.close()
    try:
        p.wait(timeout=5)
        observed["termination"] = "stdin EOF"
    except subprocess.TimeoutExpired:
        p.terminate()
        try:
            p.wait(timeout=5)
            observed["termination"] = "SIGTERM"
        except subprocess.TimeoutExpired:
            p.kill()
            p.wait(timeout=5)
            observed["termination"] = "SIGKILL"
    observed.update({"server_exit_code": p.returncode, "server_pid": p.pid,
                     "stderr_line_count": stderr_count[0],
                     "inside_canary_exists": (output / "inside.canary").exists(),
                     "outside_canary_exists": (outside / "outside.canary").exists(),
                     "sealed_sha256_after": hashlib.sha256(sealed.read_bytes()).hexdigest(),
                     "finished_at": datetime.datetime.now(datetime.timezone.utc).isoformat()})
    result_path = output / "diagnostic-result.json"
    result_path.write_text(json.dumps(observed, indent=2) + "\n")
    print(json.dumps({"result_path": str(result_path), **observed}, indent=2))
