#!/usr/bin/env python3
"""Report reviewed adapter gaps; no job admission or execution is performed."""

import ast
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[3]
REQUIRED = (
    "work_order_admission",
    "restart_lease",
    "duplicate_reconciliation",
    "late_result_fencing",
    "file_port_database_reservation",
    "cancel_child_tree",
    "budget_observation",
)
CANDIDATES = (
    (
        "managed-native-invocation",
        "plugins/sdd-implementation/scripts/managed-model-entry.py",
        "_run_cli",
        "Internal bounded subprocess exchange; no public factory work-order ownership API.",
    ),
    (
        "lite-gate",
        "plugins/sdd-lite/lib/run-lite-gate.py",
        "_run_one",
        "Required-check execution owner; not a discretionary work-order executor.",
    ),
    (
        "verification-catalog",
        "tests/verification.py",
        "main",
        "Catalog suite execution owner; no public factory lease/reconciliation contract.",
    ),
)


def inspect(root=ROOT):
    results = []
    for name, relative, symbol, boundary in CANDIDATES:
        path = root / relative
        available, digest = False, None
        try:
            raw = path.read_bytes()
            tree = ast.parse(raw)
            available = any(
                isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))
                and node.name == symbol
                for node in tree.body
            )
            digest = hashlib.sha256(raw).hexdigest()
        except (OSError, SyntaxError):
            pass
        results.append(
            {
                "adapter": name,
                "source": relative,
                "sha256": digest,
                "reviewed_symbol_present": available,
                "boundary": boundary,
                "required_capabilities": {key: "not-demonstrated" for key in REQUIRED},
            }
        )
    return {
        "schema": "factory-adapter-readiness/v1",
        "admissible": False,
        "reason": "no-verified-adapter",
        "candidates": results,
        "next": "Verify one existing executor public API and real cancel/resume/isolation/budget behavior before admission policy implementation.",
        "authority": "none",
        "scope": "source inventory only; no claim about all external hosts",
    }


