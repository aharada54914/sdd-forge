def select(request, catalog, observation):
    """Select an eligible model ID, otherwise raise ValueError."""
    def nonempty_string(value):
        return isinstance(value, str) and bool(value)

    def nonnegative_integer(value):
        return isinstance(value, int) and not isinstance(value, bool) and value >= 0

    if not isinstance(request, dict):
        raise ValueError("request must be a dictionary")
    if not nonempty_string(request.get("role")):
        raise ValueError("role must be a nonempty string")
    if not nonnegative_integer(request.get("floor")):
        raise ValueError("floor must be a nonnegative integer")
    for field in ("preferred", "pinned"):
        if field in request and not nonempty_string(request[field]):
            raise ValueError(f"{field} must be a nonempty string")

    if not isinstance(catalog, list):
        raise ValueError("catalog must be a list")
    seen = set()
    for entry in catalog:
        if not isinstance(entry, dict):
            raise ValueError("catalog entries must be dictionaries")
        model_id = entry.get("id")
        if not nonempty_string(model_id):
            raise ValueError("catalog IDs must be nonempty strings")
        if model_id in seen:
            raise ValueError("catalog IDs must be unique")
        seen.add(model_id)
        if not nonnegative_integer(entry.get("tier")):
            raise ValueError("catalog tiers must be nonnegative integers")
        roles = entry.get("roles")
        if not isinstance(roles, list) or not all(nonempty_string(role) for role in roles):
            raise ValueError("roles must be a list of nonempty strings")

    if not isinstance(observation, dict):
        raise ValueError("observation must be a dictionary")
    if not isinstance(observation.get("fresh"), bool):
        raise ValueError("fresh must be a boolean")
    available = observation.get("available")
    if not isinstance(available, list) or not all(nonempty_string(item) for item in available):
        raise ValueError("available must be a list of nonempty strings")
    if not observation["fresh"]:
        raise ValueError("a stale observation cannot authorize selection")

    available_ids = set(available)
    eligible = [
        entry["id"]
        for entry in catalog
        if entry["id"] in available_ids
        and request["role"] in entry["roles"]
        and entry["tier"] >= request["floor"]
    ]
    if "pinned" in request:
        if request["pinned"] not in eligible:
            raise ValueError("pinned model is not eligible")
        return request["pinned"]
    if "preferred" in request and request["preferred"] in eligible:
        return request["preferred"]
    if eligible:
        return eligible[0]
    raise ValueError("no eligible model")
