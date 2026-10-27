#!/usr/bin/env python3
"""Select an advisory playbook; never execute work or change track/approval."""

import argparse
import json
from pathlib import Path
import sys

ROUTES = {
    "investigate": ("investigate-codebase", "read-only", "investigation"),
    "bugfix": ("sdd-bootstrap-interviewer", "specification", "bugfix"),
    "performance": ("investigate-codebase", "read-only", "performance"),
    "prototype": ("investigate-codebase", "isolated-prototype", "prototype"),
    "handoff": ("investigate-codebase", "read-only", "handoff"),
}


def unique(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate key")
        result[key] = value
    return result


def route(request):
    required = {
        "schema",
        "purpose",
        "track",
        "requested_effect",
        "objective",
        "scenario",
        "constraints",
        "hypotheses",
        "selection_criteria",
        "budget",
    }
    if not isinstance(request, dict) or set(request) != required:
        raise ValueError(
            "playbook request fields differ from workflow-playbook-request/v1"
        )
    if request["schema"] != "workflow-playbook-request/v1":
        raise ValueError("unsupported schema")
    if request["purpose"] not in ROUTES or request["track"] not in (
        "full",
        "lite",
        "legacy",
    ):
        raise ValueError("unsupported purpose or track; use existing bootstrap routing")
    for key in ("objective", "scenario"):
        if not isinstance(request[key], str) or not request[key].strip():
            raise ValueError("objective and scenario are required")
    for key in ("constraints", "hypotheses", "selection_criteria"):
        if (
            not isinstance(request[key], list)
            or not request[key]
            or any(not isinstance(v, str) or not v.strip() for v in request[key])
        ):
            raise ValueError(
                "nonempty constraints, hypotheses and selection criteria required"
            )
    budget = request["budget"]
    if not isinstance(budget, dict) or set(budget) != {
        "seconds",
        "max_runs",
        "cost_limit",
        "cost_reason",
    }:
        raise ValueError("bounded budget required")
    if any(
        type(budget[k]) is not int or budget[k] <= 0 for k in ("seconds", "max_runs")
    ):
        raise ValueError("positive time and run limits required")
    cost = budget["cost_limit"]
    if cost is not None and (
        type(cost) not in (int, float) or not 0 <= cost < float("inf")
    ):
        raise ValueError("invalid cost limit")
    if not isinstance(budget["cost_reason"], str) or (
        cost is None and not budget["cost_reason"].strip()
    ):
        raise ValueError(
            "unobserved cost needs a reason; time/run bounds are not a monetary guarantee"
        )
    delegate, effect, reference = ROUTES[request["purpose"]]
    if request["requested_effect"] != effect:
        raise ValueError(
            "requested effect exceeds the selected playbook; no work authorized"
        )
    return {
        "schema": "workflow-playbook-route/v1",
        "purpose": request["purpose"],
        "track": request["track"],
        "delegate": delegate,
        "playbook": "references/playbooks/" + reference + ".md",
        "reason": "Explicit purpose selects work method; existing track and approval owners remain authoritative.",
        "effect": effect,
        "authorization": "none",
        "budget": budget,
        "stop_conditions": [
            "time or run budget exhausted",
            "permission boundary reached",
            "sufficient discriminating evidence",
            "marginal evidence no longer improves the decision",
        ],
        "next": "existing bootstrap specification/review/task approval"
        if request["purpose"] == "prototype"
        else delegate,
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    parser.add_argument("--request", required=True, type=Path)
    args = parser.parse_args(argv)
    try:
        result = route(
            json.loads(
                args.request.read_text(encoding="utf-8"), object_pairs_hook=unique
            )
        )
        print(json.dumps(result, ensure_ascii=False, allow_nan=False))
        return 0
    except (OSError, ValueError, TypeError, KeyError):
        print(
            json.dumps(
                {
                    "schema": "workflow-playbook-error/v1",
                    "error": "invalid-request",
                    "authorization": "none",
                }
            )
        )
        return 2


if __name__ == "__main__":
    sys.exit(main())
