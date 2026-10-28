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
    parser.add_argument("--inherit-stdin", action="store_true")
    parser.add_argument("--output-limit-bytes", type=int)
    parser.add_argument('--sealed-input-fd', type=int, action='append', default=[])
    parser.add_argument("argv", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if not math.isfinite(args.timeout) or not 0 < args.timeout <= 3600:
        parser.error("--timeout must be finite and between 0 and 3600 seconds")
    if args.output_limit_bytes is not None and not 0 < args.output_limit_bytes <= 32 * 1024 * 1024:
        parser.error("--output-limit-bytes must be between 1 and 33554432")
    if not Path("/proc/self/stat").is_file():
        parser.error("process ownership requires Linux procfs")
    command = args.argv[1:] if args.argv[:1] == ["--"] else args.argv
    status = {"cleanup": False, "reason": None, "exit_code": None}
    try:
        if sys.platform != "linux" or not command:
            raise ValueError("process-ownership-backend-unavailable")
        if args.sealed_input_fd:
            import fcntl
            # Linux UAPI constants; some Python builds omit their symbolic exports.
            required = 0x0f  # WRITE | SHRINK | GROW | SEAL
            if (len(args.sealed_input_fd) > 8192 or len(set(args.sealed_input_fd)) != len(args.sealed_input_fd)
                    or any(fd < 3 or fd == args.status_fd or fcntl.fcntl(fd, 1034) & required != required
                           for fd in args.sealed_input_fd)):
                raise ValueError('unsealed-input-fd')
        libc = ctypes.CDLL(None, use_errno=True)
        if libc.prctl(36, 1, 0, 0, 0) != 0:
            raise OSError("subreaper-registration-failed")
        stop = [False]
        signal.signal(signal.SIGTERM, lambda *_: stop.__setitem__(0, True))
        signal.signal(signal.SIGINT, lambda *_: stop.__setitem__(0, True))
        # A caller's cancellation must not strand its supervised descendants.
        parent = os.getppid()
        if libc.prctl(1, signal.SIGTERM, 0, 0, 0) != 0:
            raise OSError("parent-death-registration-failed")
        if parent == 1 or os.getppid() != parent:
            raise ValueError("cancelled")
        if args.output_limit_bytes is not None:
            import resource
            limit = min([args.output_limit_bytes] + [value for value in resource.getrlimit(resource.RLIMIT_FSIZE) if value >= 0])
            resource.setrlimit(resource.RLIMIT_FSIZE, (limit, limit))
        process = subprocess.Popen(
            command, stdin=None if args.inherit_stdin else subprocess.DEVNULL,
            close_fds=True, start_new_session=True, pass_fds=tuple(args.sealed_input_fd)
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
