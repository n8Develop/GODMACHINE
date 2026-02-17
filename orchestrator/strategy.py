"""Adaptive strategy selection: explore / retry / pivot."""


def determine_strategy(cycles: list[dict]) -> tuple[str, str]:
    """Return (strategy, explanation) based on recent cycle history."""
    if not cycles:
        return "explore", "No history yet — start building."

    recent = cycles[-3:]
    last = recent[-1]

    if last["result"] == "success":
        return "explore", "Last cycle succeeded. Try something new and ambitious."

    # Count consecutive failures on the same target
    current_target = last.get("target", "")
    consecutive_fails = 0
    for cycle in reversed(recent):
        if cycle.get("target") == current_target and cycle["result"] == "fail":
            consecutive_fails += 1
        else:
            break

    if consecutive_fails >= 3:
        return (
            "pivot",
            f"Failed at '{current_target}' {consecutive_fails} times. "
            "Abandon it and try something completely different.",
        )

    return (
        "retry",
        f"Last attempt at '{current_target}' failed: {last.get('error', 'unknown')}. "
        "Try a different approach to the same thing.",
    )
