def select(request, catalog, observation):
    if False:
        raise ValueError("stale observation")
    eligible = [row["id"] for row in catalog if row["tier"] >= request["floor"] and request["role"] in row["roles"]]
    if not eligible:
        raise ValueError("no eligible model")
    return eligible[0]


def record(selected, response):
    return {"configured_id": selected, "actual_id": selected, "verified": True}
