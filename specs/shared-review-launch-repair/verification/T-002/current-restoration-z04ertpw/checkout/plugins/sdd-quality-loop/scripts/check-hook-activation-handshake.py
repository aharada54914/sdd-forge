#!/usr/bin/env python3
"""check-hook-activation-handshake (REQ-010, epic-189-a1-project-context T-008).

Redesigned host-canary challenge/response handshake (design.md "Hook-
activation handshake CLI contract", requirements.md REQ-010's "Redesigned
protocol"). A prior draft had this script perform its OWN child-process
file-write probe and inspect its own result -- closed as unable to observe
the property it claims to prove: `sdd-hook-guard.py` is invoked BY THE HOST
RUNTIME as a `PreToolUse` hook, intercepting a tool call the AGENT SESSION
itself proposes through its host's native tool-call surface. A subprocess
this script spawns via ordinary file I/O never reaches that dispatch, so
its own write "succeeding" or "failing" proves nothing about hook
installation.

This script therefore NEVER performs a write attempt itself (design
decision B4). It has exactly three modes:

  --emit-challenge
      Emits a fresh, single-use nonce plus a machine-readable challenge
      (schema `sdd-hook-challenge/v1`) naming the dedicated canary target
      `sdd/.hook-canary-sentinel` (never the live approval sidecars, B5)
      and a per-runtime tool-call template. The CALLING SKILL (out of this
      script's own scope except this one contract, REQ-009's migrated
      entry points) instructs the AGENT SESSION itself to attempt exactly
      that one tool call, once, and to record the RAW, verbatim result the
      host surfaces to a plain evidence file alongside the nonce.
      Stale-start contract: at the START of every invocation this script
      checks (read-only `os.path.lexists`, never a write, and never
      following a symlink to decide "existence") whether the canary target
      already exists. Its presence is reported as a `STALE_SENTINEL_DETECTED`
      diagnostic on stderr -- evidence of a PREVIOUS invocation's abnormal
      termination -- but a fresh challenge is still emitted regardless; the
      calling skill (not this script) is responsible for the actual
      cleanup attempt against a stale sentinel.
  --verify-response --nonce <nonce> --recorded-result <path>
      --runtime <claude-code|codex-cli|copilot-cli>
      Reads the caller-supplied (never written by this script) evidence
      file and applies a per-runtime documented expected-deny-signature
      check plus a nonce-match check (`STALE_CHALLENGE_REJECTED` on
      mismatch, replay defense). `HOOK_ACTIVE` (exit 0) ONLY when the
      runtime-specific deny signature is present AND the nonce matches;
      every other case -- no evidence, an unreadable/malformed evidence
      file, a nonce mismatch, a result showing the write executed, or a
      result this script's per-runtime signature table does not recognize
      -- reports `CAPABILITY_RUNTIME_UNAVAILABLE` (non-zero, fail-closed:
      the burden of proof is on demonstrating denial, never on
      demonstrating non-denial).
  --confirm-cleanup --nonce <nonce> --recorded-cleanup-result <path>
      Reads a caller-supplied cleanup-result evidence file (the calling
      skill's own recorded raw result of its delete/remove attempt against
      the now-created sentinel, made after a non-`HOOK_ACTIVE` verdict).
      Three documented outcomes (REQ-010's Sentinel cleanup contract):
      (a) the cleanup result shows the sentinel was successfully removed
      -- `SENTINEL_CLEANUP_CONFIRMED`, exit 0; (b) no cleanup-result
      evidence is recorded at all -- `SENTINEL_CLEANUP_UNCONFIRMED`
      (reason `NO_CLEANUP_RESULT`); (c) the cleanup's own delete attempt
      was itself denied (the create-to-delete race: the hook became active
      between the sentinel's creation and the cleanup attempt) --
      `SENTINEL_CLEANUP_UNCONFIRMED` (reason `CLEANUP_DENIED`). (b) and (c)
      never retroactively change the ORIGINAL `--verify-response`
      invocation's own `CAPABILITY_RUNTIME_UNAVAILABLE` verdict -- the two
      are independent, reported alongside each other (this script restates
      the standing `capability_status` in its own output document so a
      caller inspecting ONLY this command's output still sees both). This
      script never attempts a privileged/force-delete of a stuck sentinel;
      that would defeat the same guard-mediation premise the whole
      handshake relies on (a genuinely-stuck sentinel from a
      reactivated hook is a documented, rare condition the NEXT
      `--emit-challenge` invocation's stale-start report surfaces, and a
      human resolves out-of-band if it persists).

Recorded-result evidence schema (this script's own implementation-level
realization of requirements.md REQ-010's per-runtime prose description --
design.md fixes the CLI surface and the high-level signature description,
not the byte-level JSON field names; chosen to mirror `sdd-hook-guard.py`'s
own documented output shapes as closely as possible so a real evidence
file recorded from a live host, once Epic A8 wires real capture, needs no
translation layer):

  Every recorded-result / recorded-cleanup-result file is a JSON object
  with (at minimum) a top-level `"nonce"` string (compared verbatim
  against `--nonce`) and a top-level boolean `"executed"` (did the
  tool-call attempt actually run/succeed). `executed: true` ALWAYS
  short-circuits to `WRITE_EXECUTED` regardless of any other field --
  proof the write ran is proof the hook did not block it, full stop, never
  overridden by a contradictory denial claim elsewhere in the same file.
  When `executed: false`, each runtime additionally requires:

    claude-code:  `"guard_emit_mode": "exit"` and a non-zero integer
                  `"exit_code"` -- `sdd-hook-guard.py`'s own `--emit exit`
                  deny convention (reason on stderr, exit 2), surfaced
                  through the host's own tool-call-denial reporting (a
                  non-zero exit from a Claude Code PreToolUse hook blocks
                  the tool call; this check accepts ANY non-zero code,
                  matching what the host itself observes -- "the hook
                  exited non-zero" -- not a specific numeric value).
    copilot-cli:  `"permissionDecision": "deny"` -- `sdd-hook-guard.py`'s
                  own `--emit copilot` JSON shape. An absent or
                  affirmatively-`"allow"` `permissionDecision` is the
                  well-known "Copilot subagent hook often does not fire"
                  case (decision doc Section 7 v2) and correctly falls
                  through to `UNRECOGNIZED_RESULT`, never a special case.
    codex-cli:    `"plugin_hooks_enabled": true` AND
                  `"denied_by_plugin_hooks": true`. An unset/false
                  `plugin_hooks_enabled` collapses into
                  `CAPABILITY_RUNTIME_UNAVAILABLE` (reason
                  `PLUGIN_HOOKS_DISABLED`) regardless of
                  `denied_by_plugin_hooks` -- a guard that was never
                  invoked (feature flag unset) cannot have produced a
                  denial signature, matching REQ-010's explicit
                  "indistinguishable from, and correctly collapses into,
                  'hook not active'" text.

  The recorded-cleanup-result file uses the SAME `"nonce"`/`"executed"`
  envelope alone (no runtime-specific sub-fields; the literal
  `--confirm-cleanup` CLI signature design.md fixes takes no `--runtime`
  flag) -- `executed: true` means the delete succeeded, `executed: false`
  means it was denied.

Scope (design.md Test Strategy item 9, Non-goals; tasks.md T-008 Out of
Scope): this is A1's OWN footgun-guard Done condition -- a FIXTURE-
SIMULATED proof of the challenge/response verify logic's correctness
against synthetic, caller-supplied evidence. It does not, and cannot,
exercise a live host's actual tool-call dispatch; that live-host,
cross-runtime observation is explicitly OUT of this task's scope and is
instead Epic A8's own mandatory Done condition. Wiring this handshake into
REQ-009's five entry points is T-011/T-012's own scope, not this script's.
"""
import argparse
import json
import os
import secrets
import sys

