def select(request, catalog, observation):
    """Return an eligible model ID, or raise ValueError for invalid input."""
    def nonempty_string(value):
        return isinstance(value, str) and len(value) > 0

    def nonnegative_integer(value):
        return (
            isinstance(value, int)
            and not isinstance(value, bool)
            and value >= 0
        )

    def string_list(value):
        return isinstance(value, list) and all(nonempty_string(item) for item in value)

    if not isinstance(request, dict):
        raise ValueError("request must be a dictionary")
    if not nonempty_string(request.get("role")):
        raise ValueError("role must be a nonempty string")
    if not nonnegative_integer(request.get("floor")):
        raise ValueError("floor must be a nonnegative integer")
    for key in ("preferred", "pinned"):
        if key in request and not nonempty_string(request[key]):
            raise ValueError(key + " must be a nonempty string")

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
        if not string_list(entry.get("roles")):
            raise ValueError("catalog roles must be a list of nonempty strings")

    if not isinstance(observation, dict):
        raise ValueError("observation must be a dictionary")
    if not isinstance(observation.get("fresh"), bool):
        raise ValueError("fresh must be a boolean")
    if not string_list(observation.get("available")):
        raise ValueError("available must be a list of nonempty strings")
    if not observation["fresh"]:
        raise ValueError("a stale observation cannot authorize selection")

    available = set(observation["available"])
    eligible = [
        entry["id"]
        for entry in catalog
        if entry["id"] in available
        and request["role"] in entry["roles"]
        and entry["tier"] >= request["floor"]
    ]
    if "pinned" in request:
        if request["pinned"] not in eligible:
            raise ValueError("pinned model is ineligible")
        return request["pinned"]
    if "preferred" in request and request["preferred"] in eligible:
        return request["preferred"]
    if eligible:
        return eligible[0]
    raise ValueError("no eligible model")
