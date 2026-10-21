#!/usr/bin/env bash
set -euo pipefail

policy_input=""
policy_engine_only="false"
explicit_keys=""
helper_path="$(cd "$(dirname "$0")" && pwd)/model-policy.py"
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
effort_policy="matrix"
requested_effort=""
role=""
host="claude-code"

while [[ $# -gt 0 ]]; do
  explicit_keys="${explicit_keys},${1#--}"
  case "$1" in
    --policy-engine-only)
      policy_engine_only="true"
      shift
      ;;
    --policy-input)
      policy_input="${2:-}"
      shift 2
      ;;
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
    --effort-policy)
      effort_policy="${2:-}"
      shift 2
      ;;
    --requested-effort)
      requested_effort="${2:-}"
      shift 2
      ;;
    --role)
      role="${2:-}"
      shift 2
      ;;
    --host)
      host="${2:-}"
      shift 2
      ;;
    *)
      printf 'MODEL_SELECTION_ERROR: unknown argument: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

if [[ "$policy_engine_only" == "true" && -z "$policy_input" ]]; then
  printf '%s\n' '{"schema":"model-policy-error/v1","reason":"config-conflict","message":"Engine-only mode requires policy input and emits no selection evidence."}' >&2
  exit 2
fi

if [[ -z "$deterministic_runtime_command" ]] ||
  ! command -v "$deterministic_runtime_command" >/dev/null 2>&1; then
  if [[ -n "$policy_input" ]]; then
    printf '%s\n' '{"schema":"model-policy-error/v1","reason":"input-invalid","message":"The deterministic selector runtime is unavailable."}' >&2
    exit 2
  fi
  printf 'BLOCKED deterministic-runtime-unavailable\n'
  exit 0
fi

# bash 3.2 (macOS CI runner's /bin/bash) errors on `"${arr[@]}"` for an empty
# array under `set -u`; `${arr[@]+"${arr[@]}"}` expands to the identical word
# list when non-empty and to zero words when empty on every bash >= 3.2.
python3 - "$risk" "$failure_class" "$previous_tier" "$consecutive_failures" \
  "$registry" "$candidates_file" "$required_tier" "$minimum_tier" \
  "$json_output" "$xhigh_reason" "$failure_history" "$attempt_number" \
  "$effort_policy" "$requested_effort" "$role" "$host" \
  "$policy_input" "$helper_path" "$explicit_keys" "$policy_engine_only" \
  ${candidates[@]+"${candidates[@]}"} 3<&0 <<'PY'
