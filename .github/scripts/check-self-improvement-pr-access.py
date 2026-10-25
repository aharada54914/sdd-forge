#!/usr/bin/env python3
"""Read-only early check of the exact credential the weekly PR session will use.

Successful listing proves read access only. GitHub does not expose a general
fine-grained-token write-permission introspection API; actual PR creation must
still succeed before the workflow can recover.
"""
import json
import os
from pathlib import Path
import re
import subprocess


def check_access(repository, token):
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*/[A-Za-z0-9][A-Za-z0-9_.-]*", repository or ""):
        return "invalid-repository"
    if not token:
        return "missing-token"
    try:
        result = subprocess.run(
            ["gh", "api", "--method", "GET",
             f"repos/{repository}/pulls?state=open&per_page=1"],
            capture_output=True, text=True, timeout=30,
            env={**os.environ, "GH_TOKEN": token},
        )
    except subprocess.TimeoutExpired:
        return "timeout"
    except (OSError, UnicodeError):
        return "client-failed"
    if result.returncode:
        # Remote diagnostics may contain private content; emit only fixed codes.
        for status in (401, 403, 404, 429):
            if re.search(rf"\(HTTP {status}\)", result.stderr):
                return f"http-{status}"
        return "request-failed"
    try:
        if not isinstance(json.loads(result.stdout), list):
            return "invalid-response"
    except (ValueError, TypeError):
        return "invalid-response"
    return None


def main():
    failure = check_access(os.environ.get("GITHUB_REPOSITORY"), os.environ.get("GH_TOKEN"))
    output = os.environ.get("GITHUB_OUTPUT")
    if failure:
        reason = (
            "Weekly PR credential preflight failed (" + failure + "). "
            "Check SDD_SESSION_PR_TOKEN expiry, repository selection and Pull requests permissions. "
            "The audit did not start; no token value or remote response is logged."
        )
        if output:
            with Path(output).open("a", encoding="utf-8") as stream:
                stream.write("failure_reason=" + reason + "\n")
        print("::error::" + reason)
        return 1
    if output:
        with Path(output).open("a", encoding="utf-8") as stream:
            stream.write("read_access=verified\n")
    print("Weekly PR credential can list pull requests; PR write permission remains unverified.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
