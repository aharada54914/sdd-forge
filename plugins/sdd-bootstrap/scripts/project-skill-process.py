#!/usr/bin/env python3
"""Linux-only child subreaper for one authorized project command.

Owns no process outside its descendant tree. This is lifecycle tracking, not an
access sandbox: child code retains the caller's file/network permissions.
"""

import argparse
import ctypes
import json
import math
import os
from pathlib import Path
import signal
import subprocess
import sys
import time


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--status-fd", type=int, required=True)
    parser.add_argument("--timeout", type=float, required=True)
    parser.add_argument("argv", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if not math.isfinite(args.timeout) or not 0 < args.timeout <= 3600:
        parser.error("--timeout must be finite and between 0 and 3600 seconds")
    if not Path("/proc/self/stat").is_file():
        parser.error("process ownership requires Linux procfs")
    command = args.argv[1:] if args.argv[:1] == ["--"] else args.argv
    status = {"cleanup": False, "reason": None, "exit_code": None}
    try:
        if sys.platform != "linux" or not command:
            raise ValueError("process-ownership-backend-unavailable")
        libc = ctypes.CDLL(None, use_errno=True)
        if libc.prctl(36, 1, 0, 0, 0) != 0:
            raise OSError("subreaper-registration-failed")
        stop = [False]
        signal.signal(signal.SIGTERM, lambda *_: stop.__setitem__(0, True))
        signal.signal(signal.SIGINT, lambda *_: stop.__setitem__(0, True))
        process = subprocess.Popen(
            command, stdin=subprocess.DEVNULL, close_fds=True, start_new_session=True
        )
        deadline = time.monotonic() + args.timeout
        while process.poll() is None:
            if stop[0] or time.monotonic() >= deadline:
                status["reason"] = "cancelled" if stop[0] else "timeout"
                break
            time.sleep(0.01)
        status["exit_code"] = process.poll()
        # Killing an ancestor reparents any detached grandchildren here. Iterate
        # until all adopted children have been killed AND reaped.
        cleanup_deadline = time.monotonic() + 5

        def children():
            owned = []
            for entry in Path("/proc").iterdir():
                if not entry.name.isdigit():
                    continue
                try:
                    fields = (entry / "stat").read_text().rsplit(")", 1)[1].split()
                    if int(fields[1]) == os.getpid():
                        owned.append(int(entry.name))
                except (OSError, ValueError, IndexError):
                    continue
            return owned

        while True:
            for pid in children():
                try:
                    os.kill(pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
            while True:
                try:
                    pid, _ = os.waitpid(-1, os.WNOHANG)
                    if pid == 0:
                        break
                except ChildProcessError:
                    break
            if not children():
                status["cleanup"] = True
                break
            if time.monotonic() >= cleanup_deadline:
                status["reason"] = "process-cleanup-incomplete"
                break
            time.sleep(0.01)
        if status["reason"] == "timeout":
            status["exit_code"] = 124
        elif status["reason"] or status["exit_code"] is None:
            status["exit_code"] = 125
    except (OSError, ValueError) as exc:
        status.update(reason=str(exc), exit_code=125)
    finally:
        os.write(args.status_fd, json.dumps(status, separators=(",", ":")).encode())
        os.close(args.status_fd)
    return status["exit_code"]


if __name__ == "__main__":
    raise SystemExit(main())