import sys
policy_mode = False
mp = None
try:
    import decimal
    import json
    import re
    import sys

    (risk, failure_class, previous_tier, consecutive_failures, registry_path,
     candidates_file, required_tier, minimum_tier, json_output, xhigh_reason,
     failure_history, attempt_number, effort_policy, requested_effort, role,
     host, policy_input, helper_path, explicit_keys, policy_engine_only,
     *legacy_candidates) = sys.argv[1:]
    policy_mode = bool(policy_input)
    policy_context = None
    mp = None
    if policy_mode:
        import importlib.util
        spec = importlib.util.spec_from_file_location("selector_model_policy", helper_path)
        mp = importlib.util.module_from_spec(spec)
        sys.modules[spec.name] = mp
        spec.loader.exec_module(mp)
        supplied = {key.replace("-", "_") for key in explicit_keys.split(",")}
        values = {"risk": risk, "role": role, "host": host, "requested_effort": requested_effort,
                  "required_tier": required_tier, "minimum_tier": minimum_tier,
                  "failure_class": failure_class, "failure_history": failure_history,
                  "previous_tier": previous_tier, "consecutive_failures": consecutive_failures,
                  "attempt_number": attempt_number, "xhigh_reason": xhigh_reason,
                  "effort_policy": effort_policy, "candidates_file": candidates_file,
                  "candidate": ",".join(legacy_candidates)}
        options = {key: value for key, value in values.items() if key in supplied}
        if "registry" not in supplied:
            from pathlib import Path
            registry_path = str(Path(helper_path).resolve().parents[3] / "contracts/agent-model-capabilities.v2.json")
        if policy_engine_only == "true":
            import os
            with os.fdopen(3, "rb") as context_stream:
                context_raw = context_stream.read(16 * 1024 * 1024 + 1)
            if len(context_raw) > 16 * 1024 * 1024:
                raise mp.PolicyError("input-invalid", "Prepared engine input exceeds the supported size.")
            policy_context = mp.strict_json(context_raw)
            if (policy_context.get("schema") != "model-policy-preparation/v1" or
                    policy_context.get("request_path") != policy_input or
                    policy_context.get("registry_path") != registry_path or
                    policy_context.get("selector_options") != options):
                raise mp.PolicyError("input-invalid", "Engine-only context must match its fixed invocation.")
        else:
            policy_context = mp.prepare_policy(policy_input, registry_path, options=options)
        request = policy_context["request"]
        risk, host = request["risk"], request["host"]
        role = policy_context["capability_role"] or ""
        requested_effort = request["requested_effort"] or ""


    def policy_block(reason, message):
        if policy_mode:
            raise mp.PolicyError(reason, message)


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

    # REQ-002 (T-002, epic-159-pillar-c, #150): v2-only effort vocabulary and
    # resolution helpers. EFFORT_ORDER is a SEPARATE ordinal from the existing
    # `efforts` tiebreak dict above (which is part of the byte-unmodified v1
    # sort key, `efforts[""] == efforts["low"] == 0`, and must not be reused
    # for v2 clamp/bump arithmetic, where "" is never a valid member).
    EFFORT_VALUES = ("low", "medium", "high", "xhigh")
    EFFORT_ORDER = ["low", "medium", "high", "xhigh"]


    def effort_rank(value):
        return EFFORT_ORDER.index(value)


    def clamp_effort(value, supported):
        """Clamp `value` to the nearest member of `supported` (AC-009)."""
        ranks = sorted(effort_rank(item) for item in supported)
        target = effort_rank(value)
        if target in ranks:
            return EFFORT_ORDER[target]
        if target < ranks[0]:
            return EFFORT_ORDER[ranks[0]]
        if target > ranks[-1]:
            return EFFORT_ORDER[ranks[-1]]
        below = max(item for item in ranks if item < target)
        above = min(item for item in ranks if item > target)
        nearest = below if (target - below) <= (above - target) else above
        return EFFORT_ORDER[nearest]


    def bump_effort(value):
        return EFFORT_ORDER[min(effort_rank(value) + 1, len(EFFORT_ORDER) - 1)]


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
    if effort_policy not in ("welded", "matrix"):
        print("MODEL_SELECTION_ERROR: invalid effort policy", file=sys.stderr)
        sys.exit(1)
    if host not in (("claude-code", "codex-cli", "copilot-cli", "gemini-cli") if policy_mode else ("claude-code", "codex-cli")):
        print("MODEL_SELECTION_ERROR: invalid host", file=sys.stderr)
        sys.exit(1)
    if requested_effort and requested_effort not in EFFORT_VALUES:
        print("MODEL_SELECTION_ERROR: invalid requested effort", file=sys.stderr)
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
            policy_block("model-tier-unavailable", "Terminal-tier recurrence requires a new approved attempt.")
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

    # `parsed` tuples are (name, tier, cost, sort_effort, final_effort, source).
    # `sort_effort` (position 3) feeds the EXISTING, byte-unmodified sort-key
    # tiebreak (`efforts[item[3]]`, below) exactly as it always has: for v1 and
    # legacy-positional candidates it IS the declared/only effort concept, so
    # `sort_effort == final_effort` there always and the two new v2-only
    # fields (`final_effort`, `source`) are inert passengers. For v2,
    # `sort_effort` stays the CANDIDATES-FILE-declared value (or "" if the
    # candidate omitted it, matching legacy's "no preference" ordinal) so the
    # existing tiebreak keeps its original "prefer the candidate's own cheaper
    # declared effort variant" meaning; `final_effort` (position 4) is the
    # REQ-002 policy-resolved value used for the xhigh eligibility gate and for
    # JSON/text reporting, since design.md requires that gate to run "computed
    # AFTER the bump, not before it".
    # RT-20260821-009: models that the registry designates as a same-tier
    # fallback (design.md:44, requirements.md:50-51) must never win an
    # equal-cost tie against their primary. Loaded best-effort so the legacy
    # --candidate path (which never required the registry) keeps working.
    fallback_names = set()
    try:
        with open(registry_path, encoding="utf-8") as _handle:
            for _model in json.load(_handle).get("models", []):
                if _model.get("fallback_for"):
                    fallback_names.add(_model["name"])
    except Exception:
        pass

    parsed = []
    available_names = []
    v2_active = False
    host_control_map = {}
    if candidates_file or policy_mode:
        try:
            if policy_mode:
                registry, candidate_data = policy_context["registry"], policy_context["candidates"]
            else:
                with open(registry_path, encoding="utf-8") as handle:
                    registry = json.load(handle)
                with open(candidates_file, encoding="utf-8") as handle:
                    candidate_data = json.load(handle)
            if not isinstance(candidate_data, list):
                raise ValueError
            schema = registry.get("schema")
            if schema == "agent-model-capabilities/v1":
                # EXISTING, byte-unmodified v1 path (AC-006): only the tuple
                # shape below is widened (two trailing fields that always
                # mirror position 3, never observed by v1 output).
                registered = {
                    item["name"]: item for item in registry["models"]
                    if item["canonical_tier"] in tiers
                }
                for item in candidate_data:
                    definition = registered[item["name"]]
                    effort = item["effort"]
                    if effort not in definition["efforts"] or not isinstance(item["available"], bool):
                        raise ValueError
                    cost = parse_cost(item["cost"])
                    if item["available"]:
                        parsed.append((item["name"], definition["canonical_tier"], cost,
                                        effort, effort, None))
                        available_names.append(item["name"])
            elif schema == "agent-model-capabilities/v2":
                v2_active = True
                risk_matrix_raw = registry.get("risk_effort_matrix")
                risk_matrix = {}
                escalation_bump_enabled = False
                if risk_matrix_raw is not None:
                    if not isinstance(risk_matrix_raw, dict):
                        raise ValueError
                    for key, value in risk_matrix_raw.items():
                        if key == "escalation_bump":
                            if not isinstance(value, bool):
                                raise ValueError
                            escalation_bump_enabled = value
                            continue
                        if key not in matrix:
                            continue
                        if not isinstance(value, str) or value not in EFFORT_VALUES:
                            raise ValueError
                        risk_matrix[key] = value
                role_defaults_raw = registry.get("role_defaults")
                role_defaults = role_defaults_raw if isinstance(role_defaults_raw, dict) else {}
                registered = {}
                for item in registry.get("models", []):
                    if item.get("canonical_tier") not in tiers:
                        continue
                    supported = item.get("supported_efforts")
                    if (not isinstance(supported, list) or len(supported) == 0
                            or any((not isinstance(entry, str)) or entry not in EFFORT_VALUES
                                   for entry in supported)):
                        raise ValueError
                    default_effort = item.get("default_effort")
                    if default_effort not in supported:
                        raise ValueError
                    control = item.get("effort_control")
                    if not isinstance(control, dict):
                        raise ValueError
                    for host_key in ("claude-code", "codex-cli"):
                        if host_key in control and control[host_key] not in (
                                "flag", "frontmatter", "none"):
                            raise ValueError
                    registered[item["name"]] = item
                role_min_tier = None
                role_default_effort = None
                if role:
                    role_entry = policy_context["role_profile"] if policy_mode else role_defaults.get(role)
                    if isinstance(role_entry, dict):
                        entry_min_tier = role_entry.get("minimum_tier")
                        if entry_min_tier in tiers:
                            role_min_tier = entry_min_tier
                        entry_default_effort = role_entry.get("default_effort")
                        if entry_default_effort in EFFORT_VALUES:
                            role_default_effort = entry_default_effort
                if not minimum_tier and role_min_tier:
                    minimum_tier = role_min_tier
                    if minimum_tier not in tiers:
                        raise ValueError
                for item in candidate_data:
                    definition = registered[item["name"]]
                    supported = definition["supported_efforts"]
                    if not isinstance(item["available"], bool):
                        raise ValueError
                    cost = ((None if item["cost"] is None else decimal.Decimal(item["cost"]))
                            if policy_mode else parse_cost(item["cost"]))
                    declared_effort = item.get("effort")
                    if declared_effort is not None:
                        if declared_effort not in supported:
                            raise ValueError
                    sort_effort = declared_effort if declared_effort is not None else ""
                    if requested_effort:
                        base_effort = requested_effort
                        source = "requested"
                    elif effort_policy == "welded":
                        base_effort = (
                            declared_effort if declared_effort is not None
                            else definition["default_effort"]
                        )
                        source = "welded"
                    elif risk in risk_matrix:
                        base_effort = risk_matrix[risk]
                        source = "risk-matrix"
                    elif role_default_effort:
                        base_effort = role_default_effort
                        source = "role-default"
                    else:
                        base_effort = definition["default_effort"]
                        source = "model-default"
                    final_effort = clamp_effort(base_effort, supported)
                    if source == "risk-matrix" and escalation_tier and escalation_bump_enabled:
                        final_effort = clamp_effort(bump_effort(final_effort), supported)
                    if item["available"]:
                        parsed.append((item["name"], definition["canonical_tier"], cost,
                                        sort_effort, final_effort, source))
                        available_names.append(item["name"])
                        host_control_map[item["name"]] = definition.get("effort_control") or {}
            else:
                raise ValueError
        except Exception:
            policy_block("config-invalid", "Capability candidates are invalid.")
            print("MODEL_SELECTION_ERROR: invalid capability candidates", file=sys.stderr)
            sys.exit(1)
    else:
        for candidate in legacy_candidates:
            try:
                name, tier, cost = candidate.rsplit(":", 2)
                parsed.append((name, tier, parse_cost(cost), "", "", None))
                available_names.append(name)
            except Exception:
                print("MODEL_SELECTION_ERROR: invalid candidate", file=sys.stderr)
                sys.exit(1)
            if tier not in tiers:
                print("MODEL_SELECTION_ERROR: invalid tier", file=sys.stderr)
                sys.exit(1)

    policy_candidates = {item["name"]: item for item in policy_context["candidates"]} if policy_mode else {}
    eligible = [
        item for item in parsed
        if (not escalation_tier or item[1] == escalation_tier)
        and (not required_tier or item[1] == required_tier)
        and (not minimum_tier or tiers[item[1]] >= tiers[minimum_tier])
        and (item[4] != "xhigh" or bool(xhigh_reason))
        and (not policy_mode or not policy_context["role_profile"].get("minimum_tier") or
             tiers[item[1]] >= tiers[policy_context["role_profile"]["minimum_tier"]])
        and (not policy_mode or item[4] in policy_candidates[item[0]]["allowed_efforts"])
    ]
    if not eligible:
        policy_block("model-tier-unavailable", "No policy candidate satisfies the required capability and effort gates.")
        print("BLOCKED model-tier-unavailable")
        sys.exit(0)
    if policy_mode:
        # Supersession applies only after the existing capability gates have accepted both models.
        superseded = {prior for item in eligible for prior in policy_candidates[item[0]]["successor_of"]}
        eligible = [item for item in eligible if item[0] not in superseded]
    winner = sorted(
        eligible,
        key=lambda item: (
            matrix[risk][item[1]], tiers[item[1]], efforts[item[3]],
            *((policy_candidates[item[0]]["preference"], item[2] is None, item[2], item[0]) if policy_mode else
              (item[2], item[0] in fallback_names, item[0]))
        ),
    )[0]
    if policy_mode:
        proposal = {"model": winner[0], "canonical_tier": winner[1],
                    "effort": winner[4], "effort_control": host_control_map[winner[0]][host]}
        result = proposal if policy_engine_only == "true" else mp.complete_policy(policy_context, proposal)
        print(mp.canonical(result).decode("utf-8"))
        sys.exit(0)
    if json_output == "true":
        output = {
            "model": winner[0],
            "canonical_tier": winner[1],
            "effort": winner[4] or None,
            "estimated_cost_per_attempt_usd": str(winner[2]),
            "available_candidates": sorted(set(available_names)),
            "xhigh_reason": xhigh_reason if winner[4] == "xhigh" else None,
            "escalation": ({
                "attempt_number": attempt,
                "failure_class": failure_class,
                "next_tier": escalation_tier,
                "prior_tier": previous_tier,
                "reason": "same-classified-failure-twice",
            } if escalation_tier else None),
        }
        if v2_active:
            output["effort_source"] = winner[5]
            output["effort_control"] = host_control_map.get(winner[0], {}).get(host)
        print(json.dumps(output, separators=(",", ":"), sort_keys=True))
    else:
        suffix = ""
        if escalation_tier:
            suffix = (
                f" prior_tier={previous_tier} next_tier={escalation_tier}"
                f" failure_class={failure_class} attempt_number={attempt}"
                " reason=same-classified-failure-twice"
            )
        print(f"{winner[0]} {winner[1]}{suffix}")
except SystemExit as failure:
    if policy_mode and failure.code not in (0, None):
        sys.stderr.write(mp.canonical(mp.PolicyError("config-invalid", "Selector options are invalid.").as_dict()).decode() + "\n")
        sys.exit(2)
    raise
except Exception as failure:
    if not policy_mode or mp is None:
        raise
    error = failure if isinstance(failure, mp.PolicyError) else mp.PolicyError("config-invalid", "Policy selection input is invalid.")
    sys.stderr.write(mp.canonical(error.as_dict()).decode() + "\n")
    sys.exit(2)

PY
