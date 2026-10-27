#!/usr/bin/env python3
"""Passive immutable run measurements. Observations never grant gate or approval authority."""

import argparse
from collections import Counter
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import re
import statistics as stats
import subprocess
import sys
import tempfile
import time
import uuid

SCHEMA = "sdd-run-measurement/v1"
PHASES = (
    "session",
    "gate",
    "command",
    "review-preparation",
    "model",
    "human-wait",
    "human-active",
)
MACHINE = ("gate", "command", "review-preparation", "model")
OUTCOMES = (
    "success",
    "failure",
    "timeout",
    "interrupted",
    "rejected",
    "abandoned",
    "undecided",
)
MARKS = (
    "idea-received",
    "comparable-ready",
    "human-decision",
    "implementation-verified",
)
def _clock_domain():
    try:
        if sys.platform == "linux":
            boot = str(uuid.UUID(Path("/proc/sys/kernel/random/boot_id").read_text().strip()))
            return "linux-boot:" + boot
        elif sys.platform == "darwin":
            result = subprocess.run(
                ["sysctl", "-n", "kern.boottime"], capture_output=True,
                text=True, check=True, timeout=2,
            )
            match = re.search(r"\bsec\s*=\s*(\d+).*\busec\s*=\s*(\d+)", result.stdout)
            if not match or not platform.node():
                raise ValueError("boot identity unavailable")
            boot = platform.node() + ":" + ":".join(match.groups())
        elif sys.platform == "win32":
            import ctypes
            data = (ctypes.c_ubyte * 64)()
            size = ctypes.c_ulong()
            query = ctypes.WinDLL("ntdll").NtQuerySystemInformation
            if query(90, ctypes.byref(data), ctypes.sizeof(data), ctypes.byref(size)) != 0:
                raise ValueError("boot identity unavailable")
            boot = str(uuid.UUID(bytes_le=bytes(data[:16])))
            if uuid.UUID(boot).int == 0:
                raise ValueError("boot identity unavailable")
        else:
            raise ValueError("unsupported platform")
        return "boot:" + hashlib.sha256((sys.platform + ":" + boot).encode()).hexdigest()
    except (OSError, ValueError, AttributeError, subprocess.SubprocessError):
        return "process:" + uuid.uuid4().hex


CLOCK_DOMAIN = _clock_domain()
KEYS = {
    "measurement": "measurement_id run_id parent_run_id scope feature task attempt rerun_reason rerun_detail scenario_id trial_id environment experiment_ref variant_ref decision_ref refs_missing_reason",
    "span-start": "span_id parent_span_id phase command_id inputs",
    "span-finish": "span_id outcome exit_code signal logs artifacts token_usage token_usage_missing_reason cost cost_missing_reason",
    "mark": "milestone ref",
}
KEYS = {
    kind: set(fields.split()) | {"schema", "kind", "clock_domain", "ns", "utc"}
    for kind, fields in KEYS.items()
}


class MeasurementError(Exception):
    def __init__(self, code="invalid", message="invalid measurement input"):
        self.code = code
        super().__init__(message)


def _clock():
    return (
        CLOCK_DOMAIN,
        time.monotonic_ns(),
        datetime.now(timezone.utc)
        .isoformat(timespec="microseconds")
        .replace("+00:00", "Z"),
    )


def _id(value, nullable=False, command=False):
    if value is None and nullable:
        return
    pattern = (
        r"[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}"
        if command
        else r"[A-Za-z0-9][A-Za-z0-9._:-]{0,63}"
    )
    if not isinstance(value, str) or not re.fullmatch(pattern, value) or ".." in value:
        raise MeasurementError()


def _text(value, nullable=True):
    if value is None and nullable:
        return
    if (
        not isinstance(value, str)
        or not value
        or len(value) > 200
        or any(ord(c) < 32 or ord(c) == 127 for c in value)
    ):
        raise MeasurementError()


def _integer(value, minimum=None, nullable=False):
    if value is None and nullable:
        return
    if type(value) is not int or (minimum is not None and value < minimum):
        raise MeasurementError()


def _safe(path, create=False):
    path = Path(path).absolute()
    for part in (path, *path.parents):
        if part.is_symlink():
            raise MeasurementError()
    if create:
        path.mkdir(parents=True, exist_ok=True)
    if not path.is_dir():
        raise MeasurementError()
    return path


