#!/usr/bin/env python3
"""Resolve optional UI provider routing; stdin/stdout are transient JSON, no I/O APIs."""
import json
import sys


def validate(request):
    if not isinstance(request, dict) or request.get("schema") != "design-sync-request/v1":
        raise ValueError("expected design-sync-request/v1")
    for key in ("ui_app", "capability_resolved", "provider_available", "egress_permitted"):
        if type(request.get(key)) is not bool:
            raise ValueError(f"{key} must be boolean")
    if request.get("operation") not in ("pull", "upload"):
        raise ValueError("operation must be pull or upload")
    for key in ("feature", "session", "destination"):
        if not isinstance(request.get(key), str) or not request[key].strip():
            raise ValueError(f"{key} must be a nonempty string")
    if request.get("ds_profile") not in ("custom", "none"):
        raise ValueError("ds_profile must be custom or none")
    if request.get("setting") is not None and not isinstance(request["setting"], str):
        raise ValueError("setting must be a string or null")
    if request.get("response") not in (None, "grant", "decline"):
        raise ValueError("response must be grant, decline, or absent")
    if request.get("response") == "grant" and (
        not isinstance(request.get("party"), str) or not request["party"].strip()
    ):
        raise ValueError("an explicit grant must name its party")
    if not isinstance(request.get("records"), list):
        raise ValueError("records must be an oldest-first array")
    for record in request["records"]:
        if not isinstance(record, dict):
            raise ValueError("record must be an object")
        for key in ("feature", "session", "destination"):
            if not isinstance(record.get(key), str) or not record[key].strip():
                raise ValueError(f"record {key} must be a nonempty string")
        if record.get("decision") not in ("granted", "withdrawn", "not-permitted"):
            raise ValueError("record decision is invalid")
        if record.get("setting", "per-feature") not in ("standing", "per-feature", "off"):
            raise ValueError("record setting is invalid")


def resolve(request):
    validate(request)
    setting = request.get("setting")
    if setting not in ("standing", "off"):
        setting = "per-feature"
    scope = {key: request[key] for key in ("feature", "session", "destination")}

    def decision(action, reason, audit=None):
        return {"schema": "design-sync-decision/v1", "action": action,
                "reason": reason, "setting": setting, "audit": audit}

    def audit(value, party=None):
        if party is None:
            party = request.get("party") if setting == "per-feature" else f"ds_upload_consent: {setting}"
        return dict(scope, decision=value, setting=setting, party=party)

    if not request["ui_app"] or request["ds_profile"] == "none":
        return decision("skip", "UI provider not applicable")
    if not request["capability_resolved"]:
        return decision("manual", "UI capability not resolved")
    if request["operation"] == "pull":
        return decision("proceed", "applicable provider read") if request["provider_available"] else decision("manual", "design tools unavailable")
    if setting == "off":
        return decision("manual", "uploads disabled", audit("not-permitted"))
    if not request["provider_available"]:
        return decision("manual", "design tools unavailable")
    if not request["egress_permitted"]:
        return decision("manual", "egress not permitted", audit("not-permitted", "egress policy"))
    records = [record for record in request["records"]
               if all(record[key] == value for key, value in scope.items())]
    latest = records[-1] if records else None
    if latest and latest["decision"] == "not-permitted" and latest.get("setting", "per-feature") != "off":
        return decision("manual", "egress not permitted for this scope")
    if setting == "standing":
        recorded = any(
            record["feature"] == scope["feature"] and record["destination"] == scope["destination"]
            and record.get("setting") == "standing" and record["decision"] == "granted"
            for record in request["records"]
        )
        return decision("proceed", "standing consent", None if recorded else audit("granted"))
    if request.get("response") == "decline":
        return decision("manual", "this attempt declined")
    if request.get("response") == "grant":
        return decision("proceed", "explicit consent", audit("granted"))
    if latest and latest["decision"] == "granted" and latest.get("setting", "per-feature") == "per-feature":
        return decision("proceed", "current scope consent")
    return decision("prompt", "current scope consent required")


def main():
    try:
        result = resolve(json.load(sys.stdin))
    except (ValueError, TypeError) as error:
        print(f"design-sync: {error}", file=sys.stderr)
        return 1
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
