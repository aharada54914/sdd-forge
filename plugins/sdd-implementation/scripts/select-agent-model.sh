#!/usr/bin/env bash
set -euo pipefail

risk=""
candidates=()
failure_class=""
failure_history=""
previous_tier=""
consecutive_failures="0"
registry="$(cd "$(dirname "$0")/../../.." && pwd)/contracts/agent-model-capabilities.json"
candidates_file=""
required_tier=""
minimum_tier=""
json_output="false"
xhigh_reason=""
attempt_number="0"
deterministic_runtime_command="python3"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --risk)
      risk="${2:-}"
      shift 2
      ;;
    --candidate)
      candidates+=("${2:-}")
      shift 2
      ;;
    --failure-class)
      failure_class="${2:-}"
      shift 2
      ;;
    --failure-history)
      failure_history="${2:-}"
      shift 2
      ;;
    --previous-tier)
      previous_tier="${2:-}"
      shift 2
      ;;
    --consecutive-failures)
      consecutive_failures="${2:-}"
      shift 2
      ;;
    --registry)
      registry="${2:-}"
      shift 2
      ;;
    --candidates-file)
      candidates_file="${2:-}"
      shift 2
      ;;
    --required-tier)
      required_tier="${2:-}"
      shift 2
      ;;
    --minimum-tier)
      minimum_tier="${2:-}"
      shift 2
      ;;
    --json)
      json_output="true"
      shift
      ;;
    --xhigh-reason)
      xhigh_reason="${2:-}"
      shift 2
      ;;
    --attempt-number)
      attempt_number="${2:-}"
      shift 2
      ;;
    --deterministic-runtime-command)
      deterministic_runtime_command="${2:-}"
      shift 2
      ;;
    *)
      printf 'MODEL_SELECTION_ERROR: unknown argument: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$deterministic_runtime_command" ]] ||
  ! command -v "$deterministic_runtime_command" >/dev/null 2>&1; then
  printf 'BLOCKED deterministic-runtime-unavailable\n'
  exit 0
fi

python3 - "$risk" "$failure_class" "$previous_tier" "$consecutive_failures" \
  "$registry" "$candidates_file" "$required_tier" "$minimum_tier" \
  "$json_output" "$xhigh_reason" "$failure_history" "$attempt_number" \
  "${candidates[@]}" <<'PY'
import decimal
import json
import re
import sys

(risk, failure_class, previous_tier, consecutive_failures, registry_path,
 candidates_file, required_tier, minimum_tier, json_output, xhigh_reason,
 failure_history, attempt_number,
 *legacy_candidates) = sys.argv[1:]
matrix = {
    "low": {"lightweight": 1, "standard": 1, "strong": 1},
    "medium": {"lightweight": 2, "standard": 1, "strong": 1},
    "high": {"lightweight": 3, "standard": 2, "strong": 1},
    "critical": {"lightweight": 3, "standard": 2, "strong": 1},
}
tiers = {"lightweight": 0, "standard": 1, "strong": 2}
efforts = {"": 0, "low": 0, "medium": 1, "high": 2, "xhigh": 3}
failure_classes = {
    "test", "lint", "typecheck", "build", "review-major", "review-critical"
}
COST = re.compile(r"^(?:0|[1-9][0-9]*)(?:\.[0-9]+)?$")

def parse_cost(value):
    if not isinstance(value, str) or not COST.fullmatch(value):
        raise ValueError
    parsed_cost = decimal.Decimal(value)
    if not parsed_cost.is_finite() or parsed_cost < 0:
        raise ValueError
    return parsed_cost

if risk not in matrix:
    print("MODEL_SELECTION_ERROR: invalid risk", file=sys.stderr)
    sys.exit(1)
try:
    recurrence = int(consecutive_failures)
    attempt = int(attempt_number)
except ValueError:
    print("MODEL_SELECTION_ERROR: invalid recurrence", file=sys.stderr)
    sys.exit(1)
if failure_class and failure_class not in failure_classes:
    print("MODEL_SELECTION_ERROR: invalid failure class", file=sys.stderr)
    sys.exit(1)
if failure_history:
    history = failure_history.split(",")
    if any(item not in failure_classes for item in history):
        print("MODEL_SELECTION_ERROR: invalid failure history", file=sys.stderr)
        sys.exit(1)
    failure_class = history[-1]
    recurrence = 2 if len(history) >= 2 and history[-1] == history[-2] else 1
if previous_tier and previous_tier not in tiers:
    print("MODEL_SELECTION_ERROR: invalid previous tier", file=sys.stderr)
    sys.exit(1)
if recurrence < 0:
    print("MODEL_SELECTION_ERROR: invalid recurrence", file=sys.stderr)
    sys.exit(1)
