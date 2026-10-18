"""Offline scoped test runner; guard Python CLI children as well as the parent."""

from __future__ import annotations

import os
from pathlib import Path
import runpy
import subprocess
import sys
import urllib.request
from unittest.mock import patch

GUARD = "from unittest.mock import patch; patch('urllib.request.OpenerDirector.open',side_effect=AssertionError('T010_OFFLINE_SENTINEL')).start(); "


def main() -> None:
    original = subprocess.Popen

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
                        + "import runpy,sys;path=sys.argv.pop(1);sys.argv[0]=path;runpy.run_path(path,run_name='__main__')",
                        command[index],
                    ]
                args = command
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
        print("NETWORK_SENTINEL_PARENT_CHILD_PASS", flush=True)
        path = sys.argv.pop(1)
        sys.argv[0] = path
        runpy.run_path(path, run_name="__main__")


if __name__ == "__main__":
    main()