def _pairs(pairs):
    data = {}
    for k, v in pairs:
        if k in data:
            raise MeasurementError()
        data[k] = v
    return data


def _load(path):
    if path.is_symlink() or not path.is_file() or path.stat().st_size > 65536:
        raise MeasurementError()
    try:
        value = json.loads(
            path.read_text(encoding="utf-8"),
            object_pairs_hook=_pairs,
            parse_constant=lambda _: (_ for _ in ()).throw(MeasurementError()),
        )
    except (ValueError, UnicodeError) as e:
        raise MeasurementError() from e
    try:
        _validate(value)
    except (TypeError, KeyError, AttributeError, ValueError) as exc:
        raise MeasurementError() from exc
    return value


def _validate(r):
    if (
        not isinstance(r, dict)
        or r.get("kind") not in KEYS
        or set(r) != KEYS[r["kind"]]
        or r["schema"] != SCHEMA
    ):
        raise MeasurementError()
    _integer(r["ns"], 0)
    _text(r["clock_domain"], False)
    try:
        timestamp = datetime.fromisoformat(r["utc"].replace("Z", "+00:00"))
        if timestamp.tzinfo is None or timestamp.utcoffset().total_seconds() != 0:
            raise MeasurementError()
    except (ValueError, TypeError, AttributeError) as e:
        raise MeasurementError() from e
    k = r["kind"]
    if k == "measurement":
        for name in ("measurement_id", "run_id"):
            _id(r[name])
        for name in (
            "parent_run_id",
            "feature",
            "task",
            "scenario_id",
            "trial_id",
            "experiment_ref",
            "variant_ref",
            "decision_ref",
        ):
            _id(r[name], True)
        if r["scope"] not in ("all", "feature") or (
            r["scope"] == "feature" and r["feature"] is None
        ):
            raise MeasurementError()
        _integer(r["attempt"], 1)
        if r["rerun_reason"] not in ("initial", "fix", "resume", "repeat", "other"):
            raise MeasurementError()
        _text(r["rerun_detail"], r["rerun_reason"] != "other")
        env = r["environment"]
        if not isinstance(env, dict) or set(env) != {
            "head",
            "dirty",
            "os",
            "arch",
            "python",
            "tools",
            "target_count",
            "input_manifest_sha256",
        }:
            raise MeasurementError()
        if env["dirty"] is not None and type(env["dirty"]) is not bool:
            raise MeasurementError()
        _integer(env["target_count"], 0, True)
        if env["head"] is not None and (
            not isinstance(env["head"], str)
            or not re.fullmatch("[a-f0-9]{40}|[a-f0-9]{64}", env["head"])
        ):
            raise MeasurementError()
        if env["input_manifest_sha256"] is not None and (
            not isinstance(env["input_manifest_sha256"], str)
            or not re.fullmatch("[a-f0-9]{64}", env["input_manifest_sha256"])
        ):
            raise MeasurementError()
        if not isinstance(env["tools"], dict):
            raise MeasurementError()
        for name, version in env["tools"].items():
            _id(name)
            _text(version, False)
        for name in ("os", "arch", "python"):
            _text(env[name], False)
        if r["refs_missing_reason"] != {
            f: "not-supplied"
            for f in ("experiment_ref", "variant_ref", "decision_ref")
            if r[f] is None
        }:
            raise MeasurementError()
    elif k == "span-start":
        _id(r["span_id"])
        _id(r["parent_span_id"], True)
        _id(r["command_id"], command=True)
        if r["phase"] not in PHASES:
            raise MeasurementError()
        _validate_refs(r["inputs"], "input")
    elif k == "span-finish":
        _id(r["span_id"])
        _integer(r["exit_code"], nullable=True)
        _text(r["signal"])
        if r["outcome"] not in OUTCOMES:
            raise MeasurementError()
        _validate_refs(r["logs"], "log")
        _validate_refs(r["artifacts"], "artifact")
        t = r["token_usage"]
        c = r["cost"]
        if t is not None:
            if not isinstance(t, dict) or set(t) != {"input", "output", "source_ref"}:
                raise MeasurementError()
            _integer(t["input"], 0)
            _integer(t["output"], 0)
            _id(t["source_ref"])
        if c is not None:
            if not isinstance(c, dict) or set(c) != {
                "amount",
                "currency",
                "source_ref",
            }:
                raise MeasurementError()
            try:
                amount = Decimal(c["amount"])
            except (InvalidOperation, TypeError) as e:
                raise MeasurementError() from e
            if (
                not isinstance(c["amount"], str)
                or not re.fullmatch(r"[0-9]+(?:\.[0-9]+)?", c["amount"])
                or not amount.is_finite()
                or amount < 0
                or not isinstance(c["currency"], str)
                or not re.fullmatch("[A-Z]{3}", c["currency"])
            ):
                raise MeasurementError()
            _id(c["source_ref"])
        for name in ("token_usage", "cost"):
            if r[name + "_missing_reason"] != (
                "not-reported" if r[name] is None else None
            ):
                raise MeasurementError()
    elif r["milestone"] not in MARKS:
        raise MeasurementError()
    else:
        _id(r["ref"], True)


