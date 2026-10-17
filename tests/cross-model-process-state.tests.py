#!/usr/bin/env python3
"""Check that timeout assertions distinguish running children from Linux zombies."""
from pathlib import Path
import shutil
import subprocess
import sys
import time
import unittest


ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(sys.platform == "linux", "Linux process states")
class ProcessStateTests(unittest.TestCase):
    def test_live_zombie_and_reaped_children(self):
        parent = subprocess.Popen(
            [sys.executable, "-c", "import os,sys; child=os.fork(); "
             "os._exit(0) if child == 0 else None; print(child,flush=True); "
             "sys.stdin.readline(); os.waitpid(child,0)"],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True,
        )
        try:
            child = int(parent.stdout.readline())
            for _ in range(100):
                if Path(f"/proc/{child}/stat").read_text().split(") ", 1)[1].startswith("Z "):
                    break
                time.sleep(0.01)
            else:
                self.fail("child did not enter zombie state")
            shell = (ROOT / "tests/cross-model.tests.sh").read_text()
            shell_helper = "process_is_dead() {" + shell.split("process_is_dead() {", 1)[1].split("\n}\n", 1)[0] + "\n}\n"
            powershell = (ROOT / "tests/cross-model.tests.ps1").read_text()
            ps_helper = "function Test-ProcessExited {" + powershell.split("function Test-ProcessExited {", 1)[1].split("\n}\n", 1)[0] + "\n}\n"
            commands = [("bash", lambda pid: ["bash", "-c", shell_helper + f"process_is_dead {pid}"])]
            if shutil.which("pwsh"):
                commands.append(("pwsh", lambda pid: ["pwsh", "-NoProfile", "-Command", ps_helper + f"if (Test-ProcessExited {pid}) {{ exit 0 }} else {{ exit 1 }}"]))
            for name, command in commands:
                with self.subTest(runtime=name, state="live"):
                    self.assertEqual(subprocess.run(command(parent.pid), timeout=15).returncode, 1)
                with self.subTest(runtime=name, state="zombie"):
                    self.assertEqual(subprocess.run(command(child), timeout=15).returncode, 0)
            parent.communicate("\n", timeout=5)
            for name, command in commands:
                with self.subTest(runtime=name, state="reaped"):
                    self.assertEqual(subprocess.run(command(child), timeout=15).returncode, 0)
        finally:
            if parent.poll() is None:
                parent.communicate("\n", timeout=5)


if __name__ == "__main__":
    unittest.main()
