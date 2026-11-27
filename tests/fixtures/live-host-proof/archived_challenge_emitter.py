"""Test-only challenge emitter from the last pre-retirement handshake.

The constants and four functions are copied verbatim from Git blob
d7e2a45e40f151fe81410fa0288c26259b290b5d (before e2110862f).
Only the historical --emit-challenge mode is available in this fixture.
"""

import json
import os
import secrets
import sys

CHALLENGE_SCHEMA = "sdd-hook-challenge/v1"
HOST_DENIAL_SCHEMA = "sdd-codex-host-denial/v1"
COPILOT_HOST_DENIAL_SCHEMA = "sdd-copilot-host-denial/v1"
CLAUDE_HOST_DENIAL_SCHEMA = "sdd-claude-host-denial/v1"
GEMINI_HOST_DENIAL_SCHEMA = "sdd-gemini-host-denial/v1"
CANARY_TARGET = "sdd/.hook-canary-sentinel"


def _codex_canary_patch(nonce):
    return (
        f"*** Begin Patch\n*** Add File: {CANARY_TARGET}\n"
        f"+sdd-hook-challenge:{nonce}\n*** End Patch"
    )


def _fresh_nonce():
    """32 hex characters (16 random bytes) -- fresh and single-use by
    construction; never derived from caller input, never persisted by this
    script (B4: nonce generation stays on the protected-script side, but
    the script itself holds no state across invocations)."""
    return secrets.token_hex(16)


def build_challenge():
    nonce = _fresh_nonce()
    templates = {"claude-code": {
        "tool_name": "Write", "tool_input": {
            "file_path": CANARY_TARGET, "content": "sdd-hook-challenge:" + nonce,
        },
    }}
    templates["codex-cli"] = {
        "tool_name": "apply_patch",
        "tool_input": {"patch": _codex_canary_patch(nonce)},
    }
    templates["copilot-cli"] = {
        "tool_name": "create",
        "tool_input": {"path": CANARY_TARGET, "file_text": "sdd-hook-challenge:" + nonce},
    }
    templates["gemini-cli"] = {
        "tool_name": "write_file",
        "tool_input": {"file_path": CANARY_TARGET, "content": "sdd-hook-challenge:" + nonce},
    }
    return {
        "schema": CHALLENGE_SCHEMA,
        "nonce": nonce,
        "canary_target": CANARY_TARGET,
        "tool_call_template": templates,
        "tool_call_alternatives": {"copilot-cli": [{
            "tool_name": "apply_patch", "tool_input": _codex_canary_patch(nonce),
        }]},
        "recorded_result_template": {"claude-code": {
            "schema": CLAUDE_HOST_DENIAL_SCHEMA, "runtime": "claude-code",
            "nonce": nonce, "executed": False, "raw_request": None, "raw_result": None,
        }, "codex-cli": {
            "schema": HOST_DENIAL_SCHEMA, "runtime": "codex-cli",
            "nonce": nonce, "executed": False, "raw_result": None,
        }, "copilot-cli": {
            "schema": COPILOT_HOST_DENIAL_SCHEMA, "runtime": "copilot-cli",
            "nonce": nonce, "executed": False, "raw_events": [],
        }, "gemini-cli": {
            "schema": GEMINI_HOST_DENIAL_SCHEMA, "runtime": "gemini-cli",
            "nonce": nonce, "executed": False, "raw_request": None, "raw_result": None,
        }},
        "capture_instructions": {"claude-code": (
            "Replace raw_request and raw_result with the verbatim native tool_use and matching tool_result "
            "objects for your one Write attempt. Preserve their real id/tool_use_id and exact content; "
            "the Write content must carry this challenge nonce. Keep executed:false when the hook blocks the Write; "
            "executed means the file was actually written, not merely attempted. Never infer or invent a numeric exit code "
            "or tool ID from prose. If the host does not expose these native objects, capture them from "
            "this session's own host event stream before verification; unavailable capture is not HOOK_ACTIVE."
        ), "codex-cli": (
            "Replace raw_result with the verbatim host denial from your own nonce-bound canary attempt. "
            "Keep executed:false only when the write did not execute. Persist this JSON with native apply_patch "
            "as a new file under an unprotected evidence directory such as reports/bootstrap/. JSON-escape "
            "the denial without changing its decoded bytes; the canary patch is string data, not patch headers. "
            "Do not embed the protected-path denial in a shell heredoc: the shell guard may reject it. "
            "Run --verify-response separately using only the evidence file path. Never infer hook metadata, "
            "fabricate a denial, encode a shell bypass, or weaken the guard. Missing capture must stop."
        ), "copilot-cli": (
            "Select the template or alternative exposed by this host. Replace raw_events with the verbatim "
            "tool.execution_start and matching tool.execution_complete objects from that one native dispatch. "
            "Preserve the actual model fields; Auto evidence does not establish a fixed-model run. "
            "An empty pair, unavailable tool, malformed-payload denial, or model prose is not activation evidence."
        ), "gemini-cli": (
            "Attempt the write_file call against sdd/.hook-canary-sentinel with content sdd-hook-challenge:<nonce>. "
            "Replace raw_request with the verbatim tool_name/tool_input object and raw_result with the verbatim "
            "BeforeTool hook decision object ({decision: 'deny', reason: ...}). Keep executed:false only when the "
            "file was not written. A malformed-payload refusal, allow decision, or model prose is not activation evidence."
        )},
    }


def run_emit_challenge():
    sentinel_path = CANARY_TARGET
    # Read-only existence check ONLY (never a write, B4). lexists (not
    # exists) so a dangling symlink still counts as "present" without this
    # script ever following it to decide presence -- the sentinel is
    # documented as path-existence-agnostic (infra-spec.md).
    if os.path.lexists(sentinel_path):
        print(
            "check-hook-activation-handshake: STALE_SENTINEL_DETECTED: "
            f"{sentinel_path!r} already exists at the start of this "
            "challenge -- a previous invocation may have crashed before "
            "its cleanup completed, or that cleanup was itself denied "
            "(the create-to-delete race); this script never removes it "
            "(B4: no write attempt is ever made from here), the CALLING "
            "SKILL is responsible for one cleanup attempt against it "
            "before trusting this new challenge's own resolution "
            "(REQ-010's Stale-start contract) -- a fresh challenge is "
            "still emitted below regardless",
            file=sys.stderr,
        )
    print(json.dumps(build_challenge(), indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    if sys.argv[1:] != ["--emit-challenge"]:
        raise SystemExit("expected --emit-challenge")
    raise SystemExit(run_emit_challenge())