def _validate_refs(refs, kind):
    if not isinstance(refs, list):
        raise MeasurementError()
    keys = {"path", "sha256", "missing"} | (
        {"stream", "truncated"}
        if kind == "log"
        else {"kind", "target_run_id"}
        if kind == "artifact"
        else set()
    )
    for ref in refs:
        if (
            not isinstance(ref, dict)
            or set(ref) != keys
            or not isinstance(ref["path"], str)
            or not ref["path"]
            or "\0" in ref["path"]
            or type(ref["missing"]) is not bool
        ):
            raise MeasurementError()
        if ref["missing"]:
            if ref["sha256"] is not None:
                raise MeasurementError()
        elif not isinstance(ref["sha256"], str) or not re.fullmatch(
            "[a-f0-9]{64}", ref["sha256"]
        ):
            raise MeasurementError()
        if kind == "log" and (
            ref["stream"] not in ("stdout", "stderr", "combined")
            or type(ref["truncated"]) is not bool
        ):
            raise MeasurementError()
        if kind == "artifact":
            if ref["kind"] not in ("run-record", "verification-receipt", "lite-output"):
                raise MeasurementError()
            _id(ref["target_run_id"], True)


def _ref(path, **extra):
    p = Path(path)
    if p.is_symlink():
        raise MeasurementError()
    exists = p.is_file()
    return dict(
        path=str(path),
        sha256=hashlib.sha256(p.read_bytes()).hexdigest() if exists else None,
        missing=not exists,
        **extra,
    )


def _record(kind, **fields):
    domain, ns, utc = _clock()
    r = dict(schema=SCHEMA, kind=kind, clock_domain=domain, ns=ns, utc=utc, **fields)
    try:
        _validate(r)
    except (ValueError, TypeError, KeyError, AttributeError) as exc:
        raise MeasurementError() from exc
    return r


def _semantic(record):
    data = {k: v for k, v in record.items() if k not in ("clock_domain", "ns", "utc")}
    if record["kind"] == "measurement":
        data["environment"] = {
            k: v
            for k, v in data["environment"].items()
            if k not in ("os", "arch", "python")
        }
    return data


