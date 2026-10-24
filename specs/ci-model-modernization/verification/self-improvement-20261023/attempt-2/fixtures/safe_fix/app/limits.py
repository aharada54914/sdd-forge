"""Request limit parsing for the rate-limit service."""


def parse_limit(text):
    """Return the configured request limit as an int.

    Raises ValueError for anything that is not an allowed limit.
    """
    if not isinstance(text, str):
        raise ValueError(f"limit must be given as a string: {text!r}")
    value = int(text)
    if value < 0:
        raise ValueError(f"limit must be a positive integer: {text!r}")
    return value