if attempt < 0:
    print("MODEL_SELECTION_ERROR: invalid attempt number", file=sys.stderr)
    sys.exit(1)
if recurrence >= 2 and not failure_class:
    print("MODEL_SELECTION_ERROR: recurrence requires a failure class", file=sys.stderr)
    sys.exit(1)
escalation_tier = None
if recurrence >= 2:
    if not previous_tier:
        print("MODEL_SELECTION_ERROR: recurrence requires a previous tier", file=sys.stderr)
        sys.exit(1)
    if attempt < 1:
        print("MODEL_SELECTION_ERROR: recurrence requires an attempt number", file=sys.stderr)
        sys.exit(1)
    if previous_tier == "strong":
        if json_output == "true":
            print(json.dumps({
                "escalation": {
                    "attempt_number": attempt,
                    "failure_class": failure_class,
                    "next_tier": None,
                    "prior_tier": previous_tier,
                    "reason": "terminal-tier-recurrence",
                },
                "reason": "terminal-tier-recurrence",
                "status": "BLOCKED",
            }, separators=(",", ":"), sort_keys=True))
        else:
            print(
                "BLOCKED terminal-tier-recurrence "
                f"prior_tier={previous_tier} next_tier=null "
                f"failure_class={failure_class} attempt_number={attempt} "
                "reason=terminal-tier-recurrence"
            )
        sys.exit(0)
    escalation_tier = "standard" if previous_tier == "lightweight" else "strong"
if required_tier and required_tier not in tiers:
    print("MODEL_SELECTION_ERROR: invalid required tier", file=sys.stderr)
    sys.exit(1)
if minimum_tier and minimum_tier not in tiers:
    print("MODEL_SELECTION_ERROR: invalid minimum tier", file=sys.stderr)
    sys.exit(1)

parsed = []
available_names = []
if candidates_file:
    try:
        with open(registry_path, encoding="utf-8") as handle:
            registry = json.load(handle)
        with open(candidates_file, encoding="utf-8") as handle:
            candidate_data = json.load(handle)
        registered = {
            item["name"]: item for item in registry["models"]
            if item["canonical_tier"] in tiers
        }
        if (registry.get("schema") != "agent-model-capabilities/v1"
                or not isinstance(candidate_data, list)):
            raise ValueError
        for item in candidate_data:
            definition = registered[item["name"]]
            effort = item["effort"]
            if effort not in definition["efforts"] or not isinstance(item["available"], bool):
                raise ValueError
            cost = parse_cost(item["cost"])
            if item["available"]:
                parsed.append((item["name"], definition["canonical_tier"], cost, effort))
                available_names.append(item["name"])
    except Exception:
        print("MODEL_SELECTION_ERROR: invalid capability candidates", file=sys.stderr)
        sys.exit(1)
else:
    for candidate in legacy_candidates:
        try:
            name, tier, cost = candidate.rsplit(":", 2)
            parsed.append((name, tier, parse_cost(cost), ""))
            available_names.append(name)
        except Exception:
            print("MODEL_SELECTION_ERROR: invalid candidate", file=sys.stderr)
            sys.exit(1)
        if tier not in tiers:
            print("MODEL_SELECTION_ERROR: invalid tier", file=sys.stderr)
            sys.exit(1)

eligible = [
    item for item in parsed
    if (not escalation_tier or item[1] == escalation_tier)
    and (not required_tier or item[1] == required_tier)
    and (not minimum_tier or tiers[item[1]] >= tiers[minimum_tier])
    and (item[3] != "xhigh" or bool(xhigh_reason))
]
if not eligible:
    print("BLOCKED model-tier-unavailable")
    sys.exit(0)
winner = sorted(
    eligible,
    key=lambda item: (
        matrix[risk][item[1]], tiers[item[1]], efforts[item[3]], item[2], item[0]
    ),
)[0]
if json_output == "true":
    print(json.dumps({
        "model": winner[0],
        "canonical_tier": winner[1],
        "effort": winner[3] or None,
        "estimated_cost_per_attempt_usd": str(winner[2]),
        "available_candidates": sorted(set(available_names)),
        "xhigh_reason": xhigh_reason if winner[3] == "xhigh" else None,
        "escalation": ({
            "attempt_number": attempt,
            "failure_class": failure_class,
            "next_tier": escalation_tier,
            "prior_tier": previous_tier,
            "reason": "same-classified-failure-twice",
        } if escalation_tier else None),
    }, separators=(",", ":"), sort_keys=True))
else:
    suffix = ""
    if escalation_tier:
        suffix = (
            f" prior_tier={previous_tier} next_tier={escalation_tier}"
            f" failure_class={failure_class} attempt_number={attempt}"
            " reason=same-classified-failure-twice"
        )
    print(f"{winner[0]} {winner[1]}{suffix}")
PY
