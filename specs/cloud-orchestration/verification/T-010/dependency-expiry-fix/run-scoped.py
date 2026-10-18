"""Offline scoped test runner; guard Python CLI children as well as the parent."""

from __future__ import annotations

import os
from pathlib import Path
import runpy
import subprocess
import tempfile
import shlex
import shutil
import sys
import urllib.request
from unittest.mock import patch

GUARD = "from unittest.mock import patch; patch('urllib.request.OpenerDirector.open',side_effect=AssertionError('T010_OFFLINE_SENTINEL')).start(); "


def main() -> None:
    original = subprocess.Popen
    temporary = tempfile.TemporaryDirectory(prefix="t010-offline-cli-")
    shim_root = Path(temporary.name).resolve()
    child = shim_root / "child.py"
    child.write_text(
        GUARD + "\nimport runpy,sys\n"
        "args=sys.argv[1:]; isolated='-I' in args\n"
        "while args and args[0] in ('-I','-B','-u','-s','-S','-E'): args.pop(0)\n"
        "if args == ['--version'] or args == ['-V']:\n"
        " print('Python '+sys.version.split()[0])\n"
        "elif args[0] == '-c':\n"
        " sys.argv=['-c',*args[2:]]; exec(compile(args[1],'<offline-shell-child>','exec'))\n"
        "elif args[0] == '-m':\n"
        " sys.argv=args[1:]; runpy.run_module(args[1],run_name='__main__')\n"
        "elif args[0] == '-':\n"
        " sys.argv=args; exec(compile(sys.stdin.read(),'<stdin>','exec'))\n"
        "else:\n"
        " from pathlib import Path\n"
        " if not isolated: sys.path.insert(0,str(Path(args[0]).resolve().parent))\n"
        " sys.argv=args; runpy.run_path(args[0],run_name='__main__')\n"
    )
    for name in ("python3", "python"):
        shim = shim_root / name
        shim.write_text(
            "#!/bin/sh\nexec " + shlex.quote(sys.executable)
            + " -I " + shlex.quote(str(child)) + ' "$@"\n'
        )
        shim.chmod(0o700)

    def guarded(args, *positional, **kwargs):
        if (
            isinstance(args, (list, tuple))
            and args
            and Path(str(args[0])).name.startswith("python")
        ):
            command = list(args)
            index = 1
            while index < len(command) and command[index] in (
                "-I",
                "-B",
                "-u",
                "-s",
                "-S",
                "-E",
            ):
                index += 1
            if index < len(command):
                if command[index] == "-c":
                    code = (
                        GUARD
                        + "exec(compile("
                        + repr(command[index + 1])
                        + ",'<guarded-child>','exec'))"
                    )
                    command[index + 1] = code
                elif command[index] == "-m":
                    module = command[index + 1]
                    command[index : index + 2] = [
                        "-c",
                        GUARD
                        + "import runpy,sys;sys.argv=sys.argv[1:];runpy.run_module("
                        + repr(module)
                        + ",run_name='__main__')",
                        module,
                    ]
                elif not command[index].startswith("-"):
                    command[index : index + 1] = [
                        "-c",
                        GUARD
                        + "import runpy,sys;from pathlib import Path;path=sys.argv.pop(1);sys.argv[0]=path;"
                        + ("sys.path.insert(0,str(Path(path).resolve().parent));" if "-I" not in command[1:index] else "")
                        + "runpy.run_path(path,run_name='__main__')",
                        command[index],
                    ]
                args = command
        if isinstance(args, (list, tuple)) and args and Path(str(args[0])).name in (
            "sh", "bash", "pwsh", "powershell"
        ):
            env = dict(kwargs.get("env") or os.environ)
            env["PATH"] = str(shim_root) + os.pathsep + env.get("PATH", os.defpath)
            kwargs["env"] = env
        return original(args, *positional, **kwargs)

    with (
        patch(
            "urllib.request.OpenerDirector.open",
            side_effect=AssertionError("T010_OFFLINE_SENTINEL"),
        ),
        patch.object(subprocess, "Popen", side_effect=guarded),
    ):
        try:
            urllib.request.OpenerDirector().open("https://invalid.example")
        except AssertionError as error:
            assert str(error) == "T010_OFFLINE_SENTINEL"
        else:
            raise AssertionError("parent network guard absent")
        result = subprocess.run(
            [
                sys.executable,
                "-I",
                "-c",
                "import urllib.request;urllib.request.urlopen('https://invalid.example')",
            ],
            env={"PATH": os.defpath},
            capture_output=True,
            text=True,
        )
        assert result.returncode != 0 and "T010_OFFLINE_SENTINEL" in result.stderr
        shell = subprocess.run(
            ["sh", "-c", "python3 -c \"import urllib.request;urllib.request.urlopen('https://invalid.example')\""],
            env={"PATH": os.defpath}, capture_output=True, text=True,
        )
        assert shell.returncode != 0 and "T010_OFFLINE_SENTINEL" in shell.stderr
        print("NETWORK_SENTINEL_PARENT_CHILD_SHELL_PASS", flush=True)
        powershell = shutil.which("pwsh")
        if powershell:
            ps = subprocess.run(
                [powershell, "-NoProfile", "-Command",
                 "python3 -c \"import urllib.request;urllib.request.urlopen('https://invalid.example')\"; exit $LASTEXITCODE"],
                capture_output=True, text=True,
            )
            assert ps.returncode != 0 and "T010_OFFLINE_SENTINEL" in ps.stderr
            print("NETWORK_SENTINEL_POWERSHELL_CHILD_PASS", flush=True)
        path = sys.argv.pop(1)
        sys.argv[0] = path
        try:
            runpy.run_path(path, run_name="__main__")
        finally:
            temporary.cleanup()


if __name__ == "__main__":
    main()