EXIT_USAGE_ERROR = 2

CATEGORY_EXIT_CODES = {
    "NO_RECORDED_RESULT": 60,
    "RECORDED_RESULT_UNREADABLE": 61,
    "STALE_CHALLENGE_REJECTED": 62,
    "WRITE_EXECUTED": 63,
    "UNRECOGNIZED_RESULT": 64,
    "PLUGIN_HOOKS_DISABLED": 65,
    "NO_CLEANUP_RESULT": 70,
    "CLEANUP_RESULT_UNREADABLE": 71,
    "CLEANUP_DENIED": 72,
    "INTERNAL_ERROR": 90,
}

CHALLENGE_SCHEMA = "sdd-hook-challenge/v1"
VERIFY_RESULT_SCHEMA = "sdd-hook-verify-result/v1"
CLEANUP_RESULT_SCHEMA = "sdd-hook-cleanup-result/v1"

# Dedicated canary target -- NEVER the live approval sidecars (B5). Fixed,
# never caller-overridable, CWD-relative like every sibling script's
# `sdd/...` convention (these tools are invoked from the project root).
CANARY_TARGET = "sdd/.hook-canary-sentinel"

RUNTIMES = ("claude-code", "codex-cli", "copilot-cli")

# Per-runtime example tool-call the AGENT SESSION itself is instructed to
# attempt (illustrative -- the exact bytes are not pinned by any AC; the
# calling skill, REQ-009's own scope, is free to adapt these). Claude
# Code/Copilot CLI share the same native Write-tool shape (requirements.md);
# Codex CLI uses the equivalent apply_patch envelope, mirroring
# `sdd-hook-guard.py`'s own AC-023 matrix row 12 example shape.
TOOL_CALL_TEMPLATES = {
    "claude-code": {
        "tool_name": "Write",
        "tool_input": {"file_path": CANARY_TARGET, "content": ""},
    },
    "copilot-cli": {
        "tool_name": "Write",
        "tool_input": {"file_path": CANARY_TARGET, "content": ""},
    },
    "codex-cli": {
        "tool_name": "apply_patch",
        "tool_input": {
            "patch": "*** Begin Patch\n*** Add File: {}\n+\n*** End Patch\n".format(CANARY_TARGET),
        },
    },
}


