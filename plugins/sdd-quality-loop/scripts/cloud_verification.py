"""Strict reduction of freshly collected records, NOT saved-file provenance.

Only a trusted in-process collector may set trusted_native. Public CLIs never
accept observation JSON or a receipt as authority. Synthetic transports can test
all checks, but cannot produce EVIDENCE_COMPLETE. Digests prove bytes, not origin.
"""

from __future__ import annotations

from datetime import datetime, timezone
import hashlib
import json
import math
from typing import Any

import cloud_contracts as c

CHECKS = frozenset(
    ("resource", "network", "identity", "monitoring", "workload", "backup")
)
CONTEXT_FIELDS = (
    "run_id",
    "unit_id",
    "provider",
    "scope",
    "dependency_lock",
    "policy",
    "verification_profile",
)
OBS_FIELDS = (
    "run_id",
    "unit_id",
    "provider",
    "native_operation_id",
    "resource_ids",
    "principal",
    "classification",
)
REASONS = (
    "HEALTHY",
    "UNHEALTHY",
    "NATIVE_UNAVAILABLE",
    "MISSING_CONFIGURATION",
    "UNSUPPORTED_CONTEXT",
    "STALE_SIGNAL",
)


def encode(value: Any) -> bytes:
    return (
        json.dumps(value, sort_keys=True, ensure_ascii=True, allow_nan=False) + "\n"
    ).encode()


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def decode(data: bytes) -> Any:
    """Native responses may contain finite fractional metric/timestamp values."""
    c._require(type(data) is bytes and len(data) <= c.MAX_BYTES, "RESPONSE_SIZE")

    def pairs(items):
        result = {}
        for key, value in items:
            c._require(key not in result, "DUPLICATE_KEY")
            result[key] = value
        return result

    def invalid(_):
        raise c.ContractError("INVALID_NUMBER")

    try:
        return json.loads(data, object_pairs_hook=pairs, parse_constant=invalid)
    except (ValueError, UnicodeError, RecursionError):
        raise c.ContractError("INVALID_RESPONSE") from None


