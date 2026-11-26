"""Exercise real installer and checker entry points against an isolated Codex home."""

import json
import os
from pathlib import Path
import subprocess


def check_registration_lifecycle(repo, base, runtime, checker_command):
    base = base.resolve()
    root, home, bin_dir = base / "install", base / "home", base / "bin"
    home.mkdir(parents=True)
    bin_dir.mkdir()
    config = home / "config.toml"
    initial = b"# user-owned setting\n"
    config.write_bytes(initial)
    env = dict(os.environ, HOME=str(home), SDD_CODEX_HOME=str(home),
               PATH=str(bin_dir) + os.pathsep + os.environ["PATH"])
    for name in ("codex", "node"):
        if os.name == "nt" and runtime == "ps1":
            script = bin_dir / (name + ".cmd")
            body = "@echo off\n"
            body += ('if "%1" == "--version" echo v26.13.0\n' if name == "node" else
                     'if defined SDD_FIXTURE_REGISTRATION_FAILURE exit /b 1\n')
            body += "exit /b 0\n"
        else:
            script = bin_dir / name
            body = "#!/bin/sh\n"
            body += ('[ "$1" != --version ] || echo v26.13.0\n' if name == "node" else
                     '[ -z "$SDD_FIXTURE_REGISTRATION_FAILURE" ] || exit 1\n')
            body += "exit 0\n"
        script.write_text(body)
        script.chmod(0o755)

    def install(target, selection=None, *, failure=None):
        if runtime == "sh":
            command = ["bash", str(repo / "install.sh"), "--source-directory", str(repo),
                       "--install-root", str(root), "--target", target]
            if selection:
                command.extend(["--mcp", selection])
        else:
            command = ["pwsh", "-NoProfile", "-File", str(repo / "install.ps1"),
                       "-SourceDirectory", str(repo), "-InstallRoot", str(root), "-Target", target]
            if isinstance(selection, tuple):
                # -File cannot bind a string array from separate native arguments.
                launcher = base / "select.ps1"
                launcher.write_text("& $args[0] -SourceDirectory $args[1] -InstallRoot $args[2] -Target $args[3] -Mcp $args[4..($args.Count-1)]")
                command = ["pwsh", "-NoProfile", "-File", str(launcher), str(repo / "install.ps1"),
                           str(repo), str(root), target, *selection]
            elif selection:
                command.extend(["-Mcp", selection])
        completed = subprocess.run(command, env=env, cwd=repo, capture_output=True, text=True)
        assert (completed.returncode != 0) == bool(failure), (command, completed.stderr)
        if failure:
            assert failure in completed.stderr, (command, completed.stderr)

    def check(label, expected):
        completed = subprocess.run(checker_command(root), env=env, cwd=repo, capture_output=True, text=True)
        report = json.loads(completed.stdout)
        rows = [(row["change_type"], row["installed_ref"]) for row in report["diverged"]]
        assert rows == expected, (label, rows)
        assert completed.returncode == bool(expected), (label, completed.returncode)
        assert report["state"] == ("installed_drifted" if expected else "installed_synced")
        print(f"ok Codex registration {label}")

    primary, secondary = "sdd-forge-mcp", "ci-mcp"
    receipt = root / ".sdd-codex-mcp-registration"
    removed = [("removed", "$SDD_CODEX_HOME/config.toml#" + primary)]
    bad_receipt = [("modified", receipt.name)]
    if os.name == "posix":
        lock = root.with_name(root.name + ".sdd-install.lock")
        lock.mkdir()
        env["SDD_INSTALL_LOCK_TIMEOUT"] = "0"
        env["SDD_INSTALL_LOCK_STALE"] = "60"
        install("FilesOnly", failure="another sdd-forge install")
        assert lock.is_dir() and not root.exists()
        os.utime(lock, (1, 1))
        (lock / "pid").write_text(str(os.getpid()) + "\n")
        os.utime(lock, (1, 1))
        install("FilesOnly", failure="another sdd-forge install")
        assert (lock / "pid").read_text().strip() == str(os.getpid())
        (lock / "pid").unlink()
        os.utime(lock, (1, 1))
        install("Codex")
        assert not lock.exists()
        env.pop("SDD_INSTALL_LOCK_TIMEOUT")
        env.pop("SDD_INSTALL_LOCK_STALE")
    else:
        install("Codex")
    check("default CLI-only", [])
    receipt.unlink()  # A pre-migration install had no selection record.
    check("legacy infers primary", removed)
    install("FilesOnly", secondary)
    check("legacy untouched host keeps previous expectation", removed)
    install("Codex")
    check("legacy targeted migration", [])
    install("Codex", secondary)
    check("secondary only, local primary CLI still placed", [])
    assert (root / "mcp" / primary / "dist" / "index.js").is_file()
    before = receipt.read_bytes(), config.read_bytes()
    install("FilesOnly")
    assert (receipt.read_bytes(), config.read_bytes()) == before
    assert (root / "mcp" / secondary / "dist" / "index.js").read_bytes() == (
        repo / "mcp" / secondary / "dist" / "index.js").read_bytes()
    check("non-target keeps secondary registration runnable", [])
    relative = Path("mcp") / secondary / "dist" / "index.js"
    (root / relative).unlink()
    check("registered runtime removed", [("added", relative.as_posix())])
    install("FilesOnly")
    check("registered runtime repaired from release", [])
    install("Codex")
    check("default prunes secondary", [])
    install("Codex", primary)
    check("explicit primary", [])
    opt_in = config.read_bytes()
    install("Codex")
    assert config.read_bytes() == opt_in
    check("default retains registered primary", [])
    before = receipt.read_bytes()
    install("FilesOnly", secondary)
    assert (receipt.read_bytes(), config.read_bytes()) == (before, opt_in)
    check("non-target retains registration", [])
    config.write_bytes(initial)
    check("deleted registration after opt-in", removed)
    install("Codex")
    check("default reinstall does not bless removal", removed)
    env["SDD_FIXTURE_REGISTRATION_FAILURE"] = "1"
    install("Codex", primary, failure="marketplace")
    env.pop("SDD_FIXTURE_REGISTRATION_FAILURE")
    check("failed registration stays pending", bad_receipt)
    install("Codex", primary)
    check("successful retry", [])
    # Historical PowerShell accepted -Mcp with mixed case and preserved that
    # spelling in its payload and all five managed TOML lines.
    receipt.unlink()
    old = primary.upper()
    original = config.read_bytes().replace(primary.encode(), old.encode())
    config.write_bytes(original)
    payload = root / "mcp" / primary
    alternate = payload.with_name("old-payload")
    payload.rename(alternate)
    alternate.rename(payload.with_name(old))
    check("mixed-case legacy", [])
    install("FilesOnly")
    assert config.read_bytes() == original
    check("mixed-case untouched host retains old contract", [])
    install("Codex")
    assert config.read_bytes() == original
    check("default retains legacy mixed-case primary", [])
    install("Codex", (primary, "CI-MCP") if runtime == "ps1" else primary)
    current = config.read_bytes()
    assert current.count(f"[mcp_servers.{primary}]".encode()) == 1 and old.encode() not in current
    if runtime == "ps1":
        assert current.count(b"[mcp_servers.ci-mcp]") == 1 and b"CI-MCP" not in current
    check("explicit registration uses canonical names", [])
    receipt.write_bytes(b"ready codex-mcp/v1 UNKNOWN\n")
    check("invalid receipt", [("removed", receipt.name)])
    install("FilesOnly", failure="Invalid Codex MCP registration receipt")
    assert receipt.read_bytes() == b"ready codex-mcp/v1 UNKNOWN\n"