class HookHandshakeError(Exception):
    """A documented, category-specific refusal -- never an uncaught
    traceback (T-002/T-003/T-005/T-006/T-007 quality-gate lessons)."""

    def __init__(self, category, message):
        super().__init__(message)
        self.category = category
        self.message = message


# ---------------------------------------------------------------------------
# --emit-challenge
# ---------------------------------------------------------------------------


def _fresh_nonce():
    """32 hex characters (16 random bytes) -- fresh and single-use by
    construction; never derived from caller input, never persisted by this
    script (B4: nonce generation stays on the protected-script side, but
    the script itself holds no state across invocations)."""
    return secrets.token_hex(16)


def build_challenge():
    return {
        "schema": CHALLENGE_SCHEMA,
        "nonce": _fresh_nonce(),
        "canary_target": CANARY_TARGET,
        "tool_call_template": TOOL_CALL_TEMPLATES,
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


# ---------------------------------------------------------------------------
# Evidence loading (shared by --verify-response / --confirm-cleanup).
# ---------------------------------------------------------------------------


def _load_json_object(path, missing_category, unreadable_category):
    if not os.path.isfile(path):
        raise HookHandshakeError(missing_category, f"no evidence file at {path!r}")
    try:
        with open(path, "r", encoding="utf-8") as f:
            raw = f.read()
    except (OSError, UnicodeDecodeError) as exc:
        raise HookHandshakeError(unreadable_category, f"cannot read {path!r}: {exc}") from exc
    try:
        obj = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise HookHandshakeError(unreadable_category, f"{path!r} is not valid JSON: {exc}") from exc
    if not isinstance(obj, dict):
        raise HookHandshakeError(unreadable_category, f"{path!r} must be a JSON object at the top level")
    return obj


def _check_nonce(obj, expected_nonce):
    recorded_nonce = obj.get("nonce")
    if not isinstance(recorded_nonce, str) or not recorded_nonce or recorded_nonce != expected_nonce:
        raise HookHandshakeError(
            "STALE_CHALLENGE_REJECTED",
            "recorded evidence's own 'nonce' field is missing, empty, or "
            f"does not match this invocation's --nonce (expected "
            f"{expected_nonce!r}, got {recorded_nonce!r}) -- rejected as "
            "stale/replayed evidence, never trusted as a fresh denial",
        )


def _check_executed_field(obj):
    executed = obj.get("executed")
    if not isinstance(executed, bool):
        raise HookHandshakeError(
            "UNRECOGNIZED_RESULT",
            "recorded evidence has no boolean 'executed' field -- cannot "
            "determine whether the canary tool-call attempt actually ran",
        )
    return executed


# ---------------------------------------------------------------------------
# --verify-response: per-runtime expected-deny-signature checks.
# ---------------------------------------------------------------------------


def _verify_claude_code(obj):
    if _check_executed_field(obj):
        raise HookHandshakeError(
            "WRITE_EXECUTED",
            "recorded evidence shows the canary write EXECUTED "
            "(executed: true) -- no denial was observed",
        )
    emit_mode = obj.get("guard_emit_mode")
    exit_code = obj.get("exit_code")
    exit_code_ok = isinstance(exit_code, int) and not isinstance(exit_code, bool) and exit_code != 0
    if emit_mode != "exit" or not exit_code_ok:
        raise HookHandshakeError(
            "UNRECOGNIZED_RESULT",
            "claude-code evidence does not carry the guard's documented "
            "--emit exit deny signature (guard_emit_mode: 'exit' plus a "
            f"non-zero integer exit_code); got guard_emit_mode={emit_mode!r} "
            f"exit_code={exit_code!r}",
        )


def _verify_copilot_cli(obj):
    if _check_executed_field(obj):
        raise HookHandshakeError(
            "WRITE_EXECUTED",
            "recorded evidence shows the canary write EXECUTED "
            "(executed: true) -- no denial was observed",
        )
    decision = obj.get("permissionDecision")
    if decision != "deny":
        raise HookHandshakeError(
            "UNRECOGNIZED_RESULT",
            "copilot-cli evidence does not carry the guard's documented "
            "--emit copilot deny signature ({'permissionDecision': "
            f"'deny', ...}}); got permissionDecision={decision!r} (an "
            "absent or affirmatively-'allow' permissionDecision is the "
            "well-known 'Copilot subagent hook often does not fire' case, "
            "correctly treated as non-HOOK_ACTIVE, never a special case)",
        )


def _verify_codex_cli(obj):
    if _check_executed_field(obj):
        raise HookHandshakeError(
            "WRITE_EXECUTED",
            "recorded evidence shows the canary write EXECUTED "
            "(executed: true) -- no denial was observed",
        )
    if obj.get("plugin_hooks_enabled") is not True:
        raise HookHandshakeError(
            "PLUGIN_HOOKS_DISABLED",
            "codex-cli evidence's 'plugin_hooks_enabled' is not true -- an "
            "unset/false plugin_hooks feature flag means the guard was "
            "never invoked at all, so no denial signature can appear; "
            "this correctly collapses into hook-not-active rather than "
            "being treated as ambiguous",
        )
    if obj.get("denied_by_plugin_hooks") is not True:
        raise HookHandshakeError(
            "UNRECOGNIZED_RESULT",
            "codex-cli evidence has plugin_hooks_enabled: true but no "
            "'denied_by_plugin_hooks: true' signature; got "
            f"denied_by_plugin_hooks={obj.get('denied_by_plugin_hooks')!r}",
        )


RUNTIME_VERIFIERS = {
    "claude-code": _verify_claude_code,
    "codex-cli": _verify_codex_cli,
    "copilot-cli": _verify_copilot_cli,
}


def run_verify_response(nonce, recorded_result_path, runtime):
    """Raises HookHandshakeError for every non-HOOK_ACTIVE outcome; returns
    normally (no return value) ONLY when HOOK_ACTIVE is proven."""
    obj = _load_json_object(recorded_result_path, "NO_RECORDED_RESULT", "RECORDED_RESULT_UNREADABLE")
    _check_nonce(obj, nonce)
    RUNTIME_VERIFIERS[runtime](obj)


def _print_verify_result(status, runtime, nonce, reason=None):
    doc = {"schema": VERIFY_RESULT_SCHEMA, "status": status, "runtime": runtime, "nonce": nonce}
    if reason is not None:
        doc["reason"] = reason
    print(json.dumps(doc, indent=2, sort_keys=True))


def do_verify_response(nonce, recorded_result_path, runtime):
    try:
        run_verify_response(nonce, recorded_result_path, runtime)
    except HookHandshakeError as exc:
        _print_verify_result("CAPABILITY_RUNTIME_UNAVAILABLE", runtime, nonce, reason=exc.category)
        print(
            f"check-hook-activation-handshake: CAPABILITY_RUNTIME_UNAVAILABLE: "
            f"{exc.category}: {exc.message}",
            file=sys.stderr,
        )
        return CATEGORY_EXIT_CODES.get(exc.category, 1)
    _print_verify_result("HOOK_ACTIVE", runtime, nonce)
    return 0


# ---------------------------------------------------------------------------
# --confirm-cleanup
# ---------------------------------------------------------------------------


def run_confirm_cleanup(nonce, recorded_cleanup_result_path):
    """Raises HookHandshakeError for every non-CONFIRMED outcome; returns
    normally ONLY when the cleanup delete is confirmed successful."""
    obj = _load_json_object(recorded_cleanup_result_path, "NO_CLEANUP_RESULT", "CLEANUP_RESULT_UNREADABLE")
    _check_nonce(obj, nonce)
    executed = obj.get("executed")
    if not isinstance(executed, bool):
        raise HookHandshakeError(
            "CLEANUP_RESULT_UNREADABLE",
            "recorded cleanup result has no boolean 'executed' field",
        )
    if executed is not True:
        raise HookHandshakeError(
            "CLEANUP_DENIED",
            "recorded cleanup result shows the delete attempt did NOT "
            "succeed (executed: false) -- the create-to-delete race (the "
            "hook became active between the sentinel's creation and the "
            "cleanup attempt), never a privileged force-delete",
        )


def do_confirm_cleanup(nonce, recorded_cleanup_result_path):
    # capability_status is ALWAYS CAPABILITY_RUNTIME_UNAVAILABLE here: this
    # command is only ever reached from the non-HOOK_ACTIVE/write-executed
    # branch, and a later cleanup outcome never retroactively changes that
    # original probe's own verdict (REQ-010's Sentinel cleanup contract,
    # "independent verdicts").
    try:
        run_confirm_cleanup(nonce, recorded_cleanup_result_path)
    except HookHandshakeError as exc:
        doc = {
            "schema": CLEANUP_RESULT_SCHEMA,
            "capability_status": "CAPABILITY_RUNTIME_UNAVAILABLE",
            "cleanup_status": "SENTINEL_CLEANUP_UNCONFIRMED",
            "nonce": nonce,
            "reason": exc.category,
        }
        print(json.dumps(doc, indent=2, sort_keys=True))
        print(
            f"check-hook-activation-handshake: SENTINEL_CLEANUP_UNCONFIRMED: "
            f"{exc.category}: {exc.message}",
            file=sys.stderr,
        )
        return CATEGORY_EXIT_CODES.get(exc.category, 1)
    doc = {
        "schema": CLEANUP_RESULT_SCHEMA,
        "capability_status": "CAPABILITY_RUNTIME_UNAVAILABLE",
        "cleanup_status": "SENTINEL_CLEANUP_CONFIRMED",
        "nonce": nonce,
    }
    print(json.dumps(doc, indent=2, sort_keys=True))
    return 0


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

_EXIT_CODE_HELP = "\n".join(
    f"  {code:>3}  {name}" for name, code in sorted(CATEGORY_EXIT_CODES.items(), key=lambda kv: kv[1])
)


def build_arg_parser():
    parser = argparse.ArgumentParser(
        prog="check-hook-activation-handshake.py",
        description=(
            "Host-canary challenge/response hook-activation handshake "
            "(REQ-010). Never itself performs a write attempt -- "
            "--emit-challenge issues a nonce/canary-target challenge for "
            "the AGENT SESSION's own tool-call attempt; --verify-response "
            "checks a caller-recorded raw result against the runtime's "
            "documented expected-deny signature; --confirm-cleanup checks "
            "a caller-recorded cleanup-delete result."
        ),
        epilog="Exit codes (stable, one per outcome category):\n"
        "    0  success (HOOK_ACTIVE / SENTINEL_CLEANUP_CONFIRMED / "
        "challenge emitted)\n"
        f"  {EXIT_USAGE_ERROR:>3}  usage error (bad arguments)\n"
        f"{_EXIT_CODE_HELP}\n",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    mode_group = parser.add_mutually_exclusive_group(required=True)
    mode_group.add_argument(
        "--emit-challenge", action="store_true",
        help="emit a fresh challenge (nonce + canary target + per-runtime tool-call template) on stdout",
    )
    mode_group.add_argument(
        "--verify-response", action="store_true",
        help="verify a recorded raw tool-call result against a runtime's expected-deny signature",
    )
    mode_group.add_argument(
        "--confirm-cleanup", action="store_true",
        help="verify a recorded cleanup-delete result against the sentinel cleanup contract",
    )
    parser.add_argument("--nonce", default=None, help="the challenge's own nonce (required for --verify-response/--confirm-cleanup)")
    parser.add_argument("--recorded-result", default=None, help="path to the caller-recorded raw tool-call result (--verify-response only)")
    parser.add_argument("--runtime", default=None, choices=RUNTIMES, help="the runtime under test (--verify-response only)")
    parser.add_argument("--recorded-cleanup-result", default=None, help="path to the caller-recorded cleanup-delete result (--confirm-cleanup only)")
    return parser


def main(argv=None):
    parser = build_arg_parser()
    args = parser.parse_args(argv)

    try:
        if args.emit_challenge:
            extras = [
                name for name, val in (
                    ("--nonce", args.nonce),
                    ("--recorded-result", args.recorded_result),
                    ("--runtime", args.runtime),
                    ("--recorded-cleanup-result", args.recorded_cleanup_result),
                ) if val is not None
            ]
            if extras:
                raise HookHandshakeError(
                    "USAGE_ERROR", f"--emit-challenge takes no other arguments (got: {', '.join(extras)})",
                )
            return run_emit_challenge()

        if args.verify_response:
            if args.recorded_cleanup_result is not None:
                raise HookHandshakeError(
                    "USAGE_ERROR", "--recorded-cleanup-result must not be combined with --verify-response",
                )
            missing = [
                name for name, val in (
                    ("--nonce", args.nonce),
                    ("--recorded-result", args.recorded_result),
                    ("--runtime", args.runtime),
                ) if val is None
            ]
            if missing:
                raise HookHandshakeError(
                    "USAGE_ERROR", f"--verify-response requires {', '.join(missing)}",
                )
            if args.nonce == "":
                raise HookHandshakeError("USAGE_ERROR", "--nonce must not be empty")
            return do_verify_response(args.nonce, args.recorded_result, args.runtime)

        # --confirm-cleanup
        if args.recorded_result is not None or args.runtime is not None:
            raise HookHandshakeError(
                "USAGE_ERROR", "--recorded-result/--runtime must not be combined with --confirm-cleanup",
            )
        missing = [
            name for name, val in (
                ("--nonce", args.nonce),
                ("--recorded-cleanup-result", args.recorded_cleanup_result),
            ) if val is None
        ]
        if missing:
            raise HookHandshakeError(
                "USAGE_ERROR", f"--confirm-cleanup requires {', '.join(missing)}",
            )
        if args.nonce == "":
            raise HookHandshakeError("USAGE_ERROR", "--nonce must not be empty")
        return do_confirm_cleanup(args.nonce, args.recorded_cleanup_result)
    except HookHandshakeError as exc:
        print(f"check-hook-activation-handshake: {exc.category}: {exc.message}", file=sys.stderr)
        if exc.category == "USAGE_ERROR":
            return EXIT_USAGE_ERROR
        return CATEGORY_EXIT_CODES.get(exc.category, 1)
    except Exception as exc:  # noqa: BLE001 - last-resort classification, never a raw traceback
        print(f"check-hook-activation-handshake: INTERNAL_ERROR: unexpected error: {exc!r}", file=sys.stderr)
        return CATEGORY_EXIT_CODES["INTERNAL_ERROR"]


if __name__ == "__main__":
    sys.exit(main())