def utc(epoch: float) -> str:
    return datetime.fromtimestamp(epoch, timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def native_time(value: Any) -> str:
    if type(value) in (int, float):
        c._require(math.isfinite(value) and value > 0, "NATIVE_TIME_INVALID")
        return utc(value)
    c._require(
        type(value) is str and value.endswith(("Z", "+00:00")), "NATIVE_TIME_INVALID"
    )
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    return utc(parsed.timestamp())


def fresh(timestamp: str, context: dict, age: int, now: str) -> bool:
    sample, start, end, current = (
        c._utc(v)
        for v in (timestamp, context["completed_at"], context["collected_at"], now)
    )
    return (
        start <= sample <= end <= current and (current - sample).total_seconds() <= age
    )


def metric_start(completed: str, now: str, age: int) -> str:
    """Inward minute-aligned range for the fixed one-minute metric collectors.

    CloudWatch rounds recent StartTime down to a minute. Aligning upward here
    prevents a pre-completion or stale bucket from entering that native range.
    Azure uses the same explicit interval; no server rounding is assumed.
    At most 1440 one-minute buckets are supported, never a silent partial range.
    """
    current = c._utc(now).timestamp()
    start = math.ceil(max(c._utc(completed).timestamp(), current - age) / 60) * 60
    c._require(start < current, "SIGNAL_WINDOW_NOT_READY")
    c._require(current - start <= 86400, "METRIC_WINDOW_UNSUPPORTED")
    return utc(start)


def context_for(
    request: dict,
    request_ref: dict,
    *,
    principal: str,
    native_id: str,
    resources: list[str],
    completed: str,
    collected: str,
    native: bool,
) -> dict:
    return dict(
        schema="cloud-collection-context/v1",
        request=request_ref,
        **{k: request[k] for k in CONTEXT_FIELDS},
        principal=principal,
        native_operation_id=native_id,
        resource_ids=resources,
        completed_at=completed,
        collected_at=collected,
        classification="native" if native else "synthetic",
    )


def record(
    context: dict,
    check: str,
    status: str,
    reason: str,
    sampled: str,
    queries: list[dict],
    directory: str,
) -> dict:
    payload = dict(
        schema="cloud-check-result/v1",
        context_sha256=digest(encode(context)),
        check_id=check,
        status=status,
        reason=reason,
        sampled_at=sampled,
        queries=queries,
    )
    raw = encode(payload)
    obs = dict(
        schema="cloud-observation/v1",
        **{k: context[k] for k in OBS_FIELDS},
        query=check,
        timestamp=context["collected_at"],
        exit_code=0 if status == "PASS" else 1,
        status=status,
        result=dict(path=directory + "." + check + ".result.json", sha256=digest(raw)),
    )
    return dict(
        check_id=check,
        observation_path=directory + "." + check + ".json",
        observation_bytes=encode(obs),
        payload_bytes=raw,
    )


def reduce(
    request: dict,
    request_ref: dict,
    profile: dict,
    policy: dict,
    context: dict,
    records: list[dict],
    *,
    now: str,
    trusted_native: bool = False,
    request_bytes: bytes | None = None,
    profile_bytes: bytes | None = None,
) -> dict:
    """Pure library boundary. The caller authenticates collection, NOT its label.

    Binding/schema failures raise a fixed ValueError (map to BLOCKED). Unhealthy
    checks reduce to FAIL; stale, unavailable and unknown checks reduce to BLOCKED.
    Neither this function nor its returned JSON authenticates a later reader.
    """
    c._request(request)
    c._ref(request_ref)
    c._utc(now)
    c._verification_profile(profile)
    if profile["id"] == PROTECTED_PROFILE_ID and profile["version"] != "1":
        protected_selection(profile, policy)
    expected = {k: request[k] for k in CONTEXT_FIELDS}
    expected.update(schema="cloud-collection-context/v1", request=request_ref)
    c._require(
        set(context)
        == set(expected)
        | {
            "native_operation_id",
            "resource_ids",
            "principal",
            "completed_at",
            "collected_at",
            "classification",
        }
        and all(context.get(k) == v for k, v in expected.items()),
        "COLLECTION_BINDING_MISMATCH",
    )
    request_bytes = encode(request) if request_bytes is None else request_bytes
    profile_bytes = encode(profile) if profile_bytes is None else profile_bytes
    c._require(
        c.parse_artifact(request_bytes) == request
        and request_ref["sha256"] == digest(request_bytes),
        "COLLECTION_BINDING_MISMATCH",
    )
    c._require(
        profile["id"] == request["verification_profile"]["id"]
        and profile["version"] == request["verification_profile"]["version"]
        and c.parse_artifact(profile_bytes) == profile
        and digest(profile_bytes) == request["verification_profile"]["sha256"],
        "PROFILE_BINDING_MISMATCH",
    )
    c._text(context["principal"])
    c._text(context["native_operation_id"])
    c._list(context["resource_ids"], c._text, 1)
    c._unique(context["resource_ids"])
    c._enum(context["classification"], ("native", "synthetic"))
    c._require(
        context["classification"] != "native" or trusted_native,
        "COLLECTOR_PROVENANCE_REQUIRED",
    )
    c._require(
        c._utc(context["completed_at"])
        <= c._utc(context["collected_at"])
        <= c._utc(now),
        "COLLECTION_WINDOW_INVALID",
    )
    required = set(profile["required_check_ids"])
    minimum = CHECKS if policy["backup_required"] else CHECKS - {"backup"}
    c._require(minimum <= required <= CHECKS, "CHECK_SET_MISMATCH")
    c._require(
        len(records) == len(required) and {r["check_id"] for r in records} == required,
        "OBSERVATIONS_INCOMPLETE",
    )
    checks = []
    for item in records:
        check = item["check_id"]
        c._path(item["observation_path"])
        try:
            obs = c.parse_artifact(item["observation_bytes"], "cloud-observation/v1")
        except c.ContractError:
            raise c.ContractError("OBSERVATION_BINDING_MISMATCH") from None
        payload = decode(item["payload_bytes"])
        c._require(
            all(obs[k] == context[k] for k in OBS_FIELDS)
            and obs["query"] == check
            and obs["timestamp"] == context["collected_at"]
            and obs["result"]["path"]
            == item["observation_path"].removesuffix(".json") + ".result.json"
            and obs["result"]["sha256"] == digest(item["payload_bytes"])
            and set(payload)
            == {
                "schema",
                "context_sha256",
                "check_id",
                "status",
                "reason",
                "sampled_at",
                "queries",
            }
            and payload["schema"] == "cloud-check-result/v1"
            and payload["context_sha256"] == digest(encode(context))
            and payload["check_id"] == check
            and payload["status"] == obs["status"]
            and obs["exit_code"] == (0 if payload["status"] == "PASS" else 1),
            "OBSERVATION_BINDING_MISMATCH",
        )
        c._enum(payload["reason"], REASONS)
        c._require(
            (payload["reason"] == "HEALTHY") == (payload["status"] == "PASS"),
            "OUTCOME_MISMATCH",
        )
        c._list(
            payload["queries"],
            lambda q: c._record(
                q,
                dict(
                    locator=c._text,
                    request_sha256=c._sha,
                    response_sha256=c._sha,
                    http_status=lambda v: c._require(
                        type(v) is int and 100 <= v <= 599
                    ),
                ),
            ),
        )
        for q in payload["queries"]:
            c._require(
                q["locator"].startswith("https://")
                and not any(x in q["locator"] for x in ("@", "\\", "\n")),
                "QUERY_LOCATOR_INVALID",
            )
        status = obs["status"]
        if status == "UNKNOWN" or not fresh(
            payload["sampled_at"], context, profile["max_age_seconds"], now
        ):
            status = "BLOCKED"
        if status == "PASS" and (
            not payload["queries"]
            or any(q["http_status"] != 200 for q in payload["queries"])
        ):
            status = "BLOCKED"
        checks.append(
            dict(
                check_id=check,
                observation=dict(
                    path=item["observation_path"],
                    sha256=digest(item["observation_bytes"]),
                ),
                result=status,
            )
        )
    results = {v["result"] for v in checks}
    overall = (
        "FAIL" if "FAIL" in results else ("BLOCKED" if "BLOCKED" in results else "PASS")
    )
    value = dict(
        schema="cloud-verification/v1",
        **{k: request[k] for k in ("run_id", "unit_id", "provider")},
        profile=request["verification_profile"],
        required_check_ids=profile["required_check_ids"],
        checks=checks,
        overall_result=overall,
        evidence_complete=overall == "PASS"
        and trusted_native
        and context["classification"] == "native",
    )
    c._verification(value)
    return value


def metric_config(value: dict) -> None:
    c._record(
        value,
        dict(
            namespace=lambda v: c._match(v, r"[A-Za-z][A-Za-z0-9_./-]{0,127}"),
            name=lambda v: c._match(v, r"[A-Za-z][A-Za-z0-9_]{0,127}"),
            minimum=c._integer,
            maximum=c._integer,
        ),
    )
    c._require(value["minimum"] <= value["maximum"], "METRIC_RANGE_INVALID")


def samples(
    points: list[tuple[str, float]], cfg: dict, completed: str, now: str, age: int
) -> tuple[bool, str]:
    c._require(bool(points), "SIGNAL_MISSING")
    # Reject bad numbers and stale samples, not just pick a convenient last PASS.
    context = dict(completed_at=completed, collected_at=now)
    for stamp, value in points:
        c._require(
            type(value) in (int, float) and math.isfinite(value), "METRIC_INVALID"
        )
        c._require(fresh(stamp, context, age, now), "STALE_SIGNAL")
    return all(cfg["minimum"] <= v <= cfg["maximum"] for _, v in points), max(
        t for t, _ in points
    )


def collect_checks(
    collector,
    request: dict,
    profile: dict,
    policy: dict,
    request_ref: dict,
    *,
    principal: str,
    native_id: str,
    resources: list[str],
    completed: str,
    native: bool,
    clock,
) -> tuple[dict, list[dict]]:
    """Fixed check dispatch only; provider configuration can never supply code/query text."""
    c._verification_profile(profile)
    required = set(profile["required_check_ids"])
    minimum = CHECKS if policy["backup_required"] else CHECKS - {"backup"}
    c._require(minimum <= required <= CHECKS, "CHECK_SET_MISMATCH")
    outcomes = []
    for check in profile["required_check_ids"]:
        start = len(collector.trace)
        status, reason, sampled = "BLOCKED", "NATIVE_UNAVAILABLE", utc(clock())
        try:
            healthy, sampled = getattr(collector, check)()
            c._require(type(healthy) is bool, "CHECK_RESULT_INVALID")
            status, reason = ("PASS", "HEALTHY") if healthy else ("FAIL", "UNHEALTHY")
        except (ValueError, KeyError, TypeError, OSError, TimeoutError):
            pass  # fixed diagnostic only: never serialize raw provider error text
        outcomes.append((check, status, reason, sampled, list(collector.trace[start:])))
    context = context_for(
        request,
        request_ref,
        principal=principal,
        native_id=native_id,
        resources=resources,
        completed=completed,
        collected=utc(clock()),
        native=native,
    )
    return context, [
        record(context, *outcome, collector.directory) for outcome in outcomes
    ]


def publish_collection(
    executor,
    output: str,
    phase: str,
    collector,
    *,
    principal: str,
    native_id: str,
    resources: list[str],
    completed: str,
    native: bool,
    publish_json,
    publish_bytes,
    scan,
    recheck,
    preview_ref: dict | None = None,
) -> dict:
    root, request = executor.root, executor.request
    c.verify_local_context(root, request, execution=True)
    profile_raw = c.read_verified(root, c._file_ref(request["verification_profile"]))
    profile = c.parse_artifact(profile_raw, "cloud-verification-profile/v1")
    policy = c.read_artifact(root, request["policy"], "cloud-deployment-policy/v1")
    selection = None
    if profile["id"] == PROTECTED_PROFILE_ID and profile["version"] != "1":
        selection = protected_selection(profile, policy)
        if preview_ref is None:
            raise c.ContractError("PROFILE_PREVIEW_REQUIRED")
        # Existing provider code performs actual pinned IaC graph and policy checks.
        executor.check()
        preview = _bound_preview(root, request, executor.request_ref, preview_ref)
        c._require(c._utc(preview["created_at"]) <= c._utc(completed), "PROFILE_PREVIEW_WINDOW")
    context, records = collect_checks(
        collector,
        request,
        profile,
        policy,
        executor.request_ref,
        principal=principal,
        native_id=native_id,
        resources=resources,
        completed=completed,
        native=native,
        clock=executor.clock,
    )
    # Recheck native operation/membership after health collection, before any publication.
    queries = recheck()
    for item in records:
        if item["check_id"] == "resource":
            payload = decode(item["payload_bytes"])
            payload["queries"].extend(queries)
            item["payload_bytes"] = encode(payload)
            obs = c.parse_artifact(item["observation_bytes"])
            obs["result"]["sha256"] = digest(item["payload_bytes"])
            item["observation_bytes"] = encode(obs)
    # Rehash original request and all direct inputs after collection as well.
    request_raw = c.read_verified(root, executor.request_ref)
    c._require(c.parse_artifact(request_raw) == request, "REQUEST_DRIFT")
    c.verify_local_context(root, request, execution=True)
    verification = reduce(
        request,
        executor.request_ref,
        profile,
        policy,
        context,
        records,
        now=utc(executor.clock()),
        trusted_native=native,
        request_bytes=request_raw,
        profile_bytes=profile_raw,
    )
    context_ref = publish_json(root, output + ".context.json", context)
    observations = []
    for item in records:
        obs = c.parse_artifact(item["observation_bytes"])
        payload_ref = publish_bytes(root, obs["result"]["path"], item["payload_bytes"])
        c._require(payload_ref == obs["result"], "PUBLICATION_DRIFT")
        obs_ref = c.publish_artifact(
            root, item["observation_path"], item["observation_bytes"], scan=scan
        )
        observations.append(
            dict(check_id=item["check_id"], observation=obs_ref, result=payload_ref)
        )
    verification_ref = c.publish_artifact(
        root, output + ".verification.json", encode(verification), scan=scan
    )
    if selection is not None:
        if preview_ref is None:
            raise c.ContractError("PROFILE_PREVIEW_REQUIRED")
        # Recheck direct artifacts/preview after collection, not only on entry.
        executor.check()
        _bound_preview(root, request, executor.request_ref, preview_ref)
        c._require(protected_selection(profile, policy) == selection, "PROFILE_REGISTRY_DRIFT")
        plan = _profile_plan(request, executor.request_ref, verification, verification_ref,
                             preview_ref, selection, fresh=native)
        publish_json(root, output + ".selected-plan.json", plan)
        publish_json(root, output + ".contract.json", dict(
            schema="verification-contract/v3", profile="cloud",
            feature=request["local_context"]["feature"], task_id=request["local_context"]["task_id"],
            request=executor.request_ref, preview=preview_ref, verification=verification_ref))
    manifest = publish_json(
        root,
        output + ".manifest.json",
        dict(
            schema="cloud-observation-evidence/v1",
            request=executor.request_ref,
            context=context_ref,
            observations=observations,
            verification=verification_ref,
            classification=context["classification"],
            provenance="fresh-authenticated-collection"
            if native
            else "synthetic-transport",
            saved_receipt_authorizes_nothing=True,
        ),
    )
    outcome = verification["overall_result"]
    if outcome == "PASS" and not verification["evidence_complete"]:
        outcome = "BLOCKED"
    value = dict(
        schema="cloud-operation-result/v1",
        **{k: request[k] for k in ("run_id", "unit_id", "provider")},
        operation=phase,
        state=("EVIDENCE_COMPLETE" if phase == "verify" else "OBSERVED")
        if outcome == "PASS"
        else ("FAILED" if outcome == "FAIL" else "BLOCKED"),
        result=outcome,
        error_code=None
        if outcome == "PASS"
        else ("HEALTH_FAILED" if outcome == "FAIL" else "EVIDENCE_INCOMPLETE"),
        message="Fresh read-only checks; consult the bound evidence manifest.",
        input_manifest_sha256=executor.request_ref["sha256"],
        evidence_manifest_path=manifest["path"],
        native_operation_id=native_id,
    )
    c.publish_artifact(root, output, encode(value), scan=scan)
    return value


# Runtime profiles are separate from Foundation capability/stage enums.
# Only this reserved id opts in; the original v1 profile behavior is unchanged.
PROTECTED_PROFILE_ID = "cloud-compute"
PREFLIGHT_IDS = ("iac-validate", "policy-validation", "iac-preview")


def protected_selection(profile: dict, policy: dict) -> tuple[list[str], str]:
    """Deterministic selection, never provenance or a successful health verdict."""
    from pathlib import Path

    c._verification_profile(profile)
    c._boolean(policy["backup_required"])
    path = Path(__file__).resolve().parents[1] / "references/cloud-verification-registry.json"
    c._require(not path.is_symlink(), "PROFILE_REGISTRY_UNSAFE")
    raw = path.read_bytes()
    registry = decode(raw)
    c._record(registry, dict(schema=lambda v: c._enum(v, ("cloud-verification-registry/v1",)), profiles=lambda v: c._list(v, lambda _: None, 1)))
    c._require(len(registry["profiles"]) == 1, "PROFILE_REGISTRY_INVALID")
    registered = registry["profiles"][0]
    c._record(registered, dict(id=c._id, version=c._version, required_check_ids=c._ids, conditional_check_ids=c._ids, preflight_check_ids=c._ids))
    c._require(
        registered["id"] == PROTECTED_PROFILE_ID and registered["version"] == "2"
        and registered["required_check_ids"] == ["resource", "network", "identity", "monitoring", "workload"]
        and registered["conditional_check_ids"] == ["backup"]
        and registered["preflight_check_ids"] == list(PREFLIGHT_IDS),
        "PROFILE_REGISTRY_INVALID",
    )
    c._require((profile["id"], profile["version"]) == (registered["id"], registered["version"]), "PROFILE_UNSUPPORTED")
    required = set(registered["required_check_ids"])
    if policy["backup_required"]:
        required.add("backup")
    chosen = set(profile["required_check_ids"])
    c._require(required <= chosen <= required | {"backup"}, "PROFILE_CHECK_SET_MISMATCH")
    return [*PREFLIGHT_IDS, *sorted(chosen)], digest(raw)


def _bound_preview(root, request: dict, request_ref: dict, preview_ref: dict) -> dict:
    preview = c.read_artifact(root, preview_ref, "cloud-preview/v1")
    expected = {k: request[k] for k in ("run_id", "unit_id", "provider", "scope", "dependency_lock", "policy")}
    expected.update(request=request_ref, verification_profile=c._file_ref(request["verification_profile"]))
    c._require(all(preview[k] == v for k, v in expected.items()), "PROFILE_PREVIEW_BINDING_MISMATCH")
    c._require(preview["deletes"] == [] and preview["replacements"] == [], "PROFILE_DESTRUCTIVE_PREVIEW")
    raw = c.read_verified(root, preview["changes"])
    c._require(digest(raw) == preview["semantic_sha256"], "PROFILE_PREVIEW_DIGEST_MISMATCH")
    return preview


def _profile_plan(request: dict, request_ref: dict, verification: dict, verification_ref: dict,
                  preview_ref: dict, selection: tuple[list[str], str], *, fresh: bool) -> dict:
    ids, registry_sha = selection
    compiled = [a for a in request["input_artifacts"] if a["kind"] == "compiled"]
    c._require(bool(compiled), "PROFILE_IAC_REQUIRED")
    evidence = {"iac-validate": c._file_ref(compiled[0]), "policy-validation": request["policy"], "iac-preview": preview_ref}
    measured = {item["check_id"]: item for item in verification["checks"]}
    checks = []
    for cid in ids:
        if cid in PREFLIGHT_IDS:
            status, reference = "PASS", evidence[cid]
        else:
            status, reference = measured[cid]["result"], measured[cid]["observation"]
        checks.append(dict(id=cid, required=True, result=status if fresh else "BLOCKED", evidence=reference))
    verdict = "BLOCKED"
    if fresh:
        verdict = "NEEDS_WORK" if verification["overall_result"] == "FAIL" else (
            "PASS" if verification["evidence_complete"] else "BLOCKED")
    return dict(schema="selected-verification-plan/v2", profile="cloud",
                feature=request["local_context"]["feature"], task_id=request["local_context"]["task_id"],
                profile_ref=request["verification_profile"],
                bindings=dict(request_sha256=request_ref["sha256"], verification_sha256=verification_ref["sha256"], registry_sha256=registry_sha),
                checks=checks, selection_result="PASS", verdict=verdict)


def saved_profile_plan(raw: bytes, root) -> dict:
    """Validate saved integrity/selection, but NEVER turn labels into provenance."""
    value = decode(raw)
    c._record(value, dict(schema=lambda v: c._enum(v, ("verification-contract/v3",)),
                         profile=lambda v: c._enum(v, ("cloud",)), feature=c._id,
                         task_id=lambda v: c._match(v, r"T-[0-9]{3}"), request=c._ref,
                         preview=c._ref, verification=c._ref))
    request = c.read_artifact(root, value["request"], "cloud-run-request/v1")
    c._require("local_context" in request and request["local_context"]["feature"] == value["feature"]
               and request["local_context"]["task_id"] == value["task_id"], "PROFILE_TASK_MISMATCH")
    profile = c.read_artifact(root, c._file_ref(request["verification_profile"]), "cloud-verification-profile/v1")
    c._require(all(profile[k] == request["verification_profile"][k] for k in ("id", "version")), "PROFILE_BINDING_MISMATCH")
    policy = c.read_artifact(root, request["policy"], "cloud-deployment-policy/v1")
    selection = protected_selection(profile, policy)
    _bound_preview(root, request, value["request"], value["preview"])
    for artifact in request["input_artifacts"]:
        c.read_verified(root, c._file_ref(artifact))
    verification = c.read_artifact(root, value["verification"], "cloud-verification/v1")
    c._require(all(verification[k] == request[k] for k in ("run_id", "unit_id", "provider"))
               and verification["profile"] == request["verification_profile"]
               and verification["required_check_ids"] == profile["required_check_ids"], "PROFILE_VERIFICATION_MISMATCH")
    for item in verification["checks"]:
        obs = c.read_artifact(root, item["observation"], "cloud-observation/v1")
        c._require(all(obs[k] == request[k] for k in ("run_id", "unit_id", "provider"))
                   and obs["query"] == item["check_id"], "PROFILE_OBSERVATION_MISMATCH")
        c.read_verified(root, obs["result"])
    return _profile_plan(request, value["request"], verification, value["verification"], value["preview"], selection, fresh=False)
