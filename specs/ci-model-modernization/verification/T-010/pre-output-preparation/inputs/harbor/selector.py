def select(request, catalog, observation):
    """Select an eligible model ID, otherwise raise ValueError."""
    preferred = request.get("preferred")
    if preferred:
        return preferred
    return catalog[0]["id"]
