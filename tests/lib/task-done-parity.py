"""Use a valid, digest-bound evidence bundle as the control for report casing/path changes."""
import hashlib
import json
import runpy
import subprocess
import sys
import tempfile
from pathlib import Path

FIXTURE = runpy.run_path(str(Path(__file__).resolve().parents[1] / "check-evidence-bundle-parity.tests.py"))["Fixture"]


def main():
    with tempfile.TemporaryDirectory() as parent:
        fx = FIXTURE(parent)
        spec = fx.root / "specs/example"
        qa = fx.root / "quality[x]"
        verification = spec / "verification"
        for folder in (qa, verification, fx.root / "qualityx"):
            folder.mkdir(parents=True)
        (spec / "tasks.md").write_text("## T-1\nApproval: Approved\nStatus: Done\n", encoding="utf-8")
        fx.contract_name = "specs/example/verification/T-1.contract.json"
        fx.bundle_name = "specs/example/verification/T-1.evidence.json"
        fx.report_name = "quality[x]/report[x].md"
        other = fx.root / "qualityx/reportx.md"
        other.write_text("Task ID: T-1\nFeature: foo\nVERDICT: PASS\n", encoding="utf-8")
        for task, verdict, expected in [
            ("T-1", "VERDICT: PASS", 0), ("T-1", "verdict: pass", 1),
            ("T-1", "VERDICT: pass", 1), ("T-1", "verdict: PASS", 1),
            ("t-1", "VERDICT: PASS", 1), ("T-1", "VERDICT: FAIL", 1),
        ]:
            bundle_path = fx.write()
            report = fx.root / fx.report_name
            report.write_text(f"Task ID: {task}\nFeature: foo\n{verdict}\n", encoding="utf-8")
            bundle = json.loads(bundle_path.read_text(encoding="utf-8"))
            artifact = next(entry for entry in bundle["artifacts"] if entry["path"] == fx.report_name)
            artifact["sha256"] = hashlib.sha256(report.read_bytes()).hexdigest()
            bundle_path.write_text(json.dumps(bundle), encoding="utf-8")
            for command in (["sh", sys.argv[1]], ["pwsh", "-NoProfile", "-File", sys.argv[2]]):
                result = subprocess.run([*command, str(spec / "tasks.md"), str(qa), str(qa), str(fx.root)],
                                        capture_output=True, text=True, timeout=30)
                assert result.returncode == expected, (command, task, verdict, result.stdout, result.stderr)
    print("Done case controls and literal report paths passed with Bash and PowerShell.")


if __name__ == "__main__":
    main()
