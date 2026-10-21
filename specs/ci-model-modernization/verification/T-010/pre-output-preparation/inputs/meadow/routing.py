def select(request, catalog, observation):
    if not observation["fresh"]:
        raise ValueError("stale observation")
    eligible = [row["id"] for row in catalog if row["tier"] >= request["floor"] and request["role"] in row["roles"] and row["id"] in observation["available"]]
    if not eligible:
        raise ValueError("no eligible model")
    return eligible[0]


def record(selected, response):
    return {"configured_id": selected, "actual_id": response.get("actual_id"), "verified": response.get("actual_id") is not None}
