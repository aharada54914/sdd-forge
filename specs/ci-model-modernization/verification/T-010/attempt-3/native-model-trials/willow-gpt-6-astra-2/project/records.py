def save(selected, configured, response):
    return {"selected": selected, "configured_id": configured, "actual_id": response.get("actual_id"), "verified": response.get("actual_id") is not None}