def _write(path, record):
    _safe(path.parent, True)
    if path.exists() or path.is_symlink():
        old = _load(path)
        if _semantic(old) != _semantic(record):
            raise MeasurementError(
                "conflict", "record conflicts with existing observation"
            )
        return old
    raw = (
        json.dumps(record, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
        + "\n"
    ).encode("utf-8")
    if len(raw) > 65536:
        raise MeasurementError()
    temporary = None
    try:
        fd, name = tempfile.mkstemp(prefix=".measure-", dir=path.parent)
        temporary = Path(name)
        with os.fdopen(fd, "wb") as stream:
            stream.write(raw)
            stream.flush()
            os.fsync(stream.fileno())
        try:
            os.link(temporary, path)
        except FileExistsError:
            return _write(path, record)
    except OSError as e:
        raise MeasurementError("io", "measurement storage unavailable") from e
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
    return record


def open_measurement(
    directory,
    *,
    measurement_id,
    run_id,
    scope,
    feature=None,
    task=None,
    attempt=1,
    rerun_reason="initial",
    rerun_detail=None,
    scenario_id=None,
    trial_id=None,
    parent_run_id=None,
    head=None,
    dirty=None,
    tools=None,
    target_count=None,
    input_manifest_sha256=None,
    experiment_ref=None,
    variant_ref=None,
    decision_ref=None,
):
    refs = dict(
        experiment_ref=experiment_ref,
        variant_ref=variant_ref,
        decision_ref=decision_ref,
    )
    r = _record(
        "measurement",
        measurement_id=measurement_id,
        run_id=run_id,
        parent_run_id=parent_run_id,
        scope=scope,
        feature=feature,
        task=task,
        attempt=attempt,
        rerun_reason=rerun_reason,
        rerun_detail=rerun_detail,
        scenario_id=scenario_id,
        trial_id=trial_id,
        environment=dict(
            head=head,
            dirty=dirty,
            os=platform.system(),
            arch=platform.machine(),
            python=platform.python_version(),
            tools=tools or {},
            target_count=target_count,
            input_manifest_sha256=input_manifest_sha256,
        ),
        **refs,
        refs_missing_reason={k: "not-supplied" for k, v in refs.items() if v is None},
    )
    return _write(_safe(directory, True) / "measurement.json", r)


def start_span(
    directory, *, phase, command_id, span_id=None, parent_span_id=None, inputs=()
):
    d = _safe(directory)
    _load(d / "measurement.json")
    span_id = span_id or uuid.uuid4().hex
    r = _record(
        "span-start",
        span_id=span_id,
        parent_span_id=parent_span_id,
        phase=phase,
        command_id=command_id,
        inputs=[_ref(p) for p in inputs],
    )
    _write(d / "spans" / f"{span_id}.start.json", r)
    return span_id


def finish_span(
    directory,
    span_id,
    *,
    outcome,
    exit_code=None,
    signal=None,
    logs=(),
    truncated=(),
    artifacts=(),
    token_usage=None,
    cost=None,
):
    _id(span_id)
    d = _safe(directory)
    _load(d / "spans" / f"{span_id}.start.json")
    if set(truncated) - {"stdout", "stderr", "combined"}:
        raise MeasurementError()
    r = _record(
        "span-finish",
        span_id=span_id,
        outcome=outcome,
        exit_code=exit_code,
        signal=signal,
        logs=[_ref(p, stream=s, truncated=s in truncated) for s, p in logs],
        artifacts=[_ref(p, kind=k, target_run_id=run) for k, p, run in artifacts],
        token_usage=token_usage,
        token_usage_missing_reason="not-reported" if token_usage is None else None,
        cost=cost,
        cost_missing_reason="not-reported" if cost is None else None,
    )
    return _write(d / "spans" / f"{span_id}.finish.json", r)


def mark(directory, milestone, *, ref=None):
    d = _safe(directory)
    _load(d / "measurement.json")
    r = _record("mark", milestone=milestone, ref=ref)
    return _write(d / "marks" / f"{milestone}.json", r)


def _union(intervals):
    if not intervals:
        return None
    total = 0
    end = None
    for start, stop in sorted(intervals):
        total += max(0, stop - max(start, end if end is not None else start))
        end = max(stop, end if end is not None else stop)
    return total


def statistics(samples):
    if not samples:
        return dict(median=None, min=None, max=None, mad=None)
    if any(type(v) not in (int, float) or not math.isfinite(v) for v in samples):
        raise MeasurementError()
    median = stats.median(samples)
    return dict(
        median=median,
        min=min(samples),
        max=max(samples),
        mad=stats.median(abs(v - median) for v in samples),
    )


def summarize(directory, *, as_of="now", ref_root=None):
    if as_of not in ("now", None):
        raise MeasurementError()
    d = _safe(directory)
    header = _load(d / "measurement.json")
    diagnostics = []
    starts = {}
    ends = {}
    marks = {}
    root = Path(ref_root or Path.cwd())

    def note(code, span_id=None):
        diagnostics.append(dict(code=code, **({"span_id": span_id} if span_id else {})))

    for sub in ("spans", "marks"):
        if not (d / sub).exists():
            continue
        _safe(d / sub)
        for p in sorted((d / sub).iterdir()):
            if p.name.startswith(".measure-"):
                continue
            try:
                r = _load(p)
                kind = r["kind"]
                if kind == "span-start" and p.name == r["span_id"] + ".start.json":
                    starts[r["span_id"]] = r
                elif kind == "span-finish" and p.name == r["span_id"] + ".finish.json":
                    ends[r["span_id"]] = r
                elif kind == "mark" and p.name == r["milestone"] + ".json":
                    marks[r["milestone"]] = r
                else:
                    raise MeasurementError()
            except (MeasurementError, OSError):
                note("record-invalid")
    now = dict(zip(("clock_domain", "ns", "utc"), _clock())) if as_of else None
    spans = []
    for sid, start in starts.items():
        end = ends.get(sid)
        reason = None
        duration = None
        censored = None
        if end is None:
            reason = "open-span"
            if (
                now
                and now["clock_domain"] == start["clock_domain"]
                and now["ns"] >= start["ns"]
            ):
                censored = now["ns"] - start["ns"]
        elif end["clock_domain"] != start["clock_domain"]:
            reason = "clock-domain-mismatch"
        elif end["ns"] < start["ns"]:
            reason = "negative-duration"
        else:
            duration = end["ns"] - start["ns"]
            wall = (
                datetime.fromisoformat(end["utc"].replace("Z", "+00:00"))
                - datetime.fromisoformat(start["utc"].replace("Z", "+00:00"))
            ).total_seconds() * 1e9
            if abs(wall - duration) > 1e9:
                note("wall-clock-adjusted", sid)
        if reason:
            note(reason, sid)
        for ref in start["inputs"] + (end["logs"] + end["artifacts"] if end else []):
            path = Path(ref["path"])
            path = path if path.is_absolute() else root / path
            try:
                if ref["missing"] or not path.is_file():
                    note("missing-ref", sid)
                elif (
                    path.is_symlink()
                    or hashlib.sha256(path.read_bytes()).hexdigest() != ref["sha256"]
                ):
                    note("ref-changed", sid)
            except OSError:
                note("missing-ref", sid)
            if ref.get("truncated"):
                note("log-truncated", sid)
        spans.append(
            dict(
                span_id=sid,
                parent_span_id=start["parent_span_id"],
                phase=start["phase"],
                command_id=start["command_id"],
                clock_domain=start["clock_domain"],
                end_clock_domain=end["clock_domain"] if end else None,
                start_ns=start["ns"],
                end_ns=end["ns"] if end else None,
                duration_ns=duration,
                duration_reason=reason,
                censored_ns=censored,
                outcome=end["outcome"] if end else "open",
                exit_code=end["exit_code"] if end else None,
                signal=end["signal"] if end else None,
                inputs=start["inputs"],
                logs=end["logs"] if end else [],
                token_usage=end["token_usage"] if end else None,
                cost=end["cost"] if end else None,
            )
        )
    for sid in ends.keys() - starts.keys():
        note("record-invalid", sid)
    by_id = {s["span_id"]: s for s in spans}
    sessions = [s for s in spans if s["phase"] == "session"]
    domain = sessions[0]["clock_domain"] if len(sessions) == 1 else None
    if len(sessions) != 1:
        note("session-missing" if not sessions else "session-duplicate")
    for s in spans:
        parent = s["parent_span_id"]
        seen = {s["span_id"]}
        while parent is not None:
            if parent not in by_id or parent in seen:
                note("parent-missing", s["span_id"])
                break
            p = by_id[parent]
            seen.add(parent)
            if s["clock_domain"] != p["clock_domain"]:
                note("clock-domain-mismatch", s["span_id"])
            elif s["start_ns"] < p["start_ns"] or (
                s["end_ns"] is not None
                and p["end_ns"] is not None
                and s["end_ns"] > p["end_ns"]
            ):
                note("child-outside-parent", s["span_id"])
            parent = p["parent_span_id"]
    valid = [
        s for s in spans if s["duration_ns"] is not None and s["clock_domain"] == domain
    ]

    def intervals(rows):
        return [(s["start_ns"], s["end_ns"]) for s in rows]

    phases = {}
    for phase in PHASES:
        rows = [s for s in valid if s["phase"] == phase]
        phases[phase] = dict(
            count=len([s for s in spans if s["phase"] == phase]),
            elapsed_ns=_union(intervals(rows)),
            effort_ns=sum(s["duration_ns"] for s in rows) if rows else None,
        )
        if not rows:
            phases[phase]["reason"] = "not-observed"
    machine = [s for s in valid if s["phase"] in MACHINE]
    outer = []
    for s in machine:
        parent = s["parent_span_id"]
        seen = set()
        nested = False
        while parent in by_id and parent not in seen:
            seen.add(parent)
            p = by_id[parent]
            if p["phase"] in MACHINE:
                nested = True
                break
            parent = p["parent_span_id"]
        if not nested:
            outer.append(s)
    elapsed = dict(
        session_ns=phases["session"]["elapsed_ns"],
        machine_elapsed_ns=_union(intervals(machine)),
        machine_effort_ns=sum(s["duration_ns"] for s in outer) if outer else None,
        machine_phases_unobserved=[p for p in MACHINE if phases[p]["count"] == 0],
        phases=phases,
        human_wait_ns=phases["human-wait"]["elapsed_ns"],
        human_active_ns=phases["human-active"]["elapsed_ns"],
    )
    for key, value in list(elapsed.items()):
        if key.endswith("_ns") and value is None:
            elapsed[key[:-3] + "_reason"] = "not-observed"
    active = [s for s in valid if s["phase"] == "human-active"]
    if active and _union(intervals(active)) < sum(s["duration_ns"] for s in active):
        elapsed["human_active_ns"] = None
        elapsed["human_active_reason"] = "human-active-overlap"
        note("human-active-overlap")
    lead = {}
    for i, name in enumerate(
        ("idea_to_comparable", "comparable_to_decision", "decision_to_verified")
    ):
        a = marks.get(MARKS[i])
        b = marks.get(MARKS[i + 1])
        reason = None
        if a is None or b is None:
            reason = "milestone-missing"
        elif a["clock_domain"] != b["clock_domain"]:
            reason = "cross-clock-domain"
        elif b["ns"] < a["ns"]:
            reason = "milestone-order"
            note(reason)
        lead[name + "_ns"] = None if reason else b["ns"] - a["ns"]
        if reason:
            lead[name + "_reason"] = reason
    models = [s for s in spans if s["phase"] == "model"]
    tokens = None
    cost = None
    if models and all(s["token_usage"] is not None for s in models):
        tokens = {
            k: sum(s["token_usage"][k] for s in models) for k in ("input", "output")
        }
    if (
        models
        and all(s["cost"] is not None for s in models)
        and len({s["cost"]["currency"] for s in models}) == 1
    ):
        cost = dict(
            amount=str(sum(Decimal(s["cost"]["amount"]) for s in models)),
            currency=models[0]["cost"]["currency"],
        )
    totals = Counter(s["outcome"] for s in spans)
    blocking = set(x["code"] for x in diagnostics) - {
        "wall-clock-adjusted",
        "log-truncated",
    }
    return dict(
        schema=SCHEMA,
        kind="summary",
        measurement=header,
        as_of=now,
        complete=not blocking,
        spans=spans,
        counts=dict(
            started=len(spans),
            by_outcome={k: totals[k] for k in (*OUTCOMES, "open")},
            invocations=dict(Counter(s["command_id"] for s in spans)),
        ),
        elapsed=elapsed,
        lead_times=lead,
        marks={
            k: {f: r[f] for f in ("ref", "clock_domain", "ns", "utc")}
            for k, r in marks.items()
        },
        artifacts=[
            ref
            for s in sessions
            for ref in ends.get(s["span_id"], {}).get("artifacts", [])
        ],
        token_usage=tokens,
        token_usage_missing_reason=None
        if tokens is not None
        else (
            "incomplete"
            if any(s["token_usage"] is not None for s in models)
            else "not-reported"
        ),
        cost=cost,
        cost_missing_reason=None
        if cost is not None
        else (
            "incomplete"
            if any(s["cost"] is not None for s in models)
            else "not-reported"
        ),
        diagnostics=diagnostics,
    )


def join_attempts(directories):
    groups = {}
    diagnostics = []
    for index, directory in enumerate(directories):
        summary = summarize(directory, as_of=None)
        h = summary["measurement"]
        key = (
            (h["scenario_id"], h["trial_id"])
            if h["scenario_id"] is not None and h["trial_id"] is not None
            else ("unpaired", index)
        )
        groups.setdefault(key, []).append(summary)
    result = []
    for values in groups.values():
        values.sort(key=lambda s: s["measurement"]["attempt"])
        previous = None
        decision = None
        attempts = []
        for s in values:
            h = s["measurement"]
            mark = s["marks"].get("human-decision")
            current = mark["ref"] if mark else None
            if previous:
                if h["attempt"] == previous["attempt"]:
                    diagnostics.append({"code": "attempt-duplicate"})
                elif (
                    h["attempt"] != previous["attempt"] + 1
                    or h["parent_run_id"] != previous["run_id"]
                ):
                    diagnostics.append({"code": "attempt-chain-broken"})
            elif h["attempt"] != 1 or h["parent_run_id"] is not None:
                diagnostics.append({"code": "attempt-chain-broken"})
            session_outcomes = [
                row["outcome"] for row in s["spans"] if row["phase"] == "session"
            ]
            attempts.append(
                dict(
                    measurement_id=h["measurement_id"],
                    run_id=h["run_id"],
                    parent_run_id=h["parent_run_id"],
                    attempt=h["attempt"],
                    rerun_reason=h["rerun_reason"],
                    complete=s["complete"],
                    session_outcome=session_outcomes[0]
                    if len(session_outcomes) == 1
                    else None,
                    by_outcome=s["counts"]["by_outcome"],
                    decision_ref=current,
                    decision_reason=None if mark else "milestone-missing",
                    decision_changed=(current != decision)
                    if current is not None and decision is not None
                    else None,
                )
            )
            if current is not None:
                decision = current
            previous = h
        result.append(
            dict(
                scenario_id=values[0]["measurement"]["scenario_id"],
                trial_id=values[0]["measurement"]["trial_id"],
                attempts=attempts,
            )
        )
    return dict(
        schema=SCHEMA,
        kind="attempt-chain",
        n=sum(len(v) for v in groups.values()),
        complete=not diagnostics
        and all(s["complete"] for v in groups.values() for s in v),
        groups=result,
        diagnostics=diagnostics,
    )


class Observer:
    """Optional owner adapter: configuration fails before work; later I/O cannot change its verdict."""

    def __init__(
        self,
        directory,
        *,
        command_id,
        parent_span_id=None,
        feature=None,
        head=None,
        dirty=None,
        target_count=None,
    ):
        self.directory = Path(directory)
        self.failed = False
        _id(parent_span_id, True)
        self.owns_session = parent_span_id is None
        if parent_span_id is not None:
            _safe(directory)
            _load(self.directory / "measurement.json")
            _load(self.directory / "spans" / (parent_span_id + ".start.json"))
            if (self.directory / "spans" / (parent_span_id + ".finish.json")).exists():
                raise MeasurementError()
            self.session = parent_span_id
            return
        if self.directory.exists() and any(self.directory.iterdir()):
            raise MeasurementError()
        identifier = uuid.uuid4().hex
        open_measurement(
            directory,
            measurement_id=identifier,
            run_id=identifier,
            scope="feature" if feature else "all",
            feature=feature,
            head=head,
            dirty=dirty,
            target_count=target_count,
        )
        self.session = start_span(directory, phase="session", command_id=command_id)

    def call(self, function, *args, **kwargs):
        if self.failed:
            return None
        try:
            return function(self.directory, *args, **kwargs)
        except (MeasurementError, OSError, ValueError):
            self.failed = True
            print("measurement: incomplete", file=sys.stderr)
            return None

    def start(self, phase, command_id, inputs=()):
        return self.call(
            start_span,
            phase=phase,
            command_id=command_id,
            parent_span_id=self.session,
            inputs=inputs,
        )

    def finish(self, span, outcome, exit_code=None, **kwargs):
        if span is not None:
            self.call(finish_span, span, outcome=outcome, exit_code=exit_code, **kwargs)

    def close(self, code, artifacts=()):
        if not self.owns_session:
            return
        self.finish(
            self.session,
            "success" if code == 0 else "failure",
            code,
            artifacts=artifacts,
        )


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    sub = p.add_subparsers(dest="command", required=True)
    for command in ("open", "start", "finish", "mark", "summarize", "join"):
        q = sub.add_parser(command)
        q.add_argument(
            "--dir", required=True, action="append" if command == "join" else "store"
        )
        if command == "open":
            for name in ("measurement-id", "run-id", "scope"):
                q.add_argument("--" + name, required=True)
            for name in (
                "feature",
                "task",
                "rerun-detail",
                "scenario-id",
                "trial-id",
                "parent-run-id",
                "head",
                "input-manifest-sha256",
                "experiment-ref",
                "variant-ref",
                "decision-ref",
            ):
                q.add_argument("--" + name)
            q.add_argument("--attempt", type=int, default=1)
            q.add_argument("--rerun-reason", default="initial")
            q.add_argument("--dirty", choices=("true", "false"))
            q.add_argument("--target-count", type=int)
            q.add_argument("--tool", action="append", default=[])
        if command == "start":
            q.add_argument("--phase", required=True)
            q.add_argument("--command-id", required=True)
            q.add_argument("--span-id")
            q.add_argument("--parent-span-id")
            q.add_argument("--input", action="append", default=[])
        if command == "finish":
            q.add_argument("--span-id", required=True)
            q.add_argument("--outcome", required=True)
            q.add_argument("--exit-code", type=int)
            q.add_argument("--signal")
            q.add_argument("--log", action="append", default=[])
            q.add_argument("--truncated", action="append", default=[])
            q.add_argument("--artifact", action="append", default=[])
            q.add_argument("--artifact-run-id", action="append", default=[])
            q.add_argument("--tokens-input", type=int)
            q.add_argument("--tokens-output", type=int)
            q.add_argument("--tokens-source")
            q.add_argument("--cost")
            q.add_argument("--currency")
            q.add_argument("--cost-source")
        if command == "mark":
            q.add_argument("--milestone", required=True)
            q.add_argument("--ref")
        if command == "summarize":
            q.add_argument("--as-of", choices=("now", "none"), default="now")
            q.add_argument("--ref-root")
        if command in ("summarize", "join"):
            q.add_argument("--output")
    a = vars(p.parse_args(argv))
    command = a.pop("command")
    directory = a.pop("dir")
    output = a.pop("output", None)
    try:
        if command == "open":
            a["tools"] = dict(x.split("=", 1) for x in a.pop("tool"))
            a["dirty"] = None if a["dirty"] is None else a["dirty"] == "true"
            result = open_measurement(directory, **a)
        elif command == "start":
            a["inputs"] = a.pop("input")
            result = start_span(directory, **a)
        elif command == "finish":
            a["logs"] = [x.split("=", 1) for x in a.pop("log")]
            artifacts = a.pop("artifact")
            ids = a.pop("artifact_run_id")
            if ids and len(ids) != len(artifacts):
                raise MeasurementError()
            a["artifacts"] = [
                (*x.split("=", 1), ids[i] if ids else None)
                for i, x in enumerate(artifacts)
            ]
            ti, to, ts = (
                a.pop(k) for k in ("tokens_input", "tokens_output", "tokens_source")
            )
            a["token_usage"] = (
                None
                if all(v is None for v in (ti, to, ts))
                else dict(input=ti, output=to, source_ref=ts)
            )
            amount, currency, source = (
                a.pop(k) for k in ("cost", "currency", "cost_source")
            )
            a["cost"] = (
                None
                if all(v is None for v in (amount, currency, source))
                else dict(amount=amount, currency=currency, source_ref=source)
            )
            result = finish_span(directory, **a)
        elif command == "mark":
            result = mark(directory, **a)
        elif command == "summarize":
            a["as_of"] = None if a["as_of"] == "none" else "now"
            result = summarize(directory, **a)
        else:
            result = join_attempts(directory)
        raw = (
            result
            if isinstance(result, str)
            else json.dumps(result, sort_keys=True, separators=(",", ":"))
        )
        if output:
            Path(output).write_text(raw + "\n", encoding="utf-8")
        else:
            print(raw)
        return 0
    except (MeasurementError, OSError, ValueError, TypeError) as e:
        code = (
            e.code
            if isinstance(e, MeasurementError)
            else "io"
            if isinstance(e, OSError)
            else "invalid"
        )
        print(
            "run-measurement: " + code + ": measurement operation failed",
            file=sys.stderr,
        )
        return {"invalid": 2, "conflict": 3, "io": 4}[code]


if __name__ == "__main__":
    sys.exit(main())