def plan(request):
    """Pure bounded admission proposal; it reserves nothing and cannot dispatch."""
    def require(condition, message):
        if not condition:
            raise ValueError(message)

    def fields(value, names):
        require(isinstance(value, dict) and set(value) == set(names.split()), "invalid-fields")

    def integer(value, minimum=0):
        require(type(value) is int and minimum <= value <= 10**9, "invalid-integer")

    def identifier(value):
        require(isinstance(value, str) and re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]{0,127}", value), "invalid-id")

    def names(value):
        require(isinstance(value, list) and len(value) <= 128, "invalid-list")
        for item in value:
            identifier(item)
        require(len(value) == len(set(value)), "duplicate-id")

    fields(request, "schema limits active queued completed decision_queue")
    require(request["schema"] == "factory-admission-request/v1", "invalid-schema")
    limits = request["limits"]
    fields(limits, "parallel features reviewers remaining_runs remaining_seconds ready_limit wait_limit_seconds")
    for value in limits.values():
        integer(value)
    require(limits["parallel"] in (2, 4, 8), "unsupported-parallelism")
    require(1 <= limits["features"] <= limits["parallel"], "invalid-feature-limit")
    queue = request["decision_queue"]
    fields(queue, "ready_count mean_review_seconds")
    integer(queue["ready_count"])
    if queue["mean_review_seconds"] is not None:
        integer(queue["mean_review_seconds"], 1)
    names(request["completed"])
    for group in ("active", "queued"):
        require(isinstance(request[group], list) and len(request[group]) <= 128, "invalid-jobs")
        for job in request[group]:
            fields(job, "id feature kind workspace dependencies paths ports databases seeds seconds reviewers")
            for key in ("id", "feature", "workspace"):
                identifier(job[key])
            require(job["kind"] in ("read_only", "isolated_prototype", "product_write"), "invalid-kind")
            for key in ("dependencies", "databases", "seeds"):
                names(job[key])
            require(job["id"] not in job["dependencies"], "self-dependency")
            integer(job["seconds"], 1)
            integer(job["reviewers"])
            require(isinstance(job["ports"], list) and len(job["ports"]) <= 128, "invalid-ports")
            for port in job["ports"]:
                integer(port, 1)
                require(port <= 65535, "invalid-port")
            require(len(job["ports"]) == len(set(job["ports"])), "duplicate-port")
            require(isinstance(job["paths"], list) and len(job["paths"]) <= 128, "invalid-paths")
            for path in job["paths"]:
                require(isinstance(path, str) and len(path) <= 1024 and
                        all(re.fullmatch(r"[A-Za-z0-9_.-]+", part) and part not in (".", "..")
                            for part in path.split("/")), "noncanonical-path")
            require(len(job["paths"]) == len(set(job["paths"])), "duplicate-path")
            require(job["kind"] == "read_only" or job["paths"], "missing-write-scope")
    active = request["active"]
    active_ids = [job["id"] for job in active]
    require(len(active_ids) == len(set(active_ids)), "duplicate-active-work-order")
    require(not set(active_ids) & set(request["completed"]), "inconsistent-active-completed")
    queued_ids = [job["id"] for job in request["queued"]]
    selected, deferred, occupied = [], [], list(active)
    seconds = limits["remaining_seconds"] - sum(job["seconds"] for job in active)
    runs = limits["remaining_runs"] - len(active)
    reviewers = limits["reviewers"] - sum(job["reviewers"] for job in active)
    for job in request["queued"]:
        reasons = []
        if queued_ids.count(job["id"]) != 1 or job["id"] in active_ids or job["id"] in request["completed"]:
            reasons.append("duplicate-work-order")
        if not set(job["dependencies"]) <= set(request["completed"]):
            reasons.append("dependencies-incomplete")
        if job["kind"] == "product_write":
            reasons.append("task-approval-integration-required")
        if queue["ready_count"] >= limits["ready_limit"] or (queue["ready_count"] and
                (queue["mean_review_seconds"] is None or
                 queue["ready_count"] * queue["mean_review_seconds"] >= limits["wait_limit_seconds"])):
            reasons.append("human-queue-limit")
        if len(occupied) >= limits["parallel"]:
            reasons.append("parallel-limit")
        if len({row["feature"] for row in occupied} | {job["feature"]}) > limits["features"]:
            reasons.append("feature-limit")
        if any(row["feature"] == job["feature"] for row in occupied):
            reasons.append("feature-busy")
        if job["seconds"] > seconds or runs < 1:
            reasons.append("run-time-budget")
        if job["reviewers"] > reviewers:
            reasons.append("reviewer-capacity")
        for key in ("ports", "databases", "seeds"):
            if any(set(job[key]) & set(row[key]) for row in occupied):
                reasons.append(key + "-conflict")
        for row in occupied:
            if job["workspace"] != row["workspace"] or job["kind"] == row["kind"] == "read_only":
                continue
            if any(a == b or a.startswith(b + "/") or b.startswith(a + "/")
                   for a in job["paths"] for b in row["paths"]):
                reasons.append("path-conflict")
                break
        if reasons:
            deferred.append({"id": job["id"], "reasons": reasons})
        else:
            selected.append(job["id"])
            occupied.append(job)
            seconds -= job["seconds"]
            runs -= 1
            reviewers -= job["reviewers"]
    raw = json.dumps(request, sort_keys=True, separators=(",", ":")).encode()
    return {"schema": "factory-admission-plan/v1", "input_sha256": hashlib.sha256(raw).hexdigest(),
            "selected": selected, "deferred": deferred, "active_unchanged": active_ids,
            "dispatch_authorized": False, "authority": "none", "cost_guarantee": False,
            "next": "Reconcile live executor ownership and atomically reserve before dispatch; this proposal grants no lease or approval."}


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate-json-key")
        result[key] = value
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    parser.add_argument("--plan", type=Path, help="Evaluate a bounded proposal without dispatch or reservations")
    args = parser.parse_args()
    try:
        if args.plan:
            with args.plan.open("rb") as stream:
                raw = stream.read(1024 * 1024 + 1)
            if len(raw) > 1024 * 1024:
                raise ValueError("request-too-large")
            result = plan(json.loads(raw, object_pairs_hook=unique_object))
        else:
            result = inspect()
        print(json.dumps(result, indent=2))
    except (OSError, ValueError, TypeError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(2)
